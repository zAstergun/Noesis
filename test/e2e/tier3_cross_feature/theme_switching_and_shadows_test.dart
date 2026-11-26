import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/core/theme.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Theme Switching & Clay Shadows Cross-Feature Interaction', () {
    testWidgets('1. Toggling between Light and Dark themes dynamically updates card shadows and surface colors',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AsterTheme.themeModeNotifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            return Theme(
              data: isDark ? AsterTheme.darkTheme : AsterTheme.softClayTheme,
              child: const SoftClayCard(
                child: Text('Dynamic Themed Card'),
              ),
            );
          },
        ),
      );

      // Verify Light mode shadow
      AsterTheme.setThemeMode(ThemeMode.light);
      await tester.pump();

      var container = tester.widget<Container>(find.byType(Container).first);
      var dec = container.decoration as BoxDecoration;
      expect(dec.boxShadow, equals(AsterConstants.clayShadow));

      // Verify Dark mode shadow
      AsterTheme.setThemeMode(ThemeMode.dark);
      await tester.pump();

      container = tester.widget<Container>(find.byType(Container).first);
      dec = container.decoration as BoxDecoration;
      expect(dec.boxShadow!.first.color, equals(Colors.black.withValues(alpha: 0.35)));

      // Reset
      AsterTheme.setThemeMode(ThemeMode.light);
    });

    testWidgets('2. ChipTheme and SoftClayChoiceChip use pill shape and soft borders in Light and Dark themes',
        (WidgetTester tester) async {
      for (final theme in [AsterTheme.softClayTheme, AsterTheme.darkTheme]) {
        expect(theme.chipTheme.shape, isA<StadiumBorder>());
        expect(theme.chipTheme.side, isA<WidgetStateBorderSide>());
        final sideProp = theme.chipTheme.side! as WidgetStateBorderSide;
        final selectedSide = sideProp.resolve({WidgetState.selected});
        final unselectedSide = sideProp.resolve({});
        expect(selectedSide, equals(BorderSide.none));
        expect(unselectedSide, isNotNull);
        expect(unselectedSide!.color, isNot(equals(Colors.black)));
      }

      bool selected = false;
      await TestAppHarness.pumpInHarness(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return Row(
              children: [
                SoftClayChoiceChip(
                  label: 'Simulados',
                  icon: Icons.assignment_rounded,
                  selected: selected,
                  onTap: () => setState(() => selected = !selected),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('Simulados'), findsOneWidget);
      await tester.tap(find.text('Simulados'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });
  });
}
