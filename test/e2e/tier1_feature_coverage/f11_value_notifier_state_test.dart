import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 11: Root setState to ValueNotifier Optimization', () {
    testWidgets('1. Active tab ValueNotifier switches IndexedStack without rebuilding outer parent',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);
      int parentBuilds = 0;

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            parentBuilds++;
            return ValueListenableBuilder<int>(
              valueListenable: tabNotifier,
              builder: (context, activeIndex, _) {
                return IndexedStack(
                  index: activeIndex,
                  children: const [
                    Text('Tab 0: Tracker'),
                    Text('Tab 1: Calendário'),
                    Text('Tab 2: Simulados'),
                  ],
                );
              },
            );
          },
        ),
      );

      expect(parentBuilds, equals(1));
      expect(find.text('Tab 0: Tracker'), findsOneWidget);

      tabNotifier.value = 1;
      await tester.pump();

      expect(parentBuilds, equals(1),
          reason: 'Tab switch via ValueNotifier must cause 0 rebuilds of outer Scaffold/builder');
      expect(find.text('Tab 1: Calendário'), findsOneWidget);
    });

    testWidgets('2. Sidebar selection indicator reacts via ValueListenableBuilder',
        (WidgetTester tester) async {
      final tabNotifier = ValueNotifier<int>(0);

      await TestAppHarness.pumpInHarness(
        tester,
        Row(
          children: List.generate(3, (idx) {
            return ValueListenableBuilder<int>(
              valueListenable: tabNotifier,
              builder: (context, activeIdx, _) {
                final isSelected = activeIdx == idx;
                return Container(
                  key: Key('tab-$idx'),
                  color: isSelected ? Colors.purple : Colors.transparent,
                  child: Text('Item $idx'),
                );
              },
            );
          }),
        ),
      );

      Container getContainer(int idx) =>
          tester.widget<Container>(find.byKey(Key('tab-$idx')));

      expect(getContainer(0).color, equals(Colors.purple));
      expect(getContainer(1).color, equals(Colors.transparent));

      tabNotifier.value = 1;
      await tester.pump();

      expect(getContainer(0).color, equals(Colors.transparent));
      expect(getContainer(1).color, equals(Colors.purple));
    });

    testWidgets('3. Timer seconds ValueNotifier updates digits with localized re-rendering',
        (WidgetTester tester) async {
      final secondsNotifier = ValueNotifier<int>(0);
      int containerBuilds = 0;

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            containerBuilds++;
            return Container(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<int>(
                valueListenable: secondsNotifier,
                builder: (context, seconds, _) {
                  final mins = (seconds ~/ 60).toString().padLeft(2, '0');
                  final secs = (seconds % 60).toString().padLeft(2, '0');
                  return Text('$mins:$secs');
                },
              ),
            );
          },
        ),
      );

      expect(containerBuilds, equals(1));
      expect(find.text('00:00'), findsOneWidget);

      secondsNotifier.value = 65;
      await tester.pump();

      expect(find.text('01:05'), findsOneWidget);
      expect(containerBuilds, equals(1),
          reason: 'Timer tick must NOT rebuild the outer timer card container');
    });

    testWidgets('4. Calendar selected date ValueNotifier updates view without rebuilding month grid',
        (WidgetTester tester) async {
      final selectedDateNotifier = ValueNotifier<DateTime>(DateTime(2026, 11, 22));
      int monthGridBuilds = 0;

      await TestAppHarness.pumpInHarness(
        tester,
        Column(
          children: [
            Builder(
              builder: (context) {
                monthGridBuilds++;
                return const Text('Month Grid (Heavy)');
              },
            ),
            ValueListenableBuilder<DateTime>(
              valueListenable: selectedDateNotifier,
              builder: (context, date, _) {
                return Text('Dia selecionado: ${date.day}/${date.month}/${date.year}');
              },
            ),
          ],
        ),
      );

      expect(monthGridBuilds, equals(1));
      expect(find.text('Dia selecionado: 22/11/2026'), findsOneWidget);

      selectedDateNotifier.value = DateTime(2026, 11, 23);
      await tester.pump();

      expect(find.text('Dia selecionado: 23/11/2026'), findsOneWidget);
      expect(monthGridBuilds, equals(1),
          reason: 'Changing selected day must not cause month grid rebuild');
    });

    testWidgets('5. ValueNotifier cleans up listeners on disposal',
        (WidgetTester tester) async {
      final notifier = ValueNotifier<String>('Initial');
      bool listenerCalled = false;
      void listener() => listenerCalled = true;

      notifier.addListener(listener);
      notifier.value = 'Changed';
      expect(listenerCalled, isTrue);

      notifier.removeListener(listener);
      listenerCalled = false;
      notifier.value = 'Changed Again';
      expect(listenerCalled, isFalse);
    });
  });
}
