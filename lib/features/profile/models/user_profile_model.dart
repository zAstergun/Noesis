import '../../ranking/models/ranking_league_model.dart';

/// Modelo público de perfil exibido quando outro usuário procura pelo `@`,
/// visualiza integrantes no Ranking/Grupos ou interage pelas conexões.
class PublicUserProfile {
  const PublicUserProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isVip = false,
    this.isCurrentUser = false,
    this.eloIndex = 0,
    this.weeklyInsights = 0,
    this.weeklyMinutes = 0,
    this.streakDays = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.followsCurrentUser = false,
    this.equippedBannerId,
    this.equippedFrameId,
    this.equippedTitleId,
    this.bestEloIndex,
    this.rankingRank,
    this.accumulatedScore = 0,
    this.top3Finishes = 0,
    this.focusSubjects = const [],
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
  final int followersCount;
  final int followingCount;

  /// Verdadeiro quando este perfil segue o usuário atual.
  /// Combinado com `isFollowing(userId)` forma uma conexão mútua ("amigo" interno).
  final bool followsCurrentUser;

  /// Customizações cosméticas desbloqueáveis com Insights.
  final String? equippedBannerId;
  final String? equippedFrameId;
  final String? equippedTitleId;

  /// Carreira noética e foco de estudos exibidos no Perfil Público.
  final int? bestEloIndex;
  final int? rankingRank;
  final int accumulatedScore;
  final int top3Finishes;
  final List<String> focusSubjects;

  RankingEloTier get elo => RankingEloCatalog.tierAt(eloIndex);
  RankingEloTier get bestElo =>
      RankingEloCatalog.tierAt(bestEloIndex != null && bestEloIndex! >= eloIndex ? bestEloIndex! : eloIndex);

  PublicUserProfile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isVip,
    bool? isCurrentUser,
    int? eloIndex,
    int? weeklyInsights,
    int? weeklyMinutes,
    int? streakDays,
    int? followersCount,
    int? followingCount,
    bool? followsCurrentUser,
    String? equippedBannerId,
    String? equippedFrameId,
    String? equippedTitleId,
    int? bestEloIndex,
    int? rankingRank,
    int? accumulatedScore,
    int? top3Finishes,
    List<String>? focusSubjects,
  }) {
    return PublicUserProfile(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isVip: isVip ?? this.isVip,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      eloIndex: eloIndex ?? this.eloIndex,
      weeklyInsights: weeklyInsights ?? this.weeklyInsights,
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      streakDays: streakDays ?? this.streakDays,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      followsCurrentUser: followsCurrentUser ?? this.followsCurrentUser,
      equippedBannerId: equippedBannerId ?? this.equippedBannerId,
      equippedFrameId: equippedFrameId ?? this.equippedFrameId,
      equippedTitleId: equippedTitleId ?? this.equippedTitleId,
      bestEloIndex: bestEloIndex ?? this.bestEloIndex,
      rankingRank: rankingRank ?? this.rankingRank,
      accumulatedScore: accumulatedScore ?? this.accumulatedScore,
      top3Finishes: top3Finishes ?? this.top3Finishes,
      focusSubjects: focusSubjects ?? this.focusSubjects,
    );
  }
}

class SocialGraphState {
  const SocialGraphState({
    required this.currentUserProfile,
    required this.directory,
    required this.followingIds,
    required this.followingUsernames,
    required this.incomingFollowerIds,
    required this.incomingFollowerUsernames,
    this.isLoading = false,
  });

  final PublicUserProfile currentUserProfile;
  final List<PublicUserProfile> directory;
  final Set<String> followingIds;
  final Set<String> followingUsernames;
  final Set<String> incomingFollowerIds;
  final Set<String> incomingFollowerUsernames;
  final bool isLoading;
}
