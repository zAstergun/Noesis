import 'package:flutter/material.dart';
import '../../../core/localization/noesis_l10n.dart';
import '../../performance/models/performance_report_model.dart';
import 'profile_cosmetics.dart';
import 'user_profile_model.dart';

class ProfileAchievementStatus {
  const ProfileAchievementStatus({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardInsights,
    required this.icon,
    required this.color,
    required this.progress,
    required this.statusLabel,
  });

  final String id;
  final String title;
  final String description;
  final int rewardInsights;
  final IconData icon;
  final Color color;
  final double progress;
  final String statusLabel;

  bool get unlocked => progress >= 1.0;
}

/// Catálogo unificado de **12 Conquistas do Noesis** com premiações reais em Insights.
class ProfileAchievementsCatalog {
  ProfileAchievementsCatalog._();

  static const int totalCount = 12;

  static List<ProfileAchievementStatus> evaluateForAccount({
    required PublicUserProfile me,
    required int totalQuizQuestionsAnswered,
    required int totalBestEloIndex,
    required int top3Finishes,
    required int joinedGroupsCount,
    required int mutualConnectionsCount,
    required String? equippedBannerId,
    required String? equippedFrameId,
    required String? equippedTitleId,
    required AccountPerformanceReport? report,
    required Color primaryCol,
  }) {
    final questions = totalQuizQuestionsAnswered > (report?.totalQuestionsAnswered ?? 0)
        ? totalQuizQuestionsAnswered
        : (report?.totalQuestionsAnswered ?? 0);
    final exams = report?.examsCount ?? 0;
    final cardsReviewed = report?.cardsReviewedInPeriod ?? 0;
    final totalNotes = report?.totalNotes ?? 0;
    final flashcardsAndNotes = cardsReviewed + totalNotes;
    final hasStudied = (report?.sessionsCount ?? 0) > 0 || me.weeklyMinutes > 0 || questions > 0;

    final effectiveEloIndex = totalBestEloIndex > me.eloIndex ? totalBestEloIndex : me.eloIndex;
    final hasCustomIdentity = !((equippedBannerId ?? ProfileCosmeticsCatalog.defaultBannerId) ==
            ProfileCosmeticsCatalog.defaultBannerId &&
        (equippedFrameId ?? ProfileCosmeticsCatalog.defaultFrameId) ==
            ProfileCosmeticsCatalog.defaultFrameId &&
        (equippedTitleId ?? ProfileCosmeticsCatalog.defaultTitleId) ==
            ProfileCosmeticsCatalog.defaultTitleId);

    final hasTeamOrFriend = joinedGroupsCount > 0 || mutualConnectionsCount > 0;

    return _buildList(
      hasStudied: hasStudied,
      streakDays: me.streakDays,
      weeklyMinutes: me.weeklyMinutes,
      questions: questions,
      exams: exams,
      flashcardsAndNotes: flashcardsAndNotes,
      eloIndex: effectiveEloIndex,
      eloName: me.elo.name,
      top3Finishes: top3Finishes,
      hasTeamOrFriend: hasTeamOrFriend,
      hasCustomIdentity: hasCustomIdentity,
      primaryCol: primaryCol,
    );
  }

  static List<ProfileAchievementStatus> evaluateForPublicProfile({
    required PublicUserProfile profile,
    required int groupsCount,
    required Color primaryCol,
  }) {
    final effectiveEloIndex =
        profile.bestEloIndex != null && profile.bestEloIndex! > profile.eloIndex
            ? profile.bestEloIndex!
            : profile.eloIndex;
    final hasCustomIdentity = (profile.equippedBannerId != null &&
            profile.equippedBannerId != ProfileCosmeticsCatalog.defaultBannerId) ||
        (profile.equippedFrameId != null &&
            profile.equippedFrameId != ProfileCosmeticsCatalog.defaultFrameId) ||
        (profile.equippedTitleId != null &&
            profile.equippedTitleId != ProfileCosmeticsCatalog.defaultTitleId);

    return _buildList(
      hasStudied: profile.weeklyMinutes > 0 || profile.weeklyInsights > 0,
      streakDays: profile.streakDays,
      weeklyMinutes: profile.weeklyMinutes,
      questions: (profile.weeklyInsights / 2).round(),
      exams: profile.top3Finishes + (profile.eloIndex >= 3 ? 3 : 0),
      flashcardsAndNotes: (profile.weeklyInsights / 15).round(),
      eloIndex: effectiveEloIndex,
      eloName: profile.elo.name,
      top3Finishes: profile.top3Finishes,
      hasTeamOrFriend: groupsCount > 0 || profile.followingCount > 0,
      hasCustomIdentity: hasCustomIdentity,
      primaryCol: primaryCol,
    );
  }

  static List<ProfileAchievementStatus> _buildList({
    required bool hasStudied,
    required int streakDays,
    required int weeklyMinutes,
    required int questions,
    required int exams,
    required int flashcardsAndNotes,
    required int eloIndex,
    required String eloName,
    required int top3Finishes,
    required bool hasTeamOrFriend,
    required bool hasCustomIdentity,
    required Color primaryCol,
  }) {
    final completedLabel = NoesisL10n.tr('Concluído');
    return [
      ProfileAchievementStatus(
        id: 'first_step',
        title: NoesisL10n.tr('Primeiro Passo'),
        description: NoesisL10n.tr('Iniciar sessões de estudo ou simulados'),
        rewardInsights: 25,
        icon: Icons.play_circle_fill_rounded,
        color: const Color(0xFF10B981),
        progress: hasStudied ? 1.0 : 0.0,
        statusLabel: hasStudied ? completedLabel : '0/1',
      ),
      ProfileAchievementStatus(
        id: 'streak_7',
        title: NoesisL10n.tr('Chama Constante'),
        description: NoesisL10n.tr('Alcançar 7 dias seguidos de streak'),
        rewardInsights: 60,
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFF59E0B),
        progress: (streakDays / 7).clamp(0.0, 1.0),
        statusLabel: streakDays >= 7 ? completedLabel : '$streakDays/7d',
      ),
      ProfileAchievementStatus(
        id: 'streak_30',
        title: NoesisL10n.tr('Guardião da Ofensiva'),
        description: NoesisL10n.tr('Manter 30 dias seguidos de consistência'),
        rewardInsights: 200,
        icon: Icons.shield_rounded,
        color: const Color(0xFFF97316),
        progress: (streakDays / 30).clamp(0.0, 1.0),
        statusLabel: streakDays >= 30 ? completedLabel : '$streakDays/30d',
      ),
      ProfileAchievementStatus(
        id: 'focus_10h',
        title: NoesisL10n.tr('Foco de 10 Horas'),
        description: NoesisL10n.tr('Completar 10h de estudo na semana'),
        rewardInsights: 80,
        icon: Icons.timer_rounded,
        color: primaryCol,
        progress: (weeklyMinutes / 600).clamp(0.0, 1.0),
        statusLabel: weeklyMinutes >= 600 ? completedLabel : '${weeklyMinutes ~/ 60}h/10h',
      ),
      ProfileAchievementStatus(
        id: 'focus_25h',
        title: NoesisL10n.tr('Maratona Semanal'),
        description: NoesisL10n.tr('Completar 25h estudadas na semana'),
        rewardInsights: 180,
        icon: Icons.bolt_rounded,
        color: const Color(0xFF6366F1),
        progress: (weeklyMinutes / 1500).clamp(0.0, 1.0),
        statusLabel: weeklyMinutes >= 1500 ? completedLabel : '${weeklyMinutes ~/ 60}h/25h',
      ),
      ProfileAchievementStatus(
        id: 'questions_100',
        title: NoesisL10n.tr('Maratonista de Questões'),
        description: NoesisL10n.tr('Responder 100 questões válidas'),
        rewardInsights: 100,
        icon: Icons.quiz_rounded,
        color: const Color(0xFF0EA5E9),
        progress: (questions / 100).clamp(0.0, 1.0),
        statusLabel: questions >= 100 ? completedLabel : '$questions/100',
      ),
      ProfileAchievementStatus(
        id: 'exams_5',
        title: NoesisL10n.tr('Estrategista de Provas'),
        description: NoesisL10n.tr('Concluir 5 simulados completos na conta'),
        rewardInsights: 160,
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF0284C7),
        progress: (exams / 5).clamp(0.0, 1.0),
        statusLabel: exams >= 5 ? completedLabel : '$exams/5',
      ),
      ProfileAchievementStatus(
        id: 'memory_builder',
        title: NoesisL10n.tr('Memória Afiada'),
        description: NoesisL10n.tr('Acumular 20 revisões de flashcards ou notas'),
        rewardInsights: 75,
        icon: Icons.style_rounded,
        color: const Color(0xFFEC4899),
        progress: (flashcardsAndNotes / 20).clamp(0.0, 1.0),
        statusLabel: flashcardsAndNotes >= 20 ? completedLabel : '$flashcardsAndNotes/20',
      ),
      ProfileAchievementStatus(
        id: 'elo_logos',
        title: NoesisL10n.tr('Ascensão Noética'),
        description: NoesisL10n.tr('Alcançar o Elo Logos (nível 3) ou acima'),
        rewardInsights: 120,
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF3B82F6),
        progress: (eloIndex / 2).clamp(0.0, 1.0),
        statusLabel: eloIndex >= 2
            ? completedLabel
            : NoesisL10n.tr('Elo {eloName}', {'eloName': NoesisL10n.tr(eloName)}),
      ),
      ProfileAchievementStatus(
        id: 'elo_apice',
        title: NoesisL10n.tr('Topo Cognitivo'),
        description: NoesisL10n.tr('Atingir Elo Ápice ou conquistar 3 pódios'),
        rewardInsights: 260,
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFD97706),
        progress: eloIndex >= 5 || top3Finishes >= 3
            ? 1.0
            : (eloIndex / 5).clamp(0.0, 0.99),
        statusLabel: eloIndex >= 5 || top3Finishes >= 3
            ? completedLabel
            : NoesisL10n.tr('{eloIndex}/5 Elo', {'eloIndex': '$eloIndex'}),
      ),
      ProfileAchievementStatus(
        id: 'team_spirit',
        title: NoesisL10n.tr('Espírito de Equipe'),
        description: NoesisL10n.tr('Participar de um grupo ou ter conexão mútua'),
        rewardInsights: 50,
        icon: Icons.groups_rounded,
        color: const Color(0xFF14B8A6),
        progress: hasTeamOrFriend ? 1.0 : 0.0,
        statusLabel: hasTeamOrFriend ? completedLabel : '0/1',
      ),
      ProfileAchievementStatus(
        id: 'custom_style',
        title: NoesisL10n.tr('Estilo Próprio'),
        description: NoesisL10n.tr('Equipar capa, moldura ou título no Perfil'),
        rewardInsights: 40,
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF9333EA),
        progress: hasCustomIdentity ? 1.0 : 0.0,
        statusLabel: hasCustomIdentity ? completedLabel : '0/1',
      ),
    ];
  }
}
