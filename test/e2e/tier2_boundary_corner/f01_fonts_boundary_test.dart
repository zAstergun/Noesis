import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../harness/test_app_harness.dart';
import '../harness/mock_http_overrides.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() {
    MockHttpOverrides.reset();
  });

  group('Tier 2 - Feature 01: Local Fonts Boundary & Corner Cases', () {
    testWidgets('1. Undeclared custom font family string falls back to system font without crash',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const Text(
          'Fallback Font Sample',
          style: TextStyle(fontFamily: 'NonExistentAsterFont'),
        ),
      );

      expect(find.text('Fallback Font Sample'), findsOneWidget);
      expect(MockHttpOverrides.recordedRequests, isEmpty);
    });

    testWidgets('2. Empty text string renders zero glyphs without exception',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Text('', style: GoogleFonts.manrope()),
      );

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('3. Portuguese accented characters and mathematical symbols render properly',
        (WidgetTester tester) async {
      const accentedSample = 'Criptografia: Não há violação nas sessões — ∑(x_i) ≥ 42h · R\$ 1.500,00';
      await TestAppHarness.pumpInHarness(
        tester,
        Text(accentedSample, style: GoogleFonts.manrope()),
      );

      expect(find.text(accentedSample), findsOneWidget);
    });

    testWidgets('4. Large accessibility text scaler (2.5x) scales text without layout assertion',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: Text('Acessibilidade 250%', style: GoogleFonts.manrope()),
        ),
      );

      expect(find.text('Acessibilidade 250%'), findsOneWidget);
    });

    testWidgets('5. Multiple rapid font renders generate zero runtime network requests',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Column(
          children: [
            Text('Manrope 400', style: GoogleFonts.manrope(fontWeight: FontWeight.w400)),
            Text('Manrope 700', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            Text('JetBrainsMono 400', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w400)),
            Text('JetBrainsMono 500', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500)),
            Text('JetBrainsMono 700', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700)),
            Text('JetBrainsMono 800', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800)),
          ],
        ),
      );

      expect(MockHttpOverrides.recordedRequests, isEmpty,
          reason: 'All font weights must resolve purely from local bundle assets');
    });
  });
}
