import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import '../../e2e/harness/mock_http_overrides.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() {
    MockHttpOverrides.reset();
  });

  test('GeminiService.sanitizeUserFacingReply strips internal tool names and DB identifiers', () {
    const leakedReply = '''
Aqui está tudo o que podemos fazer:
1. 📚 **Registro de Estudos** (`log_study_session`)
2. 📅 **Gestão de Calendário** (`schedule_calendar_event`)
3. 📝 **Criação de Simulados** (`create_quiz`)
4. 🧠 **Criação de Flashcards** (`create_flashcards`)

Seus dados ficam na tabela `noesis_sessions` do supabase.
''';

    final sanitized = GeminiService.sanitizeUserFacingReply(leakedReply);
    expect(sanitized, isNot(contains('log_study_session')));
    expect(sanitized, isNot(contains('schedule_calendar_event')));
    expect(sanitized, isNot(contains('create_quiz')));
    expect(sanitized, isNot(contains('create_flashcards')));
    expect(sanitized, isNot(contains('noesis_sessions')));
    expect(sanitized, isNot(contains('supabase')));
    expect(sanitized, contains('Registro de Estudos'));
    expect(sanitized, contains('Criação de Flashcards'));
  });

  test('GeminiService.executeAgentChat never exposes internal function names from LLM responses', () async {
    GeminiService.initialize('test-key');
    MockHttpOverrides.customResponseBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text':
                    '1. **Registro de Estudos** (`log_study_session`)\n2. **Criação de Simulados** (`create_quiz`)'
              }
            ]
          }
        }
      ]
    });

    final reply = await GeminiService.executeAgentChat(
      userMessage: 'o que você pode fazer?',
      history: [],
    );

    expect(reply, isNot(contains('log_study_session')));
    expect(reply, isNot(contains('create_quiz')));
    expect(reply, contains('Registro de Estudos'));
    expect(reply, contains('Criação de Simulados'));
  });

  testWidgets('AiAssistantScreen initial capabilities view does not expose internal code/DB calls', (tester) async {
    await TestAppHarness.pumpInHarness(tester, const AiAssistantScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('log_session()'), findsNothing);
    expect(find.textContaining('quiz.create()'), findsNothing);
    expect(find.textContaining('log_study_session'), findsNothing);
    expect(find.text('O que o Noesis AI pode fazer por você'), findsOneWidget);
    expect(find.text('Calendário & Agenda'), findsOneWidget);
    expect(find.byKey(const Key('ai_capabilities_overview')), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });
}
