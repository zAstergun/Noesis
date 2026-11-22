import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';
import '../harness/test_fixtures.dart';

List<Map<String, dynamic>> parseQuizBackground(String jsonString) {
  final clean = jsonString.trim();
  final decoded = jsonDecode(clean);
  return List<Map<String, dynamic>>.from(decoded as List);
}

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Background Isolates & Quiz Storage Interaction', () {
    test('1. Generated questions parsed via compute isolate feed directly into in-memory quiz score ledger', () async {
      final quizJson = TestFixtures.validQuizJson();

      // Parse questions off main thread
      final questions = await compute(parseQuizBackground, quizJson);
      expect(questions.length, equals(3));

      // Simulate student taking exam
      int correctAnswers = 0;
      final userAnswers = [1, 3, 0]; // All correct according to fixture

      for (int i = 0; i < questions.length; i++) {
        final expectedCorrect = questions[i]['correct_index'] as int;
        if (userAnswers[i] == expectedCorrect) {
          correctAnswers++;
        }
      }

      final scorePercent = (correctAnswers / questions.length) * 100;
      expect(scorePercent, equals(100.0));

      // Save to in-memory score record
      final quizResultRecord = {
        'quiz_id': 'quiz-comp-tia-1',
        'score': scorePercent,
        'total_questions': questions.length,
        'correct_count': correctAnswers,
        'completed_at': DateTime.now().toIso8601String(),
      };

      expect(quizResultRecord['score'], equals(100.0));
      expect(quizResultRecord['correct_count'], equals(3));
    });
  });
}
