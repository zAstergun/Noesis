import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';

void main() {
  group('Security hardening regression checks', () {
    test('GeminiService rejects non-HTTPS custom base URLs except loopback', () async {
      await expectLater(
        GeminiService.testConnection(
          providerId: 'custom',
          modelName: 'local-model',
          apiKey: '',
          baseUrl: 'http://evil.example.com/v1',
        ),
        throwsA(isA<Exception>()),
      );

      await expectLater(
        GeminiService.testConnection(
          providerId: 'custom',
          modelName: 'local-model',
          apiKey: '',
          baseUrl: 'file:///etc/passwd',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('GeminiService does not embed Google API key in query string', () {
      final source = File('lib/core/gemini_service.dart').readAsStringSync();
      expect(source.contains('?key='), isFalse);
      expect(source.contains('x-goog-api-key'), isTrue);
    });

    test('SupabaseService never grants VIP from user-editable userMetadata', () {
      final source = File('lib/core/supabase_service.dart').readAsStringSync();
      expect(source.contains("userMetadata?['is_vip']"), isFalse);
      expect(source.contains("meta['is_vip']"), isFalse);
      expect(source.contains("appMetadata['is_vip']"), isTrue);
    });

    test('web/_headers enforces HSTS and security headers', () {
      final headers = File('web/_headers').readAsStringSync();
      expect(headers, contains('Strict-Transport-Security:'));
      expect(headers, contains('X-Content-Type-Options: nosniff'));
      expect(headers, contains('X-Frame-Options: SAMEORIGIN'));
      expect(headers, contains('Referrer-Policy:'));
      expect(headers, contains('Permissions-Policy:'));
    });
  });
}
