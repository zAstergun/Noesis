import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tier 2 - Feature 10: Stream Filtering & Distinct Boundary Cases', () {
    test('1. distinct() compares item-level equality across list emissions', () async {
      final controller = StreamController<List<Map<String, dynamic>>>();
      final emissions = <List<Map<String, dynamic>>>[];

      final distinctStream = controller.stream.distinct((prev, next) {
        if (prev.length != next.length) return false;
        for (int i = 0; i < prev.length; i++) {
          if (!mapEquals(prev[i], next[i])) return false;
        }
        return true;
      });

      final sub = distinctStream.listen(emissions.add);

      // Emission 1
      controller.add([{'id': '1', 'duration': 45}]);
      await Future.delayed(const Duration(milliseconds: 10));

      // Duplicate
      controller.add([{'id': '1', 'duration': 45}]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emissions.length, equals(1));

      // Modified item
      controller.add([{'id': '1', 'duration': 60}]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emissions.length, equals(2));

      await sub.cancel();
      await controller.close();
    });

    test('2. 50 rapid emissions of identical payloads emit exactly 1 distinct event', () async {
      final controller = StreamController<int>();
      int eventCount = 0;

      final sub = controller.stream.distinct().listen((_) => eventCount++);

      for (int i = 0; i < 50; i++) {
        controller.add(42);
      }
      await Future.delayed(const Duration(milliseconds: 20));

      expect(eventCount, equals(1));

      await sub.cancel();
      await controller.close();
    });

    test('3. Stream transitions from populated list to empty list ([]) cleanly', () async {
      final controller = StreamController<List<String>>();
      final emissions = <List<String>>[];

      final sub = controller.stream.listen(emissions.add);

      controller.add(['Session 1', 'Session 2']);
      await Future.delayed(const Duration(milliseconds: 10));

      controller.add([]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emissions.length, equals(2));
      expect(emissions.last, isEmpty);

      await sub.cancel();
      await controller.close();
    });

    test('4. Stream cancellation before emission does not trigger callbacks', () async {
      final controller = StreamController<String>();
      bool callbackFired = false;

      final sub = controller.stream.listen((_) => callbackFired = true);
      await sub.cancel();

      controller.add('Event after cancel');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(callbackFired, isFalse);
      await controller.close();
    });

    test('5. Broadcast stream allows multiple concurrent distinct subscriptions', () async {
      final controller = StreamController<int>.broadcast();
      int sub1Count = 0;
      int sub2Count = 0;

      final s1 = controller.stream.distinct().listen((_) => sub1Count++);
      final s2 = controller.stream.distinct().listen((_) => sub2Count++);

      controller.add(10);
      controller.add(10); // Duplicate
      controller.add(20); // New
      await Future.delayed(const Duration(milliseconds: 20));

      expect(sub1Count, equals(2));
      expect(sub2Count, equals(2));

      await s1.cancel();
      await s2.cancel();
      await controller.close();
    });
  });
}
