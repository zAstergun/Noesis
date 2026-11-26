import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../widgets/insight_icon.dart';
import '../../../widgets/vip_privileges.dart';
import '../../ranking/widgets/noesis_elo_badge.dart';
import '../../study_groups/data/study_groups_service.dart';
import '../../study_groups/models/study_group_model.dart';
import '../../tracker/dashboard_analytics.dart';
import '../data/social_connections_service.dart';
import '../models/profile_achievements.dart';
import '../models/user_profile_model.dart';
import 'profile_cosmetic_widgets.dart';

/// Exibe a visualização pública de um perfil (como outros usuários veem ao buscar pelo `@`
/// ou ao clicar no participante em Ranking/Grupos), com botão de Seguir e convite rápido para grupo.
Future<void> showPublicUserProfileModal(
  BuildContext context, {
  required PublicUserProfile profile,
  String? previewNotice,
  VoidCallback? onEditOwnProfile,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _PublicUserProfileDialog(
      profile: profile,
      previewNotice: previewNotice,
      onEditOwnProfile: onEditOwnProfile,
    ),
  );
}

class _PublicUserProfileDialog extends StatelessWidget {
  const _PublicUserProfileDialog({
    required this.profile,
    this.previewNotice,
    this.onEditOwnProfile,
  });

  final PublicUserProfile profile;
  final String? previewNotice;
  final VoidCallback? onEditOwnProfile;

  Future<void> _inviteToGroup(BuildContext context, StudyGroup group) async {
    final res = await StudyGroupsService.instance.inviteMemberByUsername(
      groupId: group.id,
      username: profile.username,
      displayNameHint: profile.displayName,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: res.ok ? AsterConstants.menta : AsterConstants.coral,
          content: Text(
            res.ok
                ? (res.message ?? '@${profile.username} adicionado ao grupo "${group.name}"!')
                : (res.error ?? 'Não foi possível convidar.'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final social = SocialConnectionsService.instance;
    final elo = profile.elo;
    final primaryCol = AsterTheme.primary(context);
    final cardCol = isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard;
    final formattedWeeklyTime = DashboardAnalytics.formatReadableDuration(profile.weeklyMinutes);
    final streakLabel = '${profile.streakDays} ${profile.streakDays == 1 ? 'dia' : 'dias'}';

    return Dialog(
      key: const Key('public_profile_modal'),
      backgroundColor: cardCol,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        side: BorderSide(
          color: (isDark ? Colors.white : elo.badgeColor).withValues(alpha: isDark ? 0.08 : 0.16),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ValueListenableBuilder<SocialGraphState>(
          valueListenable: social.stateNotifier,
          builder: (context, state, _) {
            final isFollowing = social.isFollowing(profile.userId, username: profile.username);
            final followsMe = social.followsCurrentUser(profile.userId, username: profile.username);
            final isMutual = social.isMutualConnection(profile.userId, username: profile.username);

            final allGroups = StudyGroupsService.instance.groupsNotifier.value;
            final uid = StudyGroupsService.currentUserId;
            final sharedOrActiveGroups = profile.isCurrentUser
                ? allGroups
                : allGroups
                    .where((g) => g.members.any((m) =>
                        m.userId == profile.userId ||
                        m.username.toLowerCase() == profile.username.toLowerCase()))
                    .toList();
            final invitableGroups = profile.isCurrentUser
                ? const <StudyGroup>[]
                : allGroups
                    .where((g) =>
                        g.canUserInvite(uid) &&
                        !g.members.any((m) =>
                            m.userId == profile.userId ||
                            m.username.toLowerCase() == profile.username.toLowerCase()))
                    .toList();

            final effectiveFollowers = profile.followersCount + (isFollowing && !profile.isCurrentUser ? 1 : 0);

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cover banner com gradiente do Elo + avatar sobreposto e emblema
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        height: 92,
                        width: double.infinity,
                        decoration: buildProfileBannerDecoration(
                          bannerId: profile.equippedBannerId,
                          elo: elo,
                          fallbackPrimary: primaryCol,
                          isDark: isDark,
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -24,
                              top: -28,
                              child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: elo.badgeColor.withValues(alpha: isDark ? 0.16 : 0.14),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -18,
                              bottom: -30,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryCol.withValues(alpha: isDark ? 0.14 : 0.12),
                                ),
                              ),
                            ),
                            if (previewNotice != null)
                              Positioned(
                                left: 14,
                                top: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: cardCol.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility_rounded, size: 13, color: primaryCol),
                                      const SizedBox(width: 5),
                                      Text(
                                        previewNotice!,
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: primaryCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Material(
                                color: cardCol.withValues(alpha: 0.86),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AsterTheme.textMuted(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 42,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ProfileFramedAvatar(
                              displayName: profile.displayName,
                              avatarUrl: profile.avatarUrl,
                              isVip: profile.isVip,
                              elo: elo,
                              frameId: profile.equippedFrameId,
                              radius: 38,
                              ringBackgroundColor: cardCol,
                            ),
                            Positioned(
                              right: -2,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: cardCol,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.10),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: NoesisEloBadge(tier: elo, size: 26, highlighted: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 6,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              profile.displayName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 19.5,
                                fontWeight: FontWeight.w900,
                                color: AsterTheme.text(context),
                              ),
                            ),
                            if (profile.isVip) const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile.username}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primaryCol,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: elo.badgeColor.withValues(alpha: isDark ? 0.18 : 0.13),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                border: Border.all(
                                  color: elo.badgeColor.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NoesisEloBadge(tier: elo, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Elo ${elo.name}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: elo.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if ((profile.equippedTitleId ?? '').isNotEmpty)
                              ProfileTitleBadge(titleId: profile.equippedTitleId),
                            if (!profile.isCurrentUser && isMutual)
                              const SoftClayTag(
                                label: 'Seguem-se mutuamente',
                                color: AsterConstants.menta,
                                icon: Icons.sync_alt_rounded,
                              )
                            else if (!profile.isCurrentUser && followsMe)
                              SoftClayTag(
                                label: 'Segue você',
                                color: primaryCol,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AsterTheme.surfaceAlt(context),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            border: Border.all(
                              color: (isDark ? Colors.white : primaryCol).withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.format_quote_rounded,
                                  size: 16,
                                  color: elo.accentColor.withValues(alpha: 0.75),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (profile.bio ?? '').trim().isNotEmpty
                                      ? profile.bio!.trim()
                                      : 'Estudante ativo no ecossistema Noesis.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AsterTheme.textMuted(context),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Column(
                          key: const Key('public_profile_stats_grid'),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _metricCard(
                                    context,
                                    cardKey: const Key('public_profile_stat_time'),
                                    icon: Icons.schedule_rounded,
                                    label: 'Tempo na semana',
                                    value: formattedWeeklyTime,
                                    color: primaryCol,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _metricCard(
                                    context,
                                    cardKey: const Key('public_profile_stat_streak'),
                                    icon: Icons.local_fire_department_rounded,
                                    label: 'Sequência',
                                    value: streakLabel,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _metricCard(
                                    context,
                                    cardKey: const Key('public_profile_stat_insights'),
                                    leadingWidget: const InsightCoinIcon(size: 14),
                                    label: 'Insights na semana',
                                    value: '+${profile.weeklyInsights}',
                                    color: AsterConstants.menta,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _socialNetworkCard(
                                    context,
                                    followers: effectiveFollowers,
                                    following: profile.followingCount,
                                    primaryCol: primaryCol,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ─── Carreira Noética (espelhando o Perfil) ───
                        _buildCareerSection(
                          context,
                          primaryCol: primaryCol,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),

                        // ─── Conquistas & Insígnias em Destaque ───
                        _buildMilestonesSection(
                          context,
                          primaryCol: primaryCol,
                          isDark: isDark,
                          groupsCount: sharedOrActiveGroups.length,
                        ),

                        // ─── Matérias em Foco & Grupos ───
                        if (profile.focusSubjects.isNotEmpty || sharedOrActiveGroups.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildHighlightsSection(
                            context,
                            primaryCol: primaryCol,
                            isDark: isDark,
                            groups: sharedOrActiveGroups,
                          ),
                        ],

                        const SizedBox(height: 18),
                        if (!profile.isCurrentUser) ...[
                          Row(
                            children: [
                              Expanded(
                                child: SoftClayPillButton(
                                  key: const Key('public_profile_follow_button'),
                                  text: isFollowing ? 'Seguindo' : 'Seguir',
                                  icon: isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                                  isSecondary: isFollowing,
                                  onPressed: () => social.toggleFollow(profile),
                                ),
                              ),
                              if (invitableGroups.length == 1) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const Key('public_profile_invite_group_button'),
                                    onPressed: () => _inviteToGroup(context, invitableGroups.first),
                                    icon: const Icon(Icons.group_add_rounded, size: 16),
                                    label: Text(
                                      'Convidar p/ Grupo',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ] else if (invitableGroups.length > 1) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: PopupMenuButton<StudyGroup>(
                                    key: const Key('public_profile_invite_group_button'),
                                    onSelected: (g) => _inviteToGroup(context, g),
                                    itemBuilder: (_) => invitableGroups
                                        .map(
                                          (g) => PopupMenuItem<StudyGroup>(
                                            value: g,
                                            child: Text(g.name),
                                          ),
                                        )
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(
                                          color: primaryCol.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.group_add_rounded, size: 16, color: primaryCol),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Convidar p/ Grupo',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: primaryCol,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                        ] else if (onEditOwnProfile != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: SoftClayPillButton(
                              text: 'Editar meu Perfil',
                              icon: Icons.edit_rounded,
                              onPressed: () {
                                Navigator.of(context).pop();
                                onEditOwnProfile!();
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              side: BorderSide(
                                color: (isDark ? Colors.white : primaryCol).withValues(alpha: 0.18),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Fechar',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                color: primaryCol,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    Key? cardKey,
    IconData? icon,
    Widget? leadingWidget,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: cardKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: (isDark ? Colors.white : color).withValues(alpha: isDark ? 0.06 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leadingWidget != null)
                leadingWidget
              else if (icon != null)
                Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialNetworkCard(
    BuildContext context, {
    required int followers,
    required int following,
    required Color primaryCol,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('public_profile_stat_social'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: (isDark ? Colors.white : primaryCol).withValues(alpha: isDark ? 0.06 : 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguidores',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$followers',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: primaryCol,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguindo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$following',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AsterTheme.text(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareerSection(
    BuildContext context, {
    required Color primaryCol,
    required bool isDark,
  }) {
    final elo = profile.elo;
    final bestElo = profile.bestElo;
    return Container(
      key: const Key('public_profile_journey_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: (isDark ? Colors.white : elo.badgeColor).withValues(alpha: isDark ? 0.06 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NoesisEloBadge(tier: elo, size: 28, highlighted: true),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carreira Noética · Elo ${elo.name}',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    Text(
                      elo.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              if (profile.rankingRank != null)
                _careerChip(
                  context,
                  label: 'Liga #${profile.rankingRank}',
                  color: primaryCol,
                ),
              _careerChip(
                context,
                label: 'Melhor Elo: ${bestElo.name}',
                color: bestElo.accentColor,
              ),
              _careerChip(
                context,
                label: '${profile.accumulatedScore} pts no ranking',
                color: AsterConstants.menta,
              ),
              if (profile.top3Finishes > 0)
                _careerChip(
                  context,
                  label: '${profile.top3Finishes} ${profile.top3Finishes == 1 ? 'pódio' : 'pódios'}',
                  color: const Color(0xFFF59E0B),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _careerChip(BuildContext context, {required String label, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMilestonesSection(
    BuildContext context, {
    required Color primaryCol,
    required bool isDark,
    required int groupsCount,
  }) {
    final evaluated = ProfileAchievementsCatalog.evaluateForPublicProfile(
      profile: profile,
      groupsCount: groupsCount,
      primaryCol: primaryCol,
    );

    final badges = <({String label, IconData icon, Color color, bool unlocked})>[
      for (final a in evaluated)
        (label: a.title, icon: a.icon, color: a.color, unlocked: a.unlocked),
      if (profile.isVip)
        const (
          label: 'Membro VIP',
          icon: Icons.workspace_premium_rounded,
          color: AsterVipColors.goldDark,
          unlocked: true,
        ),
    ];

    final unlockedCount = evaluated.where((b) => b.unlocked).length;

    return Container(
      key: const Key('public_profile_milestones_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: (isDark ? Colors.white : primaryCol).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, size: 15, color: primaryCol),
              const SizedBox(width: 6),
              Text(
                'Conquistas em Destaque',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AsterTheme.text(context),
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount/${evaluated.length}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AsterTheme.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges.map((b) {
              final fg = b.unlocked ? b.color : AsterTheme.textMuted(context).withValues(alpha: 0.55);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: b.unlocked
                      ? b.color.withValues(alpha: isDark ? 0.18 : 0.11)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(
                    color: b.unlocked
                        ? b.color.withValues(alpha: 0.34)
                        : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(b.icon, size: 12.5, color: fg),
                    const SizedBox(width: 4),
                    Text(
                      b.label,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: b.unlocked ? FontWeight.w800 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsSection(
    BuildContext context, {
    required Color primaryCol,
    required bool isDark,
    required List<StudyGroup> groups,
  }) {
    return Container(
      key: const Key('public_profile_highlights_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: (isDark ? Colors.white : primaryCol).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.focusSubjects.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.menu_book_rounded, size: 14, color: primaryCol),
                const SizedBox(width: 6),
                Text(
                  'Matérias em foco',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: profile.focusSubjects
                  .map(
                    (subj) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryCol.withValues(alpha: isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        subj,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryCol,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (groups.isNotEmpty) ...[
            if (profile.focusSubjects.isNotEmpty) const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.groups_rounded, size: 14, color: AsterConstants.menta),
                const SizedBox(width: 6),
                Text(
                  profile.isCurrentUser ? 'Grupos ativos (${groups.length})' : 'Grupos em comum (${groups.length})',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: groups
                  .take(3)
                  .map(
                    (g) => SoftClayTag(
                      label: g.name,
                      color: AsterConstants.menta,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
