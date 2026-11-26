import 'package:flutter/material.dart';
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
    return [
      ProfileAchievementStatus(
        id: 'first_step',
        title: 'Primeiro Passo',
        description: 'Iniciar sessões de estudo ou simulados',
        rewardInsights: 25,
        icon: Icons.play_circle_fill_rounded,
        color: const Color(0xFF10B981),
        progress: hasStudied ? 1.0 : 0.0,
        statusLabel: hasStudied ? 'Concluído' : '0/1',
      ),
      ProfileAchievementStatus(
        id: 'streak_7',
        title: 'Chama Constante',
        description: 'Alcançar 7 dias seguidos de streak',
        rewardInsights: 60,
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFF59E0B),
        progress: (streakDays / 7).clamp(0.0, 1.0),
        statusLabel: streakDays >= 7 ? 'Concluído' : '$streakDays/7d',
      ),
      ProfileAchievementStatus(
        id: 'streak_30',
        title: 'Guardião da Ofensiva',
        description: 'Manter 30 dias seguidos de consistência',
        rewardInsights: 200,
        icon: Icons.shield_rounded,
        color: const Color(0xFFF97316),
        progress: (streakDays / 30).clamp(0.0, 1.0),
        statusLabel: streakDays >= 30 ? 'Concluído' : '$streakDays/30d',
      ),
      ProfileAchievementStatus(
        id: 'focus_10h',
        title: 'Foco de 10 Horas',
        description: 'Completar 10h de estudo na semana',
        rewardInsights: 80,
        icon: Icons.timer_rounded,
        color: primaryCol,
        progress: (weeklyMinutes / 600).clamp(0.0, 1.0),
        statusLabel: weeklyMinutes >= 600 ? 'Concluído' : '${weeklyMinutes ~/ 60}h/10h',
      ),
      ProfileAchievementStatus(
        id: 'focus_25h',
        title: 'Maratona Semanal',
        description: 'Completar 25h estudadas na semana',
        rewardInsights: 180,
        icon: Icons.bolt_rounded,
        color: const Color(0xFF6366F1),
        progress: (weeklyMinutes / 1500).clamp(0.0, 1.0),
        statusLabel: weeklyMinutes >= 1500 ? 'Concluído' : '${weeklyMinutes ~/ 60}h/25h',
      ),
      ProfileAchievementStatus(
        id: 'questions_100',
        title: 'Maratonista de Questões',
        description: 'Responder 100 questões válidas',
        rewardInsights: 100,
        icon: Icons.quiz_rounded,
        color: const Color(0xFF0EA5E9),
        progress: (questions / 100).clamp(0.0, 1.0),
        statusLabel: questions >= 100 ? 'Concluído' : '$questions/100',
      ),
      ProfileAchievementStatus(
        id: 'exams_5',
        title: 'Estrategista de Provas',
        description: 'Concluir 5 simulados completos na conta',
        rewardInsights: 160,
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF0284C7),
        progress: (exams / 5).clamp(0.0, 1.0),
        statusLabel: exams >= 5 ? 'Concluído' : '$exams/5',
      ),
      ProfileAchievementStatus(
        id: 'memory_builder',
        title: 'Memória Afiada',
        description: 'Acumular 20 revisões de flashcards ou notas',
        rewardInsights: 75,
        icon: Icons.style_rounded,
        color: const Color(0xFFEC4899),
        progress: (flashcardsAndNotes / 20).clamp(0.0, 1.0),
        statusLabel: flashcardsAndNotes >= 20 ? 'Concluído' : '$flashcardsAndNotes/20',
      ),
      ProfileAchievementStatus(
        id: 'elo_logos',
        title: 'Ascensão Noética',
        description: 'Alcançar o Elo Logos (nível 3) ou acima',
        rewardInsights: 120,
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF3B82F6),
        progress: (eloIndex / 2).clamp(0.0, 1.0),
        statusLabel: eloIndex >= 2 ? 'Concluído' : 'Elo $eloName',
      ),
      ProfileAchievementStatus(
        id: 'elo_apice',
        title: 'Topo Cognitivo',
        description: 'Atingir Elo Ápice ou conquistar 3 pódios',
        rewardInsights: 260,
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFD97706),
        progress: eloIndex >= 5 || top3Finishes >= 3
            ? 1.0
            : (eloIndex / 5).clamp(0.0, 0.99),
        statusLabel: eloIndex >= 5 || top3Finishes >= 3
            ? 'Concluído'
            : '$eloIndex/5 Elo',
      ),
      ProfileAchievementStatus(
        id: 'team_spirit',
        title: 'Espírito de Equipe',
        description: 'Participar de um grupo ou ter conexão mútua',
        rewardInsights: 50,
        icon: Icons.groups_rounded,
        color: const Color(0xFF14B8A6),
        progress: hasTeamOrFriend ? 1.0 : 0.0,
        statusLabel: hasTeamOrFriend ? 'Concluído' : '0/1',
      ),
      ProfileAchievementStatus(
        id: 'custom_style',
        title: 'Estilo Próprio',
        description: 'Equipar capa, moldura ou título no Perfil',
        rewardInsights: 40,
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF9333EA),
        progress: hasCustomIdentity ? 1.0 : 0.0,
        statusLabel: hasCustomIdentity ? 'Concluído' : '0/1',
      ),
    ];
  }
}
