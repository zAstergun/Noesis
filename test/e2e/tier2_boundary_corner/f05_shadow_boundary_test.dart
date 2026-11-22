import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/core/theme.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 2 - Feature 05: Aster Clay Shadow Boundary Cases', () {
    testWidgets('1. SoftClayCard with onTap callback triggers gesture detector without throwing',
        (WidgetTester tester) async {
      bool tapped = false;

      await TestAppHarness.pumpInHarness(
        tester,
        SoftClayCard(
          onTap: () => tapped = true,
          child: const Text('Interactive Card'),
        ),
      );

      await tester.tap(find.text('Interactive Card'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('2. SoftClayCard supports custom background colors while retaining soft clay shadow',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayCard(
          color: Color(0xFFF3F4FB),
          child: Text('Custom Tint Card'),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFF3F4FB)));
      expect(decoration.boxShadow, equals(AsterConstants.clayShadow));
    });

    testWidgets('3. Negative spread radius (-4) preserves positive card content bounding box',
        (WidgetTester tester) async {
      final key = GlobalKey();

      await TestAppHarness.pumpInHarness(
        tester,
        Center(
          child: SoftClayCard(
            key: key,
            width: 200,
            height: 150,
            child: const Text('Fixed Size Box'),
          ),
        ),
      );

      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      expect(renderBox?.size, equals(const Size(200, 150)));
    });

    testWidgets('4. Nested SoftClayCard inside SoftClayCard renders hierarchically without overflow',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayCard(
          padding: EdgeInsets.all(20),
          child: SoftClayCard(
            padding: EdgeInsets.all(10),
            child: Text('Nested Card Text'),
          ),
        ),
      );

      expect(find.text('Nested Card Text'), findsOneWidget);
      expect(find.byType(SoftClayCard), findsNWidgets(2));
    });

    test('5. Primary button shadow has positive blurRadius and controlled spread', () {
      expect(AsterConstants.primaryButtonShadow.isNotEmpty, isTrue);
      final btnShadow = AsterConstants.primaryButtonShadow.first;
      expect(btnShadow.blurRadius, equals(12));
      expect(btnShadow.offset, equals(const Offset(0, 5)));
      expect(btnShadow.color.a, greaterThan(0.2));
    });
  });
}
