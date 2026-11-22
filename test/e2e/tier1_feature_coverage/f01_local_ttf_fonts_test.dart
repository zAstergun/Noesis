import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../harness/test_app_harness.dart';
import '../harness/mock_http_overrides.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
    await GoogleFonts.pendingFonts();
  });

  setUp(() {
    MockHttpOverrides.reset();
  });

  group('Feature 01: Local TTF Font Migration', () {
    test('1. GoogleFonts.config.allowRuntimeFetching is disabled (false)', () {
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse,
          reason: 'Runtime fetching must be false to prevent web latency spikes on click');
    });

    test('2. pubspec.yaml declares all 9 local TTF font variants', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final content = pubspecFile.readAsStringSync();

      expect(content, contains('family: Manrope'));
      expect(content, contains('family: JetBrainsMono'));

      final expectedFontAssets = [
        'assets/fonts/Manrope-Regular.ttf',
        'assets/fonts/Manrope-Medium.ttf',
        'assets/fonts/Manrope-SemiBold.ttf',
        'assets/fonts/Manrope-Bold.ttf',
        'assets/fonts/Manrope-ExtraBold.ttf',
        'assets/fonts/JetBrainsMono-Regular.ttf',
        'assets/fonts/JetBrainsMono-Medium.ttf',
        'assets/fonts/JetBrainsMono-Bold.ttf',
        'assets/fonts/JetBrainsMono-ExtraBold.ttf',
      ];

      for (final asset in expectedFontAssets) {
        expect(content, contains(asset),
            reason: 'pubspec.yaml must declare font asset $asset');
      }
    });

    test('3. All 9 declared .ttf files exist on disk in assets/fonts/', () {
      final expectedFonts = [
        'Manrope-Regular.ttf',
        'Manrope-Medium.ttf',
        'Manrope-SemiBold.ttf',
        'Manrope-Bold.ttf',
        'Manrope-ExtraBold.ttf',
        'JetBrainsMono-Regular.ttf',
        'JetBrainsMono-Medium.ttf',
        'JetBrainsMono-Bold.ttf',
        'JetBrainsMono-ExtraBold.ttf',
      ];

      for (final fontName in expectedFonts) {
        final file = File('assets/fonts/$fontName');
        expect(file.existsSync(), isTrue,
            reason: 'Font file assets/fonts/$fontName must exist on filesystem');
        expect(file.lengthSync(), greaterThan(10000),
            reason: 'Font file $fontName must be a valid non-empty TTF binary');
      }
    });

    testWidgets('4. AsterTheme.softClayTheme text theme resolves without network requests',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Column(
              children: [
                Text('Display Large Title', style: theme.textTheme.displayLarge),
                Text('Body Text Content', style: theme.textTheme.bodyMedium),
              ],
            );
          },
        ),
      );
      expect(find.text('Display Large Title'), findsOneWidget);
      expect(find.text('Body Text Content'), findsOneWidget);
      expect(MockHttpOverrides.recordedRequests, isEmpty,
          reason: 'No network request should be fired when rendering local fonts');

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    });

    testWidgets('5. JetBrainsMono font family renders code snippets correctly',
        (WidgetTester tester) async {
      final codeStyle = GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      );

      await TestAppHarness.pumpInHarness(
        tester,
        Text('const cipher = AES_GCM(key, nonce);', style: codeStyle),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.data, 'const cipher = AES_GCM(key, nonce);');
      expect(textWidget.style?.fontFamily, contains('JetBrainsMono'));
      expect(MockHttpOverrides.recordedRequests, isEmpty);
    });

    test('6. All GoogleFonts.jetBrainsMono usages across lib/ adhere strictly to packaged font weights', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      final allowedWeights = {'w400', 'w500', 'w700', 'w800'};
      final fontPattern = RegExp(r'GoogleFonts\.jetBrainsMono\s*\(([^)]*)\)', multiLine: true);
      final weightPattern = RegExp(r'FontWeight\.(w\d{3}|bold|normal)');

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final match in fontPattern.allMatches(content)) {
          final args = match.group(1) ?? '';
          final weightMatch = weightPattern.firstMatch(args);
          if (weightMatch != null) {
            final weight = weightMatch.group(1);
            expect(allowedWeights, contains(weight),
                reason: 'Found unpackaged JetBrainsMono weight "$weight" in ${file.path}. Only 400, 500, 700, 800 are packaged.');
          }
        }
      }
    });
  });
}
