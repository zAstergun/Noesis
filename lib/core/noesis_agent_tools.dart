import 'dart:math' as math;
import '../features/flashcards/models/flashcard_model.dart';
import '../features/notebooks/models/notebook_model.dart';
import '../features/quizzes/data/saved_exams_repository.dart';
import '../features/roadmaps/data/roadmaps_repository.dart';
import '../features/roadmaps/models/roadmap_model.dart';
import 'localization/natural_date_keywords.dart';
import 'localization/noesis_l10n.dart';
import 'supabase_service.dart';

/// Item ou arquivo anexado pelo usuário para contextualizar o Noesis AI.
class NoesisAttachment {
  const NoesisAttachment({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.content,
  });

  final String id;

  /// 'file' | 'quiz' | 'notebook' | 'flashcard_deck' | 'roadmap' | 'study_log' | 'calendar'
  final String kind;
  final String title;
  final String subtitle;
  final String content;

  String get iconLabel {
    switch (kind) {
      case 'file':
        return NoesisL10n.tr('Arquivo');
      case 'quiz':
        return NoesisL10n.tr('Simulado');
      case 'notebook':
        return NoesisL10n.tr('Caderno');
      case 'flashcard_deck':
        return NoesisL10n.tr('Flashcards');
      case 'roadmap':
        return NoesisL10n.tr('Trilha');
      case 'study_log':
        return NoesisL10n.tr('Diário');
      case 'calendar':
        return NoesisL10n.tr('Calendário');
      default:
        return NoesisL10n.tr('Anexo');
    }
  }
}

class ExecutedToolResult {
  const ExecutedToolResult({
    required this.name,
    required this.parameters,
    required this.status,
    required this.summary,
    required this.responsePayload,
    this.data,
  });

  final String name;
  final Map<String, dynamic> parameters;
  final String status;
  final String summary;
  final Map<String, Object?> responsePayload;
  final Map<String, dynamic>? data;
}

/// Sugestão rápida contextual exibida acima do campo de mensagem no chat.
class NoesisQuickSuggestion {
  const NoesisQuickSuggestion({
    required this.id,
    required this.label,
    required this.prompt,
    this.tooltip,
  });

  final String id;
  final String label;
  final String prompt;
  final String? tooltip;
}

/// Recomendação proativa de bloco no Calendário baseada na agenda livre e na conta do usuário.
class CalendarAiRecommendation {
  const CalendarAiRecommendation({
    required this.id,
    required this.message,
    required this.eventTitle,
    required this.eventDescription,
    required this.category,
    required this.colorHex,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String message;
  final String eventTitle;
  final String eventDescription;
  final String category;
  final String colorHex;
  final DateTime startTime;
  final DateTime endTime;
}

typedef QuizGeneratorCallback = Future<List<Map<String, dynamic>>> Function({
  required String subject,
  required String topic,
  required int numberOfQuestions,
  required String difficulty,
  String? referenceContext,
});

typedef FlashcardsGeneratorCallback = Future<List<Map<String, dynamic>>> Function({
  required String subject,
  required String topic,
  required int count,
  String difficulty,
});

typedef RoadmapGeneratorCallback = Future<({String title, List<RoadmapStep> steps})> Function({
  required String subject,
  required String goal,
  required String level,
  required int estimatedWeeks,
  String? focusNotes,
});

class NoesisAgentTools {
  NoesisAgentTools._();

  /// Declarações de ferramentas compatíveis com a API REST v1beta do Google Gemini.
  static List<Map<String, dynamic>> get googleRestFunctionDeclarations => [
        {
          'name': 'inspect_account_data',
          'description': NoesisL10n.tr(
              'Lê e revisa itens reais da conta do usuário no Noesis (calendário, diário de estudos, simulados, flashcards, cadernos, trilhas e meta semanal). Use antes de responder perguntas sobre o que existe na conta ou quando precisar de IDs/conteúdos completos para revisar ou editar.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'scope': {
                'type': 'STRING',
                'description': NoesisL10n.tr(
                    'Escopo: all, calendar, sessions, quizzes, flashcards, notebooks, roadmaps, weekly_goal.'),
              },
              'search_query': {
                'type': 'STRING',
                'description': NoesisL10n.tr('Filtro opcional por título, matéria ou termo.'),
              },
            },
            'required': ['scope'],
          },
        },
        // ─── CALENDÁRIO ───
        {
          'name': 'schedule_calendar_event',
          'description': NoesisL10n.tr('Cria um novo evento, prova, revisão ou bloco de estudos no calendário.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING', 'description': NoesisL10n.tr('Título claro do evento ou prova.')},
              'start_time_iso': {
                'type': 'STRING',
                'description': NoesisL10n.tr('Data/hora de início em ISO 8601 local (ex: 2026-11-25T11:00:00).'),
              },
              'duration_minutes': {'type': 'INTEGER', 'description': NoesisL10n.tr('Duração em minutos (padrão 60).')},
              'category': {
                'type': 'STRING',
                'description': NoesisL10n.tr('Categoria: study, review, lab, exam, personal.'),
              },
              'description': {'type': 'STRING', 'description': NoesisL10n.tr('Observações do evento.')},
            },
            'required': ['title', 'start_time_iso'],
          },
        },
        {
          'name': 'update_calendar_event',
          'description': NoesisL10n.tr('Edita um evento existente no calendário (título, horário, duração, categoria ou conclusão).'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'event_id': {'type': 'STRING', 'description': NoesisL10n.tr('ID do evento (se conhecido).')},
              'title_match': {'type': 'STRING', 'description': NoesisL10n.tr('Parte do título do evento para localizar.')},
              'new_title': {'type': 'STRING', 'description': NoesisL10n.tr('Novo título (opcional).')},
              'start_time_iso': {'type': 'STRING', 'description': NoesisL10n.tr('Novo horário de início ISO 8601 (opcional).')},
              'duration_minutes': {'type': 'INTEGER', 'description': NoesisL10n.tr('Nova duração em minutos (opcional).')},
              'category': {'type': 'STRING', 'description': NoesisL10n.tr('Nova categoria (opcional).')},
              'description': {'type': 'STRING', 'description': NoesisL10n.tr('Nova descrição (opcional).')},
              'is_completed': {'type': 'BOOLEAN', 'description': NoesisL10n.tr('Marcar como concluído ou pendente.')},
            },
          },
        },
        {
          'name': 'delete_calendar_event',
          'description': NoesisL10n.tr('Remove um evento do calendário pelo ID ou título.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'event_id': {'type': 'STRING', 'description': NoesisL10n.tr('ID do evento.')},
              'title_match': {'type': 'STRING', 'description': NoesisL10n.tr('Parte do título do evento a remover.')},
            },
          },
        },
        // ─── DIÁRIO DE ESTUDOS / SESSÕES ───
        {
          'name': 'log_study_session',
          'description': NoesisL10n.tr('Registra uma sessão de estudo concluída no Diário de Estudos.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'subject': {'type': 'STRING', 'description': NoesisL10n.tr('Matéria estudada.')},
              'topic': {'type': 'STRING', 'description': NoesisL10n.tr('O que foi estudado.')},
              'duration_minutes': {'type': 'INTEGER', 'description': NoesisL10n.tr('Duração em minutos.')},
              'study_date_iso': {'type': 'STRING', 'description': NoesisL10n.tr('Data YYYY-MM-DD (opcional, padrão hoje).')},
              'notes': {'type': 'STRING', 'description': NoesisL10n.tr('Anotações opcionais.')},
            },
            'required': ['subject', 'topic', 'duration_minutes'],
          },
        },
        {
          'name': 'update_study_session',
          'description': NoesisL10n.tr('Edita um registro do Diário de Estudos.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'session_id': {'type': 'STRING'},
              'match_text': {'type': 'STRING', 'description': NoesisL10n.tr('Busca por matéria ou tópico.')},
              'subject': {'type': 'STRING'},
              'topic': {'type': 'STRING'},
              'duration_minutes': {'type': 'INTEGER'},
              'notes': {'type': 'STRING'},
            },
          },
        },
        {
          'name': 'delete_study_session',
          'description': NoesisL10n.tr('Exclui um registro do Diário de Estudos.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'session_id': {'type': 'STRING'},
              'match_text': {'type': 'STRING', 'description': NoesisL10n.tr('Matéria ou tópico do registro.')},
            },
          },
        },
        // ─── META SEMANAL E DIÁRIA ───
        {
          'name': 'set_weekly_goal',
          'description': NoesisL10n.tr('Define ou atualiza a meta semanal de estudos do usuário.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'hours': {'type': 'INTEGER', 'description': NoesisL10n.tr('Horas por semana.')},
              'minutes': {'type': 'INTEGER', 'description': NoesisL10n.tr('Minutos adicionais (0 a 59).')},
            },
            'required': ['hours'],
          },
        },
        {
          'name': 'set_daily_goal',
          'description': NoesisL10n.tr('Define ou atualiza a meta diária de estudos do usuário.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'hours': {'type': 'INTEGER', 'description': NoesisL10n.tr('Horas por dia.')},
              'minutes': {'type': 'INTEGER', 'description': NoesisL10n.tr('Minutos adicionais (0 a 59).')},
            },
            'required': ['hours'],
          },
        },
        // ─── SIMULADOS ───
        {
          'name': 'create_quiz',
          'description': NoesisL10n.tr('Cria um novo simulado com questões personalizadas.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING'},
              'subject': {'type': 'STRING'},
              'num_questions': {'type': 'INTEGER'},
              'difficulty': {'type': 'STRING'},
            },
            'required': ['title', 'subject'],
          },
        },
        {
          'name': 'delete_quiz',
          'description': NoesisL10n.tr('Remove um simulado salvo pelo ID ou título.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'quiz_id': {'type': 'STRING'},
              'title_match': {'type': 'STRING'},
            },
          },
        },
        // ─── FLASHCARDS ───
        {
          'name': 'create_flashcards',
          'description': NoesisL10n.tr('Cria um novo baralho de flashcards.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING'},
              'subject': {'type': 'STRING'},
              'topic': {'type': 'STRING'},
              'num_cards': {'type': 'INTEGER'},
            },
            'required': ['title', 'subject'],
          },
        },
        {
          'name': 'update_flashcard_deck',
          'description': NoesisL10n.tr(
              'Edita um baralho de flashcards existente: renomear, adicionar cartões ou remover cartões.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'deck_id': {'type': 'STRING'},
              'title_match': {'type': 'STRING'},
              'new_title': {'type': 'STRING'},
              'new_subject': {'type': 'STRING'},
              'new_description': {'type': 'STRING'},
              'add_cards': {
                'type': 'ARRAY',
                'items': {
                  'type': 'OBJECT',
                  'properties': {
                    'front': {'type': 'STRING'},
                    'back': {'type': 'STRING'},
                  },
                },
              },
              'remove_card_front_match': {'type': 'STRING'},
            },
          },
        },
        {
          'name': 'delete_flashcard_deck',
          'description': NoesisL10n.tr('Exclui um baralho de flashcards pelo ID ou título.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'deck_id': {'type': 'STRING'},
              'title_match': {'type': 'STRING'},
            },
          },
        },
        // ─── CADERNOS DE ESTUDO ───
        {
          'name': 'create_notebook_or_note',
          'description': NoesisL10n.tr(
              'Cria um novo caderno de estudos e/ou adiciona uma anotação dentro de um caderno.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'notebook_title': {'type': 'STRING', 'description': NoesisL10n.tr('Título do caderno.')},
              'subject': {'type': 'STRING', 'description': NoesisL10n.tr('Disciplina do caderno.')},
              'description': {'type': 'STRING', 'description': NoesisL10n.tr('Descrição do caderno (opcional).')},
              'note_title': {'type': 'STRING', 'description': NoesisL10n.tr('Título da anotação (opcional).')},
              'note_content': {'type': 'STRING', 'description': NoesisL10n.tr('Conteúdo Markdown da anotação.')},
              'tags': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
              },
              'needs_review': {'type': 'BOOLEAN', 'description': NoesisL10n.tr('Se deve marcar a anotação para revisão.')},
            },
            'required': ['notebook_title'],
          },
        },
        {
          'name': 'update_notebook_or_note',
          'description': NoesisL10n.tr(
              'Edita um caderno ou uma anotação existente (título, conteúdo, tags ou marcação de revisão).'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'notebook_id': {'type': 'STRING'},
              'notebook_match': {'type': 'STRING'},
              'new_notebook_title': {'type': 'STRING'},
              'new_subject': {'type': 'STRING'},
              'note_id': {'type': 'STRING'},
              'note_match': {'type': 'STRING'},
              'new_note_title': {'type': 'STRING'},
              'new_note_content': {'type': 'STRING'},
              'needs_review': {'type': 'BOOLEAN'},
              'mark_reviewed': {'type': 'BOOLEAN'},
            },
          },
        },
        {
          'name': 'delete_notebook_or_note',
          'description': NoesisL10n.tr('Exclui uma anotação específica ou um caderno inteiro.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'notebook_id': {'type': 'STRING'},
              'notebook_match': {'type': 'STRING'},
              'note_id': {'type': 'STRING'},
              'note_match': {'type': 'STRING'},
            },
          },
        },
        // ─── TRILHAS (ROADMAPS) ───
        {
          'name': 'create_roadmap',
          'description': NoesisL10n.tr('Cria uma nova trilha de estudos (roadmap) com etapas detalhadas.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING'},
              'subject': {'type': 'STRING'},
              'goal': {'type': 'STRING'},
              'level': {'type': 'STRING'},
              'estimated_weeks': {'type': 'INTEGER'},
            },
            'required': ['subject', 'goal'],
          },
        },
        {
          'name': 'update_roadmap',
          'description': NoesisL10n.tr(
              'Edita uma trilha (roadmap): alterar título/objetivo, adicionar etapa, marcar etapa como concluída/em andamento ou remover etapa.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'roadmap_id': {'type': 'STRING'},
              'title_match': {'type': 'STRING'},
              'new_title': {'type': 'STRING'},
              'new_goal': {'type': 'STRING'},
              'add_step_title': {'type': 'STRING'},
              'add_step_description': {'type': 'STRING'},
              'step_match': {'type': 'STRING', 'description': NoesisL10n.tr('Título da etapa para atualizar status/excluir.')},
              'step_status': {'type': 'STRING', 'description': NoesisL10n.tr('todo, doing ou done.')},
              'remove_step': {'type': 'BOOLEAN'},
            },
          },
        },
        {
          'name': 'delete_roadmap',
          'description': NoesisL10n.tr('Exclui uma trilha (roadmap) pelo ID ou título.'),
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'roadmap_id': {'type': 'STRING'},
              'title_match': {'type': 'STRING'},
            },
          },
        },
      ];

  /// Resume todos os itens atuais da conta do usuário para dar contexto real ao agente.
  static Future<String> buildAccountSnapshotText() async {
    final sessions = await SupabaseService.getStudySessions(limit: 25);
    final events = await SupabaseService.getCalendarEvents();
    final exams = await SavedExamsRepository.loadAll();
    final generatedQuizzes = await SupabaseService.getQuizzes();
    final decks = await SupabaseService.getFlashcardDecks();
    final notebooks = await SupabaseService.getNotebooks();
    final roadmaps = await RoadmapsRepository.loadAll();
    final weeklyGoal = await SupabaseService.loadWeeklyGoalMinutes();
    final weekStudied = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);

    final buf = StringBuffer();
    buf.writeln(NoesisL10n.tr('=== CONTEXTO REAL DA CONTA NO NOESIS ==='));
    buf.writeln(
      NoesisL10n.tr(
        'Meta semanal: {studied} estudados nesta semana / meta de {goal}.',
        {
          'studied': SupabaseService.formatGoalDuration(weekStudied),
          'goal': SupabaseService.formatGoalDuration(weeklyGoal),
        },
      ),
    );

    buf.writeln(NoesisL10n.tr('\n[Calendário: {count} eventos]', {'count': events.length}));
    for (final e in events.take(15)) {
      buf.writeln(
        NoesisL10n.tr(
          '- "{title}" ({category}) · início={start} · concluído={done}',
          {
            'title': e['title'],
            'category': e['category'] ?? 'study',
            'start': e['start_time'],
            'done': e['is_completed'] == true,
          },
        ),
      );
    }

    buf.writeln(NoesisL10n.tr('\n[Diário de Estudos: {count} sessões recentes]', {'count': sessions.length}));
    for (final s in sessions.take(12)) {
      buf.writeln(
        '- ${s['study_date']} · ${s['subject']}: "${s['topic']}" (${s['duration_minutes']} min)',
      );
    }

    buf.writeln(NoesisL10n.tr('\n[Simulados salvos: {count}]', {'count': exams.length + generatedQuizzes.length}));
    for (final ex in exams.take(10)) {
      buf.writeln(
        NoesisL10n.tr(
          '- "{title}" ({subject}) · {pct}% ({correct}/{total} acertos)',
          {
            'title': ex.title,
            'subject': ex.subject,
            'pct': ex.scorePercentage.round(),
            'correct': ex.correctCount,
            'total': ex.loadedCount,
          },
        ),
      );
    }
    for (final q in generatedQuizzes.take(8)) {
      final qList = (q['questions_data'] as List?) ?? [];
      buf.writeln(
        NoesisL10n.tr(
          '- "{title}" ({subject}) · {count} questões (gerado)',
          {
            'title': q['title'],
            'subject': q['subject'] ?? NoesisL10n.tr('Geral'),
            'count': qList.length,
          },
        ),
      );
    }

    buf.writeln(NoesisL10n.tr('\n[Flashcards: {count} baralhos]', {'count': decks.length}));
    for (final d in decks.take(12)) {
      buf.writeln(
        NoesisL10n.tr(
          '- "{title}" ({subject}) · {cards} cartões ({pending} p/ revisar)',
          {
            'title': d.title,
            'subject': d.subject,
            'cards': d.cardCount,
            'pending': d.pendingReviewCount(),
          },
        ),
      );
    }

    buf.writeln(NoesisL10n.tr('\n[Cadernos: {count}]', {'count': notebooks.length}));
    for (final nb in notebooks.take(12)) {
      final noteTitles = nb.notes.take(5).map((n) {
        final flag = n.needsReview ? NoesisL10n.tr(' [revisar]') : '';
        return '"${n.title}"$flag';
      }).join(', ');
      buf.writeln(
        NoesisL10n.tr(
          '- "{title}" ({subject}, {count} notas): {notes}',
          {
            'title': nb.title,
            'subject': nb.subject,
            'count': nb.noteCount,
            'notes': noteTitles,
          },
        ),
      );
    }

    buf.writeln(NoesisL10n.tr('\n[Trilhas: {count}]', {'count': roadmaps.length}));
    for (final rm in roadmaps.take(10)) {
      final pct = (rm.progress * 100).round();
      buf.writeln(
        NoesisL10n.tr(
          '- "{title}" ({subject}) · {pct}% · {count} etapas',
          {
            'title': rm.title,
            'subject': rm.subject,
            'pct': pct,
            'count': rm.steps.length,
          },
        ),
      );
    }

    return buf.toString();
  }

  /// Lista itens internos do Noesis prontos para serem anexados manualmente no chat.
  static Future<List<NoesisAttachment>> listAttachableItems() async {
    final results = await Future.wait<dynamic>([
      SavedExamsRepository.loadAll(),
      SupabaseService.getQuizzes(),
      SupabaseService.getNotebooks(),
      SupabaseService.getFlashcardDecks(),
      RoadmapsRepository.loadAll(),
    ]);

    final exams = results[0] as List<SavedExamAttempt>;
    final generatedQuizzes = results[1] as List<Map<String, dynamic>>;
    final notebooks = results[2] as List<StudyNotebook>;
    final decks = results[3] as List<FlashcardDeck>;
    final roadmaps = results[4] as List<StudyRoadmap>;

    final list = <NoesisAttachment>[];

    for (final ex in exams) {
      final qBuf = StringBuffer()
        ..writeln(NoesisL10n.tr('Simulado: {title} | Matéria: {subject} | Nota: {score}%', {
          'title': ex.title,
          'subject': ex.subject,
          'score': ex.scorePercentage.round(),
        }))
        ..writeln(NoesisL10n.tr('Acertos: {correct} | Erros: {wrong} | Em branco: {blank}', {
          'correct': ex.correctCount,
          'wrong': ex.wrongCount,
          'blank': ex.blankCount,
        }));
      for (int i = 0; i < math.min(12, ex.questions.length); i++) {
        final q = ex.questions[i];
        final userAns = ex.userAnswers[i];
        final rightIdx = q['correct_index'] as int? ?? 0;
        final status = userAns == null
            ? NoesisL10n.tr('Em branco')
            : (userAns == rightIdx ? NoesisL10n.tr('Correta') : NoesisL10n.tr('Errada'));
        qBuf.writeln('Q${i + 1} [$status]: ${q['question'] ?? ''}');
      }
      list.add(
        NoesisAttachment(
          id: 'quiz:${ex.id}',
          kind: 'quiz',
          title: ex.title,
          subtitle: NoesisL10n.tr(
            '{subject} · {pct}% ({count} questões)',
            {'subject': ex.subject, 'pct': ex.scorePercentage.round(), 'count': ex.loadedCount},
          ),
          content: qBuf.toString(),
        ),
      );
    }

    for (final q in generatedQuizzes) {
      final qId = q['id']?.toString() ?? q['title']?.toString() ?? '';
      final title = q['title']?.toString() ?? NoesisL10n.tr('Simulado Noesis');
      final subject = q['subject']?.toString() ?? NoesisL10n.tr('Geral');
      final qs = (q['questions_data'] as List?) ?? [];
      final qBuf = StringBuffer()
        ..writeln(NoesisL10n.tr('Simulado gerado: {title} | Matéria: {subject} | Questões: {count}', {
          'title': title,
          'subject': subject,
          'count': qs.length,
        }));
      for (int i = 0; i < math.min(12, qs.length); i++) {
        final item = qs[i];
        if (item is Map) {
          qBuf.writeln('Q${i + 1}: ${item['question'] ?? ''}');
        }
      }
      list.add(
        NoesisAttachment(
          id: 'genquiz:$qId',
          kind: 'quiz',
          title: title,
          subtitle: NoesisL10n.tr(
            '{subject} · {count} questões (gerado)',
            {'subject': subject, 'count': qs.length},
          ),
          content: qBuf.toString(),
        ),
      );
    }

    for (final nb in notebooks) {
      final nBuf = StringBuffer()
        ..writeln(NoesisL10n.tr('Caderno: {title} | Disciplina: {subject}', {
          'title': nb.title,
          'subject': nb.subject,
        }))
        ..writeln(NoesisL10n.tr('Descrição: {desc}', {'desc': nb.description}));
      for (final note in nb.notes) {
        nBuf.writeln(NoesisL10n.tr('\n--- Anotação: {title} (revisar={review}) ---', {
          'title': note.title,
          'review': note.needsReview,
        }));
        if (note.tags.isNotEmpty) nBuf.writeln('Tags: ${note.tags.join(', ')}');
        nBuf.writeln(note.content);
      }
      list.add(
        NoesisAttachment(
          id: 'notebook:${nb.id}',
          kind: 'notebook',
          title: nb.title,
          subtitle: NoesisL10n.tr(
            '{subject} · {count} anotações',
            {'subject': nb.subject, 'count': nb.noteCount},
          ),
          content: nBuf.toString(),
        ),
      );
    }

    for (final deck in decks) {
      final dBuf = StringBuffer()
        ..writeln(NoesisL10n.tr('Baralho: {title} | Matéria: {subject}', {
          'title': deck.title,
          'subject': deck.subject,
        }))
        ..writeln(NoesisL10n.tr('Cartões ({total}, {pending} p/ revisar):', {
          'total': deck.cardCount,
          'pending': deck.pendingReviewCount(),
        }));
      for (final c in deck.cards.take(25)) {
        dBuf.writeln('- [${c.difficulty}] ${NoesisL10n.tr('P: {front} | R: {back}', {'front': c.front, 'back': c.back})}');
      }
      list.add(
        NoesisAttachment(
          id: 'deck:${deck.id}',
          kind: 'flashcard_deck',
          title: deck.title,
          subtitle: NoesisL10n.tr(
            '{subject} · {count} cartões',
            {'subject': deck.subject, 'count': deck.cardCount},
          ),
          content: dBuf.toString(),
        ),
      );
    }

    for (final rm in roadmaps) {
      final rBuf = StringBuffer()
        ..writeln(NoesisL10n.tr('Trilha: {title} | Disciplina: {subject} | Objetivo: {goal}', {
          'title': rm.title,
          'subject': rm.subject,
          'goal': rm.goal,
        }));
      for (final st in rm.steps) {
        rBuf.writeln('- [${st.status.label}] ${st.title} (${st.estimatedHours}h): ${st.description}');
      }
      list.add(
        NoesisAttachment(
          id: 'roadmap:${rm.id}',
          kind: 'roadmap',
          title: rm.title,
          subtitle: NoesisL10n.tr(
            '{subject} · {pct}% · {count} etapas',
            {'subject': rm.subject, 'pct': (rm.progress * 100).round(), 'count': rm.steps.length},
          ),
          content: rBuf.toString(),
        ),
      );
    }

    return list;
  }

  /// Gera sugestões rápidas dinâmicas baseadas no histórico e pendências reais do usuário no Noesis.
  static Future<List<NoesisQuickSuggestion>> buildContextualQuickSuggestions() async {
    String shorten(String raw, [int maxLen = 22]) {
      final clean = raw.trim();
      if (clean.length <= maxLen) return clean;
      return '${clean.substring(0, maxLen - 1)}…';
    }

    final results = await Future.wait<dynamic>([
      SupabaseService.getFlashcardDecks(),
      SupabaseService.getNotebooks(),
      SavedExamsRepository.loadAll(),
      SupabaseService.getStudySessions(limit: 10),
      SupabaseService.getCalendarEvents(),
      RoadmapsRepository.loadAll(),
      SupabaseService.loadWeeklyGoalMinutes(),
    ]);

    final decks = results[0] as List<FlashcardDeck>;
    final notebooks = results[1] as List<StudyNotebook>;
    final exams = results[2] as List<SavedExamAttempt>;
    final sessions = results[3] as List<Map<String, dynamic>>;
    final events = results[4] as List<Map<String, dynamic>>;
    final roadmaps = results[5] as List<StudyRoadmap>;
    final weeklyGoal = results[6] as int;
    final weekStudied = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);

    final suggestions = <NoesisQuickSuggestion>[];

    // 1. Flashcards pendentes para revisar agora
    final pendingDecks = decks.where((d) => d.pendingReviewCount() > 0).toList()
      ..sort((a, b) => b.pendingReviewCount().compareTo(a.pendingReviewCount()));
    if (pendingDecks.isNotEmpty) {
      final topDeck = pendingDecks.first;
      final pending = topDeck.pendingReviewCount();
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'flashcards_pending',
          label: NoesisL10n.tr(
            '🎴 Revisar {title} ({count})',
            {'title': shorten(topDeck.title, 18), 'count': pending},
          ),
          prompt: NoesisL10n.tr(
            'Analise os {count} cartões pendentes do meu baralho "{title}" ({subject}) e me ajude a praticar com perguntas de active recall.',
            {'count': pending, 'title': topDeck.title, 'subject': topDeck.subject},
          ),
          tooltip: NoesisL10n.tr(
            'Baseado nos seus flashcards pendentes em {subject}',
            {'subject': topDeck.subject},
          ),
        ),
      );
    }

    // 2. Anotação marcada como "Precisa revisar" em Cadernos
    StudyNotebook? targetNb;
    StudyNote? targetNote;
    for (final nb in notebooks) {
      for (final note in nb.notes) {
        if (note.needsReview) {
          targetNb = nb;
          targetNote = note;
          break;
        }
      }
      if (targetNote != null) break;
    }
    if (targetNote != null && targetNb != null) {
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'notebook_review',
          label: NoesisL10n.tr('📓 Revisar nota: {title}', {'title': shorten(targetNote.title, 18)}),
          prompt: NoesisL10n.tr(
            'Leia minha anotação "{note}" no caderno "{notebook}" ({subject}), explique os pontos-chave e crie perguntas para revisão.',
            {'note': targetNote.title, 'notebook': targetNb.title, 'subject': targetNb.subject},
          ),
          tooltip: NoesisL10n.tr(
            'Anotação marcada para revisão no caderno {notebook}',
            {'notebook': targetNb.title},
          ),
        ),
      );
    }

    // 3. Reforçar pontos fracos do último simulado / menor nota
    if (exams.isNotEmpty) {
      final weakExams = exams.where((e) => e.wrongCount > 0 || e.scorePercentage < 85).toList()
        ..sort((a, b) => a.scorePercentage.compareTo(b.scorePercentage));
      final exam = weakExams.isNotEmpty ? weakExams.first : exams.first;
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'quiz_reinforce',
          label: NoesisL10n.tr(
            '📝 Reforçar {subject} ({pct}%)',
            {'subject': shorten(exam.subject, 16), 'pct': exam.scorePercentage.round()},
          ),
          prompt: NoesisL10n.tr(
            'Analise meus erros no simulado "{title}" ({pct}% de acerto em {subject}) e gere um simulado de reforço focado nessas lacunas.',
            {'title': exam.title, 'pct': exam.scorePercentage.round(), 'subject': exam.subject},
          ),
          tooltip: NoesisL10n.tr('Baseado no desempenho do simulado {title}', {'title': exam.title}),
        ),
      );
    }

    // 4. Continuidade da última sessão registrada no Diário de Estudos
    if (sessions.isNotEmpty) {
      final latest = sessions.first;
      final subj = (latest['subject'] ?? NoesisL10n.tr('Estudos')).toString().trim();
      final topic = (latest['topic'] ?? '').toString().trim();
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'session_followup',
          label: NoesisL10n.tr('⏱️ Fixar {topic}', {'topic': shorten(topic.isNotEmpty ? topic : subj, 20)}),
          prompt: NoesisL10n.tr(
            'Com base no que estudei por último ({context}), faça um resumo prático e agende uma revisão espaçada no calendário.',
            {'context': '$subj${topic.isNotEmpty ? ' · $topic' : ''}'},
          ),
          tooltip: NoesisL10n.tr('Baseado na sua última sessão registrada no Diário'),
        ),
      );
    }

    // 5. Próximo evento futuro / prova no Calendário
    final now = DateTime.now();
    final upcomingEvents = events.where((e) {
      if (e['is_completed'] == true) return false;
      final dt = DateTime.tryParse(e['start_time']?.toString() ?? '');
      return dt != null && dt.isAfter(now.subtract(const Duration(hours: 2)));
    }).toList()
      ..sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));
    if (upcomingEvents.isNotEmpty) {
      final ev = upcomingEvents.first;
      final title = (ev['title'] ?? NoesisL10n.tr('Compromisso')).toString();
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'calendar_prep',
          label: NoesisL10n.tr('📅 Preparar p/ {title}', {'title': shorten(title, 18)}),
          prompt: NoesisL10n.tr(
            'Tenho "{title}" agendado no calendário. Monte um roteiro objetivo de revisão para chegar preparado.',
            {'title': ev['title']},
          ),
          tooltip: NoesisL10n.tr('Baseado no seu próximo evento do Calendário'),
        ),
      );
    }

    // 6. Próxima etapa da Trilha de Estudos em andamento
    for (final rm in roadmaps) {
      final nextStep = rm.steps.where((s) => s.status != RoadmapStepStatus.done).firstOrNull;
      if (nextStep != null) {
        suggestions.add(
          NoesisQuickSuggestion(
            id: 'roadmap_next',
            label: NoesisL10n.tr('🗺️ Avançar: {step}', {'step': shorten(nextStep.title, 18)}),
            prompt: NoesisL10n.tr(
              'Na minha trilha "{roadmap}", me guie pela próxima etapa "{step}" com resumo e exercício prático.',
              {'roadmap': rm.title, 'step': nextStep.title},
            ),
            tooltip: NoesisL10n.tr('Próxima etapa pendente em {roadmap}', {'roadmap': rm.title}),
          ),
        );
        break;
      }
    }

    // 7. Meta semanal restante
    if (weeklyGoal > weekStudied) {
      final remaining = weeklyGoal - weekStudied;
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'weekly_goal_gap',
          label: NoesisL10n.tr(
            '🎯 Bater meta (faltam {remaining})',
            {'remaining': SupabaseService.formatGoalDuration(remaining)},
          ),
          prompt: NoesisL10n.tr(
            'Ainda faltam {remaining} para minha meta semanal de {goal}. Analise minha semana e agende blocos de estudo.',
            {
              'remaining': SupabaseService.formatGoalDuration(remaining),
              'goal': SupabaseService.formatGoalDuration(weeklyGoal),
            },
          ),
          tooltip: NoesisL10n.tr('Calculado com base no seu progresso semanal real'),
        ),
      );
    }

    // Fallbacks caso haja poucos dados cadastrados na conta
    final fallbacks = [
      NoesisQuickSuggestion(
        id: 'fallback_overview',
        label: NoesisL10n.tr('✨ Plano de estudo de hoje'),
        prompt: NoesisL10n.tr('Leia tudo o que tenho na minha conta e monte um plano objetivo para hoje.'),
      ),
      NoesisQuickSuggestion(
        id: 'fallback_quiz',
        label: NoesisL10n.tr('📝 Criar simulado diagnóstico'),
        prompt: NoesisL10n.tr('Crie um simulado de 5 questões para testar meu nível atual em Segurança e Redes.'),
      ),
      NoesisQuickSuggestion(
        id: 'fallback_calendar',
        label: NoesisL10n.tr('📅 Agendar bloco de revisão'),
        prompt: NoesisL10n.tr('Agende uma revisão de 1h no calendário para hoje às 19h.'),
      ),
    ];

    for (final fb in fallbacks) {
      if (suggestions.length >= 5) break;
      if (!suggestions.any((s) => s.id == fb.id)) {
        suggestions.add(fb);
      }
    }

    return suggestions.take(6).toList();
  }

  /// Gera recomendações proativas para o Calendário cruzando horários livres reais e prioridades da conta.
  static Future<List<CalendarAiRecommendation>> buildCalendarRecommendations({
    List<Map<String, dynamic>>? calendarEvents,
    DateTime? now,
  }) async {
    final base = now ?? DateTime.now();
    final results = await Future.wait<dynamic>([
      calendarEvents != null ? Future.value(calendarEvents) : SupabaseService.getCalendarEvents(),
      SupabaseService.getFlashcardDecks(),
      SupabaseService.getNotebooks(),
      SavedExamsRepository.loadAll(),
      SupabaseService.getStudySessions(limit: 12),
      RoadmapsRepository.loadAll(),
      SupabaseService.loadWeeklyGoalMinutes(),
    ]);

    final events = (results[0] as List).cast<Map<String, dynamic>>();
    final decks = results[1] as List<FlashcardDeck>;
    final notebooks = results[2] as List<StudyNotebook>;
    final exams = results[3] as List<SavedExamAttempt>;
    final sessions = results[4] as List<Map<String, dynamic>>;
    final roadmaps = results[5] as List<StudyRoadmap>;
    final weeklyGoal = results[6] as int;
    final weekStudied = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);

    final busyRanges = <({DateTime start, DateTime end})>[];
    for (final ev in events) {
      final st = DateTime.tryParse(ev['start_time']?.toString() ?? '');
      if (st == null) continue;
      final en = DateTime.tryParse(ev['end_time']?.toString() ?? '') ?? st.add(const Duration(minutes: 60));
      busyRanges.add((start: st, end: en));
    }

    ({DateTime start, DateTime end})? findFreeSlot(
      int durationMinutes, {
      DateTime? beforeDeadline,
      Set<String>? avoidStartKeys,
    }) {
      const preferredHours = [15, 10, 19, 14, 16, 9, 17, 20, 8, 11, 13, 18];
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final day = DateTime(base.year, base.month, base.day).add(Duration(days: dayOffset));
        for (final h in preferredHours) {
          if (dayOffset == 0 && h <= base.hour) continue;
          final candStart = DateTime(day.year, day.month, day.day, h, 0);
          final candEnd = candStart.add(Duration(minutes: durationMinutes));
          if (beforeDeadline != null && !candEnd.isBefore(beforeDeadline)) continue;
          final key = '${candStart.year}-${candStart.month}-${candStart.day}-$h';
          if (avoidStartKeys != null && avoidStartKeys.contains(key)) continue;

          final hasOverlap = busyRanges.any(
            (b) => b.start.isBefore(candEnd) && b.end.isAfter(candStart),
          );
          if (!hasOverlap) {
            return (start: candStart, end: candEnd);
          }
        }
      }
      final fallbackStart = DateTime(base.year, base.month, base.day, 19, 0).add(const Duration(days: 1));
      return (start: fallbackStart, end: fallbackStart.add(Duration(minutes: durationMinutes)));
    }

    String dayLabel(DateTime dt) {
      final today = DateTime(base.year, base.month, base.day);
      final target = DateTime(dt.year, dt.month, dt.day);
      final diff = target.difference(today).inDays;
      if (diff == 0) return NoesisL10n.tr('Hoje');
      if (diff == 1) return NoesisL10n.tr('Amanhã');
      final names = [
        NoesisL10n.tr('Segunda'),
        NoesisL10n.tr('Terça'),
        NoesisL10n.tr('Quarta'),
        NoesisL10n.tr('Quinta'),
        NoesisL10n.tr('Sexta'),
        NoesisL10n.tr('Sábado'),
        NoesisL10n.tr('Domingo'),
      ];
      return names[(dt.weekday - 1) % 7];
    }

    String windowText(DateTime st, DateTime en) {
      String fmt(DateTime d) => d.minute == 0
          ? '${d.hour}h'
          : '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
      return NoesisL10n.tr('das {start} às {end}', {'start': fmt(st), 'end': fmt(en)});
    }

    String durationLabel(int minutes) {
      if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60}h';
      if (minutes >= 60) return '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
      return '${minutes}min';
    }

    final recommendations = <CalendarAiRecommendation>[];
    final usedKeys = <String>{};

    void markUsed(DateTime st) {
      usedKeys.add('${st.year}-${st.month}-${st.day}-${st.hour}');
    }

    // 1. Próxima prova/simulado no Calendário -> bloco livre ANTES do evento
    final upcomingExams = events.where((e) {
      if (e['is_completed'] == true) return false;
      final st = DateTime.tryParse(e['start_time']?.toString() ?? '');
      if (st == null || !st.isAfter(base.add(const Duration(hours: 2)))) return false;
      final cat = (e['category'] ?? '').toString().toLowerCase();
      final title = (e['title'] ?? '').toString().toLowerCase();
      return cat == 'exam' || title.contains('prova') || title.contains('exame') || title.contains('certifica');
    }).toList()
      ..sort((a, b) => a['start_time'].toString().compareTo(b['start_time'].toString()));

    if (upcomingExams.isNotEmpty) {
      final examEv = upcomingExams.first;
      final examTitle = (examEv['title'] ?? NoesisL10n.tr('Prova')).toString();
      final examStart = DateTime.parse(examEv['start_time'].toString());
      final slot = findFreeSlot(120, beforeDeadline: examStart, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_exam_prep',
            message: NoesisL10n.tr(
              '{day} está livre {window}. Quer um bloco de {duration} de revisão antes de "{exam}"?',
              {
                'day': dayLabel(slot.start),
                'window': windowText(slot.start, slot.end),
                'duration': durationLabel(120),
                'exam': examTitle,
              },
            ),
            eventTitle: NoesisL10n.tr('Revisão p/ {exam}', {'exam': examTitle}),
            eventDescription: NoesisL10n.tr(
              'Bloco preparatório sugerido pelo Noesis AI antes do evento "{exam}".',
              {'exam': examTitle},
            ),
            category: 'review',
            colorHex: '#3CCF9A',
            startTime: slot.start,
            endTime: slot.end,
          ),
        );
      }
    }

    // 2. Simulado com erros / menor desempenho
    if (exams.isNotEmpty) {
      final weak = exams.where((e) => e.wrongCount > 0 || e.scorePercentage < 85).toList()
        ..sort((a, b) => a.scorePercentage.compareTo(b.scorePercentage));
      final targetExam = weak.isNotEmpty ? weak.first : exams.first;
      final slot = findFreeSlot(90, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_quiz_reinforce',
            message: NoesisL10n.tr(
              'Você marcou {pct}% em {subject}. {day} está livre {window} — quer agendar {duration} de reforço?',
              {
                'pct': targetExam.scorePercentage.round(),
                'subject': targetExam.subject,
                'day': dayLabel(slot.start),
                'window': windowText(slot.start, slot.end),
                'duration': durationLabel(90),
              },
            ),
            eventTitle: NoesisL10n.tr('Reforço · {subject}', {'subject': targetExam.subject}),
            eventDescription: NoesisL10n.tr(
              'Revisão direcionada dos erros do simulado "{title}" ({pct}%).',
              {'title': targetExam.title, 'pct': targetExam.scorePercentage.round()},
            ),
            category: 'lab',
            colorHex: '#F5A623',
            startTime: slot.start,
            endTime: slot.end,
          ),
        );
      }
    }

    // 3. Flashcards pendentes para revisão espaçada
    final pendingDecks = decks.where((d) => d.pendingReviewCount() > 0).toList()
      ..sort((a, b) => b.pendingReviewCount().compareTo(a.pendingReviewCount()));
    if (pendingDecks.isNotEmpty) {
      final topDeck = pendingDecks.first;
      final pending = topDeck.pendingReviewCount();
      final slot = findFreeSlot(60, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_flashcards_due',
            message: NoesisL10n.tr(
              'Há {count} flashcards pendentes em "{title}". {day} está livre {window} — quer reservar {duration} de active recall?',
              {
                'count': pending,
                'title': topDeck.title,
                'day': dayLabel(slot.start),
                'window': windowText(slot.start, slot.end),
                'duration': durationLabel(60),
              },
            ),
            eventTitle: NoesisL10n.tr('Flashcards · {subject}', {'subject': topDeck.subject}),
            eventDescription: NoesisL10n.tr(
              'Revisão espaçada dos {count} cartões pendentes de "{title}".',
              {'count': pending, 'title': topDeck.title},
            ),
            category: 'review',
            colorHex: '#3CCF9A',
            startTime: slot.start,
            endTime: slot.end,
          ),
        );
      }
    }

    // 4. Anotação de Caderno marcada com needsReview
    StudyNotebook? revNb;
    StudyNote? revNote;
    for (final nb in notebooks) {
      for (final n in nb.notes) {
        if (n.needsReview) {
          revNb = nb;
          revNote = n;
          break;
        }
      }
      if (revNote != null) break;
    }
    if (revNb != null && revNote != null) {
      final slot = findFreeSlot(60, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_notebook_review',
            message: NoesisL10n.tr(
              'Sua nota "{note}" ({subject}) está marcada para revisão. {day} está livre {window} — quer agendar {duration}?',
              {
                'note': revNote.title,
                'subject': revNb.subject,
                'day': dayLabel(slot.start),
                'window': windowText(slot.start, slot.end),
                'duration': durationLabel(60),
              },
            ),
            eventTitle: NoesisL10n.tr('Revisar Nota · {note}', {'note': revNote.title}),
            eventDescription: NoesisL10n.tr(
              'Revisão do caderno "{notebook}" ({subject}).',
              {'notebook': revNb.title, 'subject': revNb.subject},
            ),
            category: 'review',
            colorHex: '#3CCF9A',
            startTime: slot.start,
            endTime: slot.end,
          ),
        );
      }
    }

    // 5. Meta semanal restante + última disciplina estudada
    if (weeklyGoal > weekStudied || sessions.isNotEmpty) {
      final lastSubject = sessions.isNotEmpty
          ? (sessions.first['subject'] ?? NoesisL10n.tr('Estudos')).toString()
          : NoesisL10n.tr('Estudos');
      final remaining = weeklyGoal > weekStudied ? weeklyGoal - weekStudied : 120;
      final dur = remaining >= 120 ? 120 : (remaining >= 60 ? 60 : 60);
      final slot = findFreeSlot(dur, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        final msg = weeklyGoal > weekStudied
            ? NoesisL10n.tr(
                'Faltam {remaining} para sua meta semanal (último foco: {subject}). {day} está livre {window} — quer um bloco de {duration}?',
                {
                  'remaining': SupabaseService.formatGoalDuration(remaining),
                  'subject': lastSubject,
                  'day': dayLabel(slot.start),
                  'window': windowText(slot.start, slot.end),
                  'duration': durationLabel(dur),
                },
              )
            : NoesisL10n.tr(
                'Para manter seu ritmo em {subject}, {day} está livre {window}. Quer um bloco de {duration}?',
                {
                  'subject': lastSubject,
                  'day': dayLabel(slot.start),
                  'window': windowText(slot.start, slot.end),
                  'duration': durationLabel(dur),
                },
              );
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_weekly_goal',
            message: msg,
            eventTitle: NoesisL10n.tr('Estudo · {subject}', {'subject': lastSubject}),
            eventDescription: NoesisL10n.tr('Bloco planejado pelo Noesis AI para impulsionar sua meta semanal.'),
            category: 'study',
            colorHex: '#7C6CF0',
            startTime: slot.start,
            endTime: slot.end,
          ),
        );
      }
    }

    // 6. Próxima etapa pendente de Trilha
    for (final rm in roadmaps) {
      final nextStep = rm.steps.where((s) => s.status != RoadmapStepStatus.done).firstOrNull;
      if (nextStep != null) {
        final slot = findFreeSlot(90, avoidStartKeys: usedKeys);
        if (slot != null) {
          markUsed(slot.start);
          recommendations.add(
            CalendarAiRecommendation(
              id: 'cal_roadmap_step',
              message: NoesisL10n.tr(
                'Na trilha "{roadmap}", falta a etapa "{step}". {day} está livre {window} — quer reservar {duration}?',
                {
                  'roadmap': rm.title,
                  'step': nextStep.title,
                  'day': dayLabel(slot.start),
                  'window': windowText(slot.start, slot.end),
                  'duration': durationLabel(90),
                },
              ),
              eventTitle: NoesisL10n.tr('Trilha · {step}', {'step': nextStep.title}),
              eventDescription: NoesisL10n.tr(
                'Etapa da trilha "{roadmap}" ({subject}).',
                {'roadmap': rm.title, 'subject': rm.subject},
              ),
              category: 'study',
              colorHex: '#7C6CF0',
              startTime: slot.start,
              endTime: slot.end,
            ),
          );
        }
        break;
      }
    }

    if (recommendations.isEmpty) {
      final slot = findFreeSlot(90)!;
      recommendations.add(
        CalendarAiRecommendation(
          id: 'cal_fallback',
          message: NoesisL10n.tr(
            '{day} está livre {window}. Quer agendar {duration} de estudo focado?',
            {
              'day': dayLabel(slot.start),
              'window': windowText(slot.start, slot.end),
              'duration': durationLabel(90),
            },
          ),
          eventTitle: NoesisL10n.tr('Bloco de Estudo Focado'),
          eventDescription: NoesisL10n.tr('Bloco sugerido pelo Noesis AI no horário livre da sua agenda.'),
          category: 'study',
          colorHex: '#7C6CF0',
          startTime: slot.start,
          endTime: slot.end,
        ),
      );
    }

    return recommendations;
  }

  /// Parser resiliente para datas/horários naturais em português (ex: "11 da manhã de hoje", "sexta às 14h").
  static DateTime parseNaturalDateTime(String text, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final lower = text.toLowerCase();

    DateTime targetDay = base;
    if (NaturalDateKeywords.dayAfterTomorrowTokens.any(lower.contains)) {
      targetDay = base.add(const Duration(days: 2));
    } else if (NaturalDateKeywords.tomorrowTokens.any(lower.contains)) {
      targetDay = base.add(const Duration(days: 1));
    } else if (!NaturalDateKeywords.todayTokens.any(lower.contains)) {
      final dateMatch = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b').firstMatch(lower);
      if (dateMatch != null) {
        final d = int.tryParse(dateMatch.group(1)!) ?? base.day;
        final m = int.tryParse(dateMatch.group(2)!) ?? base.month;
        var y = base.year;
        if (dateMatch.group(3) != null) {
          final rawY = int.tryParse(dateMatch.group(3)!) ?? base.year;
          y = rawY < 100 ? 2000 + rawY : rawY;
        }
        targetDay = DateTime(y, m.clamp(1, 12), d.clamp(1, 31));
      } else {
        int? targetWeekday;
        for (final entry in NaturalDateKeywords.weekdayTokens.entries) {
          if (entry.value.any(lower.contains)) {
            targetWeekday = entry.key;
            break;
          }
        }

        if (targetWeekday != null) {
          int daysToAdd = (targetWeekday - base.weekday + 7) % 7;
          if (daysToAdd == 0) daysToAdd = 7;
          targetDay = base.add(Duration(days: daysToAdd));
        }
      }
    }

    int hour = 14;
    int minute = 0;

    final colonMatch = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(lower);
    final amPmMatch = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(lower);
    final hMatch = RegExp(r'\b(\d{1,2})\s*h(?:(\d{2}))?\b').firstMatch(lower);
    final naturalHourMatch = RegExp(
      r'(?:às|as|para\s+as|para\s+às|at[eé]\s+as|at|a\s+las)\s*(\d{1,2})\b',
    ).firstMatch(lower);

    if (NaturalDateKeywords.noonTokens.any(lower.contains)) {
      hour = 12;
    } else if (NaturalDateKeywords.midnightTokens.any(lower.contains)) {
      hour = 0;
    } else if (amPmMatch != null) {
      hour = (int.tryParse(amPmMatch.group(1)!) ?? 14).clamp(0, 23);
      minute = (int.tryParse(amPmMatch.group(2) ?? '0') ?? 0).clamp(0, 59);
      final mer = amPmMatch.group(3);
      if (mer == 'pm' && hour >= 1 && hour < 12) hour += 12;
      if (mer == 'am' && hour == 12) hour = 0;
    } else if (colonMatch != null) {
      hour = (int.tryParse(colonMatch.group(1)!) ?? 14).clamp(0, 23);
      minute = (int.tryParse(colonMatch.group(2)!) ?? 0).clamp(0, 59);
    } else if (hMatch != null) {
      hour = (int.tryParse(hMatch.group(1)!) ?? 14).clamp(0, 23);
      if (hMatch.group(2) != null) {
        minute = (int.tryParse(hMatch.group(2)!) ?? 0).clamp(0, 59);
      }
    } else if (naturalHourMatch != null) {
      hour = (int.tryParse(naturalHourMatch.group(1)!) ?? 14).clamp(0, 23);
    }

    if (NaturalDateKeywords.afternoonNightTokens.any(lower.contains) && hour >= 1 && hour < 12) {
      hour += 12;
    }

    return DateTime(targetDay.year, targetDay.month, targetDay.day, hour, minute);
  }

  /// Executa qualquer ferramenta de leitura/criação/edição/exclusão do Noesis.
  static Future<ExecutedToolResult> executeTool({
    required String name,
    required Map<String, dynamic> args,
    required String userMessage,
    String? attachmentContext,
    required QuizGeneratorCallback generateQuiz,
    required FlashcardsGeneratorCallback generateFlashcards,
    required RoadmapGeneratorCallback generateRoadmap,
  }) async {
    switch (name) {
      case 'inspect_account_data':
        final scope = (args['scope'] ?? 'all').toString().trim().toLowerCase();
        final query = (args['search_query'] ?? '').toString().trim().toLowerCase();
        final data = await _readAccountScope(scope: scope, query: query);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Dados da conta consultados · {scope}', {'scope': scope}),
          responsePayload: {'status': 'success', 'data': data},
        );

      case 'schedule_calendar_event':
        final title = (args['title'] ?? NoesisL10n.tr('Bloco de Estudo')).toString().trim();
        DateTime startTime;
        final rawIso = args['start_time_iso']?.toString() ?? '';
        final parsedIso = DateTime.tryParse(rawIso);
        if (parsedIso != null) {
          startTime = parsedIso.isUtc ? parsedIso.toLocal() : parsedIso;
        } else {
          startTime = parseNaturalDateTime(userMessage);
        }
        final duration = (args['duration_minutes'] as num?)?.toInt() ?? 60;
        final endTime = startTime.add(Duration(minutes: duration.clamp(15, 720)));
        final category = (args['category'] ?? 'study').toString().trim();
        final desc = args['description']?.toString();

        await SupabaseService.addCalendarEvent(
          title: title,
          description: desc,
          startTime: startTime,
          endTime: endTime,
          category: category,
        );
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Evento agendado · {time} · {title}', {
            'time': _formatTimeBrief(startTime),
            'title': title,
          }),
          responsePayload: {
            'status': 'success',
            'title': title,
            'start_time': startTime.toIso8601String(),
          },
        );

      case 'update_calendar_event':
        final events = await SupabaseService.getCalendarEvents();
        final eventId = args['event_id']?.toString();
        final titleMatch = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final target = events.where((e) {
          if (eventId != null && e['id']?.toString() == eventId) return true;
          if (titleMatch.isNotEmpty) {
            return (e['title'] ?? '').toString().toLowerCase().contains(titleMatch);
          }
          return false;
        }).firstOrNull;

        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Evento não encontrado para edição'),
            responsePayload: {'status': 'not_found', 'message': NoesisL10n.tr('Evento não encontrado.')},
          );
        }

        final oldStart = DateTime.tryParse((target['start_time'] ?? '').toString()) ?? DateTime.now();
        final oldEnd = DateTime.tryParse((target['end_time'] ?? '').toString()) ??
            oldStart.add(const Duration(minutes: 60));
        final newStart = DateTime.tryParse(args['start_time_iso']?.toString() ?? '') ?? oldStart;
        final durMins = (args['duration_minutes'] as num?)?.toInt() ??
            oldEnd.difference(oldStart).inMinutes.clamp(15, 720);
        final newEnd = newStart.add(Duration(minutes: durMins));
        final newTitle = (args['new_title'] ?? target['title'] ?? NoesisL10n.tr('Evento')).toString();
        final newCat = (args['category'] ?? target['category'] ?? 'study').toString();
        final newDesc = args.containsKey('description')
            ? args['description']?.toString()
            : target['description']?.toString();

        await SupabaseService.updateCalendarEvent(
          id: target['id'].toString(),
          title: newTitle,
          description: newDesc,
          category: newCat,
          color: target['color']?.toString(),
          startTime: newStart,
          endTime: newEnd,
        );
        if (args['is_completed'] is bool) {
          await SupabaseService.toggleCalendarEventCompleted(
            target['id'].toString(),
            args['is_completed'] == true,
          );
        }
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Calendário atualizado · {title}', {'title': newTitle}),
          responsePayload: {'status': 'success', 'title': newTitle},
        );

      case 'delete_calendar_event':
        final events = await SupabaseService.getCalendarEvents();
        final eventId = args['event_id']?.toString();
        final titleMatch = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final target = events.where((e) {
          if (eventId != null && e['id']?.toString() == eventId) return true;
          if (titleMatch.isNotEmpty) {
            return (e['title'] ?? '').toString().toLowerCase().contains(titleMatch);
          }
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Evento não encontrado para exclusão'),
            responsePayload: {'status': 'not_found'},
          );
        }
        await SupabaseService.deleteCalendarEvent(target['id'].toString());
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Evento removido · {title}', {'title': target['title']}),
          responsePayload: {'status': 'success', 'removed_title': target['title']},
        );

      case 'log_study_session':
        final subject = (args['subject'] ?? NoesisL10n.tr('Estudos')).toString().trim();
        final topic = (args['topic'] ?? NoesisL10n.tr('Geral')).toString().trim();
        final duration = ((args['duration_minutes'] as num?)?.toInt() ?? 60).clamp(1, 720);
        final studyDate =
            DateTime.tryParse(args['study_date_iso']?.toString() ?? '') ?? DateTime.now();
        final notes = args['notes']?.toString();

        await SupabaseService.addStudySession(
          subject: subject,
          topic: topic,
          durationMinutes: duration,
          studyDate: studyDate,
          notes: notes,
        );
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Sessão registrada · {duration} em {subject}', {
            'duration': _formatDuration(duration),
            'subject': subject,
          }),
          responsePayload: {'status': 'success', 'subject': subject, 'duration_minutes': duration},
        );

      case 'update_study_session':
        final sessions = await SupabaseService.getStudySessions(limit: 100);
        final sid = args['session_id']?.toString();
        final match = (args['match_text'] ?? '').toString().trim().toLowerCase();
        final target = sessions.where((s) {
          if (sid != null && s['id']?.toString() == sid) return true;
          if (match.isNotEmpty) {
            return (s['subject'] ?? '').toString().toLowerCase().contains(match) ||
                (s['topic'] ?? '').toString().toLowerCase().contains(match);
          }
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Sessão de estudo não encontrada'),
            responsePayload: {'status': 'not_found'},
          );
        }
        final newSubject = (args['subject'] ?? target['subject'] ?? NoesisL10n.tr('Geral')).toString();
        final newTopic = (args['topic'] ?? target['topic'] ?? '').toString();
        final newDur = (args['duration_minutes'] as num?)?.toInt() ??
            (target['duration_minutes'] as num?)?.toInt() ??
            60;
        final date = DateTime.tryParse((target['study_date'] ?? '').toString()) ?? DateTime.now();
        final notes = args.containsKey('notes') ? args['notes']?.toString() : target['notes']?.toString();
        await SupabaseService.updateStudySession(
          id: target['id'].toString(),
          subject: newSubject,
          topic: newTopic,
          durationMinutes: newDur,
          studyDate: date,
          notes: notes,
        );
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Diário atualizado · {subject} ({topic})', {
            'subject': newSubject,
            'topic': newTopic,
          }),
          responsePayload: {'status': 'success'},
        );

      case 'delete_study_session':
        final sessions = await SupabaseService.getStudySessions(limit: 100);
        final sid = args['session_id']?.toString();
        final match = (args['match_text'] ?? '').toString().trim().toLowerCase();
        final target = sessions.where((s) {
          if (sid != null && s['id']?.toString() == sid) return true;
          if (match.isNotEmpty) {
            return (s['subject'] ?? '').toString().toLowerCase().contains(match) ||
                (s['topic'] ?? '').toString().toLowerCase().contains(match);
          }
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Sessão de estudo não encontrada para exclusão'),
            responsePayload: {'status': 'not_found'},
          );
        }
        await SupabaseService.deleteStudySession(target['id'].toString());
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Registro removido do Diário · {topic}', {'topic': target['topic']}),
          responsePayload: {'status': 'success'},
        );

      case 'set_weekly_goal':
        final hours = (args['hours'] as num?)?.toInt() ?? 25;
        final mins = (args['minutes'] as num?)?.toInt() ?? 0;
        final rawTotal = hours * 60 + mins;
        final enabled = args['enabled'] != false && rawTotal > 0;
        final total = enabled ? rawTotal.clamp(30, 168 * 60) : 0;
        await SupabaseService.saveWeeklyGoalMinutes(total);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: total == 0
              ? NoesisL10n.tr('Meta semanal desativada (sem meta fixa)')
              : NoesisL10n.tr('Meta semanal ajustada para {goal}', {
                  'goal': SupabaseService.formatGoalDuration(total),
                }),
          responsePayload: {'status': 'success', 'weekly_goal_minutes': total},
        );

      case 'set_daily_goal':
        final dHours = (args['hours'] as num?)?.toInt() ?? 3;
        final dMins = (args['minutes'] as num?)?.toInt() ?? 0;
        final rawDaily = dHours * 60 + dMins;
        final dEnabled = args['enabled'] != false && rawDaily > 0;
        final dTotal = dEnabled
            ? rawDaily.clamp(
                SupabaseService.minDailyGoalMinutes,
                SupabaseService.maxDailyGoalMinutes,
              )
            : 0;
        await SupabaseService.saveDailyGoalMinutes(dTotal);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: dTotal == 0
              ? NoesisL10n.tr('Meta diária desativada (sem meta fixa)')
              : NoesisL10n.tr('Meta diária ajustada para {goal}', {
                  'goal': SupabaseService.formatGoalDuration(dTotal),
                }),
          responsePayload: {'status': 'success', 'daily_goal_minutes': dTotal},
        );

      case 'create_quiz':
        final title = (args['title'] ?? NoesisL10n.tr('Simulado Noesis')).toString().trim();
        final subject = (args['subject'] ?? NoesisL10n.tr('Tecnologia')).toString().trim();
        final count = ((args['num_questions'] as num?)?.toInt() ?? 5).clamp(1, 200);
        final diff = (args['difficulty'] ?? 'Médio / Prático').toString();
        final questions = await generateQuiz(
          subject: subject,
          topic: title,
          numberOfQuestions: count,
          difficulty: diff,
          referenceContext: attachmentContext,
        );
        final savedRecord = await SupabaseService.saveGeneratedQuiz(
          title: title,
          subject: subject,
          questionsData: questions,
          difficulty: diff,
        );
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Simulado criado · {count} questões · {title}', {
            'count': questions.length,
            'title': title,
          }),
          responsePayload: {'status': 'success', 'title': title, 'questions': questions.length},
          data: savedRecord,
        );

      case 'delete_quiz':
        final attempts = await SavedExamsRepository.loadAll();
        final genQuizzes = await SupabaseService.getQuizzes();
        final qid = args['quiz_id']?.toString();
        final match = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final targetAttempt = attempts.where((a) {
          if (qid != null && a.id == qid) return true;
          if (match.isNotEmpty) {
            return a.title.toLowerCase().contains(match) ||
                a.subject.toLowerCase().contains(match);
          }
          return false;
        }).firstOrNull;
        if (targetAttempt != null) {
          await SavedExamsRepository.deleteAttempt(targetAttempt.id);
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'completed',
            summary: NoesisL10n.tr('Simulado removido · {title}', {'title': targetAttempt.title}),
            responsePayload: {'status': 'success'},
          );
        }
        final targetGen = genQuizzes.where((q) {
          if (qid != null && q['id']?.toString() == qid) return true;
          if (match.isNotEmpty) {
            final t = (q['title'] ?? '').toString().toLowerCase();
            final s = (q['subject'] ?? '').toString().toLowerCase();
            return t.contains(match) || s.contains(match);
          }
          return false;
        }).firstOrNull;
        if (targetGen != null) {
          await SupabaseService.deleteQuiz(targetGen['id'].toString());
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'completed',
            summary: NoesisL10n.tr('Simulado removido · {title}', {'title': targetGen['title']}),
            responsePayload: {'status': 'success'},
          );
        }
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'failed',
          summary: NoesisL10n.tr('Simulado não encontrado'),
          responsePayload: {'status': 'not_found'},
        );

      case 'create_flashcards':
        final title = (args['title'] ?? NoesisL10n.tr('Novo Baralho de Flashcards')).toString().trim();
        final subject = (args['subject'] ?? NoesisL10n.tr('Geral')).toString().trim();
        final topic = (args['topic'] ?? title).toString().trim();
        final count = ((args['num_cards'] as num?)?.toInt() ?? 5).clamp(1, 30);
        final enrichedTopic = attachmentContext != null && attachmentContext.trim().isNotEmpty
            ? NoesisL10n.tr('{topic}\n\nUse também o material anexado:\n{ctx}', {
                'topic': topic,
                'ctx': attachmentContext.substring(0, math.min(2500, attachmentContext.length)),
              })
            : topic;
        final cardsData = await generateFlashcards(
          subject: subject,
          topic: enrichedTopic,
          count: count,
        );
        final flashcards = cardsData.asMap().entries.map((e) {
          final val = e.value;
          return Flashcard(
            id: 'fc-${DateTime.now().millisecondsSinceEpoch}-${e.key}',
            front: val['front']?.toString() ?? NoesisL10n.tr('Pergunta'),
            back: val['back']?.toString() ?? NoesisL10n.tr('Resposta'),
            tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject, topic],
          );
        }).toList();
        final deck = FlashcardDeck(
          id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          subject: subject,
          description: NoesisL10n.tr('Baralho gerado pelo Noesis AI sobre {topic}', {'topic': topic}),
          cards: flashcards,
          createdAt: DateTime.now(),
        );
        await SupabaseService.saveFlashcardDeck(deck);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Baralho criado · {count} cartões · {title}', {
            'count': flashcards.length,
            'title': title,
          }),
          responsePayload: {'status': 'success', 'title': title, 'cards': flashcards.length},
          data: deck.toMap(),
        );

      case 'update_flashcard_deck':
        final decks = await SupabaseService.getFlashcardDecks();
        final did = args['deck_id']?.toString();
        final match = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final target = decks.where((d) {
          if (did != null && d.id == did) return true;
          if (match.isNotEmpty) return d.title.toLowerCase().contains(match);
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Baralho de flashcards não encontrado'),
            responsePayload: {'status': 'not_found'},
          );
        }
        final updatedCards = List<Flashcard>.from(target.cards);
        final addCardsRaw = args['add_cards'];
        if (addCardsRaw is List) {
          for (final item in addCardsRaw.whereType<Map>()) {
            final front = (item['front'] ?? '').toString().trim();
            final back = (item['back'] ?? '').toString().trim();
            if (front.isNotEmpty && back.isNotEmpty) {
              updatedCards.add(
                Flashcard(
                  id: 'fc-${DateTime.now().millisecondsSinceEpoch}-${updatedCards.length}',
                  front: front,
                  back: back,
                  tags: [target.subject],
                ),
              );
            }
          }
        }
        final removeMatch = (args['remove_card_front_match'] ?? '').toString().trim().toLowerCase();
        if (removeMatch.isNotEmpty) {
          updatedCards.removeWhere((c) => c.front.toLowerCase().contains(removeMatch));
        }
        final updatedDeck = target.copyWith(
          title: (args['new_title'] ?? target.title).toString(),
          subject: (args['new_subject'] ?? target.subject).toString(),
          description: (args['new_description'] ?? target.description).toString(),
          cards: updatedCards,
        );
        await SupabaseService.saveFlashcardDeck(updatedDeck);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Baralho atualizado · {title} ({count} cartões)', {
            'title': updatedDeck.title,
            'count': updatedDeck.cardCount,
          }),
          responsePayload: {'status': 'success', 'title': updatedDeck.title},
          data: updatedDeck.toMap(),
        );

      case 'delete_flashcard_deck':
        final decks = await SupabaseService.getFlashcardDecks();
        final did = args['deck_id']?.toString();
        final match = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final target = decks.where((d) {
          if (did != null && d.id == did) return true;
          if (match.isNotEmpty) return d.title.toLowerCase().contains(match);
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Baralho não encontrado'),
            responsePayload: {'status': 'not_found'},
          );
        }
        await SupabaseService.deleteFlashcardDeck(target.id);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Baralho excluído · {title}', {'title': target.title}),
          responsePayload: {'status': 'success'},
        );

      case 'create_notebook_or_note':
        final nbTitle = (args['notebook_title'] ?? NoesisL10n.tr('Caderno Noesis')).toString().trim();
        final subject = (args['subject'] ?? NoesisL10n.tr('Geral')).toString().trim();
        final notebooks = await SupabaseService.getNotebooks();
        var notebook = notebooks
            .where((n) => n.title.toLowerCase() == nbTitle.toLowerCase())
            .firstOrNull;

        final noteTitle = (args['note_title'] ?? '').toString().trim();
        final noteContent = (args['note_content'] ?? '').toString().trim();
        final tags = args['tags'] is List
            ? (args['tags'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
            : <String>[subject];
        final needsReview = args['needs_review'] == true;

        if (notebook == null) {
          final newNbId = 'nb-${DateTime.now().millisecondsSinceEpoch}';
          final initialNotes = <StudyNote>[];
          if (noteTitle.isNotEmpty || noteContent.isNotEmpty) {
            initialNotes.add(
              StudyNote(
                id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                notebookId: newNbId,
                title: noteTitle.isNotEmpty ? noteTitle : nbTitle,
                content: noteContent,
                tags: tags,
                needsReview: needsReview,
              ),
            );
          }
          notebook = StudyNotebook(
            id: newNbId,
            title: nbTitle,
            subject: subject,
            description: (args['description'] ?? '').toString(),
            notes: initialNotes,
          );
          await SupabaseService.saveNotebook(notebook);
        } else if (noteTitle.isNotEmpty || noteContent.isNotEmpty) {
          final newNote = StudyNote(
            id: 'note-${DateTime.now().millisecondsSinceEpoch}',
            notebookId: notebook.id,
            title: noteTitle.isNotEmpty ? noteTitle : NoesisL10n.tr('Nova Anotação'),
            content: noteContent,
            tags: tags,
            needsReview: needsReview,
          );
          await SupabaseService.saveNote(notebook.id, newNote);
        }
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: noteTitle.isNotEmpty
              ? NoesisL10n.tr('Anotação criada · "{note}" em {notebook}', {
                  'note': noteTitle,
                  'notebook': notebook.title,
                })
              : NoesisL10n.tr('Caderno criado · {notebook}', {'notebook': notebook.title}),
          responsePayload: {'status': 'success', 'notebook': notebook.title},
        );

      case 'update_notebook_or_note':
        final notebooks = await SupabaseService.getNotebooks();
        final nbId = args['notebook_id']?.toString();
        final nbMatch = (args['notebook_match'] ?? '').toString().trim().toLowerCase();
        final targetNb = notebooks.where((n) {
          if (nbId != null && n.id == nbId) return true;
          if (nbMatch.isNotEmpty) return n.title.toLowerCase().contains(nbMatch);
          return false;
        }).firstOrNull;
        if (targetNb == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Caderno não encontrado'),
            responsePayload: {'status': 'not_found'},
          );
        }

        final noteId = args['note_id']?.toString();
        final noteMatch = (args['note_match'] ?? '').toString().trim().toLowerCase();
        if (noteId != null || noteMatch.isNotEmpty) {
          final targetNote = targetNb.notes.where((n) {
            if (noteId != null && n.id == noteId) return true;
            if (noteMatch.isNotEmpty) return n.title.toLowerCase().contains(noteMatch);
            return false;
          }).firstOrNull;
          if (targetNote == null) {
            return ExecutedToolResult(
              name: name,
              parameters: args,
              status: 'failed',
              summary: NoesisL10n.tr('Anotação não encontrada em {notebook}', {'notebook': targetNb.title}),
              responsePayload: {'status': 'not_found'},
            );
          }
          final markReviewed = args['mark_reviewed'] == true;
          final updatedNote = targetNote.copyWith(
            title: (args['new_note_title'] ?? targetNote.title).toString(),
            content: (args['new_note_content'] ?? targetNote.content).toString(),
            needsReview: markReviewed
                ? false
                : (args['needs_review'] is bool ? args['needs_review'] == true : targetNote.needsReview),
            lastReviewedAt: markReviewed ? DateTime.now() : targetNote.lastReviewedAt,
            reviewCount: markReviewed ? targetNote.reviewCount + 1 : targetNote.reviewCount,
          );
          await SupabaseService.saveNote(targetNb.id, updatedNote);
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'completed',
            summary: NoesisL10n.tr('Anotação atualizada · {title}', {'title': updatedNote.title}),
            responsePayload: {'status': 'success'},
          );
        }

        final updatedNb = targetNb.copyWith(
          title: (args['new_notebook_title'] ?? targetNb.title).toString(),
          subject: (args['new_subject'] ?? targetNb.subject).toString(),
        );
        await SupabaseService.saveNotebook(updatedNb);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Caderno atualizado · {title}', {'title': updatedNb.title}),
          responsePayload: {'status': 'success'},
        );

      case 'delete_notebook_or_note':
        final notebooks = await SupabaseService.getNotebooks();
        final nbId = args['notebook_id']?.toString();
        final nbMatch = (args['notebook_match'] ?? '').toString().trim().toLowerCase();
        final targetNb = notebooks.where((n) {
          if (nbId != null && n.id == nbId) return true;
          if (nbMatch.isNotEmpty) return n.title.toLowerCase().contains(nbMatch);
          return false;
        }).firstOrNull;
        if (targetNb == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Caderno não encontrado para exclusão'),
            responsePayload: {'status': 'not_found'},
          );
        }
        final noteId = args['note_id']?.toString();
        final noteMatch = (args['note_match'] ?? '').toString().trim().toLowerCase();
        if (noteId != null || noteMatch.isNotEmpty) {
          final targetNote = targetNb.notes.where((n) {
            if (noteId != null && n.id == noteId) return true;
            if (noteMatch.isNotEmpty) return n.title.toLowerCase().contains(noteMatch);
            return false;
          }).firstOrNull;
          if (targetNote != null) {
            await SupabaseService.deleteNote(targetNb.id, targetNote.id);
            return ExecutedToolResult(
              name: name,
              parameters: args,
              status: 'completed',
              summary: NoesisL10n.tr('Anotação excluída · {title}', {'title': targetNote.title}),
              responsePayload: {'status': 'success'},
            );
          }
        }
        await SupabaseService.deleteNotebook(targetNb.id);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Caderno excluído · {title}', {'title': targetNb.title}),
          responsePayload: {'status': 'success'},
        );

      case 'create_roadmap':
        final subject = (args['subject'] ?? NoesisL10n.tr('Geral')).toString().trim();
        final goal = (args['goal'] ?? (args['title'] ?? NoesisL10n.tr('Dominar {subject}', {'subject': subject}))).toString().trim();
        final level = (args['level'] ?? NoesisL10n.defaultRoadmapLevel).toString().trim();
        final weeks = ((args['estimated_weeks'] as num?)?.toInt() ?? 4).clamp(1, 52);
        final generated = await generateRoadmap(
          subject: subject,
          goal: goal,
          level: level,
          estimatedWeeks: weeks,
          focusNotes: attachmentContext,
        );
        final customTitle = (args['title'] ?? '').toString().trim();
        final now = DateTime.now();
        final roadmap = StudyRoadmap(
          id: 'rm-${now.millisecondsSinceEpoch}',
          title: customTitle.isNotEmpty ? customTitle : generated.title,
          goal: goal,
          subject: subject,
          level: level,
          estimatedWeeks: weeks,
          steps: generated.steps,
          createdAt: now,
          updatedAt: now,
        );
        await RoadmapsRepository.saveRoadmap(roadmap);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Trilha criada · {title} ({steps} etapas)', {
            'title': roadmap.title,
            'steps': roadmap.steps.length,
          }),
          responsePayload: {'status': 'success', 'title': roadmap.title, 'steps': roadmap.steps.length},
        );

      case 'update_roadmap':
        final roadmaps = await RoadmapsRepository.loadAll();
        final rid = args['roadmap_id']?.toString();
        final match = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final target = roadmaps.where((r) {
          if (rid != null && r.id == rid) return true;
          if (match.isNotEmpty) return r.title.toLowerCase().contains(match);
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Trilha não encontrada'),
            responsePayload: {'status': 'not_found'},
          );
        }
        final steps = List<RoadmapStep>.from(target.steps);
        final addStepTitle = (args['add_step_title'] ?? '').toString().trim();
        if (addStepTitle.isNotEmpty) {
          steps.add(
            RoadmapStep(
              id: 'step-${DateTime.now().millisecondsSinceEpoch}',
              title: addStepTitle,
              description: (args['add_step_description'] ?? '').toString(),
              estimatedHours: 4,
            ),
          );
        }
        final stepMatch = (args['step_match'] ?? '').toString().trim().toLowerCase();
        if (stepMatch.isNotEmpty) {
          if (args['remove_step'] == true) {
            steps.removeWhere((s) => s.title.toLowerCase().contains(stepMatch));
          } else if (args['step_status'] != null) {
            final newStatus = RoadmapStepStatus.fromString(args['step_status'].toString());
            for (int i = 0; i < steps.length; i++) {
              if (steps[i].title.toLowerCase().contains(stepMatch)) {
                steps[i] = steps[i].copyWith(status: newStatus);
              }
            }
          }
        }
        final updatedRm = target.copyWith(
          title: (args['new_title'] ?? target.title).toString(),
          goal: (args['new_goal'] ?? target.goal).toString(),
          steps: steps,
        );
        await RoadmapsRepository.saveRoadmap(updatedRm);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Trilha atualizada · {title}', {'title': updatedRm.title}),
          responsePayload: {'status': 'success', 'title': updatedRm.title},
        );

      case 'delete_roadmap':
        final roadmaps = await RoadmapsRepository.loadAll();
        final rid = args['roadmap_id']?.toString();
        final match = (args['title_match'] ?? '').toString().trim().toLowerCase();
        final target = roadmaps.where((r) {
          if (rid != null && r.id == rid) return true;
          if (match.isNotEmpty) return r.title.toLowerCase().contains(match);
          return false;
        }).firstOrNull;
        if (target == null) {
          return ExecutedToolResult(
            name: name,
            parameters: args,
            status: 'failed',
            summary: NoesisL10n.tr('Trilha não encontrada para exclusão'),
            responsePayload: {'status': 'not_found'},
          );
        }
        await RoadmapsRepository.deleteRoadmap(target.id);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: NoesisL10n.tr('Trilha excluída · {title}', {'title': target.title}),
          responsePayload: {'status': 'success'},
        );

      default:
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'failed',
          summary: NoesisL10n.tr('Ação desconhecida'),
          responsePayload: {'status': 'unknown_tool'},
        );
    }
  }

  /// Rede de segurança: se um modelo LLM respondeu confirmando que agendou/registrou/criou
  /// sem ter disparado nenhuma ferramenta real, executa a ação correspondente de forma determinística.
  static Future<ExecutedToolResult?> tryRecoverUnexecutedIntent({
    required String userMessage,
    required String aiReply,
    String? attachmentContext,
    required QuizGeneratorCallback generateQuiz,
    required FlashcardsGeneratorCallback generateFlashcards,
    required RoadmapGeneratorCallback generateRoadmap,
  }) async {
    final lowerUser = userMessage.toLowerCase().trim();
    final lowerReply = aiReply.toLowerCase();

    final replyClaimsAction = NaturalDateKeywords.replyClaimTokens.any(lowerReply.contains);

    final userAsksCalendarCreate =
        NaturalDateKeywords.calendarNouns.any(lowerUser.contains) &&
            NaturalDateKeywords.calendarVerbs.any(lowerUser.contains);

    if (userAsksCalendarCreate && !NaturalDateKeywords.excludeVerbs.any(lowerUser.contains)) {
      final startTime = parseNaturalDateTime(userMessage);
      final category = NaturalDateKeywords.examKeywords.any(lowerUser.contains)
          ? 'exam'
          : (NaturalDateKeywords.reviewKeywords.any(lowerUser.contains)
              ? 'review'
              : (NaturalDateKeywords.quizKeywords.any(lowerUser.contains) ? 'lab' : 'study'));
      final title = NaturalDateKeywords.examKeywords.any(lowerUser.contains)
          ? NoesisL10n.tr('Prova')
          : (NaturalDateKeywords.reviewKeywords.any(lowerUser.contains)
              ? NoesisL10n.tr('Revisão de Estudos')
              : NoesisL10n.tr('Bloco de Estudos'));
      return executeTool(
        name: 'schedule_calendar_event',
        args: {
          'title': title,
          'start_time_iso': startTime.toIso8601String(),
          'duration_minutes': 60,
          'category': category,
          'description': userMessage,
        },
        userMessage: userMessage,
        attachmentContext: attachmentContext,
        generateQuiz: generateQuiz,
        generateFlashcards: generateFlashcards,
        generateRoadmap: generateRoadmap,
      );
    }

    if (replyClaimsAction &&
        NaturalDateKeywords.sessionKeywords.any(lowerUser.contains) &&
        !NaturalDateKeywords.excludeVerbs.any(lowerUser.contains)) {
      return executeTool(
        name: 'log_study_session',
        args: {
          'subject': NoesisL10n.tr('Estudos'),
          'topic': userMessage,
          'duration_minutes': 60,
        },
        userMessage: userMessage,
        attachmentContext: attachmentContext,
        generateQuiz: generateQuiz,
        generateFlashcards: generateFlashcards,
        generateRoadmap: generateRoadmap,
      );
    }

    if (replyClaimsAction && NaturalDateKeywords.weeklyGoalKeywords.any(lowerUser.contains)) {
      final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(lowerUser);
      if (hourMatch != null) {
        final h = int.tryParse(hourMatch.group(1)!) ?? 25;
        return executeTool(
          name: 'set_weekly_goal',
          args: {'hours': h},
          userMessage: userMessage,
          attachmentContext: attachmentContext,
          generateQuiz: generateQuiz,
          generateFlashcards: generateFlashcards,
          generateRoadmap: generateRoadmap,
        );
      }
    }

    if (replyClaimsAction && NaturalDateKeywords.dailyGoalKeywords.any(lowerUser.contains)) {
      final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(lowerUser);
      final minMatch = RegExp(r'(\d+)\s*m(?:in)?').firstMatch(lowerUser);
      if (hourMatch != null || minMatch != null) {
        final h = hourMatch != null ? (int.tryParse(hourMatch.group(1)!) ?? 0) : 0;
        final m = minMatch != null ? (int.tryParse(minMatch.group(1)!) ?? 0) : 0;
        return executeTool(
          name: 'set_daily_goal',
          args: {'hours': h, 'minutes': m},
          userMessage: userMessage,
          attachmentContext: attachmentContext,
          generateQuiz: generateQuiz,
          generateFlashcards: generateFlashcards,
          generateRoadmap: generateRoadmap,
        );
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> _readAccountScope({
    required String scope,
    required String query,
  }) async {
    final result = <String, dynamic>{};
    bool matches(String text) => query.isEmpty || text.toLowerCase().contains(query);

    if (scope == 'all' || scope == 'weekly_goal' || scope == 'daily_goal') {
      final goal = await SupabaseService.loadWeeklyGoalMinutes();
      final dailyGoal = await SupabaseService.loadDailyGoalMinutes();
      final sessions = await SupabaseService.getStudySessions(limit: 100);
      final week = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
      final today = SupabaseService.computeTodayStudiedMinutes(sessions);
      result['weekly_goal'] = {
        'enabled': goal > 0,
        'goal_minutes': goal,
        'goal_formatted': goal > 0 ? SupabaseService.formatGoalDuration(goal) : NoesisL10n.tr('Sem meta definida'),
        'studied_this_week_minutes': week,
        'studied_this_week_formatted': SupabaseService.formatGoalDuration(week),
      };
      result['daily_goal'] = {
        'enabled': dailyGoal > 0,
        'goal_minutes': dailyGoal,
        'goal_formatted': dailyGoal > 0 ? SupabaseService.formatGoalDuration(dailyGoal) : NoesisL10n.tr('Sem meta definida'),
        'studied_today_minutes': today,
        'studied_today_formatted': SupabaseService.formatGoalDuration(today),
      };
    }

    if (scope == 'all' || scope == 'calendar') {
      final events = await SupabaseService.getCalendarEvents();
      result['calendar'] = events
          .where((e) => matches('${e['title']} ${e['description']} ${e['category']}'))
          .take(30)
          .toList();
    }

    if (scope == 'all' || scope == 'sessions') {
      final sessions = await SupabaseService.getStudySessions(limit: 50);
      result['sessions'] = sessions
          .where((s) => matches('${s['subject']} ${s['topic']} ${s['notes']}'))
          .take(30)
          .toList();
    }

    if (scope == 'all' || scope == 'quizzes') {
      final attempts = await SavedExamsRepository.loadAll();
      final genQuizzes = await SupabaseService.getQuizzes();
      result['quizzes'] = [
        ...attempts
            .where((a) => matches('${a.title} ${a.subject} ${a.topic}'))
            .take(20)
            .map((a) => {
                  'id': a.id,
                  'title': a.title,
                  'subject': a.subject,
                  'score_percentage': a.scorePercentage,
                  'correct': a.correctCount,
                  'wrong': a.wrongCount,
                  'created_at': a.createdAt.toIso8601String(),
                }),
        ...genQuizzes
            .where((q) => matches('${q['title']} ${q['subject']}'))
            .take(15)
            .map((q) => {
                  'id': q['id'],
                  'title': q['title'],
                  'subject': q['subject'],
                  'questions_count': (q['questions_data'] as List?)?.length ?? 0,
                  'created_at': q['created_at'],
                }),
      ];
    }

    if (scope == 'all' || scope == 'flashcards') {
      final decks = await SupabaseService.getFlashcardDecks();
      result['flashcards'] = decks
          .where((d) => matches('${d.title} ${d.subject} ${d.description}'))
          .take(20)
          .map((d) => {
                'id': d.id,
                'title': d.title,
                'subject': d.subject,
                'card_count': d.cardCount,
                'pending_review': d.pendingReviewCount(),
                'cards': d.cards
                    .take(20)
                    .map((c) => {'front': c.front, 'back': c.back, 'difficulty': c.difficulty})
                    .toList(),
              })
          .toList();
    }

    if (scope == 'all' || scope == 'notebooks') {
      final notebooks = await SupabaseService.getNotebooks();
      result['notebooks'] = notebooks
          .where((n) => matches('${n.title} ${n.subject} ${n.notes.map((e) => '${e.title} ${e.content}').join(' ')}'))
          .take(20)
          .map((n) => {
                'id': n.id,
                'title': n.title,
                'subject': n.subject,
                'notes': n.notes
                    .map((note) => {
                          'id': note.id,
                          'title': note.title,
                          'content': note.content,
                          'needs_review': note.needsReview,
                          'tags': note.tags,
                        })
                    .toList(),
              })
          .toList();
    }

    if (scope == 'all' || scope == 'roadmaps') {
      final roadmaps = await RoadmapsRepository.loadAll();
      result['roadmaps'] = roadmaps
          .where((r) => matches('${r.title} ${r.subject} ${r.goal}'))
          .take(15)
          .map((r) => {
                'id': r.id,
                'title': r.title,
                'subject': r.subject,
                'goal': r.goal,
                'progress_pct': (r.progress * 100).round(),
                'steps': r.steps
                    .map((s) => {'id': s.id, 'title': s.title, 'status': s.status.label})
                    .toList(),
              })
          .toList();
    }

    return result;
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  static String _formatTimeBrief(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return NoesisL10n.tr('{dd}/{mm} às {hh}:{min}', {
      'dd': dd,
      'mm': mm,
      'hh': hh,
      'min': min,
    });
  }
}
