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
  static Future<List<Map<String, dynamic>>> getStudySessions({int limit = 50}) async {
    if (currentUser == null) return [];
    final res = await client
        .from('noesis_sessions')
        .select()
        .eq('user_id', currentUser!.id)
        .order('study_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  static Stream<List<Map<String, dynamic>>> studySessionsStream() {
    if (currentUser == null) return const Stream.empty();
    return client
        .from('noesis_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('study_date', ascending: false);
  }

  static Future<void> addStudySession({
    required String subject,
    required String topic,
    required int durationMinutes,
    required DateTime studyDate,
    String? notes,
  }) async {
    if (currentUser == null) throw Exception("Usuário não autenticado");
    await client.from('noesis_sessions').insert({
      'user_id': currentUser!.id,
      'subject': subject,
      'topic': topic,
      'duration_minutes': durationMinutes,
      'study_date': studyDate.toIso8601String().split('T').first,
      'notes': notes,
    });
  }

  static Future<void> deleteStudySession(String id) async {
    await client.from('noesis_sessions').delete().eq('id', id);
  }

  // ----------------------------------------------------
  // CALENDAR EVENTS (noesis_calendar_events)
  // ----------------------------------------------------
  static Future<List<Map<String, dynamic>>> getCalendarEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (currentUser == null) return [];
    var query = client.from('noesis_calendar_events').select().eq('user_id', currentUser!.id);

    if (startDate != null) {
      query = query.gte('start_time', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('end_time', endDate.toIso8601String());
    }

    final res = await query.order('start_time', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Stream<List<Map<String, dynamic>>> calendarEventsStream() {
    if (currentUser == null) return const Stream.empty();
    return client
        .from('noesis_calendar_events')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUser!.id)
        .order('start_time', ascending: true);
  }

  static Future<void> addCalendarEvent({
    required String title,
    String? description,
    String category = 'study',
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (currentUser == null) throw Exception("Usuário não autenticado");
    await client.from('noesis_calendar_events').insert({
      'user_id': currentUser!.id,
      'title': title,
      'description': description,
      'category': category,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
    });
  }

  // ----------------------------------------------------
  // QUIZZES (noesis_quizzes)
  // ----------------------------------------------------
  static Future<List<Map<String, dynamic>>> getQuizzes() async {
    if (currentUser == null) return [];
    final res = await client
        .from('noesis_quizzes')
        .select()
        .eq('user_id', currentUser!.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> saveQuizResult({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questionsData,
    required double scorePercentage,
    required int timeSpentSeconds,
    String? documentId,
  }) async {
    if (currentUser == null) throw Exception("Usuário não autenticado");
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
  }
}
