import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 06: RepaintBoundary Corner Cases', () {
    testWidgets('1. RepaintBoundary maintains key identity across dynamic state rebuilds',
        (WidgetTester tester) async {
      const boundaryKey = ValueKey('stable-chart-boundary');
      final counter = ValueNotifier<int>(0);

      await TestAppHarness.pumpInHarness(
        tester,
        RepaintBoundary(
          key: boundaryKey,
          child: ValueListenableBuilder<int>(
            valueListenable: counter,
            builder: (context, val, _) => Text('Value: $val'),
          ),
        ),
      );

      expect(find.byKey(boundaryKey), findsOneWidget);
      counter.value = 42;
      await tester.pump();

      expect(find.byKey(boundaryKey), findsOneWidget);
      expect(find.text('Value: 42'), findsOneWidget);
    });

    testWidgets('2. Zero-dimension RepaintBoundary layouts without throwing raster assertion',
        (WidgetTester tester) async {
      const zeroKey = Key('zero-boundary');
      await TestAppHarness.pumpInHarness(
        tester,
        const RepaintBoundary(
          key: zeroKey,
          child: SizedBox.shrink(),
        ),
      );

      final boundary = tester.widget<RepaintBoundary>(find.byKey(zeroKey));
      expect(boundary.child, isA<SizedBox>());
    });

    testWidgets('3. Rapid state changes inside RepaintBoundary isolate paint requests',
        (WidgetTester tester) async {
      final notifier = ValueNotifier<double>(0.0);

      await TestAppHarness.pumpInHarness(
        tester,
        RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: notifier,
            builder: (context, val, _) => SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _SimpleTestPainter(progress: val),
              ),
            ),
          ),
        ),
      );

      for (int i = 1; i <= 10; i++) {
        notifier.value = i / 10.0;
        await tester.pump();
      }

      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('4. Scrollable ListView inside RepaintBoundary scrolls smoothly without clipping errors',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        SizedBox(
          height: 300,
          child: RepaintBoundary(
            child: ListView.builder(
              itemCount: 50,
              itemBuilder: (ctx, i) => ListTile(title: Text('Item $i')),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(find.text('Item 0'), findsNothing);
      expect(find.text('Item 5'), findsOneWidget);
    });

    testWidgets('5. RepaintBoundary preserves layout under AnimatedOpacity transitions',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const AnimatedOpacity(
          opacity: 0.8,
          duration: Duration(milliseconds: 200),
          child: RepaintBoundary(
            child: Text('Faded Boundary Text'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Faded Boundary Text'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });
}

class _SimpleTestPainter extends CustomPainter {
  final double progress;
  _SimpleTestPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * progress, size.height), paint);
  }

  @override
  bool shouldRepaint(_SimpleTestPainter oldDelegate) => oldDelegate.progress != progress;
}
