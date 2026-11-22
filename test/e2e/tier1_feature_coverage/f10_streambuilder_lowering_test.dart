import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';
import '../harness/test_fixtures.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 10: StreamBuilder Lowering & Distinct Stream Filtering', () {
    test('1. Stream with distinct() ignores consecutive identical session emissions', () async {
      final controller = StreamController<List<Map<String, dynamic>>>();
      final distinctStream = controller.stream.distinct((prev, next) {
        if (prev.length != next.length) return false;
        for (int i = 0; i < prev.length; i++) {
          if (!mapEquals(prev[i], next[i])) return false;
        }
        return true;
      });

      final receivedEvents = <List<Map<String, dynamic>>>[];
      final subscription = distinctStream.listen((event) {
        receivedEvents.add(event);
      });

      final sessionsA = TestFixtures.mockStudySessions();
      final sessionsB = List<Map<String, dynamic>>.from(
        sessionsA.map((s) => Map<String, dynamic>.from(s)),
      );

      controller.add(sessionsA);
      await Future.delayed(const Duration(milliseconds: 10));

      controller.add(sessionsB); // Identical payload
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(1),
          reason: 'distinct() must suppress identical subsequent emissions to prevent redundant widget rebuilds');

      final sessionsC = List<Map<String, dynamic>>.from(sessionsA);
      sessionsC.add(TestFixtures.singleStudySession(id: 'sess-new'));
      controller.add(sessionsC);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, equals(2),
          reason: 'distinct() must pass emissions when data has changed');

      await subscription.cancel();
      await controller.close();
    });

    testWidgets('2. Lowered StreamBuilder only rebuilds its own container on new emission',
        (WidgetTester tester) async {
      final streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
      int outerBuildCount = 0;
      int innerBuildCount = 0;

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            outerBuildCount++;
            return Column(
              children: [
                const Text('Static Header Card'),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: streamController.stream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    innerBuildCount++;
                    final count = snapshot.data?.length ?? 0;
                    return Text('Sessions Count: $count');
                  },
                ),
              ],
            );
          },
        ),
      );

      expect(outerBuildCount, equals(1));
      expect(innerBuildCount, equals(1));

      streamController.add(TestFixtures.mockStudySessions());
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
      await tester.pump();

      expect(outerBuildCount, equals(1),
          reason: 'Outer tree must NOT rebuild when a localized StreamBuilder receives data');
      expect(innerBuildCount, equals(2),
          reason: 'Localized StreamBuilder must rebuild to reflect new data');

      await streamController.close();
    });

    testWidgets('3. StreamBuilder gracefully handles empty stream snapshot',
        (WidgetTester tester) async {
      final streamController = StreamController<List<Map<String, dynamic>>>();

      await TestAppHarness.pumpInHarness(
        tester,
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: streamController.stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
              return const Text('Nenhuma sessão registrada');
            }
            return Text('Total: ${snapshot.data!.length}');
          },
        ),
      );

      expect(find.text('Nenhuma sessão registrada'), findsOneWidget);
      await streamController.close();
    });

    testWidgets('4. StreamBuilder handles stream error without crashing widget hierarchy',
        (WidgetTester tester) async {
      final streamController = StreamController<List<Map<String, dynamic>>>();

      await TestAppHarness.pumpInHarness(
        tester,
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: streamController.stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Erro ao carregar dados');
            }
            return const Text('Dados normais');
          },
        ),
      );

      streamController.addError(Exception('Supabase connection error'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
      await tester.pump();

      expect(find.text('Erro ao carregar dados'), findsOneWidget);
      await streamController.close();
    });

    testWidgets('5. Multiple independent StreamBuilders listen to distinct data feeds independently',
        (WidgetTester tester) async {
      final sessionController = StreamController<int>();
      final calendarController = StreamController<int>();

      await TestAppHarness.pumpInHarness(
        tester,
        Row(
          children: [
            StreamBuilder<int>(
              stream: sessionController.stream,
              initialData: 0,
              builder: (context, snap) => Text('Sessions: ${snap.data}'),
            ),
            StreamBuilder<int>(
              stream: calendarController.stream,
              initialData: 0,
              builder: (context, snap) => Text('Events: ${snap.data}'),
            ),
          ],
        ),
      );

      sessionController.add(5);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
      await tester.pump();

      expect(find.text('Sessions: 5'), findsOneWidget);
      expect(find.text('Events: 0'), findsOneWidget);

      await sessionController.close();
      await calendarController.close();
    });
  });
}
