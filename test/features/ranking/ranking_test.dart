import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/ranking/data/ranking_service.dart';
import 'package:noesis/features/ranking/models/ranking_league_model.dart';
import 'package:noesis/features/ranking/widgets/noesis_elo_badge.dart';
import 'package:noesis/features/tracker/dashboard_analytics.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    SupabaseService.setVipForTesting(null);
    RankingService.allowSyntheticPeersForTesting = true;
  });

  tearDown(() {
    RankingService.allowSyntheticPeersForTesting = false;
  });

  test('RankingService sums weekly Insights and promotes/maintains/demotes Elo across weekly cycles',
      () async {
    var fakeNow = DateTime(2026, 11, 25, 14, 0); // Quarta-feira (semana 2026-11-23)
    final shop = ShopService.instance;
    final ranking = RankingService.instance;

    await shop.resetForTesting(grantWelcomeBonus: true, customClock: () => fakeNow);
    await ranking.resetForTesting(
      currentEloIndex: 0,
      bestEloIndex: 0,
      customClock: () => fakeNow,
    );

    // Bônus de boas-vindas (+100) NÃO conta como Insight semanal competitivo
    expect(ranking.boardNotifier.value.currentUserWeeklyInsights, 0);

    // Usuário estuda e ganha +500 Insights na semana (250 em simulados + bonus VIP) -> vai para Top 1 (Zona de Promoção)
    SupabaseService.setVipForTesting(true);
    for (int i = 0; i < 5; i++) {
      shop.awardForExamCompletion(
        attemptId: 'rk-att-$i',
        groupKey: 'rk-$i',
        scorePercentage: 90,
      );
    }
    await ranking.syncCurrentUserProgress(referenceDate: fakeNow);

    final midWeek = ranking.boardNotifier.value;
    expect(midWeek.currentUserWeeklyInsights, 500);
    expect(midWeek.currentUserZone, RankingZone.promotion);
    expect(midWeek.currentUserRank, lessThanOrEqualTo(5));

    // Virada de semana (segunda seguinte: 2026-11-30) -> promove para Elo Vigília (eloIndex 1)!
    final balanceBeforePromotion = shop.balance;
    fakeNow = DateTime(2026, 11, 30, 9, 0);
    await ranking.syncCurrentUserProgress(referenceDate: fakeNow);
    final week2 = ranking.boardNotifier.value;
    expect(week2.currentEloIndex, 1);
    expect(week2.currentElo.name, 'Vigília');
    expect(week2.bestEloIndex, 1);
    expect(week2.weeksCompeted, 1);
    expect(week2.lastOutcome?.wasPromoted, isTrue);
    expect(week2.lastOutcome!.rewardInsights, greaterThan(0));
    expect(week2.lastOutcome!.pointsEarned, greaterThan(0));
    expect(week2.accumulatedRankingScore, week2.lastOutcome!.pointsEarned);
    // Recompensa de promoção cai na carteira sem inflar os Insights competitivos da nova semana
    expect(shop.balance, balanceBeforePromotion + week2.lastOutcome!.rewardInsights);
    expect(week2.currentUserWeeklyInsights, 0); // zera contagem para a nova semana
    expect(week2.currentUserZone, RankingZone.demotion); // com 0 na Vigília está na zona de rebaixamento

    // Garante que colocação melhor (#1) paga mais do que colocação inferior (#5)
    expect(
      RankingEloCatalog.promotionRewardInsights(finalRank: 1, targetEloIndex: 1),
      greaterThan(RankingEloCatalog.promotionRewardInsights(finalRank: 5, targetEloIndex: 1)),
    );

    // Manter-se no ranking acumula pontuações crescentes por sequência de semanas mantidas
    final ptsWeek1Stay = RankingEloCatalog.maintenancePointsForStreak(streakWeeks: 1, eloIndex: 1);
    final ptsWeek2Stay = RankingEloCatalog.maintenancePointsForStreak(streakWeeks: 2, eloIndex: 1);
    expect(ptsWeek2Stay, greaterThan(ptsWeek1Stay));

    // Simula duas semanas consecutivas mantendo o elo Vigília na Zona Segura (ex.: +200 Insights)
    await ranking.resetForTesting(
      currentEloIndex: 1,
      bestEloIndex: 1,
      customClock: () => fakeNow,
    );
    for (int cycle = 1; cycle <= 2; cycle++) {
      // Estuda na semana suficiente para ficar na Zona Segura (fora Top 5 e fora dos 3 últimos)
      // Em Vigília, +300 Insights posiciona o estudante na faixa segura (ranks #6..#9)
      for (int q = 1; q <= 3; q++) {
        shop.awardForExamCompletion(
          attemptId: 'stay-c$cycle-$q',
          groupKey: 'stay-$cycle-$q',
          scorePercentage: 90,
        ); // +100 (VIP) => +300 na semana
      }
      await ranking.syncCurrentUserProgress(referenceDate: fakeNow);

      // Fecha a semana avançando +7 dias
      fakeNow = fakeNow.add(const Duration(days: 7));
      await ranking.syncCurrentUserProgress(referenceDate: fakeNow);
    }
    final afterStay = ranking.boardNotifier.value;
    expect(afterStay.retentionStreakWeeks, 2);
    expect(afterStay.accumulatedRankingScore, ptsWeek1Stay + ptsWeek2Stay);

    // Fica sem estudar na semana seguinte -> cai de volta para Faísca (eloIndex 0) e zera sequência de permanência
    fakeNow = fakeNow.add(const Duration(days: 7));
    await ranking.syncCurrentUserProgress(referenceDate: fakeNow);
    final weekDemoted = ranking.boardNotifier.value;
    expect(weekDemoted.currentEloIndex, 0);
    expect(weekDemoted.currentElo.name, 'Faísca');
    expect(weekDemoted.bestEloIndex, 1); // preserva melhor elo histórico
    expect(weekDemoted.retentionStreakWeeks, 0);
    expect(weekDemoted.accumulatedRankingScore, ptsWeek1Stay + ptsWeek2Stay); // preserva pts já acumulados
    expect(weekDemoted.lastOutcome?.wasDemoted, isTrue);
  });

  testWidgets('Ranking tab in RootScreen displays Noesis Elos, interactive progression, podium, and competitor profile modal',
      (WidgetTester tester) async {
    final fakeNow = DateTime(2026, 11, 25, 15, 0);
    final shop = ShopService.instance;
    final ranking = RankingService.instance;

    await shop.resetForTesting(grantWelcomeBonus: true, customClock: () => fakeNow);
    await ranking.resetForTesting(
      currentEloIndex: 2, // Logos
      bestEloIndex: 2,
      top3Finishes: 1,
      weeksCompeted: 2,
      lastOutcome: const RankingWeekOutcome(
        weekId: '2026-11-16',
        previousEloIndex: 1,
        newEloIndex: 2,
        finalRank: 2,
        weeklyInsights: 420,
      ),
      customClock: () => fakeNow,
    );

    shop.awardForExamCompletion(
      attemptId: 'ui-rk-1',
      groupKey: 'sec',
      scorePercentage: 85,
    ); // +50 base +20% (Logos) = +60 Insights na semana

    await TestAppHarness.pumpInHarness(
      tester,
      const RootScreen(),
      screenSize: const Size(1440, 900),
    );
    final guestFinder = find.textContaining('Entrar sem login');
    if (guestFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestFinder.first);
      await tester.tap(guestFinder.first);
      await tester.pumpAndSettle();
    }

    // Navega até a nova aba Ranking no menu lateral
    final rankingNav = find.text('Ranking');
    expect(rankingNav, findsOneWidget);
    await tester.ensureVisible(rankingNav);
    await tester.tap(rankingNav);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ranking_screen_root')), findsOneWidget);
    expect(find.text('Ranking & Ligas Semanais'), findsOneWidget);
    expect(find.byKey(const Key('ranking_elo_track_card')), findsOneWidget);
    expect(find.byKey(const Key('ranking_promotion_progress')), findsOneWidget);
    expect(find.byKey(const Key('ranking_selected_elo_panel')), findsOneWidget);
    expect(find.byKey(const Key('ranking_elo_rewards_strip')), findsOneWidget);
    expect(find.byKey(const Key('ranking_accumulated_score_kpi')), findsOneWidget);
    expect(find.byKey(const Key('ranking_outcome_banner')), findsOneWidget);
    expect(find.byKey(const Key('ranking_podium_card')), findsOneWidget);

    for (final tier in RankingEloCatalog.tiers) {
      expect(find.byKey(Key('ranking_elo_tier_${tier.id}')), findsOneWidget);
    }
    expect(find.byType(NoesisEloBadge), findsAtLeastNWidgets(8));

    expect(find.text('Elo atual: Logos'), findsOneWidget);
    expect(find.text('+60'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('ranking_leaderboard_list')), findsOneWidget);
    expect(find.text('Você'), findsAtLeastNWidgets(1));

    // Inspeciona um elo futuro na trilha (Noesis) e verifica painel de detalhes
    final noesisNode = find.byKey(const Key('ranking_elo_tier_noesis'));
    await tester.ensureVisible(noesisNode);
    await tester.tap(noesisNode);
    await tester.pumpAndSettle();
    expect(find.textContaining('Elo Noesis · Intelecto pleno'), findsOneWidget);
    expect(find.text('Topo da Escala Noética'), findsOneWidget);

    // Abre perfil de um competidor ao clicar na linha e confere formatação separada de tempo
    final firstRival = ranking.boardNotifier.value.standings.firstWhere((c) => !c.isCurrentUser);
    final expectedFormattedTime = DashboardAnalytics.formatReadableDuration(firstRival.weeklyMinutes);
    expect(find.textContaining('$expectedFormattedTime na semana'), findsAtLeastNWidgets(1));

    final rivalRow = find.byKey(Key('ranking_row_${firstRival.userId}'));
    await tester.ensureVisible(rivalRow);
    await tester.tap(rivalRow);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public_profile_modal')), findsOneWidget);
    expect(find.byKey(const Key('public_profile_stats_grid')), findsOneWidget);
    expect(find.text('Tempo na semana'), findsOneWidget);
    expect(find.text('Sequência'), findsOneWidget);
    expect(find.text(expectedFormattedTime), findsOneWidget);
    expect(find.text('@${firstRival.username}'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    await TestAppHarness.drainAsync(tester);
  });
}
