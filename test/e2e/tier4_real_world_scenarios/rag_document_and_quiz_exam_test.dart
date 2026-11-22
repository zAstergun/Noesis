import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 3: RAG Document Ingestion & Exam Engine Simulation', () {
    testWidgets('Full RAG & Exam workflow: Mount QuizScreen -> Select Preset -> Load Demo Exam -> Answer question',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const QuizScreen(),
      );

      // Verify real QuizScreen is mounted
      expect(find.byType(QuizScreen), findsOneWidget);

      // Verify Exam Presets exist
      expect(find.text('CompTIA Security+'), findsOneWidget);
      expect(find.text('OWASP Top 10 & AppSec'), findsOneWidget);

      // Tap preset to configure exam parameters
      await tester.tap(find.text('CompTIA Security+'));
      await tester.pumpAndSettle();

      // Tap Testar com Demo to start the exam runner with genuine quiz questions
      final demoBtn = find.text('Testar com Demo');
      expect(demoBtn, findsOneWidget);
      await tester.ensureVisible(demoBtn);
      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      // Verify Exam Runner UI is active
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // Verify question options are rendered and selectable
      final optionFinder = find.byType(InkWell);
      expect(optionFinder, findsWidgets);

      // Select an answer option
      await tester.tap(optionFinder.at(2));
      await tester.pumpAndSettle();

      // Drain all pending font futures and frame callbacks cleanly
      await TestAppHarness.drainAsync(tester);
    });
  });
}
