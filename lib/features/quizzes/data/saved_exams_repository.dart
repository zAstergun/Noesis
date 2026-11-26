import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/supabase_service.dart';
import 'saved_exams_store_stub.dart'
    if (dart.library.io) 'saved_exams_store_io.dart'
    if (dart.library.js_interop) 'saved_exams_store_web.dart' as store;

/// Registro completo de um simulado realizado pelo usuário para revisão e histórico.
class SavedExamAttempt {
  const SavedExamAttempt({
    required this.id,
    required this.groupKey,
    required this.examModelId,
    required this.examModelName,
    required this.title,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.createdAt,
    required this.elapsedSeconds,
    required this.targetTotalCount,
    required this.questions,
    required this.userAnswers,
    required this.correctCount,
    required this.wrongCount,
    required this.blankCount,
    required this.scorePercentage,
    this.aiReviewMarkdown,
    this.timeExpired = false,
  });

  final String id;
  final String groupKey;
  final String? examModelId;
  final String examModelName;
  final String title;
  final String subject;
  final String topic;
  final String difficulty;
  final DateTime createdAt;
  final int elapsedSeconds;
  final int targetTotalCount;
  final List<Map<String, dynamic>> questions;
  final Map<int, int> userAnswers;
  final int correctCount;
  final int wrongCount;
  final int blankCount;
  final double scorePercentage;
  final String? aiReviewMarkdown;
  final bool timeExpired;

  int get loadedCount => questions.length;
  int get answeredCount => correctCount + wrongCount;

  SavedExamAttempt copyWith({
    String? aiReviewMarkdown,
    Map<int, int>? userAnswers,
    int? correctCount,
    int? wrongCount,
    int? blankCount,
    double? scorePercentage,
    int? elapsedSeconds,
    bool? timeExpired,
  }) {
    return SavedExamAttempt(
      id: id,
      groupKey: groupKey,
      examModelId: examModelId,
      examModelName: examModelName,
      title: title,
      subject: subject,
      topic: topic,
      difficulty: difficulty,
      createdAt: createdAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      targetTotalCount: targetTotalCount,
      questions: questions,
      userAnswers: userAnswers ?? this.userAnswers,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      blankCount: blankCount ?? this.blankCount,
      scorePercentage: scorePercentage ?? this.scorePercentage,
      aiReviewMarkdown: aiReviewMarkdown ?? this.aiReviewMarkdown,
      timeExpired: timeExpired ?? this.timeExpired,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupKey': groupKey,
      'examModelId': examModelId,
      'examModelName': examModelName,
      'title': title,
      'subject': subject,
      'topic': topic,
      'difficulty': difficulty,
      'createdAt': createdAt.toIso8601String(),
      'elapsedSeconds': elapsedSeconds,
      'targetTotalCount': targetTotalCount,
      'questions': questions,
      'userAnswers': userAnswers.map((k, v) => MapEntry(k.toString(), v)),
      'correctCount': correctCount,
      'wrongCount': wrongCount,
      'blankCount': blankCount,
      'scorePercentage': scorePercentage,
      'aiReviewMarkdown': aiReviewMarkdown,
      'timeExpired': timeExpired,
    };
  }

  factory SavedExamAttempt.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawAnswers = (json['userAnswers'] as Map?) ?? const {};
    final parsedAnswers = <int, int>{};
    rawAnswers.forEach((k, v) {
      final idx = int.tryParse(k.toString());
      final ans = v is int ? v : int.tryParse(v.toString());
      if (idx != null && ans != null) {
        parsedAnswers[idx] = ans;
      }
    });

    return SavedExamAttempt(
      id: (json['id'] ?? '').toString(),
      groupKey: (json['groupKey'] ?? json['examModelName'] ?? json['subject'] ?? 'geral').toString(),
      examModelId: json['examModelId']?.toString(),
      examModelName: (json['examModelName'] ?? 'Simulado').toString(),
      title: (json['title'] ?? 'Simulado').toString(),
      subject: (json['subject'] ?? 'Geral').toString(),
      topic: (json['topic'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'Médio / Prático').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      targetTotalCount: (json['targetTotalCount'] as num?)?.toInt() ?? rawQuestions.length,
      questions: rawQuestions,
      userAnswers: parsedAnswers,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      blankCount: (json['blankCount'] as num?)?.toInt() ?? 0,
      scorePercentage: (json['scorePercentage'] as num?)?.toDouble() ?? 0.0,
      aiReviewMarkdown: json['aiReviewMarkdown']?.toString(),
      timeExpired: json['timeExpired'] == true,
    );
  }

  /// Constrói a partir de uma linha da tabela `public.noesis_quizzes` do Supabase.
  factory SavedExamAttempt.fromSupabaseRow(Map<String, dynamic> row) {
    final rawQuestions = (row['questions_data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final rawAnswers = (row['user_answers'] as Map?) ?? const {};
    final parsedAnswers = <int, int>{};
    rawAnswers.forEach((k, v) {
      final idx = int.tryParse(k.toString());
      final ans = v is int ? v : int.tryParse(v.toString());
      if (idx != null && ans != null) {
        parsedAnswers[idx] = ans;
      }
    });

    final subject = (row['subject'] ?? 'Geral').toString();
    final title = (row['title'] ?? 'Simulado').toString();
    final topic = (row['topic'] ?? title).toString();
    final examModelId = row['exam_model_id']?.toString();
    final examModelName = (row['exam_model_name'] ?? '').toString().trim();
    final resolvedModelName = examModelName.isNotEmpty ? examModelName : 'Modo Livre';

    final score = (row['score_percentage'] as num?)?.toDouble() ?? 0.0;
    final storedCorrect = (row['correct_count'] as num?)?.toInt();
    final storedWrong = (row['wrong_count'] as num?)?.toInt();
    final storedBlank = (row['blank_count'] as num?)?.toInt();

    int correct = storedCorrect ?? 0;
    int wrong = storedWrong ?? 0;
    int blank = storedBlank ?? 0;
    if (storedCorrect == null && rawQuestions.isNotEmpty) {
      if (parsedAnswers.isNotEmpty) {
        for (int i = 0; i < rawQuestions.length; i++) {
          final rightIdx = rawQuestions[i]['correct_index'] as int? ?? 0;
          final sel = parsedAnswers[i];
          if (sel == null) {
            blank++;
          } else if (sel == rightIdx) {
            correct++;
          } else {
            wrong++;
          }
        }
      } else {
        correct = ((score / 100.0) * rawQuestions.length).round();
        wrong = rawQuestions.length - correct;
      }
    }

    final attemptId = (row['attempt_key'] ?? row['id'] ?? '').toString();
    final rawGroupKey = (row['group_key'] ?? '').toString().trim();
    final resolvedGroupKey = rawGroupKey.isNotEmpty
        ? rawGroupKey
        : SavedExamsRepository.computeGroupKey(
            examModelId: examModelId,
            examModelName: examModelName.isNotEmpty ? examModelName : null,
            subject: subject,
            topic: topic,
          );

    return SavedExamAttempt(
      id: attemptId,
      groupKey: resolvedGroupKey,
      examModelId: examModelId,
      examModelName: resolvedModelName,
      title: title,
      subject: subject,
      topic: topic,
      difficulty: (row['difficulty'] ?? 'Médio / Prático').toString(),
      createdAt: DateTime.tryParse(
            (row['completed_at'] ?? row['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      elapsedSeconds: (row['time_spent_seconds'] as num?)?.toInt() ?? 0,
      targetTotalCount: (row['target_total_count'] as num?)?.toInt() ?? rawQuestions.length,
      questions: rawQuestions,
      userAnswers: parsedAnswers,
      correctCount: correct,
      wrongCount: wrong,
      blankCount: blank,
      scorePercentage: score,
      aiReviewMarkdown: row['ai_review_markdown']?.toString(),
      timeExpired: row['time_expired'] == true,
    );
  }
}

/// Repositório local + sincronização opcional com Supabase para simulados finalizados.
class SavedExamsRepository {
  SavedExamsRepository._();

  static const String _storageKey = 'noesis_saved_simulados_v1';
  static const int _maxStoredAttempts = 60;
  static List<SavedExamAttempt>? _cache;

  static String computeGroupKey({
    String? examModelId,
    String? examModelName,
    required String subject,
    required String topic,
  }) {
    if (examModelId != null && examModelId.trim().isNotEmpty) {
      return 'model:${examModelId.trim().toLowerCase()}';
    }
    if (examModelName != null && examModelName.trim().isNotEmpty) {
      return 'name:${examModelName.trim().toLowerCase()}';
    }
    return 'free:${subject.trim().toLowerCase()}::${topic.trim().toLowerCase()}';
  }

  static SavedExamAttempt buildAttempt({
    required String id,
    String? examModelId,
    String? examModelName,
    required String subject,
    required String topic,
    required String difficulty,
    required List<Map<String, dynamic>> questions,
    required Map<int, int> userAnswers,
    required int elapsedSeconds,
    required int targetTotalCount,
    bool timeExpired = false,
    String? aiReviewMarkdown,
  }) {
    int correct = 0;
    int wrong = 0;
    int blank = 0;
    for (int i = 0; i < questions.length; i++) {
      final correctIdx = questions[i]['correct_index'] as int? ?? 0;
      final selectedIdx = userAnswers[i];
      if (selectedIdx == null) {
        blank++;
      } else if (selectedIdx == correctIdx) {
        correct++;
      } else {
        wrong++;
      }
    }
    final score = questions.isNotEmpty ? (correct / questions.length) * 100.0 : 0.0;
    final resolvedModelName = (examModelName != null && examModelName.trim().isNotEmpty)
        ? examModelName.trim()
        : 'Modo Livre';
    final displayTitle = (examModelName != null && examModelName.trim().isNotEmpty)
        ? examModelName.trim()
        : (topic.trim().isNotEmpty ? topic.trim() : subject.trim());

    return SavedExamAttempt(
      id: id,
      groupKey: computeGroupKey(
        examModelId: examModelId,
        examModelName: examModelName,
        subject: subject,
        topic: topic,
      ),
      examModelId: examModelId,
      examModelName: resolvedModelName,
      title: displayTitle.isEmpty ? 'Simulado' : displayTitle,
      subject: subject,
      topic: topic,
      difficulty: difficulty,
      createdAt: DateTime.now(),
      elapsedSeconds: elapsedSeconds,
      targetTotalCount: targetTotalCount,
      questions: questions.map((q) => Map<String, dynamic>.from(q)).toList(),
      userAnswers: Map<int, int>.from(userAnswers),
      correctCount: correct,
      wrongCount: wrong,
      blankCount: blank,
      scorePercentage: score,
      aiReviewMarkdown: aiReviewMarkdown,
      timeExpired: timeExpired,
    );
  }

  static Future<List<SavedExamAttempt>> loadAll({bool forceRemote = false}) async {
    List<SavedExamAttempt> localList;
    if (_cache != null && !forceRemote) {
      localList = List<SavedExamAttempt>.from(_cache!);
    } else {
      localList = [];
      try {
        final raw = await store.readSavedExamsRaw(_storageKey);
        if (raw != null && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            localList = decoded
                .whereType<Map>()
                .map((e) => SavedExamAttempt.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar histórico local de simulados: $e');
      }
    }

    if (SupabaseService.isAuthenticated && (_cache == null || forceRemote)) {
      try {
        final remoteRows = await SupabaseService.getQuizzes();
        if (remoteRows.isNotEmpty) {
          final mergedById = <String, SavedExamAttempt>{
            for (final item in localList) item.id: item,
          };
          for (final row in remoteRows) {
            final remoteAttempt = SavedExamAttempt.fromSupabaseRow(row);
            if (remoteAttempt.id.isEmpty) continue;
            final existing = mergedById[remoteAttempt.id];
            if (existing == null) {
              mergedById[remoteAttempt.id] = remoteAttempt;
            } else {
              final hasBetterReview = (remoteAttempt.aiReviewMarkdown ?? '').isNotEmpty &&
                  (existing.aiReviewMarkdown ?? '').isEmpty;
              if (hasBetterReview || remoteAttempt.questions.length > existing.questions.length) {
                mergedById[remoteAttempt.id] = remoteAttempt;
              }
            }
          }
          localList = mergedById.values.toList();
          await _persist(localList);
        }
      } catch (e) {
        debugPrint('Erro ao sincronizar histórico de simulados do Supabase: $e');
      }
    }

    localList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (localList.length > _maxStoredAttempts) {
      localList.removeRange(_maxStoredAttempts, localList.length);
    }
    _cache = localList;
    return List<SavedExamAttempt>.unmodifiable(_cache!);
  }

  static Future<List<SavedExamAttempt>> saveAttempt(
    SavedExamAttempt attempt, {
    bool syncRemote = true,
  }) async {
    final list = List<SavedExamAttempt>.from(await loadAll());
    final existingIdx = list.indexWhere((a) => a.id == attempt.id);
    if (existingIdx != -1) {
      list[existingIdx] = attempt;
    } else {
      list.insert(0, attempt);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length > _maxStoredAttempts) {
      list.removeRange(_maxStoredAttempts, list.length);
    }
    _cache = list;
    await _persist(list);
    SupabaseService.recordConsistencyActivity(date: attempt.createdAt);

    if (syncRemote) {
      await SupabaseService.upsertSavedExamAttempt(attempt.toJson());
    }
    return List<SavedExamAttempt>.unmodifiable(list);
  }

  static Future<void> updateAiReview(String attemptId, String reviewMarkdown) async {
    final list = List<SavedExamAttempt>.from(await loadAll());
    final idx = list.indexWhere((a) => a.id == attemptId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(aiReviewMarkdown: reviewMarkdown);
      _cache = list;
      await _persist(list);
    }
    await SupabaseService.updateSavedExamAiReview(attemptId, reviewMarkdown);
  }

  static Future<List<SavedExamAttempt>> deleteAttempt(String attemptId) async {
    final list = List<SavedExamAttempt>.from(await loadAll());
    list.removeWhere((a) => a.id == attemptId);
    _cache = list;
    await _persist(list);
    await SupabaseService.deleteSavedExamAttempt(attemptId);
    return List<SavedExamAttempt>.unmodifiable(list);
  }

  /// Retorna tentativas anteriores do mesmo simulado (ordenadas da mais recente para a mais antiga).
  static List<SavedExamAttempt> historyForGroup(
    List<SavedExamAttempt> all,
    String groupKey, {
    String? excludeId,
  }) {
    return all
        .where((a) => a.groupKey == groupKey && (excludeId == null || a.id != excludeId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @visibleForTesting
  static Future<void> clearForTest() async {
    _cache = [];
    await store.writeSavedExamsRaw(_storageKey, '[]');
  }

  static Future<void> _persist(List<SavedExamAttempt> list) async {
    try {
      final encoded = jsonEncode(list.map((a) => a.toJson()).toList());
      await store.writeSavedExamsRaw(_storageKey, encoded);
    } catch (e) {
      debugPrint('Erro ao salvar histórico local de simulados: $e');
    }
  }
}
