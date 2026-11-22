import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature 03: Web Index & Context Cleanup', () {
    late String indexHtml;
    late String projectContext;

    setUpAll(() {
      final indexFile = File('web/index.html');
      expect(indexFile.existsSync(), isTrue, reason: 'web/index.html must exist');
      indexHtml = indexFile.readAsStringSync();

      final contextFile = File('PROJECT_CONTEXT.md');
      expect(contextFile.existsSync(), isTrue, reason: 'PROJECT_CONTEXT.md must exist');
      projectContext = contextFile.readAsStringSync();
    });

    test('1. web/index.html has legacy IE compatibility tags removed', () {
      expect(indexHtml.contains('X-UA-Compatible'), isFalse,
          reason: 'Legacy IE=Edge and X-UA-Compatible tags must be removed to avoid web engine warnings');
      expect(indexHtml.contains('IE=EmulateIE'), isFalse);
    });

    test('2. web/index.html includes optimized viewport and touch-action css', () {
      expect(indexHtml, contains('viewport-fit=cover'));
      expect(indexHtml, contains('touch-action: manipulation'),
          reason: 'touch-action: manipulation removes the 300ms mobile touch delay');
      expect(indexHtml, contains('-webkit-tap-highlight-color: transparent'));
    });

    test('3. web/index.html sets application title to Noesis', () {
      expect(indexHtml, contains('<title>Noesis</title>'));
      expect(indexHtml, contains('apple-mobile-web-app-title" content="Noesis"'));
    });

    test('4. PROJECT_CONTEXT.md documents modern release and wasm build commands', () {
      expect(projectContext, contains('flutter build web --release'),
          reason: 'PROJECT_CONTEXT.md must document release build command');
      expect(projectContext, contains('flutter build web --release --wasm'),
          reason: 'PROJECT_CONTEXT.md must document WebAssembly release build command');
    });

    test('5. web/index.html preserves dynamic base href placeholder', () {
      expect(indexHtml, contains('<base href="\$FLUTTER_BASE_HREF">'),
          reason: 'Flutter build pipeline requires dynamic base href substitution');
    });
  });
}
