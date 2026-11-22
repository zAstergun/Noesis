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
        'Autonomous AI assistant loads real screen, shows conversation history, triggers action chip and voice dialog',
        (WidgetTester tester) async {
      GeminiService.initialize('dummy-gemini-key');

      await TestAppHarness.pumpInHarness(
        tester,
        const AiAssistantScreen(),
      );

      // Verify real AiAssistantScreen mounts
      expect(find.byType(AiAssistantScreen), findsOneWidget);

      // Verify conversation history messages from initState
      expect(find.textContaining('Sessão de 1h30 salva em Criptografia'), findsOneWidget);

      // Verify quick action chips
      expect(find.text('✨ Criar simulado sobre OWASP'), findsOneWidget);
      expect(find.text('✨ Agendar revisão sexta às 14h'), findsOneWidget);
      expect(find.text('✨ Resumo de Criptografia'), findsOneWidget);

      // Tap quick action chip to send message
      await tester.tap(find.text('✨ Resumo de Criptografia'));
      await tester.pumpAndSettle();

      // Verify user message is rendered in the real conversation
      expect(find.text('Faça um resumo dos principais conceitos de Criptografia'), findsOneWidget);

      // Open voice input dialog
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();

      // Verify voice command list in modal
      expect(find.textContaining('Registre 1h30 de estudo de Criptografia'), findsOneWidget);

      // Drain any pending font or async callbacks
      await TestAppHarness.drainAsync(tester);
    });
  });
}
