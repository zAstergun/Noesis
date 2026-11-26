enum PerformancePeriod {
  days7,
  days30,
  days90,
  allTime,
  custom,
}

extension PerformancePeriodX on PerformancePeriod {
  String get label {
    switch (this) {
      case PerformancePeriod.days7:
        return 'Últimos 7 dias';
      case PerformancePeriod.days30:
        return 'Últimos 30 dias';
      case PerformancePeriod.days90:
        return 'Últimos 90 dias';
      case PerformancePeriod.allTime:
        return 'Todo o histórico';
      case PerformancePeriod.custom:
        return 'Personalizado';
    }
  }

  String get shortLabel {
    switch (this) {
      case PerformancePeriod.days7:
        return '7 dias';
      case PerformancePeriod.days30:
        return '30 dias';
      case PerformancePeriod.days90:
        return '90 dias';
      case PerformancePeriod.allTime:
        return 'Tudo';
      case PerformancePeriod.custom:
        return 'Personalizado';
    }
  }
}

class PerformancePeriodRange {
  const PerformancePeriodRange({
    required this.period,
    required this.start,
    required this.end,
    required this.label,
  });

  final PerformancePeriod period;
  final DateTime start;
  final DateTime end;
  final String label;

  int get spanDays => (end.difference(start).inDays + 1).clamp(1, 36500);
}

class SubjectBreakdownItem {
  const SubjectBreakdownItem({
    required this.subject,
    required this.minutes,
    required this.sessionsCount,
    required this.shareFraction,
    this.examCount = 0,
    this.averageExamScore,
  });

  final String subject;
  final int minutes;
  final int sessionsCount;
  final double shareFraction;
  final int examCount;
  final double? averageExamScore;
}

class PerformanceTimeBucket {
  const PerformanceTimeBucket({
    required this.label,
    required this.minutes,
    required this.insightsEarned,
    required this.date,
  });

  final String label;
  final int minutes;
  final int insightsEarned;
  final DateTime date;
}

class ExamTrendPoint {
  const ExamTrendPoint({
    required this.examId,
    required this.title,
    required this.subject,
    required this.scorePercentage,
    required this.correctCount,
    required this.totalCount,
    required this.createdAt,
  });

  final String examId;
  final String title;
  final String subject;
  final double scorePercentage;
  final int correctCount;
  final int totalCount;
  final DateTime createdAt;
}

class PerformanceAiReview {
  const PerformanceAiReview({
    required this.id,
    required this.createdAt,
    required this.periodLabel,
    required this.summaryHeadline,
    required this.markdownContent,
    this.generatedWithLlm = false,
  });

  final String id;
  final DateTime createdAt;
  final String periodLabel;
  final String summaryHeadline;
  final String markdownContent;
  final bool generatedWithLlm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'period_label': periodLabel,
        'summary_headline': summaryHeadline,
        'markdown_content': markdownContent,
        'generated_with_llm': generatedWithLlm,
      };

  factory PerformanceAiReview.fromJson(Map<String, dynamic> json) {
    return PerformanceAiReview(
      id: (json['id'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      periodLabel: (json['period_label'] ?? 'Período').toString(),
      summaryHeadline: (json['summary_headline'] ?? 'Review de Desempenho').toString(),
      markdownContent: (json['markdown_content'] ?? '').toString(),
      generatedWithLlm: json['generated_with_llm'] == true,
    );
  }
}

class AccountPerformanceReport {
  const AccountPerformanceReport({
    required this.range,
    required this.generatedAt,
    required this.periodMinutes,
    required this.previousPeriodMinutes,
    required this.minutesDeltaPct,
    required this.sessionsCount,
    required this.activeDaysCount,
    required this.dailyAverageMinutes,
    required this.bestDayMinutes,
    required this.bestDayDate,
    required this.currentStreakDays,
    required this.dailyGoalMinutes,
    required this.weeklyGoalMinutes,
    required this.timeBuckets,
    required this.subjectBreakdowns,
    required this.examsCount,
    required this.totalQuestionsAnswered,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.blankAnswers,
    required this.averageExamScore,
    required this.previousExamScore,
    required this.bestExamScore,
    required this.examTrend,
    required this.totalDecks,
    required this.totalCards,
    required this.cardsReviewedInPeriod,
    required this.easyCards,
    required this.goodCards,
    required this.hardCards,
    required this.unreviewedCards,
    required this.cardsDueCount,
    required this.retentionRatePct,
    required this.totalNotebooks,
    required this.totalNotes,
    required this.notesUpdatedInPeriod,
    required this.notesNeedingReview,
    required this.totalRoadmaps,
    required this.completedRoadmapSteps,
    required this.totalRoadmapSteps,
    required this.roadmapProgressPct,
    required this.calendarEventsInPeriod,
    required this.calendarCompletedInPeriod,
    required this.calendarPendingUpcoming,
    required this.insightsEarnedInPeriod,
    required this.insightsInvestedInPeriod,
    required this.currentInsightsBalance,
    required this.consistencySealsCount,
    required this.currentEloName,
    required this.bestEloName,
    required this.currentWeeklyRank,
    required this.joinedGroupsCount,
    required this.mutualConnectionsCount,
  });

  final PerformancePeriodRange range;
  final DateTime generatedAt;

  // Tempo & Consistência
  final int periodMinutes;
  final int previousPeriodMinutes;
  final int? minutesDeltaPct;
  final int sessionsCount;
  final int activeDaysCount;
  final int dailyAverageMinutes;
  final int bestDayMinutes;
  final DateTime? bestDayDate;
  final int currentStreakDays;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;

  // Séries & Matérias
  final List<PerformanceTimeBucket> timeBuckets;
  final List<SubjectBreakdownItem> subjectBreakdowns;

  // Simulados & Questões
  final int examsCount;
  final int totalQuestionsAnswered;
  final int correctAnswers;
  final int wrongAnswers;
  final int blankAnswers;
  final double? averageExamScore;
  final double? previousExamScore;
  final double? bestExamScore;
  final List<ExamTrendPoint> examTrend;

  // Flashcards
  final int totalDecks;
  final int totalCards;
  final int cardsReviewedInPeriod;
  final int easyCards;
  final int goodCards;
  final int hardCards;
  final int unreviewedCards;
  final int cardsDueCount;
  final int retentionRatePct;

  // Cadernos, Trilhas & Calendário
  final int totalNotebooks;
  final int totalNotes;
  final int notesUpdatedInPeriod;
  final int notesNeedingReview;
  final int totalRoadmaps;
  final int completedRoadmapSteps;
  final int totalRoadmapSteps;
  final int roadmapProgressPct;
  final int calendarEventsInPeriod;
  final int calendarCompletedInPeriod;
  final int calendarPendingUpcoming;

  // Insights & Comunidade
  final int insightsEarnedInPeriod;
  final int insightsInvestedInPeriod;
  final int currentInsightsBalance;
  final int consistencySealsCount;
  final String currentEloName;
  final String bestEloName;
  final int currentWeeklyRank;
  final int joinedGroupsCount;
  final int mutualConnectionsCount;
}
