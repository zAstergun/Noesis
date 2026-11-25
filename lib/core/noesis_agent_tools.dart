import 'dart:math' as math;
import '../features/flashcards/models/flashcard_model.dart';
import '../features/notebooks/models/notebook_model.dart';
import '../features/quizzes/data/saved_exams_repository.dart';
import '../features/roadmaps/data/roadmaps_repository.dart';
import '../features/roadmaps/models/roadmap_model.dart';
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
        return 'Arquivo';
      case 'quiz':
        return 'Simulado';
      case 'notebook':
        return 'Caderno';
      case 'flashcard_deck':
        return 'Flashcards';
      case 'roadmap':
        return 'Trilha';
      case 'study_log':
        return 'Diário';
      case 'calendar':
        return 'Calendário';
      default:
        return 'Anexo';
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
          'description':
              'Lê e revisa itens reais da conta do usuário no Noesis (calendário, diário de estudos, simulados, flashcards, cadernos, trilhas e meta semanal). Use antes de responder perguntas sobre o que existe na conta ou quando precisar de IDs/conteúdos completos para revisar ou editar.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'scope': {
                'type': 'STRING',
                'description':
                    'Escopo: all, calendar, sessions, quizzes, flashcards, notebooks, roadmaps, weekly_goal.',
              },
              'search_query': {
                'type': 'STRING',
                'description': 'Filtro opcional por título, matéria ou termo.',
              },
            },
            'required': ['scope'],
          },
        },
        // ─── CALENDÁRIO ───
        {
          'name': 'schedule_calendar_event',
          'description': 'Cria um novo evento, prova, revisão ou bloco de estudos no calendário.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'title': {'type': 'STRING', 'description': 'Título claro do evento ou prova.'},
              'start_time_iso': {
                'type': 'STRING',
                'description': 'Data/hora de início em ISO 8601 local (ex: 2026-11-25T11:00:00).',
              },
              'duration_minutes': {'type': 'INTEGER', 'description': 'Duração em minutos (padrão 60).'},
              'category': {
                'type': 'STRING',
                'description': 'Categoria: study, review, lab, exam, personal.',
              },
              'description': {'type': 'STRING', 'description': 'Observações do evento.'},
            },
            'required': ['title', 'start_time_iso'],
          },
        },
        {
          'name': 'update_calendar_event',
          'description': 'Edita um evento existente no calendário (título, horário, duração, categoria ou conclusão).',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'event_id': {'type': 'STRING', 'description': 'ID do evento (se conhecido).'},
              'title_match': {'type': 'STRING', 'description': 'Parte do título do evento para localizar.'},
              'new_title': {'type': 'STRING', 'description': 'Novo título (opcional).'},
              'start_time_iso': {'type': 'STRING', 'description': 'Novo horário de início ISO 8601 (opcional).'},
              'duration_minutes': {'type': 'INTEGER', 'description': 'Nova duração em minutos (opcional).'},
              'category': {'type': 'STRING', 'description': 'Nova categoria (opcional).'},
              'description': {'type': 'STRING', 'description': 'Nova descrição (opcional).'},
              'is_completed': {'type': 'BOOLEAN', 'description': 'Marcar como concluído ou pendente.'},
            },
          },
        },
        {
          'name': 'delete_calendar_event',
          'description': 'Remove um evento do calendário pelo ID ou título.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'event_id': {'type': 'STRING', 'description': 'ID do evento.'},
              'title_match': {'type': 'STRING', 'description': 'Parte do título do evento a remover.'},
            },
          },
        },
        // ─── DIÁRIO DE ESTUDOS / SESSÕES ───
        {
          'name': 'log_study_session',
          'description': 'Registra uma sessão de estudo concluída no Diário de Estudos.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'subject': {'type': 'STRING', 'description': 'Matéria estudada.'},
              'topic': {'type': 'STRING', 'description': 'O que foi estudado.'},
              'duration_minutes': {'type': 'INTEGER', 'description': 'Duração em minutos.'},
              'study_date_iso': {'type': 'STRING', 'description': 'Data YYYY-MM-DD (opcional, padrão hoje).'},
              'notes': {'type': 'STRING', 'description': 'Anotações opcionais.'},
            },
            'required': ['subject', 'topic', 'duration_minutes'],
          },
        },
        {
          'name': 'update_study_session',
          'description': 'Edita um registro do Diário de Estudos.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'session_id': {'type': 'STRING'},
              'match_text': {'type': 'STRING', 'description': 'Busca por matéria ou tópico.'},
              'subject': {'type': 'STRING'},
              'topic': {'type': 'STRING'},
              'duration_minutes': {'type': 'INTEGER'},
              'notes': {'type': 'STRING'},
            },
          },
        },
        {
          'name': 'delete_study_session',
          'description': 'Exclui um registro do Diário de Estudos.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'session_id': {'type': 'STRING'},
              'match_text': {'type': 'STRING', 'description': 'Matéria ou tópico do registro.'},
            },
          },
        },
        // ─── META SEMANAL ───
        {
          'name': 'set_weekly_goal',
          'description': 'Define ou atualiza a meta semanal de estudos do usuário.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'hours': {'type': 'INTEGER', 'description': 'Horas por semana.'},
              'minutes': {'type': 'INTEGER', 'description': 'Minutos adicionais (0 a 59).'},
            },
            'required': ['hours'],
          },
        },
        // ─── SIMULADOS ───
        {
          'name': 'create_quiz',
          'description': 'Cria um novo simulado com questões personalizadas.',
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
          'description': 'Remove um simulado salvo pelo ID ou título.',
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
          'description': 'Cria um novo baralho de flashcards.',
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
          'description':
              'Edita um baralho de flashcards existente: renomear, adicionar cartões ou remover cartões.',
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
          'description': 'Exclui um baralho de flashcards pelo ID ou título.',
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
          'description':
              'Cria um novo caderno de estudos e/ou adiciona uma anotação dentro de um caderno.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'notebook_title': {'type': 'STRING', 'description': 'Título do caderno.'},
              'subject': {'type': 'STRING', 'description': 'Disciplina do caderno.'},
              'description': {'type': 'STRING', 'description': 'Descrição do caderno (opcional).'},
              'note_title': {'type': 'STRING', 'description': 'Título da anotação (opcional).'},
              'note_content': {'type': 'STRING', 'description': 'Conteúdo Markdown da anotação.'},
              'tags': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
              },
              'needs_review': {'type': 'BOOLEAN', 'description': 'Se deve marcar a anotação para revisão.'},
            },
            'required': ['notebook_title'],
          },
        },
        {
          'name': 'update_notebook_or_note',
          'description':
              'Edita um caderno ou uma anotação existente (título, conteúdo, tags ou marcação de revisão).',
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
          'description': 'Exclui uma anotação específica ou um caderno inteiro.',
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
          'description': 'Cria uma nova trilha de estudos (roadmap) com etapas detalhadas.',
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
          'description':
              'Edita uma trilha (roadmap): alterar título/objetivo, adicionar etapa, marcar etapa como concluída/em andamento ou remover etapa.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'roadmap_id': {'type': 'STRING'},
              'title_match': {'type': 'STRING'},
              'new_title': {'type': 'STRING'},
              'new_goal': {'type': 'STRING'},
              'add_step_title': {'type': 'STRING'},
              'add_step_description': {'type': 'STRING'},
              'step_match': {'type': 'STRING', 'description': 'Título da etapa para atualizar status/excluir.'},
              'step_status': {'type': 'STRING', 'description': 'todo, doing ou done.'},
              'remove_step': {'type': 'BOOLEAN'},
            },
          },
        },
        {
          'name': 'delete_roadmap',
          'description': 'Exclui uma trilha (roadmap) pelo ID ou título.',
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
    buf.writeln('=== CONTEXTO REAL DA CONTA NO NOESIS ===');
    buf.writeln(
      'Meta semanal: ${SupabaseService.formatGoalDuration(weekStudied)} estudados nesta semana / '
      'meta de ${SupabaseService.formatGoalDuration(weeklyGoal)}.',
    );

    buf.writeln('\n[Calendário: ${events.length} eventos]');
    for (final e in events.take(15)) {
      buf.writeln(
        '- "${e['title']}" (${e['category'] ?? 'study'}) · início=${e['start_time']} · '
        'concluído=${e['is_completed'] == true}',
      );
    }

    buf.writeln('\n[Diário de Estudos: ${sessions.length} sessões recentes]');
    for (final s in sessions.take(12)) {
      buf.writeln(
        '- ${s['study_date']} · ${s['subject']}: "${s['topic']}" (${s['duration_minutes']} min)',
      );
    }

    buf.writeln('\n[Simulados salvos: ${exams.length + generatedQuizzes.length}]');
    for (final ex in exams.take(10)) {
      buf.writeln(
        '- "${ex.title}" (${ex.subject}) · ${ex.scorePercentage.round()}% '
        '(${ex.correctCount}/${ex.loadedCount} acertos)',
      );
    }
    for (final q in generatedQuizzes.take(8)) {
      final qList = (q['questions_data'] as List?) ?? [];
      buf.writeln(
        '- "${q['title']}" (${q['subject'] ?? 'Geral'}) · ${qList.length} questões (gerado)',
      );
    }

    buf.writeln('\n[Flashcards: ${decks.length} baralhos]');
    for (final d in decks.take(12)) {
      buf.writeln(
        '- "${d.title}" (${d.subject}) · ${d.cardCount} cartões (${d.pendingReviewCount()} p/ revisar)',
      );
    }

    buf.writeln('\n[Cadernos: ${notebooks.length}]');
    for (final nb in notebooks.take(12)) {
      final noteTitles = nb.notes.take(5).map((n) {
        final flag = n.needsReview ? ' [revisar]' : '';
        return '"${n.title}"$flag';
      }).join(', ');
      buf.writeln('- "${nb.title}" (${nb.subject}, ${nb.noteCount} notas): $noteTitles');
    }

    buf.writeln('\n[Trilhas: ${roadmaps.length}]');
    for (final rm in roadmaps.take(10)) {
      final pct = (rm.progress * 100).round();
      buf.writeln('- "${rm.title}" (${rm.subject}) · $pct% · ${rm.steps.length} etapas');
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
        ..writeln('Simulado: ${ex.title} | Matéria: ${ex.subject} | Nota: ${ex.scorePercentage.round()}%')
        ..writeln('Acertos: ${ex.correctCount} | Erros: ${ex.wrongCount} | Em branco: ${ex.blankCount}');
      for (int i = 0; i < math.min(12, ex.questions.length); i++) {
        final q = ex.questions[i];
        final userAns = ex.userAnswers[i];
        final rightIdx = q['correct_index'] as int? ?? 0;
        final status = userAns == null ? 'Em branco' : (userAns == rightIdx ? 'Correta' : 'Errada');
        qBuf.writeln('Q${i + 1} [$status]: ${q['question'] ?? ''}');
      }
      list.add(
        NoesisAttachment(
          id: 'quiz:${ex.id}',
          kind: 'quiz',
          title: ex.title,
          subtitle: '${ex.subject} · ${ex.scorePercentage.round()}% (${ex.loadedCount} questões)',
          content: qBuf.toString(),
        ),
      );
    }

    for (final q in generatedQuizzes) {
      final qId = q['id']?.toString() ?? q['title']?.toString() ?? '';
      final title = q['title']?.toString() ?? 'Simulado Noesis';
      final subject = q['subject']?.toString() ?? 'Geral';
      final qs = (q['questions_data'] as List?) ?? [];
      final qBuf = StringBuffer()
        ..writeln('Simulado gerado: $title | Matéria: $subject | Questões: ${qs.length}');
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
          subtitle: '$subject · ${qs.length} questões (gerado)',
          content: qBuf.toString(),
        ),
      );
    }

    for (final nb in notebooks) {
      final nBuf = StringBuffer()
        ..writeln('Caderno: ${nb.title} | Disciplina: ${nb.subject}')
        ..writeln('Descrição: ${nb.description}');
      for (final note in nb.notes) {
        nBuf.writeln('\n--- Anotação: ${note.title} (revisar=${note.needsReview}) ---');
        if (note.tags.isNotEmpty) nBuf.writeln('Tags: ${note.tags.join(', ')}');
        nBuf.writeln(note.content);
      }
      list.add(
        NoesisAttachment(
          id: 'notebook:${nb.id}',
          kind: 'notebook',
          title: nb.title,
          subtitle: '${nb.subject} · ${nb.noteCount} anotações',
          content: nBuf.toString(),
        ),
      );
    }

    for (final deck in decks) {
      final dBuf = StringBuffer()
        ..writeln('Baralho: ${deck.title} | Matéria: ${deck.subject}')
        ..writeln('Cartões (${deck.cardCount}, ${deck.pendingReviewCount()} p/ revisar):');
      for (final c in deck.cards.take(25)) {
        dBuf.writeln('- [${c.difficulty}] P: ${c.front} | R: ${c.back}');
      }
      list.add(
        NoesisAttachment(
          id: 'deck:${deck.id}',
          kind: 'flashcard_deck',
          title: deck.title,
          subtitle: '${deck.subject} · ${deck.cardCount} cartões',
          content: dBuf.toString(),
        ),
      );
    }

    for (final rm in roadmaps) {
      final rBuf = StringBuffer()
        ..writeln('Trilha: ${rm.title} | Disciplina: ${rm.subject} | Objetivo: ${rm.goal}');
      for (final st in rm.steps) {
        rBuf.writeln('- [${st.status.label}] ${st.title} (${st.estimatedHours}h): ${st.description}');
      }
      list.add(
        NoesisAttachment(
          id: 'roadmap:${rm.id}',
          kind: 'roadmap',
          title: rm.title,
          subtitle: '${rm.subject} · ${(rm.progress * 100).round()}% · ${rm.steps.length} etapas',
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
          label: '🎴 Revisar ${shorten(topDeck.title, 18)} ($pending)',
          prompt:
              'Analise os $pending cartões pendentes do meu baralho "${topDeck.title}" (${topDeck.subject}) e me ajude a praticar com perguntas de active recall.',
          tooltip: 'Baseado nos seus flashcards pendentes em ${topDeck.subject}',
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
          label: '📓 Revisar nota: ${shorten(targetNote.title, 18)}',
          prompt:
              'Leia minha anotação "${targetNote.title}" no caderno "${targetNb.title}" (${targetNb.subject}), explique os pontos-chave e crie perguntas para revisão.',
          tooltip: 'Anotação marcada para revisão no caderno ${targetNb.title}',
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
          label: '📝 Reforçar ${shorten(exam.subject, 16)} (${exam.scorePercentage.round()}%)',
          prompt:
              'Analise meus erros no simulado "${exam.title}" (${exam.scorePercentage.round()}% de acerto em ${exam.subject}) e gere um simulado de reforço focado nessas lacunas.',
          tooltip: 'Baseado no desempenho do simulado ${exam.title}',
        ),
      );
    }

    // 4. Continuidade da última sessão registrada no Diário de Estudos
    if (sessions.isNotEmpty) {
      final latest = sessions.first;
      final subj = (latest['subject'] ?? 'Estudos').toString().trim();
      final topic = (latest['topic'] ?? '').toString().trim();
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'session_followup',
          label: '⏱️ Fixar ${shorten(topic.isNotEmpty ? topic : subj, 20)}',
          prompt:
              'Com base no que estudei por último ($subj${topic.isNotEmpty ? " · $topic" : ""}), faça um resumo prático e agende uma revisão espaçada no calendário.',
          tooltip: 'Baseado na sua última sessão registrada no Diário',
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
      final title = (ev['title'] ?? 'Compromisso').toString();
      suggestions.add(
        NoesisQuickSuggestion(
          id: 'calendar_prep',
          label: '📅 Preparar p/ ${shorten(title, 18)}',
          prompt:
              'Tenho "${ev['title']}" agendado no calendário. Monte um roteiro objetivo de revisão para chegar preparado.',
          tooltip: 'Baseado no seu próximo evento do Calendário',
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
            label: '🗺️ Avançar: ${shorten(nextStep.title, 18)}',
            prompt:
                'Na minha trilha "${rm.title}", me guie pela próxima etapa "${nextStep.title}" com resumo e exercício prático.',
            tooltip: 'Próxima etapa pendente em ${rm.title}',
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
          label: '🎯 Bater meta (faltam ${SupabaseService.formatGoalDuration(remaining)})',
          prompt:
              'Ainda faltam ${SupabaseService.formatGoalDuration(remaining)} para minha meta semanal de ${SupabaseService.formatGoalDuration(weeklyGoal)}. Analise minha semana e agende blocos de estudo.',
          tooltip: 'Calculado com base no seu progresso semanal real',
        ),
      );
    }

    // Fallbacks caso haja poucos dados cadastrados na conta
    const fallbacks = [
      NoesisQuickSuggestion(
        id: 'fallback_overview',
        label: '✨ Plano de estudo de hoje',
        prompt: 'Leia tudo o que tenho na minha conta e monte um plano objetivo para hoje.',
      ),
      NoesisQuickSuggestion(
        id: 'fallback_quiz',
        label: '📝 Criar simulado diagnóstico',
        prompt: 'Crie um simulado de 5 questões para testar meu nível atual em Segurança e Redes.',
      ),
      NoesisQuickSuggestion(
        id: 'fallback_calendar',
        label: '📅 Agendar bloco de revisão',
        prompt: 'Agende uma revisão de 1h no calendário para hoje às 19h.',
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
      if (diff == 0) return 'Hoje';
      if (diff == 1) return 'Amanhã';
      const names = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
      return names[(dt.weekday - 1) % 7];
    }

    String windowText(DateTime st, DateTime en) {
      String fmt(DateTime d) => d.minute == 0
          ? '${d.hour}h'
          : '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
      return 'das ${fmt(st)} às ${fmt(en)}';
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
      final examTitle = (examEv['title'] ?? 'Prova').toString();
      final examStart = DateTime.parse(examEv['start_time'].toString());
      final slot = findFreeSlot(120, beforeDeadline: examStart, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_exam_prep',
            message:
                '${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)}. Quer um bloco de ${durationLabel(120)} de revisão antes de "$examTitle"?',
            eventTitle: 'Revisão p/ $examTitle',
            eventDescription: 'Bloco preparatório sugerido pelo Noesis AI antes do evento "$examTitle".',
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
            message:
                'Você marcou ${targetExam.scorePercentage.round()}% em ${targetExam.subject}. ${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)} — quer agendar ${durationLabel(90)} de reforço?',
            eventTitle: 'Reforço · ${targetExam.subject}',
            eventDescription:
                'Revisão direcionada dos erros do simulado "${targetExam.title}" (${targetExam.scorePercentage.round()}%).',
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
            message:
                'Há $pending flashcards pendentes em "${topDeck.title}". ${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)} — quer reservar ${durationLabel(60)} de active recall?',
            eventTitle: 'Flashcards · ${topDeck.subject}',
            eventDescription: 'Revisão espaçada dos $pending cartões pendentes de "${topDeck.title}".',
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
            message:
                'Sua nota "${revNote.title}" (${revNb.subject}) está marcada para revisão. ${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)} — quer agendar ${durationLabel(60)}?',
            eventTitle: 'Revisar Nota · ${revNote.title}',
            eventDescription: 'Revisão do caderno "${revNb.title}" (${revNb.subject}).',
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
      final lastSubject = sessions.isNotEmpty ? (sessions.first['subject'] ?? 'Estudos').toString() : 'Estudos';
      final remaining = weeklyGoal > weekStudied ? weeklyGoal - weekStudied : 120;
      final dur = remaining >= 120 ? 120 : (remaining >= 60 ? 60 : 60);
      final slot = findFreeSlot(dur, avoidStartKeys: usedKeys);
      if (slot != null) {
        markUsed(slot.start);
        final msg = weeklyGoal > weekStudied
            ? 'Faltam ${SupabaseService.formatGoalDuration(remaining)} para sua meta semanal (último foco: $lastSubject). ${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)} — quer um bloco de ${durationLabel(dur)}?'
            : 'Para manter seu ritmo em $lastSubject, ${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)}. Quer um bloco de ${durationLabel(dur)}?';
        recommendations.add(
          CalendarAiRecommendation(
            id: 'cal_weekly_goal',
            message: msg,
            eventTitle: 'Estudo · $lastSubject',
            eventDescription: 'Bloco planejado pelo Noesis AI para impulsionar sua meta semanal.',
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
              message:
                  'Na trilha "${rm.title}", falta a etapa "${nextStep.title}". ${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)} — quer reservar ${durationLabel(90)}?',
              eventTitle: 'Trilha · ${nextStep.title}',
              eventDescription: 'Etapa da trilha "${rm.title}" (${rm.subject}).',
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
          message:
              '${dayLabel(slot.start)} está livre ${windowText(slot.start, slot.end)}. Quer agendar ${durationLabel(90)} de estudo focado?',
          eventTitle: 'Bloco de Estudo Focado',
          eventDescription: 'Bloco sugerido pelo Noesis AI no horário livre da sua agenda.',
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
    if (lower.contains('depois de amanh')) {
      targetDay = base.add(const Duration(days: 2));
    } else if (lower.contains('amanhã') || lower.contains('amanha')) {
      targetDay = base.add(const Duration(days: 1));
    } else if (!lower.contains('hoje')) {
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
        if (lower.contains('segunda')) targetWeekday = DateTime.monday;
        if (lower.contains('terça') || lower.contains('terca')) targetWeekday = DateTime.tuesday;
        if (lower.contains('quarta')) targetWeekday = DateTime.wednesday;
        if (lower.contains('quinta')) targetWeekday = DateTime.thursday;
        if (lower.contains('sexta')) targetWeekday = DateTime.friday;
        if (lower.contains('sábado') || lower.contains('sabado')) targetWeekday = DateTime.saturday;
        if (lower.contains('domingo')) targetWeekday = DateTime.sunday;

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
    final hMatch = RegExp(r'\b(\d{1,2})\s*h(?:(\d{2}))?\b').firstMatch(lower);
    final naturalHourMatch = RegExp(
      r'(?:às|as|para\s+as|para\s+às|at[eé]\s+as)\s*(\d{1,2})(?:\s*(?:horas|da\s+manh[ãa]|da\s+tarde|da\s+noite|da\s+madrugada))?',
    ).firstMatch(lower);

    if (lower.contains('meio-dia') || lower.contains('meio dia')) {
      hour = 12;
    } else if (lower.contains('meia-noite') || lower.contains('meia noite')) {
      hour = 0;
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

    if ((lower.contains('da tarde') || lower.contains('da noite')) && hour >= 1 && hour < 12) {
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
          summary: 'Dados da conta consultados · $scope',
          responsePayload: {'status': 'success', 'data': data},
        );

      case 'schedule_calendar_event':
        final title = (args['title'] ?? 'Bloco de Estudo').toString().trim();
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
          summary: 'Evento agendado · ${_formatTimeBrief(startTime)} · $title',
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
            summary: 'Evento não encontrado para edição',
            responsePayload: {'status': 'not_found', 'message': 'Evento não encontrado.'},
          );
        }

        final oldStart = DateTime.tryParse((target['start_time'] ?? '').toString()) ?? DateTime.now();
        final oldEnd = DateTime.tryParse((target['end_time'] ?? '').toString()) ??
            oldStart.add(const Duration(minutes: 60));
        final newStart = DateTime.tryParse(args['start_time_iso']?.toString() ?? '') ?? oldStart;
        final durMins = (args['duration_minutes'] as num?)?.toInt() ??
            oldEnd.difference(oldStart).inMinutes.clamp(15, 720);
        final newEnd = newStart.add(Duration(minutes: durMins));
        final newTitle = (args['new_title'] ?? target['title'] ?? 'Evento').toString();
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
          summary: 'Calendário atualizado · $newTitle',
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
            summary: 'Evento não encontrado para exclusão',
            responsePayload: {'status': 'not_found'},
          );
        }
        await SupabaseService.deleteCalendarEvent(target['id'].toString());
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Evento removido · ${target['title']}',
          responsePayload: {'status': 'success', 'removed_title': target['title']},
        );

      case 'log_study_session':
        final subject = (args['subject'] ?? 'Estudos').toString().trim();
        final topic = (args['topic'] ?? 'Geral').toString().trim();
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
          summary: 'Sessão registrada · ${_formatDuration(duration)} em $subject',
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
            summary: 'Sessão de estudo não encontrada',
            responsePayload: {'status': 'not_found'},
          );
        }
        final newSubject = (args['subject'] ?? target['subject'] ?? 'Geral').toString();
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
          summary: 'Diário atualizado · $newSubject ($newTopic)',
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
            summary: 'Sessão de estudo não encontrada para exclusão',
            responsePayload: {'status': 'not_found'},
          );
        }
        await SupabaseService.deleteStudySession(target['id'].toString());
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Registro removido do Diário · ${target['topic']}',
          responsePayload: {'status': 'success'},
        );

      case 'set_weekly_goal':
        final hours = (args['hours'] as num?)?.toInt() ?? 25;
        final mins = (args['minutes'] as num?)?.toInt() ?? 0;
        final total = (hours * 60 + mins).clamp(30, 168 * 60);
        await SupabaseService.saveWeeklyGoalMinutes(total);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Meta semanal ajustada para ${SupabaseService.formatGoalDuration(total)}',
          responsePayload: {'status': 'success', 'weekly_goal_minutes': total},
        );

      case 'create_quiz':
        final title = (args['title'] ?? 'Simulado Noesis').toString().trim();
        final subject = (args['subject'] ?? 'Tecnologia').toString().trim();
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
          summary: 'Simulado criado · ${questions.length} questões · $title',
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
            summary: 'Simulado removido · ${targetAttempt.title}',
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
            summary: 'Simulado removido · ${targetGen['title']}',
            responsePayload: {'status': 'success'},
          );
        }
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'failed',
          summary: 'Simulado não encontrado',
          responsePayload: {'status': 'not_found'},
        );

      case 'create_flashcards':
        final title = (args['title'] ?? 'Novo Baralho de Flashcards').toString().trim();
        final subject = (args['subject'] ?? 'Geral').toString().trim();
        final topic = (args['topic'] ?? title).toString().trim();
        final count = ((args['num_cards'] as num?)?.toInt() ?? 5).clamp(1, 30);
        final enrichedTopic = attachmentContext != null && attachmentContext.trim().isNotEmpty
            ? '$topic\n\nUse também o material anexado:\n${attachmentContext.substring(0, math.min(2500, attachmentContext.length))}'
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
            front: val['front']?.toString() ?? 'Pergunta',
            back: val['back']?.toString() ?? 'Resposta',
            tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject, topic],
          );
        }).toList();
        final deck = FlashcardDeck(
          id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          subject: subject,
          description: 'Baralho gerado pelo Noesis AI sobre $topic',
          cards: flashcards,
          createdAt: DateTime.now(),
        );
        await SupabaseService.saveFlashcardDeck(deck);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Baralho criado · ${flashcards.length} cartões · $title',
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
            summary: 'Baralho de flashcards não encontrado',
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
          summary: 'Baralho atualizado · ${updatedDeck.title} (${updatedDeck.cardCount} cartões)',
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
            summary: 'Baralho não encontrado',
            responsePayload: {'status': 'not_found'},
          );
        }
        await SupabaseService.deleteFlashcardDeck(target.id);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Baralho excluído · ${target.title}',
          responsePayload: {'status': 'success'},
        );

      case 'create_notebook_or_note':
        final nbTitle = (args['notebook_title'] ?? 'Caderno Noesis').toString().trim();
        final subject = (args['subject'] ?? 'Geral').toString().trim();
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
            title: noteTitle.isNotEmpty ? noteTitle : 'Nova Anotação',
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
              ? 'Anotação criada · "$noteTitle" em ${notebook.title}'
              : 'Caderno criado · ${notebook.title}',
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
            summary: 'Caderno não encontrado',
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
              summary: 'Anotação não encontrada em ${targetNb.title}',
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
            summary: 'Anotação atualizada · ${updatedNote.title}',
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
          summary: 'Caderno atualizado · ${updatedNb.title}',
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
            summary: 'Caderno não encontrado para exclusão',
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
              summary: 'Anotação excluída · ${targetNote.title}',
              responsePayload: {'status': 'success'},
            );
          }
        }
        await SupabaseService.deleteNotebook(targetNb.id);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Caderno excluído · ${targetNb.title}',
          responsePayload: {'status': 'success'},
        );

      case 'create_roadmap':
        final subject = (args['subject'] ?? 'Geral').toString().trim();
        final goal = (args['goal'] ?? (args['title'] ?? 'Dominar $subject')).toString().trim();
        final level = (args['level'] ?? 'Intermediário').toString().trim();
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
          summary: 'Trilha criada · ${roadmap.title} (${roadmap.steps.length} etapas)',
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
            summary: 'Trilha não encontrada',
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
          summary: 'Trilha atualizada · ${updatedRm.title}',
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
            summary: 'Trilha não encontrada para exclusão',
            responsePayload: {'status': 'not_found'},
          );
        }
        await RoadmapsRepository.deleteRoadmap(target.id);
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'completed',
          summary: 'Trilha excluída · ${target.title}',
          responsePayload: {'status': 'success'},
        );

      default:
        return ExecutedToolResult(
          name: name,
          parameters: args,
          status: 'failed',
          summary: 'Ação desconhecida',
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

    final replyClaimsAction = lowerReply.contains('acabei de') ||
        lowerReply.contains('agendad') ||
        lowerReply.contains('registr') ||
        lowerReply.contains('criei') ||
        lowerReply.contains('adicionei') ||
        lowerReply.contains('excluí') ||
        lowerReply.contains('exclui') ||
        lowerReply.contains('atualizei');

    final userAsksCalendarCreate = (lowerUser.contains('calendario') ||
            lowerUser.contains('calendário') ||
            lowerUser.contains('agend') ||
            lowerUser.contains('aviso') ||
            lowerUser.contains('marqu')) &&
        (lowerUser.contains('cri') ||
            lowerUser.contains('agend') ||
            lowerUser.contains('adicion') ||
            lowerUser.contains('marqu') ||
            lowerUser.contains('coloc'));

    if (userAsksCalendarCreate && !lowerUser.contains('exclu') && !lowerUser.contains('remov')) {
      final startTime = parseNaturalDateTime(userMessage);
      final category = lowerUser.contains('prova')
          ? 'exam'
          : (lowerUser.contains('revis')
              ? 'review'
              : (lowerUser.contains('simulado') ? 'lab' : 'study'));
      final title = lowerUser.contains('prova')
          ? 'Prova'
          : (lowerUser.contains('revis') ? 'Revisão de Estudos' : 'Bloco de Estudos');
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
        (lowerUser.contains('registr') || lowerUser.contains('estudei')) &&
        !lowerUser.contains('exclu')) {
      return executeTool(
        name: 'log_study_session',
        args: {
          'subject': 'Estudos',
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

    if (replyClaimsAction && lowerUser.contains('meta semanal')) {
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

    return null;
  }

  static Future<Map<String, dynamic>> _readAccountScope({
    required String scope,
    required String query,
  }) async {
    final result = <String, dynamic>{};
    bool matches(String text) => query.isEmpty || text.toLowerCase().contains(query);

    if (scope == 'all' || scope == 'weekly_goal') {
      final goal = await SupabaseService.loadWeeklyGoalMinutes();
      final sessions = await SupabaseService.getStudySessions(limit: 100);
      final week = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
      result['weekly_goal'] = {
        'goal_minutes': goal,
        'goal_formatted': SupabaseService.formatGoalDuration(goal),
        'studied_this_week_minutes': week,
        'studied_this_week_formatted': SupabaseService.formatGoalDuration(week),
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
    return '$dd/$mm às $hh:$min';
  }
}
