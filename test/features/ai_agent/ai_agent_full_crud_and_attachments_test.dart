import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/noesis_agent_tools.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/ai_agent/ai_assistant_screen.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/roadmaps/data/roadmaps_repository.dart';
import '../../e2e/harness/mock_http_overrides.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() {
    MockHttpOverrides.reset();
    AiAssistantScreen.filePickerOverrideForTesting = null;
  });

  tearDown(() {
    AiAssistantScreen.filePickerOverrideForTesting = null;
  });

  test('parseNaturalDateTime resolves Portuguese natural dates and times accurately', () {
    final now = DateTime(2026, 11, 25, 8, 30); // Quarta-feira

    final dtToday11 = NoesisAgentTools.parseNaturalDateTime(
      'crie um aviso no calendario de uma prova para as 11 da manhã de hoje',
      now: now,
    );
    expect(dtToday11.year, 2026);
    expect(dtToday11.month, 11);
    expect(dtToday11.day, 25);
    expect(dtToday11.hour, 11);
    expect(dtToday11.minute, 0);

    final dtTonight9 = NoesisAgentTools.parseNaturalDateTime(
      'agendar revisão amanhã às 9 da noite',
      now: now,
    );
    expect(dtTonight9.day, 26);
    expect(dtTonight9.hour, 21);

    final dtAfternoon3 = NoesisAgentTools.parseNaturalDateTime(
      'marque estudo hoje para as 3 da tarde',
      now: now,
    );
    expect(dtAfternoon3.day, 25);
    expect(dtAfternoon3.hour, 15);
  });

  test('executeAgentChat recovers unexecuted calendar intent when LLM hallucinates confirmation', () async {
    GeminiService.initialize('test-key');
    MockHttpOverrides.customResponseBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text':
                    'Perfeito, Aster. Acabei de registrar a sua prova no **Calendário** para hoje, às **11:00**.'
              }
            ]
          }
        }
      ]
    });

    final before = await SupabaseService.getCalendarEvents();
    final beforeCount = before.length;

    final reply = await GeminiService.executeAgentChat(
      userMessage: 'crie um aviso no calendario de uma prova para as 11 da manhã de hoje',
      history: [],
    );

    final after = await SupabaseService.getCalendarEvents();
    expect(after.length, beforeCount + 1);
    expect(GeminiService.lastExecutedActions, isNotEmpty);
    expect(GeminiService.lastExecutedActions.first.name, 'schedule_calendar_event');

    final created = after.last;
    final createdStart = DateTime.parse(created['start_time'].toString());
    expect(createdStart.hour, 11);
    expect(createdStart.day, DateTime.now().day);
    expect(reply, isNot(contains('schedule_calendar_event')));
  });

  test('NoesisAgentTools supports full account inspection and CRUD across all pages', () async {
    Future<List<Map<String, dynamic>>> fakeQuiz({
      required String subject,
      required String topic,
      required int numberOfQuestions,
      required String difficulty,
      String? referenceContext,
    }) async {
      return [
        {
          'question': 'Pergunta sobre $topic',
          'options': ['A', 'B', 'C', 'D'],
          'correct_index': 0,
          'explanation': 'Explicação teste',
        }
      ];
    }

    Future<List<Map<String, dynamic>>> fakeCards({
      required String subject,
      required String topic,
      required int count,
      String difficulty = 'Médio',
    }) async {
      return [
        {'front': 'O que é $topic?', 'back': 'Conceito de $subject', 'tags': [subject]}
      ];
    }

    // 1. Weekly Goal
    final goalRes = await NoesisAgentTools.executeTool(
      name: 'set_weekly_goal',
      args: {'hours': 30},
      userMessage: 'Defina meta semanal de 30h',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    expect(goalRes.status, 'completed');
    expect(await SupabaseService.loadWeeklyGoalMinutes(), 30 * 60);

    // 2. Notebook + Note Create / Update / Delete
    final nbRes = await NoesisAgentTools.executeTool(
      name: 'create_notebook_or_note',
      args: {
        'notebook_title': 'Caderno E2E Agente',
        'subject': 'Engenharia de Software',
        'note_title': 'Padrões GoF',
        'note_content': 'Singleton, Strategy, Observer.',
        'needs_review': true,
      },
      userMessage: 'Crie um caderno sobre padrões GoF',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    expect(nbRes.status, 'completed');
    var notebooks = await SupabaseService.getNotebooks();
    expect(notebooks.any((n) => n.title == 'Caderno E2E Agente'), isTrue);

    final updNbRes = await NoesisAgentTools.executeTool(
      name: 'update_notebook_or_note',
      args: {
        'notebook_match': 'Caderno E2E Agente',
        'note_match': 'Padrões GoF',
        'new_note_content': 'Strategy e Adapter explicados.',
        'mark_reviewed': true,
      },
      userMessage: 'Atualize a nota Padrões GoF',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    expect(updNbRes.status, 'completed');

    // 3. Roadmap Create / Inspect / Delete
    final rmRes = await NoesisAgentTools.executeTool(
      name: 'create_roadmap',
      args: {'subject': 'Cloud Native', 'goal': 'Kubernetes CKAD', 'estimated_weeks': 3},
      userMessage: 'Crie trilha de Kubernetes CKAD',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    expect(rmRes.status, 'completed');
    final roadmaps = await RoadmapsRepository.loadAll();
    expect(roadmaps.any((r) => r.subject == 'Cloud Native'), isTrue);

    // 4. Inspect full account & attachable items
    final inspectRes = await NoesisAgentTools.executeTool(
      name: 'inspect_account_data',
      args: {'scope': 'all'},
      userMessage: 'Leia tudo da minha conta',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    final data = inspectRes.responsePayload['data'] as Map<String, dynamic>;
    expect(data['notebooks'], isNotEmpty);
    expect(data['roadmaps'], isNotEmpty);
    expect(data['weekly_goal']['goal_minutes'], 30 * 60);

    final attachables = await NoesisAgentTools.listAttachableItems();
    expect(attachables.any((a) => a.title == 'Caderno E2E Agente' && a.kind == 'notebook'), isTrue);

    // 5. Quiz Create & Delete
    final quizRes = await NoesisAgentTools.executeTool(
      name: 'create_quiz',
      args: {'title': 'Simulado Temporário IA', 'subject': 'Redes', 'num_questions': 1},
      userMessage: 'Crie simulado',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    expect(quizRes.status, 'completed');
    expect((await SupabaseService.getQuizzes()).any((q) => q['title'] == 'Simulado Temporário IA'), isTrue);

    final delQuizRes = await NoesisAgentTools.executeTool(
      name: 'delete_quiz',
      args: {'title_match': 'Simulado Temporário IA'},
      userMessage: 'Exclua o simulado temporário IA',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    expect(delQuizRes.status, 'completed');
    expect((await SupabaseService.getQuizzes()).any((q) => q['title'] == 'Simulado Temporário IA'), isFalse);

    // Cleanup created notebook & roadmap
    await NoesisAgentTools.executeTool(
      name: 'delete_notebook_or_note',
      args: {'notebook_match': 'Caderno E2E Agente'},
      userMessage: 'Excluir caderno',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
    await NoesisAgentTools.executeTool(
      name: 'delete_roadmap',
      args: {'title_match': 'Cloud Native'},
      userMessage: 'Excluir trilha',
      generateQuiz: fakeQuiz,
      generateFlashcards: fakeCards,
      generateRoadmap: ({required subject, required goal, required level, required estimatedWeeks, focusNotes}) async {
        final rm = await GeminiService.generateStudyRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: estimatedWeeks,
          extraNotes: focusNotes,
        );
        return (title: rm.title, steps: rm.steps);
      },
    );
  });

  test('executeAgentChat executes noesis_action blocks returned by REST models and strips internal tags', () async {
    GeminiService.initialize('test-key');
    MockHttpOverrides.customResponseBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text':
                    'Caderno criado com sucesso!\n<noesis_action>{"action":"create_notebook_or_note","data":{"notebook_title":"Caderno REST","subject":"Redes","note_title":"BGP","note_content":"ASNs e roteamento entre domínios."}}</noesis_action>'
              }
            ]
          }
        }
      ]
    });

    final reply = await GeminiService.executeAgentChat(
      userMessage: 'Crie um caderno de Redes sobre BGP',
      history: [],
    );

    expect(reply, contains('Caderno criado com sucesso'));
    expect(reply, isNot(contains('<noesis_action>')));
    expect(GeminiService.lastExecutedActions.any((a) => a.name == 'create_notebook_or_note'), isTrue);
    final notebooks = await SupabaseService.getNotebooks();
    expect(notebooks.any((n) => n.title == 'Caderno REST'), isTrue);
  });

  testWidgets('AiAssistantScreen supports attaching files and internal Noesis items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    GeminiService.initialize('test-key');
    MockHttpOverrides.customResponseBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'Li seu arquivo e seu caderno com atenção!'}
            ]
          }
        }
      ]
    });

    await SupabaseService.saveNotebook(
      StudyNotebook(
        id: 'nb-attach-test',
        title: 'Resumo TLS 1.3',
        subject: 'Criptografia',
        description: 'Notas de handshake',
        notes: [
          StudyNote(
            id: 'note-1',
            notebookId: 'nb-attach-test',
            title: '0-RTT e PFS',
            content: 'Perfect Forward Secrecy com ECDHE',
            updatedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    AiAssistantScreen.filePickerOverrideForTesting = () async => [
          const NoesisAttachment(
            id: 'file:edital.txt',
            kind: 'file',
            title: 'edital.txt',
            subtitle: '2.1 KB · .txt',
            content: 'Conteúdo do edital sobre Segurança de Redes.',
          ),
        ];

    await TestAppHarness.pumpInHarness(tester, const AiAssistantScreen());
    await tester.pumpAndSettle();

    // 1. Anexa um arquivo local via botão de clipe
    await tester.tap(find.byKey(const Key('ai_attach_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_file_option')));
    await tester.pumpAndSettle();
    expect(find.text('Arquivo: edital.txt'), findsOneWidget);

    // 2. Anexa um Caderno interno do Noesis
    await tester.tap(find.byKey(const Key('ai_attach_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach_noesis_item_option')));
    await tester.pumpAndSettle();
    expect(find.text('Anexar Item do Noesis'), findsOneWidget);
    await tester.tap(find.text('Resumo TLS 1.3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anexar Selecionados'));
    await tester.pumpAndSettle();
    expect(find.text('Caderno: Resumo TLS 1.3'), findsOneWidget);

    // 3. Envia mensagem com os anexos
    await tester.enterText(find.byType(TextField), 'Revise esses materiais para mim');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Revise esses materiais para mim'), findsOneWidget);
    expect(find.text('Li seu arquivo e seu caderno com atenção!'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('AiAssistantScreen shows capabilities first and erases them as soon as the user types', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    GeminiService.initialize('configured-test-key');
    await TestAppHarness.pumpInHarness(tester, const AiAssistantScreen());
    await tester.pumpAndSettle();

    // Mostra as capacidades iniciais (sem mensagens simuladas antigas)
    expect(find.byKey(const Key('ai_capabilities_overview')), findsOneWidget);
    expect(find.text('O que o Noesis AI pode fazer por você'), findsOneWidget);
    expect(find.text('registra 1h30 de criptografia, estudei AES-GCM e nonce reuse'), findsNothing);

    // Sem botão de restaurar exemplo, sem ícone de chave e sem aviso quando configurada
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byKey(const Key('ai_api_key_button')), findsNothing);
    expect(find.byIcon(Icons.key_rounded), findsNothing);
    expect(find.byKey(const Key('ai_missing_key_notice')), findsNothing);

    // Quando a pessoa digita algo, as instruções iniciais são apagadas
    await tester.enterText(find.byType(TextField), 'Oi Noesis');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_capabilities_overview')), findsNothing);
    expect(find.text('O que o Noesis AI pode fazer por você'), findsNothing);

    // Ao clicar em Limpar conversa (lixeira), volta para a tela de capacidades
    await tester.tap(find.byKey(const Key('ai_clear_chat_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_capabilities_overview')), findsOneWidget);
    expect(find.text('O que o Noesis AI pode fazer por você'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('AiAssistantScreen replaces key icon/dialog with notice when no API key is configured', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    GeminiService.initialize('');
    await TestAppHarness.pumpInHarness(tester, const AiAssistantScreen());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_api_key_button')), findsNothing);
    expect(find.byIcon(Icons.key_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byKey(const Key('ai_missing_key_notice')), findsOneWidget);
    expect(find.text('Configure uma chave de IA para usar o assistente'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  test('buildContextualQuickSuggestions adapts chips to user sessions, notebooks, and pending flashcards', () async {
    await SupabaseService.addStudySession(
      subject: 'Segurança em Cloud',
      topic: 'IAM Least Privilege',
      durationMinutes: 45,
      studyDate: DateTime.now(),
    );

    final suggestions = await NoesisAgentTools.buildContextualQuickSuggestions();
    expect(suggestions, isNotEmpty);
    expect(suggestions.any((s) => s.id == 'session_followup' && s.label.contains('IAM Least Privilege')), isTrue);
    expect(suggestions.any((s) => s.id == 'flashcards_pending'), isTrue);
    expect(suggestions.any((s) => s.prompt.contains('IAM Least Privilege')), isTrue);
  });
}
