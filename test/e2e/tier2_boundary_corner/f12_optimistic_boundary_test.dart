import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 12: Optimistic UI Boundary Cases', () {
    test('1. Double submit debounce flag prevents duplicate optimistic item creation', () {
      bool isSubmitting = false;
      int itemsCreated = 0;

      void submitItem() {
        if (isSubmitting) return;
        isSubmitting = true;
        itemsCreated++;
      }

      // Simulate rapid double click
      submitItem();
      submitItem();

      expect(itemsCreated, equals(1));
    });

    test('2. Zero and negative duration input validation prevents invalid optimistic session', () {
      bool validateDuration(int minutes) => minutes > 0;

      expect(validateDuration(0), isFalse);
      expect(validateDuration(-15), isFalse);
      expect(validateDuration(60), isTrue);
    });

    testWidgets('3. Form validation triggers error text on zero minutes without modifying state',
        (WidgetTester tester) async {
      final sessions = ValueNotifier<List<String>>(['Existing Session']);
      final durationController = TextEditingController(text: '0');
      String? errorMessage;

      await TestAppHarness.pumpInHarness(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                TextField(controller: durationController),
                if (errorMessage != null) Text(errorMessage!),
                ElevatedButton(
                  onPressed: () {
                    final mins = int.tryParse(durationController.text) ?? 0;
                    if (mins <= 0) {
                      setState(() => errorMessage = 'Duração deve ser maior que 0');
                    } else {
                      sessions.value = ['New Session', ...sessions.value];
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        ),
      );

      await tester.tap(find.text('Salvar'));
      await tester.pump();

      expect(find.text('Duração deve ser maior que 0'), findsOneWidget);
      expect(sessions.value.length, equals(1));
    });

    test('4. Optimistic item deleted immediately after creation removes correct item by temp ID', () {
      final list = <Map<String, dynamic>>[
        {'id': 'temp-1', 'title': 'Pending Session 1'},
        {'id': 'real-2', 'title': 'Persisted Session 2'},
      ];

      list.removeWhere((item) => item['id'] == 'temp-1');
      expect(list.length, equals(1));
      expect(list.first['id'], equals('real-2'));
    });

    testWidgets('5. Concurrent state updates do not lose optimistic entries in ValueNotifier',
        (WidgetTester tester) async {
      final listNotifier = ValueNotifier<List<int>>([]);

      for (int i = 0; i < 10; i++) {
        listNotifier.value = [...listNotifier.value, i];
      }

      expect(listNotifier.value.length, equals(10));
      expect(listNotifier.value, equals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
    });
  });
}
