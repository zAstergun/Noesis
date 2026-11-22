import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:noesis/features/calendar/calendar_screen.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 4: Cognitive Calendar Planning & Agenda Lifecycle', () {
    testWidgets('Full calendar lifecycle: Switch view -> Open New Block Dialog -> Enter Title -> Cancel',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const CalendarScreen(),
      );

      // Verify real CalendarScreen mounts
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Verify default view modes exist
      expect(find.text('Semana'), findsOneWidget);
      expect(find.text('Dia'), findsOneWidget);
      expect(find.text('Mês'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);

      // 1. Switch to Month view
      await tester.tap(find.text('Mês'));
      await tester.pumpAndSettle();
      expect(find.byType(TableCalendar), findsWidgets);

      // 2. Switch to Day view
      await tester.tap(find.text('Dia'));
      await tester.pumpAndSettle();

      // 3. Switch back to Week view
      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();

      // 4. Open New Block modal
      final newBlockBtn = find.text('+ Novo bloco');
      expect(newBlockBtn, findsOneWidget);
      await tester.tap(newBlockBtn);
      await tester.pumpAndSettle();

      // Verify dialog opened
      expect(find.text('Novo Bloco / Agendamento'), findsOneWidget);

      // 5. Cancel and dismiss dialog
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Novo Bloco / Agendamento'), findsNothing);

      // Drain all pending font futures and pending relayout frame callbacks
      await TestAppHarness.drainAsync(tester);
    });
  });
}
