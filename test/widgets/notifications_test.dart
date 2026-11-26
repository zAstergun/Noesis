import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/notifications_service.dart';
import 'package:noesis/core/shop_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/quizzes/data/saved_exams_repository.dart';
import 'package:noesis/features/roadmaps/models/roadmap_model.dart';
import 'package:noesis/main.dart';
import '../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    await NotificationsService.instance.resetForTesting();
    GeminiService.initialize('');
  });

  test('NotificationsService builds real notifications from user study data without fake mocks', () {
    final now = DateTime(2026, 11, 25, 10, 0);
    final notifications = NotificationsService.buildNotificationsFromData(
      now: now,
      events: [
        {
          'id': 'evt-exam-1',
          'title': 'Prova de Redes & Segurança',
          'category': 'exam',
          'start_time': DateTime(2026, 11, 25, 14, 0).toIso8601String(),
          'is_completed': false,
        },
      ],
      sessions: [
        {
          'subject': 'Criptografia',
          'topic': 'TLS 1.3',
          'duration_minutes': 60,
          'study_date': DateTime(2026, 11, 25, 8, 30).toIso8601String(),
        },
      ],
      weeklyGoalMinutes: 60,
      decks: [
        FlashcardDeck(
          id: 'deck-1',
          title: 'Segurança de Redes',
          subject: 'Cyber',
          description: '',
          cards: [
            Flashcard(id: 'c1', front: 'TLS?', back: 'Transport Layer Security', difficulty: 'unreviewed'),
            Flashcard(id: 'c2', front: 'AES?', back: 'Symmetric cipher', difficulty: 'hard'),
          ],
          createdAt: now,
        ),
      ],
      notebooks: [
        StudyNotebook(
          id: 'nb-1',
          title: 'Caderno Cloud',
          subject: 'Cloud',
          description: '',
          notes: [
            StudyNote(
              id: 'n1',
              notebookId: 'nb-1',
              title: 'IAM',
              content: 'Least privilege',
              needsReview: true,
              updatedAt: now.subtract(const Duration(days: 5)),
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      exams: [
        SavedExamAttempt(
          id: 'ex-1',
          groupKey: 'sec',
          examModelId: null,
          examModelName: 'Simulado',
          title: 'Simulado Security+',
          subject: 'Segurança',
          topic: 'OWASP',
          difficulty: 'Médio',
          createdAt: now.subtract(const Duration(hours: 3)),
          elapsedSeconds: 300,
          targetTotalCount: 10,
          questions: List.generate(10, (i) => {'question': 'Q$i'}),
          userAnswers: const {},
          correctCount: 5,
          wrongCount: 5,
          blankCount: 0,
          scorePercentage: 50,
        ),
      ],
      roadmaps: [
        StudyRoadmap(
          id: 'rm-1',
          title: 'Trilha AppSec',
          subject: 'Segurança',
          goal: 'Dominar AppSec',
          level: 'Intermediário',
          steps: const [
            RoadmapStep(id: 's1', title: 'XSS & CSP', status: RoadmapStepStatus.doing),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      hasConfiguredAiKey: false,
      hasWelcomeBonus: true,
    );

    final titles = notifications.map((n) => n.title).join(' | ');
    final messages = notifications.map((n) => n.message).join(' | ');

    // Nenhum texto mockado antigo
    expect(messages.contains('42 dias de consistência'), isFalse);
    expect(titles.contains('Novo Simulado RAG Gerado'), isFalse);

    // Notificações reais derivadas dos dados
    expect(notifications.any((n) => n.id == 'welcome_insights_bonus' && n.title.contains('+100 Insights') && n.targetTab == 9), isTrue);
    expect(notifications.any((n) => n.title == 'Prova / Marco Próximo' && n.message.contains('Prova de Redes & Segurança')), isTrue);
    expect(notifications.any((n) => n.title.contains('2 cards para revisar') && n.targetTab == 2), isTrue);
    expect(notifications.any((n) => n.title.contains('1 anotação para revisar') && n.targetTab == 3), isTrue);
    expect(notifications.any((n) => n.title.contains('Meta Semanal Atingida')), isTrue);
    expect(notifications.any((n) => n.title.contains('Sequência Ativa · 1 dia')), isTrue);
    expect(notifications.any((n) => n.title.contains('Revisão Recomendada em Simulado') && n.targetTab == 1), isTrue);
    expect(notifications.any((n) => n.title.contains('Próxima Etapa · Trilha AppSec') && n.targetTab == 8), isTrue);
    expect(notifications.any((n) => n.title == 'Chave de IA não configurada' && n.targetTab == 6), isTrue);
  });

  testWidgets('Notification bell opens live notifications, marks read, navigates, dismisses and clears', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await SupabaseService.addCalendarEvent(
      title: 'Simulado Live Agenda',
      category: 'exam',
      startTime: DateTime.now().add(const Duration(hours: 2)),
      endTime: DateTime.now().add(const Duration(hours: 3)),
    );

    await TestAppHarness.pumpInHarness(tester, const NoesisApp());
    await tester.pumpAndSettle();

    final guestBtn = find.text('Entrar sem login · Modo de Teste');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('notifications_bell_button')), findsOneWidget);
    expect(find.byKey(const Key('notifications_unread_dot')), findsOneWidget);

    // Abre o painel de notificações
    await tester.tap(find.byKey(const Key('notifications_bell_button')));
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsOneWidget);
    expect(ShopService.instance.balance, 100);
    expect(find.textContaining('Bônus de boas-vindas · +100 Insights'), findsOneWidget);
    expect(find.textContaining('Simulado Live Agenda'), findsAtLeastNWidgets(1));
    expect(find.text('Chave de IA não configurada'), findsOneWidget);
    expect(find.textContaining('42 dias de consistência'), findsNothing);

    // Dispara descarte individual em uma notificação
    await tester.tap(find.byTooltip('Dispensar').first);
    await tester.pumpAndSettle();

    // Toca em "Marcar lidas" -> badge de não lidas some
    if (find.text('Marcar lidas').evaluate().isNotEmpty) {
      await tester.tap(find.text('Marcar lidas'));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('notifications_unread_dot')), findsNothing);

    // Toca em "Limpar todas" -> mostra estado vazio e permite verificar novamente
    await tester.tap(find.text('Limpar todas'));
    await tester.pumpAndSettle();
    expect(find.text('Tudo em dia!'), findsOneWidget);

    await tester.tap(find.text('Verificar notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Chave de IA não configurada'), findsOneWidget);

    // Toca na notificação de chave de IA -> navega diretamente para Configurações
    await tester.tap(find.text('Chave de IA não configurada'));
    await tester.pumpAndSettle();
    expect(find.text('Preferências de tema, chave de IA, idiomas do ecossistema e perfil'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });
}
