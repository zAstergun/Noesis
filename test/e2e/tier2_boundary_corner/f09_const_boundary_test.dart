import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/constants.dart';

void main() {
  group('Tier 2 - Feature 09: Const Invariants & Edge Cases', () {
    test('1. Complex BoxDecorations with const gradients are true compile-time constants', () {
      const decA = BoxDecoration(
        color: AsterConstants.surfaceCard,
        borderRadius: BorderRadius.all(Radius.circular(AsterConstants.radiusMedium)),
      );
      const decB = BoxDecoration(
        color: AsterConstants.surfaceCard,
        borderRadius: BorderRadius.all(Radius.circular(AsterConstants.radiusMedium)),
      );

      expect(identical(decA, decB), isTrue);
    });

    test('2. Compile-time constant lists in AsterConstants throw UnsupportedError upon mutation attempt', () {
      expect(
        () => (AsterConstants.clayShadow as dynamic).add(const BoxShadow()),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('3. Reused EdgeInsets constant instances share identical object identity', () {
      const padding1 = EdgeInsets.all(22);
      const padding2 = EdgeInsets.all(22);
      expect(identical(padding1, padding2), isTrue);
    });

    test('4. Const TextStyle references evaluate without runtime object allocation', () {
      const style1 = TextStyle(fontSize: 14, color: AsterConstants.textDark);
      const style2 = TextStyle(fontSize: 14, color: AsterConstants.textDark);
      expect(identical(style1, style2), isTrue);
    });

    test('5. RoundedRectangleBorder instances with clay radius tokens are constant-creatable', () {
      const border = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AsterConstants.radiusLarge)),
      );
      expect(border.borderRadius, equals(BorderRadius.circular(28.0)));
    });
  });
}
