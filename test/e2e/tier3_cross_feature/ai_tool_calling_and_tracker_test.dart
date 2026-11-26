import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';
import '../harness/mock_http_overrides.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() {
    MockHttpOverrides.reset();
  });

  group('Tier 3: AI Tool Calling & Study Session Tracker Interaction', () {
    test('1. GeminiService.executeAgentChat requests API key when unconfigured', () async {
      GeminiService.initialize('');
      final reply = await GeminiService.executeAgentChat(
        userMessage: 'Registre 1h30 de estudo de Criptografia',
        history: [],
      );

      expect(reply, contains('configure sua chave de API'));
    });

    test('2. GeminiService.executeAgentChat processes candidate responses hermetically', () async {
      GeminiService.initialize('test-ai-key');
      MockHttpOverrides.customResponseBody = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Sessão de Criptografia registrada com sucesso no Tracker!'}
              ]
            }
          }
        ]
      });

      final history = <Content>[];
      final reply = await GeminiService.executeAgentChat(
        userMessage: 'Registre 1h30 de estudo de Criptografia',
        history: history,
      );

      expect(reply, contains('Sessão de Criptografia registrada'));
    });

    test('3. SupabaseService starts without fake seeded calendar events', () async {
      final initialEvents = await SupabaseService.calendarEventsStream().first;
      expect(initialEvents.any((e) => (e['id'] as String).startsWith('mock-')), isFalse);
    });

    test('4. SupabaseService.addCalendarEvent updates in-memory calendar stream in Guest Mode', () async {
      final now = DateTime.now();
      await SupabaseService.addCalendarEvent(
        title: 'Revisão OWASP Top 10',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        category: 'review',
        description: 'Revisão agendada via ferramenta Noesis AI',
      );

      final events = await SupabaseService.getCalendarEvents();
      expect(events.any((e) => e['title'] == 'Revisão OWASP Top 10'), isTrue);
    });
  });
}
