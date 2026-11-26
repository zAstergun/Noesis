import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/shop_service.dart';
import '../../../core/supabase_service.dart';
import '../../quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../quizzes/data/saved_exams_store_web.dart' as local_store;
import '../models/ranking_league_model.dart';

class RankingService {
  RankingService._();
  static final RankingService instance = RankingService._();

  static const String _storageKey = 'noesis_ranking_state_v1';
  static const int _bracketSize = 12;

  static DateTime Function() _clock = DateTime.now;
  static DateTime currentNow() => _clock();

  @visibleForTesting
  static set clockForTesting(DateTime Function() fn) => _clock = fn;

  @visibleForTesting
  static bool allowSyntheticPeersForTesting = false;

  final ValueNotifier<RankingBoardState> boardNotifier = ValueNotifier<RankingBoardState>(
    RankingBoardState(
      weekId: weekIdForDate(DateTime.now()),
      weekEndsAt: weekEndForDate(DateTime.now()),
      currentEloIndex: 0,
      bestEloIndex: 0,
      top3Finishes: 0,
      weeksCompeted: 0,
      standings: const [],
      currentUserRank: 1,
      currentUserZone: RankingZone.safe,
      currentUserWeeklyInsights: 0,
      isLoading: true,
    ),
  );

  bool _loaded = false;
  bool _listeningShop = false;
  int _currentEloIndex = 0;
  int _bestEloIndex = 0;
  int _top3Finishes = 0;
  int _weeksCompeted = 0;
  int _retentionStreakWeeks = 0;
  int _accumulatedRankingScore = 0;
  String _activeWeekId = '';
  int _storedWeekInsights = 0;
  int _storedWeekMinutes = 0;
  int _storedStreakDays = 0;
  RankingWeekOutcome? _lastOutcome;

  static String weekIdForDate(DateTime dt) {
    final day = DateTime(dt.year, dt.month, dt.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime weekEndForDate(DateTime dt) {
    final day = DateTime(dt.year, dt.month, dt.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  static RankingZone zoneForRank(
    int rank, {
    required int total,
    required RankingEloTier tier,
  }) {
    if (tier.promotionSlots > 0 && rank <= tier.promotionSlots) {
      return RankingZone.promotion;
    }
    if (tier.demotionSlots > 0 &&
        total > tier.promotionSlots + tier.demotionSlots &&
        rank > total - tier.demotionSlots) {
      return RankingZone.demotion;
    }
    return RankingZone.safe;
  }

  void _ensureListeners() {
    if (_listeningShop) return;
    _listeningShop = true;
    ShopService.instance.transactionsNotifier.addListener(_onUpstreamChanged);
    SupabaseService.userProfileNotifier.addListener(_onUpstreamChanged);
  }

  void _onUpstreamChanged() {
    if (_loaded) {
      unawaited(syncCurrentUserProgress());
    }
  }

  Future<void> init({bool force = false, DateTime? referenceDate}) async {
    _ensureListeners();
    if (_loaded && !force) return;
    _loaded = true;

    final now = referenceDate ?? _clock();
    _activeWeekId = weekIdForDate(now);

    try {
      final raw = await local_store.readSavedExamsRaw(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _currentEloIndex = ((decoded['current_elo_index'] as num?)?.toInt() ?? 0)
              .clamp(0, RankingEloCatalog.tiers.length - 1);
          _bestEloIndex = ((decoded['best_elo_index'] as num?)?.toInt() ?? _currentEloIndex)
              .clamp(0, RankingEloCatalog.tiers.length - 1);
          _top3Finishes = (decoded['top3_finishes'] as num?)?.toInt() ?? 0;
          _weeksCompeted = (decoded['weeks_competed'] as num?)?.toInt() ?? 0;
          _retentionStreakWeeks = (decoded['retention_streak_weeks'] as num?)?.toInt() ?? 0;
          _accumulatedRankingScore = (decoded['accumulated_ranking_score'] as num?)?.toInt() ?? 0;
          final savedWeek = (decoded['active_week_id'] ?? '').toString().trim();
          if (savedWeek.isNotEmpty) {
            _activeWeekId = savedWeek;
          }
          _storedWeekInsights = (decoded['stored_week_insights'] as num?)?.toInt() ?? 0;
          _storedWeekMinutes = (decoded['stored_week_minutes'] as num?)?.toInt() ?? 0;
          _storedStreakDays = (decoded['stored_streak_days'] as num?)?.toInt() ?? 0;
          if (decoded['last_outcome'] is Map) {
            _lastOutcome = RankingWeekOutcome.fromJson(
              Map<String, dynamic>.from(decoded['last_outcome'] as Map),
            );
          }
        }
      }
    } catch (_) {}

    await syncCurrentUserProgress(referenceDate: now);
  }

  Future<void> syncCurrentUserProgress({DateTime? referenceDate}) async {
    final now = referenceDate ?? _clock();
    await ShopService.instance.init();
    final currentWeekId = weekIdForDate(now);

    // Resolve virada semanal de elo se uma semana anterior ficou aberta
    if (_activeWeekId.isNotEmpty && _activeWeekId != currentWeekId) {
      await _resolveClosedWeek(_activeWeekId, nextWeekId: currentWeekId);
    }
    _activeWeekId = currentWeekId;

    final profile = SupabaseService.userProfileNotifier.value ??
        await SupabaseService.loadFullProfile();
    final sessions = await SupabaseService.getStudySessions(limit: 200);

    final weeklyInsights = ShopService.instance.weeklyEarnedInsightsAt(now);
    final weeklyMinutes =
        SupabaseService.computeCurrentWeekStudiedMinutes(sessions, referenceDate: now);
    final streakDays = SupabaseService.computeCurrentStreakDays(
      sessions,
      referenceDate: now,
      protectedDates: ShopService.instance.protectedStreakDates,
    );

    _storedWeekInsights = weeklyInsights;
    _storedWeekMinutes = weeklyMinutes;
    _storedStreakDays = streakDays;

    final currentUid = SupabaseService.currentUser?.id ?? 'local_user';
    final displayName = (profile?['full_name'] ?? 'Estudante').toString().trim();
    final username = SupabaseService.sanitizeUsername(
      (profile?['channel'] ?? 'estudante').toString(),
    );
    final avatarUrl = profile?['avatar_url']?.toString();
    final bio = profile?['bio']?.toString();
    final isVip = SupabaseService.isCurrentUserVip;

    final currentCompetitor = RankingCompetitor(
      userId: currentUid,
      username: username.isEmpty ? 'estudante' : username,
      displayName: displayName.isEmpty ? 'Estudante' : displayName,
      avatarUrl: avatarUrl,
      bio: bio,
      isVip: isVip,
      isCurrentUser: true,
      eloIndex: _currentEloIndex,
      weeklyInsights: weeklyInsights,
      weeklyMinutes: weeklyMinutes,
      streakDays: streakDays,
    );

    final remoteCompetitors = await _loadRemoteCompetitors(
      weekId: currentWeekId,
      eloIndex: _currentEloIndex,
      excludeUserId: currentUid,
    );

    final standings = _assembleLeagueBracket(
      weekId: currentWeekId,
      eloIndex: _currentEloIndex,
      currentUser: currentCompetitor,
      remoteCompetitors: remoteCompetitors,
    );

    final rankIdx = standings.indexWhere((c) => c.isCurrentUser);
    final rank = rankIdx == -1 ? 1 : rankIdx + 1;
    final tier = RankingEloCatalog.tierAt(_currentEloIndex);
    final zone = zoneForRank(rank, total: standings.length, tier: tier);
    ShopService.instance.setCurrentEloIndex(_currentEloIndex);

    boardNotifier.value = RankingBoardState(
      weekId: currentWeekId,
      weekEndsAt: weekEndForDate(now),
      currentEloIndex: _currentEloIndex,
      bestEloIndex: _bestEloIndex,
      top3Finishes: _top3Finishes,
      weeksCompeted: _weeksCompeted,
      standings: standings,
      currentUserRank: rank,
      currentUserZone: zone,
      currentUserWeeklyInsights: weeklyInsights,
      retentionStreakWeeks: _retentionStreakWeeks,
      accumulatedRankingScore: _accumulatedRankingScore,
      lastOutcome: _lastOutcome,
      isLoading: false,
    );

    await _persist(profile: profile);
  }

  Future<void> _resolveClosedWeek(
    String closedWeekId, {
    required String nextWeekId,
  }) async {
    final prevElo = _currentEloIndex;
    final tier = RankingEloCatalog.tierAt(prevElo);
    final uid = SupabaseService.currentUser?.id ?? 'local_user';
    final snapshotUser = RankingCompetitor(
      userId: uid,
      username: 'estudante',
      displayName: 'Você',
      isCurrentUser: true,
      eloIndex: prevElo,
      weeklyInsights: _storedWeekInsights,
      weeklyMinutes: _storedWeekMinutes,
      streakDays: _storedStreakDays,
    );

    final bracket = _assembleLeagueBracket(
      weekId: closedWeekId,
      eloIndex: prevElo,
      currentUser: snapshotUser,
      remoteCompetitors: const [],
    );

    final idx = bracket.indexWhere((c) => c.isCurrentUser);
    final finalRank = idx == -1 ? bracket.length : idx + 1;
    final zone = zoneForRank(finalRank, total: bracket.length, tier: tier);

    int nextElo = prevElo;
    if (zone == RankingZone.promotion && prevElo < RankingEloCatalog.tiers.length - 1) {
      nextElo = prevElo + 1;
    } else if (zone == RankingZone.demotion && prevElo > 0) {
      nextElo = prevElo - 1;
    }

    int rewardInsights = 0;
    int pointsEarned = 0;

    if (nextElo > prevElo) {
      // Promoção: recompensa em Insights proporcional à colocação (#1..#5) + pontuação de subida
      rewardInsights = RankingEloCatalog.promotionRewardInsights(
        finalRank: finalRank,
        targetEloIndex: nextElo,
      );
      pointsEarned = RankingEloCatalog.promotionRankingPoints(
        finalRank: finalRank,
        targetEloIndex: nextElo,
      );
      _accumulatedRankingScore += pointsEarned;
      final nextTierName = RankingEloCatalog.tierAt(nextElo).name;
      ShopService.instance.awardForRankingReward(
        idempotentId: 'ranking_promo_${closedWeekId}_elo_$nextElo',
        amount: rewardInsights,
        description: 'Promoção no Ranking (#$finalRank) · Elo $nextTierName',
      );
    } else if (nextElo == prevElo &&
        zone != RankingZone.demotion &&
        _storedWeekInsights > 0) {
      // Permanência: pontuações e bônus que se acumulam quanto mais semanas seguidas o estudante se mantém!
      _retentionStreakWeeks++;
      pointsEarned = RankingEloCatalog.maintenancePointsForStreak(
        streakWeeks: _retentionStreakWeeks,
        eloIndex: prevElo,
      );
      rewardInsights = RankingEloCatalog.maintenanceInsightsForStreak(
        streakWeeks: _retentionStreakWeeks,
        eloIndex: prevElo,
      );
      _accumulatedRankingScore += pointsEarned;
      ShopService.instance.awardForRankingReward(
        idempotentId: 'ranking_retention_${closedWeekId}_s$_retentionStreakWeeks',
        amount: rewardInsights,
        description:
            'Permanência no Ranking ($_retentionStreakWeeksª sem. seguida) · Elo ${tier.name}',
      );
    } else if (nextElo < prevElo) {
      // Rebaixamento reinicia a sequência consecutiva de permanência, preservando o acumulado já ganho
      _retentionStreakWeeks = 0;
    }

    _currentEloIndex = nextElo;
    ShopService.instance.setCurrentEloIndex(_currentEloIndex);
    if (nextElo > _bestEloIndex) {
      _bestEloIndex = nextElo;
    }
    if (finalRank <= 3) {
      _top3Finishes++;
    }
    _weeksCompeted++;
    _activeWeekId = nextWeekId;
    _lastOutcome = RankingWeekOutcome(
      weekId: closedWeekId,
      previousEloIndex: prevElo,
      newEloIndex: nextElo,
      finalRank: finalRank,
      weeklyInsights: _storedWeekInsights,
      rewardInsights: rewardInsights,
      pointsEarned: pointsEarned,
      retentionStreakWeeks: _retentionStreakWeeks,
    );
    _storedWeekInsights = 0;
  }

  Future<void> dismissLastOutcome() async {
    _lastOutcome = null;
    boardNotifier.value = boardNotifier.value.copyWith(clearOutcome: true);
    await _persist();
  }

  Future<List<RankingCompetitor>> _loadRemoteCompetitors({
    required String weekId,
    required int eloIndex,
    required String excludeUserId,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return const [];
    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, channel, avatar_url, bio, is_vip, stats')
          .limit(80);
      final list = <RankingCompetitor>[];
      for (final raw in (rows as List)) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = (map['id'] ?? '').toString();
        if (id.isEmpty || id == excludeUserId) continue;
        final stats = map['stats'] is Map
            ? Map<String, dynamic>.from(map['stats'] as Map)
            : const <String, dynamic>{};
        final remoteWeek = (stats['noesis_ranking_week_id'] ?? '').toString();
        final remoteElo = (stats['noesis_ranking_elo_index'] as num?)?.toInt() ?? 0;
        final remoteInsights = (stats['noesis_ranking_weekly_insights'] as num?)?.toInt() ?? 0;
        if (remoteWeek != weekId || remoteElo != eloIndex) continue;

        list.add(
          RankingCompetitor(
            userId: id,
            username: SupabaseService.sanitizeUsername((map['channel'] ?? 'estudante').toString()),
            displayName: (map['full_name'] ?? 'Estudante').toString(),
            avatarUrl: map['avatar_url']?.toString(),
            bio: map['bio']?.toString(),
            isVip: map['is_vip'] == true,
            eloIndex: remoteElo,
            weeklyInsights: remoteInsights,
            weeklyMinutes: (stats['noesis_ranking_weekly_minutes'] as num?)?.toInt() ?? 0,
            streakDays: (stats['noesis_ranking_streak_days'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  List<RankingCompetitor> _assembleLeagueBracket({
    required String weekId,
    required int eloIndex,
    required RankingCompetitor currentUser,
    required List<RankingCompetitor> remoteCompetitors,
  }) {
    final byId = <String, RankingCompetitor>{
      currentUser.userId: currentUser,
    };
    for (final c in remoteCompetitors) {
      byId.putIfAbsent(c.userId, () => c);
    }

    if (allowSyntheticPeersForTesting && byId.length < _bracketSize) {
      final bots = _generateActiveLeaguePeers(
        weekId: weekId,
        eloIndex: eloIndex,
        needed: _bracketSize - byId.length,
        excludeUserId: currentUser.userId,
      );
      for (final b in bots) {
        byId.putIfAbsent(b.userId, () => b);
      }
    }

    final sorted = byId.values.toList()
      ..sort((a, b) {
        final cmpInsights = b.weeklyInsights.compareTo(a.weeklyInsights);
        if (cmpInsights != 0) return cmpInsights;
        final cmpMins = b.weeklyMinutes.compareTo(a.weeklyMinutes);
        if (cmpMins != 0) return cmpMins;
        final cmpStreak = b.streakDays.compareTo(a.streakDays);
        if (cmpStreak != 0) return cmpStreak;
        if (a.isCurrentUser != b.isCurrentUser) return a.isCurrentUser ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
    return sorted;
  }

  /// Gera concorrentes ativos determinísticos na mesma chave semanal e elo
  /// quando não há usuários suficientes na tabela remota ou no modo visitante.
  List<RankingCompetitor> _generateActiveLeaguePeers({
    required String weekId,
    required int eloIndex,
    required int needed,
    required String excludeUserId,
  }) {
    const profiles = [
      (handle: 'camila_sec', name: 'Camila Rocha', bio: 'Foco em Security+ e redes.', vip: true),
      (handle: 'lucas_dev', name: 'Lucas Mendes', bio: 'Resolvendo simulados diários.', vip: false),
      (handle: 'mariana_med', name: 'Mariana Alves', bio: 'Flashcards de revisão espaçada.', vip: true),
      (handle: 'rafael_cloud', name: 'Rafael Costa', bio: 'Arquitetura Cloud e Linux.', vip: false),
      (handle: 'beatriz_law', name: 'Beatriz Nunes', bio: 'Consistência acima de tudo.', vip: false),
      (handle: 'pedro_ita', name: 'Pedro Henrique', bio: 'Trilhas intensivas de cálculo.', vip: true),
      (handle: 'julia_ux', name: 'Júlia Martins', bio: 'Anotações organizadas por caderno.', vip: false),
      (handle: 'thiago_net', name: 'Thiago Ribeiro', bio: 'Estudando protocolos TCP/IP.', vip: false),
      (handle: 'larissa_bio', name: 'Larissa Gomes', bio: 'Meta diária firme todo dia.', vip: false),
      (handle: 'bruno_data', name: 'Bruno Souza', bio: 'Banco de dados e estatística.', vip: true),
      (handle: 'fernanda_en', name: 'Fernanda Lima', bio: 'Prática ativa de idiomas.', vip: false),
    ];

    final baseForElo = 60 + eloIndex * 95;
    final weekSeed = weekId.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
    final peers = <RankingCompetitor>[];

    for (int i = 0; i < profiles.length && peers.length < needed; i++) {
      final idx = (i + (weekSeed % profiles.length)) % profiles.length;
      final p = profiles[idx];
      final id = 'league_${eloIndex}_${p.handle}';
      if (id == excludeUserId) continue;

      final tierSpread = (profiles.length - i) * (28 + eloIndex * 10);
      final jitter = ((weekSeed >> (i % 8)) % 19) - 9;
      final insights = (baseForElo + tierSpread + jitter).clamp(20, 4500);
      final minutes = (insights * 0.75).round().clamp(30, 1800);
      final streak = ((profiles.length - i) + eloIndex).clamp(1, 45);

      peers.add(
        RankingCompetitor(
          userId: id,
          username: p.handle,
          displayName: p.name,
          bio: p.bio,
          isVip: p.vip,
          eloIndex: eloIndex,
          weeklyInsights: insights,
          weeklyMinutes: minutes,
          streakDays: streak,
        ),
      );
    }
    return peers;
  }

  Future<void> _persist({Map<String, dynamic>? profile}) async {
    try {
      await local_store.writeSavedExamsRaw(
        _storageKey,
        jsonEncode({
          'current_elo_index': _currentEloIndex,
          'best_elo_index': _bestEloIndex,
          'top3_finishes': _top3Finishes,
          'weeks_competed': _weeksCompeted,
          'retention_streak_weeks': _retentionStreakWeeks,
          'accumulated_ranking_score': _accumulatedRankingScore,
          'active_week_id': _activeWeekId,
          'stored_week_insights': _storedWeekInsights,
          'stored_week_minutes': _storedWeekMinutes,
          'stored_streak_days': _storedStreakDays,
          if (_lastOutcome != null) 'last_outcome': _lastOutcome!.toJson(),
        }),
      );
    } catch (_) {}

    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        final loadedProfile = profile ?? await SupabaseService.getProfile();
        final currentStats = loadedProfile?['stats'] is Map
            ? Map<String, dynamic>.from(loadedProfile!['stats'] as Map)
            : <String, dynamic>{};
        currentStats['noesis_ranking_elo_index'] = _currentEloIndex;
        currentStats['noesis_ranking_weekly_insights'] = _storedWeekInsights;
        currentStats['noesis_ranking_week_id'] = _activeWeekId;
        currentStats['noesis_ranking_weekly_minutes'] = _storedWeekMinutes;
        currentStats['noesis_ranking_streak_days'] = _storedStreakDays;
        currentStats['noesis_ranking_retention_streak'] = _retentionStreakWeeks;
        currentStats['noesis_ranking_accumulated_score'] = _accumulatedRankingScore;
        await SupabaseService.client
            .from('profiles')
            .update({
              'stats': currentStats,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      } catch (_) {}
    }
  }

  @visibleForTesting
  Future<void> resetForTesting({
    int currentEloIndex = 0,
    int bestEloIndex = 0,
    int top3Finishes = 0,
    int weeksCompeted = 0,
    int retentionStreakWeeks = 0,
    int accumulatedRankingScore = 0,
    String? activeWeekId,
    int storedWeekInsights = 0,
    RankingWeekOutcome? lastOutcome,
    DateTime Function()? customClock,
  }) async {
    _clock = customClock ?? DateTime.now;
    _loaded = true;
    _currentEloIndex = currentEloIndex.clamp(0, RankingEloCatalog.tiers.length - 1);
    ShopService.instance.setCurrentEloIndex(_currentEloIndex);
    _bestEloIndex = bestEloIndex.clamp(_currentEloIndex, RankingEloCatalog.tiers.length - 1);
    _top3Finishes = top3Finishes;
    _weeksCompeted = weeksCompeted;
    _retentionStreakWeeks = retentionStreakWeeks;
    _accumulatedRankingScore = accumulatedRankingScore;
    _activeWeekId = activeWeekId ?? weekIdForDate(_clock());
    _storedWeekInsights = storedWeekInsights;
    _storedWeekMinutes = 0;
    _storedStreakDays = 0;
    _lastOutcome = lastOutcome;
    await _persist();
    await syncCurrentUserProgress(referenceDate: _clock());
  }
}
