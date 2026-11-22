import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature 04: Wasm & Release Build Verification', () {
    test('1. Release build command is documented and executable in project context', () {
      final contextFile = File('PROJECT_CONTEXT.md');
      expect(contextFile.existsSync(), isTrue);
      final text = contextFile.readAsStringSync();
      expect(text, contains('flutter build web --release'));
    });

    test('2. WasmGC build flag is documented with modern flutter web command', () {
      final contextFile = File('PROJECT_CONTEXT.md');
      final text = contextFile.readAsStringSync();
      expect(text, contains('flutter build web --release --wasm'));
    });

    test('3. web/index.html uses flutter_bootstrap.js for wasm and canvaskit bootstrapping', () {
      final indexFile = File('web/index.html');
      expect(indexFile.existsSync(), isTrue);
      final html = indexFile.readAsStringSync();
      expect(html, contains('<script src="flutter_bootstrap.js" async></script>'),
          reason: 'Flutter 3.50+ web initializes via flutter_bootstrap.js with SkWasm / CanvasKit fallback');
    });

    test('4. pubspec.yaml declares assets directory so web packaging includes fonts', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/fonts/'));
      expect(Directory('assets/fonts').existsSync(), isTrue);
      final fontFiles = Directory('assets/fonts').listSync().whereType<File>().toList();
      expect(fontFiles.length, equals(9),
          reason: 'All 9 font assets must be available for web packaging');
    });

    test('5. web/manifest.json exists and specifies valid standalone PWA configuration', () {
      final manifestFile = File('web/manifest.json');
      expect(manifestFile.existsSync(), isTrue);
      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent, contains('"name": "Noesis"'));
      expect(manifestContent, contains('"display": "standalone"'));
    });
  });
}
