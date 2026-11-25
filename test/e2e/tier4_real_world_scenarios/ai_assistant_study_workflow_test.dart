import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 2: Autonomous AI Assistant Study Session Logging', () {
    testWidgets(
        'Autonomous AI assistant loads real screen, shows conversation history, triggers action chip and sends message',
        (WidgetTester tester) async {
      GeminiService.initialize('dummy-gemini-key');

      await TestAppHarness.pumpInHarness(
        tester,
        const AiAssistantScreen(),
      );

      // Verify real AiAssistantScreen mounts
      expect(find.byType(AiAssistantScreen), findsOneWidget);

      // Verify initial capabilities showcase instead of fake chat history
      expect(find.text('O que o Noesis AI pode fazer por você'), findsOneWidget);
      expect(find.text('Calendário & Agenda'), findsOneWidget);
      expect(find.textContaining('Sessão de 1h30 salva em Criptografia'), findsNothing);

      // Verify contextual quick action chips generated from user's Noesis data
      expect(find.textContaining('🎴 Revisar'), findsOneWidget);
      expect(find.textContaining('🎯 Bater meta'), findsOneWidget);

      // Tap contextual quick action chip to send message
      final flashcardChip = find.textContaining('🎴 Revisar').first;
      await tester.tap(flashcardChip);
      await tester.pumpAndSettle();

      // Verify contextual user message is rendered in the real conversation
      expect(find.textContaining('cartões pendentes'), findsOneWidget);

      // Verify text input bar and send button are present and accessible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Drain any pending font or async callbacks
      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('AiAssistantScreen occupies full content area without 1000px constraint cutoff', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await TestAppHarness.pumpInHarness(
        tester,
        const AiAssistantScreen(),
        screenSize: const Size(1600, 1000),
      );

      final cardFinder = find.byType(AiAssistantScreen);
      expect(cardFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(cardFinder);
      expect(renderBox.size.width, equals(1600));

      await TestAppHarness.drainAsync(tester);
    });
  });
}
