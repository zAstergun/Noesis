import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
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
    required this.currentStreakDays,
    required this.bestDayMinutes,
    required this.bestDayDate,
    required this.activeDaysCount,
    required this.totalTrackedDays,
  });

  final List<List<int>> levels;
  final List<List<int>> minutesGrid;
  final List<List<DateTime>> datesGrid;
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
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  static String formatReadableDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _weekdayLetter(int weekday) {
    switch (weekday) {
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
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
      default:
        return 'Dom';
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
      bars.add(
        DashboardDayBar(
          date: d,
          dayLetter: _weekdayLetter(d.weekday),
          fullDayLabel: '${_weekdayName(d.weekday)} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
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
      deltaLabel = 'Sem registros nos últimos 7d';
      deltaPositive = false;
    } else if (prevTotal == 0) {
      deltaLabel = 'Nova sequência semanal';
      deltaPositive = true;
    } else {
      final diffPct = (((currentTotal - prevTotal) / prevTotal) * 100).round();
      deltaPct = diffPct;
      if (diffPct > 0) {
        deltaLabel = '↑ $diffPct% vs. semana ant.';
        deltaPositive = true;
      } else if (diffPct < 0) {
        deltaLabel = '↓ ${diffPct.abs()}% vs. semana ant.';
        deltaPositive = false;
      } else {
        deltaLabel = '= 0% vs. semana ant.';
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
    int columns = 26,
    int rows = 7,
    DateTime? referenceDate,
  }) {
    final today = _dayOnly(referenceDate ?? DateTime.now());
    final byDay = _groupMinutesByDay(sessions, exams: exams);

    // Alinha colunas em semanas calendário (Seg..Dom), terminando na semana atual.
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = currentWeekMonday.subtract(Duration(days: (columns - 1) * 7));

    final levels = List.generate(columns, (_) => List.filled(rows, 0));
    final minutesGrid = List.generate(columns, (_) => List.filled(rows, 0));
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
          continue;
        }
        trackedDays++;
        final mins = byDay[date] ?? 0;
        minutesGrid[col][row] = mins;
        levels[col][row] = levelForMinutes(mins);
        if (mins > 0) activeDays++;
      }
    }

    // Streak real considerando sessões + simulados registrados
    int streak = 0;
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime? cursor;
    if ((byDay[today] ?? 0) > 0) {
      cursor = today;
    } else if ((byDay[yesterday] ?? 0) > 0) {
      cursor = yesterday;
    }
    while (cursor != null && (byDay[cursor] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int bestMinutes = 0;
    DateTime? bestDate;
    byDay.forEach((date, mins) {
      if (mins > bestMinutes) {
        bestMinutes = mins;
        bestDate = date;
      }
    });

    return DashboardConsistencyStats(
      levels: levels,
      minutesGrid: minutesGrid,
      datesGrid: datesGrid,
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

    final rawMap = <String, int>{};
    for (final s in sessions) {
      final mins = (s['duration_minutes'] as num?)?.toInt() ?? 0;
      if (mins <= 0) continue;
      if (cutoff != null) {
        final rawDate = (s['study_date'] ?? s['created_at'] ?? '').toString().trim();
        final parsed = DateTime.tryParse(rawDate);
        if (parsed == null || _dayOnly(parsed).isBefore(cutoff)) continue;
      }
      final subject = (s['subject'] ?? 'Outros').toString().trim();
      final label = subject.isEmpty ? 'Outros' : subject;
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
      'Outros': othersMinutes,
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
      return const ['Geral', 'Matemática', 'Programação', 'Idiomas'];
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
        final key = attempt.subject.trim().isEmpty ? 'Geral' : attempt.subject.trim();
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
          badgeLabel: 'Simulados',
          message:
              'Sua acurácia em $weakestSubject está em $avgRound% nos simulados. '
              'Agende uma revisão focada de 30 min para reforçar os erros.',
          recommendedReviewTitle: 'Revisão Focada · $weakestSubject',
          recommendedReviewDescription:
              'Revisão direcionada gerada pelo insight do Dashboard (média atual: $avgRound%).',
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
        badgeLabel: 'Flashcards',
        message:
            'Você tem $pendingCards flashcard${pendingCards == 1 ? '' : 's'} para revisar, '
            'com prioridade em "${pendingDeck.title}" (${pendingDeck.subject}).',
        recommendedReviewTitle: 'Revisão Espaçada · ${pendingDeck.title}',
        recommendedReviewDescription:
            'Sessão ativa de flashcards para consolidar ${pendingDeck.subject}.',
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
        badgeLabel: 'Trilhas',
        message:
            'Próxima etapa recomendada na trilha "${nextRoadmap.roadmap.title}": '
            '${nextRoadmap.step.title} (~${nextRoadmap.step.estimatedHours}h).',
        recommendedReviewTitle: 'Trilha · ${nextRoadmap.step.title}',
        recommendedReviewDescription:
            'Bloco prático para avançar na trilha "${nextRoadmap.roadmap.title}".',
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
      final title = (first['title'] ?? 'Atividade agendada').toString();
      return DashboardInsight(
        badgeLabel: 'Agenda',
        message:
            'Você tem ${upcoming.length} compromisso${upcoming.length == 1 ? '' : 's'} nos próximos 7 dias, '
            'começando por "$title".',
        recommendedReviewTitle: 'Preparação · $title',
        recommendedReviewDescription:
            'Bloco de preparação antes do evento "$title".',
        recommendedDurationMinutes: 30,
        targetTab: 5,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
      );
    }

    final remainingMinutes = math.max(0, weeklyGoalMinutes - currentWeekMinutes);
    if (remainingMinutes > 0) {
      return DashboardInsight(
        badgeLabel: 'Meta Semanal',
        message:
            'Você estudou ${formatReadableDuration(currentWeekMinutes)} nesta semana. '
            'Faltam ${formatReadableDuration(remainingMinutes)} para bater sua meta semanal.',
        recommendedReviewTitle: 'Sessão de Foco · Meta Semanal',
        recommendedReviewDescription:
            'Bloco planejado para avançar na meta semanal de estudos.',
        recommendedDurationMinutes: 45,
        targetTab: 7,
        accuracySpots: spots,
        latestAccuracyPct: avgExamPct,
      );
    }

    return DashboardInsight(
      badgeLabel: 'Consistência',
      message:
          'Meta semanal atingida com ${consistency.currentStreakDays}d de streak! '
          'Consolide seu conhecimento criando um simulado ou nova trilha.',
      recommendedReviewTitle: 'Revisão Consolidada · Noesis',
      recommendedReviewDescription: 'Sessão de consolidação semanal.',
      recommendedDurationMinutes: 30,
      targetTab: 1,
      accuracySpots: spots,
      latestAccuracyPct: avgExamPct,
    );
  }
}
