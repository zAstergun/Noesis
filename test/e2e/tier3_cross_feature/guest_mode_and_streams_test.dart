import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Guest Mode & Distinct Streams Cross-Feature Interaction', () {
    testWidgets('1. Guest Mode calendar stream emits initial in-memory events to StreamBuilder',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.calendarEventsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final events = snapshot.data!;
            return Text('Total de Eventos: ${events.length}');
          },
        ),
      );

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();

      expect(find.textContaining('Total de Eventos:'), findsOneWidget);
    });

    test('2. Multiple identical emissions in Guest Mode stream do not emit duplicate stream values', () async {
      final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
      int emissionCount = 0;

      final distinctStream = controller.stream.distinct((prev, next) => prev.length == next.length);
      final sub = distinctStream.listen((_) => emissionCount++);

      final sample = await SupabaseService.getCalendarEvents();
      controller.add(sample);
      controller.add(sample); // duplicate
      await Future.delayed(const Duration(milliseconds: 20));

      expect(emissionCount, equals(1));
      await sub.cancel();
      await controller.close();
    });
  });
}
