import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/features/flashcards/flashcards_screen.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import 'package:noesis/main.dart';
import '../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  testWidgets(
    'Mobile shell renders fixed 5-slot bottom bar, organized Menu Hub, and zero layout overflows across all 14 tabs and active study flows at 360x780',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await TestAppHarness.pumpInHarness(
        tester,
        const NoesisApp(),
        screenSize: const Size(360, 780),
      );
      await tester.pumpAndSettle();

      final guestBtn = find.textContaining('Entrar sem login');
      if (guestBtn.evaluate().isNotEmpty) {
        await tester.tap(guestBtn.first);
        await tester.pumpAndSettle();
      }

      // 5 slots fixos na barra inferior: Dashboard, Simulados, Flashcards, Noesis AI, Menu
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Simulados'), findsAtLeastNWidgets(1));
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Noesis AI'), findsOneWidget);
      expect(find.byKey(const Key('mobile_menu_button')), findsOneWidget);
      expect(find.byKey(const Key('notifications_bell_button')), findsOneWidget);
      expect(find.byKey(const Key('header_wallet_pill')), findsOneWidget);

      // Abre o Menu Hub mobile e verifica busca + seções + metas
      await tester.tap(find.byKey(const Key('mobile_menu_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile_menu_hub_sheet')), findsOneWidget);
      expect(find.byKey(const Key('mobile_menu_daily_goal_card')), findsOneWidget);
      expect(find.byKey(const Key('mobile_menu_weekly_goal_card')), findsOneWidget);
      expect(find.text('ESTUDO'), findsOneWidget);
      expect(find.text('ROTINA & IA'), findsOneWidget);
      expect(find.text('COMUNIDADE'), findsOneWidget);
      expect(find.text('CONTA'), findsOneWidget);

      // Testa filtro de busca no Menu Hub
      await tester.enterText(
        find.widgetWithText(TextField, 'Ir para módulo ou ferramenta...'),
        'Ranking',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile_menu_item_11')), findsOneWidget);
      expect(find.byKey(const Key('mobile_menu_item_3')), findsNothing);

      // Navega para Ranking pelo Menu Hub e verifica barra superior contextual
      await tester.tap(find.byKey(const Key('mobile_menu_item_11')));
      await tester.pumpAndSettle();
      expect(RootScreen.activeTabNotifier.value, 11);
      expect(find.byKey(const Key('mobile_topbar_menu_pill')), findsOneWidget);

      // Visita todas as 14 abas no viewport 360x780 para garantir zero overflow
      for (int tabIndex = 0; tabIndex < 14; tabIndex++) {
        RootScreen.switchTab(tabIndex);
        await tester.pumpAndSettle();
        expect(
          errors,
          isEmpty,
          reason: 'Erro de layout/overflow encontrado na aba $tabIndex: ${errors.map((e) => e.exceptionAsString()).join('\n')}',
        );
      }

      // Testa Simulado ativo em tela 360x780
      QuizScreen.startQuiz(
        title: 'Simulado Mobile Audit',
        subject: 'Redes',
        questions: [
          {
            'question': 'Qual camada do modelo OSI realiza o roteamento lógico de pacotes?',
            'options': ['Enlace', 'Rede', 'Transporte', 'Aplicação'],
            'correct_index': 1,
            'explanation': 'A camada de Rede (Camada 3) trata de endereçamento lógico e roteamento.',
          },
        ],
      );
      RootScreen.switchTab(1);
      await tester.pumpAndSettle();
      expect(errors, isEmpty, reason: 'Erro no Simulado ativo mobile: $errors');

      // Testa Flashcard em estudo em tela 360x780
      FlashcardsScreen.startDeck(
        FlashcardDeck(
          id: 'mobile-audit-deck',
          title: 'Baralho de Arquitetura Distribuída',
          subject: 'Sistemas',
          description: 'Teste de responsividade',
          cards: [
            Flashcard(
              id: 'mobile-audit-card-1',
              front: 'O que garante o teorema CAP?',
              back: 'Consistência, Disponibilidade e Tolerância a Particionamento.',
              difficulty: 'unreviewed',
            ),
          ],
          createdAt: DateTime(2026, 11, 25),
        ),
      );
      RootScreen.switchTab(2);
      await tester.pumpAndSettle();
      expect(errors, isEmpty, reason: 'Erro no estudo de Flashcards mobile: $errors');

      // Testa Cadernos Master-Detail em tela 360x780
      RootScreen.switchTab(3);
      await tester.pumpAndSettle();
      final openNotebookBtn = find.textContaining('Abrir Caderno');
      if (openNotebookBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(openNotebookBtn.first);
        await tester.tap(openNotebookBtn.first);
        await tester.pumpAndSettle();
        expect(errors, isEmpty, reason: 'Erro ao abrir caderno no mobile: $errors');
      }

      await TestAppHarness.drainAsync(tester);
    },
  );
}
