import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import '../harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Tier 3: AI Tool Calling & Calendar Scheduling Interaction', () {
    test('1. schedule_calendar_event schema processes ISO 8601 start time and duration', () {
      final args = {
        'title': 'Reunião de Alinhamento Cloud',
        'start_time_iso': DateTime(2026, 12, 5, 14).toIso8601String(),
        'duration_minutes': 60,
        'category': 'work',
      };

      final startTime = DateTime.parse(args['start_time_iso'] as String);
      final duration = (args['duration_minutes'] as num).toInt();
      final endTime = startTime.add(Duration(minutes: duration));

      expect(endTime.isAfter(startTime), isTrue);
      expect(endTime.difference(startTime).inMinutes, equals(60));
    });

    test('2. AI tool scheduling in Guest Mode succeeds and persists to in-memory events', () async {
      final startTime = DateTime(2026, 12, 6, 10);
      final endTime = startTime.add(const Duration(minutes: 90));

      await SupabaseService.addCalendarEvent(
        title: 'AI Scheduled Study Block',
        category: 'study',
        startTime: startTime,
        endTime: endTime,
      );

      final events = await SupabaseService.getCalendarEvents();
      expect(events.any((e) => e['title'] == 'AI Scheduled Study Block'), isTrue);
    });
  });
}
