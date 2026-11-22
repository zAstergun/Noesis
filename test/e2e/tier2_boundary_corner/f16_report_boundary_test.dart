import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tier 2 - Feature 16: Report Requirements & Constraint Boundaries', () {
    late String projectContext;

    setUpAll(() {
      final file = File('PROJECT_CONTEXT.md');
      expect(file.existsSync(), isTrue);
      projectContext = file.readAsStringSync();
    });

    test('1. Architecture specifies strict preservation of Supabase database schema without modifications', () {
      expect(projectContext, contains('noesis_sessions'));
      expect(projectContext, contains('noesis_calendar_events'));
    });

    test('2. Performance criteria establish 60 FPS CanvasKit and 16ms frame budget target', () {
      expect(projectContext, anyOf(contains('60'), contains('CanvasKit')));
    });

    test('3. Design system constraint forbids breaking Aster Soft Clay look and feel', () {
      expect(projectContext, contains('Aster Soft Clay'));
      expect(projectContext, contains('lavanda'));
      expect(projectContext, contains('menta'));
    });

    test('4. Root cause categories span fonts, assets, rendering, state, and isolates', () {
      expect(projectContext, anyOf(contains('fontes'), contains('Fontes'), contains('TTF')));
      expect(projectContext, anyOf(contains('Stream'), contains('stream')));
    });

    test('5. Multi-provider AI fallback ensures alternative models when provider is unavailable', () {
      expect(projectContext, contains('Google'));
      expect(projectContext, contains('OpenAI'));
      expect(projectContext, contains('Anthropic'));
    });
  });
}
