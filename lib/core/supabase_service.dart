import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<List<Map<String, dynamic>>> getStudySessions({int limit = 50}) async {
    _seedInitialStudySessions();
    if (currentUser == null) {
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
      if (list.isEmpty) {
        return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
      }
      return list;
    } catch (_) {
      return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
    }
  }

  static Stream<List<Map<String, dynamic>>> studySessionsStream() {
    _seedInitialStudySessions();
    if (currentUser == null) {
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
        .map((sessions) {
          if (sessions.isEmpty && _inMemoryStudySessions.isNotEmpty) {
            return List<Map<String, dynamic>>.from(_inMemoryStudySessions);
          }
          return sessions;
        });
  }

  static Future<void> addStudySession({
    required String subject,
    required String topic,
    required int durationMinutes,
    required DateTime studyDate,
    String? notes,
  }) async {
    _seedInitialStudySessions();
    final newSession = {
      'id': 'sess-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser?.id,
      'subject': subject,
      'topic': topic,
      'duration_minutes': durationMinutes,
      'study_date': studyDate.toIso8601String().split('T').first,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    _inMemoryStudySessions.insert(0, newSession);
    _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));

    if (currentUser != null) {
      try {
        await client.from('noesis_sessions').insert({
          'user_id': currentUser!.id,
          'subject': subject,
          'topic': topic,
          'duration_minutes': durationMinutes,
          'study_date': studyDate.toIso8601String().split('T').first,
          'notes': notes,
        });
      } catch (e) {
        debugPrint('Erro ao persistir sessão no Supabase: $e');
      }
    }
  }

  static Future<void> deleteStudySession(String id) async {
    _seedInitialStudySessions();
    _inMemoryStudySessions.removeWhere((s) => s['id'] == id);
    _studySessionsStreamController.add(List<Map<String, dynamic>>.from(_inMemoryStudySessions));

    if (currentUser != null) {
      try {
        await client.from('noesis_sessions').delete().eq('id', id);
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
}
