import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/localization/noesis_l10n.dart';
import '../../core/localization/noesis_locale_service.dart';
import '../../core/shop_service.dart';
import '../flashcards/models/flashcard_model.dart';
import '../notebooks/models/notebook_model.dart';
import '../quizzes/data/saved_exams_repository.dart';
import '../roadmaps/models/roadmap_model.dart';

class DashboardDayBar {
  const DashboardDayBar({
    required this.date,
    required this.dayLetter,
    required this.fullDayLabel,
    required this.minutes,
    required this.fraction,
    required this.isToday,
  });

  final DateTime date;
  final String dayLetter;
  final String fullDayLabel;
  final int minutes;
  final double fraction;
  final bool isToday;
}

class DashboardSevenDaysStats {
  const DashboardSevenDaysStats({
    required this.totalMinutes,
    required this.previous7DaysMinutes,
    required this.deltaPercentage,
    required this.deltaLabel,
    required this.deltaPositive,
    required this.bars,
  });

  final int totalMinutes;
  final int previous7DaysMinutes;
  final int? deltaPercentage;
  final String deltaLabel;
  final bool deltaPositive;
  final List<DashboardDayBar> bars;
}

class DashboardConsistencyStats {
  const DashboardConsistencyStats({
    required this.levels,
    required this.minutesGrid,
    required this.datesGrid,
    this.activitiesGrid = const [],
    this.protectedGrid = const [],
    required this.currentStreakDays,
    required this.bestDayMinutes,
    required this.bestDayDate,
    required this.activeDaysCount,
    required this.totalTrackedDays,
  });

  final List<List<int>> levels;
  final List<List<int>> minutesGrid;
  final List<List<DateTime>> datesGrid;
  final List<List<int>> activitiesGrid;
  final List<List<bool>> protectedGrid;
  final int currentStreakDays;
  final int bestDayMinutes;
  final DateTime? bestDayDate;
  final int activeDaysCount;
  final int totalTrackedDays;
}

class DashboardEcosystemSnapshot {
  const DashboardEcosystemSnapshot({
    this.savedExams = const [],
    this.decks = const [],
    this.notebooks = const [],
    this.roadmaps = const [],
    this.calendarEvents = const [],
  });

  final List<SavedExamAttempt> savedExams;
  final List<FlashcardDeck> decks;
  final List<StudyNotebook> notebooks;
  final List<StudyRoadmap> roadmaps;
  final List<Map<String, dynamic>> calendarEvents;

  int get examsCount => savedExams.length;

  double? get averageExamScore {
    if (savedExams.isEmpty) return null;
    final sum = savedExams.fold<double>(0.0, (acc, e) => acc + e.scorePercentage);
    return sum / savedExams.length;
  }

  List<SavedExamAttempt> get chronologicalExams {
    final sorted = List<SavedExamAttempt>.from(savedExams)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  int get totalCards => decks.fold<int>(0, (acc, d) => acc + d.cards.length);

  int get cardsNeedingReview {
    int count = 0;
    final now = DateTime.now();
    for (final deck in decks) {
      for (final card in deck.cards) {
        if (card.difficulty == 'hard' ||
            card.difficulty == 'unreviewed' ||
            card.lastReviewed == null ||
            now.difference(card.lastReviewed!).inDays >= 3) {
          count++;
        }
      }
    }
    return count;
  }

  FlashcardDeck? get mostPendingDeck {
    FlashcardDeck? best;
    int bestCount = 0;
    final now = DateTime.now();
    for (final deck in decks) {
      final pending = deck.cards.where((c) {
        return c.difficulty == 'hard' ||
            c.difficulty == 'unreviewed' ||
            c.lastReviewed == null ||
            now.difference(c.lastReviewed!).inDays >= 3;
      }).length;
      if (pending > bestCount) {
        bestCount = pending;
        best = deck;
      }
    }
    return best;
  }

  int get notebooksCount => notebooks.length;
  int get notesCount => notebooks.fold<int>(0, (acc, n) => acc + n.notes.length);

  int get roadmapsCount => roadmaps.length;

  int get overallRoadmapProgressPct {
    if (roadmaps.isEmpty) return 0;
    final total = roadmaps.fold<double>(0.0, (acc, r) => acc + r.progress);
    return ((total / roadmaps.length) * 100).round().clamp(0, 100);
  }

  ({StudyRoadmap roadmap, RoadmapStep step})? get nextRoadmapStep {
    for (final roadmap in roadmaps) {
      final doing = roadmap.steps.where((s) => s.status == RoadmapStepStatus.doing).toList();
      if (doing.isNotEmpty) {
        return (roadmap: roadmap, step: doing.first);
      }
      final todo = roadmap.steps.where((s) => s.status == RoadmapStepStatus.todo).toList();
      if (todo.isNotEmpty) {
        return (roadmap: roadmap, step: todo.first);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> upcomingEvents({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekAhead = startOfToday.add(const Duration(days: 7));
    final list = <Map<String, dynamic>>[];
    for (final event in calendarEvents) {
      if (event['is_completed'] == true) continue;
      final start = DateTime.tryParse((event['start_time'] ?? '').toString());
      if (start == null) continue;
      if (!start.isBefore(startOfToday) && start.isBefore(weekAhead)) {
        list.add(event);
      }
    }
    list.sort((a, b) {
      final da = DateTime.tryParse((a['start_time'] ?? '').toString()) ?? now;
      final db = DateTime.tryParse((b['start_time'] ?? '').toString()) ?? now;
      return da.compareTo(db);
    });
    return list;
  }
}

class DashboardInsight {
  const DashboardInsight({
    required this.badgeLabel,
    required this.message,
    required this.recommendedReviewTitle,
    required this.recommendedReviewDescription,
    required this.recommendedDurationMinutes,
    required this.targetTab,
    required this.accuracySpots,
    this.latestAccuracyPct,
    this.weakestSubject,
  });

  final String badgeLabel;
  final String message;
  final String recommendedReviewTitle;
  final String recommendedReviewDescription;
  final int recommendedDurationMinutes;
  final int targetTab;
  final List<FlSpot> accuracySpots;
  final int? latestAccuracyPct;
  final String? weakestSubject;
}

class DashboardAnalytics {
  DashboardAnalytics._();

  static String formatCompactDuration(int totalMinutes) {
    if (totalMinutes <= 0) return NoesisL10n.tr('0m');
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return NoesisL10n.tr('{m}m', {'m': '$m'});
    if (m == 0) return NoesisL10n.tr('{h}h', {'h': '$h'});
    return NoesisL10n.tr(
      '{h}h{m}',
      {'h': '$h', 'm': m.toString().padLeft(2, '0')},
    );
  }

  static String formatReadableDuration(int totalMinutes) {
    if (totalMinutes <= 0) return NoesisL10n.tr('0m');
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return NoesisL10n.tr('{m}m', {'m': '$m'});
    if (m == 0) return NoesisL10n.tr('{h}h', {'h': '$h'});
    return NoesisL10n.tr('{h}h {m}m', {'h': '$h', 'm': '$m'});
  }

  static DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _weekdayLetter(DateTime d) {
    try {
      final formatted = DateFormat.EEEEE(NoesisLocaleService.intlLocale).format(d);
      if (formatted.isNotEmpty) return formatted.toUpperCase();
    } catch (_) {}
    switch (d.weekday) {
      case DateTime.monday:
        return 'S';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'Q';
      case DateTime.thursday:
        return 'Q';
      case DateTime.friday:
        return 'S';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
      default:
        return 'D';
    }
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return NoesisL10n.tr('Seg');
      case DateTime.tuesday:
        return NoesisL10n.tr('Ter');
      case DateTime.wednesday:
        return NoesisL10n.tr('Qua');
      case DateTime.thursday:
        return NoesisL10n.tr('Qui');
      case DateTime.friday:
        return NoesisL10n.tr('Sex');
      case DateTime.saturday:
        return NoesisL10n.tr('Sáb');
      case DateTime.sunday:
      default:
        return NoesisL10n.tr('Dom');
    }
  }

  static Map<DateTime, int> _groupMinutesByDay(
    List<Map<String, dynamic>> sessions, {
    List<SavedExamAttempt> exams = const [],
  }) {
    final map = <DateTime, int>{};
    for (final s in sessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final raw = (s['study_date'] ?? s['created_at'] ?? '').toString().trim();
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      final day = _dayOnly(parsed);
      map[day] = (map[day] ?? 0) + mins;
    }
    for (final exam in exams) {
      final mins = (exam.elapsedSeconds / 60).round();
      if (mins <= 0) continue;
      final day = _dayOnly(exam.createdAt);
      map[day] = (map[day] ?? 0) + mins;
    }
    return map;
  }

  static DashboardSevenDaysStats computeLast7DaysStats(
    List<Map<String, dynamic>> sessions, {
    DateTime? referenceDate,
  }) {
    final today = _dayOnly(referenceDate ?? DateTime.now());
    final byDay = _groupMinutesByDay(sessions);

    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final dayMinutes = days.map((d) => byDay[d] ?? 0).toList();
    final currentTotal = dayMinutes.fold<int>(0, (acc, m) => acc + m);

    int prevTotal = 0;
    for (int i = 7; i <= 13; i++) {
      prevTotal += byDay[today.subtract(Duration(days: i))] ?? 0;
    }

    final maxMins = dayMinutes.fold<int>(0, (acc, m) => math.max(acc, m));
    final bars = <DashboardDayBar>[];
    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final m = dayMinutes[i];
      final fraction = maxMins > 0
          ? (m > 0 ? math.max(0.14, m / maxMins) : 0.06)
          : 0.06;
      String fullDayLabel;
      try {
        fullDayLabel = DateFormat.MMMEd(NoesisLocaleService.intlLocale).format(d);
      } catch (_) {
        fullDayLabel =
            '${_weekdayName(d.weekday)} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      }
      bars.add(
        DashboardDayBar(
          date: d,
          dayLetter: _weekdayLetter(d),
          fullDayLabel: fullDayLabel,
          minutes: m,
          fraction: fraction,
          isToday: i == days.length - 1,
        ),
      );
    }

    int? deltaPct;
    String deltaLabel;
    bool deltaPositive = true;

    if (currentTotal == 0 && prevTotal == 0) {
      deltaLabel = NoesisL10n.tr('Sem registros nos últimos 7d');
      deltaPositive = false;
    } else if (prevTotal == 0) {
      deltaLabel = NoesisL10n.tr('Nova sequência semanal');
      deltaPositive = true;
    } else {
      final diffPct = (((currentTotal - prevTotal) / prevTotal) * 100).round();
      deltaPct = diffPct;
      if (diffPct > 0) {
        deltaLabel = NoesisL10n.tr('↑ {pct}% vs. semana ant.', {'pct': '$diffPct'});
        deltaPositive = true;
      } else if (diffPct < 0) {
        deltaLabel = NoesisL10n.tr('↓ {pct}% vs. semana ant.', {'pct': '${diffPct.abs()}'});
        deltaPositive = false;
      } else {
        deltaLabel = NoesisL10n.tr('= 0% vs. semana ant.');
        deltaPositive = true;
      }
    }

    return DashboardSevenDaysStats(
      totalMinutes: currentTotal,
      previous7DaysMinutes: prevTotal,
      deltaPercentage: deltaPct,
      deltaLabel: deltaLabel,
      deltaPositive: deltaPositive,
      bars: bars,
    );
  }

  static int levelForMinutes(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 45) return 1;
    if (minutes < 120) return 2;
    if (minutes < 240) return 3;
    return 4;
  }

  static DashboardConsistencyStats computeConsistencyStats(
    List<Map<String, dynamic>> sessions, {
    List<SavedExamAttempt> exams = const [],
    List<FlashcardDeck> decks = const [],
    List<StudyNotebook> notebooks = const [],
    List<StudyRoadmap> roadmaps = const [],
    List<Map<String, dynamic>> calendarEvents = const [],
    List<ShopTransaction> transactions = const [],
    Map<DateTime, int> recordedActivityCounts = const {},
    Set<DateTime> protectedDates = const {},
    int columns = 26,
    int rows = 7,
    DateTime? referenceDate,
  }) {
    final today = _dayOnly(referenceDate ?? DateTime.now());
    final byDayMinutes = _groupMinutesByDay(sessions, exams: exams);
    final byDayScore = Map<DateTime, int>.from(byDayMinutes);
    final byDayActivities = <DateTime, int>{};

    void addActivity(DateTime rawDate, {int count = 1, int scoreMinutes = 5}) {
      if (count <= 0) return;
      final day = _dayOnly(rawDate);
      byDayActivities[day] = (byDayActivities[day] ?? 0) + count;
      byDayScore[day] = (byDayScore[day] ?? 0) + scoreMinutes;
    }

    // 1. Sessões registradas (horas/minutos de estudo)
    for (final s in sessions) {
      final id = (s['id'] ?? '').toString();
      if (id.startsWith('session-mock-')) continue;
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      final raw = (s['study_date'] ?? s['created_at'] ?? '').toString().trim();
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      final day = _dayOnly(parsed);
      byDayActivities[day] = (byDayActivities[day] ?? 0) + 1;
    }

    // 2. Simulados concluídos (mesmo com duração curta < 30s contam como atividade)
    for (final exam in exams) {
      final day = _dayOnly(exam.createdAt);
      byDayActivities[day] = (byDayActivities[day] ?? 0) + 1;
      if ((exam.elapsedSeconds / 60).round() <= 0) {
        byDayScore[day] = (byDayScore[day] ?? 0) + 5;
      }
    }

    // 3. Flashcards revisados
    final flashcardReviewsByDay = <DateTime, int>{};
    for (final deck in decks) {
      for (final card in deck.cards) {
        final reviewedAt = card.lastReviewed;
        if (reviewedAt != null) {
          final day = _dayOnly(reviewedAt);
          flashcardReviewsByDay[day] = (flashcardReviewsByDay[day] ?? 0) + 1;
        }
      }
    }
    final ledgerFlashcardsByDay = <DateTime, int>{};
    for (final tx in transactions) {
      if (tx.amount <= 0) continue;
      if (tx.source == 'welcome' ||
          tx.source == 'ranking_reward' ||
          tx.source == 'achievement' ||
          tx.source == 'purchase') {
        continue;
      }
      final day = _dayOnly(tx.createdAt);
      if (tx.source == 'flashcard_review' || tx.source == 'flashcard_redeem') {
        ledgerFlashcardsByDay[day] = (ledgerFlashcardsByDay[day] ?? 0) + 1;
      } else if (tx.source == 'quiz_question') {
        addActivity(day, count: 1, scoreMinutes: 4);
      } else if (tx.source != 'exam_complete') {
        addActivity(day, count: 1, scoreMinutes: 6);
      }
    }
    final allFlashcardDays = <DateTime>{
      ...flashcardReviewsByDay.keys,
      ...ledgerFlashcardsByDay.keys,
    };
    for (final day in allFlashcardDays) {
      final count = math.max(
        flashcardReviewsByDay[day] ?? 0,
        ledgerFlashcardsByDay[day] ?? 0,
      );
      if (count > 0) {
        addActivity(day, count: count, scoreMinutes: count * 5);
      }
    }

    // 4. Cadernos e anotações criadas, editadas ou revisadas
    for (final nb in notebooks) {
      if (nb.notes.isEmpty) {
        addActivity(nb.createdAt, count: 1, scoreMinutes: 6);
      } else {
        for (final note in nb.notes) {
          final noteDays = <DateTime>{
            _dayOnly(note.createdAt),
            _dayOnly(note.updatedAt),
            if (note.lastReviewedAt != null) _dayOnly(note.lastReviewedAt!),
          };
          final estMins = math.max(5, note.estimatedReviewMinutes);
          for (final day in noteDays) {
            addActivity(day, count: 1, scoreMinutes: estMins);
          }
        }
      }
    }

    // 5. Trilhas de estudo com progresso/atualização
    for (final rm in roadmaps) {
      if (rm.steps.isNotEmpty) {
        addActivity(rm.updatedAt, count: 1, scoreMinutes: 6);
      }
    }

    // 6. Eventos concluídos na agenda
    for (final evt in calendarEvents) {
      if (evt['is_completed'] != true) continue;
      final parsed = DateTime.tryParse(
        (evt['start_time'] ?? evt['end_time'] ?? '').toString(),
      );
      if (parsed != null) {
        addActivity(parsed, count: 1, scoreMinutes: 6);
      }
    }

    // 7. Registro persistido de ações (inclui respostas rápidas < 3s e criações locais)
    recordedActivityCounts.forEach((rawDay, count) {
      if (count <= 0) return;
      final day = _dayOnly(rawDay);
      final existing = byDayActivities[day] ?? 0;
      if (count > existing) {
        final delta = count - existing;
        byDayActivities[day] = count;
        byDayScore[day] = (byDayScore[day] ?? 0) + (delta * 5);
      } else if ((byDayScore[day] ?? 0) <= 0) {
        byDayScore[day] = count * 5;
      }
    });

    final normalizedProtected = protectedDates.map(_dayOnly).toSet();

    // Alinha colunas em semanas calendário (Seg..Dom), terminando na semana atual.
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = currentWeekMonday.subtract(Duration(days: (columns - 1) * 7));

    final levels = List.generate(columns, (_) => List.filled(rows, 0));
    final minutesGrid = List.generate(columns, (_) => List.filled(rows, 0));
    final activitiesGrid = List.generate(columns, (_) => List.filled(rows, 0));
    final protectedGrid = List.generate(columns, (_) => List.filled(rows, false));
    final datesGrid = List.generate(
      columns,
      (col) => List.generate(
        rows,
        (row) => firstMonday.add(Duration(days: col * 7 + row)),
      ),
    );

    int activeDays = 0;
    int trackedDays = 0;

    for (int col = 0; col < columns; col++) {
      for (int row = 0; row < rows; row++) {
        final date = datesGrid[col][row];
        if (date.isAfter(today)) {
          levels[col][row] = 0;
          minutesGrid[col][row] = 0;
          activitiesGrid[col][row] = 0;
          protectedGrid[col][row] = false;
          continue;
        }
        trackedDays++;
        final mins = byDayMinutes[date] ?? 0;
        final acts = byDayActivities[date] ?? 0;
        final score = byDayScore[date] ?? 0;
        minutesGrid[col][row] = mins;
        activitiesGrid[col][row] = acts;
        levels[col][row] = levelForMinutes(score);
        protectedGrid[col][row] = score <= 0 && normalizedProtected.contains(date);
        if (score > 0 || acts > 0) activeDays++;
      }
    }

    // Streak real considerando todas as atividades de estudo + dias protegidos pelo Selo de Consistência
    int streak = 0;
    final yesterday = today.subtract(const Duration(days: 1));
    bool isDayActive(DateTime d) => (byDayScore[d] ?? 0) > 0 || (byDayActivities[d] ?? 0) > 0;
    DateTime? cursor;
    if (isDayActive(today) || normalizedProtected.contains(today)) {
      cursor = today;
    } else if (isDayActive(yesterday) || normalizedProtected.contains(yesterday)) {
      cursor = yesterday;
    }
    while (cursor != null) {
      if (isDayActive(cursor)) {
        streak++;
      } else if (!normalizedProtected.contains(cursor)) {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int bestMinutes = 0;
    DateTime? bestDate;
    byDayMinutes.forEach((date, mins) {
      if (mins > bestMinutes) {
        bestMinutes = mins;
        bestDate = date;
      }
    });

    return DashboardConsistencyStats(
      levels: levels,
      minutesGrid: minutesGrid,
      datesGrid: datesGrid,
      activitiesGrid: activitiesGrid,
      protectedGrid: protectedGrid,
      currentStreakDays: streak,
      bestDayMinutes: bestMinutes,
      bestDayDate: bestDate,
      activeDaysCount: activeDays,
      totalTrackedDays: trackedDays,
    );
  }

  static Map<String, int> computeSubjectDistribution(
    List<Map<String, dynamic>> sessions, {
    int? daysWindow,
    DateTime? referenceDate,
  }) {
    final today = _dayOnly(referenceDate ?? DateTime.now());
    final cutoff = daysWindow != null ? today.subtract(Duration(days: daysWindow - 1)) : null;

    final othersLabel = NoesisL10n.tr('Outros');
    final rawMap = <String, int>{};
    for (final s in sessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      if (cutoff != null) {
        final rawDate = (s['study_date'] ?? s['created_at'] ?? '').toString().trim();
        final parsed = DateTime.tryParse(rawDate);
        if (parsed == null || _dayOnly(parsed).isBefore(cutoff)) continue;
      }
      final subject = (s['subject'] ?? othersLabel).toString().trim();
      final label = subject.isEmpty ? othersLabel : subject;
      rawMap[label] = (rawMap[label] ?? 0) + mins;
    }

    final sorted = rawMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= 5) {
      return {for (final e in sorted) e.key: e.value};
    }

    final top4 = sorted.take(4);
    final othersMinutes = sorted.skip(4).fold<int>(0, (acc, e) => acc + e.value);
    return {
      for (final e in top4) e.key: e.value,
      othersLabel: othersMinutes,
    };
  }

  static List<String> collectAllUserSubjects({
    required List<Map<String, dynamic>> sessions,
    required DashboardEcosystemSnapshot ecosystem,
    int maxCount = 10,
  }) {
    final seen = <String>{};
    final result = <String>[];

    void addSubject(String raw) {
      final clean = raw.trim();
      if (clean.isEmpty) return;
      if (seen.add(clean.toLowerCase())) {
        result.add(clean);
      }
    }

    for (final s in sessions) {
      addSubject((s['subject'] ?? '').toString());
    }
    for (final r in ecosystem.roadmaps) {
      addSubject(r.subject);
    }
    for (final d in ecosystem.decks) {
      addSubject(d.subject);
    }
    for (final n in ecosystem.notebooks) {
      addSubject(n.subject);
    }

    if (result.isEmpty) {
      return [
        NoesisL10n.tr('Geral'),
        NoesisL10n.tr('Matemática'),
        NoesisL10n.tr('Programação'),
        NoesisL10n.tr('Idiomas'),
      ];
    }
    return result.take(maxCount).toList();
  }

  static DashboardInsight buildInsight(
    DashboardEcosystemSnapshot ecosystem, {
    required List<Map<String, dynamic>> sessions,
    required DashboardConsistencyStats consistency,
    required int weeklyGoalMinutes,
    required int currentWeekMinutes,
    DateTime? referenceDate,
  }) {
    final chronoExams = ecosystem.chronologicalExams;
    final recentExams = chronoExams.length > 10
        ? chronoExams.sublist(chronoExams.length - 10)
        : chronoExams;

    final spots = recentExams.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.scorePercentage.clamp(0.0, 100.0),
      );
    }).toList();

    final avgExamPct = ecosystem.averageExamScore?.round();

    // 1. Analisar menor desempenho ou queda recente em Simulados
    String? weakestSubject;
    double? weakestAvg;
    if (chronoExams.isNotEmpty) {
      final bySubject = <String, List<double>>{};
      for (final attempt in chronoExams) {
        final key = attempt.subject.trim().isEmpty
            ? NoesisL10n.tr('Geral')
            : attempt.subject.trim();
        bySubject.putIfAbsent(key, () => []).add(attempt.scorePercentage);
      }
      bySubject.forEach((subject, scores) {
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        if (weakestAvg == null || avg < weakestAvg!) {
          weakestAvg = avg;
          weakestSubject = subject;
        }
      });

      if (weakestSubject != null && weakestAvg != null && weakestAvg! < 75.0) {
        final avgRound = weakestAvg!.round();
        return DashboardInsight(
          badgeLabel: NoesisL10n.tr('Simulados'),
          message: NoesisL10n.tr(
            'Sua acurácia em {subject} está em {avg}% nos simulados. Agende uma revisão focada de 30 min para reforçar os erros.',
            {'subject': weakestSubject!, 'avg': '$avgRound'},
          ),
          recommendedReviewTitle: NoesisL10n.tr(
            'Revisão Focada · {subject}',
            {'subject': weakestSubject!},
          ),
          recommendedReviewDescription: NoesisL10n.tr(
            'Revisão direcionada gerada pelo insight do Dashboard (média atual: {avg}%).',
            {'avg': '$avgRound'},
          ),
          recommendedDurationMinutes: 30,
          targetTab: 1,
          accuracySpots: spots,
          latestAccuracyPct: avgExamPct,
          weakestSubject: weakestSubject,
        );
      }
    }

    // 2. Analisar Flashcards pendentes / difíceis
    final pendingCards = ecosystem.cardsNeedingReview;
    final pendingDeck = ecosystem.mostPendingDeck;
    if (pendingCards > 0 && pendingDeck != null) {
      return DashboardInsight(
        badgeLabel: NoesisL10n.tr('Flashcards'),
        message: pendingCards == 1
            ? NoesisL10n.tr(
                'Você tem 1 flashcard para revisar, com prioridade em "{title}" ({subject}).',
                {'title': pendingDeck.title, 'subject': pendingDeck.subject},
              )
            : NoesisL10n.tr(
                'Você tem {count} flashcards para revisar, com prioridade em "{title}" ({subject}).',
                {
                  'count': '$pendingCards',
                  'title': pendingDeck.title,
                  'subject': pendingDeck.subject,
                },
              ),
        recommendedReviewTitle: NoesisL10n.tr(
          'Revisão Espaçada · {title}',
          {'title': pendingDeck.title},
        ),
        recommendedReviewDescription: NoesisL10n.tr(
          'Sessão ativa de flashcards para consolidar {subject}.',
          {'subject': pendingDeck.subject},
        ),
        recommendedDurationMinutes: 25,
        targetTab: 2,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
        weakestSubject: pendingDeck.subject,
      );
    }

    // 3. Analisar próximo passo da Trilha ativa
    final nextRoadmap = ecosystem.nextRoadmapStep;
    if (nextRoadmap != null) {
      return DashboardInsight(
        badgeLabel: NoesisL10n.tr('Trilhas'),
        message: NoesisL10n.tr(
          'Próxima etapa recomendada na trilha "{roadmap}": {step} (~{hours}h).',
          {
            'roadmap': nextRoadmap.roadmap.title,
            'step': nextRoadmap.step.title,
            'hours': '${nextRoadmap.step.estimatedHours}',
          },
        ),
        recommendedReviewTitle: NoesisL10n.tr(
          'Trilha · {step}',
          {'step': nextRoadmap.step.title},
        ),
        recommendedReviewDescription: NoesisL10n.tr(
          'Bloco prático para avançar na trilha "{roadmap}".',
          {'roadmap': nextRoadmap.roadmap.title},
        ),
        recommendedDurationMinutes: 45,
        targetTab: 8,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
        weakestSubject: nextRoadmap.roadmap.subject,
      );
    }

    // 4. Analisar próximos eventos ou ritmo da Meta Semanal
    final upcoming = ecosystem.upcomingEvents(referenceDate: referenceDate);
    if (upcoming.isNotEmpty) {
      final first = upcoming.first;
      final title = (first['title'] ?? NoesisL10n.tr('Atividade agendada')).toString();
      return DashboardInsight(
        badgeLabel: NoesisL10n.tr('Agenda'),
        message: upcoming.length == 1
            ? NoesisL10n.tr(
                'Você tem 1 compromisso nos próximos 7 dias, começando por "{title}".',
                {'title': title},
              )
            : NoesisL10n.tr(
                'Você tem {count} compromissos nos próximos 7 dias, começando por "{title}".',
                {'count': '${upcoming.length}', 'title': title},
              ),
        recommendedReviewTitle: NoesisL10n.tr(
          'Preparação · {title}',
          {'title': title},
        ),
        recommendedReviewDescription: NoesisL10n.tr(
          'Bloco de preparação antes do evento "{title}".',
          {'title': title},
        ),
        recommendedDurationMinutes: 30,
        targetTab: 5,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
      );
    }

    if (weeklyGoalMinutes <= 0) {
      return DashboardInsight(
        badgeLabel: NoesisL10n.tr('Consistência'),
        message: NoesisL10n.tr(
          'Você estudou {duration} nesta semana em ritmo livre ({days}d de streak).',
          {
            'duration': formatReadableDuration(currentWeekMinutes),
            'days': '${consistency.currentStreakDays}',
          },
        ),
        recommendedReviewTitle: NoesisL10n.tr('Sessão de Revisão · Noesis'),
        recommendedReviewDescription: NoesisL10n.tr('Bloco prático no seu próprio ritmo.'),
        recommendedDurationMinutes: 30,
        targetTab: 1,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
      );
    }

    final remainingMinutes = math.max(0, weeklyGoalMinutes - currentWeekMinutes);
    if (remainingMinutes > 0) {
      return DashboardInsight(
        badgeLabel: NoesisL10n.tr('Meta Semanal'),
        message: NoesisL10n.tr(
          'Você estudou {studied} nesta semana. Faltam {remaining} para bater sua meta semanal.',
          {
            'studied': formatReadableDuration(currentWeekMinutes),
            'remaining': formatReadableDuration(remainingMinutes),
          },
        ),
        recommendedReviewTitle: NoesisL10n.tr('Sessão de Foco · Meta Semanal'),
        recommendedReviewDescription:
            NoesisL10n.tr('Bloco planejado para avançar na meta semanal de estudos.'),
        recommendedDurationMinutes: 45,
        targetTab: 7,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
      );
    }

    return DashboardInsight(
      badgeLabel: NoesisL10n.tr('Consistência'),
      message: NoesisL10n.tr(
        'Meta semanal atingida com {days}d de streak! Consolide seu conhecimento criando um simulado ou nova trilha.',
        {'days': '${consistency.currentStreakDays}'},
      ),
      recommendedReviewTitle: NoesisL10n.tr('Revisão Consolidada · Noesis'),
      recommendedReviewDescription: NoesisL10n.tr('Sessão de consolidação semanal.'),
      recommendedDurationMinutes: 30,
      targetTab: 1,
      accuracySpots: spots,
      latestAccuracyPct: avgExamPct,
    );
  }
}
