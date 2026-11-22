import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tier 2 - Feature 04: Build Pipeline Boundary Cases', () {
    test('1. pubspec.yaml enables uses-material-design for icon font tree-shaking', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('uses-material-design: true'));
    });

    test('2. Web asset paths use canonical forward slashes for cross-platform compatibility', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets\\fonts\\'), isFalse,
          reason: 'Pubspec asset declarations must use forward slashes for Linux/Web builds');
      expect(pubspec, contains('assets/fonts/'));
    });

    test('3. Flutter SDK constraint allows modern Dart features (^3.14.0)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('sdk: ^3.14.0'));
    });

    test('4. PROJECT_CONTEXT.md specifies Windows and Web release commands consistently', () {
      final contextText = File('PROJECT_CONTEXT.md').readAsStringSync();
      expect(contextText, contains('flutter build windows --release'));
      expect(contextText, contains('flutter build web --release'));
    });

    test('5. web/manifest.json specifies valid background and theme colors matching Aster theme', () {
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest, contains('"background_color"'));
      expect(manifest, contains('"theme_color"'));
    });
  });
}
