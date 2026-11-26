import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/insights_economy_config.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/flashcards/flashcards_screen.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import 'package:noesis/features/ranking/data/ranking_service.dart';
import 'package:noesis/features/shop/shop_screen.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/insight_gain_toast_overlay.dart';
import 'package:noesis/widgets/insight_icon.dart';
import '../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    SupabaseService.setVipForTesting(false);
    await AsterTheme.resetCustomThemeForTesting();
    AsterTheme.selectThemeOption('soft_clay_nevoa');
    await ShopService.instance.resetForTesting();
  });

  tearDown(() async {
    SupabaseService.setVipForTesting(false);
    await AsterTheme.resetCustomThemeForTesting();
    AsterTheme.selectThemeOption('soft_clay_nevoa');
    await ShopService.instance.resetForTesting();
  });

  test('Insights Economy v1 config, ledger balance, welcome bonus, and anti-abuse rules', () async {
    expect(InsightsEconomyConfig.currencyName, 'Insights');
    expect(InsightsEconomyConfig.currencySymbol, '✦');

    // Soma dos 10 temas pagos = 6.300 Insights (3x300 + 4x600 + 3x1000)
    final paidSum = AsterTheme.availableThemes
        .where((t) => t.id != 'soft_clay_nevoa')
        .fold<int>(0, (acc, t) => acc + InsightsEconomyConfig.priceForTheme(t.id));
    expect(paidSum, 6300);

    final shop = ShopService.instance;
    DateTime fakeNow = DateTime(2026, 11, 25, 10, 0);
    await shop.resetForTesting(grantWelcomeBonus: true, customClock: () => fakeNow);

    // Bônus de boas-vindas (+100 ✦) registrado no ledger
    expect(shop.balance, 100);
    expect(shop.ledger.length, 1);
    expect(shop.ledger.first.id, 'welcome_bonus');
    expect(shop.todayEarnedInsights, 0); // boas-vindas não consome teto diário

    // Anti-abuso < 3s na questão de simulado não paga
    expect(
      shop.awardForQuizAnswer(
        isCorrect: true,
        elapsedSinceShown: const Duration(seconds: 2),
      ),
      0,
    );
    // >= 3s: +3 certa (+1 base + 2 extra), +1 respondida errada
    expect(
      shop.awardForQuizAnswer(
        isCorrect: true,
        elapsedSinceShown: const Duration(seconds: 4),
      ),
      3,
    );
    expect(
      shop.awardForQuizAnswer(
        isCorrect: false,
        elapsedSinceShown: const Duration(seconds: 5),
      ),
      1,
    );

    // Simulado concluído: decaimento 100% -> 50% -> 25%
    expect(
      shop.awardForExamCompletion(
        attemptId: 'att-1',
        groupKey: 'sec',
        scorePercentage: 85,
      ),
      50, // 20 + 30
    );
    // Idempotente no mesmo attemptId
    expect(
      shop.awardForExamCompletion(
        attemptId: 'att-1',
        groupKey: 'sec',
        scorePercentage: 85,
      ),
      0,
    );
    expect(
      shop.awardForExamCompletion(
        attemptId: 'att-2',
        groupKey: 'sec',
        scorePercentage: 80,
      ),
      25, // 50%
    );
    expect(
      shop.awardForExamCompletion(
        attemptId: 'att-3',
        groupKey: 'sec',
        scorePercentage: 90,
      ),
      13, // 25% de 50 arredondado
    );

    // Flashcard: só paga +1 se estiver na hora de revisar; 'hard' superado depois paga +2
    expect(
      shop.awardForFlashcardReview(
        cardId: 'c-not-due',
        difficulty: 'good',
        isDueForReview: false,
      ),
      0,
    );
    expect(
      shop.awardForFlashcardReview(
        cardId: 'c-due',
        difficulty: 'hard',
        isDueForReview: true,
      ),
      1,
    );
    // Superou o cartão difícil depois como 'good' -> +2 extra (mesmo com allowReviewBase: false)
    expect(
      shop.awardForFlashcardReview(
        cardId: 'c-due',
        difficulty: 'good',
        isDueForReview: true,
        wasPreviouslyHard: true,
        allowReviewBase: false,
      ),
      2,
    );

    // Teto diário suave (150 Insights/dia): estoura 150 com meta semanal (+150) e recebe metade após 150
    // Antes disso, ganhamos 3 + 1 + 50 + 25 + 13 + 1 + 2 = 95 hoje.
    expect(shop.todayEarnedInsights, 95);
    final weeklyPaid = shop.evaluateStudyProgressRewards(
      sessions: [
        {
          'id': 'real-1',
          'duration_minutes': 220,
          'study_date': '2026-11-25',
        },
        {
          'id': 'real-2',
          'duration_minutes': 60,
          'study_date': '2026-11-24',
        },
        {
          'id': 'real-3',
          'duration_minutes': 60,
          'study_date': '2026-11-23',
        },
      ],
      weeklyGoalMinutes: 300, // Meta dia ~43m (bateu 220m), Meta semanal 300m (bateu 340m), Streak 3d (+20)
      referenceDate: fakeNow,
    );
    // Sem teto seria 15 (dia) + 150 (semana) + 20 (3d streak) = 185.
    // Como faltavam 55 até 150: 15 (total 110) + [40 cheios + (110/2)=55 -> 95] (total 205) + 10 (metade de 20) = 120!
    expect(weeklyPaid, 120);

    // Compra idempotente de tema Essencial (300 Insights)
    await shop.resetForTesting(initialBalance: 350, customClock: () => fakeNow);
    final buy1 = await shop.purchaseTheme('aurora');
    expect(buy1.ok, isTrue);
    expect(shop.balance, 50);
    expect(shop.isThemeUnlocked('aurora'), isTrue);

    // Segunda chamada não cobra duas vezes
    final buy2 = await shop.purchaseTheme('aurora');
    expect(buy2.ok, isTrue);
    expect(shop.balance, 50);
  });

  testWidgets('Answering quizzes >= 3s and due flashcards awards Insights and Shop buys/equips/previews themes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DateTime fakeNow = DateTime(2026, 11, 25, 10, 0);
    await ShopService.instance.resetForTesting(customClock: () => fakeNow);

    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    // Card no Dashboard não colide mais com o nome da moeda e carteira usa 1 único InsightCoinIcon sem estrela dupla
    expect(find.text('Sugestão do agente'), findsOneWidget);
    expect(find.text('Insight do agente'), findsNothing);
    final headerWallet = find.byKey(const Key('header_wallet_pill'));
    expect(headerWallet, findsOneWidget);
    expect(
      find.descendant(of: headerWallet, matching: find.byType(InsightCoinIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: headerWallet, matching: find.textContaining('✦')),
      findsNothing,
    );

    // 1. Simulado: questão certa após >= 3 segundos dá +3 Insights
    QuizScreen.startQuiz(
      title: 'Simulado Economia',
      subject: 'Segurança',
      questions: [
        {
          'question': 'Qual protocolo protege tráfego HTTP na camada de transporte?',
          'options': ['FTP', 'TLS', 'SNMP', 'ICMP'],
          'correct_index': 1,
          'explanation': 'TLS cifra a comunicação HTTPS.',
        },
      ],
    );
    RootScreen.switchTab(1);
    await tester.pumpAndSettle();

    // Avança o relógio 4 segundos para passar pela regra anti-abuso de >= 3s
    fakeNow = fakeNow.add(const Duration(seconds: 4));

    await tester.ensureVisible(find.text('TLS'));
    await tester.tap(find.text('TLS'));
    await tester.pumpAndSettle();

    expect(ShopService.instance.balance, 3);

    // 2. Flashcards: card na hora de revisar dá +1 Insight
    FlashcardsScreen.startDeck(
      FlashcardDeck(
        id: 'deck-shop-test',
        title: 'Baralho Insights',
        subject: 'Cloud',
        description: '',
        cards: [
          Flashcard(
            id: 'card-shop-1',
            front: 'O que é S3?',
            back: 'Object Storage da AWS.',
            difficulty: 'unreviewed',
          ),
        ],
        createdAt: fakeNow,
      ),
    );
    RootScreen.switchTab(2);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ver Resposta (Virar Cartão) 👆'));
    await tester.tap(find.text('Ver Resposta (Virar Cartão) 👆'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Bom'));
    await tester.tap(find.textContaining('Bom'));
    await tester.pumpAndSettle();

    expect(ShopService.instance.balance, 4);

    // 3. Abre a Loja, vê faixa de 300 ✦ e compra & pré-visualiza Aurora
    await tester.tap(find.text('Loja'));
    await tester.pumpAndSettle();
    expect(find.text('Loja do Noesis'), findsOneWidget);
    expect(find.byKey(const Key('shop_section_all')), findsOneWidget);
    expect(find.byKey(const Key('shop_section_themes')), findsOneWidget);
    expect(find.byKey(const Key('shop_section_arsenal')), findsOneWidget);
    expect(find.byKey(const Key('shop_section_identity')), findsOneWidget);
    expect(find.byKey(const Key('shop_legendary_card')), findsOneWidget);
    expect(find.text('Temas Especiais'), findsOneWidget);
    expect(find.text('Temas Lendários'), findsNothing);
    final shopBadge = find.byKey(const Key('shop_balance_badge'));
    expect(
      find.descendant(of: shopBadge, matching: find.byType(InsightCoinIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: shopBadge, matching: find.textContaining('✦')),
      findsNothing,
    );

    await ShopService.instance.resetForTesting(
      initialBalance: 250,
      grantWelcomeBonus: true,
      customClock: () => fakeNow,
    );
    await tester.pumpAndSettle();

    // Bônus de boas-vindas não aparece na Loja (vai para Notificações)
    expect(find.text('Bônus de boas-vindas'), findsNothing);

    final auroraCard = find.byKey(const Key('shop_card_aurora'));
    await tester.ensureVisible(auroraCard);
    await tester.tap(auroraCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop_theme_preview_modal')), findsOneWidget);
    await tester.tap(find.byKey(const Key('preview_buy_aurora')));
    await tester.pumpAndSettle();

    expect(ShopService.instance.isThemeUnlocked('aurora'), isTrue);
    expect(ShopService.instance.balance, 50);

    await tester.tap(find.byKey(const Key('preview_equip_aurora')));
    await tester.pumpAndSettle();
    expect(AsterTheme.activeThemeIdNotifier.value, 'aurora');

    // 4. Verifica que em Configurações tema não comprado (Grafite 1000 ✦) exige compra na Loja
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    final grafiteConfig = find.byKey(const Key('theme_option_grafite'));
    await tester.ensureVisible(grafiteConfig);
    await tester.tap(grafiteConfig);
    await tester.pumpAndSettle();
    expect(AsterTheme.activeThemeIdNotifier.value, 'aurora');
    expect(find.textContaining('1000 ✦ Insights'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('VIP Custom theme preview allows live RGB editing in mockup and saves when VIP', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SupabaseService.setVipForTesting(false);
    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Loja'));
    await tester.pumpAndSettle();

    final customCard = find.byKey(const Key('shop_card_custom'));
    await tester.ensureVisible(customCard);
    await tester.tap(customCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop_theme_preview_modal')), findsOneWidget);
    expect(find.byKey(const Key('preview_toggle_rgb_button')), findsOneWidget);

    // Não-VIP pode abrir o editor RGB na prévia e testar cores em tempo real no mockup
    await tester.tap(find.byKey(const Key('preview_toggle_rgb_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vip_custom_theme_editor')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('vip_rgb_hex_field')));
    await tester.enterText(find.byKey(const Key('vip_rgb_hex_field')), '#00FFAA');
    await tester.pumpAndSettle();

    expect(find.text('#00FFAA'), findsAtLeastNWidgets(1));
    final canvasContainer = tester.widget<Container>(find.byKey(const Key('preview_mockup_canvas')));
    final canvasDec = canvasContainer.decoration! as BoxDecoration;
    // Borda do canvas usa option.primary com alpha 0.35 -> RGB acompanha #00FFAA
    expect((canvasDec.border!.top.color.g * 255).round(), 255);
    // App real continua sem o tema VIP ativado para não-VIP
    expect(AsterTheme.activeThemeIdNotifier.value, isNot(AsterTheme.customThemeId));

    // Ativa VIP enquanto a prévia está aberta -> exibe botão "Salvar e Equipar" e aplica no app
    SupabaseService.setVipForTesting(true);
    await tester.pumpAndSettle();

    final applyBtn = find.byKey(const Key('preview_apply_custom_button'));
    expect(applyBtn, findsOneWidget);
    await tester.ensureVisible(applyBtn);
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();

    expect(AsterTheme.activeThemeIdNotifier.value, AsterTheme.customThemeId);
    expect(AsterTheme.customThemeColorsNotifier.value.primary, const Color(0xFF00FFAA));

    await TestAppHarness.drainAsync(tester);
  });

  test('Streak Protector purchases preserve streak across missed days without inflating streak count', () async {
    final shop = ShopService.instance;
    final today = DateTime(2026, 11, 26, 9, 0);
    await shop.resetForTesting(initialBalance: 400, customClock: () => today);

    // Compra 1 Protetor de Ofensiva (180 Insights)
    final buy = await shop.purchaseStreakProtector();
    expect(buy.ok, isTrue);
    expect(shop.streakProtectors, 1);
    expect(shop.balance, 220);

    // Estudou dias 23 e 24 (2 dias), faltou dia 25 (ontem em relação a 26/11)
    final sessions = [
      {'id': 's1', 'duration_minutes': 45, 'study_date': '2026-11-23'},
      {'id': 's2', 'duration_minutes': 30, 'study_date': '2026-11-24'},
    ];
    expect(
      SupabaseService.computeCurrentStreakDays(sessions, referenceDate: today),
      0,
    );

    final consumed = await shop.reconcileStreakProtectors(sessions, referenceDate: today);
    expect(consumed, 1);
    expect(shop.streakProtectors, 0);
    expect(
      SupabaseService.computeCurrentStreakDays(
        sessions,
        referenceDate: today,
        protectedDates: shop.protectedStreakDates,
      ),
      2,
    );
  });

  testWidgets('Shop Arsenal section buys Streak Protector and shows Em breve sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await ShopService.instance.resetForTesting(initialBalance: 360);
    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Loja'));
    await tester.pumpAndSettle();

    // Filtra diretamente para Arsenal de Estudo
    await tester.tap(find.byKey(const Key('shop_section_arsenal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop_streak_protector_card')), findsOneWidget);
    expect(find.text('SELO DE CONSISTÊNCIA'), findsOneWidget);
    expect(find.text('COMO APARECE NA SUA CONSISTÊNCIA'), findsOneWidget);
    expect(find.text('dia protegido'), findsOneWidget);
    expect(find.text('0/5', findRichText: true), findsOneWidget);
    expect(find.text('Pacotes de decks prontos'), findsOneWidget);
    expect(find.text('Personas do Noesis AI'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop_buy_streak_protector')));
    await tester.pumpAndSettle();

    expect(ShopService.instance.streakProtectors, 1);
    expect(ShopService.instance.balance, 180);
    expect(find.text('1/5', findRichText: true), findsOneWidget);

    // Verifica no Dashboard ao lado da Consistência (1/5 selos + legenda Protegido)
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard_consistency_seals')), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    expect(find.textContaining('Protegido'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Loja'));
    await tester.pumpAndSettle();

    // Seção Identidade & Status (Capas, Molduras e Títulos à venda + VIP)
    await tester.tap(find.byKey(const Key('shop_section_identity')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop_identity_store_section')), findsOneWidget);
    expect(find.byKey(const Key('shop_identity_tab_banner')), findsOneWidget);
    expect(find.byKey(const Key('shop_identity_tab_frame')), findsOneWidget);
    expect(find.byKey(const Key('shop_identity_tab_title')), findsOneWidget);
    expect(find.text('Aurora Lavanda'), findsOneWidget);
    expect(find.text('Manto Imperial VIP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shop_identity_tab_title')));
    await tester.pumpAndSettle();
    expect(find.text('Mente Inquieta'), findsAtLeastNWidgets(1));
    expect(find.text('Mecenas VIP'), findsAtLeastNWidgets(1));

    // Ativa VIP na Loja -> card mostra modo ilimitado 2x Insights e libera VIP em Identidade
    SupabaseService.setVipForTesting(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop_vip_unlimited_pill')), findsOneWidget);
    expect(find.textContaining('Ilimitado'), findsAtLeastNWidgets(1));
    expect(find.text('Bônus VIP ativo · 2× Insights'), findsOneWidget);
    expect(find.text('Equipar VIP'), findsAtLeastNWidgets(1));

    await TestAppHarness.drainAsync(tester);
  });

  test('VIP earns 2x normal Insights with unlimited daily earning cap', () async {
    final shop = ShopService.instance;
    final fakeNow = DateTime(2026, 11, 25, 11, 0);
    SupabaseService.setVipForTesting(true);
    await shop.resetForTesting(customClock: () => fakeNow);

    // Questão certa >= 3s: normal 3 -> VIP 6; errada: normal 1 -> VIP 2
    expect(
      shop.awardForQuizAnswer(
        isCorrect: true,
        elapsedSinceShown: const Duration(seconds: 4),
      ),
      6,
    );
    expect(
      shop.awardForQuizAnswer(
        isCorrect: false,
        elapsedSinceShown: const Duration(seconds: 5),
      ),
      2,
    );

    // Simulado >= 80%: normal 50 -> VIP 100
    expect(
      shop.awardForExamCompletion(
        attemptId: 'vip-att-1',
        groupKey: 'sec',
        scorePercentage: 85,
      ),
      100,
    );

    // Flashcard na hora: normal 1 -> VIP 2; difícil superado: normal 2 -> VIP 4
    expect(
      shop.awardForFlashcardReview(
        cardId: 'vip-c1',
        difficulty: 'hard',
        isDueForReview: true,
      ),
      2,
    );
    expect(
      shop.awardForFlashcardReview(
        cardId: 'vip-c1',
        difficulty: 'good',
        isDueForReview: true,
        wasPreviouslyHard: true,
        allowReviewBase: false,
      ),
      4,
    );

    // Já ganhou 114 hoje; meta dia (30) + meta semana (300) + streak 3d (40) = 370 sem redução após 150!
    final progressPaid = shop.evaluateStudyProgressRewards(
      sessions: [
        {'id': 'v1', 'duration_minutes': 220, 'study_date': '2026-11-25'},
        {'id': 'v2', 'duration_minutes': 60, 'study_date': '2026-11-24'},
        {'id': 'v3', 'duration_minutes': 60, 'study_date': '2026-11-23'},
      ],
      weeklyGoalMinutes: 300,
      referenceDate: fakeNow,
    );
    expect(progressPaid, 370);
    expect(shop.balance, 484);
  });

  test('Standard protector cap is 5 while VIP doubles cap to 10 and grants 2 free protectors per month', () async {
    final shop = ShopService.instance;
    var clock = DateTime(2026, 11, 10, 10, 0);
    addTearDown(() => SupabaseService.setVipForTesting(null));

    // Usuário gratuito: máximo de 5 protetores
    SupabaseService.setVipForTesting(false);
    await shop.resetForTesting(
      initialBalance: 2500,
      initialStreakProtectors: 5,
      customClock: () => clock,
    );
    expect(shop.maxStreakProtectors, 5);
    expect(shop.streakProtectors, 5);
    final blockedFree = await shop.purchaseStreakProtector();
    expect(blockedFree.ok, isFalse);
    expect(blockedFree.error, contains('5'));

    // Usuário VIP: limite dobra para 10 e ganha 2 protetores gratuitos no mês (sem repetir no mesmo mês)
    SupabaseService.setVipForTesting(true);
    await shop.resetForTesting(
      initialBalance: 2500,
      initialStreakProtectors: 5,
      customClock: () => clock,
    );
    expect(shop.maxStreakProtectors, 10);

    final novGrant = await shop.grantMonthlyVipStreakProtectorsIfEligible();
    expect(novGrant, 2);
    expect(shop.streakProtectors, 7);
    expect(shop.balance, 2500); // gratuito, não desconta Insights
    expect(await shop.grantMonthlyVipStreakProtectorsIfEligible(), 0); // idempotente no mesmo mês

    // Novo mês (dezembro): ganha mais 2 gratuitamente até o limite de 10
    clock = DateTime(2026, 12, 1, 9, 0);
    final decGrant = await shop.grantMonthlyVipStreakProtectorsIfEligible();
    expect(decGrant, 2);
    expect(shop.streakProtectors, 9);

    // Pode comprar o 10º, mas o 11º é bloqueado pelo limite VIP de 10
    final tenth = await shop.purchaseStreakProtector();
    expect(tenth.ok, isTrue);
    expect(shop.streakProtectors, 10);

    final eleventh = await shop.purchaseStreakProtector();
    expect(eleventh.ok, isFalse);
    expect(eleventh.error, contains('10'));
  });

  testWidgets('Shop transaction ledger separates earned vs invested Insights cleanly',
      (WidgetTester tester) async {
    final shop = ShopService.instance;
    final fakeNow = DateTime(2026, 11, 25, 14, 30);
    addTearDown(() => SupabaseService.setVipForTesting(null));
    SupabaseService.setVipForTesting(true);
    await shop.resetForTesting(
      initialBalance: 0,
      customClock: () => fakeNow,
    );

    shop.awardForQuizAnswer(
      isCorrect: true,
      elapsedSinceShown: const Duration(seconds: 4),
    );
    shop.awardForFlashcardReview(
      cardId: 'tx-card-1',
      difficulty: 'good',
      isDueForReview: true,
      deckTitle: 'Redes',
    );
    // VIP ganha 100 por simulado >= 80%, garantindo >= 180 Insights no ledger para comprar 1 Selo
    shop.awardForExamCompletion(
      attemptId: 'tx-exam-1',
      groupKey: 'redes',
      scorePercentage: 90,
    );
    shop.awardForExamCompletion(
      attemptId: 'tx-exam-2',
      groupKey: 'sec',
      scorePercentage: 90,
    );

    final sealRes = await shop.purchaseStreakProtector();
    expect(sealRes.ok, isTrue);

    await TestAppHarness.pumpInHarness(
      tester,
      const ShopScreen(),
      screenSize: const Size(1280, 900),
    );

    final ledgerCard = find.byKey(const Key('shop_transactions_ledger_card'));
    await tester.ensureVisible(ledgerCard);
    await tester.pumpAndSettle();

    expect(ledgerCard, findsOneWidget);
    expect(find.text('CONQUISTADOS NOS ESTUDOS'), findsOneWidget);
    expect(find.text('INVESTIDOS NA LOJA'), findsOneWidget);
    expect(find.text('SALDO DISPONÍVEL'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('ledger_summary_spent')),
        matching: find.text('-180'),
      ),
      findsOneWidget,
    );

    // Filtra apenas Investidos -> mostra compra do Selo e oculta ganhos de estudo
    await tester.tap(find.byKey(const Key('transactions_filter_spent')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: ledgerCard,
        matching: find.textContaining('Selo de Consistência'),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(
        of: ledgerCard,
        matching: find.textContaining('Flashcard revisado'),
      ),
      findsNothing,
    );

    // Filtra apenas Conquistados -> mostra ganhos e oculta o gasto (-180) na lista filtrada
    await tester.tap(find.byKey(const Key('transactions_filter_earned')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: ledgerCard,
        matching: find.textContaining('Flashcard revisado'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: ledgerCard,
        matching: find.text('Investimento · Hoje · 14:30'),
      ),
      findsNothing,
    );

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets(
      'Free Consistency Seal granted every 100 answered questions and every 10h studied in a week respecting account limit',
      (WidgetTester tester) async {
    final shop = ShopService.instance;
    final fakeNow = DateTime(2026, 11, 25, 16, 0);
    addTearDown(() => SupabaseService.setVipForTesting(null));
    SupabaseService.setVipForTesting(false); // Limite da conta = 5

    await shop.resetForTesting(
      initialBalance: 0,
      initialStreakProtectors: 3,
      initialQuizQuestionsAnswered: 99,
      customClock: () => fakeNow,
    );
    expect(shop.streakProtectors, 3);
    expect(shop.questionsTowardNextFreeProtector, 99);

    // 100ª questão válida -> ganha +1 selo grátis (4/5)
    shop.awardForQuizAnswer(
      isCorrect: true,
      elapsedSinceShown: const Duration(seconds: 4),
    );
    expect(shop.totalQuizQuestionsAnswered, 100);
    expect(shop.questionsTowardNextFreeProtector, 0);
    expect(shop.streakProtectors, 4);

    // 10h (600m) estudadas na semana -> ganha +1 selo grátis (5/5, atingiu teto!)
    // Mesmo passando de 20h (1200m) na mesma semana, respeita o limite de 5 da conta.
    shop.evaluateStudyProgressRewards(
      sessions: const [
        {'id': 'w1', 'duration_minutes': 600, 'study_date': '2026-11-24'},
        {'id': 'w2', 'duration_minutes': 600, 'study_date': '2026-11-25'},
      ],
      weeklyGoalMinutes: 0,
      dailyGoalMinutes: 0,
      referenceDate: fakeNow,
    );
    expect(shop.streakProtectors, 5);

    // Verifica idempotência ao reavaliar mesma semana
    shop.evaluateStudyProgressRewards(
      sessions: const [
        {'id': 'w1', 'duration_minutes': 600, 'study_date': '2026-11-24'},
        {'id': 'w2', 'duration_minutes': 600, 'study_date': '2026-11-25'},
      ],
      weeklyGoalMinutes: 0,
      dailyGoalMinutes: 0,
      referenceDate: fakeNow,
    );
    expect(shop.streakProtectors, 5);

    // Para conta VIP (limite 10), estudar 20h na semana seguinte concede +2 selos grátis (600m e 1200m)
    SupabaseService.setVipForTesting(true);
    final nextWeek = DateTime(2026, 12, 2, 16, 0);
    await shop.resetForTesting(
      initialBalance: 0,
      initialStreakProtectors: 5,
      customClock: () => nextWeek,
    );
    shop.evaluateStudyProgressRewards(
      sessions: const [
        {'id': 'nw1', 'duration_minutes': 600, 'study_date': '2026-12-01'},
        {'id': 'nw2', 'duration_minutes': 600, 'study_date': '2026-12-02'},
      ],
      weeklyGoalMinutes: 0,
      dailyGoalMinutes: 0,
      referenceDate: nextWeek,
    );
    expect(shop.streakProtectors, 7);

    // UI da Loja informa claramente as duas regras
    await TestAppHarness.pumpInHarness(
      tester,
      const ShopScreen(),
      screenSize: const Size(1280, 900),
    );
    final infoBox = find.byKey(const Key('shop_free_seals_info_box'));
    await tester.ensureVisible(infoBox);
    await tester.pumpAndSettle();

    expect(infoBox, findsOneWidget);
    expect(find.textContaining('100 questões'), findsAtLeastNWidgets(1));
    expect(find.textContaining('10h estudadas na semana'), findsAtLeastNWidgets(1));
    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('InsightGainToastOverlay displays instant gain banner with amount and reason and auto-dismisses',
      (WidgetTester tester) async {
    await ShopService.instance.resetForTesting();

    await TestAppHarness.pumpInHarness(
      tester,
      const InsightGainToastOverlay(
        child: Scaffold(body: Center(child: Text('Conteúdo'))),
      ),
      screenSize: const Size(1280, 800),
    );

    // Ganho em questão certa de simulado
    final earnedQuiz = ShopService.instance.awardForQuizAnswer(
      isCorrect: true,
      elapsedSinceShown: const Duration(seconds: 5),
      subject: 'Redes',
    );
    expect(earnedQuiz, 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('insight_gain_toast_container')), findsOneWidget);
    expect(find.text('+3 Insights'), findsOneWidget);
    expect(find.text('Simulado'), findsOneWidget);
    expect(find.text('Questão certa no Simulado · Redes'), findsOneWidget);

    // Ganho de recompensa com texto no singular (+1 Insight)
    final earnedCard = ShopService.instance.awardForFlashcardReview(
      cardId: 'card_toast_1',
      difficulty: 'good',
      isDueForReview: true,
      deckTitle: 'TCP/IP',
    );
    expect(earnedCard, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('+1 Insight'), findsOneWidget);
    expect(find.text('Flashcard'), findsOneWidget);
    expect(find.text('Flashcard revisado · TCP/IP'), findsOneWidget);

    // Após o tempo de exibição, os avisos desaparecem automaticamente
    await tester.pump(const Duration(milliseconds: 3400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('insight_gain_toast_container')), findsNothing);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('Elo increases daily cap (+20/tier) and Insights gain (+10%/tier), and VIP doubles all bonuses',
      (WidgetTester tester) async {
    final shop = ShopService.instance;
    final fakeNow = DateTime(2026, 11, 25, 11, 0);
    addTearDown(() => SupabaseService.setVipForTesting(null));

    // Free no Elo 3 (Síntese): +30% ganho e limite diário = 150 + 3*20 = 210
    SupabaseService.setVipForTesting(false);
    await shop.resetForTesting(eloIndex: 3, customClock: () => fakeNow);
    expect(shop.currentDailySoftCap, 210);
    expect(shop.currentEloBonusPercent, 30);

    // Simulado >=80% (base 50) com +30% = 65 Insights
    final examFree = shop.awardForExamCompletion(
      attemptId: 'elo3-free-1',
      groupKey: 'elo3-g1',
      scorePercentage: 90,
    );
    expect(examFree, 65);

    // Segundo simulado igual em grupo diferente (+65 -> total 130) e meta semanal (+150*1.3 = 195):
    // Faltam 80 para o teto 210 -> 80 cheios + metade de 115 (57,5 -> 57 com 0.5 carry) = 137!
    final examFree2 = shop.awardForExamCompletion(
      attemptId: 'elo3-free-2',
      groupKey: 'elo3-g2',
      scorePercentage: 90,
    );
    expect(examFree2, 65);
    expect(shop.todayEarnedInsights, 130);

    final weeklyFree = shop.evaluateStudyProgressRewards(
      sessions: const [
        {'id': 'e1', 'duration_minutes': 300, 'study_date': '2026-11-25'},
      ],
      weeklyGoalMinutes: 300,
      dailyGoalMinutes: 0,
      referenceDate: fakeNow,
    );
    // 195 brutos: 80 até 210 + floor(115/2)=57 => 137
    expect(weeklyFree, 137);

    // Questões unitárias (+1 base) no Elo 1 (+10%) acumulam frações e pagam +11 em 10 questões
    await shop.resetForTesting(eloIndex: 1, customClock: () => fakeNow);
    int totalQ = 0;
    for (int i = 0; i < 10; i++) {
      totalQ += shop.awardForQuizAnswer(
        isCorrect: false,
        elapsedSinceShown: const Duration(seconds: 5),
      );
    }
    expect(totalQ, 11);

    // VIP no Elo 7 (Noesis, +70%) dobra tudo: (50 * 1.7) * 2 = 170, sem teto
    SupabaseService.setVipForTesting(true);
    await RankingService.instance.resetForTesting(
      currentEloIndex: 7,
      bestEloIndex: 7,
      customClock: () => fakeNow,
    );
    await shop.resetForTesting(eloIndex: 7, customClock: () => fakeNow);
    final examVip = shop.awardForExamCompletion(
      attemptId: 'elo7-vip-1',
      groupKey: 'elo7-g1',
      scorePercentage: 90,
    );
    expect(examVip, 170);

    // ShopScreen exibe corretamente os bônus de Elo + VIP
    await TestAppHarness.pumpInHarness(
      tester,
      const ShopScreen(),
      screenSize: const Size(1280, 900),
    );
    expect(find.byKey(const Key('shop_vip_unlimited_pill')), findsOneWidget);
    expect(find.textContaining('2× VIP · +70% Noesis'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });
}
