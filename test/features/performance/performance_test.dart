import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/performance/data/performance_analytics_service.dart';
import 'package:noesis/features/performance/models/performance_report_model.dart';
import 'package:noesis/features/quizzes/data/saved_exams_repository.dart';
import 'package:noesis/features/roadmaps/data/roadmaps_repository.dart';
import 'package:noesis/features/roadmaps/models/roadmap_model.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  test('PerformanceAnalyticsService aggregates full account utilization and filters accurately by period', () async {
    final now = DateTime(2026, 11, 25, 16, 0);
    final svc = PerformanceAnalyticsService.instance;
    await svc.resetForTesting(customClock: () => now);
    await ShopService.instance.resetForTesting(grantWelcomeBonus: true, customClock: () => now);

    // Sessões espalhadas ao longo do tempo: hoje (-1d), 15 dias atrás e 60 dias atrás
    final sessions = [
      {
        'subject': 'Redes',
        'duration_minutes': 90,
        'study_date': DateTime(2026, 11, 24, 10, 0).toIso8601String(),
      },
      {
        'subject': 'Cloud AWS',
        'duration_minutes': 120,
        'study_date': DateTime(2026, 11, 10, 10, 0).toIso8601String(), // dentro de 30d, fora de 7d
      },
      {
        'subject': 'Direito',
        'duration_minutes': 180,
        'study_date': DateTime(2026, 9, 25, 10, 0).toIso8601String(), // dentro de 90d, fora de 30d
      },
    ];

    final exams = [
      SavedExamAttempt(
        id: 'ex-perf-1',
        groupKey: 'net',
        examModelId: null,
        examModelName: 'Modo Livre',
        title: 'Simulado Redes',
        subject: 'Redes',
        topic: 'TCP/IP',
        difficulty: 'Médio',
        createdAt: DateTime(2026, 11, 23, 12, 0),
        elapsedSeconds: 300,
        targetTotalCount: 10,
        questions: const [],
        userAnswers: const {},
        correctCount: 8,
        wrongCount: 2,
        blankCount: 0,
        scorePercentage: 80,
      ),
      SavedExamAttempt(
        id: 'ex-perf-2',
        groupKey: 'cloud',
        examModelId: null,
        examModelName: 'Modo Livre',
        title: 'Simulado Cloud',
        subject: 'Cloud AWS',
        topic: 'IAM',
        difficulty: 'Médio',
        createdAt: DateTime(2026, 11, 8, 12, 0),
        elapsedSeconds: 300,
        targetTotalCount: 10,
        questions: const [],
        userAnswers: const {},
        correctCount: 6,
        wrongCount: 4,
        blankCount: 0,
        scorePercentage: 60,
      ),
    ];

    final report7d = svc.buildReportFromData(
      range: PerformanceAnalyticsService.computeRange(PerformancePeriod.days7, referenceDate: now),
      now: now,
      sessions: sessions,
      exams: exams,
      decks: const [],
      notebooks: const [],
      roadmaps: const [],
      calendarEvents: const [],
      transactions: const [],
      dailyGoalMinutes: 60,
      weeklyGoalMinutes: 600,
    );
    expect(report7d.periodMinutes, 90);
    expect(report7d.examsCount, 1);
    expect(report7d.averageExamScore, 80);

    final report30d = svc.buildReportFromData(
      range: PerformanceAnalyticsService.computeRange(PerformancePeriod.days30, referenceDate: now),
      now: now,
      sessions: sessions,
      exams: exams,
      decks: const [],
      notebooks: const [],
      roadmaps: const [],
      calendarEvents: const [],
      transactions: const [],
      dailyGoalMinutes: 60,
      weeklyGoalMinutes: 600,
    );
    expect(report30d.periodMinutes, 210);
    expect(report30d.examsCount, 2);
    expect(report30d.averageExamScore, 70);

    final report90d = svc.buildReportFromData(
      range: PerformanceAnalyticsService.computeRange(PerformancePeriod.days90, referenceDate: now),
      now: now,
      sessions: sessions,
      exams: exams,
      decks: const [],
      notebooks: const [],
      roadmaps: const [],
      calendarEvents: const [],
      transactions: const [],
      dailyGoalMinutes: 60,
      weeklyGoalMinutes: 600,
    );
    expect(report90d.periodMinutes, 390);
    expect(report90d.subjectBreakdowns.length, 3);
  });

  testWidgets('Desempenho tab displays full account metrics, switches periods, and generates longitudinal AI reviews',
      (WidgetTester tester) async {
    final now = DateTime.now();
    await PerformanceAnalyticsService.instance.resetForTesting(customClock: () => now);
    await ShopService.instance.resetForTesting(grantWelcomeBonus: true, customClock: () => now);
    await SavedExamsRepository.clearForTest();
    await RoadmapsRepository.saveRoadmap(
      StudyRoadmap(
        id: 'rm-perf-1',
        title: 'Trilha Redes & Segurança',
        subject: 'Redes',
        goal: 'Domínio completo',
        level: 'Intermediário',
        steps: const [
          RoadmapStep(id: 's1', title: 'OSI & TCP/IP', status: RoadmapStepStatus.done),
          RoadmapStep(id: 's2', title: 'TLS 1.3', status: RoadmapStepStatus.todo),
        ],
        createdAt: now,
        updatedAt: now,
      ),
      syncRemote: false,
    );
    await SupabaseService.saveNotebook(
      StudyNotebook(
        id: 'nb-perf-1',
        title: 'Caderno Redes',
        subject: 'Redes',
        notes: [
          StudyNote(
            id: 'note-p1',
            notebookId: 'nb-perf-1',
            title: 'BGP',
            content: 'Resumo BGP',
            needsReview: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await SupabaseService.saveFlashcardDeck(
      FlashcardDeck(
        id: 'dk-perf-1',
        title: 'Deck Redes',
        subject: 'Redes',
        description: 'Portas',
        cards: [
          Flashcard(
            id: 'fc-p1',
            front: 'HTTPS',
            back: '443',
            difficulty: 'easy',
            lastReviewed: now,
            reviewCount: 1,
          ),
        ],
        createdAt: now,
      ),
    );

    await TestAppHarness.pumpInHarness(
      tester,
      const RootScreen(),
      screenSize: const Size(1440, 900),
    );
    final guestFinder = find.textContaining('Entrar sem login');
    if (guestFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestFinder.first);
      await tester.tap(guestFinder.first);
      await tester.pumpAndSettle();
    }

    // Navega até a aba Desempenho no menu lateral
    final perfNav = find.text('Desempenho');
    expect(perfNav, findsOneWidget);
    await tester.ensureVisible(perfNav);
    await tester.tap(perfNav);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('performance_screen_root')), findsOneWidget);
    expect(find.text('Desempenho & Analytics'), findsOneWidget);
    expect(find.byKey(const Key('performance_period_bar')), findsOneWidget);
    expect(find.byKey(const Key('perf_kpi_hours')), findsOneWidget);
    expect(find.byKey(const Key('perf_kpi_exams')), findsOneWidget);
    expect(find.byKey(const Key('perf_kpi_flashcards')), findsOneWidget);
    expect(find.byKey(const Key('perf_kpi_insights')), findsOneWidget);
    expect(find.byKey(const Key('performance_time_chart_card')), findsOneWidget);
    // O eixo Y do gráfico de ritmo separa horas e minutos em vez de mostrar tudo em "m"
    expect(find.textContaining('Distribuição de tempo estudado'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('performance_time_chart_card')),
        matching: find.textContaining('h'),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.byKey(const Key('performance_exam_chart_card')), findsOneWidget);
    expect(find.byKey(const Key('performance_subjects_breakdown')), findsOneWidget);
    expect(find.byKey(const Key('performance_ecosystem_matrix')), findsOneWidget);

    // Alterna período para 7 dias e gera Review da IA longitudinal
    await tester.tap(find.byKey(const Key('perf_period_7d')));
    await tester.pumpAndSettle();
    expect(find.text('7 dias analisados'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('performance_generate_ai_review_button')));
    await tester.tap(find.byKey(const Key('performance_generate_ai_review_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('performance_active_ai_review_body')), findsOneWidget);
    expect(find.byKey(const Key('performance_ai_reviews_timeline')), findsOneWidget);
    expect(find.text('HISTÓRICO DE REVIEWS AO LONGO DO TEMPO (1)'), findsOneWidget);

    // Muda para 90 dias e gera segundo review -> mantém histórico cronológico dos reviews
    await tester.ensureVisible(find.byKey(const Key('perf_period_90d')));
    await tester.tap(find.byKey(const Key('perf_period_90d')));
    await tester.pumpAndSettle();
    expect(find.text('90 dias analisados'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('performance_generate_ai_review_button')));
    await tester.tap(find.byKey(const Key('performance_generate_ai_review_button')));
    await tester.pumpAndSettle();
    expect(find.text('HISTÓRICO DE REVIEWS AO LONGO DO TEMPO (2)'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });
}
