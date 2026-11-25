import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/flashcards/models/flashcard_model.dart';
import '../features/notebooks/models/notebook_model.dart';
import '../features/quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../features/quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../features/quizzes/data/saved_exams_store_web.dart' as local_store;

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // ----------------------------------------------------
  // AUTH & ASTER ACCOUNT
  // ----------------------------------------------------
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
    return response;
  }

  static Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await client.auth.signInWithOAuth(
      provider,
      scopes: provider == OAuthProvider.discord ? 'identify email' : null,
      redirectTo: kIsWeb ? null : 'io.supabase.noesis://login-callback/',
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error loading Aster Profile: $e');
      return null;
    }
  }

  // ----------------------------------------------------
  // WEEKLY STUDY GOAL (local cache + profiles.stats)
  // ----------------------------------------------------
  static const int defaultWeeklyGoalMinutes = 25 * 60; // 25h padrão
  static const int minWeeklyGoalMinutes = 30; // 30m mínimo
  static const int maxWeeklyGoalMinutes = 168 * 60; // 168h máximo (semana inteira)
  static final ValueNotifier<int> weeklyGoalMinutesNotifier =
      ValueNotifier<int>(defaultWeeklyGoalMinutes);

  static String formatGoalDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0h';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '${hours}h';
    if (hours == 0) return '${mins}m';
    return '${hours}h ${mins}m';
  }

  static int computeCurrentWeekStudiedMinutes(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sundayEnd = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    int total = 0;
    for (final session in sessions) {
      final mins = (session['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (session['study_date'] ?? session['created_at'] ?? '').toString().trim();
      if (rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (!day.isBefore(monday) && !day.isAfter(sundayEnd)) {
        total += mins;
      }
    }
    return total;
  }

  static int computeCurrentStreakDays(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
  }) {
    final activeDays = <DateTime>{};
    for (final session in sessions) {
      final mins = (session['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final rawDate = (session['study_date'] ?? session['created_at'] ?? '').toString().trim();
      if (rawDate.isEmpty) continue;
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      activeDays.add(DateTime(parsed.year, parsed.month, parsed.day));
    }
    if (activeDays.isEmpty) return 0;

    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime cursor;
    if (activeDays.contains(today)) {
      cursor = today;
    } else if (activeDays.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<int> loadWeeklyGoalMinutes() async {
    int? resolved;
    try {
      final raw = await local_store.readSavedExamsRaw('noesis_weekly_goal_v1');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['weekly_goal_minutes'] is num) {
          final parsed = (decoded['weekly_goal_minutes'] as num).toInt();
          if (parsed >= minWeeklyGoalMinutes && parsed <= maxWeeklyGoalMinutes) {
            resolved = parsed;
          }
        }
      }
    } catch (_) {}

    if (currentUser != null) {
      try {
        final profile = await getProfile();
        final stats = profile?['stats'];
        if (stats is Map && stats['noesis_weekly_goal_minutes'] is num) {
          final remote = (stats['noesis_weekly_goal_minutes'] as num).toInt();
          if (remote >= minWeeklyGoalMinutes && remote <= maxWeeklyGoalMinutes) {
            resolved = remote;
            unawaited(
              local_store.writeSavedExamsRaw(
                'noesis_weekly_goal_v1',
                jsonEncode({'weekly_goal_minutes': remote}),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar meta semanal do Supabase: $e');
      }
    }

    final finalMinutes = resolved ?? defaultWeeklyGoalMinutes;
    weeklyGoalMinutesNotifier.value = finalMinutes;
    return finalMinutes;
  }

  static Future<void> saveWeeklyGoalMinutes(int minutes) async {
    final clamped = minutes.clamp(minWeeklyGoalMinutes, maxWeeklyGoalMinutes);
    weeklyGoalMinutesNotifier.value = clamped;

    try {
      await local_store.writeSavedExamsRaw(
        'noesis_weekly_goal_v1',
        jsonEncode({
          'weekly_goal_minutes': clamped,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}

    if (currentUser != null) {
      try {
        final profile = await getProfile();
        final currentStats = profile?['stats'] is Map
            ? Map<String, dynamic>.from(profile!['stats'] as Map)
            : <String, dynamic>{};
        currentStats['noesis_weekly_goal_minutes'] = clamped;
        await client
            .from('profiles')
            .update({
              'stats': currentStats,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao salvar meta semanal no Supabase: $e');
      }
    }
  }

  // ----------------------------------------------------
  // STUDY SESSIONS (noesis_sessions)
  // ----------------------------------------------------
  static final StreamController<List<Map<String, dynamic>>> _studySessionsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static List<Map<String, dynamic>> _inMemoryStudySessions = [];
  static bool _seededMockSessions = false;

  static void _seedInitialStudySessions() {
    if (_seededMockSessions) return;
    _seededMockSessions = true;
    final now = DateTime.now();
    _inMemoryStudySessions = [
      {
        'id': 'session-mock-1',
        'subject': 'Criptografia',
        'topic': 'AES-GCM & Modos de Operação',
        'duration_minutes': 90,
        'study_date': now.subtract(const Duration(hours: 3)).toIso8601String().split('T').first,
        'notes': 'Análise de nonce reuse e ataques de replay.',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        'id': 'session-mock-2',
        'subject': 'Cloud / AWS',
        'topic': 'VPC Peering & IAM Security',
        'duration_minutes': 60,
        'study_date': now.subtract(const Duration(days: 1)).toIso8601String().split('T').first,
        'notes': 'Políticas de least privilege e endpoints de VPC.',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 'session-mock-3',
        'subject': 'Redes & OWASP',
        'topic': 'SQL Injection & XSS Mitigations',
        'duration_minutes': 45,
        'study_date': now.subtract(const Duration(days: 2)).toIso8601String().split('T').first,
        'notes': 'Laboratório prático com headers de CSP.',
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 'session-mock-4',
        'subject': 'Sistemas Dist.',
        'topic': 'Raft Consensus & Eventual Consistency',
        'duration_minutes': 75,
        'study_date': now.subtract(const Duration(days: 3)).toIso8601String().split('T').first,
        'notes': 'Leitura do paper do Raft e análise de split-brain.',
        'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];
  }

  static Future<void> _hydrateLocalStudySessions() async {
    if (currentUser == null) {
      _seedInitialStudySessions();
    }
    try {
      final raw = await local_store.readSavedExamsRaw('noesis_study_sessions_v1');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          _inMemoryStudySessions = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (_) {}
  }

  static Future<void> _persistLocalStudySessions() async {
    try {
      await local_store.writeSavedExamsRaw(
        'noesis_study_sessions_v1',
        jsonEncode(_inMemoryStudySessions),
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getStudySessions({int limit = 50}) async {
    if (currentUser == null) {
      await _hydrateLocalStudySessions();
      return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
    }
    try {
      final res = await client
          .from('noesis_sessions')
          .select()
          .eq('user_id', currentUser!.id)
          .order('study_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(res);
      _inMemoryStudySessions = list;
      unawaited(_persistLocalStudySessions());
      return list;
    } catch (_) {
      return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
    }
  }

  static Stream<List<Map<String, dynamic>>> studySessionsStream() {
    if (currentUser == null) {
      _seedInitialStudySessions();
      return Stream<List<Map<String, dynamic>>>.multi((controller) {
        controller.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
        final sub = _studySessionsStreamController.stream.listen((sessions) {
          controller.add(sessions);
        });
        controller.onCancel = () => sub.cancel();
      });
    }

    return client
        .from('noesis_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('study_date', ascending: false)
        .map((sessions) => List<Map<String, dynamic>>.from(sessions));
  }

  static Future<void> addStudySession({
    required String subject,
    required String topic,
    required int durationMinutes,
    required DateTime studyDate,
    String? notes,
  }) async {
    await _hydrateLocalStudySessions();
    final tempId = 'sess-${DateTime.now().millisecondsSinceEpoch}';
    final dateOnly = studyDate.toIso8601String().split('T').first;
    final newSession = {
      'id': tempId,
      'user_id': currentUser?.id,
      'subject': subject,
      'topic': topic,
      'duration_minutes': durationMinutes,
      'study_date': dateOnly,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    _inMemoryStudySessions.insert(0, newSession);
    _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
    await _persistLocalStudySessions();

    if (currentUser != null) {
      try {
        final inserted = await client
            .from('noesis_sessions')
            .insert({
              'user_id': currentUser!.id,
              'subject': subject,
              'topic': topic,
              'duration_minutes': durationMinutes,
              'study_date': dateOnly,
              'notes': notes,
            })
            .select()
            .single();
        final idx = _inMemoryStudySessions.indexWhere((s) => s['id'] == tempId);
        if (idx != -1) {
          _inMemoryStudySessions[idx] = Map<String, dynamic>.from(inserted);
          _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
          await _persistLocalStudySessions();
        }
      } catch (e) {
        debugPrint('Erro ao persistir sessão no Supabase: $e');
      }
    }
  }

  static Future<void> updateStudySession({
    required String id,
    required String subject,
    required String topic,
    required int durationMinutes,
    required DateTime studyDate,
    String? notes,
  }) async {
    await _hydrateLocalStudySessions();
    final dateOnly = studyDate.toIso8601String().split('T').first;
    final idx = _inMemoryStudySessions.indexWhere((s) => s['id'] == id);
    if (idx != -1) {
      _inMemoryStudySessions[idx] = {
        ..._inMemoryStudySessions[idx],
        'subject': subject,
        'topic': topic,
        'duration_minutes': durationMinutes,
        'study_date': dateOnly,
        'notes': notes,
      };
      _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
      await _persistLocalStudySessions();
    }

    if (currentUser != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      try {
        await client
            .from('noesis_sessions')
            .update({
              'subject': subject,
              'topic': topic,
              'duration_minutes': durationMinutes,
              'study_date': dateOnly,
              'notes': notes,
            })
            .eq('id', id)
            .eq('user_id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao atualizar sessão no Supabase: $e');
      }
    }
  }

  static Future<void> deleteStudySession(String id) async {
    await _hydrateLocalStudySessions();
    _inMemoryStudySessions.removeWhere((s) => s['id'] == id);
    _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));
    await _persistLocalStudySessions();

    if (currentUser != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      try {
        await client
            .from('noesis_sessions')
            .delete()
            .eq('id', id)
            .eq('user_id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao deletar sessão no Supabase: $e');
      }
    }
  }

  // ----------------------------------------------------
  // CALENDAR EVENTS (noesis_calendar_events)
  // ----------------------------------------------------
  static final StreamController<List<Map<String, dynamic>>> _calendarStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static List<Map<String, dynamic>> _inMemoryCalendarEvents = [];
  static bool _seededMockCalendar = false;

  static void _seedInitialCalendarEvents() {
    if (_seededMockCalendar) return;
    _seededMockCalendar = true;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    DateTime at(int dayOffset, int hour, int minute) {
      final d = monday.add(Duration(days: dayOffset));
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    _inMemoryCalendarEvents = [
      {
        'id': 'mock-1',
        'title': 'Criptografia · Modos de Operação',
        'description': 'Estudo aprofundado de AES-GCM e nonce reuse.',
        'category': 'study',
        'start_time': at(0, 8, 0).toIso8601String(), // Seg 08:00
        'end_time': at(0, 9, 30).toIso8601String(), // 1.5h
        'is_completed': true,
      },
      {
        'id': 'mock-2',
        'title': 'Lab OWASP · SQLi & XSS',
        'description': 'Prática no ambiente de laboratório com testes de penetração.',
        'category': 'lab',
        'start_time': at(1, 9, 0).toIso8601String(), // Ter 09:00
        'end_time': at(1, 11, 0).toIso8601String(), // 2h
        'is_completed': true,
      },
      {
        'id': 'mock-3',
        'title': 'Criptografia · Hashing & MAC',
        'description': 'Revisão de HMAC, SHA-256 e PBKDF2.',
        'category': 'study',
        'start_time': at(2, 8, 0).toIso8601String(), // Qua 08:00
        'end_time': at(2, 9, 30).toIso8601String(), // 1.5h
        'is_completed': true,
      },
      {
        'id': 'mock-4',
        'title': 'Mentoria de Carreira & Certificações',
        'description': 'Alinhamento de cronograma para Security+ e AWS SAA.',
        'category': 'exam',
        'start_time': at(2, 14, 0).toIso8601String(), // Qua 14:00
        'end_time': at(2, 15, 0).toIso8601String(), // 1h
        'is_completed': true,
      },
      {
        'id': 'mock-5',
        'title': 'Simulado #12 · Security+',
        'description': 'Simulado com 50 questões focadas em Arquitetura e Ameaças.',
        'category': 'lab',
        'start_time': at(3, 10, 0).toIso8601String(), // Qui 10:00
        'end_time': at(3, 11, 30).toIso8601String(), // 1.5h
        'is_completed': false,
      },
      {
        'id': 'mock-6',
        'title': 'Deep work · Cloud Security',
        'description': 'Estudo de arquitetura de nuvem AWS, IAM e VPC Peering.',
        'category': 'study',
        'start_time': at(4, 9, 0).toIso8601String(), // Sex 09:00
        'end_time': at(4, 12, 0).toIso8601String(), // 3h
        'is_completed': false,
      },
      {
        'id': 'mock-7',
        'title': 'Revisão Criptografia',
        'description': 'Revisão espaçada dos conceitos de chaves assimétricas.',
        'category': 'review',
        'start_time': at(4, 14, 0).toIso8601String(), // Sex 14:00
        'end_time': at(4, 15, 0).toIso8601String(), // 1h
        'is_completed': false,
      },
      {
        'id': 'mock-8',
        'title': 'Prova Oficial Security+',
        'description': '16:00 · Pearson VUE · Trazer dois documentos com foto.',
        'category': 'exam',
        'start_time': at(4, 16, 0).toIso8601String(), // Sex 16:00
        'end_time': at(4, 18, 0).toIso8601String(), // 2h
        'is_completed': false,
      },
      {
        'id': 'mock-9',
        'title': 'Planejamento Semanal',
        'description': 'Definir metas para a semana seguinte e checar métricas.',
        'category': 'lab',
        'start_time': at(5, 10, 0).toIso8601String(), // Sáb 10:00
        'end_time': at(5, 11, 0).toIso8601String(), // 1h
        'is_completed': false,
      },
    ];
  }

  static Future<List<Map<String, dynamic>>> getCalendarEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _seedInitialCalendarEvents();
    if (currentUser == null) {
      return List<Map<String, dynamic>>.from(_inMemoryCalendarEvents);
    }
    try {
      var query = client.from('noesis_calendar_events').select().eq('user_id', currentUser!.id);

      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('end_time', endDate.toIso8601String());
      }

      final res = await query.order('start_time', ascending: true);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isEmpty) {
        return List<Map<String, dynamic>>.from(_inMemoryCalendarEvents);
      }
      return list;
    } catch (_) {
      return List<Map<String, dynamic>>.from(_inMemoryCalendarEvents);
    }
  }

  static Stream<List<Map<String, dynamic>>> calendarEventsStream() {
    _seedInitialCalendarEvents();
    if (currentUser == null) {
      return Stream<List<Map<String, dynamic>>>.multi((controller) {
        controller.add(List<Map<String, dynamic>>.from(_inMemoryCalendarEvents));
        final sub = _calendarStreamController.stream.listen((events) {
          controller.add(events);
        });
        controller.onCancel = () => sub.cancel();
      });
    }

    return client
        .from('noesis_calendar_events')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('start_time', ascending: true)
        .map((events) {
          if (events.isEmpty) {
            return List<Map<String, dynamic>>.from(_inMemoryCalendarEvents);
          }
          return events;
        });
  }

  static Future<void> addCalendarEvent({
    required String title,
    String? description,
    String category = 'study',
    String? color,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _seedInitialCalendarEvents();
    final newEvent = {
      'id': 'evt-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser?.id,
      'title': title,
      'description': description,
      'category': category,
      'color': ?color,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    _inMemoryCalendarEvents.add(newEvent);
    _calendarStreamController.add(List<Map<String, dynamic>>.from(_inMemoryCalendarEvents));

    if (currentUser != null) {
      try {
        final payload = {
          'user_id': currentUser!.id,
          'title': title,
          'description': description,
          'category': category,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
        };
        if (color != null) {
          payload['color'] = color;
        }
        await client.from('noesis_calendar_events').insert(payload);
      } catch (e) {
        debugPrint('Erro ao persistir evento no Supabase: $e');
      }
    }
  }

  static Future<void> deleteCalendarEvent(String id) async {
    _seedInitialCalendarEvents();
    _inMemoryCalendarEvents.removeWhere((e) => e['id'] == id);
    _calendarStreamController.add(List<Map<String, dynamic>>.from(_inMemoryCalendarEvents));

    if (currentUser != null) {
      try {
        await client.from('noesis_calendar_events').delete().eq('id', id);
      } catch (e) {
        debugPrint('Erro ao deletar evento no Supabase: $e');
      }
    }
  }

  static Future<void> toggleCalendarEventCompleted(String id, bool isCompleted) async {
    _seedInitialCalendarEvents();
    final idx = _inMemoryCalendarEvents.indexWhere((e) => e['id'] == id);
    if (idx != -1) {
      _inMemoryCalendarEvents[idx]['is_completed'] = isCompleted;
      _calendarStreamController.add(List<Map<String, dynamic>>.from(_inMemoryCalendarEvents));
    }

    if (currentUser != null) {
      try {
        await client.from('noesis_calendar_events').update({'is_completed': isCompleted}).eq('id', id);
      } catch (e) {
        debugPrint('Erro ao atualizar status do evento no Supabase: $e');
      }
    }
  }

  static Future<void> updateCalendarEvent({
    required String id,
    String? title,
    String? description,
    String? category,
    String? color,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    _seedInitialCalendarEvents();
    final idx = _inMemoryCalendarEvents.indexWhere((e) => e['id'] == id);
    if (idx != -1) {
      if (title != null) _inMemoryCalendarEvents[idx]['title'] = title;
      if (description != null) _inMemoryCalendarEvents[idx]['description'] = description;
      if (category != null) _inMemoryCalendarEvents[idx]['category'] = category;
      if (color != null) _inMemoryCalendarEvents[idx]['color'] = color;
      if (startTime != null) _inMemoryCalendarEvents[idx]['start_time'] = startTime.toIso8601String();
      if (endTime != null) _inMemoryCalendarEvents[idx]['end_time'] = endTime.toIso8601String();
      _calendarStreamController.add(List<Map<String, dynamic>>.from(_inMemoryCalendarEvents));
    }

    if (currentUser != null) {
      try {
        final payload = <String, dynamic>{
          'title': ?title,
          'description': ?description,
          'category': ?category,
          'color': ?color,
          if (startTime != null) 'start_time': startTime.toIso8601String(),
          if (endTime != null) 'end_time': endTime.toIso8601String(),
        };
        await client.from('noesis_calendar_events').update(payload).eq('id', id);
      } catch (e) {
        debugPrint('Erro ao atualizar evento no Supabase: $e');
      }
    }
  }

  // ----------------------------------------------------
  // QUIZZES (noesis_quizzes)
  // ----------------------------------------------------
  static final List<Map<String, dynamic>> _inMemoryQuizzes = [];

  static Future<List<Map<String, dynamic>>> getQuizzes() async {
    if (currentUser == null) {
      return List<Map<String, dynamic>>.from(_inMemoryQuizzes);
    }
    try {
      final res = await client
          .from('noesis_quizzes')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return List<Map<String, dynamic>>.from(_inMemoryQuizzes);
    }
  }

  static Future<Map<String, dynamic>> saveGeneratedQuiz({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questionsData,
    String? difficulty,
  }) async {
    final quizRecord = {
      'id': 'quiz-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser?.id,
      'title': title,
      'subject': subject,
      'difficulty': difficulty ?? 'Médio / Prático',
      'questions_data': questionsData,
      'score_percentage': null,
      'time_spent_seconds': null,
      'completed_at': null,
      'created_at': DateTime.now().toIso8601String(),
    };
    _inMemoryQuizzes.insert(0, quizRecord);

    if (currentUser != null) {
      try {
        await client.from('noesis_quizzes').insert({
          'user_id': currentUser!.id,
          'title': title,
          'subject': subject,
          'questions_data': questionsData,
        });
      } catch (e) {
        debugPrint('Erro ao persistir simulado gerado no Supabase: $e');
      }
    }
    return quizRecord;
  }

  static Future<void> deleteQuiz(String quizId) async {
    _inMemoryQuizzes.removeWhere((q) => q['id']?.toString() == quizId);
    if (currentUser != null) {
      try {
        await client
            .from('noesis_quizzes')
            .delete()
            .eq('id', quizId)
            .eq('user_id', currentUser!.id);
      } catch (e) {
        debugPrint('Erro ao excluir simulado no Supabase: $e');
      }
    }
  }

  static Future<void> saveQuizResult({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questionsData,
    required double scorePercentage,
    required int timeSpentSeconds,
    String? documentId,
  }) async {
    final quizRecord = {
      'id': 'quiz-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser?.id,
      'title': title,
      'subject': subject,
      'questions_data': questionsData,
      'score_percentage': scorePercentage,
      'time_spent_seconds': timeSpentSeconds,
      'completed_at': DateTime.now().toIso8601String(),
      'document_id': documentId,
    };
    _inMemoryQuizzes.insert(0, quizRecord);

    if (currentUser != null) {
      try {
        await client.from('noesis_quizzes').insert({
          'user_id': currentUser!.id,
          'title': title,
          'subject': subject,
          'questions_data': questionsData,
          'score_percentage': scorePercentage,
          'time_spent_seconds': timeSpentSeconds,
          'completed_at': DateTime.now().toIso8601String(),
          'document_id': documentId,
        });
      } catch (e) {
        debugPrint('Erro ao persistir resultado do simulado no Supabase: $e');
      }
    }
  }

  /// Salva ou atualiza um simulado completo na tabela `noesis_quizzes` (incluindo respostas e review da IA).
  static Future<void> upsertSavedExamAttempt(Map<String, dynamic> attemptJson) async {
    final attemptKey = (attemptJson['id'] ?? '').toString().trim();
    if (attemptKey.isEmpty) return;

    final existingMemIdx = _inMemoryQuizzes.indexWhere(
      (q) => q['attempt_key'] == attemptKey || q['id'] == attemptKey,
    );
    final memRecord = {
      'id': attemptKey,
      'attempt_key': attemptKey,
      'user_id': currentUser?.id,
      'group_key': attemptJson['groupKey'],
      'exam_model_id': attemptJson['examModelId'],
      'exam_model_name': attemptJson['examModelName'],
      'title': attemptJson['title'] ?? 'Simulado',
      'subject': attemptJson['subject'] ?? 'Geral',
      'topic': attemptJson['topic'] ?? '',
      'difficulty': attemptJson['difficulty'] ?? 'Médio / Prático',
      'target_total_count': attemptJson['targetTotalCount'],
      'questions_data': attemptJson['questions'] ?? const [],
      'user_answers': attemptJson['userAnswers'] ?? const <String, dynamic>{},
      'correct_count': attemptJson['correctCount'] ?? 0,
      'wrong_count': attemptJson['wrongCount'] ?? 0,
      'blank_count': attemptJson['blankCount'] ?? 0,
      'score_percentage': attemptJson['scorePercentage'] ?? 0.0,
      'time_spent_seconds': attemptJson['elapsedSeconds'] ?? 0,
      'time_expired': attemptJson['timeExpired'] == true,
      'ai_review_markdown': attemptJson['aiReviewMarkdown'],
      'completed_at': attemptJson['createdAt'] ?? DateTime.now().toIso8601String(),
    };
    if (existingMemIdx != -1) {
      _inMemoryQuizzes[existingMemIdx] = memRecord;
    } else {
      _inMemoryQuizzes.insert(0, memRecord);
    }

    if (currentUser == null) return;

    try {
      final uid = currentUser!.id;
      final existing = await client
          .from('noesis_quizzes')
          .select('id')
          .eq('user_id', uid)
          .eq('attempt_key', attemptKey)
          .maybeSingle();

      final payload = {
        'user_id': uid,
        'attempt_key': attemptKey,
        'group_key': attemptJson['groupKey'],
        'exam_model_id': attemptJson['examModelId'],
        'exam_model_name': attemptJson['examModelName'],
        'title': attemptJson['title'] ?? 'Simulado',
        'subject': attemptJson['subject'] ?? 'Geral',
        'topic': attemptJson['topic'] ?? '',
        'difficulty': attemptJson['difficulty'] ?? 'Médio / Prático',
        'target_total_count': attemptJson['targetTotalCount'],
        'questions_data': attemptJson['questions'] ?? const [],
        'user_answers': attemptJson['userAnswers'] ?? const <String, dynamic>{},
        'correct_count': attemptJson['correctCount'] ?? 0,
        'wrong_count': attemptJson['wrongCount'] ?? 0,
        'blank_count': attemptJson['blankCount'] ?? 0,
        'score_percentage': attemptJson['scorePercentage'] ?? 0.0,
        'time_spent_seconds': attemptJson['elapsedSeconds'] ?? 0,
        'time_expired': attemptJson['timeExpired'] == true,
        if (attemptJson['aiReviewMarkdown'] != null)
          'ai_review_markdown': attemptJson['aiReviewMarkdown'],
        'completed_at': attemptJson['createdAt'] ?? DateTime.now().toIso8601String(),
      };

      if (existing != null && existing['id'] != null) {
        await client
            .from('noesis_quizzes')
            .update(payload)
            .eq('id', existing['id'])
            .eq('user_id', uid);
      } else {
        await client.from('noesis_quizzes').insert(payload);
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar simulado salvo no Supabase: $e');
    }
  }

  /// Atualiza o markdown da análise da IA para um simulado já salvo no Supabase.
  static Future<void> updateSavedExamAiReview(String attemptKey, String reviewMarkdown) async {
    final memIdx = _inMemoryQuizzes.indexWhere(
      (q) => q['attempt_key'] == attemptKey || q['id'] == attemptKey,
    );
    if (memIdx != -1) {
      _inMemoryQuizzes[memIdx]['ai_review_markdown'] = reviewMarkdown;
    }

    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      await client
          .from('noesis_quizzes')
          .update({'ai_review_markdown': reviewMarkdown})
          .eq('user_id', uid)
          .eq('attempt_key', attemptKey);
    } catch (e) {
      debugPrint('Erro ao atualizar review IA do simulado no Supabase: $e');
    }
  }

  /// Remove um simulado salvo do Supabase.
  static Future<void> deleteSavedExamAttempt(String attemptKey) async {
    _inMemoryQuizzes.removeWhere(
      (q) => q['attempt_key'] == attemptKey || q['id'] == attemptKey,
    );

    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      final deletedByKey = await client
          .from('noesis_quizzes')
          .delete()
          .eq('user_id', uid)
          .eq('attempt_key', attemptKey)
          .select('id');
      if ((deletedByKey as List).isEmpty &&
          RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(attemptKey)) {
        await client
            .from('noesis_quizzes')
            .delete()
            .eq('user_id', uid)
            .eq('id', attemptKey);
      }
    } catch (e) {
      debugPrint('Erro ao excluir simulado salvo no Supabase: $e');
    }
  }

  // ----------------------------------------------------
  // FLASHCARDS & REPETIÇÃO ESPAÇADA
  // ----------------------------------------------------
  static final List<FlashcardDeck> _inMemoryFlashcardDecks = [];
  static bool _flashcardsSeeded = false;

  static void _seedInitialFlashcardDecks() {
    if (_flashcardsSeeded) return;
    _flashcardsSeeded = true;

    final now = DateTime.now();
    _inMemoryFlashcardDecks.addAll([
      FlashcardDeck(
        id: 'deck-crypto-1',
        title: 'Criptografia & Certificação Security+',
        subject: 'Criptografia',
        description: 'Cifras simétricas vs assimétricas, modos de operação, integridade, PFS e assinaturas digitais.',
        colorHex: '7C6CF0',
        iconCode: 0xe5e1,
        createdAt: now.subtract(const Duration(days: 4)),
        cards: [
          Flashcard(
            id: 'c-1',
            front: 'Qual a diferença essencial entre criptografia simétrica e assimétrica?',
            back: 'A simétrica (AES, ChaCha20) usa uma única chave compartilhada para cifrar e decifrar (alta velocidade, ideal para dados massivos). A assimétrica (RSA, ECC) usa um par público/privado (ideal para troca de chaves e assinaturas digitais).',
            tags: ['Criptografia', 'Fundamentos'],
            difficulty: 'easy',
            reviewCount: 3,
            lastReviewed: now.subtract(const Duration(hours: 12)),
          ),
          Flashcard(
            id: 'c-2',
            front: 'O que é Forward Secrecy (PFS - Perfect Forward Secrecy)?',
            back: 'Propriedade que assegura que o vazamento futuro da chave privada de longo prazo do servidor NÃO permita decifrar o tráfego de sessões passadas. Implementado via trocas efêmeras Diffie-Hellman (DHE/ECDHE).',
            tags: ['TLS', 'PFS'],
            difficulty: 'good',
            reviewCount: 2,
            lastReviewed: now.subtract(const Duration(days: 1)),
          ),
          Flashcard(
            id: 'c-3',
            front: 'Qual o papel do Salt e das funções KDF (Argon2, bcrypt, PBKDF2) no hash de senhas?',
            back: 'O Salt adiciona entropia aleatória única para neutralizar Rainbow Tables e hashes idênticos. O KDF aplica custo computacional e de memória calibrado para retardar ataques de força bruta com GPUs e ASICs.',
            tags: ['Hash', 'Segurança'],
            difficulty: 'easy',
            reviewCount: 4,
            lastReviewed: now.subtract(const Duration(hours: 6)),
          ),
          Flashcard(
            id: 'c-4',
            front: 'Como funciona a assinatura digital e o que ela garante?',
            back: 'O emissor calcula o hash da mensagem e o cifra com sua CHAVE PRIVADA. O receptor decifra com a CHAVE PÚBLICA do emissor e valida o hash. Garante: Autenticidade, Integridade e Não-Repúdio.',
            tags: ['PKI', 'Assinatura'],
            difficulty: 'hard',
            reviewCount: 1,
            lastReviewed: now.subtract(const Duration(days: 2)),
          ),
          Flashcard(
            id: 'c-5',
            front: 'Qual a diferença entre AES-CBC e AES-GCM?',
            back: 'AES-CBC oferece apenas confidencialidade e exige padding (vulnerável a Padding Oracle sem MAC). AES-GCM é um modo AEAD que entrega confidencialidade e integridade autenticada simultaneamente em alta performance.',
            tags: ['AES', 'AEAD'],
            difficulty: 'unreviewed',
          ),
        ],
      ),
      FlashcardDeck(
        id: 'deck-cloud-2',
        title: 'Arquitetura Cloud & Resiliência AWS',
        subject: 'Cloud / AWS',
        description: 'Conceitos de VPC, isolamento de subnets, padrões de alta disponibilidade e recuperação de desastres.',
        colorHex: '3CCF9A',
        iconCode: 0xe19f,
        createdAt: now.subtract(const Duration(days: 2)),
        cards: [
          Flashcard(
            id: 'c-6',
            front: 'O que distingue uma Subnet Pública de uma Subnet Privada na AWS VPC?',
            back: 'Subnet Pública possui uma Route Table com rota para um Internet Gateway (0.0.0.0/0 -> IGW). Subnet Privada não possui rota direta para o IGW e utiliza um NAT Gateway (posicionado numa subnet pública) para acesso outbound.',
            tags: ['VPC', 'Redes'],
            difficulty: 'easy',
            reviewCount: 2,
            lastReviewed: now.subtract(const Duration(hours: 20)),
          ),
          Flashcard(
            id: 'c-7',
            front: 'Qual a diferença crucial entre RTO e RPO em Disaster Recovery?',
            back: 'RTO (Recovery Time Objective): tempo máximo suportável fora do ar até a restauração. RPO (Recovery Point Objective): perda máxima de dados tolerável medida no tempo (ex: intervalo de replicação de banco de dados).',
            tags: ['DR', 'Resiliência'],
            difficulty: 'good',
            reviewCount: 2,
            lastReviewed: now.subtract(const Duration(days: 1)),
          ),
          Flashcard(
            id: 'c-8',
            front: 'Qual a vantagem fundamental de IAM Roles sobre IAM Users?',
            back: 'IAM Roles fornecem credenciais temporárias renováveis automaticamente via AWS STS, eliminando senhas e access keys de longa duração hardcoded em servidores ou aplicações.',
            tags: ['IAM', 'Segurança'],
            difficulty: 'easy',
            reviewCount: 3,
            lastReviewed: now.subtract(const Duration(days: 2)),
          ),
          Flashcard(
            id: 'c-9',
            front: 'Como o padrão Dead Letter Queue (DLQ) protege arquiteturas orientadas a eventos?',
            back: 'Isola mensagens malformadas (poison pills) após esgotar o limite de tentativas de reprocessamento, impedindo travamento de consumers e perda silenciosa de eventos.',
            tags: ['SQS', 'Filas'],
            difficulty: 'unreviewed',
          ),
        ],
      ),
      FlashcardDeck(
        id: 'deck-algo-3',
        title: 'Estruturas de Dados & Algoritmos',
        subject: 'Ciência da Computação',
        description: 'Complexidade de tempo Big-O, busca em grafos, balanceamento de árvores e técnicas dinâmicas.',
        colorHex: 'F5A623',
        iconCode: 0xe6df,
        createdAt: now.subtract(const Duration(days: 1)),
        cards: [
          Flashcard(
            id: 'c-10',
            front: 'Qual a complexidade de tempo de busca, inserção e remoção em uma Hash Table?',
            back: 'Caso Médio: O(1) amortizado constante. Pior Caso: O(N) linear quando ocorrem colisões em cadeia e a resolução se degrada para varredura de lista encadeada.',
            tags: ['Big-O', 'Hash'],
            difficulty: 'easy',
            reviewCount: 2,
          ),
          Flashcard(
            id: 'c-11',
            front: 'Quando optar por Busca em Largura (BFS) vs Busca em Profundidade (DFS)?',
            back: 'BFS (usa Fila FIFO) encontra o menor caminho em grafos não ponderados. DFS (usa Pilha/Recursão LIFO) consome menos memória em árvores profundas e é ideal para ordenação topológica e detecção de ciclos.',
            tags: ['Grafos', 'BFS/DFS'],
            difficulty: 'good',
            reviewCount: 1,
          ),
          Flashcard(
            id: 'c-12',
            front: 'O que diferencia o QuickSort do MergeSort na prática?',
            back: 'QuickSort é in-place (O(1) memória adicional) e mais rápido em dados em memória pelo cache, mas pior caso é O(N²). MergeSort é estável e garante O(N log N) sempre, porém exige O(N) memória extra.',
            tags: ['Ordenação', 'Algoritmos'],
            difficulty: 'unreviewed',
          ),
        ],
      ),
    ]);
  }

  static Future<List<FlashcardDeck>> getFlashcardDecks() async {
    _seedInitialFlashcardDecks();
    if (currentUser == null) {
      return List<FlashcardDeck>.from(_inMemoryFlashcardDecks);
    }
    try {
      final res = await client
          .from('noesis_flashcard_decks')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);
      final list = (res as List).map((row) => FlashcardDeck.fromMap(Map<String, dynamic>.from(row))).toList();
      if (list.isEmpty) {
        return List<FlashcardDeck>.from(_inMemoryFlashcardDecks);
      }
      return list;
    } catch (_) {
      return List<FlashcardDeck>.from(_inMemoryFlashcardDecks);
    }
  }

  static Future<FlashcardDeck> saveFlashcardDeck(FlashcardDeck deck) async {
    _seedInitialFlashcardDecks();
    final existingIndex = _inMemoryFlashcardDecks.indexWhere((d) => d.id == deck.id);
    if (existingIndex >= 0) {
      _inMemoryFlashcardDecks[existingIndex] = deck;
    } else {
      _inMemoryFlashcardDecks.insert(0, deck);
    }

    if (currentUser != null) {
      try {
        final payload = {
          'id': deck.id,
          'user_id': currentUser!.id,
          'title': deck.title,
          'subject': deck.subject,
          'description': deck.description,
          'cards': deck.cards.map((c) => c.toMap()).toList(),
          'color_hex': deck.colorHex,
          'icon_code': deck.iconCode,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client.from('noesis_flashcard_decks').upsert(payload);
      } catch (e) {
        debugPrint('Erro ao salvar baralho no Supabase: $e');
      }
    }
    return deck;
  }

  static Future<void> deleteFlashcardDeck(String deckId) async {
    _inMemoryFlashcardDecks.removeWhere((d) => d.id == deckId);
    if (currentUser != null) {
      try {
        await client.from('noesis_flashcard_decks').delete().eq('id', deckId);
      } catch (e) {
        debugPrint('Erro ao excluir baralho no Supabase: $e');
      }
    }
  }

  static Future<void> updateCardReview({
    required String deckId,
    required String cardId,
    required String difficulty,
  }) async {
    _seedInitialFlashcardDecks();
    final deckIndex = _inMemoryFlashcardDecks.indexWhere((d) => d.id == deckId);
    if (deckIndex >= 0) {
      final deck = _inMemoryFlashcardDecks[deckIndex];
      final cardIndex = deck.cards.indexWhere((c) => c.id == cardId);
      if (cardIndex >= 0) {
        final card = deck.cards[cardIndex];
        card.difficulty = difficulty;
        card.reviewCount += 1;
        card.lastReviewed = DateTime.now();
      }
      if (currentUser != null) {
        saveFlashcardDeck(_inMemoryFlashcardDecks[deckIndex]);
      }
    }
  }

  // ----------------------------------------------------
  // CADERNOS DE ESTUDO & ANOTAÇÕES (NOTEBOOKS)
  // ----------------------------------------------------
  static final List<StudyNotebook> _inMemoryNotebooks = [];
  static bool _notebooksSeeded = false;

  static void _seedInitialNotebooks() {
    if (_notebooksSeeded) return;
    _notebooksSeeded = true;

    final now = DateTime.now();
    _inMemoryNotebooks.addAll([
      StudyNotebook(
        id: 'nb-cloud-1',
        title: 'Arquitetura Cloud & Infraestrutura',
        subject: 'Tecnologia',
        description: 'Anotações sobre VPCs, Subnets, Gateways, Roteamento e Práticas de Alta Disponibilidade.',
        colorHex: '7C6CF0',
        iconCode: 0xe3e6, // Icons.menu_book_rounded
        createdAt: now.subtract(const Duration(days: 5)),
        notes: [
          StudyNote(
            id: 'note-cloud-1',
            notebookId: 'nb-cloud-1',
            title: 'Topologia de Redes VPC & Subnets Públicas vs Privadas',
            content: '### Fundamentos de VPC (Virtual Private Cloud)\n\n'
                'Uma VPC é uma rede virtual isolada e dedicada à sua conta em nuvem. '
                'Ao estruturar a rede para aplicações críticas de estudo e produção, dividimos em duas camadas essenciais:\n\n'
                '* **Subnets Públicas:** Têm rota direta para o **Internet Gateway (IGW)**. Hospedam balanceadores de carga (ALB/NLB) e instâncias de borda (Bastion Hosts).\n'
                '* **Subnets Privadas:** Não possuem rota direta para a internet. O tráfego de saída passa por um **NAT Gateway** estrategicamente alocado na subnet pública.\n\n'
                '```bash\n'
                '# Exemplo de verificação de rotas e gateways\n'
                'aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0123456789abcdef0"\n'
                '```\n\n'
                'O diagrama de infraestrutura abaixo exemplifica essa segmentação segura:',
            links: [
              StudyLink(
                id: 'link-cloud-img-1',
                url: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800',
                title: 'Data Center e Infraestrutura Cloud',
                isImage: true,
              ),
              StudyLink(
                id: 'link-cloud-ref-1',
                url: 'https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html',
                title: 'Documentação Oficial Amazon VPC',
                isImage: false,
              ),
            ],
            tags: ['Cloud', 'AWS', 'VPC', 'Infra'],
            createdAt: now.subtract(const Duration(days: 3)),
          ),
          StudyNote(
            id: 'note-cloud-2',
            notebookId: 'nb-cloud-1',
            title: 'Configuração de Segurança: Security Groups vs Network ACLs',
            content: '### Comparativo de Camadas de Defesa em Profundidade\n\n'
                '1. **Security Groups:** Statefull (com estado). Atuam no nível da interface de rede elástica (ENI). Regras de entrada autorizam automaticamente as saídas de resposta correspondentes.\n'
                '2. **NACLs (Network Access Control Lists):** Stateless (sem estado). Atuam no nível da subnet inteira como filtro de pacotes por número de regra.\n\n'
                'Recomenda-se manter as NACLs com regras padrão de permissão e focar o controle granular nos Security Groups.',
            links: [
              StudyLink(
                id: 'link-cloud-img-2',
                url: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
                title: 'Roteamento de Redes e Servidores',
                isImage: true,
              ),
            ],
            tags: ['Segurança', 'NACL', 'Firewall'],
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
      StudyNotebook(
        id: 'nb-crypto-2',
        title: 'Criptografia Aplicada & Segurança da Informação',
        subject: 'Criptografia',
        description: 'Protocolos de segurança, cifras de chave pública, curvas elípticas e TLS 1.3.',
        colorHex: '5DC6A1',
        iconCode: 0xe5e1, // Icons.security_rounded
        createdAt: now.subtract(const Duration(days: 2)),
        notes: [
          StudyNote(
            id: 'note-crypto-1',
            notebookId: 'nb-crypto-2',
            title: 'Handshake TLS 1.3 e Perfect Forward Secrecy (PFS)',
            content: '### Otimização e Segurança no TLS 1.3 (RFC 8446)\n\n'
                'O protocolo TLS 1.3 reduziu o tempo de handshake para **1-RTT** (ou até 0-RTT com retomada de sessão) '
                'e removeu cifras obsoletas que não ofereciam Perfect Forward Secrecy.\n\n'
                '* **Cifras Estáticas Removidas:** RSA Key Exchange estático foi abolido.\n'
                '* **Obrigatório:** Troca de chaves efêmera baseada em Diffie-Hellman (ECDHE com Curve25519 ou P-256).\n'
                '* **Cifras Suportadas:** AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305.\n\n'
                'O segredo de encaminhamento perfeito garante que, mesmo que a chave de longo prazo do servidor seja violada no futuro, os dados trafegados no passado permanecem indecifráveis.',
            links: [
              StudyLink(
                id: 'link-crypto-img-1',
                url: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800',
                title: 'Código Criptográfico e Segurança de Dados',
                isImage: true,
              ),
              StudyLink(
                id: 'link-crypto-ref-1',
                url: 'https://www.rfc-editor.org/rfc/rfc8446',
                title: 'RFC 8446: Protocolo TLS 1.3',
                isImage: false,
              ),
            ],
            tags: ['TLS 1.3', 'PFS', 'ECDHE', 'Criptografia'],
            createdAt: now.subtract(const Duration(hours: 18)),
          ),
        ],
      ),
    ]);
  }

  static Future<List<StudyNotebook>> getNotebooks() async {
    _seedInitialNotebooks();

    if (currentUser != null) {
      try {
        final res = await client
            .from('noesis_study_notebooks')
            .select()
            .eq('user_id', currentUser!.id)
            .order('created_at', ascending: false);
        final list = (res as List)
            .map((row) => StudyNotebook.fromMap(Map<String, dynamic>.from(row)))
            .toList();
        if (list.isNotEmpty) {
          return list;
        }
      } catch (e) {
        debugPrint('Erro ao buscar cadernos no Supabase: $e');
      }
    }
    return List<StudyNotebook>.from(_inMemoryNotebooks);
  }

  static Future<StudyNotebook> saveNotebook(StudyNotebook notebook) async {
    _seedInitialNotebooks();
    final idx = _inMemoryNotebooks.indexWhere((n) => n.id == notebook.id);
    if (idx >= 0) {
      _inMemoryNotebooks[idx] = notebook;
    } else {
      _inMemoryNotebooks.insert(0, notebook);
    }

    if (currentUser != null) {
      try {
        final payload = {
          'id': notebook.id,
          'user_id': currentUser!.id,
          'title': notebook.title,
          'subject': notebook.subject,
          'description': notebook.description,
          'color_hex': notebook.colorHex,
          'icon_code': notebook.iconCode,
          'notes': notebook.notes.map((n) => n.toMap()).toList(),
          'created_at': notebook.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client.from('noesis_study_notebooks').upsert(payload);
      } catch (e) {
        debugPrint('Erro ao salvar caderno no Supabase: $e');
      }
    }

    return notebook;
  }

  static Future<void> deleteNotebook(String notebookId) async {
    _inMemoryNotebooks.removeWhere((n) => n.id == notebookId);
    if (currentUser != null) {
      try {
        await client.from('noesis_study_notebooks').delete().eq('id', notebookId);
      } catch (e) {
        debugPrint('Erro ao excluir caderno no Supabase: $e');
      }
    }
  }

  static Future<void> saveNote(String notebookId, StudyNote note) async {
    _seedInitialNotebooks();
    final nbIndex = _inMemoryNotebooks.indexWhere((n) => n.id == notebookId);
    if (nbIndex >= 0) {
      final nb = _inMemoryNotebooks[nbIndex];
      final noteList = List<StudyNote>.from(nb.notes);
      final nIndex = noteList.indexWhere((n) => n.id == note.id);
      if (nIndex >= 0) {
        noteList[nIndex] = note;
      } else {
        noteList.insert(0, note);
      }
      final updatedNb = nb.copyWith(notes: noteList, updatedAt: DateTime.now());
      _inMemoryNotebooks[nbIndex] = updatedNb;
      if (currentUser != null) {
        await saveNotebook(updatedNb);
      }
    }
  }

  static Future<void> deleteNote(String notebookId, String noteId) async {
    _seedInitialNotebooks();
    final nbIndex = _inMemoryNotebooks.indexWhere((n) => n.id == notebookId);
    if (nbIndex >= 0) {
      final nb = _inMemoryNotebooks[nbIndex];
      final noteList = List<StudyNote>.from(nb.notes)..removeWhere((n) => n.id == noteId);
      final updatedNb = nb.copyWith(notes: noteList, updatedAt: DateTime.now());
      _inMemoryNotebooks[nbIndex] = updatedNb;
      if (currentUser != null) {
        await saveNotebook(updatedNb);
      }
    }
  }

  // ----------------------------------------------------
  // TRILHAS DE ESTUDO / ROADMAPS (noesis_roadmaps)
  // ----------------------------------------------------
  static final List<Map<String, dynamic>> _inMemoryRoadmaps = [];

  static Future<List<Map<String, dynamic>>> getRoadmaps() async {
    if (currentUser == null) {
      return List<Map<String, dynamic>>.from(_inMemoryRoadmaps);
    }
    try {
      final res = await client
          .from('noesis_roadmaps')
          .select()
          .eq('user_id', currentUser!.id)
          .order('updated_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      _inMemoryRoadmaps
        ..clear()
        ..addAll(list);
      return list;
    } catch (e) {
      debugPrint('Erro ao buscar trilhas no Supabase: $e');
      return List<Map<String, dynamic>>.from(_inMemoryRoadmaps);
    }
  }

  static Future<void> upsertRoadmap(Map<String, dynamic> roadmapJson) async {
    final roadmapKey = (roadmapJson['id'] ?? '').toString().trim();
    if (roadmapKey.isEmpty) return;

    final idx = _inMemoryRoadmaps.indexWhere(
      (r) => r['roadmap_key'] == roadmapKey || r['id'] == roadmapKey,
    );
    final memRecord = {
      ...roadmapJson,
      'roadmap_key': roadmapKey,
      'user_id': currentUser?.id,
    };
    if (idx != -1) {
      _inMemoryRoadmaps[idx] = memRecord;
    } else {
      _inMemoryRoadmaps.insert(0, memRecord);
    }

    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      final existing = await client
          .from('noesis_roadmaps')
          .select('id')
          .eq('user_id', uid)
          .eq('roadmap_key', roadmapKey)
          .maybeSingle();

      final payload = {
        'user_id': uid,
        'roadmap_key': roadmapKey,
        'title': roadmapJson['title'] ?? 'Trilha de Estudos',
        'goal': roadmapJson['goal'] ?? '',
        'subject': roadmapJson['subject'] ?? 'Geral',
        'level': roadmapJson['level'] ?? 'Intermediário',
        'estimated_weeks': roadmapJson['estimated_weeks'] ?? 4,
        'steps': roadmapJson['steps'] ?? const [],
        'updated_at': roadmapJson['updated_at'] ?? DateTime.now().toIso8601String(),
      };

      if (existing != null && existing['id'] != null) {
        await client
            .from('noesis_roadmaps')
            .update(payload)
            .eq('id', existing['id'])
            .eq('user_id', uid);
      } else {
        await client.from('noesis_roadmaps').insert({
          ...payload,
          'created_at': roadmapJson['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar trilha no Supabase: $e');
    }
  }

  static Future<void> deleteRoadmap(String roadmapKey) async {
    _inMemoryRoadmaps.removeWhere(
      (r) => r['roadmap_key'] == roadmapKey || r['id'] == roadmapKey,
    );
    if (currentUser == null) return;
    try {
      final uid = currentUser!.id;
      final deletedByKey = await client
          .from('noesis_roadmaps')
          .delete()
          .eq('user_id', uid)
          .eq('roadmap_key', roadmapKey)
          .select('id');
      if ((deletedByKey as List).isEmpty &&
          RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(roadmapKey)) {
        await client
            .from('noesis_roadmaps')
            .delete()
            .eq('user_id', uid)
            .eq('id', roadmapKey);
      }
    } catch (e) {
      debugPrint('Erro ao excluir trilha no Supabase: $e');
    }
  }
}
