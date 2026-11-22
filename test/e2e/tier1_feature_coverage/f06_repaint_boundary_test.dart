import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/theme.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 06: RepaintBoundary Strategic Placement', () {
    testWidgets('1. SoftClayBackground encloses static ambient gradient in a RepaintBoundary',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayBackground(
          child: Center(child: Text('Interactive Body')),
        ),
      );

      final boundaries = find.descendant(
        of: find.byType(SoftClayBackground),
        matching: find.byType(RepaintBoundary),
      );
      expect(boundaries, findsAtLeastNWidgets(1),
          reason: 'SoftClayBackground must use RepaintBoundary to cache the ambient background gradients');
    });

    testWidgets('2. RepaintBoundary creates a render object with isRepaintBoundary set to true',
        (WidgetTester tester) async {
      final key = GlobalKey();
      await TestAppHarness.pumpInHarness(
        tester,
        RepaintBoundary(
          key: key,
          child: const SizedBox(width: 100, height: 100, child: Text('Isolated Node')),
        ),
      );

      final renderObject = key.currentContext?.findRenderObject();
      expect(renderObject, isNotNull);
      expect(renderObject!.isRepaintBoundary, isTrue,
          reason: 'RepaintBoundary must create a distinct GPU compositing layer');
    });

    testWidgets('3. Chart subtrees isolated with RepaintBoundary preserve paint containment',
        (WidgetTester tester) async {
      final chartKey = GlobalKey();
      await TestAppHarness.pumpInHarness(
        tester,
        RepaintBoundary(
          key: chartKey,
          child: Container(
            width: 200,
            height: 200,
            color: Colors.amber,
            child: const Center(child: Text('Chart Placeholder')),
          ),
        ),
      );

      final renderBox = chartKey.currentContext?.findRenderObject() as RenderBox?;
      expect(renderBox, isNotNull);
      expect(renderBox!.isRepaintBoundary, isTrue);
      expect(renderBox.size, equals(const Size(200, 200)));
    });

    testWidgets('4. RepaintBoundary safely supports dynamic child state changes without losing boundary',
        (WidgetTester tester) async {
      final counter = ValueNotifier<int>(0);

      await TestAppHarness.pumpInHarness(
        tester,
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: counter,
            builder: (context, val, _) => Text('Count: $val'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      counter.value = 5;
      await tester.pump();
      expect(find.text('Count: 5'), findsOneWidget);

      final boundary = tester.widget<RepaintBoundary>(find.byType(RepaintBoundary).first);
      expect(boundary.child, isNotNull);
    });

    testWidgets('5. Multiple nested RepaintBoundaries remain stable in screen layout',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        SoftClayBackground(
          child: Row(
            children: [
              RepaintBoundary(
                child: Container(width: 200, color: Colors.blue),
              ),
              Expanded(
                child: RepaintBoundary(
                  child: Container(color: Colors.green),
                ),
              ),
            ],
          ),
        ),
      );

      final boundaries = find.byType(RepaintBoundary);
      expect(boundaries, findsAtLeastNWidgets(2));
    });
  });
}
