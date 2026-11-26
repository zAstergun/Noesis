import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/insights_economy_config.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../widgets/insight_icon.dart';
import '../../widgets/vip_privileges.dart';
import '../profile/data/social_connections_service.dart';
import '../profile/models/user_profile_model.dart';
import '../profile/widgets/public_profile_modal.dart';
import '../study_groups/widgets/study_group_modals.dart';
import '../tracker/dashboard_analytics.dart';
import 'data/ranking_service.dart';
import 'models/ranking_league_model.dart';
import 'widgets/noesis_elo_badge.dart';

/// Página **Ranking & Ligas Semanais**:
/// competição semanal no estilo Duolingo somando os Insights obtidos na semana
/// e promovendo/rebaixando usuários ativos entre os 8 elos cognitivos do Noesis.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  int? _inspectedEloIndex;

  @override
  void initState() {
    super.initState();
    RankingService.instance.init();
  }

  String _formatRemainingTime(DateTime weekEndsAt) {
    final diff = weekEndsAt.difference(RankingService.currentNow());
    if (diff.isNegative) return 'Encerrando...';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h restantes';
    if (hours > 0) return '${hours}h ${mins}m restantes';
    return '${mins}m restantes';
  }

  void _openCompetitorProfileModal(BuildContext context, RankingCompetitor c, RankingEloTier elo) {
    final social = SocialConnectionsService.instance;
    final fromDirectory = social.findByUserOrHandle(userId: c.userId, username: c.username);
    final profile = fromDirectory ??
        PublicUserProfile(
          userId: c.userId,
          username: c.username,
          displayName: c.displayName,
          avatarUrl: c.avatarUrl,
          bio: c.bio,
          isVip: c.isVip,
          isCurrentUser: c.isCurrentUser,
          eloIndex: elo.index,
          weeklyInsights: c.weeklyInsights,
          weeklyMinutes: c.weeklyMinutes,
          streakDays: c.streakDays,
        );
    showPublicUserProfileModal(context, profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return ValueListenableBuilder<RankingBoardState>(
      valueListenable: RankingService.instance.boardNotifier,
      builder: (context, board, _) {
        final elo = board.currentElo;
        final nextElo = board.currentEloIndex < RankingEloCatalog.tiers.length - 1
            ? RankingEloCatalog.tierAt(board.currentEloIndex + 1)
            : null;
        final prevElo = board.currentEloIndex > 0
            ? RankingEloCatalog.tierAt(board.currentEloIndex - 1)
            : null;

        final inspectedIdx = (_inspectedEloIndex ?? board.currentEloIndex)
            .clamp(0, RankingEloCatalog.tiers.length - 1);
        final inspectedElo = RankingEloCatalog.tierAt(inspectedIdx);

        final standings = board.standings;
        final promotionCutoffScore = elo.promotionSlots > 0 && standings.length >= elo.promotionSlots
            ? standings[elo.promotionSlots - 1].weeklyInsights
            : (standings.isNotEmpty ? standings.first.weeklyInsights : 0);
        final pointsToPromotion = (promotionCutoffScore - board.currentUserWeeklyInsights + 1)
            .clamp(0, 999999);

        final safeZoneRank = elo.demotionSlots > 0 && standings.length > elo.demotionSlots
            ? standings.length - elo.demotionSlots
            : standings.length;
        final safeCutoffScore = safeZoneRank > 0 && standings.length >= safeZoneRank
            ? standings[safeZoneRank - 1].weeklyInsights
            : 0;

        return SingleChildScrollView(
          key: const Key('ranking_screen_root'),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36.0 : 16.0,
            vertical: 18.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Cabeçalho ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NoesisCollapsedMenuSpacer(width: 82),
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NoesisEloBadge(
                                  tier: elo,
                                  size: 48,
                                  highlighted: true,
                                ),
                                const SizedBox(width: 14),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ranking & Ligas Semanais',
                                        style: GoogleFonts.manrope(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                          color: AsterTheme.text(context),
                                        ),
                                      ),
                                      Text(
                                        'Jornada cognitiva semanal pelos Insights conquistados no Noesis',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12.5,
                                          color: AsterTheme.textMuted(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  key: const Key('ranking_week_countdown'),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AsterTheme.primary(context).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: AsterTheme.primary(context),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatRemainingTime(board.weekEndsAt),
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AsterTheme.primary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Atualizar liga',
                                  onPressed: () => RankingService.instance.syncCurrentUserProgress(),
                                  icon: const Icon(Icons.refresh_rounded, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (board.lastOutcome != null) ...[
                    _buildLastOutcomeBanner(context, board.lastOutcome!),
                    const SizedBox(height: 16),
                  ],

                  // ─── Progressão de Elos (Hero + Trilha Conectada + Inspetor) ───
                  _buildEloProgressionCard(
                    context,
                    board: board,
                    elo: elo,
                    nextElo: nextElo,
                    prevElo: prevElo,
                    inspectedElo: inspectedElo,
                    promotionCutoffScore: promotionCutoffScore,
                    pointsToPromotion: pointsToPromotion,
                    safeCutoffScore: safeCutoffScore,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 20),

                  // ─── Pódio + Tabela da Competição Semanal ───
                  SoftClayCard(
                    key: const Key('ranking_leaderboard_list'),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            NoesisEloBadge(tier: elo, size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Elo ${elo.name} · Chave da Semana',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AsterTheme.text(context),
                                ),
                              ),
                            ),
                            SoftClayTag(
                              label: _zoneLabel(board.currentUserZone),
                              color: _zoneColor(context, board.currentUserZone),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextElo != null
                              ? 'Os ${elo.promotionSlots} primeiros avançam para ${nextElo.name} no encerramento semanal (domingo às 23h59).'
                              : 'Você está no elo máximo (${elo.name})! Disputa pelo pódio semanal.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                        if (standings.length >= 3) ...[
                          const SizedBox(height: 18),
                          _buildPodiumBanner(context, standings: standings, elo: elo),
                        ],
                        const SizedBox(height: 18),
                        ..._buildZonedStandingsRows(context, board, elo, nextElo, prevElo),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ─── Dica para subir de Elo ───
                  SoftClayCard(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const InsightCoinIcon(size: 20),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Cada Insight obtido em Simulados (+${InsightsEconomyConfig.quizQuestionAnswered + InsightsEconomyConfig.quizQuestionCorrectBonus}/questão), Flashcards e Metas soma na sua subida semanal.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => RootScreen.switchTab(1),
                              icon: const Icon(Icons.assignment_rounded, size: 15),
                              label: const Text('Ir p/ Simulados'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => RootScreen.switchTab(2),
                              icon: const Icon(Icons.style_rounded, size: 15),
                              label: const Text('Ir p/ Flashcards'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEloProgressionCard(
    BuildContext context, {
    required RankingBoardState board,
    required RankingEloTier elo,
    required RankingEloTier? nextElo,
    required RankingEloTier? prevElo,
    required RankingEloTier inspectedElo,
    required int promotionCutoffScore,
    required int pointsToPromotion,
    required int safeCutoffScore,
    required bool isDesktop,
  }) {
    final totalTiers = RankingEloCatalog.tiers.length;
    final standings = board.standings;

    // Calcula progresso visual na meta semanal atual
    final int targetScore;
    final String goalLabel;
    if (board.currentUserZone == RankingZone.demotion && prevElo != null && safeCutoffScore > 0) {
      targetScore = safeCutoffScore + 1;
      goalLabel = 'Meta para sair do rebaixamento';
    } else if (nextElo != null && elo.promotionSlots > 0) {
      targetScore = promotionCutoffScore > 0 ? promotionCutoffScore + 1 : 1;
      goalLabel = 'Rumo ao Elo ${nextElo.name} (Top ${elo.promotionSlots})';
    } else {
      targetScore = promotionCutoffScore > 0 ? promotionCutoffScore : 1;
      goalLabel = 'Disputa pela liderança em ${elo.name}';
    }

    final double progressRatio = targetScore <= 0
        ? 1.0
        : (board.currentUserWeeklyInsights / targetScore).clamp(0.0, 1.0);

    return SoftClayCard(
      key: const Key('ranking_elo_track_card'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabeçalho da Trilha + Elo Atual
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NoesisEloBadge(
                    tier: elo,
                    size: 54,
                    highlighted: true,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESCALA NOÉTICA · NÍVEL ${elo.index + 1} DE $totalTiers',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Elo atual: ${elo.name}',
                        style: GoogleFonts.manrope(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: elo.accentColor,
                        ),
                      ),
                      Text(
                        elo.subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _zoneColor(context, board.currentUserZone).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(
                    color: _zoneColor(context, board.currentUserZone).withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  _zoneLabel(board.currentUserZone),
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _zoneColor(context, board.currentUserZone),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Medidor de Progresso para Promoção / Zona Segura
          Container(
            key: const Key('ranking_promotion_progress'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              border: Border.all(color: AsterTheme.surfaceInset(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      board.currentUserZone == RankingZone.promotion
                          ? Icons.rocket_launch_rounded
                          : (board.currentUserZone == RankingZone.demotion
                              ? Icons.shield_outlined
                              : Icons.trending_up_rounded),
                      size: 16,
                      color: elo.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        goalLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.text(context),
                        ),
                      ),
                    ),
                    Text(
                      '+${board.currentUserWeeklyInsights} / +$targetScore',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: elo.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progressRatio),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) {
                      return Container(
                        height: 9,
                        width: double.infinity,
                        color: AsterTheme.surfaceInset(context),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: val.clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  elo.accentColor,
                                  nextElo?.badgeColor ?? AsterConstants.menta,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      _zoneHelperText(
                        board.currentUserZone,
                        nextElo: nextElo,
                        prevElo: prevElo,
                        promotionSlots: elo.promotionSlots,
                        pointsToPromotion: pointsToPromotion,
                      ),
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _zoneColor(context, board.currentUserZone),
                      ),
                    ),
                    Text(
                      'Toque em qualquer elo abaixo para ver detalhes',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Trilha Visual Conectada dos 8 Elos do Noesis
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < totalTiers; i++) ...[
                    _buildEloStepNode(
                      context,
                      tier: RankingEloCatalog.tiers[i],
                      currentEloIndex: board.currentEloIndex,
                      bestEloIndex: board.bestEloIndex,
                      isInspected: RankingEloCatalog.tiers[i].index == inspectedElo.index,
                      onTap: () {
                        setState(() {
                          _inspectedEloIndex = RankingEloCatalog.tiers[i].index;
                        });
                      },
                    ),
                    if (i < totalTiers - 1)
                      _buildEloConnector(
                        context,
                        leftTier: RankingEloCatalog.tiers[i],
                        rightTier: RankingEloCatalog.tiers[i + 1],
                        currentEloIndex: board.currentEloIndex,
                        bestEloIndex: board.bestEloIndex,
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 4. Painel Interativo de Detalhes do Elo Selecionado
          _buildInspectedEloPanel(
            context,
            tier: inspectedElo,
            currentEloIndex: board.currentEloIndex,
            bestEloIndex: board.bestEloIndex,
            retentionStreakWeeks: board.retentionStreakWeeks,
          ),

          const SizedBox(height: 18),

          // 5. KPIs da Semana e Histórico
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryKpiTile(
                context,
                label: 'POSIÇÃO NA LIGA',
                value: '#${board.currentUserRank}',
                subtitle: 'de ${standings.length} ativos nesta semana',
                accent: elo.accentColor,
                icon: Icons.emoji_events_rounded,
              ),
              _summaryKpiTile(
                context,
                key: const Key('ranking_weekly_insights_kpi'),
                label: 'INSIGHTS DA SEMANA',
                value: '+${board.currentUserWeeklyInsights}',
                subtitle: _zoneHelperText(
                  board.currentUserZone,
                  nextElo: nextElo,
                  prevElo: prevElo,
                  promotionSlots: elo.promotionSlots,
                  pointsToPromotion: pointsToPromotion,
                ),
                accent: AsterConstants.menta,
                icon: Icons.auto_awesome_rounded,
                showCoin: true,
              ),
              _summaryKpiTile(
                context,
                key: const Key('ranking_accumulated_score_kpi'),
                label: 'PONTUAÇÃO ACUMULADA',
                value: '${board.accumulatedRankingScore} pts',
                subtitle:
                    '${board.retentionStreakWeeks} ${board.retentionStreakWeeks == 1 ? 'sem. seguida mantida' : 'sem. seguidas mantidas'} · próx. +${RankingEloCatalog.maintenancePointsForStreak(streakWeeks: board.retentionStreakWeeks + 1, eloIndex: board.currentEloIndex)} pts',
                accent: AsterConstants.ambar,
                icon: Icons.local_fire_department_rounded,
              ),
              _summaryKpiTile(
                context,
                label: 'MELHOR ELO',
                value: board.bestElo.name,
                subtitle:
                    '${board.top3Finishes} ${board.top3Finishes == 1 ? 'pódio Top 3' : 'pódios Top 3'} · ${board.weeksCompeted} sem.',
                accent: AsterTheme.primary(context),
                icon: Icons.workspace_premium_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEloStepNode(
    BuildContext context, {
    required RankingEloTier tier,
    required int currentEloIndex,
    required int bestEloIndex,
    required bool isInspected,
    required VoidCallback onTap,
  }) {
    final isCurrent = tier.index == currentEloIndex;
    final isUnlocked = tier.index <= bestEloIndex;
    final isBelowOrAtCurrent = tier.index <= currentEloIndex;

    return InkWell(
      key: Key('ranking_elo_tier_${tier.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isInspected
              ? tier.badgeColor.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          border: Border.all(
            color: isInspected
                ? tier.badgeColor.withValues(alpha: 0.65)
                : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: isCurrent ? 54 : 46,
                  height: isCurrent ? 54 : 46,
                  child: Center(
                    child: NoesisEloBadge(
                      tier: tier,
                      size: isCurrent ? 52 : 44,
                      locked: !isUnlocked,
                      highlighted: isCurrent,
                    ),
                  ),
                ),
                if (!isUnlocked)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: AsterTheme.card(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: AsterTheme.surfaceInset(context)),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 10,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  )
                else if (isBelowOrAtCurrent && !isCurrent)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: AsterConstants.menta,
                        shape: BoxShape.circle,
                        border: Border.all(color: AsterTheme.card(context), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tier.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: isCurrent || isInspected ? FontWeight.w900 : FontWeight.w700,
                color: isCurrent
                    ? tier.accentColor
                    : (isUnlocked ? AsterTheme.text(context) : AsterTheme.textMuted(context)),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCurrent
                    ? tier.badgeColor.withValues(alpha: 0.18)
                    : AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Text(
                isCurrent ? 'Atual' : 'Nível ${tier.index + 1}',
                style: GoogleFonts.manrope(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isCurrent ? tier.accentColor : AsterTheme.textMuted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEloConnector(
    BuildContext context, {
    required RankingEloTier leftTier,
    required RankingEloTier rightTier,
    required int currentEloIndex,
    required int bestEloIndex,
  }) {
    final bool isActiveSegment = rightTier.index <= currentEloIndex;
    final bool isBestSegment = rightTier.index <= bestEloIndex;

    return Padding(
      padding: const EdgeInsets.only(top: 27),
      child: Container(
        width: 24,
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: isActiveSegment
              ? LinearGradient(
                  colors: [leftTier.accentColor, rightTier.accentColor],
                )
              : null,
          color: isActiveSegment
              ? null
              : (isBestSegment
                  ? rightTier.accentColor.withValues(alpha: 0.30)
                  : AsterTheme.surfaceInset(context)),
        ),
      ),
    );
  }

  Widget _buildInspectedEloPanel(
    BuildContext context, {
    required RankingEloTier tier,
    required int currentEloIndex,
    required int bestEloIndex,
    required int retentionStreakWeeks,
  }) {
    final bool isCurrent = tier.index == currentEloIndex;
    final bool isNext = tier.index == currentEloIndex + 1;
    final bool isUnlocked = tier.index <= bestEloIndex;
    final int nextRetentionPts = RankingEloCatalog.maintenancePointsForStreak(
      streakWeeks: retentionStreakWeeks + 1,
      eloIndex: tier.index,
    );
    final int nextRetentionInsights = RankingEloCatalog.maintenanceInsightsForStreak(
      streakWeeks: retentionStreakWeeks + 1,
      eloIndex: tier.index,
    );

    final String statusText;
    final Color statusColor;
    if (isCurrent) {
      statusText = 'Seu elo atual';
      statusColor = tier.accentColor;
    } else if (isNext) {
      statusText = 'Próxima conquista';
      statusColor = AsterConstants.menta;
    } else if (isUnlocked) {
      statusText = 'Já alcançado';
      statusColor = AsterTheme.primary(context);
    } else {
      statusText = 'A desbloquear';
      statusColor = AsterTheme.textMuted(context);
    }

    return AnimatedContainer(
      key: const Key('ranking_selected_elo_panel'),
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tier.badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: tier.badgeColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NoesisEloBadge(
                    tier: tier,
                    size: 28,
                    locked: !isUnlocked,
                    highlighted: isCurrent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Elo ${tier.name} · ${tier.subtitle}',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.text(context),
                    ),
                  ),
                ],
              ),
              SoftClayTag(label: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tier.milestoneDescription,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AsterTheme.textMuted(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _rulePill(
                context,
                icon: Icons.arrow_upward_rounded,
                label: tier.promotionSlots > 0
                    ? 'Promoção: Top ${tier.promotionSlots} da chave'
                    : 'Topo da Escala Noética',
                color: AsterConstants.menta,
              ),
              _rulePill(
                context,
                icon: tier.demotionSlots > 0
                    ? Icons.arrow_downward_rounded
                    : Icons.verified_user_outlined,
                label: tier.demotionSlots > 0
                    ? 'Rebaixamento: últimos ${tier.demotionSlots}'
                    : 'Sem rebaixamento',
                color: tier.demotionSlots > 0 ? AsterConstants.coral : AsterTheme.primary(context),
              ),
              _rulePill(
                context,
                icon: Icons.local_fire_department_rounded,
                label:
                    'Permanência: +$nextRetentionPts pts e +$nextRetentionInsights Insights (cresce a cada semana)',
                color: AsterConstants.ambar,
              ),
            ],
          ),
          if (tier.promotionSlots > 0) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('ranking_elo_rewards_strip'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AsterTheme.surfaceInset(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECOMPENSA POR COLOCAÇÃO AO SUBIR PARA ${RankingEloCatalog.tierAt(tier.index + 1).name.toUpperCase()}',
                    style: GoogleFonts.manrope(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (int r = 1; r <= tier.promotionSlots; r++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AsterConstants.menta.withValues(alpha: r == 1 ? 0.16 : 0.09),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#$r: +${RankingEloCatalog.promotionRewardInsights(finalRank: r, targetEloIndex: tier.index + 1)}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: r == 1 ? AsterConstants.menta : AsterTheme.text(context),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const InsightCoinIcon(size: 11),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rulePill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumBanner(
    BuildContext context, {
    required List<RankingCompetitor> standings,
    required RankingEloTier elo,
  }) {
    final first = standings[0];
    final second = standings[1];
    final third = standings[2];

    return Container(
      key: const Key('ranking_podium_card'),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            elo.badgeColor.withValues(alpha: 0.11),
            AsterTheme.surfaceAlt(context),
          ],
        ),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: elo.badgeColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PÓDIO DA SEMANA',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _podiumSlot(
                  context,
                  competitor: second,
                  rank: 2,
                  elo: elo,
                  pedestalHeight: 42,
                  medalColor: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _podiumSlot(
                  context,
                  competitor: first,
                  rank: 1,
                  elo: elo,
                  pedestalHeight: 56,
                  medalColor: AsterConstants.ambar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _podiumSlot(
                  context,
                  competitor: third,
                  rank: 3,
                  elo: elo,
                  pedestalHeight: 32,
                  medalColor: const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumSlot(
    BuildContext context, {
    required RankingCompetitor competitor,
    required int rank,
    required RankingEloTier elo,
    required double pedestalHeight,
    required Color medalColor,
  }) {
    return InkWell(
      onTap: () => _openCompetitorProfileModal(context, competitor, elo),
      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Icon(Icons.emoji_events_rounded, size: 18, color: medalColor),
            ),
          GroupMemberAvatar(
            displayName: competitor.displayName,
            avatarUrl: competitor.avatarUrl,
            isVip: competitor.isVip,
            radius: rank == 1 ? 22 : 18,
          ),
          const SizedBox(height: 6),
          Text(
            competitor.isCurrentUser ? 'Você' : competitor.displayName.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: competitor.isCurrentUser ? AsterTheme.primary(context) : AsterTheme.text(context),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+${competitor.weeklyInsights}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AsterConstants.menta,
                ),
              ),
              const SizedBox(width: 4),
              const InsightCoinIcon(size: 12),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: pedestalHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: rank == 1 ? 0.20 : 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: medalColor.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: GoogleFonts.jetBrainsMono(
                fontSize: rank == 1 ? 15 : 13,
                fontWeight: FontWeight.w900,
                color: medalColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastOutcomeBanner(BuildContext context, RankingWeekOutcome outcome) {
    final prev = RankingEloCatalog.tierAt(outcome.previousEloIndex);
    final next = RankingEloCatalog.tierAt(outcome.newEloIndex);
    final Color accent;
    final IconData icon;
    final String title;
    if (outcome.wasPromoted) {
      accent = AsterConstants.menta;
      icon = Icons.arrow_circle_up_rounded;
      title =
          'Promoção semanal (#${outcome.finalRank})! Você subiu de ${prev.name} para Elo ${next.name}!';
    } else if (outcome.wasDemoted) {
      accent = AsterConstants.coral;
      icon = Icons.arrow_circle_down_rounded;
      title = 'Fechamento da semana anterior: você foi movido para Elo ${next.name}.';
    } else {
      accent = AsterTheme.primary(context);
      icon = Icons.check_circle_outline_rounded;
      final streakPart = outcome.retentionStreakWeeks > 0
          ? ' · ${outcome.retentionStreakWeeks}ª sem. seguida'
          : '';
      title =
          'Semana anterior encerrada (#${outcome.finalRank}) · Você manteve o Elo ${next.name}$streakPart.';
    }

    final rewardSummary = <String>[
      if (outcome.rewardInsights > 0) '+${outcome.rewardInsights} Insights na carteira',
      if (outcome.pointsEarned > 0) '+${outcome.pointsEarned} pts acumulados',
    ].join(' · ');

    return Container(
      key: const Key('ranking_outcome_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title (+${outcome.weeklyInsights} Insights na semana ${outcome.weekId})',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
                if (rewardSummary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Recompensa recebida: $rewardSummary',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dispensar aviso',
            onPressed: () => RankingService.instance.dismissLastOutcome(),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _summaryKpiTile(
    BuildContext context, {
    Key? key,
    required String label,
    required String value,
    required String subtitle,
    required Color accent,
    required IconData icon,
    bool showCoin = false,
  }) {
    return Container(
      key: key,
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AsterTheme.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              if (showCoin) ...[
                const SizedBox(width: 6),
                const InsightCoinIcon(size: 16),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AsterTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  String _zoneLabel(RankingZone z) {
    switch (z) {
      case RankingZone.promotion:
        return 'Zona de Promoção ↑';
      case RankingZone.safe:
        return 'Zona Segura';
      case RankingZone.demotion:
        return 'Zona de Rebaixamento ↓';
    }
  }

  Color _zoneColor(BuildContext context, RankingZone z) {
    switch (z) {
      case RankingZone.promotion:
        return AsterConstants.menta;
      case RankingZone.safe:
        return AsterTheme.primary(context);
      case RankingZone.demotion:
        return AsterConstants.coral;
    }
  }

  String _zoneHelperText(
    RankingZone zone, {
    required RankingEloTier? nextElo,
    required RankingEloTier? prevElo,
    required int promotionSlots,
    required int pointsToPromotion,
  }) {
    if (zone == RankingZone.promotion) {
      return nextElo != null
          ? 'Subindo para ${nextElo.name}!'
          : 'No topo da escala Noesis!';
    }
    if (zone == RankingZone.demotion && prevElo != null) {
      return 'Atenção: risco de descer para ${prevElo.name}';
    }
    if (nextElo != null && promotionSlots > 0 && pointsToPromotion > 0) {
      return 'Faltam +$pointsToPromotion para o Top $promotionSlots';
    }
    return 'Mantendo seu elo esta semana';
  }

  List<Widget> _buildZonedStandingsRows(
    BuildContext context,
    RankingBoardState board,
    RankingEloTier elo,
    RankingEloTier? nextElo,
    RankingEloTier? prevElo,
  ) {
    final widgets = <Widget>[];
    RankingZone? lastZone;
    final total = board.standings.length;

    for (int i = 0; i < total; i++) {
      final rank = i + 1;
      final competitor = board.standings[i];
      final zone = RankingService.zoneForRank(rank, total: total, tier: elo);

      if (zone != lastZone) {
        if (lastZone != null) widgets.add(const SizedBox(height: 10));
        widgets.add(
          _buildZoneHeader(
            context,
            zone: zone,
            nextElo: nextElo,
            prevElo: prevElo,
            promotionSlots: elo.promotionSlots,
            demotionSlots: elo.demotionSlots,
          ),
        );
        widgets.add(const SizedBox(height: 8));
        lastZone = zone;
      }

      widgets.add(_buildCompetitorRow(context, competitor, rank: rank, zone: zone, elo: elo));
    }
    return widgets;
  }

  Widget _buildZoneHeader(
    BuildContext context, {
    required RankingZone zone,
    required RankingEloTier? nextElo,
    required RankingEloTier? prevElo,
    required int promotionSlots,
    required int demotionSlots,
  }) {
    final Color color = _zoneColor(context, zone);
    final IconData icon;
    final String text;
    switch (zone) {
      case RankingZone.promotion:
        icon = Icons.arrow_upward_rounded;
        text = 'ZONA DE PROMOÇÃO · TOP $promotionSlots SOBEM PARA ${nextElo?.name.toUpperCase() ?? ''}';
      case RankingZone.safe:
        icon = Icons.horizontal_rule_rounded;
        text = 'ZONA DE PERMANÊNCIA · MANTÉM O ELO';
      case RankingZone.demotion:
        icon = Icons.arrow_downward_rounded;
        text = 'ZONA DE REBAIXAMENTO · ÚLTIMOS $demotionSlots DESCEM PARA ${prevElo?.name.toUpperCase() ?? ''}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitorRow(
    BuildContext context,
    RankingCompetitor c, {
    required int rank,
    required RankingZone zone,
    required RankingEloTier elo,
  }) {
    final primaryCol = AsterTheme.primary(context);
    final zoneCol = _zoneColor(context, zone);
    final medalColor = switch (rank) {
      1 => AsterConstants.ambar,
      2 => const Color(0xFF64748B),
      3 => const Color(0xFFB45309),
      _ => AsterTheme.textMuted(context),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.isCurrentUser
            ? primaryCol.withValues(alpha: 0.10)
            : AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(
          color: c.isCurrentUser ? primaryCol : AsterTheme.surfaceInset(context),
          width: c.isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('ranking_row_${c.userId}'),
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          onTap: () => _openCompetitorProfileModal(context, c, elo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: rank <= 3 ? 14 : 13,
                      fontWeight: FontWeight.w900,
                      color: medalColor,
                    ),
                  ),
                ),
                GroupMemberAvatar(
                  displayName: c.displayName,
                  avatarUrl: c.avatarUrl,
                  isVip: c.isVip,
                  radius: 17,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            c.displayName,
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                          if (c.isCurrentUser)
                            SoftClayTag(
                              label: 'Você',
                              color: primaryCol,
                            ),
                          if (c.isVip)
                            const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${c.username} · ${DashboardAnalytics.formatReadableDuration(c.weeklyMinutes)} na semana · ${c.streakDays}d streak',
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: zoneCol.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${c.weeklyInsights}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: zoneCol,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const InsightCoinIcon(size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
