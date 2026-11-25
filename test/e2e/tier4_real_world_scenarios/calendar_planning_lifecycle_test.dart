import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:noesis/core/noesis_agent_tools.dart';
import 'package:noesis/core/supabase_service.dart';
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

    testWidgets('Calendar weekly, daily, and modal views display full 24h schedule including 22h to 06h',
        (WidgetTester tester) async {
      final today = DateTime.now();
      await SupabaseService.addCalendarEvent(
        title: 'Estudo Noturno 23h',
        category: 'study',
        startTime: DateTime(today.year, today.month, today.day, 23, 0),
        endTime: DateTime(today.year, today.month, today.day, 23, 50),
      );
      await SupabaseService.addCalendarEvent(
        title: 'Revisão Madrugada 04h',
        category: 'review',
        startTime: DateTime(today.year, today.month, today.day, 4, 0),
        endTime: DateTime(today.year, today.month, today.day, 5, 0),
      );

      await TestAppHarness.pumpInHarness(
        tester,
        const CalendarScreen(),
      );
      await tester.pumpAndSettle();

      // Semana mostra todas as 24h (00h..06h e 22h..23h)
      expect(find.text('00h'), findsOneWidget);
      expect(find.text('06h'), findsOneWidget);
      expect(find.text('22h'), findsOneWidget);
      expect(find.text('23h'), findsOneWidget);
      expect(find.text('Estudo Noturno 23h'), findsAtLeastNWidgets(1));
      expect(find.text('Revisão Madrugada 04h'), findsAtLeastNWidgets(1));

      // Dia mostra 00:00 até 23:00
      await tester.tap(find.text('Dia'));
      await tester.pumpAndSettle();
      expect(find.text('00:00'), findsAtLeastNWidgets(1));
      expect(find.text('04:00'), findsAtLeastNWidgets(1));

      // Novo bloco permite selecionar qualquer hora entre 00:00 e 23:00 (24 horas)
      await tester.tap(find.text('+ Novo bloco'));
      await tester.pumpAndSettle();
      final hourDropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>).first,
      );
      final hourValues = hourDropdown.items?.map((item) => item.value).toList();
      expect(hourValues, equals(List.generate(24, (i) => i)));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('Calendar AI suggestion card adapts to account context and avoids occupied slots',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      // Bloqueia amanhã 15h-17h e adiciona uma prova próxima (antes das demais) + sessão recente
      await SupabaseService.addCalendarEvent(
        title: 'Reunião Ocupada',
        category: 'study',
        startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0),
        endTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 0),
      );
      await SupabaseService.addCalendarEvent(
        title: 'Prova Security+ AWS',
        category: 'exam',
        startTime: now.add(const Duration(hours: 6)),
        endTime: now.add(const Duration(hours: 8)),
      );
      await SupabaseService.addStudySession(
        subject: 'Cloud AWS',
        topic: 'IAM & KMS',
        durationMinutes: 60,
        studyDate: now,
      );

      final recs = await NoesisAgentTools.buildCalendarRecommendations(now: now);
      expect(recs, isNotEmpty);
      expect(recs.first.message, contains('Prova Security+ AWS'));

      // Verifica que nenhum bloco sugerido colide com o slot ocupado 15h-17h de amanhã
      final occStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0);
      final occEnd = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 0);
      for (final r in recs) {
        final overlaps = r.startTime.isBefore(occEnd) && r.endTime.isAfter(occStart);
        expect(overlaps, isFalse);
      }

      await TestAppHarness.pumpInHarness(
        tester,
        const CalendarScreen(),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar_ai_suggestion_card')), findsOneWidget);
      expect(find.textContaining('Prova Security+ AWS'), findsAtLeastNWidgets(1));
      expect(find.text('Sim, agendar'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });
  });
}
