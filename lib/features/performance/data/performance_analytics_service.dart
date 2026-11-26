import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/gemini_service.dart';
import '../../../core/shop_service.dart';
import '../../../core/supabase_service.dart';
import '../../flashcards/models/flashcard_model.dart';
import '../../notebooks/models/notebook_model.dart';
import '../../profile/data/social_connections_service.dart';
import '../../quizzes/data/saved_exams_repository.dart';
import '../../quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../quizzes/data/saved_exams_store_web.dart' as local_store;
import '../../ranking/data/ranking_service.dart';
import '../../roadmaps/data/roadmaps_repository.dart';
import '../../roadmaps/models/roadmap_model.dart';
import '../../study_groups/data/study_groups_service.dart';
import '../models/performance_report_model.dart';

class PerformanceAnalyticsService {
  PerformanceAnalyticsService._();
  static final PerformanceAnalyticsService instance = PerformanceAnalyticsService._();

  static const String _reviewsStorageKey = 'noesis_performance_ai_reviews_v1';

  static DateTime Function() _clock = DateTime.now;
  static DateTime currentNow() => _clock();

  @visibleForTesting
  static set clockForTesting(DateTime Function() fn) => _clock = fn;

  final ValueNotifier<List<PerformanceAiReview>> reviewsNotifier =
      ValueNotifier<List<PerformanceAiReview>>(const []);

  bool _reviewsLoaded = false;
  int _reviewSeq = 0;

  static PerformancePeriodRange computeRange(
    PerformancePeriod period, {
    DateTime? referenceDate,
    DateTimeRange? customRange,
    List<DateTime> historicalDates = const [],
  }) {
    final now = referenceDate ?? _clock();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (period) {
      case PerformancePeriod.days7:
        return PerformancePeriodRange(
          period: period,
          start: todayStart.subtract(const Duration(days: 6)),
          end: todayEnd,
          label: 'Últimos 7 dias',
        );
      case PerformancePeriod.days30:
        return PerformancePeriodRange(
          period: period,
          start: todayStart.subtract(const Duration(days: 29)),
          end: todayEnd,
          label: 'Últimos 30 dias',
        );
      case PerformancePeriod.days90:
        return PerformancePeriodRange(
          period: period,
          start: todayStart.subtract(const Duration(days: 89)),
          end: todayEnd,
          label: 'Últimos 90 dias',
        );
      case PerformancePeriod.custom:
        if (customRange != null) {
          final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
          final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
          final startLbl =
              '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}';
          final endLbl =
              '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';
          return PerformancePeriodRange(
            period: period,
            start: start,
            end: end,
            label: '$startLbl – $endLbl',
          );
        }
        return PerformancePeriodRange(
          period: period,
          start: todayStart.subtract(const Duration(days: 29)),
          end: todayEnd,
          label: 'Personalizado (30d)',
        );
      case PerformancePeriod.allTime:
        DateTime earliest = todayStart.subtract(const Duration(days: 29));
        for (final dt in historicalDates) {
          final day = DateTime(dt.year, dt.month, dt.day);
          if (day.isBefore(earliest)) earliest = day;
        }
        return PerformancePeriodRange(
          period: period,
          start: earliest,
          end: todayEnd,
          label: 'Todo o histórico',
        );
    }
  }

  static bool _inRange(DateTime dt, DateTime start, DateTime end) {
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  static DateTime? _parseSessionDate(Map<String, dynamic> session) {
    final raw = (session['study_date'] ?? session['created_at'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<List<PerformanceAiReview>> loadAiReviews({bool force = false}) async {
    if (_reviewsLoaded && !force) return reviewsNotifier.value;
    _reviewsLoaded = true;
    try {
      final raw = await local_store.readSavedExamsRaw(_reviewsStorageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map((m) => PerformanceAiReview.fromJson(Map<String, dynamic>.from(m)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          reviewsNotifier.value = parsed;
          return parsed;
        }
      }
    } catch (_) {}
    reviewsNotifier.value = const [];
    return const [];
  }

  Future<void> _saveReviews(List<PerformanceAiReview> list) async {
    final sorted = List<PerformanceAiReview>.from(list)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    reviewsNotifier.value = sorted;
    try {
      await local_store.writeSavedExamsRaw(
        _reviewsStorageKey,
        jsonEncode(sorted.take(20).map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<AccountPerformanceReport> loadReport({
    required PerformancePeriod period,
    DateTimeRange? customRange,
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? _clock();
    await Future.wait([
      ShopService.instance.init(),
      RankingService.instance.init(),
      StudyGroupsService.instance.init(),
      SocialConnectionsService.instance.init(),
      loadAiReviews(),
    ]);

    final results = await Future.wait<dynamic>([
      SupabaseService.getStudySessions(limit: 500),
      SavedExamsRepository.loadAll(),
      SupabaseService.getFlashcardDecks(),
      SupabaseService.getNotebooks(),
      RoadmapsRepository.loadAll(),
      SupabaseService.getCalendarEvents(),
      SupabaseService.loadDailyGoalMinutes(),
      SupabaseService.loadWeeklyGoalMinutes(),
    ]);

    final sessions = results[0] as List<Map<String, dynamic>>;
    final exams = results[1] as List<SavedExamAttempt>;
    final decks = results[2] as List<FlashcardDeck>;
    final notebooks = results[3] as List<StudyNotebook>;
    final roadmaps = results[4] as List<StudyRoadmap>;
    final events = results[5] as List<Map<String, dynamic>>;
    final dailyGoalMinutes = results[6] as int;
    final weeklyGoalMinutes = results[7] as int;

    final historicalDates = <DateTime>[];
    for (final s in sessions) {
      final dt = _parseSessionDate(s);
      if (dt != null) historicalDates.add(dt);
    }
    for (final e in exams) {
      historicalDates.add(e.createdAt);
    }

    final range = computeRange(
      period,
      referenceDate: now,
      customRange: customRange,
      historicalDates: historicalDates,
    );

    return buildReportFromData(
      range: range,
      now: now,
      sessions: sessions,
      exams: exams,
      decks: decks,
      notebooks: notebooks,
      roadmaps: roadmaps,
      calendarEvents: events,
      transactions: ShopService.instance.transactionsNotifier.value,
      dailyGoalMinutes: dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes,
    );
  }

  AccountPerformanceReport buildReportFromData({
    required PerformancePeriodRange range,
    required DateTime now,
    required List<Map<String, dynamic>> sessions,
    required List<SavedExamAttempt> exams,
    required List<FlashcardDeck> decks,
    required List<StudyNotebook> notebooks,
    required List<StudyRoadmap> roadmaps,
    required List<Map<String, dynamic>> calendarEvents,
    required List<ShopTransaction> transactions,
    required int dailyGoalMinutes,
    required int weeklyGoalMinutes,
  }) {
    final bool hasPreviousWindow = range.period != PerformancePeriod.allTime;
    final prevEnd = range.start.subtract(const Duration(seconds: 1));
    final prevStart = prevEnd.subtract(Duration(days: range.spanDays - 1));
    final prevStartDay = DateTime(prevStart.year, prevStart.month, prevStart.day);

    // ─── 1. Sessões de Estudo & Matérias ───
    int periodMinutes = 0;
    int prevMinutes = 0;
    int sessionsCount = 0;
    final minutesByDay = <DateTime, int>{};
    final minutesBySubject = <String, int>{};
    final sessionsBySubject = <String, int>{};

    for (final s in sessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final dt = _parseSessionDate(s);
      if (dt == null) continue;

      if (_inRange(dt, range.start, range.end)) {
        periodMinutes += mins;
        sessionsCount++;
        final day = DateTime(dt.year, dt.month, dt.day);
        minutesByDay[day] = (minutesByDay[day] ?? 0) + mins;
        final rawSubj = (s['subject'] ?? 'Geral').toString().trim();
        final subj = rawSubj.isEmpty ? 'Geral' : rawSubj;
        minutesBySubject[subj] = (minutesBySubject[subj] ?? 0) + mins;
        sessionsBySubject[subj] = (sessionsBySubject[subj] ?? 0) + 1;
      } else if (hasPreviousWindow && _inRange(dt, prevStartDay, prevEnd)) {
        prevMinutes += mins;
      }
    }

    int bestDayMinutes = 0;
    DateTime? bestDayDate;
    minutesByDay.forEach((day, m) {
      if (m > bestDayMinutes) {
        bestDayMinutes = m;
        bestDayDate = day;
      }
    });

    final int? minutesDeltaPct;
    if (!hasPreviousWindow || prevMinutes == 0) {
      minutesDeltaPct = prevMinutes == 0 && periodMinutes > 0 && hasPreviousWindow ? 100 : null;
    } else {
      minutesDeltaPct = (((periodMinutes - prevMinutes) / prevMinutes) * 100).round();
    }

    final currentStreakDays = SupabaseService.computeCurrentStreakDays(
      sessions,
      referenceDate: now,
      protectedDates: ShopService.instance.protectedStreakDates,
    );

    // ─── 2. Simulados & Curva de Desempenho ───
    final examsInPeriod = exams.where((e) => _inRange(e.createdAt, range.start, range.end)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final examsPrev = hasPreviousWindow
        ? exams.where((e) => _inRange(e.createdAt, prevStartDay, prevEnd)).toList()
        : const <SavedExamAttempt>[];

    int totalQuestions = 0;
    int correct = 0;
    int wrong = 0;
    int blank = 0;
    double? bestExamScore;
    final examScoresBySubject = <String, List<double>>{};

    for (final e in examsInPeriod) {
      totalQuestions += e.questions.length;
      correct += e.correctCount;
      wrong += e.wrongCount;
      blank += e.blankCount;
      if (bestExamScore == null || e.scorePercentage > bestExamScore) {
        bestExamScore = e.scorePercentage;
      }
      final sKey = e.subject.trim().isEmpty ? 'Geral' : e.subject.trim();
      examScoresBySubject.putIfAbsent(sKey, () => []).add(e.scorePercentage);
    }

    final double? avgExamScore = examsInPeriod.isEmpty
        ? null
        : examsInPeriod.fold<double>(0.0, (acc, e) => acc + e.scorePercentage) / examsInPeriod.length;
    final double? prevExamScore = examsPrev.isEmpty
        ? null
        : examsPrev.fold<double>(0.0, (acc, e) => acc + e.scorePercentage) / examsPrev.length;

    final examTrend = examsInPeriod
        .map(
          (e) => ExamTrendPoint(
            examId: e.id,
            title: e.title,
            subject: e.subject,
            scorePercentage: e.scorePercentage,
            correctCount: e.correctCount,
            totalCount: e.questions.length,
            createdAt: e.createdAt,
          ),
        )
        .toList();

    // Une matérias de sessões + matérias de simulados no breakdown
    final allSubjects = <String>{
      ...minutesBySubject.keys,
      ...examScoresBySubject.keys,
    };
    final breakdowns = allSubjects.map((subj) {
      final mins = minutesBySubject[subj] ?? 0;
      final sCount = sessionsBySubject[subj] ?? 0;
      final scores = examScoresBySubject[subj] ?? const <double>[];
      final avgS = scores.isEmpty
          ? null
          : scores.fold<double>(0.0, (a, b) => a + b) / scores.length;
      return SubjectBreakdownItem(
        subject: subj,
        minutes: mins,
        sessionsCount: sCount,
        shareFraction: periodMinutes > 0 ? (mins / periodMinutes).clamp(0.0, 1.0) : 0.0,
        examCount: scores.length,
        averageExamScore: avgS,
      );
    }).toList()
      ..sort((a, b) {
        final mCmp = b.minutes.compareTo(a.minutes);
        if (mCmp != 0) return mCmp;
        return b.examCount.compareTo(a.examCount);
      });

    // ─── 3. Economia de Insights no período ───
    int earnedInPeriod = 0;
    int investedInPeriod = 0;
    final insightsByDay = <DateTime, int>{};

    for (final tx in transactions) {
      if (!_inRange(tx.createdAt, range.start, range.end)) continue;
      if (tx.amount > 0) {
        if (tx.source != 'welcome') {
          earnedInPeriod += tx.amount;
          final day = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
          insightsByDay[day] = (insightsByDay[day] ?? 0) + tx.amount;
        }
      } else if (tx.amount < 0) {
        investedInPeriod += tx.amount.abs();
      }
    }

    // ─── 4. Buckets Temporais para Gráfico Analítico ───
    final timeBuckets = _buildTimeBuckets(
      range: range,
      minutesByDay: minutesByDay,
      insightsByDay: insightsByDay,
    );

    // ─── 5. Flashcards & Retenção ───
    int totalCards = 0;
    int cardsReviewedInPeriod = 0;
    int easyCards = 0;
    int goodCards = 0;
    int hardCards = 0;
    int unreviewedCards = 0;
    int cardsDueCount = 0;

    for (final d in decks) {
      for (final c in d.cards) {
        totalCards++;
        if (c.lastReviewed != null && _inRange(c.lastReviewed!, range.start, range.end)) {
          cardsReviewedInPeriod++;
        }
        switch (c.difficulty) {
          case 'easy':
            easyCards++;
          case 'good':
            goodCards++;
          case 'hard':
            hardCards++;
          default:
            unreviewedCards++;
        }
        if (c.difficulty == 'hard' ||
            c.difficulty == 'unreviewed' ||
            c.lastReviewed == null ||
            now.difference(c.lastReviewed!).inDays >= 3) {
          cardsDueCount++;
        }
      }
    }
    final reviewedTotal = easyCards + goodCards + hardCards;
    final retentionRatePct =
        reviewedTotal > 0 ? (((easyCards + goodCards) / reviewedTotal) * 100).round() : 0;

    // ─── 6. Cadernos, Trilhas & Calendário ───
    int totalNotes = 0;
    int notesUpdatedInPeriod = 0;
    int notesNeedingReview = 0;
    for (final nb in notebooks) {
      for (final note in nb.notes) {
        totalNotes++;
        if (note.needsReview) notesNeedingReview++;
        if (_inRange(note.updatedAt, range.start, range.end) ||
            _inRange(note.createdAt, range.start, range.end)) {
          notesUpdatedInPeriod++;
        }
      }
    }

    int completedSteps = 0;
    int totalSteps = 0;
    for (final rm in roadmaps) {
      totalSteps += rm.steps.length;
      completedSteps += rm.steps.where((s) => s.status == RoadmapStepStatus.done).length;
    }
    final roadmapProgressPct =
        totalSteps > 0 ? ((completedSteps / totalSteps) * 100).round().clamp(0, 100) : 0;

    int calInPeriod = 0;
    int calCompleted = 0;
    int calUpcoming = 0;
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final ev in calendarEvents) {
      final start = DateTime.tryParse((ev['start_time'] ?? '').toString());
      if (start == null) continue;
      final done = ev['is_completed'] == true;
      if (_inRange(start, range.start, range.end)) {
        calInPeriod++;
        if (done) calCompleted++;
      }
      if (!done && !start.isBefore(todayStart)) {
        calUpcoming++;
      }
    }

    final board = RankingService.instance.boardNotifier.value;
    final groupsCount = StudyGroupsService.instance.groupsNotifier.value.length;
    final mutualCount = SocialConnectionsService.instance.mutualConnections.length;

    return AccountPerformanceReport(
      range: range,
      generatedAt: now,
      periodMinutes: periodMinutes,
      previousPeriodMinutes: prevMinutes,
      minutesDeltaPct: minutesDeltaPct,
      sessionsCount: sessionsCount,
      activeDaysCount: minutesByDay.length,
      dailyAverageMinutes: (periodMinutes / range.spanDays).round(),
      bestDayMinutes: bestDayMinutes,
      bestDayDate: bestDayDate,
      currentStreakDays: currentStreakDays,
      dailyGoalMinutes: dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes,
      timeBuckets: timeBuckets,
      subjectBreakdowns: breakdowns,
      examsCount: examsInPeriod.length,
      totalQuestionsAnswered: totalQuestions,
      correctAnswers: correct,
      wrongAnswers: wrong,
      blankAnswers: blank,
      averageExamScore: avgExamScore,
      previousExamScore: prevExamScore,
      bestExamScore: bestExamScore,
      examTrend: examTrend,
      totalDecks: decks.length,
      totalCards: totalCards,
      cardsReviewedInPeriod: cardsReviewedInPeriod,
      easyCards: easyCards,
      goodCards: goodCards,
      hardCards: hardCards,
      unreviewedCards: unreviewedCards,
      cardsDueCount: cardsDueCount,
      retentionRatePct: retentionRatePct,
      totalNotebooks: notebooks.length,
      totalNotes: totalNotes,
      notesUpdatedInPeriod: notesUpdatedInPeriod,
      notesNeedingReview: notesNeedingReview,
      totalRoadmaps: roadmaps.length,
      completedRoadmapSteps: completedSteps,
      totalRoadmapSteps: totalSteps,
      roadmapProgressPct: roadmapProgressPct,
      calendarEventsInPeriod: calInPeriod,
      calendarCompletedInPeriod: calCompleted,
      calendarPendingUpcoming: calUpcoming,
      insightsEarnedInPeriod: earnedInPeriod,
      insightsInvestedInPeriod: investedInPeriod,
      currentInsightsBalance: ShopService.instance.balanceNotifier.value,
      consistencySealsCount: ShopService.instance.streakProtectorsNotifier.value,
      currentEloName: board.currentElo.name,
      bestEloName: board.bestElo.name,
      currentWeeklyRank: board.currentUserRank,
      joinedGroupsCount: groupsCount,
      mutualConnectionsCount: mutualCount,
    );
  }

  List<PerformanceTimeBucket> _buildTimeBuckets({
    required PerformancePeriodRange range,
    required Map<DateTime, int> minutesByDay,
    required Map<DateTime, int> insightsByDay,
  }) {
    final startDay = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day);
    final totalDays = endDay.difference(startDay).inDays + 1;

    // Para até 10 dias (ex.: 7 dias), exibe 1 barra por dia
    if (totalDays <= 10) {
      return List.generate(totalDays, (i) {
        final d = startDay.add(Duration(days: i));
        final label = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        return PerformanceTimeBucket(
          label: label,
          minutes: minutesByDay[d] ?? 0,
          insightsEarned: insightsByDay[d] ?? 0,
          date: d,
        );
      });
    }

    // Para períodos longos (30d, 90d, Tudo, Personalizado), agrupa em até 7 janelas equilibradas
    const bucketCount = 6;
    final bucketDays = (totalDays / bucketCount).ceil().clamp(1, 3650);
    final buckets = <PerformanceTimeBucket>[];

    for (int b = 0; b < bucketCount; b++) {
      final bStart = startDay.add(Duration(days: b * bucketDays));
      if (bStart.isAfter(endDay)) break;
      final candidateEnd = bStart.add(Duration(days: bucketDays - 1));
      final bEnd = candidateEnd.isAfter(endDay) ? endDay : candidateEnd;

      int sumMins = 0;
      int sumInsights = 0;
      DateTime cur = bStart;
      while (!cur.isAfter(bEnd)) {
        sumMins += minutesByDay[cur] ?? 0;
        sumInsights += insightsByDay[cur] ?? 0;
        cur = cur.add(const Duration(days: 1));
      }

      final lbl = '${bStart.day.toString().padLeft(2, '0')}/${bStart.month.toString().padLeft(2, '0')}';
      buckets.add(
        PerformanceTimeBucket(
          label: lbl,
          minutes: sumMins,
          insightsEarned: sumInsights,
          date: bStart,
        ),
      );
    }
    return buckets;
  }

  /// Gera e salva um Review longitudinal da IA para o relatório atual.
  Future<PerformanceAiReview> generateAndSaveAiReview(AccountPerformanceReport report) async {
    await loadAiReviews();
    final subjectSummaries = report.subjectBreakdowns.take(5).map((s) {
      final h = (s.minutes / 60.0).toStringAsFixed(1);
      final examPart = s.averageExamScore != null ? ' · média ${s.averageExamScore!.round()}%' : '';
      return '${s.subject}: ${h}h$examPart';
    }).toList();

    final res = await GeminiService.generateAccountPerformanceReview(
      periodLabel: report.range.label,
      totalMinutes: report.periodMinutes,
      previousPeriodMinutes: report.previousPeriodMinutes,
      minutesDeltaPct: report.minutesDeltaPct,
      sessionsCount: report.sessionsCount,
      activeDaysCount: report.activeDaysCount,
      streakDays: report.currentStreakDays,
      examsCount: report.examsCount,
      totalQuestions: report.totalQuestionsAnswered,
      averageExamScore: report.averageExamScore,
      previousExamScore: report.previousExamScore,
      topSubjectsSummary: subjectSummaries,
      cardsReviewedInPeriod: report.cardsReviewedInPeriod,
      retentionRatePct: report.retentionRatePct,
      cardsDueCount: report.cardsDueCount,
      notesUpdatedInPeriod: report.notesUpdatedInPeriod,
      notesNeedingReview: report.notesNeedingReview,
      roadmapProgressPct: report.roadmapProgressPct,
      insightsEarnedInPeriod: report.insightsEarnedInPeriod,
      currentEloName: report.currentEloName,
    );

    final now = _clock();
    final review = PerformanceAiReview(
      id: 'perf_rev_${now.microsecondsSinceEpoch}_${++_reviewSeq}',
      createdAt: now,
      periodLabel: report.range.label,
      summaryHeadline: res.headline,
      markdownContent: res.markdown,
      generatedWithLlm: res.generatedWithLlm,
    );
    await _saveReviews([review, ...reviewsNotifier.value]);
    return review;
  }

  Future<void> deleteReview(String id) async {
    await loadAiReviews();
    await _saveReviews(reviewsNotifier.value.where((r) => r.id != id).toList());
  }

  @visibleForTesting
  Future<void> resetForTesting({DateTime Function()? customClock}) async {
    if (customClock != null) _clock = customClock;
    _reviewsLoaded = true;
    reviewsNotifier.value = const [];
    try {
      await local_store.writeSavedExamsRaw(_reviewsStorageKey, '');
    } catch (_) {}
  }
}
