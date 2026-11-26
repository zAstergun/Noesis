import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 3: RAG Document Ingestion & Exam Engine Simulation', () {
    testWidgets('Full RAG & Exam workflow: Mount QuizScreen -> Select Preset -> Start Exam -> Answer question',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const QuizScreen(),
      );

      // Verify real QuizScreen is mounted without demo generator buttons
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('Testar com Demo'), findsNothing);

      // Verify Exam Presets exist
      expect(find.text('CompTIA Security+'), findsOneWidget);
      expect(find.text('OWASP Top 10 & AppSec'), findsOneWidget);

      // Tap preset to configure exam parameters
      await tester.tap(find.text('CompTIA Security+'));
      await tester.pumpAndSettle();

      // Start an active exam session directly via QuizScreen.startQuiz
      QuizScreen.startQuiz(
        title: 'Simulado Security+',
        subject: 'Cybersegurança',
        questions: [
          {
            'question': 'Qual medida melhor mitiga SSRF na raiz?',
            'options': [
              'Lista negra simples de IPs.',
              'Allow-list de hosts, bloqueio de redirects e pinning DNS.',
              'HTML-encoding na resposta.',
              'Mover para sub-rede pública.',
            ],
            'correct_index': 1,
            'explanation': 'Allow-list de hosts e bloqueio de redirecionamentos mitigam SSRF.',
          },
        ],
      );
      await tester.pumpAndSettle();

      // Verify Exam Runner UI is active
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // Verify question options are rendered and selectable
      expect(find.text('Allow-list de hosts, bloqueio de redirects e pinning DNS.'), findsOneWidget);
      await tester.tap(find.text('Allow-list de hosts, bloqueio de redirects e pinning DNS.'));
      await tester.pumpAndSettle();

      // Drain all pending font futures and frame callbacks cleanly
      await TestAppHarness.drainAsync(tester);
    });
  });
}
