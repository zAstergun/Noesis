import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/insights_economy_config.dart';
import '../../core/localization/noesis_l10n.dart';
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
    if (diff.isNegative) return NoesisL10n.tr('Encerrando...');
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (days > 0) return NoesisL10n.tr('{days}d {hours}h restantes', {'days': days, 'hours': hours});
    if (hours > 0) return NoesisL10n.tr('{hours}h {mins}m restantes', {'hours': hours, 'mins': mins});
    return NoesisL10n.tr('{mins}m restantes', {'mins': mins});
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
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isDesktop ? 460 : MediaQuery.sizeOf(context).width - 130,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('Ranking & Ligas Semanais'),
                                        style: GoogleFonts.manrope(
                                          fontSize: isDesktop ? 21 : 18.5,
                                          fontWeight: FontWeight.w900,
                                          color: AsterTheme.text(context),
                                        ),
                                      ),
                                      Text(
                                        context.tr('Jornada cognitiva semanal pelos Insights conquistados no Noesis'),
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
                                  tooltip: context.tr('Atualizar liga'),
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
                    padding: EdgeInsets.all(isDesktop ? 22 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            NoesisEloBadge(tier: elo, size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('Elo {name} · Chave da Semana', {'name': elo.localizedName}),
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
                              ? context.tr(
                                  'Os {slots} primeiros avançam para {elo} no encerramento semanal (domingo às 23h59).',
                                  {'slots': elo.promotionSlots, 'elo': nextElo.localizedName},
                                )
                              : context.tr(
                                  'Você está no elo máximo ({elo})! Disputa pelo pódio semanal.',
                                  {'elo': elo.localizedName},
                                ),
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
                    padding: EdgeInsets.all(isDesktop ? 18 : 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 580 : MediaQuery.sizeOf(context).width - 64,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const InsightCoinIcon(size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr(
                                    'Cada Insight obtido em Simulados (+{perQuestion}/questão), Flashcards e Metas soma na sua subida semanal.',
                                    {
                                      'perQuestion':
                                          InsightsEconomyConfig.quizQuestionAnswered + InsightsEconomyConfig.quizQuestionCorrectBonus,
                                    },
                                  ),
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => RootScreen.switchTab(1),
                              icon: const Icon(Icons.assignment_rounded, size: 15),
                              label: Text(context.tr('Ir p/ Simulados')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => RootScreen.switchTab(2),
                              icon: const Icon(Icons.style_rounded, size: 15),
                              label: Text(context.tr('Ir p/ Flashcards')),
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
      goalLabel = context.tr('Meta para sair do rebaixamento');
    } else if (nextElo != null && elo.promotionSlots > 0) {
      targetScore = promotionCutoffScore > 0 ? promotionCutoffScore + 1 : 1;
      goalLabel = context.tr(
        'Rumo ao Elo {elo} (Top {slots})',
        {'elo': nextElo.localizedName, 'slots': elo.promotionSlots},
      );
    } else {
      targetScore = promotionCutoffScore > 0 ? promotionCutoffScore : 1;
      goalLabel = context.tr('Disputa pela liderança em {elo}', {'elo': elo.localizedName});
    }

    final double progressRatio = targetScore <= 0
        ? 1.0
        : (board.currentUserWeeklyInsights / targetScore).clamp(0.0, 1.0);

    return SoftClayCard(
      key: const Key('ranking_elo_track_card'),
      padding: EdgeInsets.all(isDesktop ? 22 : 16),
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
                        context.tr(
                          'ESCALA NOÉTICA · NÍVEL {level} DE {total}',
                          {'level': elo.index + 1, 'total': totalTiers},
                        ),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('Elo atual: {name}', {'name': elo.localizedName}),
                        style: GoogleFonts.manrope(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: elo.accentColor,
                        ),
                      ),
                      Text(
                        elo.localizedSubtitle,
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
                        alignment: AlignmentDirectional.centerStart,
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
                      context.tr('Toque em qualquer elo abaixo para ver detalhes'),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 760 ? 4 : (w >= 280 ? 2 : 1);
              const gap = 10.0;
              final tileW = (w - (cols - 1) * gap) / cols;

              final tiles = [
                _summaryKpiTile(
                  context,
                  label: context.tr('POSIÇÃO NA LIGA'),
                  value: '#${board.currentUserRank}',
                  subtitle: context.tr('de {count} ativos nesta semana', {'count': standings.length}),
                  accent: elo.accentColor,
                  icon: Icons.emoji_events_rounded,
                ),
                _summaryKpiTile(
                  context,
                  key: const Key('ranking_weekly_insights_kpi'),
                  label: context.tr('INSIGHTS DA SEMANA'),
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
                  label: context.tr('PONTUAÇÃO ACUMULADA'),
                  value: context.tr('{points} pts', {'points': board.accumulatedRankingScore}),
                  subtitle: context.tr(
                    board.retentionStreakWeeks == 1
                        ? '{weeks} sem. seguida mantida · próx. +{next} pts'
                        : '{weeks} sem. seguidas mantidas · próx. +{next} pts',
                    {
                      'weeks': board.retentionStreakWeeks,
                      'next': RankingEloCatalog.maintenancePointsForStreak(
                        streakWeeks: board.retentionStreakWeeks + 1,
                        eloIndex: board.currentEloIndex,
                      ),
                    },
                  ),
                  accent: AsterConstants.ambar,
                  icon: Icons.local_fire_department_rounded,
                ),
                _summaryKpiTile(
                  context,
                  label: context.tr('MELHOR ELO'),
                  value: board.bestElo.localizedName,
                  subtitle: context.tr(
                    board.top3Finishes == 1
                        ? '{top3} pódio Top 3 · {weeks} sem.'
                        : '{top3} pódios Top 3 · {weeks} sem.',
                    {'top3': board.top3Finishes, 'weeks': board.weeksCompeted},
                  ),
                  accent: AsterTheme.primary(context),
                  icon: Icons.workspace_premium_rounded,
                ),
              ];

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final tile in tiles) SizedBox(width: tileW, child: tile),
                ],
              );
            },
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
                  PositionedDirectional(
                    end: -2,
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
                  PositionedDirectional(
                    end: -2,
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
              tier.localizedName,
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
                isCurrent ? context.tr('Atual') : context.tr('Nível {level}', {'level': tier.index + 1}),
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
      statusText = context.tr('Seu elo atual');
      statusColor = tier.accentColor;
    } else if (isNext) {
      statusText = context.tr('Próxima conquista');
      statusColor = AsterConstants.menta;
    } else if (isUnlocked) {
      statusText = context.tr('Já alcançado');
      statusColor = AsterTheme.primary(context);
    } else {
      statusText = context.tr('A desbloquear');
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width >= 900
                      ? 580
                      : MediaQuery.sizeOf(context).width - 88,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NoesisEloBadge(
                      tier: tier,
                      size: 28,
                      locked: !isUnlocked,
                      highlighted: isCurrent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Elo {name} · {subtitle}',
                          {'name': tier.localizedName, 'subtitle': tier.localizedSubtitle},
                        ),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SoftClayTag(label: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tier.localizedMilestoneDescription,
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
                    ? context.tr('Promoção: Top {slots} da chave', {'slots': tier.promotionSlots})
                    : context.tr('Topo da Escala Noética'),
                color: AsterConstants.menta,
              ),
              _rulePill(
                context,
                icon: tier.demotionSlots > 0
                    ? Icons.arrow_downward_rounded
                    : Icons.verified_user_outlined,
                label: tier.demotionSlots > 0
                    ? context.tr('Rebaixamento: últimos {slots}', {'slots': tier.demotionSlots})
                    : context.tr('Sem rebaixamento'),
                color: tier.demotionSlots > 0 ? AsterConstants.coral : AsterTheme.primary(context),
              ),
              _rulePill(
                context,
                icon: Icons.local_fire_department_rounded,
                label: context.tr(
                  'Permanência: +{points} pts e +{insights} Insights (cresce a cada semana)',
                  {'points': nextRetentionPts, 'insights': nextRetentionInsights},
                ),
                color: AsterConstants.ambar,
              ),
              _rulePill(
                context,
                icon: Icons.auto_awesome_rounded,
                label: tier.index == 0
                    ? context.tr(
                        'Economia: Ganho base (1×) · Limite {cap}/dia',
                        {'cap': InsightsEconomyConfig.dailySoftCapForElo(0)},
                      )
                    : context.tr(
                        'Bônus do Elo: +{bonus}% Insights · Limite {cap}/dia (2× no VIP)',
                        {
                          'bonus': InsightsEconomyConfig.eloBonusPercent(tier.index),
                          'cap': InsightsEconomyConfig.dailySoftCapForElo(tier.index),
                        },
                      ),
                color: tier.accentColor,
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
                    context.tr(
                      'RECOMPENSA POR COLOCAÇÃO AO SUBIR PARA {elo}',
                      {'elo': RankingEloCatalog.tierAt(tier.index + 1).localizedName.toUpperCase()},
                    ),
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
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
            context.tr('PÓDIO DA SEMANA'),
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
            competitor.isCurrentUser ? context.tr('Você') : competitor.displayName.split(' ').first,
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
                  fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w800,
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
      title = context.tr(
        'Promoção semanal (#{rank})! Você subiu de {prev} para Elo {next}!',
        {'rank': outcome.finalRank, 'prev': prev.localizedName, 'next': next.localizedName},
      );
    } else if (outcome.wasDemoted) {
      accent = AsterConstants.coral;
      icon = Icons.arrow_circle_down_rounded;
      title = context.tr(
        'Fechamento da semana anterior: você foi movido para Elo {next}.',
        {'next': next.localizedName},
      );
    } else {
      accent = AsterTheme.primary(context);
      icon = Icons.check_circle_outline_rounded;
      final streakPart = outcome.retentionStreakWeeks > 0
          ? context.tr(' · {weeks}ª sem. seguida', {'weeks': outcome.retentionStreakWeeks})
          : '';
      title = context.tr(
        'Semana anterior encerrada (#{rank}) · Você manteve o Elo {next}{streakPart}.',
        {'rank': outcome.finalRank, 'next': next.localizedName, 'streakPart': streakPart},
      );
    }

    final rewardSummary = <String>[
      if (outcome.rewardInsights > 0)
        context.tr('+{insights} Insights na carteira', {'insights': outcome.rewardInsights}),
      if (outcome.pointsEarned > 0)
        context.tr('+{points} pts acumulados', {'points': outcome.pointsEarned}),
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
                  context.tr(
                    '{title} (+{insights} Insights na semana {weekId})',
                    {'title': title, 'insights': outcome.weeklyInsights, 'weekId': outcome.weekId},
                  ),
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
                if (rewardSummary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    context.tr('Recompensa recebida: {summary}', {'summary': rewardSummary}),
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
            tooltip: context.tr('Dispensar aviso'),
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
                  fontWeight: FontWeight.w800,
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
        return NoesisL10n.tr('Zona de Promoção ↑');
      case RankingZone.safe:
        return NoesisL10n.tr('Zona Segura');
      case RankingZone.demotion:
        return NoesisL10n.tr('Zona de Rebaixamento ↓');
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
          ? NoesisL10n.tr('Subindo para {elo}!', {'elo': nextElo.localizedName})
          : NoesisL10n.tr('No topo da escala Noesis!');
    }
    if (zone == RankingZone.demotion && prevElo != null) {
      return NoesisL10n.tr('Atenção: risco de descer para {elo}', {'elo': prevElo.localizedName});
    }
    if (nextElo != null && promotionSlots > 0 && pointsToPromotion > 0) {
      return NoesisL10n.tr(
        'Faltam +{points} para o Top {slots}',
        {'points': pointsToPromotion, 'slots': promotionSlots},
      );
    }
    return NoesisL10n.tr('Mantendo seu elo esta semana');
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
        text = context.tr(
          'ZONA DE PROMOÇÃO · TOP {slots} SOBEM PARA {elo}',
          {'slots': promotionSlots, 'elo': nextElo?.localizedName.toUpperCase() ?? ''},
        );
      case RankingZone.safe:
        icon = Icons.horizontal_rule_rounded;
        text = context.tr('ZONA DE PERMANÊNCIA · MANTÉM O ELO');
      case RankingZone.demotion:
        icon = Icons.arrow_downward_rounded;
        text = context.tr(
          'ZONA DE REBAIXAMENTO · ÚLTIMOS {slots} DESCEM PARA {elo}',
          {'slots': demotionSlots, 'elo': prevElo?.localizedName.toUpperCase() ?? ''},
        );
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
                      fontWeight: FontWeight.w800,
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
                              label: context.tr('Você'),
                              color: primaryCol,
                            ),
                          if (c.isVip)
                            const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          '@{username} · {duration} na semana · {streak}d streak',
                          {
                            'username': c.username,
                            'duration': DashboardAnalytics.formatReadableDuration(c.weeklyMinutes),
                            'streak': c.streakDays,
                          },
                        ),
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
                          fontWeight: FontWeight.w800,
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
