import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/constants.dart';
import 'core/desktop_window_service.dart';
import 'core/localization/noesis_l10n.dart';
import 'core/localization/noesis_locale_service.dart';
import 'core/noesis_crm_service.dart';
import 'core/notifications_service.dart';
import 'core/shop_service.dart';
import 'core/theme.dart';
import 'core/supabase_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/tracker/tracker_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/ai_agent/ai_assistant_screen.dart';
import 'features/quizzes/quiz_screen.dart';
import 'features/flashcards/flashcards_screen.dart';
import 'features/notebooks/notebooks_screen.dart';
import 'features/performance/performance_screen.dart';
import 'features/profile/data/social_connections_service.dart';
import 'features/profile/profile_screen.dart';
import 'features/ranking/data/ranking_service.dart';
import 'features/ranking/ranking_screen.dart';
import 'features/roadmaps/roadmaps_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/study_groups/study_groups_screen.dart';
import 'features/study_log/study_log_screen.dart';
import 'features/settings/settings_screen.dart';
import 'widgets/desktop_top_bar.dart';
import 'widgets/insight_gain_toast_overlay.dart';
import 'widgets/insight_icon.dart';
import 'widgets/noesis_logo.dart';
import 'widgets/profile_settings_dialog.dart';
import 'widgets/vip_privileges.dart';
import 'widgets/weekly_goal_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar idioma (manual > perfil > detecção automática > fallback Inglês)
  // e formatação de datas para todos os 15 idiomas suportados
  await NoesisLocaleService.ensureInitialized();

  // Inicializar controle nativo da janela desktop (Windows)
  await DesktopWindowService.ensureInitialized();
  await DesktopWindowService.setDarkMode(AsterTheme.isDarkMode);

  // Inicializar Supabase com a instância oficial do Aster
  await Supabase.initialize(
    url: AsterConstants.supabaseUrl,
    anonKey: AsterConstants.supabaseAnonKey,
  );

  // Desativar download de fontes em runtime (utilizar fontes locais em assets/fonts/)
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const NoesisApp());
}

class AsterScrollBehavior extends MaterialScrollBehavior {
  const AsterScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class NoesisApp extends StatefulWidget {
  const NoesisApp({super.key});

  @override
  State<NoesisApp> createState() => _NoesisAppState();
}

class _NoesisAppState extends State<NoesisApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    NoesisLocaleService.handlePlatformLocalesChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AsterTheme.themeModeNotifier,
        AsterTheme.activeThemeIdNotifier,
        AsterTheme.customThemeColorsNotifier,
        NoesisLocaleService.currentCodeNotifier,
      ]),
      builder: (context, _) {
        final themeMode = AsterTheme.themeModeNotifier.value;
        final activeOption = NoesisLocaleService.currentLanguage;
        return MaterialApp(
          title: AsterConstants.appName,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AsterScrollBehavior(),
          theme: AsterTheme.activeLightThemeData(),
          darkTheme: AsterTheme.activeDarkThemeData(),
          themeMode: themeMode,
          locale: activeOption.locale,
          supportedLocales: NoesisLocaleService.supportedFlutterLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Troca o ThemeData em 1 frame sem lerp pesado de TextTheme; a fluidez visual
          // é feita pelo NoesisThemeTransitionOverlay diretamente na GPU.
          themeAnimationDuration: Duration.zero,
          builder: (context, child) {
            return NoesisLocaleScope(
              notifier: NoesisLocaleService.currentCodeNotifier,
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamilyFallback: AsterTheme.scriptFontFamilyFallback,
                ),
                child: Directionality(
                  textDirection: NoesisLocaleService.textDirection,
                  child: NoesisThemeTransitionOverlay(
                    child: InsightGainToastOverlay(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
          home: const RootScreen(),
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @visibleForTesting
  static bool bypassAuthForTesting = false;

  @visibleForTesting
  static bool? isWebOverrideForTesting;

  static bool get _isWebEntry => isWebOverrideForTesting ?? kIsWeb;

  static late ValueNotifier<int> activeTabNotifier;
  static ValueNotifier<int>? activeTabListenable;
  static void switchTab(int index) {
    final notifier = activeTabListenable;
    if (notifier != null) {
      notifier.value = index;
    }
  }

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _SidebarNavEntry {
  const _SidebarNavEntry({
    required this.index,
    required this.title,
    required this.icon,
    this.subtitle = '',
    this.shortTitle,
  });

  final int index;
  final String title;
  final IconData icon;
  final String subtitle;
  final String? shortTitle;
}

class _SidebarNavSection {
  const _SidebarNavSection({
    this.header,
    required this.items,
  });

  final String? header;
  final List<_SidebarNavEntry> items;
}

class _RootScreenState extends State<RootScreen> {
  static List<_SidebarNavSection> get _navSections => [
    _SidebarNavSection(
      items: [
        _SidebarNavEntry(
          index: 0,
          title: NoesisL10n.tr('Dashboard'),
          shortTitle: NoesisL10n.tr('Início'),
          icon: Icons.home_rounded,
          subtitle: NoesisL10n.tr('Timer e metas'),
        ),
        _SidebarNavEntry(
          index: 13,
          title: NoesisL10n.tr('Desempenho'),
          icon: Icons.analytics_rounded,
          subtitle: NoesisL10n.tr('Métricas e evolução'),
        ),
      ],
    ),
    _SidebarNavSection(
      header: NoesisL10n.tr('ESTUDO'),
      items: [
        _SidebarNavEntry(
          index: 1,
          title: NoesisL10n.tr('Simulados'),
          icon: Icons.assignment_rounded,
          subtitle: NoesisL10n.tr('Provas com IA e RAG'),
        ),
        _SidebarNavEntry(
          index: 2,
          title: NoesisL10n.tr('Flashcards'),
          icon: Icons.style_rounded,
          subtitle: NoesisL10n.tr('Revisão espaçada 3D'),
        ),
        _SidebarNavEntry(
          index: 3,
          title: NoesisL10n.tr('Cadernos'),
          icon: Icons.menu_book_rounded,
          subtitle: NoesisL10n.tr('Resumos e anotações'),
        ),
        _SidebarNavEntry(
          index: 8,
          title: NoesisL10n.tr('Trilhas'),
          icon: Icons.route_rounded,
          subtitle: NoesisL10n.tr('Mapas de aprendizado'),
        ),
      ],
    ),
    _SidebarNavSection(
      header: NoesisL10n.tr('ROTINA & IA'),
      items: [
        _SidebarNavEntry(
          index: 7,
          title: NoesisL10n.tr('Diário de Estudos'),
          shortTitle: NoesisL10n.tr('Diário'),
          icon: Icons.auto_stories_rounded,
          subtitle: NoesisL10n.tr('Registro de sessões'),
        ),
        _SidebarNavEntry(
          index: 5,
          title: NoesisL10n.tr('Calendário'),
          icon: Icons.calendar_today_rounded,
          subtitle: NoesisL10n.tr('Agenda e revisões'),
        ),
        _SidebarNavEntry(
          index: 4,
          title: NoesisL10n.tr('Noesis AI'),
          icon: Icons.smart_toy_rounded,
          subtitle: NoesisL10n.tr('Tutor cognitivo'),
        ),
      ],
    ),
    _SidebarNavSection(
      header: NoesisL10n.tr('COMUNIDADE'),
      items: [
        _SidebarNavEntry(
          index: 10,
          title: NoesisL10n.tr('Grupos'),
          icon: Icons.groups_rounded,
          subtitle: NoesisL10n.tr('Estudo em equipe'),
        ),
        _SidebarNavEntry(
          index: 11,
          title: NoesisL10n.tr('Ranking'),
          icon: Icons.emoji_events_rounded,
          subtitle: NoesisL10n.tr('Ligas semanais'),
        ),
      ],
    ),
    _SidebarNavSection(
      header: NoesisL10n.tr('CONTA'),
      items: [
        _SidebarNavEntry(
          index: 12,
          title: NoesisL10n.tr('Perfil'),
          icon: Icons.person_rounded,
          subtitle: NoesisL10n.tr('Conquistas e social'),
        ),
        _SidebarNavEntry(
          index: 9,
          title: NoesisL10n.tr('Loja'),
          icon: Icons.storefront_rounded,
          subtitle: NoesisL10n.tr('Temas e itens VIP'),
        ),
        _SidebarNavEntry(
          index: 6,
          title: NoesisL10n.tr('Configurações'),
          shortTitle: NoesisL10n.tr('Config'),
          icon: Icons.settings_rounded,
          subtitle: NoesisL10n.tr('IA, temas e idioma'),
        ),
      ],
    ),
  ];

  static const Set<int> _mobilePrimaryTabIndices = {0, 1, 2, 4};

  static ({String? section, _SidebarNavEntry entry}) _findNavEntry(int index) {
    for (final section in _navSections) {
      for (final item in section.items) {
        if (item.index == index) {
          return (section: section.header, entry: item);
        }
      }
    }
    return (section: null, entry: _navSections.first.items.first);
  }

  late final ValueNotifier<int> _activeTabNotifier;
  Map<String, dynamic>? _userProfile;
  bool _isSidebarCollapsed = false;
  bool _showAuthScreen = false;
  bool _dismissedEmailBanner = false;
  bool _isResendingEmailBanner = false;
  bool _isCheckingEmailBanner = false;
  String? _dismissedAnnouncementFingerprint;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _studySessionsSubscription;
  Session? _session;
  int _weeklyStudiedMinutes = 0;
  int _dailyStudiedMinutes = 0;
  int _currentStreakDays = 0;

  final Set<int> _loadedTabs = {0};

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const TrackerScreen();
      case 1:
        return const QuizScreen();
      case 2:
        return const FlashcardsScreen();
      case 3:
        return const NotebooksScreen();
      case 4:
        return const AiAssistantScreen();
      case 5:
        return const CalendarScreen();
      case 6:
        return const SettingsScreen();
      case 7:
        return const StudyLogScreen();
      case 8:
        return const RoadmapsScreen();
      case 9:
        return const ShopScreen();
      case 10:
        return const StudyGroupsScreen();
      case 11:
        return const RankingScreen();
      case 12:
        return const ProfileScreen();
      case 13:
        return const PerformanceScreen();
      default:
        return const TrackerScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    AsterTheme.sidebarCollapsedNotifier.value = _isSidebarCollapsed;
    _activeTabNotifier = ValueNotifier<int>(0);
    RootScreen.activeTabNotifier = _activeTabNotifier;
    RootScreen.activeTabListenable = _activeTabNotifier;
    _activeTabNotifier.addListener(() {
      if (mounted) {
        setState(() {
          _loadedTabs.add(_activeTabNotifier.value);
        });
        NotificationsService.instance.refresh();
        NoesisCrmService.instance.updateRouteForTab(_activeTabNotifier.value);
      }
    });
    _session = SupabaseService.client.auth.currentSession;
    _showAuthScreen =
        !RootScreen._isWebEntry ||
        SupabaseService.extractOAuthCallbackError(Uri.base) != null;
    SupabaseService.userProfileNotifier.addListener(_onUserProfileChanged);
    SupabaseService.isVipNotifier.addListener(_onUserProfileChanged);
    SupabaseService.consistencyRevisionNotifier.addListener(_onConsistencyActivityChanged);
    ShopService.instance.transactionsNotifier.addListener(_onConsistencyActivityChanged);
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (!mounted) return;
      final newSession = data.session;
      if (_session?.user.id != newSession?.user.id) {
        setState(() {
          _session = newSession;
          _dismissedEmailBanner = false;
          if (newSession == null) {
            _showAuthScreen = !RootScreen._isWebEntry;
          }
        });
        NotificationsService.instance.handleAuthUserChanged(newSession?.user.id);
        NoesisCrmService.instance.onAuthChanged();
        if (newSession != null || RootScreen.bypassAuthForTesting) {
          unawaited(_initializeUserContext(forceShopReload: true));
        }
      }
    });
    NotificationsService.instance.handleAuthUserChanged(_session?.user.id);
    NotificationsService.instance.start();
    if (!RootScreen.bypassAuthForTesting) {
      unawaited(NoesisCrmService.instance.start());
    }
    if (_session != null || RootScreen.bypassAuthForTesting) {
      unawaited(_initializeUserContext());
    }
  }

  Future<void> _initializeUserContext({bool forceShopReload = false}) async {
    await Future.wait([
      _loadProfile(),
      _loadWeeklyGoalAndSessions(),
      ShopService.instance.init(force: forceShopReload),
    ]);
    if (mounted) {
      await NotificationsService.instance.refresh();
    }
  }

  void _onUserProfileChanged() {
    if (!mounted) return;
    setState(() {
      _userProfile = SupabaseService.userProfileNotifier.value;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    AsterTheme.sidebarCollapsedNotifier.value = _isSidebarCollapsed;
  }

  void _onConsistencyActivityChanged() {
    if (!mounted) return;
    unawaited(_syncSessionsAndRewards(_latestSessions));
  }

  List<Map<String, dynamic>> _latestSessions = const [];

  @override
  void dispose() {
    SupabaseService.userProfileNotifier.removeListener(_onUserProfileChanged);
    SupabaseService.isVipNotifier.removeListener(_onUserProfileChanged);
    SupabaseService.consistencyRevisionNotifier.removeListener(_onConsistencyActivityChanged);
    ShopService.instance.transactionsNotifier.removeListener(_onConsistencyActivityChanged);
    NotificationsService.instance.stop();
    NoesisCrmService.instance.stop();
    AsterTheme.sidebarCollapsedNotifier.value = false;
    _authSubscription?.cancel();
    _studySessionsSubscription?.cancel();
    if (identical(RootScreen.activeTabListenable, _activeTabNotifier)) {
      RootScreen.activeTabListenable = null;
    }
    _activeTabNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyGoalAndSessions() async {
    await Future.wait([
      SupabaseService.loadWeeklyGoalMinutes(),
      SupabaseService.loadDailyGoalMinutes(),
      SupabaseService.loadConsistencyActivity(),
    ]);
    await ShopService.instance.init();
    await RankingService.instance.init();
    _studySessionsSubscription?.cancel();
    _studySessionsSubscription = SupabaseService.studySessionsStream().listen((sessions) {
      if (!mounted) return;
      unawaited(_syncSessionsAndRewards(sessions));
    });
    final initialSessions = await SupabaseService.getStudySessions(limit: 200);
    await _syncSessionsAndRewards(initialSessions);
  }

  Future<void> _syncSessionsAndRewards(List<Map<String, dynamic>> sessions) async {
    _latestSessions = sessions;
    final extraActiveDates = <DateTime>{
      ...SupabaseService.recordedConsistencyDates,
      ...ShopService.instance.studyActivityDates,
    };
    await ShopService.instance.reconcileStreakProtectors(
      sessions,
      extraActiveDates: extraActiveDates,
    );
    ShopService.instance.evaluateStudyProgressRewards(
      sessions: sessions,
      weeklyGoalMinutes: SupabaseService.weeklyGoalMinutesNotifier.value,
      dailyGoalMinutes: SupabaseService.dailyGoalMinutesNotifier.value,
    );
    unawaited(RankingService.instance.syncCurrentUserProgress());
    final mins = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
    final dailyMins = SupabaseService.computeTodayStudiedMinutes(sessions);
    final streak = SupabaseService.computeCurrentStreakDays(
      sessions,
      protectedDates: ShopService.instance.protectedStreakDates,
      extraActiveDates: extraActiveDates,
    );
    if (mounted &&
        (mins != _weeklyStudiedMinutes ||
            dailyMins != _dailyStudiedMinutes ||
            streak != _currentStreakDays)) {
      setState(() {
        _weeklyStudiedMinutes = mins;
        _dailyStudiedMinutes = dailyMins;
        _currentStreakDays = streak;
      });
    }
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.loadFullProfile();
    await AsterTheme.loadCustomTheme(isVip: SupabaseService.isCurrentUserVip);
    unawaited(SocialConnectionsService.instance.init());
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
  }

  void _openProfileSettings() {
    showProfileSettingsDialog(
      context,
      streakDays: _currentStreakDays,
    );
  }

  Future<void> _resendBannerVerificationEmail(String email) async {
    if (_isResendingEmailBanner || email.trim().isEmpty) return;
    setState(() => _isResendingEmailBanner = true);
    try {
      await SupabaseService.resendSignupConfirmation(email);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AsterConstants.menta,
              content: Text(
                context.tr('Link de confirmação reenviado para {email}!', {'email': email}),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AsterConstants.coral,
              content: Text(
                SupabaseService.translateAuthError(e),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isResendingEmailBanner = false);
    }
  }

  Future<void> _checkBannerVerificationStatus() async {
    if (_isCheckingEmailBanner) return;
    setState(() => _isCheckingEmailBanner = true);
    try {
      final refreshed = await SupabaseService.refreshCurrentUser();
      if (!mounted) return;
      final confirmed = refreshed?.emailConfirmedAt != null ||
          SupabaseService.isCurrentUserEmailConfirmed;
      if (confirmed) {
        setState(() {
          _session = SupabaseService.client.auth.currentSession;
          _dismissedEmailBanner = true;
        });
        unawaited(NotificationsService.instance.refresh());
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AsterConstants.menta,
              content: Text(
                context.tr('E-mail confirmado com sucesso!'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: AsterConstants.ambar,
              content: Text(
                context.tr('Ainda não detectamos a confirmação. Clique no link enviado para seu e-mail.'),
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isCheckingEmailBanner = false);
    }
  }

  Widget _buildEmailVerificationReminderBanner({
    required BuildContext context,
    required String email,
    required bool isWideScreen,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final hasEmail = email.trim().isNotEmpty;

    return Container(
      key: const Key('email_verification_reminder_banner'),
      margin: EdgeInsets.fromLTRB(
        isWideScreen ? 28 : 16,
        isWideScreen ? 10 : 6,
        isWideScreen ? 28 : 16,
        4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AsterConstants.ambar.withValues(alpha: isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: AsterConstants.ambar.withValues(alpha: 0.42),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mark_email_unread_rounded,
                size: 18,
                color: AsterConstants.ambar,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  hasEmail
                      ? context.tr('Confirme seu e-mail ({email}) para validar e proteger sua conta.', {'email': email})
                      : context.tr('Confirme seu e-mail na caixa de entrada para validar sua conta.'),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasEmail)
                TextButton.icon(
                  key: const Key('email_verification_resend_button'),
                  onPressed: _isResendingEmailBanner
                      ? null
                      : () => _resendBannerVerificationEmail(email),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AsterConstants.ambar,
                  ),
                  icon: _isResendingEmailBanner
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 15),
                  label: Text(
                    _isResendingEmailBanner ? context.tr('Reenviando...') : context.tr('Reenviar e-mail'),
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              TextButton(
                key: const Key('email_verification_refresh_button'),
                onPressed: _isCheckingEmailBanner ? null : _checkBannerVerificationStatus,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: textCol,
                ),
                child: Text(
                  _isCheckingEmailBanner ? context.tr('Verificando...') : context.tr('Já confirmei'),
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('email_verification_dismiss_button'),
                tooltip: context.tr('Lembrar depois'),
                onPressed: () => setState(() => _dismissedEmailBanner = true),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                splashRadius: 16,
                icon: Icon(Icons.close_rounded, size: 16, color: mutedCol),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return context.tr('Bom dia');
    if (hour >= 12 && hour < 18) return context.tr('Boa tarde');
    return context.tr('Boa noite');
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    final formatter = DateFormat.MMMMEEEEd(NoesisLocaleService.intlLocale);
    try {
      final text = formatter.format(now);
      if (text.isEmpty) return NoesisL10n.tr('Hoje · Foco Ativo');
      return text[0].toUpperCase() + text.substring(1);
    } catch (_) {
      return NoesisL10n.tr('Hoje · Foco Ativo');
    }
  }

  void _showNotificationsPanel(BuildContext context, bool isWideScreen) {
    NotificationsService.instance.refresh();
    if (isWideScreen) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.12),
        builder: (dialogContext) {
          return Stack(
            children: [
              PositionedDirectional(
                top: DesktopTopBar.height + 6,
                end: DesktopWindowService.isCustomFrameSupported ? 116 : 16,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 390,
                      maxHeight: 520,
                    ),
                    child: _buildNotificationsContent(
                      dialogContext: dialogContext,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (bottomSheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: _buildNotificationsContent(
                  dialogContext: bottomSheetContext,
                  isBottomSheet: true,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildNotificationsContent({
    required BuildContext dialogContext,
    bool isBottomSheet = false,
  }) {
    return ValueListenableBuilder<List<NoesisNotification>>(
      valueListenable: NotificationsService.instance.notificationsNotifier,
      builder: (context, items, _) {
        final unread = items.where((n) => !n.isRead).length;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryCol = AsterTheme.primary(context);
        final cardCol = AsterTheme.card(context);
        final surfaceAltCol = AsterTheme.surfaceAlt(context);
        final insetCol = AsterTheme.surfaceInset(context);
        final textCol = AsterTheme.text(context);
        final mutedCol = AsterTheme.textMuted(context);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            border: Border.all(
              color: isDark ? insetCol : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isBottomSheet)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: insetCol,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryCol.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        size: 16,
                        color: primaryCol,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dialogContext.tr('Notificações'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AsterConstants.coral.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          unread == 1
                              ? dialogContext.tr('{count} nova', {'count': unread})
                              : dialogContext.tr('{count} novas', {'count': unread}),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.coral,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (unread > 0)
                      TextButton(
                        onPressed: NotificationsService.instance.markAllAsRead,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          dialogContext.tr('Marcar lidas'),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryCol,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: mutedCol),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: insetCol),
              Flexible(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: surfaceAltCol,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.done_all_rounded,
                                size: 24,
                                color: AsterConstants.menta,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              dialogContext.tr('Tudo em dia!'),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textCol,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dialogContext.tr('Você não tem novas notificações no momento.'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: mutedCol,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: NotificationsService.instance.restoreAndRefresh,
                              icon: Icon(Icons.refresh_rounded, size: 15, color: primaryCol),
                              label: Text(
                                dialogContext.tr('Verificar notificações'),
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryCol,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 64,
                          endIndent: 20,
                          color: insetCol.withValues(alpha: 0.6),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final itemColor = item.resolveColor(context);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                NotificationsService.instance.markAsRead(item.id);
                                _activeTabNotifier.value = item.targetTab;
                                _loadedTabs.add(item.targetTab);
                                Navigator.of(dialogContext).pop();
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: itemColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: item.id == 'welcome_insights_bonus'
                                          ? const Center(child: InsightCoinIcon(size: 20))
                                          : Icon(item.icon, size: 18, color: itemColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13,
                                                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                    color: textCol,
                                                  ),
                                                ),
                                              ),
                                              if (!item.isRead) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: itemColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.message,
                                            style: GoogleFonts.manrope(
                                              fontSize: 11.5,
                                              height: 1.35,
                                              color: item.isRead
                                                  ? mutedCol.withValues(alpha: 0.72)
                                                  : mutedCol,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.timeLabel,
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              color: mutedCol.withValues(alpha: 0.75),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: dialogContext.tr('Dispensar'),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: mutedCol.withValues(alpha: 0.7),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 14,
                                      onPressed: () =>
                                          NotificationsService.instance.dismiss(item.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (items.isNotEmpty) ...[
                Divider(height: 1, color: insetCol),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dialogContext.tr('Toque para abrir no app'),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: mutedCol.withValues(alpha: 0.75),
                        ),
                      ),
                      TextButton(
                        onPressed: NotificationsService.instance.dismissAll,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          dialogContext.tr('Limpar todas'),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: mutedCol,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemoteAnnouncementBanner({
    required BuildContext context,
    required NoesisAnnouncement announcement,
    required bool isWideScreen,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent;
    final IconData icon;
    switch (announcement.type) {
      case 'warning':
        accent = AsterConstants.ambar;
      case 'release':
        accent = AsterConstants.menta;
      case 'promo':
        accent = AsterConstants.coral;
      default:
        accent = AsterConstants.lavanda;
    }
    switch (announcement.type) {
      case 'warning':
        icon = Icons.warning_amber_rounded;
      case 'release':
        icon = Icons.new_releases_rounded;
      case 'promo':
        icon = Icons.celebration_rounded;
      default:
        icon = Icons.campaign_rounded;
    }

    return Container(
      key: const Key('crm_remote_announcement_banner'),
      margin: EdgeInsets.fromLTRB(
        isWideScreen ? 28 : 16,
        isWideScreen ? 10 : 6,
        isWideScreen ? 28 : 16,
        4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (announcement.title.isNotEmpty)
                  Text(
                    announcement.title,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.text(context),
                    ),
                  ),
                if (announcement.message.isNotEmpty)
                  Text(
                    announcement.message,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
              ],
            ),
          ),
          if (announcement.ctaLabel.isNotEmpty && announcement.ctaUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                final uri = Uri.tryParse(announcement.ctaUrl);
                if (uri != null) {
                  unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
                }
              },
              child: Text(
                announcement.ctaLabel,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          IconButton(
            tooltip: context.tr('Dispensar aviso'),
            onPressed: () => setState(() {
              _dismissedAnnouncementFingerprint = announcement.fingerprint;
            }),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            splashRadius: 16,
            icon: Icon(Icons.close_rounded, size: 16, color: AsterTheme.textMuted(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleDisabledNotice(BuildContext context, int tabIndex) {
    final navInfo = _findNavEntry(tabIndex);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AsterTheme.card(context),
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          boxShadow: AsterTheme.isDarkMode
              ? AsterConstants.clayDarkShadow
              : AsterConstants.clayShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AsterConstants.ambar.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.construction_rounded, color: AsterConstants.ambar, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('{module} em manutenção', {'module': context.tr(navInfo.entry.title)}),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AsterTheme.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Este módulo foi pausado temporariamente pela administração do ecossistema Aster.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AsterTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => RootScreen.switchTab(0),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: Text(context.tr('Voltar ao Dashboard')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceScreen(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SoftClayBackground(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AsterTheme.card(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
              boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NoesisLogo(size: 56, withShadow: true),
                const SizedBox(height: 18),
                Text(
                  context.tr('Noesis em Manutenção'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(message),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.45,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => unawaited(NoesisCrmService.instance.fetchRemoteConfig()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.tr('Verificar Novamente')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NoesisRemotePlatformConfig>(
      valueListenable: NoesisCrmService.instance.configNotifier,
      builder: (context, remoteConfig, _) {
        if (remoteConfig.maintenanceMode && !RootScreen.bypassAuthForTesting) {
          return _buildMaintenanceScreen(context, remoteConfig.maintenanceMessage);
        }
        return _buildRootContent(context, remoteConfig);
      },
    );
  }

  Widget _buildRootContent(BuildContext context, NoesisRemotePlatformConfig remoteConfig) {
    final session = _session ?? SupabaseService.client.auth.currentSession;

    if (session == null && !RootScreen.bypassAuthForTesting) {
      if (RootScreen._isWebEntry && !_showAuthScreen) {
        return LandingScreen(
          onOpenLogin: () {
            setState(() {
              _showAuthScreen = true;
            });
          },
        );
      }
      return AuthScreen(
        allowRegistration: remoteConfig.allowRegistration,
        onAuthenticated: () {
          final newSession = SupabaseService.client.auth.currentSession;
          final changed = _session?.user.id != newSession?.user.id;
          setState(() {
            _session = newSession;
            _dismissedEmailBanner = false;
            _showAuthScreen = !RootScreen._isWebEntry;
          });
          if (changed) {
            NotificationsService.instance.handleAuthUserChanged(newSession?.user.id);
            unawaited(_initializeUserContext(forceShopReload: true));
          }
        },
        onBackToLanding: RootScreen._isWebEntry
            ? () {
                setState(() {
                  _showAuthScreen = false;
                });
              }
            : null,
      );
    }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isWideScreen = screenWidth >= 900;
        final isCompactPhone = screenWidth < 380;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final rawFullName = (_userProfile?['full_name'] ?? '').toString().trim();
        final rawChannel = SupabaseService.sanitizeUsername((_userProfile?['channel'] ?? '').toString());
        final userName = rawFullName.isNotEmpty
            ? rawFullName
            : (rawChannel.isNotEmpty
                ? '@$rawChannel'
                : (session?.user.email?.split('@').first ?? context.tr('Estudante')));
        final initials = userName.isNotEmpty ? userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase() : 'ES';
        final avatarImage = buildAvatarImageProvider(_userProfile?['avatar_url']?.toString());
        final isVip = SupabaseService.isCurrentUserVip;

        void openMobileMenu() => _showMobileMenuSheet(
          context: context,
          userName: userName,
          rawChannel: rawChannel,
          initials: initials,
          avatarImage: avatarImage,
          isVip: isVip,
        );

        Widget buildWalletPill({required bool compactLabel}) {
          return ValueListenableBuilder<int>(
            valueListenable: ShopService.instance.balanceNotifier,
            builder: (context, balance, _) {
              return Tooltip(
                message: context.tr('Saldo na Loja ({currency})', {'currency': ShopService.currencyName}),
                child: InkWell(
                  key: const Key('header_wallet_pill'),
                  onTap: () => RootScreen.switchTab(9),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compactLabel ? 10 : 12,
                      vertical: compactLabel ? 6 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: AsterTheme.card(context),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      border: Border.all(
                        color: AsterConstants.ambar.withValues(alpha: 0.4),
                      ),
                      boxShadow: isDark
                          ? AsterConstants.claySubtleDarkShadow
                          : AsterConstants.claySubtleShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InsightCoinIcon(size: compactLabel ? 16 : 18),
                        SizedBox(width: compactLabel ? 5 : 7),
                        Text(
                          compactLabel ? '$balance' : '$balance ${ShopService.currencyName}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: compactLabel ? 11.5 : 12,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        Widget buildMobileBell({double size = 38}) {
          return ValueListenableBuilder<List<NoesisNotification>>(
            valueListenable: NotificationsService.instance.notificationsNotifier,
            builder: (context, notifications, _) {
              final unread = notifications.where((n) => !n.isRead).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: AsterTheme.card(context),
                      shape: BoxShape.circle,
                      boxShadow: isDark
                          ? AsterConstants.claySubtleDarkShadow
                          : AsterConstants.claySubtleShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('notifications_bell_button'),
                        onTap: () => _showNotificationsPanel(context, isWideScreen),
                        borderRadius: BorderRadius.circular(size / 2),
                        child: Center(
                          child: Icon(
                            unread > 0
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_none_rounded,
                            size: size * 0.5,
                            color: AsterTheme.text(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (unread > 0)
                    PositionedDirectional(
                      key: const Key('notifications_unread_dot'),
                      top: 1,
                      end: 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AsterConstants.coral,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AsterTheme.card(context),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(255, 122, 144, 0.4),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        }

        Widget buildMobileAvatar({double radius = 17}) {
          return Tooltip(
            message: context.tr('Configurações do Perfil'),
            child: InkWell(
              key: const Key('mobile_profile_button'),
              customBorder: const CircleBorder(),
              onTap: _openProfileSettings,
              child: VipAvatarCircle(
                isVip: isVip,
                badgeSize: VipBadgeSize.xs,
                borderWidth: 2,
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.16),
                  backgroundImage: avatarImage,
                  onBackgroundImageError: avatarImage != null ? (_, _) {} : null,
                  child: avatarImage == null
                      ? Text(
                          initials,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: AsterTheme.primary(context),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          );
        }

        final mainContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Top Bar (Desktop apenas na Home; Mobile em todas as telas com SafeArea)
            ValueListenableBuilder<int>(
              valueListenable: _activeTabNotifier,
              builder: (context, activeIndex, _) {
                if (isWideScreen && activeIndex != 0) {
                  return const SizedBox.shrink();
                }

                if (!isWideScreen && activeIndex != 0) {
                  final navInfo = _findNavEntry(activeIndex);
                  final sectionLabel = navInfo.section != null ? context.tr(navInfo.section!) : 'NOESIS';
                  return RepaintBoundary(
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(16, 14, isVip ? 20 : 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: InkWell(
                                key: const Key('mobile_topbar_menu_pill'),
                                onTap: openMobileMenu,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AsterTheme.card(context),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    border: Border.all(
                                      color: AsterTheme.surfaceInset(context).withValues(alpha: isDark ? 0.7 : 0.9),
                                    ),
                                    boxShadow: isDark
                                        ? AsterConstants.claySubtleDarkShadow
                                        : AsterConstants.claySubtleShadow,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        navInfo.entry.icon,
                                        size: 16,
                                        color: AsterTheme.primary(context),
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          isCompactPhone
                                              ? context.tr(navInfo.entry.title)
                                              : '$sectionLabel · ${context.tr(navInfo.entry.title)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AsterTheme.text(context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 17,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          buildWalletPill(compactLabel: true),
                          SizedBox(width: isCompactPhone ? 8 : 10),
                          buildMobileBell(size: 36),
                          SizedBox(width: isCompactPhone ? 8 : 10),
                          buildMobileAvatar(radius: 16),
                        ],
                      ),
                    ),
                  );
                }

                return RepaintBoundary(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      isWideScreen ? 28 : 16,
                      isWideScreen ? 22 : 14,
                      isWideScreen ? 28 : (isVip ? 20 : 16),
                      isWideScreen ? 12 : 10,
                    ),
                    child: Row(
                      children: [
                        if (!isWideScreen) ...[
                          const NoesisLogo(size: 32, withShadow: true),
                          const SizedBox(width: 9),
                          const NoesisWordmark(fontSize: 19),
                          if (screenWidth >= 360 && _currentStreakDays > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AsterConstants.ambar.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Text(
                                context.tr('🔥 {days}d', {'days': _currentStreakDays}),
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AsterTheme.text(context),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting(context)}, $userName.',
                                style: GoogleFonts.manrope(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AsterTheme.text(context),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    _currentStreakDays == 1
                                        ? context.tr('{date} · {days} dia de streak ', {'date': _formatTodayDate(), 'days': _currentStreakDays})
                                        : context.tr('{date} · {days} dias de streak ', {'date': _formatTodayDate(), 'days': _currentStreakDays}),
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: AsterTheme.textMuted(context),
                                    ),
                                  ),
                                  const Text('🔥', style: TextStyle(fontSize: 13)),
                                  ValueListenableBuilder<int>(
                                    valueListenable:
                                        ShopService.instance.streakProtectorsNotifier,
                                    builder: (context, shields, _) {
                                      if (shields <= 0) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsetsDirectional.only(start: 6),
                                        child: Tooltip(
                                          message: shields == 1
                                              ? context.tr('{count} Protetor de Ofensiva ativo', {'count': shields})
                                              : context.tr('{count} Protetores de Ofensiva ativos', {'count': shields}),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF38BDF8)
                                                  .withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(
                                                AsterConstants.radiusPill,
                                              ),
                                              border: Border.all(
                                                color: const Color(0xFF38BDF8)
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const StreakShieldIcon(size: 13),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$shields',
                                                  style: GoogleFonts.jetBrainsMono(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF0284C7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],

                        const Spacer(),

                        // Carteira rápida de Insights (clique abre a Loja)
                        buildWalletPill(compactLabel: !isWideScreen && screenWidth < 430),

                        // No mobile, o sino e o avatar ficam aqui no header (no desktop ficam na barra superior estilo Wispr Flow)
                        if (!isWideScreen) ...[
                          SizedBox(width: isCompactPhone ? 8 : 10),
                          buildMobileBell(size: 38),
                          SizedBox(width: isCompactPhone ? 8 : 10),
                          buildMobileAvatar(radius: 17),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            if (remoteConfig.announcement.enabled &&
                (remoteConfig.announcement.title.isNotEmpty ||
                    remoteConfig.announcement.message.isNotEmpty) &&
                _dismissedAnnouncementFingerprint !=
                    remoteConfig.announcement.fingerprint)
              _buildRemoteAnnouncementBanner(
                context: context,
                announcement: remoteConfig.announcement,
                isWideScreen: isWideScreen,
              )
            else
              ValueListenableBuilder<List<NoesisCrmNotice>>(
                valueListenable: NoesisCrmService.instance.noticesNotifier,
                builder: (context, notices, _) {
                  final urgentNotice = notices
                      .where((n) => n.tone == 'urgent' || n.tone == 'warning')
                      .where((n) => _dismissedAnnouncementFingerprint != 'notice:${n.id}')
                      .firstOrNull;
                  if (urgentNotice == null) return const SizedBox.shrink();
                  return _buildRemoteAnnouncementBanner(
                    context: context,
                    announcement: urgentNotice.toAnnouncement(),
                    isWideScreen: isWideScreen,
                  );
                },
              ),

            if (!_dismissedEmailBanner &&
                SupabaseService.shouldShowEmailVerificationReminder)
              _buildEmailVerificationReminderBanner(
                context: context,
                email: session?.user.email ??
                    (_userProfile?['email']?.toString() ?? ''),
                isWideScreen: isWideScreen,
              ),

            // Telas do App com Offstage (apenas a aba ativa executa layout/paint)
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _activeTabNotifier,
                builder: (context, activeIndex, _) {
                  _loadedTabs.add(activeIndex);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (int index = 0; index < 14; index++)
                        if (_loadedTabs.contains(index))
                          Positioned.fill(
                            child: Offstage(
                              offstage: index != activeIndex,
                              child: TickerMode(
                                enabled: index == activeIndex,
                                child: RepaintBoundary(
                                  child: NoesisCrmService.instance.isModuleEnabledForTab(index)
                                      ? _buildScreen(index)
                                      : _buildModuleDisabledNotice(context, index),
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        );

        final shellColor = noesisDesktopShellColor(context);
        final frameBorderColor = AsterTheme.surfaceInset(context).withValues(
          alpha: isDark ? 0.72 : 0.9,
        );

        return Scaffold(
          backgroundColor: isWideScreen ? shellColor : null,
          body: isWideScreen
              ? Container(
                  color: shellColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Barra Superior Integrada ───
                      ValueListenableBuilder<int>(
                        valueListenable: _activeTabNotifier,
                        builder: (context, activeIndex, _) {
                          return DesktopTopBar(
                            showWorkspaceControls: true,
                            isSidebarCollapsed: _isSidebarCollapsed,
                            isSettingsActive: activeIndex == 6,
                            onToggleSidebar: _toggleSidebar,
                            onOpenShop: () => RootScreen.switchTab(9),
                            onOpenNotifications: () => _showNotificationsPanel(context, isWideScreen),
                            onOpenSettings: () {
                              _activeTabNotifier.value = 6;
                              _loadedTabs.add(6);
                            },
                          );
                        },
                      ),

                      // ─── Área Inferior: Barra Lateral (Expandida ou Trilho Minimizado) + Página Enquadrada ───
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RepaintBoundary(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                width: _isSidebarCollapsed ? 62.0 : 236.0,
                                child: ClipRect(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 170),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: _isSidebarCollapsed
                                        ? _buildCollapsedSidebarRail(
                                            context: context,
                                            isDark: isDark,
                                            userName: userName,
                                            initials: initials,
                                            avatarImage: avatarImage,
                                            isVip: isVip,
                                          )
                                        : OverflowBox(
                                            key: const ValueKey('sidebar_expanded_overflow'),
                                            minWidth: 236.0,
                                            maxWidth: 236.0,
                                            alignment: AlignmentDirectional.topStart,
                                            child: _buildExpandedSidebarPanel(
                                              context: context,
                                              isDark: isDark,
                                              userName: userName,
                                              rawChannel: rawChannel,
                                              initials: initials,
                                              avatarImage: avatarImage,
                                              isVip: isVip,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            // ─── Enquadramento em Volta da Página (Borda Arredondada Estilo Wispr Flow) ───
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: frameBorderColor,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.045),
                                        blurRadius: 14,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SoftClayBackground(child: mainContent),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : (DesktopWindowService.isCustomFrameSupported
                  ? Container(
                      color: shellColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DesktopTopBar(
                            showWorkspaceControls: false,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SoftClayBackground(child: mainContent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SoftClayBackground(
                      child: SafeArea(
                        bottom: false,
                        child: mainContent,
                      ),
                    )),

          // ─── Bottom Navigation Bar Fixa Soft Clay (4 Principais + Menu Hub) ───
          bottomNavigationBar: !isWideScreen
              ? RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _activeTabNotifier,
                    builder: (context, activeIndex, _) {
                      final isInMenuTab = !_mobilePrimaryTabIndices.contains(activeIndex);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                          border: Border(
                            top: BorderSide(
                              color: AsterTheme.surfaceInset(context).withValues(alpha: isDark ? 0.55 : 0.75),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.32)
                                  : const Color.fromRGBO(60, 60, 120, 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMobileNavItem(
                                    0,
                                    Icons.home_rounded,
                                    context.tr('Dashboard'),
                                    activeIndex: activeIndex,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMobileNavItem(
                                    1,
                                    Icons.assignment_rounded,
                                    context.tr('Simulados'),
                                    activeIndex: activeIndex,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMobileNavItem(
                                    2,
                                    Icons.style_rounded,
                                    context.tr('Flashcards'),
                                    activeIndex: activeIndex,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMobileNavItem(
                                    4,
                                    Icons.smart_toy_rounded,
                                    context.tr('Noesis AI'),
                                    activeIndex: activeIndex,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMobileMenuNavButton(
                                    isActive: isInMenuTab,
                                    activeIndex: activeIndex,
                                    onTap: openMobileMenu,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : null,
        );
  }

  Widget _buildExpandedSidebarPanel({
    required BuildContext context,
    required bool isDark,
    required String userName,
    required String rawChannel,
    required String initials,
    required ImageProvider? avatarImage,
    required bool isVip,
  }) {
    return Container(
      key: const ValueKey('sidebar_expanded_panel'),
      width: 236,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Itens de Menu organizados por seção (rolável em telas menores para manter rodapé sempre visível)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in _navSections) ...[
                    if (section.header != null) _buildNavSectionHeader(context.tr(section.header!)),
                    for (int i = 0; i < section.items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 1),
                      _buildNavItem(
                        index: section.items[i].index,
                        title: context.tr(section.items[i].title),
                        icon: section.items[i].icon,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Widget: Meta Diária & Meta Semanal (interativos e editáveis)
          _buildGoalCard(
            key: const Key('sidebar_daily_goal_card'),
            tooltip: context.tr('Clique para editar a meta diária'),
            title: context.tr('META DIÁRIA'),
            studiedMinutes: _dailyStudiedMinutes,
            goalMinutesListenable: SupabaseService.dailyGoalMinutesNotifier,
            emptySuffix: context.tr('hoje'),
            progressColor: AsterTheme.primary(context),
            isDark: isDark,
            onTap: () => showDailyGoalEditorDialog(
              context,
              currentWeekStudiedMinutes: _weeklyStudiedMinutes,
              currentDayStudiedMinutes: _dailyStudiedMinutes,
            ),
          ),
          const SizedBox(height: 8),
          _buildGoalCard(
            key: const Key('sidebar_weekly_goal_card'),
            tooltip: context.tr('Clique para editar a meta semanal'),
            title: context.tr('META SEMANAL'),
            studiedMinutes: _weeklyStudiedMinutes,
            goalMinutesListenable: SupabaseService.weeklyGoalMinutesNotifier,
            emptySuffix: context.tr('na sem.'),
            progressColor: AsterTheme.secondary(context),
            isDark: isDark,
            onTap: () => showWeeklyGoalEditorDialog(
              context,
              currentWeekStudiedMinutes: _weeklyStudiedMinutes,
              currentDayStudiedMinutes: _dailyStudiedMinutes,
            ),
          ),
          const SizedBox(height: 10),

          // Botão oficial da comunidade Discord do Aster
          Tooltip(
            message: context.tr('Entrar na comunidade Discord do Aster ({code})', {'code': AsterConstants.asterDiscordInviteCode}),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5865F2),
                    Color(0xFF4752C4),
                  ],
                ),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5865F2).withValues(alpha: isDark ? 0.28 : 0.26),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                child: InkWell(
                  key: const Key('sidebar_discord_button'),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  hoverColor: Colors.white.withValues(alpha: 0.08),
                  splashColor: Colors.white.withValues(alpha: 0.14),
                  onTap: _openDiscordUrl,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: DiscordLogoWidget(size: 16),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('Entrar no Discord'),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                context.tr('Comunidade Aster'),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Perfil do Usuário + Sair
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: context.tr('Configurações do Perfil'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('sidebar_profile_button'),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      onTap: _openProfileSettings,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          children: [
                            VipAvatarCircle(
                              isVip: isVip,
                              badgeSize: VipBadgeSize.xs,
                              borderWidth: 2,
                              child: CircleAvatar(
                                radius: 17,
                                backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.15),
                                backgroundImage: avatarImage,
                                onBackgroundImageError: avatarImage != null ? (_, _) {} : null,
                                child: avatarImage == null
                                    ? Text(
                                        initials,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                          color: AsterTheme.primary(context),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                    ),
                                  ),
                                  Text(
                                    rawChannel.isNotEmpty
                                        ? '@$rawChannel · ${isVip ? 'VIP · ' : ''}${_currentStreakDays}d'
                                        : '${isVip ? 'VIP' : 'Pro'} · ${context.tr('Streak')} ${_currentStreakDays}d',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.tune_rounded,
                              size: 15,
                              color: isDark
                                  ? AsterConstants.textMutedDark.withValues(alpha: 0.8)
                                  : AsterConstants.textMuted.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                ),
                tooltip: context.tr('Sair'),
                onPressed: () {
                  SupabaseService.signOut();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({
    required Key key,
    required String tooltip,
    required String title,
    required int studiedMinutes,
    required ValueNotifier<int> goalMinutesListenable,
    required String emptySuffix,
    required Color progressColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: goalMinutesListenable,
      builder: (context, goalMinutes, _) {
        final hasGoal = goalMinutes > 0;
        final safeGoal = hasGoal ? goalMinutes : 1;
        final progress = (studiedMinutes / safeGoal).clamp(0.0, 1.0);
        final pct = ((studiedMinutes / safeGoal) * 100).round().clamp(0, 999);
        final reached = hasGoal && studiedMinutes >= safeGoal;

        return Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: AsterTheme.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AsterTheme.surfaceInset(context).withValues(alpha: isDark ? 0.55 : 0.75),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? AsterConstants.textMutedDark
                                  : AsterConstants.textMuted,
                            ),
                          ),
                          Icon(
                            Icons.edit_rounded,
                            size: 11,
                            color: AsterTheme.primary(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              hasGoal
                                  ? '${SupabaseService.formatGoalDuration(studiedMinutes)} / ${SupabaseService.formatGoalDuration(goalMinutes)}'
                                  : '${SupabaseService.formatGoalDuration(studiedMinutes)} $emptySuffix',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AsterConstants.textLight
                                    : AsterConstants.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasGoal ? '$pct%' : context.tr('Sem meta'),
                            style: GoogleFonts.manrope(
                              fontSize: hasGoal ? 11.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: !hasGoal
                                  ? (isDark
                                      ? AsterConstants.textMutedDark
                                      : AsterConstants.textMuted)
                                  : (reached
                                      ? AsterTheme.secondary(context)
                                      : AsterTheme.primary(context)),
                            ),
                          ),
                        ],
                      ),
                      if (hasGoal) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          backgroundColor: AsterTheme.surfaceInset(context),
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Trilho de ícones minimizado estilo Wispr Flow (62px).
  Widget _buildCollapsedSidebarRail({
    required BuildContext context,
    required bool isDark,
    required String userName,
    required String initials,
    required ImageProvider? avatarImage,
    required bool isVip,
  }) {
    final dividerColor = AsterTheme.surfaceInset(context).withValues(alpha: isDark ? 0.65 : 0.85);
    return Container(
      key: const ValueKey('sidebar_collapsed_rail'),
      width: 62,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  for (int s = 0; s < _navSections.length; s++) ...[
                    if (s > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: Container(height: 1, color: dividerColor),
                      ),
                    for (int i = 0; i < _navSections[s].items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 3),
                      _buildRailNavItem(_navSections[s].items[i]),
                    ],
                  ],
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Container(height: 1, color: dividerColor),
          ),
          _buildRailActionIcon(
            tooltip: context.tr('Metas de Estudo'),
            icon: Icons.track_changes_rounded,
            onTap: () => showDailyGoalEditorDialog(
              context,
              currentWeekStudiedMinutes: _weeklyStudiedMinutes,
              currentDayStudiedMinutes: _dailyStudiedMinutes,
            ),
          ),
          const SizedBox(height: 2),
          Tooltip(
            message: context.tr('Entrar no Discord (Comunidade Aster)'),
            child: InkWell(
              onTap: _openDiscordUrl,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 38,
                height: 34,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Center(
                      child: DiscordLogoWidget(size: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Tooltip(
            message: context.tr('{user} · Perfil', {'user': userName}),
            child: InkWell(
              onTap: _openProfileSettings,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 38,
                height: 36,
                child: Center(
                  child: VipAvatarCircle(
                    isVip: isVip,
                    badgeSize: VipBadgeSize.xs,
                    borderWidth: 1.5,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.16),
                      backgroundImage: avatarImage,
                      onBackgroundImageError: avatarImage != null ? (_, _) {} : null,
                      child: avatarImage == null
                          ? Text(
                              initials,
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                                color: AsterTheme.primary(context),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          _buildRailActionIcon(
            tooltip: context.tr('Sair'),
            icon: Icons.logout_rounded,
            onTap: () => SupabaseService.signOut(),
          ),
        ],
      ),
    );
  }

  Widget _buildRailNavItem(_SidebarNavEntry entry) {
    return ValueListenableBuilder<int>(
      valueListenable: _activeTabNotifier,
      builder: (context, activeIndex, _) {
        final cs = Theme.of(context).colorScheme;
        final isSelected = activeIndex == entry.index;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Tooltip(
          message: context.tr(entry.title),
          waitDuration: const Duration(milliseconds: 260),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _activeTabNotifier.value = entry.index;
                _loadedTabs.add(entry.index);
              },
              borderRadius: BorderRadius.circular(10),
              hoverColor: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected ? AsterTheme.primaryShadow(context) : null,
                ),
                child: Center(
                  child: Icon(
                    entry.icon,
                    size: 18,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRailActionIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
          child: SizedBox(
            width: 38,
            height: 34,
            child: Center(
              child: Icon(
                icon,
                size: 17.5,
                color: AsterTheme.textMuted(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDiscordUrl() async {
    final uri = Uri.parse(AsterConstants.asterDiscordUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _buildNavSectionHeader(String title) {
    final muted = AsterTheme.textMuted(context);
    final lineCol = AsterTheme.surfaceInset(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 8, 2),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: muted.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: lineCol.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Color _sectionAccentColor(BuildContext context, String? header) {
    if (header == null) return AsterTheme.primary(context);
    if (header == NoesisL10n.tr('ESTUDO') || header == NoesisL10n.tr('ESTUDO', null, 'br')) {
      return AsterConstants.ambar;
    }
    if (header == NoesisL10n.tr('ROTINA & IA') || header == NoesisL10n.tr('ROTINA & IA', null, 'br')) {
      return AsterConstants.menta;
    }
    if (header == NoesisL10n.tr('COMUNIDADE') || header == NoesisL10n.tr('COMUNIDADE', null, 'br')) {
      return AsterConstants.coral;
    }
    return AsterTheme.primary(context);
  }

  void _showMobileMenuSheet({
    required BuildContext context,
    required String userName,
    required String rawChannel,
    required String initials,
    required ImageProvider? avatarImage,
    required bool isVip,
  }) {
    String searchQuery = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
            final primaryCol = AsterTheme.primary(sheetContext);
            final cardCol = AsterTheme.card(sheetContext);
            final altCol = AsterTheme.surfaceAlt(sheetContext);
            final insetCol = AsterTheme.surfaceInset(sheetContext);
            final textCol = AsterTheme.text(sheetContext);
            final mutedCol = AsterTheme.textMuted(sheetContext);
            final q = searchQuery.trim().toLowerCase();

            return DraggableScrollableSheet(
              initialChildSize: 0.84,
              minChildSize: 0.52,
              maxChildSize: 0.94,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  key: const Key('mobile_menu_hub_sheet'),
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AsterConstants.radiusLarge),
                    ),
                    border: Border.all(
                      color: isDark ? insetCol : Colors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: insetCol,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header do usuário + Ações rápidas
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 14, 10),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _openProfileSettings();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  VipAvatarCircle(
                                    isVip: isVip,
                                    badgeSize: VipBadgeSize.xs,
                                    borderWidth: 2,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: primaryCol.withValues(alpha: 0.16),
                                      backgroundImage: avatarImage,
                                      onBackgroundImageError: avatarImage != null ? (_, _) {} : null,
                                      child: avatarImage == null
                                          ? Text(
                                              initials,
                                              style: GoogleFonts.manrope(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: primaryCol,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.sizeOf(context).width * 0.48,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: textCol,
                                          ),
                                        ),
                                        Text(
                                          rawChannel.isNotEmpty
                                              ? '@$rawChannel · 🔥 ${_currentStreakDays}d'
                                              : '${isVip ? 'VIP' : context.tr('Estudante')} · 🔥 ${_currentStreakDays}d',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: mutedCol,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: context.tr('Editar Perfil'),
                              icon: Icon(Icons.tune_rounded, size: 20, color: mutedCol),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _openProfileSettings();
                              },
                            ),
                            IconButton(
                              tooltip: context.tr('Sair'),
                              icon: const Icon(Icons.logout_rounded, size: 20, color: AsterConstants.coral),
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                SupabaseService.signOut();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Barra de busca rápida de módulos
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: TextField(
                          onChanged: (value) => setSheetState(() => searchQuery = value),
                          style: GoogleFonts.manrope(fontSize: 13, color: textCol),
                          decoration: InputDecoration(
                            hintText: context.tr('Ir para módulo ou ferramenta...'),
                            hintStyle: GoogleFonts.manrope(fontSize: 12.5, color: mutedCol),
                            prefixIcon: Icon(Icons.search_rounded, size: 19, color: mutedCol),
                            isDense: true,
                            filled: true,
                            fillColor: altCol,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              borderSide: BorderSide(color: primaryCol, width: 1.4),
                            ),
                          ),
                        ),
                      ),

                      Divider(height: 1, color: insetCol.withValues(alpha: 0.7)),

                      // Conteúdo rolável: Metas + Categorias em Grid + Discord
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            if (q.isEmpty) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildGoalCard(
                                      key: const Key('mobile_menu_daily_goal_card'),
                                      tooltip: context.tr('Editar meta diária'),
                                      title: context.tr('META DIÁRIA'),
                                      studiedMinutes: _dailyStudiedMinutes,
                                      goalMinutesListenable: SupabaseService.dailyGoalMinutesNotifier,
                                      emptySuffix: context.tr('hoje'),
                                      progressColor: primaryCol,
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.of(sheetContext).pop();
                                        showDailyGoalEditorDialog(
                                          context,
                                          currentWeekStudiedMinutes: _weeklyStudiedMinutes,
                                          currentDayStudiedMinutes: _dailyStudiedMinutes,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildGoalCard(
                                      key: const Key('mobile_menu_weekly_goal_card'),
                                      tooltip: context.tr('Editar meta semanal'),
                                      title: context.tr('META SEMANAL'),
                                      studiedMinutes: _weeklyStudiedMinutes,
                                      goalMinutesListenable: SupabaseService.weeklyGoalMinutesNotifier,
                                      emptySuffix: context.tr('na sem.'),
                                      progressColor: AsterTheme.secondary(context),
                                      isDark: isDark,
                                      onTap: () {
                                        Navigator.of(sheetContext).pop();
                                        showWeeklyGoalEditorDialog(
                                          context,
                                          currentWeekStudiedMinutes: _weeklyStudiedMinutes,
                                          currentDayStudiedMinutes: _dailyStudiedMinutes,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            for (final section in _navSections) ...[
                              Builder(
                                builder: (context) {
                                  final filteredItems = section.items.where((item) {
                                    if (q.isEmpty) return true;
                                    return item.title.toLowerCase().contains(q) ||
                                        context.tr(item.title).toLowerCase().contains(q) ||
                                        item.subtitle.toLowerCase().contains(q) ||
                                        context.tr(item.subtitle).toLowerCase().contains(q) ||
                                        (section.header?.toLowerCase().contains(q) ?? false) ||
                                        (section.header != null &&
                                            context.tr(section.header!).toLowerCase().contains(q));
                                  }).toList();
                                  if (filteredItems.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final accent = _sectionAccentColor(context, section.header);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 9, top: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              section.header != null
                                                  ? context.tr(section.header!)
                                                  : context.tr('PRINCIPAL'),
                                              style: GoogleFonts.manrope(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.0,
                                                color: mutedCol,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: insetCol.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final cols = constraints.maxWidth >= 520 ? 3 : 2;
                                          const spacing = 10.0;
                                          final itemWidth =
                                              (constraints.maxWidth - (spacing * (cols - 1))) / cols;
                                          return Wrap(
                                            spacing: spacing,
                                            runSpacing: spacing,
                                            children: filteredItems.map((entry) {
                                              final isSelected =
                                                  _activeTabNotifier.value == entry.index;
                                              return SizedBox(
                                                width: itemWidth,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    key: Key('mobile_menu_item_${entry.index}'),
                                                    borderRadius: BorderRadius.circular(
                                                      AsterConstants.radiusMedium,
                                                    ),
                                                    onTap: () {
                                                      _activeTabNotifier.value = entry.index;
                                                      _loadedTabs.add(entry.index);
                                                      Navigator.of(sheetContext).pop();
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 160),
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? primaryCol.withValues(
                                                                alpha: isDark ? 0.22 : 0.12,
                                                              )
                                                            : altCol,
                                                        borderRadius: BorderRadius.circular(
                                                          AsterConstants.radiusMedium,
                                                        ),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? primaryCol
                                                              : insetCol.withValues(
                                                                  alpha: isDark ? 0.55 : 0.75,
                                                                ),
                                                          width: isSelected ? 1.5 : 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 34,
                                                            height: 34,
                                                            decoration: BoxDecoration(
                                                              color: isSelected
                                                                  ? primaryCol
                                                                  : accent.withValues(alpha: 0.15),
                                                              borderRadius:
                                                                  BorderRadius.circular(11),
                                                            ),
                                                            child: Icon(
                                                              entry.icon,
                                                              size: 18,
                                                              color: isSelected
                                                                  ? AsterTheme.onPrimary(context)
                                                                  : accent,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text(
                                                                  context.tr(entry.title),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: GoogleFonts.manrope(
                                                                    fontSize: 12.5,
                                                                    fontWeight: FontWeight.w800,
                                                                    color: isSelected
                                                                        ? primaryCol
                                                                        : textCol,
                                                                  ),
                                                                ),
                                                                if (entry.subtitle.isNotEmpty)
                                                                  Text(
                                                                    context.tr(entry.subtitle),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: GoogleFonts.manrope(
                                                                      fontSize: 10.5,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: mutedCol,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  );
                                },
                              ),
                            ],

                            // Comunidade Discord Aster
                            if (q.isEmpty)
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF5865F2), Color(0xFF4752C4)],
                                  ),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5865F2).withValues(alpha: 0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    onTap: () {
                                      Navigator.of(sheetContext).pop();
                                      _openDiscordUrl();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(9),
                                            ),
                                            child: const Center(
                                              child: DiscordLogoWidget(size: 16),
                                            ),
                                          ),
                                          const SizedBox(width: 11),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context.tr('Entrar no Discord'),
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  context.tr('Comunidade oficial Aster'),
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 11,
                                                    color: Colors.white.withValues(alpha: 0.82),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: _activeTabNotifier,
      builder: (context, activeIndex, _) {
        final cs = Theme.of(context).colorScheme;
        final isSelected = activeIndex == index;

        return Container(
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            boxShadow: isSelected ? AsterTheme.primaryShadow(context) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _activeTabNotifier.value = index;
                _loadedTabs.add(index);
              },
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.2),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileNavItem(
    int index,
    IconData icon,
    String label, {
    required int activeIndex,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = activeIndex == index;

    return GestureDetector(
      onTap: () {
        _activeTabNotifier.value = index;
        _loadedTabs.add(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMenuNavButton({
    required bool isActive,
    required int activeIndex,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final activeEntry = isActive ? _findNavEntry(activeIndex).entry : null;
    final label = activeEntry != null
        ? context.tr(activeEntry.shortTitle ?? activeEntry.title)
        : context.tr('Menu');

    return GestureDetector(
      key: const Key('mobile_menu_button'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? cs.primary.withValues(alpha: 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive && activeEntry != null
                      ? activeEntry.icon
                      : Icons.grid_view_rounded,
                  size: 21,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
                if (isActive)
                  PositionedDirectional(
                    top: -1,
                    end: -4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
