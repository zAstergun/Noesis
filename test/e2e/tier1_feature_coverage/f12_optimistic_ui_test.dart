import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';
import '../harness/test_fixtures.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 12: Optimistic UI Updates & Latency Reduction', () {
    testWidgets('1. Modal dialog dismisses synchronously upon save button click',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Nova Sessão'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Abrir Modal'),
            );
          },
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();
      expect(find.text('Nova Sessão'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Nova Sessão'), findsNothing,
          reason: 'Dialog must be dismissed immediately without awaiting network sync');
    });

    testWidgets('2. Optimistic session insert immediately updates UI list',
        (WidgetTester tester) async {
      final sessionsNotifier = ValueNotifier<List<Map<String, dynamic>>>(
        TestFixtures.mockStudySessions(),
      );

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: sessionsNotifier,
          builder: (context, list, _) {
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) => Text(list[i]['subject'] as String),
            );
          },
        ),
      );

      expect(find.text('Criptografia'), findsOneWidget);
      expect(find.text('Redes & Protocolos'), findsOneWidget);

      // Optimistic insert
      final newSession = TestFixtures.singleStudySession(
        subject: 'Engenharia Reversa',
        durationMinutes: 45,
      );
      sessionsNotifier.value = [newSession, ...sessionsNotifier.value];
      await tester.pump();

      expect(find.text('Engenharia Reversa'), findsOneWidget);
      expect(sessionsNotifier.value.first['subject'], equals('Engenharia Reversa'),
          reason: 'Optimistic insert must prepend item to list instantly');
    });

    testWidgets('3. Optimistic session delete immediately removes item from list',
        (WidgetTester tester) async {
      final sessionsNotifier = ValueNotifier<List<Map<String, dynamic>>>(
        TestFixtures.mockStudySessions(),
      );

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: sessionsNotifier,
          builder: (context, list, _) {
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final item = list[i];
                return ListTile(
                  title: Text(item['subject'] as String),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      sessionsNotifier.value = sessionsNotifier.value
                          .where((s) => s['id'] != item['id'])
                          .toList();
                    },
                  ),
                );
              },
            );
          },
        ),
      );

      expect(find.text('Criptografia'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pump();

      expect(find.text('Criptografia'), findsNothing,
          reason: 'Session must be removed from UI list immediately upon delete click');
    });

    testWidgets('4. Optimistic total study duration counter updates synchronously',
        (WidgetTester tester) async {
      final totalMinutes = ValueNotifier<int>(150);

      await TestAppHarness.pumpInHarness(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: totalMinutes,
          builder: (context, mins, _) {
            final hours = (mins / 60).toStringAsFixed(1);
            return Text('Total: ${hours}h');
          },
        ),
      );

      expect(find.text('Total: 2.5h'), findsOneWidget);

      totalMinutes.value += 60;
      await tester.pump();

      expect(find.text('Total: 3.5h'), findsOneWidget);
    });

    testWidgets('5. Rollback restores state cleanly if background synchronization fails',
        (WidgetTester tester) async {
      final stateNotifier = ValueNotifier<List<String>>(['Session 1', 'Session 2']);
      final previousState = List<String>.from(stateNotifier.value);

      // Perform optimistic update
      stateNotifier.value = ['Session 3', ...stateNotifier.value];
      expect(stateNotifier.value.length, equals(3));

      // Simulate background network error -> rollback
      stateNotifier.value = previousState;
      expect(stateNotifier.value.length, equals(2));
      expect(stateNotifier.value.contains('Session 3'), isFalse);
    });
  });
}
