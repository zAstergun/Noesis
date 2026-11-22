import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> parseQuestionsSafe(String text) {
  String clean = text.trim();
  if (clean.startsWith('```json')) clean = clean.substring(7);
  if (clean.startsWith('```')) clean = clean.substring(3);
  if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
  clean = clean.trim();

  if (clean.isEmpty) return [];

  final decoded = jsonDecode(clean);
  if (decoded is List) {
    return List<Map<String, dynamic>>.from(decoded);
  } else if (decoded is Map && decoded.containsKey('questions')) {
    return List<Map<String, dynamic>>.from(decoded['questions']);
  }
  return [];
}

String decodeBytesSafe(List<int> bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

void main() {
  group('Tier 2 - Feature 13: Background Isolates Boundary Cases', () {
    test('1. Empty byte array (0 bytes) decodes to empty string without error', () async {
      final decoded = await compute(decodeBytesSafe, <int>[]);
      expect(decoded, isEmpty);
    });

    test('2. Corrupted and invalid UTF-8 bytes decode gracefully using allowMalformed fallback', () async {
      // 0xFF and 0xC0 are invalid UTF-8 start bytes
      final corruptBytes = [0xFF, 0xC0, 0x65, 0x66];
      final result = await compute(decodeBytesSafe, corruptBytes);
      expect(result.isNotEmpty, isTrue);
      expect(result, contains('ef'));
    });

    test('3. Truncated JSON string throws FormatException rather than unhandled crash', () async {
      const truncated = '{"questions": [{"id": 1, "text": "Incom';
      expect(
        () async => await compute(parseQuestionsSafe, truncated),
        throwsA(isA<FormatException>()),
      );
    });

    test('4. Empty questions list in valid JSON payload parses to empty List', () async {
      final emptyQuestionsJson = jsonEncode({'questions': []});
      final result = await compute(parseQuestionsSafe, emptyQuestionsJson);
      expect(result, isEmpty);
    });

    test('5. 1MB synthetic UTF-8 payload decodes in isolate efficiently', () async {
      final largeString = 'A' * (1024 * 1024); // 1 MB
      final bytes = utf8.encode(largeString);

      final sw = Stopwatch()..start();
      final decoded = await compute(decodeBytesSafe, bytes);
      sw.stop();

      expect(decoded.length, equals(1024 * 1024));
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: '1MB decode in background isolate should complete rapidly');
    });
  });
}
