import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../ranking/models/ranking_league_model.dart';
import '../../study_groups/widgets/study_group_modals.dart';
import '../models/profile_cosmetics.dart';

/// Constrói a decoração do banner de perfil usando o cosmético equipado (ou o degradê do Elo).
BoxDecoration buildProfileBannerDecoration({
  required String? bannerId,
  required RankingEloTier elo,
  required Color fallbackPrimary,
  required bool isDark,
}) {
  final item = ProfileCosmeticsCatalog.equippedBannerFor(bannerId);
  if (item == null || item.gradientColors.isEmpty) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          elo.badgeColor.withValues(alpha: isDark ? 0.34 : 0.22),
          fallbackPrimary.withValues(alpha: isDark ? 0.24 : 0.14),
        ],
      ),
    );
  }

  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: item.gradientColors
          .map((c) => c.withValues(alpha: isDark ? 0.44 : 0.30))
          .toList(),
    ),
  );
}

/// Avatar envolvido pela moldura/aura equipada no Perfil.
class ProfileFramedAvatar extends StatelessWidget {
  const ProfileFramedAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isVip = false,
    required this.elo,
    this.frameId,
    this.radius = 36,
    this.ringBackgroundColor,
  });

  final String displayName;
  final String? avatarUrl;
  final bool isVip;
  final RankingEloTier elo;
  final String? frameId;
  final double radius;
  final Color? ringBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frame = ProfileCosmeticsCatalog.equippedFrameFor(frameId);
    final innerBg =
        ringBackgroundColor ?? (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard);

    if (frame == null) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: innerBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: elo.badgeColor.withValues(alpha: isDark ? 0.24 : 0.16),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: GroupMemberAvatar(
          displayName: displayName,
          avatarUrl: avatarUrl,
          isVip: isVip,
          radius: radius,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: frame.gradientColors.length >= 2
              ? frame.gradientColors
              : [frame.accentColor, frame.accentColor.withValues(alpha: 0.65)],
        ),
        boxShadow: [
          BoxShadow(
            color: frame.accentColor.withValues(alpha: isDark ? 0.42 : 0.32),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: innerBg,
          shape: BoxShape.circle,
        ),
        child: GroupMemberAvatar(
          displayName: displayName,
          avatarUrl: avatarUrl,
          isVip: isVip,
          radius: radius,
        ),
      ),
    );
  }
}

/// Pílula discreta do título personalizado conquistado com Insights.
class ProfileTitleBadge extends StatelessWidget {
  const ProfileTitleBadge({
    super.key,
    required this.titleId,
  });

  final String? titleId;

  @override
  Widget build(BuildContext context) {
    final title = ProfileCosmeticsCatalog.equippedTitleFor(titleId);
    if (title == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: title.accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(
          color: title.accentColor.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(title.icon, size: 13, color: title.accentColor),
          const SizedBox(width: 5),
          Text(
            title.name,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: title.accentColor,
            ),
          ),
          if (title.isVipOnly) ...[
            const SizedBox(width: 4),
            Icon(Icons.workspace_premium_rounded, size: 12, color: title.accentColor),
          ],
        ],
      ),
    );
  }
}
