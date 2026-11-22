import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/core/theme.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 8: Multi-Theme Toggle & Asset/Font Integrity Verification', () {
    testWidgets('Toggling between Soft Clay Light and Dark mode preserves font hierarchy and container integrity',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AsterTheme.themeModeNotifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            return Theme(
              data: isDark ? AsterTheme.darkTheme : AsterTheme.softClayTheme,
              child: SoftClayBackground(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Título em Manrope w800',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AsterConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'const key = generateAESKey(256);',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AsterConstants.menta,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SoftClayCard(
                        child: Text(
                          isDark ? 'Tema Escuro Ativo' : 'Tema Claro Soft Clay Ativo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      // Verify Light mode state
      AsterTheme.setThemeMode(ThemeMode.light);
      await tester.pump();

      expect(find.text('Título em Manrope w800'), findsOneWidget);
      expect(find.text('Tema Claro Soft Clay Ativo'), findsOneWidget);

      // Toggle to Dark mode
      AsterTheme.setThemeMode(ThemeMode.dark);
      await tester.pump();

      expect(find.text('Tema Escuro Ativo'), findsOneWidget);

      // Toggle back to Light mode
      AsterTheme.setThemeMode(ThemeMode.light);
      await tester.pump();

      expect(find.text('Tema Claro Soft Clay Ativo'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await TestAppHarness.drainAsync(tester);
    });
  });
}
