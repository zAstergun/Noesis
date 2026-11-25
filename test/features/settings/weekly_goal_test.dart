import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/settings/settings_screen.dart';
import 'package:noesis/main.dart';
import 'package:noesis/widgets/weekly_goal_dialog.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    await SupabaseService.saveWeeklyGoalMinutes(SupabaseService.defaultWeeklyGoalMinutes);
  });

  test('formatGoalDuration and computeCurrentWeekStudiedMinutes work accurately', () {
    expect(SupabaseService.formatGoalDuration(0), '0h');
    expect(SupabaseService.formatGoalDuration(45), '45m');
    expect(SupabaseService.formatGoalDuration(1500), '25h');
    expect(SupabaseService.formatGoalDuration(90), '1h 30m');

    // Reference date: Wednesday 2026-11-25
    final wednesday = DateTime(2026, 11, 25, 14, 0);
    final sessions = [
      {'duration_minutes': 90, 'study_date': '2026-11-23'}, // Monday (same week)
      {'duration_minutes': 60, 'study_date': '2026-11-25'}, // Wednesday (same week)
      {'duration_minutes': 45, 'study_date': '2026-11-29'}, // Sunday (same week)
      {'duration_minutes': 120, 'study_date': '2026-11-22'}, // Previous Sunday (excluded)
      {'duration_minutes': 80, 'study_date': '2026-11-30'}, // Next Monday (excluded)
    ];

    expect(
      SupabaseService.computeCurrentWeekStudiedMinutes(sessions, referenceDate: wednesday),
      195,
    );
  });

  testWidgets('WeeklyGoalEditorDialog validates, applies presets, and saves goal',
      (WidgetTester tester) async {
    await TestAppHarness.pumpInHarness(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showWeeklyGoalEditorDialog(
              context,
              currentWeekStudiedMinutes: 600,
            ),
            child: const Text('Abrir Modal'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Modal'));
    await tester.pumpAndSettle();

    expect(find.text('Editar Meta Semanal'), findsOneWidget);
    expect(find.textContaining('10h / 25h · 40%'), findsOneWidget);

    // Invalid (< 30 min) validation check
    await tester.enterText(find.byKey(const Key('weekly_goal_hours_field')), '0');
    await tester.enterText(find.byKey(const Key('weekly_goal_minutes_field')), '15');
    await tester.pump();
    await tester.tap(find.text('Salvar Meta'));
    await tester.pump();
    expect(find.textContaining('30 minutos e 168 horas'), findsOneWidget);

    // Select preset 40h and save
    await tester.tap(find.text('40h'));
    await tester.pump();
    expect(find.textContaining('10h / 40h · 25%'), findsOneWidget);

    await tester.tap(find.text('Salvar Meta'));
    await tester.pumpAndSettle();

    expect(SupabaseService.weeklyGoalMinutesNotifier.value, 40 * 60);
    final reloaded = await SupabaseService.loadWeeklyGoalMinutes();
    expect(reloaded, 40 * 60);
  });

  testWidgets('RootScreen sidebar META SEMANAL card opens editor and updates live',
      (WidgetTester tester) async {
    await TestAppHarness.pumpInHarness(
      tester,
      const RootScreen(),
      screenSize: const Size(1440, 900),
    );

    // Enter guest mode if on AuthScreen
    final guestFinder = find.textContaining('Entrar sem login');
    if (guestFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestFinder.first);
      await tester.tap(guestFinder.first);
      await tester.pumpAndSettle();
    }

    final weeklyGoalCard = find.byKey(const Key('sidebar_weekly_goal_card'));
    expect(find.text('META SEMANAL'), findsOneWidget);
    expect(
      find.descendant(
        of: weeklyGoalCard,
        matching: find.textContaining('/ 25h'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(weeklyGoalCard);
    await tester.tap(weeklyGoalCard);
    await tester.pumpAndSettle();

    expect(find.text('Editar Meta Semanal'), findsOneWidget);
    await tester.tap(find.text('30h'));
    await tester.pump();
    await tester.tap(find.text('Salvar Meta'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: weeklyGoalCard,
        matching: find.textContaining('/ 30h'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard_kpi_weekly_goal')),
        matching: find.textContaining('/ 30h'),
      ),
      findsOneWidget,
    );
    expect(SupabaseService.weeklyGoalMinutesNotifier.value, 30 * 60);
    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('SettingsScreen displays weekly goal card and allows editing',
      (WidgetTester tester) async {
    await TestAppHarness.pumpInHarness(
      tester,
      const SettingsScreen(),
      screenSize: const Size(1280, 800),
    );

    expect(find.text('Meta Semanal de Estudos'), findsOneWidget);
    expect(find.textContaining('Meta atual: 25h/semana'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_edit_weekly_goal_button')));
    await tester.pumpAndSettle();

    expect(find.text('Editar Meta Semanal'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('weekly_goal_hours_field')), '12');
    await tester.enterText(find.byKey(const Key('weekly_goal_minutes_field')), '30');
    await tester.pump();

    await tester.tap(find.text('Salvar Meta'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Meta atual: 12h 30m/semana'), findsOneWidget);
    expect(SupabaseService.weeklyGoalMinutesNotifier.value, 12 * 60 + 30);
  });

  testWidgets('SettingsScreen displays Névoa and all 10 new Noesis themes cleanly',
      (WidgetTester tester) async {
    await TestAppHarness.pumpInHarness(
      tester,
      const SettingsScreen(),
      screenSize: const Size(1280, 900),
    );

    expect(find.text('Névoa'), findsOneWidget);
    expect(find.text('Soft Clay Névoa'), findsNothing);
    expect(find.byKey(const Key('theme_option_soft_clay_nevoa')), findsOneWidget);
    expect(find.text('Modo Escuro'), findsNothing);
    expect(find.text('Soft Clay Noturno'), findsNothing);
    expect(find.text('Sistema'), findsNothing);
    expect(find.text('Modo Claro'), findsNothing);

    const expectedThemes = [
      ('aurora', 'Aurora'),
      ('floresta', 'Floresta'),
      ('oceano', 'Oceano'),
      ('brasa', 'Brasa'),
      ('grafite', 'Grafite'),
      ('lagoa', 'Lagoa'),
      ('sakura', 'Sakura'),
      ('esmeralda', 'Esmeralda'),
      ('crepusculo', 'Crepúsculo'),
      ('nordico', 'Nórdico'),
    ];

    for (final item in expectedThemes) {
      expect(find.byKey(Key('theme_option_${item.$1}')), findsOneWidget);
      expect(find.text(item.$2), findsOneWidget);
    }

    // Seleciona um tema escuro (Grafite) e outro claro (Floresta) via UI
    await tester.ensureVisible(find.byKey(const Key('theme_option_grafite')));
    await tester.tap(find.byKey(const Key('theme_option_grafite')));
    await tester.pumpAndSettle();
    expect(AsterTheme.activeThemeIdNotifier.value, 'grafite');
    expect(AsterTheme.themeModeNotifier.value, ThemeMode.dark);
    expect(AsterTheme.activeDarkThemeData().scaffoldBackgroundColor, const Color(0xFF0A0A0C));

    await tester.ensureVisible(find.byKey(const Key('theme_option_floresta')));
    await tester.tap(find.byKey(const Key('theme_option_floresta')));
    await tester.pumpAndSettle();
    expect(AsterTheme.activeThemeIdNotifier.value, 'floresta');
    expect(AsterTheme.themeModeNotifier.value, ThemeMode.light);
    expect(AsterTheme.activeLightThemeData().scaffoldBackgroundColor, const Color(0xFFEEF4EF));

    // Restaura padrão Soft Clay Névoa ao final
    AsterTheme.selectThemeOption('soft_clay_nevoa');
  });
}
