import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';
import 'package:noesis/core/theme.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature 05: Aster Clay Shadow Simplification', () {
    test('1. AsterConstants.clayShadow defines exactly two BoxShadow layers', () {
      expect(AsterConstants.clayShadow.length, equals(2));
      final primaryLayer = AsterConstants.clayShadow[0];
      final secondaryLayer = AsterConstants.clayShadow[1];

      expect(primaryLayer.blurRadius, equals(18));
      expect(primaryLayer.offset, equals(const Offset(0, 8)));
      expect(primaryLayer.spreadRadius, equals(-4));

      expect(secondaryLayer.blurRadius, equals(6));
      expect(secondaryLayer.offset, equals(const Offset(0, 2)));
    });

    test('2. AsterConstants.claySubtleShadow defines a simplified single-layer shadow for dense items', () {
      expect(AsterConstants.claySubtleShadow.length, equals(1));
      final shadow = AsterConstants.claySubtleShadow[0];

      expect(shadow.blurRadius, equals(8));
      expect(shadow.offset, equals(const Offset(0, 3)));
      expect(shadow.spreadRadius, equals(-2));
      expect(shadow.color, equals(const Color.fromRGBO(60, 60, 120, 0.05)));
    });

    testWidgets('3. SoftClayCard applies clayShadow in light theme mode',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayCard(
          child: Text('Card Content'),
        ),
        themeMode: ThemeMode.light,
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, equals(AsterConstants.clayShadow));
    });

    testWidgets('4. SoftClayCard adapts shadow to dark elevation in dark theme mode',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayCard(
          child: Text('Dark Card Content'),
        ),
        themeMode: ThemeMode.dark,
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, equals(1));
      expect(decoration.boxShadow!.first.color, equals(Colors.black.withValues(alpha: 0.35)));
      expect(decoration.boxShadow!.first.blurRadius, equals(24));
    });

    testWidgets('5. SoftClayCard preserves radiusLarge by default and allows radius customization',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const Column(
          children: [
            SoftClayCard(borderRadius: AsterConstants.radiusLarge, child: Text('Default Radius')),
            SoftClayCard(borderRadius: AsterConstants.radiusMedium, child: Text('Custom Radius')),
          ],
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container)).toList();
      final dec1 = containers[0].decoration as BoxDecoration;
      final dec2 = containers[1].decoration as BoxDecoration;

      expect(dec1.borderRadius, equals(BorderRadius.circular(28.0)));
      expect(dec2.borderRadius, equals(BorderRadius.circular(16.0)));
    });

    test('6. AsterConstants.clayListShadow defines single-layer shadow for repeating lists', () {
      expect(AsterConstants.clayListShadow.length, equals(1));
      final shadow = AsterConstants.clayListShadow[0];

      expect(shadow.blurRadius, equals(10));
      expect(shadow.offset, equals(const Offset(0, 4)));
      expect(shadow.spreadRadius, equals(-2));
      expect(shadow.color, equals(const Color.fromRGBO(60, 60, 120, 0.07)));
    });

    testWidgets('7. SoftClayCard.list applies clayListShadow in light theme mode',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayCard.list(
          child: Text('Dense List Item'),
        ),
        themeMode: ThemeMode.light,
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, equals(AsterConstants.clayListShadow));
    });

    testWidgets('8. SoftClayCard with useListShadow: true applies clayListShadow',
        (WidgetTester tester) async {
      await TestAppHarness.pumpInHarness(
        tester,
        const SoftClayCard(
          useListShadow: true,
          child: Text('Dense List Item with Flag'),
        ),
        themeMode: ThemeMode.light,
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, equals(AsterConstants.clayListShadow));
    });
  });
}
