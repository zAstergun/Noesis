import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import '../harness/test_app_harness.dart';
import '../harness/mock_http_overrides.dart';
import '../harness/test_fixtures.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() {
    MockHttpOverrides.reset();
    GeminiService.initialize('test-isolate-key');
  });

  group('Feature 13: Background Processing Isolates & Production Parser Routines', () {
    test('1. compute(utf8.decode) decodes large RAG byte array in background isolate', () async {
      final sampleText = TestFixtures.sampleRagDocument * 100;
      final bytes = utf8.encode(sampleText);

      final decoded = await compute(utf8.decode, bytes);
      expect(decoded.length, equals(sampleText.length));
      expect(decoded, contains('CompTIA Security+ SY0-701'));
    });

    test('2. GeminiService.generateQuiz parses valid JSON response payload', () async {
      MockHttpOverrides.customResponseBody = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': TestFixtures.validQuizJson()}
              ]
            }
          }
        ]
      });

      final questions = await GeminiService.generateQuiz(
        subject: 'Criptografia',
        topic: 'Modos de Operação',
        numberOfQuestions: 3,
      );

      expect(questions.length, equals(3));
      expect(questions.first['question'], contains('ECB'));
      expect(questions.first['correct_index'], equals(1));
    });

    test('3. GeminiService.generateQuiz strips markdown code fences (```json)', () async {
      MockHttpOverrides.customResponseBody = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': TestFixtures.markdownFencedQuizJson()}
              ]
            }
          }
        ]
      });

      final questions = await GeminiService.generateQuiz(
        subject: 'Criptografia',
        topic: 'Code Fences',
      );

      expect(questions.isNotEmpty, isTrue);
      expect(questions.first['options'], isA<List>());
      expect((questions.first['options'] as List).length, equals(4));
    });

    test('4. GeminiService.generateQuiz handles nested { "questions": [...] } schema', () async {
      MockHttpOverrides.customResponseBody = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': TestFixtures.nestedQuizJson()}
              ]
            }
          }
        ]
      });

      final questions = await GeminiService.generateQuiz(
        subject: 'Criptografia',
        topic: 'Nested Schema',
        numberOfQuestions: 1,
      );

      expect(questions.length, equals(1));
      expect(questions.first['question'], contains('AES-GCM'));
    });

    test('5. GeminiService.generateQuiz throws on malformed JSON syntax without uncaught crash', () async {
      MockHttpOverrides.customResponseBody = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': TestFixtures.malformedQuizJson}
              ]
            }
          }
        ]
      });

      expect(
        () async => await GeminiService.generateQuiz(
          subject: 'Criptografia',
          topic: 'Malformed Syntax',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
