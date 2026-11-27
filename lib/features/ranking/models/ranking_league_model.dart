import 'package:flutter/material.dart';
import '../../../core/localization/noesis_l10n.dart';

enum RankingZone { promotion, safe, demotion }

class RankingEloTier {
  const RankingEloTier({
    required this.index,
    required this.id,
    required this.name,
    required this.subtitle,
    required this.milestoneDescription,
    required this.accentColor,
    required this.badgeColor,
    required this.icon,
    required this.promotionSlots,
    required this.demotionSlots,
  });

  final int index;
  final String id;
  final String name;
  final String subtitle;
  final String milestoneDescription;
  final Color accentColor;
  final Color badgeColor;
  final IconData icon;
  final int promotionSlots;
  final int demotionSlots;

  String get localizedName => NoesisL10n.tr(name);
  String get localizedSubtitle => NoesisL10n.tr(subtitle);
  String get localizedMilestoneDescription => NoesisL10n.tr(milestoneDescription);
}

class RankingCompetitor {
  const RankingCompetitor({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isVip = false,
    this.isCurrentUser = false,
    required this.eloIndex,
    required this.weeklyInsights,
    this.weeklyMinutes = 0,
    this.streakDays = 0,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isVip;
  final bool isCurrentUser;
  final int eloIndex;
  final int weeklyInsights;
  final int weeklyMinutes;
  final int streakDays;

  RankingCompetitor copyWith({
    int? eloIndex,
    int? weeklyInsights,
    int? weeklyMinutes,
    int? streakDays,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    bool? isVip,
  }) {
    return RankingCompetitor(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isVip: isVip ?? this.isVip,
      isCurrentUser: isCurrentUser,
      eloIndex: eloIndex ?? this.eloIndex,
      weeklyInsights: weeklyInsights ?? this.weeklyInsights,
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

class RankingWeekOutcome {
  const RankingWeekOutcome({
    required this.weekId,
    required this.previousEloIndex,
    required this.newEloIndex,
    required this.finalRank,
    required this.weeklyInsights,
    this.rewardInsights = 0,
    this.pointsEarned = 0,
    this.retentionStreakWeeks = 0,
  });

  final String weekId;
  final int previousEloIndex;
  final int newEloIndex;
  final int finalRank;
  final int weeklyInsights;
  final int rewardInsights;
  final int pointsEarned;
  final int retentionStreakWeeks;

  bool get wasPromoted => newEloIndex > previousEloIndex;
  bool get wasDemoted => newEloIndex < previousEloIndex;
  bool get maintained => newEloIndex == previousEloIndex;

  Map<String, dynamic> toJson() => {
        'week_id': weekId,
        'previous_elo_index': previousEloIndex,
        'new_elo_index': newEloIndex,
        'final_rank': finalRank,
        'weekly_insights': weeklyInsights,
        'reward_insights': rewardInsights,
        'points_earned': pointsEarned,
        'retention_streak_weeks': retentionStreakWeeks,
      };

  factory RankingWeekOutcome.fromJson(Map<String, dynamic> json) {
    return RankingWeekOutcome(
      weekId: (json['week_id'] ?? '').toString(),
      previousEloIndex: (json['previous_elo_index'] as num?)?.toInt() ?? 0,
      newEloIndex: (json['new_elo_index'] as num?)?.toInt() ?? 0,
      finalRank: (json['final_rank'] as num?)?.toInt() ?? 1,
      weeklyInsights: (json['weekly_insights'] as num?)?.toInt() ?? 0,
      rewardInsights: (json['reward_insights'] as num?)?.toInt() ?? 0,
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
      retentionStreakWeeks: (json['retention_streak_weeks'] as num?)?.toInt() ?? 0,
    );
  }
}

class RankingBoardState {
  const RankingBoardState({
    required this.weekId,
    required this.weekEndsAt,
    required this.currentEloIndex,
    required this.bestEloIndex,
    required this.top3Finishes,
    required this.weeksCompeted,
    required this.standings,
    required this.currentUserRank,
    required this.currentUserZone,
    required this.currentUserWeeklyInsights,
    this.retentionStreakWeeks = 0,
    this.accumulatedRankingScore = 0,
    this.lastOutcome,
    this.isLoading = false,
  });

  final String weekId;
  final DateTime weekEndsAt;
  final int currentEloIndex;
  final int bestEloIndex;
  final int top3Finishes;
  final int weeksCompeted;
  final List<RankingCompetitor> standings;
  final int currentUserRank;
  final RankingZone currentUserZone;
  final int currentUserWeeklyInsights;
  final int retentionStreakWeeks;
  final int accumulatedRankingScore;
  final RankingWeekOutcome? lastOutcome;
  final bool isLoading;

  RankingEloTier get currentElo => RankingEloCatalog.tierAt(currentEloIndex);
  RankingEloTier get bestElo => RankingEloCatalog.tierAt(bestEloIndex);

  RankingBoardState copyWith({
    String? weekId,
    DateTime? weekEndsAt,
    int? currentEloIndex,
    int? bestEloIndex,
    int? top3Finishes,
    int? weeksCompeted,
    List<RankingCompetitor>? standings,
    int? currentUserRank,
    RankingZone? currentUserZone,
    int? currentUserWeeklyInsights,
    int? retentionStreakWeeks,
    int? accumulatedRankingScore,
    RankingWeekOutcome? lastOutcome,
    bool clearOutcome = false,
    bool? isLoading,
  }) {
    return RankingBoardState(
      weekId: weekId ?? this.weekId,
      weekEndsAt: weekEndsAt ?? this.weekEndsAt,
      currentEloIndex: currentEloIndex ?? this.currentEloIndex,
      bestEloIndex: bestEloIndex ?? this.bestEloIndex,
      top3Finishes: top3Finishes ?? this.top3Finishes,
      weeksCompeted: weeksCompeted ?? this.weeksCompeted,
      standings: standings ?? this.standings,
      currentUserRank: currentUserRank ?? this.currentUserRank,
      currentUserZone: currentUserZone ?? this.currentUserZone,
      currentUserWeeklyInsights: currentUserWeeklyInsights ?? this.currentUserWeeklyInsights,
      retentionStreakWeeks: retentionStreakWeeks ?? this.retentionStreakWeeks,
      accumulatedRankingScore: accumulatedRankingScore ?? this.accumulatedRankingScore,
      lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RankingEloCatalog {
  RankingEloCatalog._();

  static List<RankingEloTier> get tiers => [
    RankingEloTier(
      index: 0,
      id: 'faisca',
      name: NoesisL10n.tr('Faísca'),
      subtitle: NoesisL10n.tr('Primeiro contato e curiosidade ativa'),
      milestoneDescription: NoesisL10n.tr(
          'Porta de entrada no Noesis. Todo Insight obtido em simulados, flashcards e metas já conta para subir de elo.'),
      accentColor: const Color(0xFFD97706),
      badgeColor: const Color(0xFFF5A623),
      icon: Icons.bolt_rounded,
      promotionSlots: 5,
      demotionSlots: 0,
    ),
    RankingEloTier(
      index: 1,
      id: 'vigilia',
      name: NoesisL10n.tr('Vigília'),
      subtitle: NoesisL10n.tr('Atenção ativa e presença nos estudos'),
      milestoneDescription: NoesisL10n.tr(
          'Consolida o hábito semanal. Sessões regulares e revisões em dia mantêm seu ritmo acima da linha de corte.'),
      accentColor: const Color(0xFF475569),
      badgeColor: const Color(0xFF64748B),
      icon: Icons.visibility_rounded,
      promotionSlots: 5,
      demotionSlots: 3,
    ),
    RankingEloTier(
      index: 2,
      id: 'logos',
      name: NoesisL10n.tr('Logos'),
      subtitle: NoesisL10n.tr('Raciocínio estruturado e método'),
      milestoneDescription: NoesisL10n.tr(
          'Representa clareza analítica. Combinar cadernos organizados com simulados acelera os ganhos da semana.'),
      accentColor: const Color(0xFF0284C7),
      badgeColor: const Color(0xFF38BDF8),
      icon: Icons.menu_book_rounded,
      promotionSlots: 5,
      demotionSlots: 3,
    ),
    RankingEloTier(
      index: 3,
      id: 'sintese',
      name: NoesisL10n.tr('Síntese'),
      subtitle: NoesisL10n.tr('Conexão madura entre teoria e prática'),
      milestoneDescription: NoesisL10n.tr(
          'A disputa aperta no Top 4. Aqui se destacam estudantes que unem trilhas, mapas mentais e revisão espaçada.'),
      accentColor: const Color(0xFF059669),
      badgeColor: const Color(0xFF3CCF9A),
      icon: Icons.hub_rounded,
      promotionSlots: 4,
      demotionSlots: 3,
    ),
    RankingEloTier(
      index: 4,
      id: 'episteme',
      name: NoesisL10n.tr('Episteme'),
      subtitle: NoesisL10n.tr('Conhecimento sólido e fundamentado'),
      milestoneDescription: NoesisL10n.tr(
          'Patamar avançado de domínio. Exige alta precisão em simulados e constância durante toda a semana.'),
      accentColor: const Color(0xFF6D28D9),
      badgeColor: const Color(0xFF7C6CF0),
      icon: Icons.psychology_rounded,
      promotionSlots: 4,
      demotionSlots: 3,
    ),
    RankingEloTier(
      index: 5,
      id: 'apice',
      name: NoesisL10n.tr('Ápice'),
      subtitle: NoesisL10n.tr('Alta performance e ritmo competitivo'),
      milestoneDescription: NoesisL10n.tr(
          'Apenas o pódio (Top 3) avança. Cada meta cumprida e cada bloco de estudo define sua subida.'),
      accentColor: const Color(0xFFE11D48),
      badgeColor: const Color(0xFFFF7A90),
      icon: Icons.trending_up_rounded,
      promotionSlots: 3,
      demotionSlots: 3,
    ),
    RankingEloTier(
      index: 6,
      id: 'sophia',
      name: NoesisL10n.tr('Sophia'),
      subtitle: NoesisL10n.tr('Maestria acadêmica entre a elite'),
      milestoneDescription: NoesisL10n.tr(
          'Antecâmara do topo cognitivo. Disputa acirrada entre os estudantes mais consistentes da comunidade.'),
      accentColor: const Color(0xFFB45309),
      badgeColor: const Color(0xFFFBBF24),
      icon: Icons.auto_awesome_rounded,
      promotionSlots: 3,
      demotionSlots: 3,
    ),
    RankingEloTier(
      index: 7,
      id: 'noesis',
      name: NoesisL10n.tr('Noesis'),
      subtitle: NoesisL10n.tr('Intelecto pleno · Elo máximo da semana'),
      milestoneDescription: NoesisL10n.tr(
          'O auge da jornada no Noesis. Sem elos acima — aqui a disputa é pelo pódio semanal e pela permanência.'),
      accentColor: const Color(0xFF4F46E5),
      badgeColor: const Color(0xFF8B5CF6),
      icon: Icons.workspace_premium_rounded,
      promotionSlots: 0,
      demotionSlots: 3,
    ),
  ];

  static RankingEloTier tierAt(int index) {
    final safe = index.clamp(0, tiers.length - 1);
    return tiers[safe];
  }

  /// Recompensa em Insights ao subir de Elo na virada semanal, proporcional à colocação (`finalRank`)
  /// e ao nível do novo Elo alcançado.
  static int promotionRewardInsights({
    required int finalRank,
    required int targetEloIndex,
  }) {
    final baseByRank = switch (finalRank) {
      1 => 150,
      2 => 115,
      3 => 90,
      4 => 70,
      5 => 55,
      _ => 45,
    };
    return baseByRank + (targetEloIndex.clamp(0, tiers.length - 1) * 15);
  }

  /// Pontuação de carreira atribuída na subida de Elo conforme colocação.
  static int promotionRankingPoints({
    required int finalRank,
    required int targetEloIndex,
  }) {
    final rankScore = (200 - ((finalRank - 1).clamp(0, 10) * 25)).clamp(75, 200);
    return rankScore + (targetEloIndex.clamp(0, tiers.length - 1) * 20);
  }

  /// Pontuação acumulativa ganha ao se manter no ranking sem cair:
  /// cresce progressivamente conforme aumenta a sequência de semanas consecutivas mantidas.
  static int maintenancePointsForStreak({
    required int streakWeeks,
    required int eloIndex,
  }) {
    final safeStreak = streakWeeks.clamp(1, 520);
    return 30 + ((safeStreak - 1) * 15) + (eloIndex.clamp(0, tiers.length - 1) * 10);
  }

  /// Bônus de Insights pela permanência consecutiva no ranking (também acumulativo por sequência).
  static int maintenanceInsightsForStreak({
    required int streakWeeks,
    required int eloIndex,
  }) {
    final safeStreak = streakWeeks.clamp(1, 520);
    final streakBonus = (15 + ((safeStreak - 1) * 8)).clamp(15, 75);
    return streakBonus + (eloIndex.clamp(0, tiers.length - 1) * 5);
  }
}
