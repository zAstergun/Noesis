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
    await SupabaseService.resetProfileForTesting();
    await NotificationsService.instance.resetForTesting();
    GeminiService.initialize('');
  });

  tearDown(() async {
    await SupabaseService.resetProfileForTesting();
    await NotificationsService.instance.resetForTesting();
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
    expect(notifications.any((n) => n.id == 'email_verification_pending'), isFalse);

    final unconfirmedNotes = NotificationsService.buildNotificationsFromData(
      now: now,
      events: const [],
      sessions: const [],
      weeklyGoalMinutes: 60,
      decks: const [],
      notebooks: const [],
      exams: const [],
      roadmaps: const [],
      hasConfiguredAiKey: true,
      isEmailConfirmed: false,
    );
    expect(
      unconfirmedNotes.any((n) => n.id == 'email_verification_pending' && n.title == 'Confirme seu e-mail'),
      isTrue,
    );
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

  test('Calendar event IDs stay identical between local ISO and UTC ISO and weekId is stable across month boundary', () {
    final localStart = DateTime(2026, 11, 26, 22, 0);
    final nowLocal = DateTime(2026, 11, 26, 20, 0);

    final fromLocal = NotificationsService.buildNotificationsFromData(
      now: nowLocal,
      events: [
        {
          'id': 'evt-utc-test',
          'title': 'Revisão de Física',
          'category': 'study',
          'start_time': localStart.toIso8601String(),
          'is_completed': false,
        },
      ],
      sessions: const [],
      weeklyGoalMinutes: 60,
      decks: const [],
      notebooks: const [],
      exams: const [],
      roadmaps: const [],
      hasConfiguredAiKey: true,
    );

    final fromUtc = NotificationsService.buildNotificationsFromData(
      now: nowLocal,
      events: [
        {
          'id': 'evt-utc-test',
          'title': 'Revisão de Física',
          'category': 'study',
          'start_time': localStart.toUtc().toIso8601String(),
          'is_completed': false,
        },
      ],
      sessions: const [],
      weeklyGoalMinutes: 60,
      decks: const [],
      notebooks: const [],
      exams: const [],
      roadmaps: const [],
      hasConfiguredAiKey: true,
    );

    expect(fromLocal.first.id, fromUtc.first.id);
    expect(fromLocal.first.timeLabel, fromUtc.first.timeLabel);

    // Segunda (30/11/2026) e Terça (01/12/2026) devem gerar o mesmo ID de meta semanal
    final mondayNotes = NotificationsService.buildNotificationsFromData(
      now: DateTime(2026, 11, 30, 18, 0),
      events: const [],
      sessions: [
        {'id': 's1', 'duration_minutes': 60, 'study_date': '2026-11-30'},
      ],
      weeklyGoalMinutes: 60,
      decks: const [],
      notebooks: const [],
      exams: const [],
      roadmaps: const [],
      hasConfiguredAiKey: true,
    );
    final tuesdayNotes = NotificationsService.buildNotificationsFromData(
      now: DateTime(2026, 12, 1, 18, 0),
      events: const [],
      sessions: [
        {'id': 's1', 'duration_minutes': 60, 'study_date': '2026-11-30'},
      ],
      weeklyGoalMinutes: 60,
      decks: const [],
      notebooks: const [],
      exams: const [],
      roadmaps: const [],
      hasConfiguredAiKey: true,
    );
    final monGoalId = mondayNotes.firstWhere((n) => n.id.startsWith('goal_reached_')).id;
    final tueGoalId = tuesdayNotes.firstWhere((n) => n.id.startsWith('goal_reached_')).id;
    expect(monGoalId, tueGoalId);
  });

  test('Read, dismissed, cleared and restored notification states persist across relogin and isolate accounts', () async {
    final remoteDb = <String, Map<String, dynamic>>{};
    SupabaseService.notificationsStateLoaderOverrideForTesting = (uid) async {
      final entry = remoteDb[uid];
      return entry == null ? null : Map<String, dynamic>.from(entry);
    };
    SupabaseService.notificationsStateSaverOverrideForTesting = (uid, state) async {
      remoteDb[uid] = Map<String, dynamic>.from(state);
    };

    // 1. Login como User A
    SupabaseService.currentUserIdOverrideForTesting = 'user-a';
    NotificationsService.instance.handleAuthUserChanged('user-a');
    await NotificationsService.instance.refresh();

    final initialA = NotificationsService.instance.notificationsNotifier.value;
    expect(initialA.any((n) => n.id == 'welcome_insights_bonus' && !n.isRead), isTrue);
    expect(initialA.any((n) => n.id == 'ai_key_missing' && !n.isRead), isTrue);

    // Marca 'ai_key_missing' como lida e dispensa 'welcome_insights_bonus', depois sai imediatamente
    await NotificationsService.instance.markAsRead('ai_key_missing');
    await NotificationsService.instance.dismiss('welcome_insights_bonus');
    await SupabaseService.signOut();

    // 2. Reloga como User A em um ambiente sem cache local (ex: novo navegador / porta diferente)
    await NotificationsService.instance.resetForTesting();
    SupabaseService.currentUserIdOverrideForTesting = 'user-a';
    NotificationsService.instance.handleAuthUserChanged('user-a');
    await NotificationsService.instance.refresh();

    final reloggedA = NotificationsService.instance.notificationsNotifier.value;
    expect(reloggedA.any((n) => n.id == 'welcome_insights_bonus'), isFalse);
    final aiNoteAfterRelogin = reloggedA.firstWhere((n) => n.id == 'ai_key_missing');
    expect(aiNoteAfterRelogin.isRead, isTrue);

    // 3. Troca para User B -> não deve herdar estado lido/dispensado do User A
    await SupabaseService.signOut();
    SupabaseService.currentUserIdOverrideForTesting = 'user-b';
    NotificationsService.instance.handleAuthUserChanged('user-b');
    await NotificationsService.instance.refresh();

    final listB = NotificationsService.instance.notificationsNotifier.value;
    expect(listB.any((n) => n.id == 'welcome_insights_bonus' && !n.isRead), isTrue);
    expect(listB.any((n) => n.id == 'ai_key_missing' && !n.isRead), isTrue);

    // 4. Volta para User A, limpa todas sem await imediato antes do signOut (testa flushPendingSync)
    await SupabaseService.signOut();
    SupabaseService.currentUserIdOverrideForTesting = 'user-a';
    NotificationsService.instance.handleAuthUserChanged('user-a');
    await NotificationsService.instance.refresh();

    // Dispara dismissAll sem aguardar e chama signOut logo em seguida
    // ignore: unawaited_futures
    NotificationsService.instance.dismissAll();
    await SupabaseService.signOut();

    // Reloga como User A sem cache local -> lista deve permanecer vazia
    await NotificationsService.instance.resetForTesting();
    SupabaseService.currentUserIdOverrideForTesting = 'user-a';
    NotificationsService.instance.handleAuthUserChanged('user-a');
    await NotificationsService.instance.refresh();
    expect(NotificationsService.instance.notificationsNotifier.value, isEmpty);

    // 5. Restaura notificações e reloga -> restauradas voltam, e a que já era lida continua lida
    await NotificationsService.instance.restoreAndRefresh();
    await SupabaseService.signOut();
    await NotificationsService.instance.resetForTesting();
    SupabaseService.currentUserIdOverrideForTesting = 'user-a';
    NotificationsService.instance.handleAuthUserChanged('user-a');
    await NotificationsService.instance.refresh();

    final restoredA = NotificationsService.instance.notificationsNotifier.value;
    expect(restoredA.any((n) => n.id == 'welcome_insights_bonus' && !n.isRead), isTrue);
    expect(restoredA.any((n) => n.id == 'ai_key_missing' && n.isRead), isTrue);
  });
}
