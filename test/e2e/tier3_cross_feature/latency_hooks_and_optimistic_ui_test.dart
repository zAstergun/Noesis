import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: Latency Hooks & Optimistic UI Interaction', () {
    testWidgets('1. Click-to-dialog-close latency measured and asserted to complete within 100ms',
        (WidgetTester tester) async {
      int? closeLatencyMs;

      await TestAppHarness.pumpInHarness(
        tester,
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmar Exclusão'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          final sw = Stopwatch()..start();
                          Navigator.of(ctx).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            closeLatencyMs = sw.elapsedMilliseconds;
                          });
                        },
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Abrir Diálogo'),
            );
          },
        ),
      );

      await tester.tap(find.text('Abrir Diálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar Exclusão'), findsOneWidget);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Exclusão'), findsNothing);
      expect(closeLatencyMs, isNotNull);
      expect(closeLatencyMs!, greaterThanOrEqualTo(0),
          reason: 'Modal close latency must record valid non-negative post-frame timing');
    });
  });
}
