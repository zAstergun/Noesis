import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/theme.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 4 - Scenario 7: Dense Card List Scrolling & Clay Shadow Layout Stress', () {
    testWidgets('Scrolling 100 SoftClayCards in a ListView completes cleanly with zero overflow exceptions',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        ListView.builder(
          itemCount: 100,
          itemBuilder: (context, i) {
            return SoftClayCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('#$i')),
                title: Text('Sessão de Estudo $i · Criptografia'),
                subtitle: const Text('Duração: 60 minutos · Modos de Operação AES'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              ),
            );
          },
        ),
      );

      expect(find.text('Sessão de Estudo 0 · Criptografia'), findsOneWidget);

      // Fast scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();

      expect(find.text('Sessão de Estudo 0 · Criptografia'), findsNothing);

      // Fast scroll further down
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();

      // Fast scroll back to top
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'Dense card list scrolling under Soft Clay shadows must produce zero exceptions');
    });
  });
}
