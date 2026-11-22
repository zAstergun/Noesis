import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tier 2 - Feature 03: Web Index & Context Boundary Cases', () {
    late String html;

    setUpAll(() {
      html = File('web/index.html').readAsStringSync();
    });

    test('1. web/index.html is well-formed with closing tags for html, head, and body', () {
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<head>'));
      expect(html, contains('</head>'));
      expect(html, contains('<body>'));
      expect(html, contains('</body>'));
      expect(html, contains('</html>'));
    });

    test('2. web/index.html contains zero external runtime font download links (fonts.googleapis.com)', () {
      expect(html.contains('fonts.googleapis.com'), isFalse,
          reason: 'Fonts must not be preconnected or fetched from external CDNs');
      expect(html.contains('fonts.gstatic.com'), isFalse);
    });

    test('3. web/index.html links to manifest.json and favicon.png', () {
      expect(html, contains('href="manifest.json"'));
      expect(html, contains('href="favicon.png"'));
    });

    test('4. web/index.html explicitly disables iOS tap highlight and user selection in canvas', () {
      expect(html, contains('-webkit-tap-highlight-color: transparent'));
      expect(html, contains('user-select: none'));
      expect(html, contains('flt-glass-pane'));
    });

    test('5. Base href placeholder syntax exactly matches Flutter build tool requirement', () {
      expect(html, contains('<base href="\$FLUTTER_BASE_HREF">'));
    });
  });
}
