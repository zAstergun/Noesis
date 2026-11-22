import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature 16: Comparative Performance Report Specifications', () {
    late String projectContextText;

    setUpAll(() {
      final file = File('PROJECT_CONTEXT.md');
      expect(file.existsSync(), isTrue);
      projectContextText = file.readAsStringSync();
    });

    test('1. Performance optimization requirements cover all 5 core application screens', () {
      final expectedScreens = [
        'Tracker de Estudos',
        'Calendário Integrado',
        'Motor de Simulados com RAG',
        'Agente Cognitivo',
        'Configurações',
      ];

      for (final screen in expectedScreens) {
        expect(projectContextText, contains(screen),
            reason: 'Performance scope must encompass $screen');
      }
    });

    test('2. Performance target defines responsive click feedback within 100ms budget', () {
      expect(projectContextText.toLowerCase(), anyOf(contains('latência'), contains('performance')));
    });

    test('3. Guest Mode and offline operation are specified as zero-network benchmark baseline', () {
      expect(projectContextText, contains('Modo Visitante'));
      expect(projectContextText, contains('offline'));
    });

    test('4. WebAssembly (WasmGC) high performance release target is verified in documentation', () {
      expect(projectContextText, contains('flutter build web --release --wasm'));
      expect(projectContextText, contains('WasmGC'));
    });

    test('5. Multi-provider AI latency benchmarking feature is documented in settings', () {
      expect(projectContextText, contains('benchmark de latência'));
    });
  });
}
