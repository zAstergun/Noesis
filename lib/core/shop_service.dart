import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../features/profile/models/profile_cosmetics.dart';
import '../features/quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../features/quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../features/quizzes/data/saved_exams_store_web.dart' as local_store;
import 'insights_economy_config.dart';
import 'supabase_service.dart';
import 'theme.dart';

class ShopTransaction {
  final String id;
  final int amount; // positivo = ganho, negativo = gasto
  final String description;
  final String source;
  final String reference;
  final DateTime createdAt;

  const ShopTransaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.source,
    required this.reference,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'description': description,
        'source': source,
        'reference': reference,
        'created_at': createdAt.toIso8601String(),
      };

  factory ShopTransaction.fromJson(Map<String, dynamic> json) => ShopTransaction(
        id: (json['id'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        description: (json['description'] ?? '').toString(),
        source: (json['source'] ?? 'study').toString(),
        reference: (json['reference'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

class ShopPurchaseResult {
  final bool ok;
  final String? message;
  final String? error;

  const ShopPurchaseResult({
    required this.ok,
    this.message,
    this.error,
  });
}

/// Evento emitido em tempo real sempre que o estudante conquista Insights.
class InsightGainEvent {
  final String id;
  final int amount;
  final String reason;
  final String source;
  final bool isVipBoosted;
  final DateTime createdAt;

  const InsightGainEvent({
    required this.id,
    required this.amount,
    required this.reason,
    required this.source,
    required this.isVipBoosted,
    required this.createdAt,
  });
}

/// Serviço central da Economia de Insights: livro de transações (ledger),
/// regras anti-abuso v1, loja de temas e compra idempotente.
class ShopService {
  ShopService._();
  static final ShopService instance = ShopService._();

  // Atalhos const centralizados apontando para InsightsEconomyConfig
  static const String currencyName = InsightsEconomyConfig.currencyName;
  static const String currencySingular = InsightsEconomyConfig.currencySingular;
  static const String currencySymbol = InsightsEconomyConfig.currencySymbol;

  static const String storageKey = 'noesis_insights_ledger_v1';
  static const String _legacyStorageKey = 'noesis_shop_wallet_v1';
  static const String defaultFreeThemeId = 'soft_clay_nevoa';

  static DateTime Function() _clock = DateTime.now;
  static DateTime currentNow() => _clock();

  /// Relógio injetável para testes unitários/widget (tempo mínimo, teto diário).
  @visibleForTesting
  static set clockForTesting(DateTime Function() fn) => _clock = fn;

  final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Set<String>> unlockedThemesNotifier =
      ValueNotifier<Set<String>>({defaultFreeThemeId});
  final ValueNotifier<List<ShopTransaction>> transactionsNotifier =
      ValueNotifier<List<ShopTransaction>>(const []);
  final ValueNotifier<int> streakProtectorsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Set<String>> unlockedProfileItemsNotifier = ValueNotifier<Set<String>>({
    ProfileCosmeticsCatalog.defaultBannerId,
    ProfileCosmeticsCatalog.defaultFrameId,
    ProfileCosmeticsCatalog.defaultTitleId,
  });
  final ValueNotifier<String?> equippedBannerIdNotifier =
      ValueNotifier<String?>(ProfileCosmeticsCatalog.defaultBannerId);
  final ValueNotifier<String?> equippedFrameIdNotifier =
      ValueNotifier<String?>(ProfileCosmeticsCatalog.defaultFrameId);
  final ValueNotifier<String?> equippedTitleIdNotifier =
      ValueNotifier<String?>(ProfileCosmeticsCatalog.defaultTitleId);
  final ValueNotifier<Set<String>> claimedAchievementsNotifier =
      ValueNotifier<Set<String>>(const {});
  final ValueNotifier<InsightGainEvent?> latestGainNotifier =
      ValueNotifier<InsightGainEvent?>(null);

  final List<ShopTransaction> _ledger = [];
  final Set<String> _pendingHardCardIds = {};
  final Set<String> _purchasingThemeIds = {};
  final Set<DateTime> _protectedStreakDates = {};
  int _softCapHalfCarry = 0; // resto de 0,5 Insight em unidades inteiras de meios-pontos
  int _totalQuizQuestionsAnswered = 0;
  bool _loaded = false;
  bool _listeningVip = false;
  int _resetEpoch = 0;

  void _ensureVipListener() {
    if (_listeningVip) return;
    _listeningVip = true;
    SupabaseService.isVipNotifier.addListener(_onVipStatusChanged);
  }

  void _onVipStatusChanged() {
    if (SupabaseService.isCurrentUserVip && _loaded) {
      unawaited(grantMonthlyVipStreakProtectorsIfEligible());
    }
  }

  int get balance => balanceNotifier.value;
  Set<String> get unlockedThemes => unlockedThemesNotifier.value;
  List<ShopTransaction> get ledger => List<ShopTransaction>.unmodifiable(_ledger);
  int get streakProtectors => streakProtectorsNotifier.value;
  int get maxStreakProtectors =>
      InsightsEconomyConfig.maxStreakProtectorsForVip(SupabaseService.isCurrentUserVip);
  int get totalQuizQuestionsAnswered => _totalQuizQuestionsAnswered;
  int get questionsTowardNextFreeProtector =>
      _totalQuizQuestionsAnswered % InsightsEconomyConfig.questionsPerFreeStreakProtector;

  int get monthlyFreeVipProtectorsReceivedThisMonth {
    final now = _clock();
    final prefix =
        'vip_monthly_protector:${now.year}-${now.month.toString().padLeft(2, '0')}:';
    return _ledger.where((tx) => tx.id.startsWith(prefix)).length;
  }

  Set<DateTime> get protectedStreakDates => Set<DateTime>.unmodifiable(_protectedStreakDates);

  int priceForTheme(String themeId) => InsightsEconomyConfig.priceForTheme(themeId);

  ThemePriceTier tierForTheme(String themeId) => InsightsEconomyConfig.tierForTheme(themeId);

  bool isThemeUnlocked(String themeId) {
    if (themeId == defaultFreeThemeId) return true;
    if (themeId == AsterTheme.customThemeId) {
      return SupabaseService.isCurrentUserVip;
    }
    return unlockedThemesNotifier.value.contains(themeId);
  }

  bool get hasWelcomeBonus =>
      _ledger.any((tx) => tx.id == 'welcome_bonus' || tx.source == 'welcome');

  /// Soma de Insights de estudo ganhos hoje (exclui bônus único de boas-vindas e prêmios do ranking).
  int get todayEarnedInsights {
    final now = _clock();
    int total = 0;
    for (final tx in _ledger) {
      if (tx.amount <= 0) continue;
      if (tx.source == 'welcome' ||
          tx.source == 'ranking_reward' ||
          tx.source == 'achievement') {
        continue;
      }
      if (tx.createdAt.year == now.year &&
          tx.createdAt.month == now.month &&
          tx.createdAt.day == now.day) {
        total += tx.amount;
      }
    }
    return total;
  }

  /// Soma de Insights conquistados na semana atual (segunda 00:00 até agora),
  /// excluindo bônus inicial de boas-vindas, prêmios semanais de fechamento e descontos na Loja.
  int get weeklyEarnedInsights => weeklyEarnedInsightsAt(_clock());

  int weeklyEarnedInsightsAt(DateTime referenceDate) {
    final today = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sundayEnd = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    int total = 0;
    for (final tx in _ledger) {
      if (tx.amount <= 0) continue;
      if (tx.source == 'welcome' ||
          tx.source == 'ranking_reward' ||
          tx.source == 'achievement') {
        continue;
      }
      if (!tx.createdAt.isBefore(monday) && !tx.createdAt.isAfter(sundayEnd)) {
        total += tx.amount;
      }
    }
    return total;
  }

  /// Concede Insights diretamente na carteira por conquistas de fechamento semanal do Ranking
  /// (subida de elo proporcional à colocação ou bônus acumulativo de permanência), sem inflar
  /// o placar competitivo da nova semana.
  int awardForRankingReward({
    required String idempotentId,
    required int amount,
    required String description,
    String reference = 'ranking_league',
  }) {
    if (amount <= 0) return 0;
    if (_ledger.any((tx) => tx.id == idempotentId)) return 0;

    final tx = ShopTransaction(
      id: idempotentId,
      amount: amount,
      description: description,
      source: 'ranking_reward',
      reference: reference,
      createdAt: _clock(),
    );
    _ledger.add(tx);
    _recomputeFromLedger();
    latestGainNotifier.value = InsightGainEvent(
      id: tx.id,
      amount: amount,
      reason: description,
      source: 'ranking_reward',
      isVipBoosted: false,
      createdAt: tx.createdAt,
    );
    unawaited(_persist());
    unawaited(_syncLedgerEntryIfAuthenticated(tx));
    return amount;
  }

  /// Concede Insights diretamente na carteira pelo resgate único de uma Conquista da conta,
  /// sem inflar o placar semanal competitivo do Ranking.
  int claimAchievementReward({
    required String achievementId,
    required String title,
    required int amount,
  }) {
    if (amount <= 0) return 0;
    final txId = 'achievement:$achievementId';
    if (_ledger.any((tx) => tx.id == txId)) return 0;

    final tx = ShopTransaction(
      id: txId,
      amount: amount,
      description: 'Conquista: $title',
      source: 'achievement',
      reference: txId,
      createdAt: _clock(),
    );
    _ledger.add(tx);
    _recomputeFromLedger();
    latestGainNotifier.value = InsightGainEvent(
      id: tx.id,
      amount: amount,
      reason: 'Conquista desbloqueada: $title',
      source: 'achievement',
      isVipBoosted: false,
      createdAt: tx.createdAt,
    );
    unawaited(_persist());
    unawaited(_syncLedgerEntryIfAuthenticated(tx));
    return amount;
  }

  bool isAchievementClaimed(String achievementId) =>
      claimedAchievementsNotifier.value.contains(achievementId);

  /// Recalcula saldo, temas desbloqueados e protetores de ofensiva a partir do livro de transações.
  void _recomputeFromLedger() {
    int sum = 0;
    int purchasedProtectors = 0;
    final unlocked = <String>{defaultFreeThemeId};
    final unlockedProfile = <String>{
      ProfileCosmeticsCatalog.defaultBannerId,
      ProfileCosmeticsCatalog.defaultFrameId,
      ProfileCosmeticsCatalog.defaultTitleId,
    };
    final claimedAch = <String>{};
    for (final tx in _ledger) {
      sum += tx.amount;
      if (tx.source == 'purchase' && tx.reference.startsWith('theme:')) {
        final themeId = tx.reference.substring('theme:'.length).trim();
        if (themeId.isNotEmpty) unlocked.add(themeId);
      } else if (tx.source == 'purchase' && tx.reference.startsWith('profile_item:')) {
        final itemId = tx.reference.substring('profile_item:'.length).trim();
        if (itemId.isNotEmpty) unlockedProfile.add(itemId);
      } else if (tx.source == 'purchase' && tx.reference == 'streak_protector') {
        purchasedProtectors++;
      } else if (tx.source == 'achievement' && tx.reference.startsWith('achievement:')) {
        final achId = tx.reference.substring('achievement:'.length).trim();
        if (achId.isNotEmpty) claimedAch.add(achId);
      }
    }
    balanceNotifier.value = sum < 0 ? 0 : sum;
    unlockedThemesNotifier.value = unlocked;
    unlockedProfileItemsNotifier.value = unlockedProfile;
    claimedAchievementsNotifier.value = claimedAch;
    final remainingProtectors = purchasedProtectors - _protectedStreakDates.length;
    streakProtectorsNotifier.value = remainingProtectors < 0 ? 0 : remainingProtectors;

    final sorted = List<ShopTransaction>.from(_ledger)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    transactionsNotifier.value = sorted;
  }

  Future<void> init({bool force = false}) async {
    _ensureVipListener();
    if (_loaded && !force) return;
    _loaded = true;
    _ledger.clear();
    _pendingHardCardIds.clear();
    _protectedStreakDates.clear();
    _softCapHalfCarry = 0;
    _totalQuizQuestionsAnswered = 0;

    try {
      String? raw = await local_store.readSavedExamsRaw(storageKey);
      if (raw == null || raw.trim().isEmpty) {
        raw = await local_store.readSavedExamsRaw(_legacyStorageKey);
      }

      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final rawEntries = (map['ledger'] as List?) ?? (map['transactions'] as List?) ?? const [];
          for (final item in rawEntries) {
            if (item is Map) {
              final tx = ShopTransaction.fromJson(Map<String, dynamic>.from(item));
              if (tx.id.isNotEmpty && !_ledger.any((e) => e.id == tx.id)) {
                _ledger.add(tx);
              }
            }
          }
          final hardIds = (map['pending_hard_cards'] as List?) ?? const [];
          for (final id in hardIds) {
            final clean = id.toString().trim();
            if (clean.isNotEmpty) _pendingHardCardIds.add(clean);
          }
          final protectedRaw = (map['protected_streak_dates'] as List?) ?? const [];
          for (final rawDate in protectedRaw) {
            final parsed = DateTime.tryParse(rawDate.toString().trim());
            if (parsed != null) {
              _protectedStreakDates.add(DateTime(parsed.year, parsed.month, parsed.day));
            }
          }
          _softCapHalfCarry = (map['soft_cap_half_carry'] as num?)?.toInt() ?? 0;
          _totalQuizQuestionsAnswered =
              (map['total_quiz_questions_answered'] as num?)?.toInt() ?? 0;
          final savedBanner = (map['equipped_banner_id'] ?? '').toString().trim();
          final savedFrame = (map['equipped_frame_id'] ?? '').toString().trim();
          final savedTitle = (map['equipped_title_id'] ?? '').toString().trim();
          if (savedBanner.isNotEmpty) equippedBannerIdNotifier.value = savedBanner;
          if (savedFrame.isNotEmpty) equippedFrameIdNotifier.value = savedFrame;
          if (savedTitle.isNotEmpty) equippedTitleIdNotifier.value = savedTitle;

          // Migra temas desbloqueados legados sem entrada de compra no ledger
          final legacyThemes = (map['unlocked_themes'] as List?) ?? const [];
          for (final t in legacyThemes) {
            final themeId = t.toString().trim();
            if (themeId.isEmpty || themeId == defaultFreeThemeId) continue;
            final ref = 'theme:$themeId';
            if (!_ledger.any((e) => e.source == 'purchase' && e.reference == ref)) {
              _ledger.add(
                ShopTransaction(
                  id: 'purchase:$ref',
                  amount: 0,
                  description: 'Tema desbloqueado ($themeId)',
                  source: 'purchase',
                  reference: ref,
                  createdAt: _clock(),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // Concede bônus de boas-vindas (+100 ✦) na primeira inicialização da carteira
    await _ensureWelcomeBonus();
    final ledgerQuizCount = _ledger.where((tx) => tx.source == 'quiz_question').length;
    if (ledgerQuizCount > _totalQuizQuestionsAnswered) {
      _totalQuizQuestionsAnswered = ledgerQuizCount;
    }
    _recomputeFromLedger();
    await _grantMonthlyVipStreakProtectorsInternal();
    await _persist();
  }

  bool _grantFreeStreakProtector({
    required String id,
    required String description,
    DateTime? timestamp,
  }) {
    if (streakProtectors >= maxStreakProtectors) return false;
    if (_ledger.any((tx) => tx.id == id)) return false;

    final tx = ShopTransaction(
      id: id,
      amount: 0,
      description: description,
      source: 'purchase',
      reference: 'streak_protector',
      createdAt: timestamp ?? _clock(),
    );
    _ledger.add(tx);
    _recomputeFromLedger();
    unawaited(_syncLedgerEntryIfAuthenticated(tx));
    return true;
  }

  /// Concede até 2 Selos de Consistência gratuitos por mês para usuários VIP,
  /// respeitando o teto VIP em dobro (10 guardados).
  Future<int> grantMonthlyVipStreakProtectorsIfEligible() async {
    final epoch = _resetEpoch;
    await init();
    if (epoch != _resetEpoch) return 0;
    final granted = await _grantMonthlyVipStreakProtectorsInternal();
    if (granted > 0) {
      await _persist();
    }
    return granted;
  }

  Future<int> _grantMonthlyVipStreakProtectorsInternal() async {
    if (!SupabaseService.isCurrentUserVip) return 0;
    final now = _clock();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    int granted = 0;

    for (int slot = 1; slot <= InsightsEconomyConfig.vipMonthlyFreeProtectors; slot++) {
      if (streakProtectors >= maxStreakProtectors) break;
      final added = _grantFreeStreakProtector(
        id: 'vip_monthly_protector:$ym:$slot',
        description: 'Bônus VIP mensal · Selo de Consistência ($ym)',
        timestamp: now,
      );
      if (added) granted++;
    }
    return granted;
  }

  Future<void> _ensureWelcomeBonus() async {
    const welcomeId = 'welcome_bonus';
    if (_ledger.any((tx) => tx.id == welcomeId || tx.source == 'welcome')) return;
    _ledger.add(
      ShopTransaction(
        id: welcomeId,
        amount: InsightsEconomyConfig.welcomeBonus,
        description: 'Bônus de boas-vindas',
        source: 'welcome',
        reference: 'onboarding',
        createdAt: _clock(),
      ),
    );
  }

  Future<void> _persist() async {
    try {
      await local_store.writeSavedExamsRaw(
        storageKey,
        jsonEncode({
          'ledger': _ledger.map((t) => t.toJson()).toList(),
          'pending_hard_cards': _pendingHardCardIds.toList(),
          'protected_streak_dates':
              _protectedStreakDates.map((d) => _isoDate(d)).toList()..sort(),
          'soft_cap_half_carry': _softCapHalfCarry,
          'total_quiz_questions_answered': _totalQuizQuestionsAnswered,
          'equipped_banner_id': equippedBannerIdNotifier.value,
          'equipped_frame_id': equippedFrameIdNotifier.value,
          'equipped_title_id': equippedTitleIdNotifier.value,
        }),
      );
    } catch (_) {}
  }

  /// Aplica o teto diário suave (150 Insights cheios/dia, metade após o teto).
  int _applyDailySoftCap(int rawAmount) {
    if (rawAmount <= 0) return 0;
    final earnedToday = todayEarnedInsights;
    const cap = InsightsEconomyConfig.dailySoftCap;

    if (earnedToday + rawAmount <= cap) {
      return rawAmount;
    }
    if (earnedToday >= cap) {
      final totalHalfUnits = rawAmount + _softCapHalfCarry;
      final paid = totalHalfUnits ~/ 2;
      _softCapHalfCarry = totalHalfUnits % 2;
      return paid;
    }

    // Cruzando exatamente a fronteira dos 150 Insights no dia
    final fullPart = cap - earnedToday;
    final overflowPart = rawAmount - fullPart;
    final totalHalfUnits = overflowPart + _softCapHalfCarry;
    final halfPart = totalHalfUnits ~/ 2;
    _softCapHalfCarry = totalHalfUnits % 2;
    return fullPart + halfPart;
  }

  int _appendStudyReward({
    required String? idempotentId,
    required int rawAmount,
    required String description,
    required String source,
    required String reference,
    bool applySoftCap = true,
  }) {
    if (rawAmount <= 0) return 0;
    if (idempotentId != null && _ledger.any((tx) => tx.id == idempotentId)) {
      return 0;
    }
    final isVip = SupabaseService.isCurrentUserVip;
    final boostedRaw =
        isVip ? rawAmount * InsightsEconomyConfig.vipGainMultiplier : rawAmount;
    final amount =
        (!isVip && applySoftCap) ? _applyDailySoftCap(boostedRaw) : boostedRaw;
    if (amount <= 0) {
      unawaited(_persist());
      return 0;
    }

    final now = _clock();
    final tx = ShopTransaction(
      id: idempotentId ?? '$source-${now.microsecondsSinceEpoch}-${_ledger.length}',
      amount: amount,
      description: isVip ? '$description · 2× VIP' : description,
      source: source,
      reference: reference,
      createdAt: now,
    );
    _ledger.add(tx);
    _recomputeFromLedger();
    latestGainNotifier.value = InsightGainEvent(
      id: tx.id,
      amount: amount,
      reason: description,
      source: source,
      isVipBoosted: isVip,
      createdAt: now,
    );
    unawaited(_persist());
    unawaited(_syncLedgerEntryIfAuthenticated(tx));
    return amount;
  }

  Future<void> _syncLedgerEntryIfAuthenticated(ShopTransaction tx) async {
    final user = SupabaseService.currentUser;
    if (user == null) return; // Garante zero requisições de rede no modo Visitante/Offline
    try {
      await SupabaseService.client.from('noesis_insight_ledger').upsert({
        'id': tx.id,
        'user_id': user.id,
        'amount': tx.amount,
        'description': tx.description,
        'source': tx.source,
        'reference': tx.reference,
        'created_at': tx.createdAt.toIso8601String(),
      });
    } catch (_) {}
  }

  /// Questão de simulado: +1 respondida, +2 extra se certa (+3 total).
  /// Regra anti-abuso: só paga se levou ao menos 3 segundos.
  /// Também concede 1 Selo de Consistência gratuito a cada 100 questões válidas (respeitando o limite da conta).
  int awardForQuizAnswer({
    required bool isCorrect,
    Duration? elapsedSinceShown,
    String? subject,
    String? reference,
  }) {
    if (elapsedSinceShown != null &&
        elapsedSinceShown < InsightsEconomyConfig.minQuizQuestionDuration) {
      return 0;
    }
    _totalQuizQuestionsAnswered++;
    final raw = InsightsEconomyConfig.quizQuestionAnswered +
        (isCorrect ? InsightsEconomyConfig.quizQuestionCorrectBonus : 0);
    final ctxLabel = (subject ?? '').trim().isNotEmpty ? ' · ${subject!.trim()}' : '';
    final earned = _appendStudyReward(
      idempotentId: null,
      rawAmount: raw,
      description: isCorrect ? 'Questão certa no Simulado$ctxLabel' : 'Questão respondida no Simulado$ctxLabel',
      source: 'quiz_question',
      reference: reference ?? 'quiz_question',
    );
    var grantedFreeShield = false;
    if (_totalQuizQuestionsAnswered % InsightsEconomyConfig.questionsPerFreeStreakProtector == 0) {
      final milestone =
          _totalQuizQuestionsAnswered ~/ InsightsEconomyConfig.questionsPerFreeStreakProtector;
      grantedFreeShield = _grantFreeStreakProtector(
        id: 'question_milestone_protector:$milestone',
        description:
            'Selo de Consistência grátis · $_totalQuizQuestionsAnswered questões respondidas',
      );
    }
    if (grantedFreeShield || earned == 0) {
      unawaited(_persist());
    }
    return earned;
  }

  /// Quantas vezes o aluno já concluiu este mesmo grupo de simulado.
  int priorExamCompletionsForGroup(String groupKey) {
    final prefix = 'exam_group:$groupKey:';
    return _ledger
        .where((tx) => tx.source == 'exam_complete' && tx.reference.startsWith(prefix))
        .length;
  }

  /// Simulado concluído: +20, e +30 extra com >= 80% de acerto.
  /// Anti-abuso: refazer o mesmo simulado paga 100%, depois 50%, depois 25%.
  int awardForExamCompletion({
    required String attemptId,
    required String groupKey,
    required double scorePercentage,
    String? subject,
  }) {
    final txId = 'exam_complete:$attemptId';
    if (_ledger.any((tx) => tx.id == txId)) return 0;

    final priorCount = priorExamCompletionsForGroup(groupKey);
    const mults = InsightsEconomyConfig.examRepeatMultipliers;
    final multiplier = priorCount < mults.length ? mults[priorCount] : mults.last;

    final baseRaw = InsightsEconomyConfig.examCompleted +
        (scorePercentage >= InsightsEconomyConfig.examHighScoreThresholdPct
            ? InsightsEconomyConfig.examHighScoreBonus
            : 0);
    final decayedRaw = (baseRaw * multiplier).round();
    final pctInt = scorePercentage.round();
    final ctxLabel = (subject ?? '').trim().isNotEmpty ? ' · ${subject!.trim()}' : '';
    final repeatSuffix = priorCount == 0
        ? ''
        : (multiplier == 0.5 ? ' (50% repetição)' : ' (25% repetição)');

    return _appendStudyReward(
      idempotentId: txId,
      rawAmount: decayedRaw,
      description: 'Simulado concluído ($pctInt%)$ctxLabel$repeatSuffix',
      source: 'exam_complete',
      reference: 'exam_group:$groupKey:$attemptId',
    );
  }

  /// Flashcard revisado: +1 se estava realmente na hora de revisar;
  /// +2 extra se havia sido marcado como difícil antes e agora foi acertado ('good'/'easy').
  int awardForFlashcardReview({
    required String cardId,
    required String difficulty,
    required bool isDueForReview,
    bool wasPreviouslyHard = false,
    String? deckTitle,
    bool allowReviewBase = true,
  }) {
    int totalEarned = 0;
    final ctxLabel = (deckTitle ?? '').trim().isNotEmpty ? ' · ${deckTitle!.trim()}' : '';

    if (allowReviewBase && isDueForReview) {
      totalEarned += _appendStudyReward(
        idempotentId: null,
        rawAmount: InsightsEconomyConfig.flashcardDueReview,
        description: 'Flashcard revisado$ctxLabel',
        source: 'flashcard_review',
        reference: 'card:$cardId',
      );
    }

    final trackedAsHard = wasPreviouslyHard || _pendingHardCardIds.contains(cardId);
    if (difficulty == 'hard') {
      _pendingHardCardIds.add(cardId);
      unawaited(_persist());
    } else if ((difficulty == 'good' || difficulty == 'easy') && trackedAsHard) {
      _pendingHardCardIds.remove(cardId);
      totalEarned += _appendStudyReward(
        idempotentId: null,
        rawAmount: InsightsEconomyConfig.flashcardHardRedeemedBonus,
        description: 'Cartão difícil superado$ctxLabel',
        source: 'flashcard_redeem',
        reference: 'card:$cardId',
      );
    }

    return totalEarned;
  }

  /// Avalia meta do dia (+15), meta semanal (+150) e streak (3d, 7d, 14d, 30d) sem duplicar.
  int evaluateStudyProgressRewards({
    required List<Map<String, dynamic>> sessions,
    required int weeklyGoalMinutes,
    int? dailyGoalMinutes,
    DateTime? referenceDate,
  }) {
    // Exclui registros mockados de demonstração do saldo real
    final realSessions = sessions.where((s) {
      final id = (s['id'] ?? '').toString();
      return !id.startsWith('session-mock-');
    }).toList();
    if (realSessions.isEmpty) return 0;

    final now = referenceDate ?? _clock();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = _isoDate(today);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final mondayIso = _isoDate(monday);

    int earned = 0;

    // 1. Meta do dia batida (+15)
    int todayMinutes = 0;
    for (final s in realSessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (s['study_date'] ?? s['created_at'] ?? '').toString().trim();
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (day == today) todayMinutes += mins;
    }
    final int? dailyTargetMinutes = dailyGoalMinutes != null
        ? (dailyGoalMinutes > 0 ? dailyGoalMinutes.clamp(15, 1440) : null)
        : (weeklyGoalMinutes > 0
            ? (weeklyGoalMinutes / 7).round().clamp(15, 720)
            : null);
    if (dailyTargetMinutes != null && todayMinutes >= dailyTargetMinutes) {
      earned += _appendStudyReward(
        idempotentId: 'daily_goal:$todayIso',
        rawAmount: InsightsEconomyConfig.dailyGoalHit,
        description: 'Meta do dia batida',
        source: 'daily_goal',
        reference: 'daily_goal:$todayIso',
      );
    }

    // 2. Meta semanal batida (+150)
    final weekMinutes = SupabaseService.computeCurrentWeekStudiedMinutes(
      realSessions,
      referenceDate: now,
    );
    if (weeklyGoalMinutes > 0 && weekMinutes >= weeklyGoalMinutes) {
      earned += _appendStudyReward(
        idempotentId: 'weekly_goal:$mondayIso',
        rawAmount: InsightsEconomyConfig.weeklyGoalHit,
        description: 'Meta semanal batida',
        source: 'weekly_goal',
        reference: 'weekly_goal:$mondayIso',
      );
    }

    // 2b. 1 Selo de Consistência gratuito a cada 10h de estudo na semana (respeitando o limite da conta)
    final weeklyHourTiers =
        weekMinutes ~/ InsightsEconomyConfig.weeklyStudyMinutesPerFreeStreakProtector;
    var grantedWeeklyShield = false;
    for (int tier = 1; tier <= weeklyHourTiers; tier++) {
      if (streakProtectors >= maxStreakProtectors) break;
      final added = _grantFreeStreakProtector(
        id: 'weekly_hours_protector:$mondayIso:$tier',
        description: 'Selo de Consistência grátis · ${tier * 10}h estudadas na semana',
        timestamp: now,
      );
      if (added) grantedWeeklyShield = true;
    }
    if (grantedWeeklyShield) {
      unawaited(_persist());
    }

    // 3. Marcos de Streak: 3, 7, 14 e 30 dias (+20, +60, +120, +300)
    final streakDays = SupabaseService.computeCurrentStreakDays(
      realSessions,
      referenceDate: now,
      protectedDates: protectedStreakDates,
    );
    for (final entry in InsightsEconomyConfig.streakMilestones.entries) {
      if (streakDays >= entry.key) {
        earned += _appendStudyReward(
          idempotentId: 'streak:${entry.key}',
          rawAmount: entry.value,
          description: 'Streak de ${entry.key} dias alcançado',
          source: 'streak',
          reference: 'streak:${entry.key}',
        );
      }
    }

    return earned;
  }

  /// Recompensa de estudo realizada exclusivamente dentro de um Grupo de Estudos.
  /// Respeita o multiplicador VIP (2×) e o teto diário suave para contas gratuitas,
  /// retornando o valor exato creditado para somar ao ranking interno daquele grupo.
  int awardGroupStudyReward({
    required String groupId,
    required String source,
    required int rawAmount,
    required String description,
    String? idempotentId,
    String? reference,
  }) {
    return _appendStudyReward(
      idempotentId: idempotentId,
      rawAmount: rawAmount,
      description: description,
      source: source,
      reference: reference ?? 'group:$groupId',
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Compra idempotente de tema com Insights: não cobra duas vezes por clique duplo.
  Future<ShopPurchaseResult> purchaseTheme(String themeId) async {
    await init();
    if (_purchasingThemeIds.contains(themeId)) {
      return const ShopPurchaseResult(
        ok: true,
        message: 'Compra já em processamento.',
      );
    }
    _purchasingThemeIds.add(themeId);
    try {
      if (themeId == AsterTheme.customThemeId) {
        return const ShopPurchaseResult(
          ok: false,
          error: 'O tema Personalizado RGB é um privilégio exclusivo VIP.',
        );
      }

      final themeOption =
          AsterTheme.availableThemes.where((t) => t.id == themeId).firstOrNull;
      if (themeOption == null) {
        return const ShopPurchaseResult(ok: false, error: 'Tema não encontrado na loja.');
      }

      final txId = 'purchase:theme:$themeId';
      if (isThemeUnlocked(themeId) || _ledger.any((t) => t.id == txId)) {
        return ShopPurchaseResult(
          ok: true,
          message: 'Você já possui o tema ${themeOption.name}.',
        );
      }

      final price = priceForTheme(themeId);
      if (balance < price) {
        final missing = price - balance;
        return ShopPurchaseResult(
          ok: false,
          error:
              'Saldo insuficiente. Faltam ${InsightsEconomyConfig.formatBalance(missing)} para comprar ${themeOption.name}.',
        );
      }

      final tx = ShopTransaction(
        id: txId,
        amount: -price,
        description: 'Compra do tema ${themeOption.name}',
        source: 'purchase',
        reference: 'theme:$themeId',
        createdAt: _clock(),
      );
      _ledger.add(tx);
      _recomputeFromLedger();
      await _persist();
      unawaited(_syncLedgerEntryIfAuthenticated(tx));

      return ShopPurchaseResult(
        ok: true,
        message:
            'Tema ${themeOption.name} desbloqueado por ${InsightsEconomyConfig.formatCompact(price)}!',
      );
    } finally {
      _purchasingThemeIds.remove(themeId);
    }
  }

  bool isProfileItemUnlocked(String itemId) {
    final item = ProfileCosmeticsCatalog.findById(itemId);
    if (item != null) {
      if (item.isVipOnly) return SupabaseService.isCurrentUserVip;
      if (item.isFree) return true;
    }
    return unlockedProfileItemsNotifier.value.contains(itemId);
  }

  bool isProfileItemEquipped(ProfileCosmeticItem item) {
    if (!isProfileItemUnlocked(item.id)) return false;
    switch (item.category) {
      case ProfileCosmeticCategory.banner:
        return equippedBannerIdNotifier.value == item.id;
      case ProfileCosmeticCategory.frame:
        return equippedFrameIdNotifier.value == item.id;
      case ProfileCosmeticCategory.title:
        return equippedTitleIdNotifier.value == item.id;
    }
  }

  Future<void> equipProfileItem(ProfileCosmeticCategory category, String itemId) async {
    await init();
    switch (category) {
      case ProfileCosmeticCategory.banner:
        equippedBannerIdNotifier.value = itemId;
        break;
      case ProfileCosmeticCategory.frame:
        equippedFrameIdNotifier.value = itemId;
        break;
      case ProfileCosmeticCategory.title:
        equippedTitleIdNotifier.value = itemId;
        break;
    }
    await _persist();
  }

  /// Compra (com Insights) ou libera via VIP e equipa um item cosmético do Perfil.
  Future<ShopPurchaseResult> purchaseAndEquipProfileItem(ProfileCosmeticItem item) async {
    await init();
    final lockKey = 'profile_item:${item.id}';
    if (_purchasingThemeIds.contains(lockKey)) {
      return const ShopPurchaseResult(ok: true, message: 'Item já em processamento.');
    }
    _purchasingThemeIds.add(lockKey);
    try {
      if (item.isVipOnly && !SupabaseService.isCurrentUserVip) {
        return ShopPurchaseResult(
          ok: false,
          error: '${item.name} é exclusivo para assinantes VIP.',
        );
      }

      if (isProfileItemUnlocked(item.id)) {
        await equipProfileItem(item.category, item.id);
        return ShopPurchaseResult(
          ok: true,
          message: '${item.name} equipado no seu perfil!',
        );
      }

      if (balance < item.price) {
        final missing = item.price - balance;
        return ShopPurchaseResult(
          ok: false,
          error:
              'Saldo insuficiente. Faltam ${InsightsEconomyConfig.formatBalance(missing)} para desbloquear ${item.name}.',
        );
      }

      final txId = 'purchase:profile_item:${item.id}';
      final tx = ShopTransaction(
        id: txId,
        amount: -item.price,
        description: 'Perfil: ${item.name}',
        source: 'purchase',
        reference: 'profile_item:${item.id}',
        createdAt: _clock(),
      );
      _ledger.add(tx);
      _recomputeFromLedger();
      await equipProfileItem(item.category, item.id);
      unawaited(_syncLedgerEntryIfAuthenticated(tx));

      return ShopPurchaseResult(
        ok: true,
        message:
            '${item.name} desbloqueado por ${InsightsEconomyConfig.formatCompact(item.price)} e equipado!',
      );
    } finally {
      _purchasingThemeIds.remove(lockKey);
    }
  }

  /// Compra um Selo de Consistência (limite de 5 padrão ou 10 para VIP).
  Future<ShopPurchaseResult> purchaseStreakProtector() async {
    await init();
    if (_purchasingThemeIds.contains('streak_protector')) {
      return const ShopPurchaseResult(ok: true, message: 'Compra já em processamento.');
    }
    _purchasingThemeIds.add('streak_protector');
    try {
      final maxAllowed = maxStreakProtectors;
      if (streakProtectors >= maxAllowed) {
        return ShopPurchaseResult(
          ok: false,
          error:
              'Você já atingiu o limite de $maxAllowed Selos de Consistência guardados.',
        );
      }
      const price = InsightsEconomyConfig.streakProtectorPrice;
      if (balance < price) {
        final missing = price - balance;
        return ShopPurchaseResult(
          ok: false,
          error:
              'Saldo insuficiente. Faltam ${InsightsEconomyConfig.formatBalance(missing)} para guardar um Selo de Consistência.',
        );
      }

      final now = _clock();
      final tx = ShopTransaction(
        id: 'purchase:streak_protector:${now.microsecondsSinceEpoch}',
        amount: -price,
        description: 'Selo de Consistência',
        source: 'purchase',
        reference: 'streak_protector',
        createdAt: now,
      );
      _ledger.add(tx);
      _recomputeFromLedger();
      await _persist();
      unawaited(_syncLedgerEntryIfAuthenticated(tx));

      return ShopPurchaseResult(
        ok: true,
        message:
            'Selo de Consistência guardado! Você agora tem $streakProtectors/$maxAllowed ativos.',
      );
    } finally {
      _purchasingThemeIds.remove('streak_protector');
    }
  }

  /// Consome protetores automaticamente para cobrir dias perdidos recentes que manteriam
  /// uma sequência real anterior viva (ex.: estudou anteontem, falhou ontem).
  Future<int> reconcileStreakProtectors(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
  }) async {
    await init();
    final available = streakProtectors;
    if (available <= 0) return 0;

    final activeDays = <DateTime>{};
    for (final s in sessions) {
      final id = (s['id'] ?? '').toString();
      if (id.startsWith('session-mock-')) continue;
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (s['study_date'] ?? s['created_at'] ?? '').toString().trim();
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      activeDays.add(DateTime(parsed.year, parsed.month, parsed.day));
    }
    if (activeDays.isEmpty) return 0;

    final now = referenceDate ?? _clock();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Caminha para trás a partir de ontem procurando dias sem estudo e ainda não protegidos
    // até encontrar uma ponte com algum dia ativo/protegido anterior.
    final gapToProtect = <DateTime>[];
    var cursor = yesterday;
    bool foundPriorStudy = false;

    for (int i = 0; i < available + 1; i++) {
      if (activeDays.contains(cursor)) {
        foundPriorStudy = true;
        break;
      }
      if (_protectedStreakDates.contains(cursor)) {
        // Continua recuando para confirmar que existe estudo real antes desta proteção
        var check = cursor.subtract(const Duration(days: 1));
        while (_protectedStreakDates.contains(check)) {
          check = check.subtract(const Duration(days: 1));
        }
        if (activeDays.contains(check)) {
          foundPriorStudy = true;
        }
        break;
      }
      gapToProtect.add(cursor);
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (!foundPriorStudy || gapToProtect.isEmpty || gapToProtect.length > available) {
      return 0;
    }

    _protectedStreakDates.addAll(gapToProtect);
    _recomputeFromLedger();
    await _persist();
    return gapToProtect.length;
  }

  @visibleForTesting
  Future<void> resetForTesting({
    int initialBalance = 0,
    bool grantWelcomeBonus = false,
    Set<String>? unlockedThemes,
    int initialStreakProtectors = 0,
    int initialQuizQuestionsAnswered = 0,
    Set<DateTime>? initialProtectedDates,
    DateTime Function()? customClock,
  }) async {
    _resetEpoch++;
    _clock = customClock ?? DateTime.now;
    _loaded = true;
    _ledger.clear();
    _pendingHardCardIds.clear();
    _purchasingThemeIds.clear();
    _protectedStreakDates.clear();
    _softCapHalfCarry = 0;
    _totalQuizQuestionsAnswered = initialQuizQuestionsAnswered;
    equippedBannerIdNotifier.value = ProfileCosmeticsCatalog.defaultBannerId;
    equippedFrameIdNotifier.value = ProfileCosmeticsCatalog.defaultFrameId;
    equippedTitleIdNotifier.value = ProfileCosmeticsCatalog.defaultTitleId;
    latestGainNotifier.value = null;

    final now = _clock();
    if (grantWelcomeBonus) {
      _ledger.add(
        ShopTransaction(
          id: 'welcome_bonus',
          amount: InsightsEconomyConfig.welcomeBonus,
          description: 'Bônus de boas-vindas',
          source: 'welcome',
          reference: 'onboarding',
          createdAt: now,
        ),
      );
    }
    if (initialBalance > 0) {
      _ledger.add(
        ShopTransaction(
          id: 'test_seed_${now.microsecondsSinceEpoch}',
          amount: initialBalance,
          description: 'Saldo inicial de teste',
          source: 'welcome',
          reference: 'test_seed',
          createdAt: now,
        ),
      );
    }
    for (int i = 0; i < initialStreakProtectors; i++) {
      _ledger.add(
        ShopTransaction(
          id: 'test_shield_$i',
          amount: 0,
          description: 'Protetor de Ofensiva',
          source: 'purchase',
          reference: 'streak_protector',
          createdAt: now,
        ),
      );
    }
    if (initialProtectedDates != null) {
      for (final d in initialProtectedDates) {
        _protectedStreakDates.add(DateTime(d.year, d.month, d.day));
      }
    }
    if (unlockedThemes != null) {
      for (final themeId in unlockedThemes) {
        if (themeId == defaultFreeThemeId) continue;
        _ledger.add(
          ShopTransaction(
            id: 'purchase:theme:$themeId',
            amount: 0,
            description: 'Tema desbloqueado ($themeId)',
            source: 'purchase',
            reference: 'theme:$themeId',
            createdAt: now,
          ),
        );
      }
    }

    _recomputeFromLedger();
    await _persist();
  }
}
