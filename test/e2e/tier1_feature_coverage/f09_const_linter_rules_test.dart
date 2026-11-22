import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';

void main() {
  group('Feature 09: Const Linter Rules & Widget Immutability', () {
    late String analysisOptionsText;

    setUpAll(() {
      final file = File('analysis_options.yaml');
      expect(file.existsSync(), isTrue);
      analysisOptionsText = file.readAsStringSync();
    });

    test('1. analysis_options.yaml specifies prefer_const_constructors lint rule enabled as true', () {
      expect(analysisOptionsText, contains('prefer_const_constructors: true'));
    });

    test('2. analysis_options.yaml specifies prefer_const_literals_to_create_immutables enabled as true', () {
      expect(analysisOptionsText, contains('prefer_const_literals_to_create_immutables: true'));
    });

    test('3. AsterConstants lists are compile-time constants (identical references)', () {
      const listA = AsterConstants.clayShadow;
      const listB = AsterConstants.clayShadow;
      expect(identical(listA, listB), isTrue,
          reason: 'BoxShadow lists in AsterConstants must be true compile-time constants');

      const subtleA = AsterConstants.claySubtleShadow;
      const subtleB = AsterConstants.claySubtleShadow;
      expect(identical(subtleA, subtleB), isTrue);

      const listShadowA = AsterConstants.clayListShadow;
      const listShadowB = AsterConstants.clayListShadow;
      expect(identical(listShadowA, listShadowB), isTrue);
    });

    testWidgets('4. Static icons and decorations can be instantiated with const constructors',
        (WidgetTester tester) async {
      const widget = Center(
        child: Icon(Icons.bolt, color: AsterConstants.lavanda),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: widget)));
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('5. Layout spacers (SizedBox) with fixed dimensions instantiate with const',
        (WidgetTester tester) async {
      const spacer = SizedBox(width: 16, height: 16);
      expect(spacer.width, equals(16));
      expect(spacer.height, equals(16));
    });
  });
}
