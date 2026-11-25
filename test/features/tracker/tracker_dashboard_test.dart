import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/quizzes/data/saved_exams_repository.dart';
import 'package:noesis/features/roadmaps/data/roadmaps_repository.dart';
import 'package:noesis/features/roadmaps/models/roadmap_model.dart';
import 'package:noesis/features/tracker/dashboard_analytics.dart';
import 'package:noesis/features/tracker/tracker_screen.dart';
import '../../e2e/harness/mock_http_overrides.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  test('DashboardAnalytics computes 7-day comparison, consistency streak, and cross-feature insights', () {
    final ref = DateTime(2026, 11, 24, 15, 0);
    final sessions = [
      {'subject': 'Matemática', 'duration_minutes': 240, 'study_date': '2026-11-24'},
      {'subject': 'Física', 'duration_minutes': 90, 'study_date': '2026-11-23'},
      {'subject': 'Matemática', 'duration_minutes': 60, 'study_date': '2026-11-22'},
      // Semana anterior (total = 130m vs atual = 390m -> +200%)
      {'subject': 'Química', 'duration_minutes': 130, 'study_date': '2026-11-16'},
    ];

    final stats7d = DashboardAnalytics.computeLast7DaysStats(sessions, referenceDate: ref);
    expect(stats7d.totalMinutes, 390);
    expect(stats7d.previous7DaysMinutes, 130);
    expect(stats7d.deltaPercentage, 200);
    expect(stats7d.deltaLabel, '↑ 200% vs. semana ant.');
    expect(stats7d.bars.length, 7);
    expect(stats7d.bars.last.isToday, isTrue);
    expect(stats7d.bars.last.minutes, 240);

    final consistency = DashboardAnalytics.computeConsistencyStats(
      sessions,
      referenceDate: ref,
    );
    expect(consistency.currentStreakDays, 3);
    expect(consistency.bestDayMinutes, 240);
    expect(consistency.activeDaysCount, 4);

    // Simulado com nota baixa aciona recomendação prioritária em Simulados
    final lowExam = SavedExamAttempt(
      id: 'ex-1',
      groupKey: 'gk-1',
      examModelId: null,
      examModelName: 'Modo Livre',
      title: 'Simulado Álgebra',
      subject: 'Matemática',
      topic: 'Logaritmos',
      difficulty: 'Difícil',
      createdAt: ref.subtract(const Duration(days: 1)),
      elapsedSeconds: 1200,
      targetTotalCount: 10,
      questions: const [],
      userAnswers: const {},
      correctCount: 5,
      wrongCount: 5,
      blankCount: 0,
      scorePercentage: 50,
    );

    final ecosystemLowExam = DashboardEcosystemSnapshot(
      savedExams: [lowExam],
      decks: [
        FlashcardDeck(
          id: 'd1',
          title: 'Fórmulas',
          subject: 'Física',
          description: '',
          cards: [Flashcard(id: 'c1', front: 'F = ?', back: 'm*a', difficulty: 'hard')],
          createdAt: ref,
        ),
      ],
      notebooks: [
        StudyNotebook(id: 'n1', title: 'Caderno', subject: 'Matemática', createdAt: ref),
      ],
      roadmaps: [
        StudyRoadmap(
          id: 'r1',
          title: 'ENEM Exatas',
          goal: '800+',
          subject: 'Matemática',
          level: 'Intermediário',
          estimatedWeeks: 6,
          steps: const [
            RoadmapStep(id: 's1', title: 'Funções', status: RoadmapStepStatus.doing),
          ],
          createdAt: ref,
          updatedAt: ref,
        ),
      ],
    );

    final insightExam = DashboardAnalytics.buildInsight(
      ecosystemLowExam,
      sessions: sessions,
      consistency: consistency,
      weeklyGoalMinutes: 1500,
      currentWeekMinutes: 390,
      referenceDate: ref,
    );
    expect(insightExam.badgeLabel, 'Simulados');
    expect(insightExam.message, contains('Matemática'));
    expect(insightExam.latestAccuracyPct, 50);
    expect(insightExam.accuracySpots.length, 1);

    // Sem simulados fracos, prioriza Flashcards pendentes
    final insightCards = DashboardAnalytics.buildInsight(
      DashboardEcosystemSnapshot(
        decks: ecosystemLowExam.decks,
        roadmaps: ecosystemLowExam.roadmaps,
      ),
      sessions: sessions,
      consistency: consistency,
      weeklyGoalMinutes: 1500,
      currentWeekMinutes: 390,
      referenceDate: ref,
    );
    expect(insightCards.badgeLabel, 'Flashcards');
    expect(insightCards.message, contains('Fórmulas'));
  });

  testWidgets('TrackerScreen renders functional ecosystem overview, lap checkpoints, real insight actions, and analysis modal',
      (WidgetTester tester) async {
    await SavedExamsRepository.clearForTest();
    await RoadmapsRepository.clearForTest();
    await RoadmapsRepository.saveRoadmap(
      StudyRoadmap(
        id: 'rm-test-1',
        title: 'Trilha Flutter Avançado',
        goal: 'Dominar arquitetura',
        subject: 'Flutter',
        level: 'Avançado',
        estimatedWeeks: 4,
        steps: const [
          RoadmapStep(
            id: 'st-1',
            title: 'RenderObjects & CustomPainter',
            status: RoadmapStepStatus.doing,
            estimatedHours: 6,
          ),
        ],
        createdAt: DateTime(2026, 11, 20),
        updatedAt: DateTime(2026, 11, 24),
      ),
      syncRemote: false,
    );

    await TestAppHarness.pumpInHarness(
      tester,
      const TrackerScreen(),
      screenSize: const Size(1440, 960),
    );
    await tester.pumpAndSettle();

    expect(find.text('SESSÃO EM ANDAMENTO'), findsOneWidget);
    expect(find.text('Meta Semanal'), findsOneWidget);
    expect(find.text('Simulados'), findsOneWidget);
    expect(find.text('Flashcards & Cadernos'), findsOneWidget);
    expect(find.text('Trilhas & Agenda'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_streak_value')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_best_day_value')), findsOneWidget);

    // Marca um checkpoint funcional no timer
    final flagBtn = find.byIcon(Icons.flag_outlined);
    await tester.ensureVisible(flagBtn);
    await tester.tap(flagBtn);
    await tester.pumpAndSettle();
    expect(find.text('1 checkpoint'), findsOneWidget);

    // Agenda revisão real a partir do card Insight do agente
    final scheduleBtn = find.text('Agendar revisão');
    await tester.ensureVisible(scheduleBtn);
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    expect(find.text('Revisão agendada ✓'), findsOneWidget);
    // SnackBar com SnackBarAction deve sumir automaticamente (persist: false)
    expect(find.text('Ver Agenda'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Ver Agenda'), findsNothing);
    final events = await SupabaseService.getCalendarEvents();
    expect(events.any((e) => (e['category'] ?? '') == 'review'), isTrue);

    // Abre o Diagnóstico Completo pelo botão Ver análise
    final analysisBtn = find.text('Ver análise');
    await tester.ensureVisible(analysisBtn);
    await tester.tap(analysisBtn);
    await tester.pumpAndSettle();

    expect(find.text('Diagnóstico Completo de Estudos'), findsOneWidget);
    expect(find.text('Trilhas (Roadmap)'), findsOneWidget);

    // Gera plano via Noesis AI e verifica renderização formatada em Markdown (sem asteriscos crus)
    GeminiService.initialize('test-ai-key');
    MockHttpOverrides.customResponseBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text':
                    'Aqui está seu **plano prático**:\n\n* **Revisar Flashcards:** complete os cartões pendentes.\n* **Simulado:** faça um teste de *estruturas*.'
              }
            ]
          }
        }
      ]
    });

    await tester.tap(find.text('Gerar plano com Noesis AI'));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('**plano prático**'), findsNothing);

    MockHttpOverrides.reset();
    await TestAppHarness.drainAsync(tester);
  });
}
