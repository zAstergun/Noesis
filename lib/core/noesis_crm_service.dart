import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'insights_economy_config.dart';
import 'localization/noesis_l10n.dart';
import 'shop_service.dart';
import 'supabase_service.dart';

class NoesisAnnouncement {
  final bool enabled;
  final String title;
  final String message;
  final String type; // 'info' | 'warning' | 'promo' | 'release'
  final String ctaLabel;
  final String ctaUrl;

  const NoesisAnnouncement({
    this.enabled = false,
    this.title = '',
    this.message = '',
    this.type = 'info',
    this.ctaLabel = '',
    this.ctaUrl = '',
  });

  factory NoesisAnnouncement.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NoesisAnnouncement();
    return NoesisAnnouncement(
      enabled: map['enabled'] == true,
      title: (map['title'] ?? '').toString().trim(),
      message: (map['message'] ?? '').toString().trim(),
      type: (map['type'] ?? 'info').toString().trim(),
      ctaLabel: (map['cta_label'] ?? '').toString().trim(),
      ctaUrl: (map['cta_url'] ?? '').toString().trim(),
    );
  }

  String get fingerprint => '$enabled|$type|$title|$message|$ctaUrl';
}

class NoesisCrmNotice {
  final String id;
  final String title;
  final String message;
  final String tone; // 'info' | 'warning' | 'promo' | 'urgent'
  final String ctaLabel;
  final String ctaUrl;
  final DateTime createdAt;

  const NoesisCrmNotice({
    required this.id,
    required this.title,
    required this.message,
    this.tone = 'info',
    this.ctaLabel = '',
    this.ctaUrl = '',
    required this.createdAt,
  });

  factory NoesisCrmNotice.fromRow(Map<String, dynamic> row) {
    return NoesisCrmNotice(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString().trim(),
      message: (row['message'] ?? '').toString().trim(),
      tone: (row['tone'] ?? 'info').toString().trim(),
      ctaLabel: (row['cta_label'] ?? '').toString().trim(),
      ctaUrl: (row['cta_url'] ?? '').toString().trim(),
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  NoesisAnnouncement toAnnouncement() => NoesisAnnouncement(
        enabled: true,
        title: title,
        message: message,
        type: tone == 'urgent' ? 'warning' : tone,
        ctaLabel: ctaLabel,
        ctaUrl: ctaUrl,
      );
}

class NoesisRemotePlatformConfig {
  final bool maintenanceMode;
  final String? _maintenanceMessageOverride;
  final bool allowGuestMode;
  final bool allowRegistration;
  final Map<String, bool> featureFlags;
  final NoesisAnnouncement announcement;
  final Map<String, dynamic> versionControl;
  final Map<String, dynamic> economyConfig;
  final Map<String, dynamic> aiGovernance;

  const NoesisRemotePlatformConfig({
    this.maintenanceMode = false,
    String? maintenanceMessage,
    this.allowGuestMode = true,
    this.allowRegistration = true,
    this.featureFlags = const {
      'ai_agent': true,
      'quizzes': true,
      'flashcards': true,
      'notebooks': true,
      'roadmaps': true,
      'calendar': true,
      'study_groups': true,
      'ranking': true,
      'shop': true,
    },
    this.announcement = const NoesisAnnouncement(),
    this.versionControl = const {},
    this.economyConfig = const {},
    this.aiGovernance = const {},
  }) : _maintenanceMessageOverride = maintenanceMessage;

  String get maintenanceMessage {
    final override = _maintenanceMessageOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return NoesisL10n.tr(
      'O Noesis está passando por uma manutenção programada para melhorias. Voltamos em instantes!',
    );
  }

  factory NoesisRemotePlatformConfig.fromRow(Map<String, dynamic> row) {
    final rawFlags = row['feature_flags'];
    final flags = <String, bool>{
      'ai_agent': true,
      'quizzes': true,
      'flashcards': true,
      'notebooks': true,
      'roadmaps': true,
      'calendar': true,
      'study_groups': true,
      'ranking': true,
      'shop': true,
    };
    if (rawFlags is Map) {
      for (final entry in rawFlags.entries) {
        flags[entry.key.toString()] = entry.value != false;
      }
    }

    final rawAnn = row['announcement'];
    final annMap =
        rawAnn is Map ? Map<String, dynamic>.from(rawAnn) : null;

    final rawVersion = row['version_control'];
    final rawEconomy = row['economy_config'];
    final rawAi = row['ai_governance'];

    return NoesisRemotePlatformConfig(
      maintenanceMode: row['maintenance_mode'] == true,
      maintenanceMessage: (row['maintenance_message'] ?? '').toString().trim(),
      allowGuestMode: row['allow_guest_mode'] != false,
      allowRegistration: row['allow_registration'] != false,
      featureFlags: flags,
      announcement: NoesisAnnouncement.fromMap(annMap),
      versionControl: rawVersion is Map
          ? Map<String, dynamic>.from(rawVersion)
          : const {},
      economyConfig: rawEconomy is Map
          ? Map<String, dynamic>.from(rawEconomy)
          : const {},
      aiGovernance:
          rawAi is Map ? Map<String, dynamic>.from(rawAi) : const {},
    );
  }

  bool isFeatureEnabled(String key) => featureFlags[key] ?? true;
}

/// Serviço responsável por integrar o Noesis ao Aster CRM:
/// - Telemetria de presença em tempo real (`crm_record_presence_ping`)
/// - Registro de uso do app na conta Aster (`crm_touch_user_app`)
/// - Sincronização de governança remota (`noesis_platform_config`) via fetch + Realtime
class NoesisCrmService {
  NoesisCrmService._();
  static final NoesisCrmService instance = NoesisCrmService._();

  static const String appId = 'noesis';

  final ValueNotifier<NoesisRemotePlatformConfig> configNotifier =
      ValueNotifier<NoesisRemotePlatformConfig>(const NoesisRemotePlatformConfig());
  final ValueNotifier<List<NoesisCrmNotice>> noticesNotifier =
      ValueNotifier<List<NoesisCrmNotice>>(const []);

  Timer? _heartbeatTimer;
  RealtimeChannel? _configChannel;
  RealtimeChannel? _noticesChannel;
  RealtimeChannel? _ledgerChannel;
  String? _sessionId;
  String _currentPath = '/dashboard';
  String? _lastTouchedUid;
  bool _started = false;
  int _startEpoch = 0;

  static const Map<int, String> _tabPaths = {
    0: '/dashboard',
    1: '/quizzes',
    2: '/flashcards',
    3: '/notebooks',
    4: '/ai-agent',
    5: '/calendar',
    6: '/settings',
    7: '/study-log',
    8: '/roadmaps',
    9: '/shop',
    10: '/study-groups',
    11: '/ranking',
    12: '/profile',
    13: '/performance',
  };

  static const Map<int, String> _tabFeatureKeys = {
    1: 'quizzes',
    2: 'flashcards',
    3: 'notebooks',
    4: 'ai_agent',
    5: 'calendar',
    8: 'roadmaps',
    9: 'shop',
    10: 'study_groups',
    11: 'ranking',
  };

  bool isModuleEnabledForTab(int tabIndex) {
    final key = _tabFeatureKeys[tabIndex];
    if (key == null) return true;
    return configNotifier.value.isFeatureEnabled(key);
  }

  String _ensureSessionId() {
    if (_sessionId != null) return _sessionId!;
    final rand = Random();
    final suffix = List.generate(8, (_) => rand.nextInt(36).toRadixString(36)).join();
    _sessionId = 'noesis_${suffix}_${DateTime.now().millisecondsSinceEpoch}';
    return _sessionId!;
  }

  Map<String, dynamic> _clientInfo() {
    String os;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        os = 'Windows';
      case TargetPlatform.android:
        os = 'Android';
      case TargetPlatform.iOS:
        os = 'iOS';
      case TargetPlatform.macOS:
        os = 'macOS';
      case TargetPlatform.linux:
        os = 'Linux';
      default:
        os = 'Desktop';
    }
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return {
      'os': os,
      'browser': kIsWeb ? 'Web (Flutter)' : 'App Nativo ($os)',
      'device': isMobile ? 'Mobile' : 'Desktop',
      'app_version': '1.0.0+1',
    };
  }

  bool get _hasSupabaseClient {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get _isTestBinding {
    try {
      return WidgetsBinding.instance.runtimeType
          .toString()
          .contains('TestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  Future<void> start() async {
    if (_started || !_hasSupabaseClient || _isTestBinding) return;
    _started = true;
    final epoch = ++_startEpoch;

    await fetchRemoteConfig();
    if (!_started || epoch != _startEpoch) return;
    unawaited(fetchNotices());

    _subscribeConfigRealtime();
    _subscribeNoticesRealtime();
    _subscribeLedgerRealtime();
    unawaited(sendPresencePing());
    unawaited(touchUserAppIfAuthenticated());

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(sendPresencePing());
      unawaited(fetchRemoteConfig());
      if (SupabaseService.currentUser != null) {
        unawaited(fetchNotices());
        unawaited(ShopService.instance.syncFromCloud());
      }
    });
  }

  void stop() {
    _startEpoch++;
    _started = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_configChannel != null && _hasSupabaseClient) {
      try {
        Supabase.instance.client.removeChannel(_configChannel!);
      } catch (_) {}
      _configChannel = null;
    }
    if (_noticesChannel != null && _hasSupabaseClient) {
      try {
        Supabase.instance.client.removeChannel(_noticesChannel!);
      } catch (_) {}
      _noticesChannel = null;
    }
    if (_ledgerChannel != null && _hasSupabaseClient) {
      try {
        Supabase.instance.client.removeChannel(_ledgerChannel!);
      } catch (_) {}
      _ledgerChannel = null;
    }
  }

  void updateRouteForTab(int tabIndex) {
    final nextPath = _tabPaths[tabIndex] ?? '/dashboard';
    if (_currentPath != nextPath) {
      _currentPath = nextPath;
      if (_started) {
        unawaited(sendPresencePing());
      }
    }
  }

  void onAuthChanged() {
    if (!_started) return;
    _resubscribeRealtimeChannels();
    unawaited(sendPresencePing());
    unawaited(touchUserAppIfAuthenticated());
    unawaited(fetchNotices());
    unawaited(ShopService.instance.syncFromCloud());
  }

  void _resubscribeRealtimeChannels() {
    if (!_hasSupabaseClient) return;
    for (final ch in [_configChannel, _noticesChannel, _ledgerChannel]) {
      if (ch != null) {
        try {
          Supabase.instance.client.removeChannel(ch);
        } catch (_) {}
      }
    }
    _configChannel = null;
    _noticesChannel = null;
    _ledgerChannel = null;
    _subscribeConfigRealtime();
    _subscribeNoticesRealtime();
    _subscribeLedgerRealtime();
  }

  void _subscribeLedgerRealtime() {
    if (!_hasSupabaseClient) return;
    try {
      _ledgerChannel = Supabase.instance.client
          .channel('noesis-insight-ledger-live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'noesis_insight_ledger',
            callback: (payload) {
              final uid = SupabaseService.currentUser?.id;
              if (uid == null) return;
              final newUid = payload.newRecord['user_id']?.toString();
              final oldUid = payload.oldRecord['user_id']?.toString();
              if (newUid == uid || oldUid == uid) {
                unawaited(ShopService.instance.syncFromCloud());
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('NoesisCrmService: erro ao assinar Realtime do ledger: $e');
    }
  }

  Future<void> fetchNotices() async {
    if (!_hasSupabaseClient || SupabaseService.currentUser == null) {
      noticesNotifier.value = const [];
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('noesis_crm_notices')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(20);
      final list = (rows as List)
          .whereType<Map>()
          .map((r) => NoesisCrmNotice.fromRow(Map<String, dynamic>.from(r)))
          .toList();
      noticesNotifier.value = list;
    } catch (e) {
      debugPrint('NoesisCrmService: falha ao buscar noesis_crm_notices: $e');
    }
  }

  void _subscribeNoticesRealtime() {
    if (!_hasSupabaseClient) return;
    try {
      _noticesChannel = Supabase.instance.client
          .channel('noesis-crm-notices-live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'noesis_crm_notices',
            callback: (_) {
              unawaited(fetchNotices());
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('NoesisCrmService: erro ao assinar Realtime de avisos: $e');
    }
  }

  Future<void> fetchRemoteConfig() async {
    if (!_hasSupabaseClient) return;
    try {
      final row = await Supabase.instance.client
          .from('noesis_platform_config')
          .select()
          .eq('id', 'default')
          .maybeSingle();
      if (row != null) {
        _applyConfigRow(Map<String, dynamic>.from(row));
      }
    } catch (e) {
      debugPrint('NoesisCrmService: falha ao buscar noesis_platform_config: $e');
    }
  }

  void _applyConfigRow(Map<String, dynamic> row) {
    final cfg = NoesisRemotePlatformConfig.fromRow(row);
    configNotifier.value = cfg;
    InsightsEconomyConfig.applyRemoteOverrides(cfg.economyConfig);
  }

  void _subscribeConfigRealtime() {
    if (!_hasSupabaseClient) return;
    try {
      _configChannel = Supabase.instance.client
          .channel('noesis-platform-config-live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'noesis_platform_config',
            callback: (payload) {
              if (payload.newRecord.isNotEmpty) {
                _applyConfigRow(Map<String, dynamic>.from(payload.newRecord));
              } else {
                unawaited(fetchRemoteConfig());
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('NoesisCrmService: erro ao assinar Realtime de config: $e');
    }
  }

  Future<void> sendPresencePing() async {
    if (!_hasSupabaseClient) return;
    try {
      final user = SupabaseService.currentUser;
      final profile = SupabaseService.userProfileNotifier.value;
      final isAuth = user != null;
      final userName = isAuth
          ? (profile?['full_name'] ??
                  user.userMetadata?['full_name'] ??
                  user.email?.split('@').first ??
                  NoesisL10n.tr('Estudante Aster'))
              .toString()
          : NoesisL10n.tr('Visitante Noesis');

      await Supabase.instance.client.rpc(
        'crm_record_presence_ping',
        params: {
          'p_app_id': appId,
          'p_session_id': _ensureSessionId(),
          'p_user_id': user?.id,
          'p_user_email': user?.email,
          'p_user_name': userName,
          'p_is_authenticated': isAuth,
          'p_current_path': _currentPath,
          'p_client_info': _clientInfo(),
        },
      );
    } catch (_) {
      // Falha silenciosa para nunca impactar a experiência de estudo offline/online
    }
  }

  Future<void> touchUserAppIfAuthenticated() async {
    if (!_hasSupabaseClient) return;
    final user = SupabaseService.currentUser;
    if (user == null || _lastTouchedUid == user.id) return;
    _lastTouchedUid = user.id;
    try {
      await Supabase.instance.client.rpc(
        'crm_touch_user_app',
        params: {
          'p_app_id': appId,
          'p_metadata': _clientInfo(),
        },
      );
    } catch (_) {}
  }
}
