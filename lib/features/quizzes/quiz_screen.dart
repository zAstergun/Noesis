import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';
import '../../core/supabase_service.dart';
import '../flashcards/models/flashcard_model.dart';
import '../notebooks/models/notebook_model.dart';
import 'data/exam_models_catalog.dart';
import 'data/saved_exams_repository.dart';

String _decodeUtf8Bytes(List<int> bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

class _QuestionSectionBlock {
  const _QuestionSectionBlock({
    required this.label,
    required this.body,
    required this.isSupportingText,
    this.sourceCitation,
  });

  final String? label;
  final String body;
  final bool isSupportingText;
  final String? sourceCitation;
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  static final ValueNotifier<Map<String, dynamic>?> externalQuizStarter = ValueNotifier(null);

  /// Consolida baralhos de flashcards, cadernos de estudo e documento/edital extra em um contexto RAG estruturado.
  static String? buildStudyReferenceContext({
    List<FlashcardDeck> decks = const [],
    List<StudyNotebook> notebooks = const [],
    String? documentText,
    int maxChars = 14000,
  }) {
    final buffer = StringBuffer();

    for (final deck in decks) {
      if (buffer.length >= maxChars) break;
      buffer.writeln('=== BARALHO DE FLASHCARDS ANEXADO: ${deck.title} (Matéria: ${deck.subject}) ===');
      if (deck.description.trim().isNotEmpty) {
        buffer.writeln('Resumo: ${deck.description.trim()}');
      }
      for (final card in deck.cards) {
        if (buffer.length >= maxChars) break;
        final front = card.front.trim();
        final back = card.back.trim();
        if (front.isEmpty && back.isEmpty) continue;
        buffer.writeln('- Frente: $front');
        if (back.isNotEmpty) {
          buffer.writeln('  Verso/Resposta: $back');
        }
        if (card.tags.isNotEmpty) {
          buffer.writeln('  Tags: ${card.tags.join(', ')}');
        }
      }
      buffer.writeln('');
    }

    for (final nb in notebooks) {
      if (buffer.length >= maxChars) break;
      buffer.writeln('=== CADERNO DE ESTUDOS ANEXADO: ${nb.title} (Matéria: ${nb.subject}) ===');
      if (nb.description.trim().isNotEmpty) {
        buffer.writeln('Descrição: ${nb.description.trim()}');
      }
      for (final note in nb.notes) {
        if (buffer.length >= maxChars) break;
        buffer.writeln('--- Anotação: ${note.title} ---');
        if (note.tags.isNotEmpty) {
          buffer.writeln('Tags: ${note.tags.join(', ')}');
        }
        final content = note.content.trim();
        if (content.isNotEmpty) {
          buffer.writeln(content);
        }
      }
      buffer.writeln('');
    }

    final extraDoc = documentText?.trim() ?? '';
    if (extraDoc.isNotEmpty && buffer.length < maxChars) {
      buffer.writeln('=== APOSTILA / DOCUMENTO ANEXADO ===');
      buffer.writeln(extraDoc);
    }

    final result = buffer.toString().trim();
    if (result.isEmpty) return null;
    if (result.length <= maxChars) return result;
    return '${result.substring(0, maxChars)}\n...[conteúdo truncado pelo limite do prompt]';
  }

  static void startQuiz({
    required String title,
    required String subject,
    required List<Map<String, dynamic>> questions,
    String? difficulty,
    int? durationSeconds,
  }) {
    externalQuizStarter.value = {
      'title': title,
      'subject': subject,
      'questions': questions,
      'difficulty': difficulty,
      'durationSeconds': durationSeconds,
    };
  }

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ─── Configuração da Geração ───
  final _subjectController = TextEditingController(text: 'Cybersegurança');
  final _topicController = TextEditingController(text: 'CompTIA Security+ SY0-701 & OWASP Top 10');
  final _documentTextController = TextEditingController();
  final _examSearchController = TextEditingController();
  final _questionCountInputController = TextEditingController(text: '90');

  ExamCategory _selectedCategory = ExamCategory.all;
  ExamModelTemplate? _selectedExamModel = ExamModelsCatalog.models.first;
  bool _applyExamBlueprint = true;
  int _questionCount = 90;
  String _difficulty = 'Avançado / Nível Certificação';
  bool _useDocument = false;
  String? _uploadedFileName;
  List<FlashcardDeck> _availableDecks = [];
  List<StudyNotebook> _availableNotebooks = [];
  final Set<String> _selectedDeckIds = {};
  final Set<String> _selectedNotebookIds = {};
  String? _cachedReferenceContextText;

  // ─── Níveis de Dificuldade Interativos ───
  final List<Map<String, dynamic>> _difficultyLevels = [
    {
      'id': 'Iniciante / Fundamentos',
      'label': 'Iniciante',
      'title': 'Fundamentos & Conceitos',
      'desc': 'Foco em definições, vocabulário e princípios teóricos essenciais.',
      'icon': Icons.school_outlined,
      'color': AsterConstants.menta,
    },
    {
      'id': 'Médio / Prático',
      'label': 'Prático',
      'title': 'Cenários & Hands-On',
      'desc': 'Análise de snippets de código, logs de erro e arquitetura real.',
      'icon': Icons.terminal_rounded,
      'color': AsterConstants.ambar,
    },
    {
      'id': 'Avançado / Nível Certificação',
      'label': 'Certificação',
      'title': 'Exame Oficial & Pegadinhas',
      'desc': 'Nível de exigência idêntico a bancas examinadoras profissionais.',
      'icon': Icons.verified_user_outlined,
      'color': null,
    },
  ];

  // ─── Estado da Execução do Simulado ───
  bool _isGenerating = false;
  bool _isLoadingNextBatch = false;
  String? _batchErrorMessage;
  int _targetQuestionCount = 0;
  int _examSessionToken = 0;
  String? _cachedBlueprintText;
  int _generatedProgress = 0;
  int _generatedTotal = 0;
  List<Map<String, dynamic>>? _activeQuestions;
  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {}; // { questionIndex: selectedOptionIndex }
  final Set<int> _flaggedQuestions = {}; // Questões marcadas para revisão
  final bool _showExplanation = true;
  int _remainingSeconds = 38 * 60 + 12;
  int _initialTotalSeconds = 38 * 60 + 12;
  late final ValueNotifier<int> _timerNotifier;
  Timer? _examTimer;
  bool _showSavedHistory = false;
  List<SavedExamAttempt> _savedAttempts = [];
  bool _loadingSavedAttempts = false;
  String? _historyGroupFilter;
  String? _currentAttemptId;
  bool _hasShownTimeUpAlert = false;
  bool _timeExpiredThisSession = false;
  bool _isReviewingSavedAttempt = false;

  @override
  void initState() {
    super.initState();
    _timerNotifier = ValueNotifier<int>(_remainingSeconds);
    _activeQuestions = null;
    QuizScreen.externalQuizStarter.addListener(_onExternalQuizStarted);
    _refreshSavedAttempts();
    _loadStudyResources();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (QuizScreen.externalQuizStarter.value != null) {
        _onExternalQuizStarted();
      }
    });
  }

  void _setQuestionCount(int value) {
    final clamped = value.clamp(3, GeminiService.quizMaxQuestions);
    setState(() {
      _questionCount = clamped;
      _questionCountInputController.text = '$clamped';
    });
  }

  void _selectExamModel(ExamModelTemplate? model) {
    setState(() {
      _selectedExamModel = model;
      if (model != null) {
        _subjectController.text = model.subject;
        _topicController.text = model.topic;
        _difficulty = model.difficulty;
        _applyExamBlueprint = true;
        _questionCount = model.recommendedCount.clamp(3, GeminiService.quizMaxQuestions);
        _questionCountInputController.text = '$_questionCount';
      }
    });
  }

  void _onExternalQuizStarted() {
    final data = QuizScreen.externalQuizStarter.value;
    if (data != null && mounted) {
      final loadedQuestions = List<Map<String, dynamic>>.from(data['questions']);
      final count = loadedQuestions.length.clamp(1, GeminiService.quizMaxQuestions);
      final customDuration = data['durationSeconds'] as int?;
      setState(() {
        _examSessionToken++;
        _isLoadingNextBatch = false;
        _batchErrorMessage = null;
        _currentAttemptId = null;
        _hasShownTimeUpAlert = false;
        _timeExpiredThisSession = false;
        _isReviewingSavedAttempt = false;
        _selectedExamModel = null;
        _subjectController.text = data['subject'] ?? 'Geral';
        _topicController.text = data['title'] ?? 'Simulado Noesis AI';
        _difficulty = data['difficulty'] ?? 'Médio / Prático';
        _activeQuestions = loadedQuestions;
        _targetQuestionCount = loadedQuestions.length;
        _questionCount = count.clamp(3, GeminiService.quizMaxQuestions);
        _questionCountInputController.text = '$_questionCount';
        _currentQuestionIndex = 0;
        _userAnswers.clear();
        _flaggedQuestions.clear();
        _initialTotalSeconds = customDuration ?? (loadedQuestions.length * 120);
        _remainingSeconds = _initialTotalSeconds;
        _startTimer();
      });
      QuizScreen.externalQuizStarter.value = null;
    }
  }

  void _loadDemoMockQuiz() {
    setState(() {
      _examSessionToken++;
      _isLoadingNextBatch = false;
      _batchErrorMessage = null;
      _currentAttemptId = null;
      _hasShownTimeUpAlert = false;
      _timeExpiredThisSession = false;
      _isReviewingSavedAttempt = false;
      _selectedExamModel = ExamModelsCatalog.models.first;
      _subjectController.text = 'Cybersegurança';
      _topicController.text = 'CompTIA Security+ SY0-701';
      _difficulty = 'Avançado / Nível Certificação';
      _questionCount = 3;
      _questionCountInputController.text = '3';
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _flaggedQuestions.clear();
      _activeQuestions = [
        {
          'question':
              'Uma API interna expõe o endpoint /fetch?target= que busca o conteúdo de qualquer URL e o devolve ao cliente. Durante um pentest, o analista obteve credenciais temporárias da instância EC2 acessando o serviço de metadados. Qual medida melhor mitiga a vulnerabilidade na raiz?',
          'code_snippet':
              "1  # handler.py\n2  url = request.args.get('target')\n3  resp = requests.get(url, timeout=3)\n4  return resp.text  # 200 OK",
          'options': [
            'Aplicar rate limiting no endpoint e manter a validação de URL por lista negra de IPs internos.',
            'Validar o destino com allow-list de hosts, bloquear redirecionamentos e resolver DNS antes da requisição (pinning).',
            'Mover o serviço para uma sub-rede pública e desabilitar o IMDSv1 apenas no bastion host.',
            'Sanitizar o parâmetro com HTML-encoding para impedir injeção de payloads no corpo da resposta.',
          ],
          'correct_index': 1,
          'explanation':
              'O cenário descreve um SSRF clássico: o servidor faz requisições para URLs controladas pelo usuário. A mitigação robusta é allow-list de destinos + bloqueio de redirects + resolução DNS prévia para evitar DNS rebinding. A alternativa A usa lista negra (facilmente contornável via 169.254.169.254 em formatos alternativos). C e D confundem o vetor com XSS / arquitetura de rede.',
          'rag_sources': ['OWASP Top 10 2021 · A10', 'AWS IMDSv2 docs', 'CompTIA Security+ SY0-701'],
        },
        {
          'question':
              'Em uma arquitetura de microsserviços, como garantir que tokens JWT assinados com algoritmo assimétrico (RS256) não sejam forçados a validação insegura?',
          'code_snippet':
              "1  # jwt_verify.py\n2  header = jwt.get_unverified_header(token)\n3  # Vulnerabilidade: confiar cegamente no alg do cabeçalho\n4  jwt.decode(token, verify=True)",
          'options': [
            'Forçar explicitamente o algoritmo aceito (algorithms=[\'RS256\']) no momento da validação pelo consumidor.',
            'Permitir que o cliente escolha entre HS256 e RS256 dinamicamente.',
            'Codificar a chave pública em Base64 na URL de callback.',
            'Desativar a checagem de expiração do token (exp claim).',
          ],
          'correct_index': 0,
          'explanation':
              'Vulnerabilidades de confusão de algoritmo (como forçar HS256 com chave pública como segredo) são mitigadas restringindo os algoritmos permitidos na chamada de decode.',
          'rag_sources': ['RFC 7519', 'NIST SP 800-63B'],
        },
      ];
      _targetQuestionCount = _activeQuestions!.length;
      _userAnswers[0] = 1; // Selecionou B no mock
      _initialTotalSeconds = 38 * 60 + 12;
      _remainingSeconds = _initialTotalSeconds;
      _startTimer();
    });
  }

  void _startTimer() {
    _examTimer?.cancel();
    _timerNotifier.value = _remainingSeconds;
    if (_remainingSeconds <= 0) return;
    _examTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _timerNotifier.value = _remainingSeconds;
        if (_remainingSeconds == 0) {
          _examTimer?.cancel();
          _timeExpiredThisSession = true;
          _handleTimeExpired();
        }
      } else {
        _examTimer?.cancel();
      }
    });
  }

  void _handleTimeExpired() {
    if (!mounted || _activeQuestions == null || _hasShownTimeUpAlert) return;
    _hasShownTimeUpAlert = true;
    setState(() {});
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AsterConstants.coral.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_outlined, color: AsterConstants.coral, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tempo Esgotado!',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AsterTheme.text(context),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'O tempo previsto para este simulado chegou ao fim (00:00). Você pode finalizar agora para salvar o resultado e ver o comparativo com a IA, ou continuar revisando.',
          style: GoogleFonts.manrope(fontSize: 13.5, height: 1.5, color: AsterTheme.textMuted(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continuar Revisando'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showExamCompletionDialog();
            },
            icon: const Icon(Icons.analytics_outlined, size: 17),
            label: const Text('Ver Resultado & Review IA'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshSavedAttempts({bool forceRemote = false}) async {
    if (_loadingSavedAttempts) return;
    _loadingSavedAttempts = true;
    final list = await SavedExamsRepository.loadAll(forceRemote: forceRemote);
    _loadingSavedAttempts = false;
    if (mounted) {
      setState(() {
        _savedAttempts = list;
      });
    }
  }

  Future<void> _loadStudyResources() async {
    try {
      final results = await Future.wait([
        SupabaseService.getFlashcardDecks(),
        SupabaseService.getNotebooks(),
      ]);
      if (mounted) {
        setState(() {
          _availableDecks = results[0] as List<FlashcardDeck>;
          _availableNotebooks = results[1] as List<StudyNotebook>;
        });
      }
    } catch (_) {}
  }

  Future<void> _showAttachFlashcardsDialog() async {
    if (_availableDecks.isEmpty) {
      await _loadStudyResources();
    }
    if (!mounted) return;
    final tempSelected = Set<String>.from(_selectedDeckIds);
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = _availableDecks.where((d) {
            if (search.trim().isEmpty) return true;
            final q = search.trim().toLowerCase();
            return d.title.toLowerCase().contains(q) || d.subject.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
            title: Row(
              children: [
                Icon(Icons.style_outlined, color: AsterTheme.primary(context), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Anexar Baralhos de Flashcards',
                    style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (v) => setDialogState(() => search = v),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      hintText: 'Filtrar baralhos por nome ou matéria...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum baralho de flashcards encontrado.',
                              style: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.textMuted(context)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, idx) {
                              final deck = filtered[idx];
                              final checked = tempSelected.contains(deck.id);
                              return CheckboxListTile(
                                value: checked,
                                activeColor: AsterTheme.primary(context),
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      tempSelected.add(deck.id);
                                    } else {
                                      tempSelected.remove(deck.id);
                                    }
                                  });
                                },
                                title: Text(
                                  deck.title,
                                  style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  '${deck.subject} · ${deck.cards.length} cartões',
                                  style: GoogleFonts.manrope(fontSize: 11.5, color: AsterTheme.textMuted(context)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDeckIds
                      ..clear()
                      ..addAll(tempSelected);
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text('Aplicar (${tempSelected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAttachNotebooksDialog() async {
    if (_availableNotebooks.isEmpty) {
      await _loadStudyResources();
    }
    if (!mounted) return;
    final tempSelected = Set<String>.from(_selectedNotebookIds);
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = _availableNotebooks.where((n) {
            if (search.trim().isEmpty) return true;
            final q = search.trim().toLowerCase();
            return n.title.toLowerCase().contains(q) || n.subject.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
            title: Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: AsterConstants.menta, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Anexar Cadernos de Estudo',
                    style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (v) => setDialogState(() => search = v),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 18),
                      hintText: 'Filtrar cadernos por título ou matéria...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum caderno encontrado.',
                              style: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.textMuted(context)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, idx) {
                              final nb = filtered[idx];
                              final checked = tempSelected.contains(nb.id);
                              return CheckboxListTile(
                                value: checked,
                                activeColor: AsterConstants.menta,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      tempSelected.add(nb.id);
                                    } else {
                                      tempSelected.remove(nb.id);
                                    }
                                  });
                                },
                                title: Text(
                                  nb.title,
                                  style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  '${nb.subject} · ${nb.notes.length} anotações',
                                  style: GoogleFonts.manrope(fontSize: 11.5, color: AsterTheme.textMuted(context)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedNotebookIds
                      ..clear()
                      ..addAll(tempSelected);
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text('Aplicar (${tempSelected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<SavedExamAttempt> _saveCurrentAttempt({String? aiReviewMarkdown}) async {
    final questions = List<Map<String, dynamic>>.from(_activeQuestions ?? const []);
    final attemptId = _currentAttemptId ?? 'sim-${DateTime.now().millisecondsSinceEpoch}';
    _currentAttemptId = attemptId;
    final existing = _savedAttempts.where((a) => a.id == attemptId).firstOrNull;
    final elapsedSeconds = (_initialTotalSeconds - _remainingSeconds).clamp(0, _initialTotalSeconds);
    final subjectText = _subjectController.text.trim().isEmpty ? 'Geral' : _subjectController.text.trim();
    final topicText = _topicController.text.trim().isEmpty ? 'Simulado' : _topicController.text.trim();

    final attempt = SavedExamsRepository.buildAttempt(
      id: attemptId,
      examModelId: _selectedExamModel?.id,
      examModelName: _selectedExamModel?.name,
      subject: subjectText,
      topic: topicText,
      difficulty: _difficulty,
      questions: questions,
      userAnswers: Map<int, int>.from(_userAnswers),
      elapsedSeconds: elapsedSeconds,
      targetTotalCount: _targetQuestionCount > 0 ? _targetQuestionCount : questions.length,
      timeExpired: _timeExpiredThisSession,
      aiReviewMarkdown: aiReviewMarkdown ?? existing?.aiReviewMarkdown,
    );

    final updatedList = await SavedExamsRepository.saveAttempt(attempt);
    if (mounted) {
      setState(() {
        _savedAttempts = updatedList;
      });
    }
    return attempt;
  }

  void _openSavedAttemptForReview(SavedExamAttempt attempt) {
    final model = attempt.examModelId != null ? ExamModelsCatalog.findByName(attempt.examModelId) : null;
    setState(() {
      _examSessionToken++;
      _isLoadingNextBatch = false;
      _batchErrorMessage = null;
      _currentAttemptId = attempt.id;
      _hasShownTimeUpAlert = false;
      _timeExpiredThisSession = attempt.timeExpired;
      _isReviewingSavedAttempt = true;
      _selectedExamModel = model ?? ExamModelsCatalog.findByName(attempt.examModelName);
      _subjectController.text = attempt.subject;
      _topicController.text = attempt.topic;
      _difficulty = attempt.difficulty;
      _activeQuestions = attempt.questions.map((q) => Map<String, dynamic>.from(q)).toList();
      _targetQuestionCount = attempt.targetTotalCount;
      _questionCount = attempt.questions.length.clamp(3, GeminiService.quizMaxQuestions);
      _questionCountInputController.text = '$_questionCount';
      _currentQuestionIndex = 0;
      _userAnswers
        ..clear()
        ..addAll(attempt.userAnswers);
      _flaggedQuestions.clear();
      _examTimer?.cancel();
      _initialTotalSeconds = attempt.elapsedSeconds;
      _remainingSeconds = attempt.elapsedSeconds;
      _timerNotifier.value = _remainingSeconds;
      _showSavedHistory = false;
    });
  }

  void _retakeSavedAttempt(SavedExamAttempt attempt) {
    final model = attempt.examModelId != null ? ExamModelsCatalog.findByName(attempt.examModelId) : null;
    setState(() {
      _examSessionToken++;
      _isLoadingNextBatch = false;
      _batchErrorMessage = null;
      _currentAttemptId = null;
      _hasShownTimeUpAlert = false;
      _timeExpiredThisSession = false;
      _isReviewingSavedAttempt = false;
      _selectedExamModel = model ?? ExamModelsCatalog.findByName(attempt.examModelName);
      _subjectController.text = attempt.subject;
      _topicController.text = attempt.topic;
      _difficulty = attempt.difficulty;
      _activeQuestions = attempt.questions.map((q) => Map<String, dynamic>.from(q)).toList();
      _targetQuestionCount = attempt.questions.length;
      _questionCount = attempt.questions.length.clamp(3, GeminiService.quizMaxQuestions);
      _questionCountInputController.text = '$_questionCount';
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _flaggedQuestions.clear();
      _initialTotalSeconds = attempt.questions.length * 120;
      _remainingSeconds = _initialTotalSeconds;
      _showSavedHistory = false;
      _startTimer();
    });
  }

  void _openSavedAttemptCompletionReport(SavedExamAttempt attempt) {
    final previousForGroup = SavedExamsRepository.historyForGroup(
      _savedAttempts,
      attempt.groupKey,
      excludeId: attempt.id,
    );
    showDialog(
      context: context,
      builder: (ctx) => _ExamCompletionDialog(
        attemptId: attempt.id,
        examModelName: attempt.examModelName == 'Modo Livre' ? null : attempt.examModelName,
        subject: attempt.subject,
        topic: attempt.topic,
        questions: attempt.questions,
        targetTotalCount: attempt.targetTotalCount,
        userAnswers: attempt.userAnswers,
        elapsedSeconds: attempt.elapsedSeconds,
        initialAiReview: attempt.aiReviewMarkdown,
        previousGroupAttempts: previousForGroup,
        onAiReviewReady: (markdown) {
          SavedExamsRepository.updateAiReview(attempt.id, markdown).then((_) {
            _refreshSavedAttempts();
          });
        },
        onJumpToQuestion: (index) {
          Navigator.of(ctx).pop();
          _openSavedAttemptForReview(attempt);
          setState(() => _currentQuestionIndex = index);
        },
        onNewSimulado: () {
          Navigator.of(ctx).pop();
          setState(() {
            _activeQuestions = null;
            _showSavedHistory = false;
          });
        },
      ),
    );
  }

  Future<void> _deleteSavedAttempt(String attemptId) async {
    final updated = await SavedExamsRepository.deleteAttempt(attemptId);
    if (mounted) {
      setState(() {
        _savedAttempts = updated;
        if (_historyGroupFilter != null &&
            !_savedAttempts.any((a) => a.groupKey == _historyGroupFilter)) {
          _historyGroupFilter = null;
        }
      });
    }
  }

  String _formatTimer(int totalSecs) {
    final h = totalSecs ~/ 3600;
    final m = ((totalSecs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$m:$s';
    }
    return '$m:$s';
  }

  String _formatEstimatedMinutes(int totalMinutes) {
    if (totalMinutes < 60) return '~$totalMinutes min estimados';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '~${h}h estimadas' : '~${h}h ${m.toString().padLeft(2, '0')}min estimados';
  }

  Future<void> _pickDocumentFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'json', 'pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        _uploadedFileName = file.name;

        try {
          final bytes = await file.readAsBytes();
          final text = await compute(_decodeUtf8Bytes, bytes);
          _documentTextController.text = text;
        } catch (_) {
          final len = file.lengthSync() ?? 0;
          _documentTextController.text = '[Arquivo "${file.name}" carregado (${(len / 1024).toStringAsFixed(1)} KB)]';
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar arquivo: $e')),
        );
      }
    }
  }

  Color _resolveExamAccent(Color raw) =>
      raw == AsterConstants.lavanda ? AsterTheme.primary(context) : raw;

  Color _onAccentColor(Color accent) =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.light
          ? const Color(0xFF111111)
          : Colors.white;

  Future<void> _showBlueprintPreviewDialog(ExamModelTemplate model) async {
    final content = await ExamModelsCatalog.loadBlueprint(model);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final modelAccent = _resolveExamAccent(model.accent);
        final textCol = AsterTheme.text(ctx);
        final mutedCol = AsterTheme.textMuted(ctx);
        final primaryCol = AsterTheme.primary(ctx);
        final insetCol = AsterTheme.surfaceInset(ctx);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          backgroundColor: AsterTheme.card(ctx),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: modelAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(model.icon, color: modelAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textCol,
                              ),
                            ),
                            Text(
                              '${model.category.label} · ${model.optionsFormat} · Guia Oficial (.md)',
                              style: GoogleFonts.manrope(fontSize: 11, color: mutedCol),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close_rounded, color: mutedCol),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AsterTheme.surfaceAlt(ctx),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      ),
                      child: content == null
                          ? Center(
                              child: Text(
                                'Não foi possível carregar o guia ${model.assetPath}.',
                                style: GoogleFonts.manrope(color: mutedCol),
                              ),
                            )
                          : SingleChildScrollView(
                              child: MarkdownBody(
                                data: content,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  h1: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w900, color: textCol),
                                  h2: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: primaryCol),
                                  h3: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: textCol),
                                  p: GoogleFonts.manrope(fontSize: 12.5, height: 1.5, color: textCol),
                                  strong: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: textCol),
                                  em: GoogleFonts.manrope(fontStyle: FontStyle.italic, color: mutedCol),
                                  listBullet: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: primaryCol),
                                  blockquote: GoogleFonts.manrope(fontSize: 12.5, height: 1.45, color: textCol),
                                  blockquoteDecoration: BoxDecoration(
                                    color: primaryCol.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(left: BorderSide(color: primaryCol, width: 3.5)),
                                  ),
                                  blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  tableHead: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: textCol),
                                  tableBody: GoogleFonts.manrope(fontSize: 12, height: 1.4, color: textCol),
                                  tableBorder: TableBorder.all(color: insetCol, width: 1),
                                  tableCellsDecoration: BoxDecoration(
                                    color: AsterTheme.card(ctx).withValues(alpha: 0.55),
                                  ),
                                  tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  code: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: primaryCol,
                                    backgroundColor: insetCol.withValues(alpha: 0.7),
                                  ),
                                  horizontalRuleDecoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: insetCol, width: 1)),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SoftClayPillButton(
                        text: 'Aplicar Modelo (${model.recommendedCount} Q)',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () {
                          _selectExamModel(model);
                          _setQuestionCount(model.recommendedCount);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuestionNavigatorDialog() {
    final totalQ = _activeQuestions?.length ?? 0;
    if (totalQ == 0) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          backgroundColor: AsterTheme.card(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 540),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_view_rounded, color: AsterTheme.primary(context), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mapa da Prova ($totalQ questões)',
                          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w900, color: AsterTheme.text(context)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close_rounded, color: AsterTheme.textMuted(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildLegendDot('Atual', AsterTheme.primary(context)),
                      _buildLegendDot('Respondida (${_userAnswers.length})', AsterConstants.menta),
                      _buildLegendDot('Revisão (${_flaggedQuestions.length})', AsterConstants.ambar),
                      _buildLegendDot('Pendente (${totalQ - _userAnswers.length})', AsterTheme.surfaceInset(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 56,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: totalQ,
                      itemBuilder: (context, idx) {
                        final isCurrent = idx == _currentQuestionIndex;
                        final isFlagged = _flaggedQuestions.contains(idx);
                        final isAnswered = _userAnswers.containsKey(idx);

                        Color bg = AsterTheme.surfaceAlt(context);
                        Color fg = AsterTheme.text(context);
                        Color? border;

                        if (isCurrent) {
                          bg = AsterTheme.primary(context);
                          fg = AsterTheme.onPrimary(context);
                        } else if (isFlagged) {
                          bg = AsterConstants.ambar.withValues(alpha: 0.18);
                          fg = AsterConstants.ambar;
                          border = AsterConstants.ambar;
                        } else if (isAnswered) {
                          bg = AsterConstants.menta.withValues(alpha: 0.18);
                          fg = AsterConstants.menta;
                          border = AsterConstants.menta.withValues(alpha: 0.4);
                        }

                        return InkWell(
                          onTap: () {
                            setState(() => _currentQuestionIndex = idx);
                            Navigator.of(ctx).pop();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(10),
                              border: border != null ? Border.all(color: border, width: 1.2) : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.textMuted(context)),
        ),
      ],
    );
  }

  Future<void> _startGenerateQuiz() async {
    final isCustom = GeminiService.provider == 'custom';
    final hasKey = GeminiService.apiKey != null && GeminiService.apiKey!.trim().isNotEmpty;

    if (!isCustom && !hasKey) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 5),
            content: Text('Configure sua chave de API para ${GeminiService.currentProvider.label} em Configurações.'),
            action: SnackBarAction(
              label: 'Testar Demo',
              textColor: Colors.white,
              onPressed: _loadDemoMockQuiz,
            ),
          ),
        );
      return;
    }

    final sessionToken = ++_examSessionToken;

    setState(() {
      _isGenerating = true;
      _isLoadingNextBatch = false;
      _batchErrorMessage = null;
      _currentAttemptId = null;
      _hasShownTimeUpAlert = false;
      _timeExpiredThisSession = false;
      _isReviewingSavedAttempt = false;
      _targetQuestionCount = _questionCount;
      _generatedProgress = 0;
      _generatedTotal = _questionCount;
      _activeQuestions = null;
      _userAnswers.clear();
      _flaggedQuestions.clear();
      _currentQuestionIndex = 0;
    });

    try {
      String? blueprintText;
      if (_selectedExamModel != null && _applyExamBlueprint) {
        blueprintText = await ExamModelsCatalog.loadBlueprint(_selectedExamModel!);
      }
      _cachedBlueprintText = blueprintText;

      final selectedDecks = _availableDecks
          .where((d) => _selectedDeckIds.contains(d.id))
          .toList();
      final selectedNotebooks = _availableNotebooks
          .where((n) => _selectedNotebookIds.contains(n.id))
          .toList();
      final docText = _useDocument && _documentTextController.text.trim().isNotEmpty
          ? _documentTextController.text.trim()
          : null;
      _cachedReferenceContextText = QuizScreen.buildStudyReferenceContext(
        decks: selectedDecks,
        notebooks: selectedNotebooks,
        documentText: docText,
      );

      final firstBatchSize =
          _targetQuestionCount > GeminiService.quizBatchSize ? GeminiService.quizBatchSize : _targetQuestionCount;

      final firstBatch = await GeminiService.generateQuizBatch(
        subject: _subjectController.text.trim().isEmpty ? 'Geral' : _subjectController.text.trim(),
        topic: _topicController.text.trim().isEmpty ? 'Conhecimentos Gerais' : _topicController.text.trim(),
        referenceDocumentText: _cachedReferenceContextText,
        examModelName: _selectedExamModel?.name,
        examBlueprintText: blueprintText,
        batchCount: firstBatchSize,
        totalTarget: _targetQuestionCount,
        startNumber: 1,
        batchIndex: 1,
        difficulty: _difficulty,
      );

      if (!mounted || sessionToken != _examSessionToken) return;

      setState(() {
        _activeQuestions = List<Map<String, dynamic>>.from(firstBatch);
        _generatedProgress = _activeQuestions!.length;
        _initialTotalSeconds = _targetQuestionCount * 120;
        _remainingSeconds = _initialTotalSeconds;
        _startTimer();
      });

      if (_activeQuestions!.length < _targetQuestionCount) {
        // Continua carregando os próximos lotes em segundo plano mantendo o total alvo intacto
        unawaited(_continueLoadingRemainingBatches(sessionToken));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar simulado: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _continueLoadingRemainingBatches(
    int sessionToken, {
    bool advanceToNewBatch = false,
  }) async {
    if (_isLoadingNextBatch) return;
    if (!mounted || sessionToken != _examSessionToken) return;

    setState(() {
      _isLoadingNextBatch = true;
      _batchErrorMessage = null;
    });

    int batchIndex = ((_activeQuestions?.length ?? 0) / GeminiService.quizBatchSize).ceil() + 1;

    try {
      while (mounted &&
          sessionToken == _examSessionToken &&
          _activeQuestions != null &&
          _activeQuestions!.length < _targetQuestionCount) {
        // Pausa gentil entre chamadas para evitar rate limit (429) de RPM
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        if (!mounted || sessionToken != _examSessionToken || _activeQuestions == null) break;

        final currentLoaded = _activeQuestions!.length;
        final remaining = _targetQuestionCount - currentLoaded;
        final nextCount =
            remaining > GeminiService.quizBatchSize ? GeminiService.quizBatchSize : remaining;

        final recentStems = _activeQuestions!
            .map((q) => (q['question'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.length > 65 ? s.substring(0, 65) : s)
            .toList();

        final nextBatch = await GeminiService.generateQuizBatch(
          subject: _subjectController.text.trim().isEmpty ? 'Geral' : _subjectController.text.trim(),
          topic: _topicController.text.trim().isEmpty ? 'Conhecimentos Gerais' : _topicController.text.trim(),
          referenceDocumentText: _cachedReferenceContextText,
          examModelName: _selectedExamModel?.name,
          examBlueprintText: _cachedBlueprintText,
          batchCount: nextCount,
          totalTarget: _targetQuestionCount,
          startNumber: currentLoaded + 1,
          batchIndex: batchIndex,
          difficulty: _difficulty,
          recentStems: recentStems,
        );

        if (!mounted || sessionToken != _examSessionToken || _activeQuestions == null) break;

        setState(() {
          final prevLength = _activeQuestions!.length;
          for (final q in nextBatch) {
            if (_activeQuestions!.length >= _targetQuestionCount) break;
            _activeQuestions!.add(q);
          }
          _generatedProgress = _activeQuestions!.length;
          if (advanceToNewBatch && _activeQuestions!.length > prevLength) {
            _currentQuestionIndex = prevLength;
            advanceToNewBatch = false;
          }
        });
        batchIndex++;
      }
    } catch (e) {
      if (mounted && sessionToken == _examSessionToken) {
        setState(() {
          _batchErrorMessage = e.toString();
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 6),
              content: Text('Pausa no lote ${_activeQuestions?.length ?? 0}/$_targetQuestionCount: $e'),
              action: SnackBarAction(
                label: 'Tentar Próximo Lote',
                textColor: Colors.white,
                onPressed: () => _continueLoadingRemainingBatches(sessionToken),
              ),
            ),
          );
      }
    } finally {
      if (mounted && sessionToken == _examSessionToken) {
        setState(() => _isLoadingNextBatch = false);
      }
    }
  }

  Future<void> _showExamCompletionDialog() async {
    final questions = _activeQuestions ?? [];
    if (questions.isEmpty) return;

    final elapsedSeconds = (_initialTotalSeconds - _remainingSeconds).clamp(0, _initialTotalSeconds);
    final subjectText = _subjectController.text.trim().isEmpty ? 'Geral' : _subjectController.text.trim();
    final topicText = _topicController.text.trim().isEmpty ? 'Simulado' : _topicController.text.trim();

    String? attemptId = _currentAttemptId;
    String? savedAiReview;
    if (_isReviewingSavedAttempt && attemptId != null) {
      savedAiReview = _savedAttempts.where((a) => a.id == attemptId).firstOrNull?.aiReviewMarkdown;
    } else {
      final saved = await _saveCurrentAttempt();
      attemptId = saved.id;
      savedAiReview = saved.aiReviewMarkdown;
    }

    if (!mounted) return;
    final groupKey = SavedExamsRepository.computeGroupKey(
      examModelId: _selectedExamModel?.id,
      examModelName: _selectedExamModel?.name,
      subject: subjectText,
      topic: topicText,
    );
    final previousForGroup = SavedExamsRepository.historyForGroup(
      _savedAttempts,
      groupKey,
      excludeId: attemptId,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return _ExamCompletionDialog(
          attemptId: attemptId,
          examModelName: _selectedExamModel?.name,
          subject: subjectText,
          topic: topicText,
          questions: List<Map<String, dynamic>>.from(questions),
          targetTotalCount: _targetQuestionCount > 0 ? _targetQuestionCount : questions.length,
          userAnswers: Map<int, int>.from(_userAnswers),
          elapsedSeconds: elapsedSeconds,
          initialAiReview: savedAiReview,
          previousGroupAttempts: previousForGroup,
          onAiReviewReady: attemptId == null
              ? null
              : (markdown) {
                  SavedExamsRepository.updateAiReview(attemptId!, markdown).then((_) {
                    _refreshSavedAttempts();
                  });
                },
          onJumpToQuestion: (index) {
            Navigator.of(ctx).pop();
            setState(() => _currentQuestionIndex = index);
          },
          onNewSimulado: () {
            Navigator.of(ctx).pop();
            setState(() {
              _examSessionToken++;
              _isLoadingNextBatch = false;
              _batchErrorMessage = null;
              _currentAttemptId = null;
              _isReviewingSavedAttempt = false;
              _activeQuestions = null;
              _examTimer?.cancel();
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    QuizScreen.externalQuizStarter.removeListener(_onExternalQuizStarted);
    _subjectController.dispose();
    _topicController.dispose();
    _documentTextController.dispose();
    _examSearchController.dispose();
    _questionCountInputController.dispose();
    _timerNotifier.dispose();
    _examTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isExamActive = _activeQuestions != null && _activeQuestions!.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isExamActive) ...[
            _buildSimuladoTopHeader(isDesktop),
            const SizedBox(height: 18),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildQuestionLeftPanel()),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: _buildAlternativesRightPanel()),
                ],
              )
            else ...[
              _buildQuestionLeftPanel(),
              const SizedBox(height: 16),
              _buildAlternativesRightPanel(),
            ],
            const SizedBox(height: 22),
            _buildBottomExamControls(),
          ] else if (_showSavedHistory) ...[
            _buildSavedHistoryCard(isDesktop),
          ] else ...[
            _buildGeneratorCard(isDesktop),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Header do Simulado em Andamento ───
  Widget _buildSimuladoTopHeader(bool isDesktop) {
    final loadedQ = _activeQuestions?.length ?? 1;
    final targetQ = _targetQuestionCount > loadedQ ? _targetQuestionCount : loadedQ;
    final currQ = _currentQuestionIndex + 1;
    final progress = currQ / targetQ;

    final subjectStr = _subjectController.text.trim().isEmpty ? 'GERAL' : _subjectController.text.trim().toUpperCase();
    final topicStr = _topicController.text.trim().isEmpty ? 'SIMULADO TÉCNICO' : _topicController.text.trim().toUpperCase();
    final isFlagged = _flaggedQuestions.contains(_currentQuestionIndex);
    final hasMoreBatches = loadedQ < targetQ;

    return Column(
      children: [
        Row(
          children: [
            const NoesisCollapsedMenuSpacer(width: 82),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIMULADO · $subjectStr · $topicStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Questão $currQ / $targetQ',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AsterTheme.text(context),
                        ),
                      ),
                      if (hasMoreBatches)
                        InkWell(
                          onTap: _isLoadingNextBatch
                              ? null
                              : () => _continueLoadingRemainingBatches(_examSessionToken),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_batchErrorMessage != null ? AsterConstants.coral : AsterTheme.primary(context))
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLoadingNextBatch)
                                  SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(strokeWidth: 1.8, color: AsterTheme.primary(context)),
                                  )
                                else
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 13,
                                    color: _batchErrorMessage != null ? AsterConstants.coral : AsterTheme.primary(context),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  _isLoadingNextBatch
                                      ? 'Carregando $loadedQ/$targetQ...'
                                      : (_batchErrorMessage != null
                                          ? 'Pausado em $loadedQ/$targetQ · Retomar'
                                          : '$loadedQ/$targetQ carregadas · +Lote'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _batchErrorMessage != null ? AsterConstants.coral : AsterTheme.primary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isReviewingSavedAttempt)
                        const SoftClayTag(
                          label: 'Modo Revisão',
                          color: AsterConstants.menta,
                        ),
                      if (_selectedExamModel != null)
                        SoftClayTag(
                          label: _selectedExamModel!.name,
                          color: _selectedExamModel!.accent,
                        ),
                      SoftClayTag(
                        label: _subjectController.text.trim().isNotEmpty ? _subjectController.text.trim() : 'Geral',
                        color: AsterConstants.ambar,
                      ),
                      SoftClayTag(
                        label: _difficulty.split(' / ').first,
                        color: AsterTheme.primary(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Botão Finalizar / Revisão IA antecipada
            Tooltip(
              message: 'Ver comparativo de acertos e análise da IA',
              child: InkWell(
                onTap: _showExamCompletionDialog,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AsterConstants.menta.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 15, color: AsterConstants.menta),
                      if (isDesktop) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Encerrar & Review',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.menta,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botão Mapa de Questões (Essencial para simulados de 30 a 120 questões)
            Tooltip(
              message: 'Abrir mapa completo das questões',
              child: InkWell(
                onTap: _showQuestionNavigatorDialog,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AsterTheme.card(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    boxShadow: AsterConstants.claySubtleShadow,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.grid_view_rounded, size: 15, color: AsterTheme.primary(context)),
                      if (isDesktop) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Mapa ($currQ/$loadedQ)',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Timer Pill
            ValueListenableBuilder<int>(
              valueListenable: _timerNotifier,
              builder: (context, secs, _) {
                final isExpired = !_isReviewingSavedAttempt && (secs <= 0 || _timeExpiredThisSession);
                final isWarning = !_isReviewingSavedAttempt && !isExpired && secs <= 60;
                final pillColor = isExpired
                    ? AsterConstants.coral.withValues(alpha: 0.12)
                    : (isWarning ? AsterConstants.ambar.withValues(alpha: 0.14) : AsterTheme.card(context));
                final iconColor = isExpired
                    ? AsterConstants.coral
                    : (isWarning ? AsterConstants.ambar : AsterTheme.primary(context));
                final textColor = isExpired ? AsterConstants.coral : AsterTheme.text(context);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    boxShadow: AsterConstants.claySubtleShadow,
                    border: isExpired ? Border.all(color: AsterConstants.coral.withValues(alpha: 0.55)) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                        size: 16,
                        color: iconColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isExpired ? '00:00 · Esgotado' : _formatTimer(secs),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),

            // Botão Flag (Marcar para Revisão)
            Tooltip(
              message: isFlagged ? 'Desmarcar revisão' : 'Marcar para revisão',
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isFlagged) {
                      _flaggedQuestions.remove(_currentQuestionIndex);
                    } else {
                      _flaggedQuestions.add(_currentQuestionIndex);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isFlagged ? AsterConstants.ambar.withValues(alpha: 0.15) : AsterTheme.card(context),
                    shape: BoxShape.circle,
                    boxShadow: AsterConstants.claySubtleShadow,
                    border: isFlagged ? Border.all(color: AsterConstants.ambar, width: 1.5) : null,
                  ),
                  child: Icon(
                    isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                    size: 16,
                    color: isFlagged ? AsterConstants.ambar : AsterTheme.textMuted(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botão Fechar Simulado
            Tooltip(
              message: 'Sair do Simulado e voltar ao Gerador',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AsterTheme.card(context),
                  shape: BoxShape.circle,
                  boxShadow: AsterConstants.claySubtleShadow,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close_rounded, size: 18, color: AsterTheme.text(context)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
                        title: Text('Sair do Simulado?', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                        content: Text(
                          'Seu progresso atual nesta sessão será encerrado e você voltará ao menu de geração.',
                          style: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.textMuted(context)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Continuar Prova'),
                          ),
                          if (!_isReviewingSavedAttempt && _userAnswers.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _saveCurrentAttempt();
                                if (!mounted) return;
                                setState(() {
                                  _examSessionToken++;
                                  _isLoadingNextBatch = false;
                                  _batchErrorMessage = null;
                                  _activeQuestions = null;
                                  _currentAttemptId = null;
                                  _examTimer?.cancel();
                                });
                              },
                              child: const Text('Salvar e Sair'),
                            ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _examSessionToken++;
                                _isLoadingNextBatch = false;
                                _batchErrorMessage = null;
                                _activeQuestions = null;
                                _currentAttemptId = null;
                                _isReviewingSavedAttempt = false;
                                _examTimer?.cancel();
                              });
                            },
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                backgroundColor: AsterTheme.surfaceInset(context),
                valueColor: AlwaysStoppedAnimation(AsterTheme.primary(context)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toInt()}% (${_userAnswers.length}/$targetQ resp.)',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AsterTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Painel Esquerdo (Enunciado + Bloco Terminal Code + Gabarito RAG) ───
  Widget _buildQuestionLeftPanel() {
    final currentQ = _activeQuestions![_currentQuestionIndex];
    final questionText = (currentQ['question'] ?? '').toString();
    final supportingText = (currentQ['supporting_text'] ?? '').toString().trim();
    final sourceCitation = (currentQ['source_citation'] ?? '').toString().trim();
    final codeSnippet = (currentQ['code_snippet'] ?? '').toString();
    final explanation = (currentQ['explanation'] ?? '').toString();
    final disciplineLabel = _resolveQuestionDiscipline(currentQ, _currentQuestionIndex);
    final accentColor = _selectedExamModel?.accent ?? AsterTheme.primary(context);
    final hasAnswered = _userAnswers.containsKey(_currentQuestionIndex);
    final correctIdx = currentQ['correct_index'] as int? ?? 0;
    final letters = ['A', 'B', 'C', 'D', 'E'];
    final correctLetter = letters[correctIdx % letters.length];
    final rawSources = (currentQ['rag_sources'] as List?)?.map((e) => e.toString()).toList() ??
        [
          if (_selectedExamModel != null) _selectedExamModel!.name,
          disciplineLabel,
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftClayCard(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 13, color: accentColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        disciplineLabel,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildFormattedQuestionBody(
                questionText,
                supportingText: supportingText,
                sourceCitation: sourceCitation,
              ),
              const SizedBox(height: 18),

              if (codeSnippet.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Text(
                            'material / código de referência',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AsterTheme.textMuted(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        codeSnippet,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          height: 1.6,
                          color: AsterTheme.text(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),

        if (hasAnswered && _showExplanation) ...[
          const SizedBox(height: 16),
          SoftClayCard.list(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AsterConstants.menta.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: AsterConstants.menta),
                          const SizedBox(width: 6),
                          Text(
                            'Gabarito: $correctLetter',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AsterConstants.menta,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AsterTheme.primary(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        '+10 XP',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: AsterTheme.primary(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: _cleanMathAndFormatting(explanation),
                  selectable: true,
                  styleSheet: _buildMarkdownStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'FONTES RAG: ',
                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AsterTheme.textMuted(context)),
                    ),
                    ...rawSources.map(_buildRagChip),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    Color? textColor,
  }) {
    final baseColor = textColor ?? AsterTheme.text(context);
    return MarkdownStyleSheet(
      p: GoogleFonts.manrope(
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        color: baseColor,
      ),
      pPadding: const EdgeInsets.only(bottom: 8),
      strong: GoogleFonts.manrope(
        fontSize: fontSize,
        height: height,
        fontWeight: FontWeight.w800,
        color: baseColor,
      ),
      em: GoogleFonts.manrope(
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        fontStyle: FontStyle.italic,
        color: baseColor,
      ),
      listBullet: GoogleFonts.manrope(
        fontSize: fontSize,
        height: height,
        fontWeight: FontWeight.w700,
        color: AsterTheme.primary(context),
      ),
      blockquote: GoogleFonts.manrope(
        fontSize: fontSize - 0.5,
        height: height,
        fontStyle: FontStyle.italic,
        color: AsterTheme.textMuted(context),
      ),
      blockquoteDecoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AsterTheme.primary(context), width: 3)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      code: GoogleFonts.jetBrainsMono(
        fontSize: fontSize - 1.5,
        fontWeight: FontWeight.w700,
        color: AsterTheme.primary(context),
        backgroundColor: AsterTheme.surfaceAlt(context),
      ),
    );
  }

  String _resolveQuestionDiscipline(Map<String, dynamic> q, int questionIndex) {
    final explicit = (q['discipline'] ?? q['subject'] ?? q['area'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;

    final examNameLower = _selectedExamModel?.name.toLowerCase();
    final sources = (q['rag_sources'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && (examNameLower == null || e.toLowerCase() != examNameLower))
            .toList() ??
        const <String>[];
    if (sources.isNotEmpty) {
      return sources.first;
    }

    if (_selectedExamModel != null) {
      final total = (_activeQuestions != null && _activeQuestions!.length > _questionCount)
          ? _activeQuestions!.length
          : _questionCount;
      final schedule = _selectedExamModel!.resolveSectionPerQuestion(total);
      if (questionIndex >= 0 && questionIndex < schedule.length) {
        return schedule[questionIndex];
      }
    }

    final subj = _subjectController.text.trim();
    return subj.isNotEmpty ? subj : 'Conhecimentos Gerais';
  }

  /// Separa dinamicamente Texto de Apoio / Contexto / Fonte / Enunciado para exibição editorial.
  Widget _buildFormattedQuestionBody(
    String rawText, {
    String? supportingText,
    String? sourceCitation,
  }) {
    var normalized = _cleanMathAndFormatting(rawText.replaceAll('\r\n', '\n')).trim();
    final cleanSupport = _cleanMathAndFormatting((supportingText ?? '').replaceAll('\r\n', '\n')).trim();
    final cleanSource = _cleanMathAndFormatting((sourceCitation ?? '').replaceAll('\r\n', '\n')).trim();

    if (normalized.isEmpty && cleanSupport.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = <_QuestionSectionBlock>[];
    if (cleanSupport.isNotEmpty) {
      parsed.add(
        _extractSourceCitation(
          label: 'Texto de Apoio',
          isSupporting: true,
          rawBody: cleanSupport,
          explicitSource: cleanSource,
        ),
      );
      if (normalized.startsWith(cleanSupport)) {
        normalized = normalized.substring(cleanSupport.length).trim();
      }
      if (normalized.isNotEmpty) {
        final tailBlocks = _parseQuestionSections(normalized);
        if (tailBlocks.isNotEmpty) {
          parsed.addAll(tailBlocks);
        } else {
          parsed.add(
            _QuestionSectionBlock(
              label: null,
              body: normalized,
              isSupportingText: false,
            ),
          );
        }
      }
    } else {
      parsed.addAll(_parseQuestionSections(normalized, explicitSource: cleanSource));
    }
    final widgets = <Widget>[];

    for (int i = 0; i < parsed.length; i++) {
      final block = parsed[i];
      if (i > 0) {
        widgets.add(const SizedBox(height: 16));
      }

      if (block.isSupportingText) {
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              border: Border(
                left: BorderSide(
                  color: (_selectedExamModel?.accent ?? AsterTheme.primary(context)).withValues(alpha: 0.75),
                  width: 3.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.label != null) ...[
                  Text(
                    block.label!.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: _selectedExamModel?.accent ?? AsterTheme.primary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                MarkdownBody(
                  data: block.body,
                  selectable: true,
                  styleSheet: _buildMarkdownStyle(
                    fontSize: 14.2,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (block.sourceCitation != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      block.sourceCitation!,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.label != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AsterTheme.primary(context).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    block.label!.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                ),
              ],
              MarkdownBody(
                data: block.body,
                selectable: true,
                styleSheet: _buildMarkdownStyle(
                  fontSize: 15.5,
                  height: 1.62,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (block.sourceCitation != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    block.sourceCitation!,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  List<_QuestionSectionBlock> _parseQuestionSections(
    String text, {
    String? explicitSource,
  }) {
    final headerRegex = RegExp(
      r'^(?:\*{1,2})?(Texto[- ]?base|Texto de apoio|Texto\s+[I12]+|Text\s+[12]+|Passage|Stimulus|Est[ií]mulo|Vignette|Vinheta|Cen[aá]rio|Scenario|Contexto|Context|Caso cl[ií]nico|Extrait|Fragmento|Comando|Enunciado|Pergunta|Question(?:\s+Stem)?|Lead-in)(?:\*{1,2})?\s*:\s*(.*)$',
      caseSensitive: false,
    );

    const supportingKeys = {
      'texto-base',
      'texto base',
      'texto de apoio',
      'passage',
      'stimulus',
      'estímulo',
      'estimulo',
      'vignette',
      'vinheta',
      'cenário',
      'cenario',
      'scenario',
      'contexto',
      'context',
      'caso clínico',
      'caso clinico',
      'extrait',
      'fragmento',
    };

    final lines = text.split('\n');
    final explicitSections = <({String? label, bool isSupporting, List<String> lines})>[];
    bool foundAnyHeader = false;

    String? currentLabel;
    bool currentSupporting = false;
    var currentLines = <String>[];

    for (final line in lines) {
      final match = headerRegex.firstMatch(line.trim());
      if (match != null) {
        foundAnyHeader = true;
        if (currentLines.any((l) => l.trim().isNotEmpty) || currentLabel != null) {
          explicitSections.add((
            label: currentLabel,
            isSupporting: currentSupporting,
            lines: List<String>.from(currentLines),
          ));
        }
        final rawLabel = match.group(1)!.trim();
        final lowerLabel = rawLabel.toLowerCase();
        final remainder = match.group(2)?.trim() ?? '';
        currentSupporting = supportingKeys.contains(lowerLabel) ||
            lowerLabel.startsWith('texto ') ||
            lowerLabel.startsWith('text ');
        // Em provas reais (ENEM, FUVEST, OAB, SAT), a pergunta abaixo do texto-base
        // não recebe rótulo artificial ("COMANDO"), aparecendo limpa diretamente.
        currentLabel = currentSupporting
            ? (lowerLabel == 'texto-base' || lowerLabel == 'texto base' ? 'Texto de Apoio' : rawLabel)
            : null;
        currentLines = remainder.isNotEmpty ? [remainder] : [];
      } else {
        currentLines.add(line);
      }
    }

    if (currentLines.any((l) => l.trim().isNotEmpty) || currentLabel != null) {
      explicitSections.add((
        label: currentLabel,
        isSupporting: currentSupporting,
        lines: currentLines,
      ));
    }

    if (foundAnyHeader && explicitSections.isNotEmpty) {
      final blocks = explicitSections
          .map((sec) => _extractSourceCitation(
                label: sec.label,
                isSupporting: sec.isSupporting,
                rawBody: sec.lines.join('\n').trim(),
              ))
          .where((b) => b.body.isNotEmpty)
          .toList();
      if (explicitSource != null && explicitSource.isNotEmpty) {
        final idx = blocks.indexWhere((b) => b.isSupportingText && b.sourceCitation == null);
        if (idx != -1) {
          blocks[idx] = _QuestionSectionBlock(
            label: blocks[idx].label,
            body: blocks[idx].body,
            isSupportingText: true,
            sourceCitation: explicitSource,
          );
        }
      }
      return blocks;
    }

    // Sem cabeçalhos explícitos: extrai primeiro eventual linha/parágrafo final de citação ("Fonte: ...")
    // para que ela não impeça a detecção da pergunta imediatamente acima.
    final citationRegex = RegExp(
      r'^(?:Fonte|Disponível em|Adaptado de|Adaptado|Source|Referência|Reference)\s*:\s*.+$',
      caseSensitive: false,
    );
    final rawLines = text.split('\n');
    String? trailingSource = (explicitSource != null && explicitSource.isNotEmpty) ? explicitSource : null;
    while (rawLines.isNotEmpty) {
      final trimmedEnd = rawLines.last.trim();
      if (trimmedEnd.isEmpty) {
        rawLines.removeLast();
        continue;
      }
      if (citationRegex.hasMatch(trimmedEnd)) {
        trailingSource ??= trimmedEnd;
        rawLines.removeLast();
        continue;
      }
      break;
    }
    final bodyWithoutSource = rawLines.join('\n').trim();

    final paragraphs = bodyWithoutSource
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.length >= 2) {
      final last = paragraphs.last;
      final earlier = paragraphs.sublist(0, paragraphs.length - 1).join('\n\n');
      final lastLower = last.toLowerCase();

      const stemOpeners = [
        'considerando',
        'com base',
        'assinale',
        'diante',
        'segundo ',
        'de acordo',
        'infere-se',
        'conclui-se',
        'depreende-se',
        'identifica-se',
        'evidencia-se',
        'observa-se',
        'nota-se',
        'verifica-se',
        'a partir',
        'tendo em vista',
        'analisando',
        'no texto',
        'o texto',
        'o trecho',
        'no trecho',
        'o fragmento',
        'a leitura',
        'a linguagem',
        'o poema',
        'a crônica',
        'a charge',
        'o gráfico',
        'a tabela',
        'na situação',
        'nessa perspectiva',
        'nesse contexto',
        'nesse sentido',
        'dessa forma',
        'qual ',
        'quais ',
        'como ',
        'por que ',
        'em relação',
        'acerca d',
        'indique ',
        'marque ',
        'aponte ',
        'determine ',
        'calcule ',
        'which of the following',
        'based on',
        'according to',
        'what ',
        'why ',
        'how ',
        'según ',
        'selon ',
      ];

      final incompleteStemSuffixRegex = RegExp(
        r'\b(o|a|os|as|um|uma|de|do|da|dos|das|em|no|na|nos|nas|ao|à|aos|às|para|por|pelo|pela|pelos|pelas|com|sobre|entre|que|como|qual|quando|onde|é|são|foi|eram|ser|se|revela|revelam|indica|indicam|permite|permitem|constitui|constituem|representa|representam|evidencia|evidenciam|demonstra|demonstram|of|to|the|a|an|in|by|for|with|from|that)$',
        caseSensitive: false,
      );

      final startsAsCommand = stemOpeners.any((p) => lastLower.startsWith(p));
      final endsAsStem = last.contains('?') ||
          last.endsWith(':') ||
          last.endsWith('...') ||
          last.endsWith('…') ||
          last.endsWith('o(a)') ||
          last.endsWith('os(as)') ||
          last.endsWith('a(o)') ||
          last.endsWith('um(a)') ||
          incompleteStemSuffixRegex.hasMatch(last);
      final looksUnfinishedSentence =
          !last.endsWith('.') && !last.endsWith('"') && !last.endsWith('”') && !last.endsWith("'") && last.length <= 280;
      final looksQuotedPassage = last.startsWith('"') || last.startsWith('“');

      if ((earlier.length >= 70 || paragraphs.length >= 3) &&
          !looksQuotedPassage &&
          (startsAsCommand || endsAsStem || looksUnfinishedSentence)) {
        return [
          _extractSourceCitation(
            label: 'Texto de Apoio',
            isSupporting: true,
            rawBody: earlier,
            explicitSource: trailingSource,
          ),
          _extractSourceCitation(
            label: null,
            isSupporting: false,
            rawBody: last,
          ),
        ];
      }
    }

    return [
      _extractSourceCitation(
        label: null,
        isSupporting: false,
        rawBody: bodyWithoutSource.isNotEmpty ? bodyWithoutSource : text,
        explicitSource: trailingSource,
      ),
    ];
  }

  _QuestionSectionBlock _extractSourceCitation({
    required String? label,
    required bool isSupporting,
    required String rawBody,
    String? explicitSource,
  }) {
    var lines = rawBody.split('\n');
    if (isSupporting) {
      // Remove prefixo '>' caso a IA tenha envolvido o texto-base inteiro em blockquote
      lines = lines.map((l) => l.replaceFirst(RegExp(r'^\s*>\s?'), '')).toList();
    }
    String? source = (explicitSource != null && explicitSource.trim().isNotEmpty) ? explicitSource.trim() : null;
    if (lines.length >= 2) {
      final lastLine = lines.last.trim();
      if (RegExp(r'^(Fonte|Disponível em|Adaptado de|Adaptado|Source|Referência|Reference)\s*:', caseSensitive: false)
          .hasMatch(lastLine)) {
        source ??= lastLine;
        lines.removeLast();
      }
    }
    return _QuestionSectionBlock(
      label: label,
      body: lines.join('\n').trim(),
      isSupportingText: isSupporting,
      sourceCitation: source,
    );
  }

  /// Limpa delimitadores LaTeX comuns (`$10\%$`, `\times`, `\frac{a}{b}`) preservando valores monetários (`R$ 100`).
  String _cleanMathAndFormatting(String input) {
    var out = input;
    out = out.replaceAll(r'\%', '%');
    out = out.replaceAll(r'\&', '&');
    out = out.replaceAll(r'\times', '×');
    out = out.replaceAll(r'\cdot', '·');
    out = out.replaceAll(r'\div', '÷');
    out = out.replaceAll(r'\leq', '≤');
    out = out.replaceAll(r'\le', '≤');
    out = out.replaceAll(r'\geq', '≥');
    out = out.replaceAll(r'\ge', '≥');
    out = out.replaceAll(r'\neq', '≠');
    out = out.replaceAll(r'\ne', '≠');
    out = out.replaceAll(r'\approx', '≈');
    out = out.replaceAll(r'\pm', '±');
    out = out.replaceAll(r'\rightarrow', '→');
    out = out.replaceAll(r'\to', '→');
    out = out.replaceAll(r'\pi', 'π');
    out = out.replaceAll(r'\Delta', 'Δ');
    out = out.replaceAll('^2', '²').replaceAll('^{2}', '²');
    out = out.replaceAll('^3', '³').replaceAll('^{3}', '³');
    out = out.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '${m.group(1)}/${m.group(2)}',
    );
    out = out.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (m) => '√(${m.group(1)})',
    );
    // Remove delimitadores $...$ de expressões inline (sem afetar "R$ 10.000,00" ou "US$ 50")
    out = out.replaceAllMapped(
      RegExp(r'(?<![RUr\w])\$([^$\n]{1,40})\$'),
      (m) => m.group(1)!.trim(),
    );
    return out;
  }

  String _stripOptionPrefix(String rawOption) {
    return _cleanMathAndFormatting(rawOption)
        .trim()
        .replaceFirst(RegExp(r'^(?:\([A-Ea-e1-5]\)|[A-Ea-e1-5][).:\-])\s+'), '')
        .trim();
  }

  Widget _buildRagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 12, color: AsterTheme.primary(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AsterTheme.text(context)),
          ),
        ],
      ),
    );
  }

  // ─── Painel Direito com Alternativas ───
  Widget _buildAlternativesRightPanel() {
    final currentQ = _activeQuestions![_currentQuestionIndex];
    final List<dynamic> options = currentQ['options'] ?? [];
    final correctIdx = currentQ['correct_index'] as int? ?? 0;
    final selectedIdx = _userAnswers[_currentQuestionIndex];
    final hasAnswered = selectedIdx != null;

    final letters = ['A', 'B', 'C', 'D', 'E'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SELECIONE UMA ALTERNATIVA',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AsterTheme.textMuted(context),
          ),
        ),
        const SizedBox(height: 12),

        ...options.asMap().entries.map((entry) {
          final idx = entry.key;
          final optText = _stripOptionPrefix(entry.value.toString());
          final isSelected = selectedIdx == idx;
          final isCorrect = idx == correctIdx;

          Color badgeBg = AsterTheme.surfaceAlt(context);
          Color badgeText = AsterTheme.text(context);
          Color cardBg = AsterTheme.card(context);
          Color? borderColor;

          if (hasAnswered) {
            if (isCorrect) {
              badgeBg = AsterConstants.menta;
              badgeText = Colors.white;
              cardBg = AsterConstants.menta.withValues(alpha: 0.08);
              borderColor = AsterConstants.menta;
            } else if (isSelected && !isCorrect) {
              badgeBg = AsterConstants.coral;
              badgeText = Colors.white;
              cardBg = AsterConstants.coral.withValues(alpha: 0.08);
              borderColor = AsterConstants.coral;
            }
          } else if (isSelected) {
            badgeBg = AsterTheme.primary(context);
            badgeText = AsterTheme.onPrimary(context);
            borderColor = AsterTheme.primary(context);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              boxShadow: AsterConstants.clayListShadow,
              border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                onTap: () {
                  setState(() {
                    _userAnswers[_currentQuestionIndex] = idx;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: hasAnswered && isCorrect
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : Text(
                                  letters[idx % letters.length],
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: badgeText,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: MarkdownBody(
                          data: optText,
                          styleSheet: _buildMarkdownStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Controles Inferiores (Seguro contra overflow até 120 questões + Paginação por Lotes) ───
  Widget _buildBottomExamControls() {
    final loadedQ = _activeQuestions?.length ?? 1;
    final targetQ = _targetQuestionCount > loadedQ ? _targetQuestionCount : loadedQ;
    final hasMoreBatches = loadedQ < targetQ;
    final isAtLoadedEnd = _currentQuestionIndex == loadedQ - 1;
    final isLastOverall = isAtLoadedEnd && !hasMoreBatches;

    // Janela deslizante de no máximo 9 pontos para nunca estourar em provas de 120 questões
    const maxVisibleDots = 9;
    final int windowStart = loadedQ <= maxVisibleDots
        ? 0
        : (_currentQuestionIndex - maxVisibleDots ~/ 2).clamp(0, loadedQ - maxVisibleDots);
    final int windowEnd = (windowStart + maxVisibleDots).clamp(0, loadedQ);

    final remainingToLoad = targetQ - loadedQ;
    final nextBatchSize =
        remainingToLoad > GeminiService.quizBatchSize ? GeminiService.quizBatchSize : remainingToLoad;

    String rightBtnText = 'Próxima';
    IconData? rightBtnIcon = Icons.arrow_forward_rounded;
    VoidCallback? rightBtnAction = () => setState(() => _currentQuestionIndex++);

    if (isLastOverall) {
      rightBtnText = 'Finalizar Prova';
      rightBtnIcon = Icons.check_circle_rounded;
      rightBtnAction = _showExamCompletionDialog;
    } else if (isAtLoadedEnd && hasMoreBatches) {
      if (_isLoadingNextBatch) {
        rightBtnText = 'Carregando +$nextBatchSize Q...';
        rightBtnIcon = null;
        rightBtnAction = null;
      } else {
        rightBtnText = 'Próximo Lote (+$nextBatchSize Q)';
        rightBtnIcon = Icons.auto_awesome_rounded;
        rightBtnAction = () => _continueLoadingRemainingBatches(
              _examSessionToken,
              advanceToNewBatch: true,
            );
      }
    }

    return Row(
      children: [
        SoftClayPillButton(
          text: 'Anterior',
          icon: Icons.arrow_back_rounded,
          isSecondary: true,
          onPressed: _currentQuestionIndex > 0
              ? () => setState(() => _currentQuestionIndex--)
              : null,
        ),
        const Spacer(),

        InkWell(
          onTap: _showQuestionNavigatorDialog,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AsterTheme.card(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              boxShadow: AsterConstants.claySubtleShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (windowStart > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('…', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AsterTheme.textMuted(context))),
                  ),
                ...List.generate(windowEnd - windowStart, (offset) {
                  final idx = windowStart + offset;
                  final isCurrent = idx == _currentQuestionIndex;
                  final isFlagged = _flaggedQuestions.contains(idx);
                  final isAnswered = _userAnswers.containsKey(idx);

                  Color dotColor = AsterTheme.surfaceInset(context);
                  if (isFlagged) {
                    dotColor = AsterConstants.ambar;
                  } else if (isCurrent) {
                    dotColor = AsterTheme.primary(context);
                  } else if (isAnswered) {
                    dotColor = AsterConstants.menta;
                  }

                  return Container(
                    width: isCurrent ? 14 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: dotColor,
                      borderRadius: BorderRadius.circular(3.5),
                    ),
                  );
                }),
                if (windowEnd < loadedQ)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('…', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AsterTheme.textMuted(context))),
                  ),
                const SizedBox(width: 8),
                Text(
                  hasMoreBatches
                      ? '${_currentQuestionIndex + 1}/$targetQ ($loadedQ pr.)'
                      : '${_currentQuestionIndex + 1}/$targetQ',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.primary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),

        SoftClayPillButton(
          text: rightBtnText,
          icon: rightBtnIcon,
          onPressed: rightBtnAction,
        ),
      ],
    );
  }

  Widget _buildTopModeToggle() {
    final savedCount = _savedAttempts.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeToggleOption(
            label: 'Novo Simulado',
            icon: Icons.auto_awesome,
            selected: !_showSavedHistory,
            onTap: () => setState(() => _showSavedHistory = false),
          ),
          const SizedBox(width: 4),
          _modeToggleOption(
            label: savedCount > 0 ? 'Realizados ($savedCount)' : 'Realizados',
            icon: Icons.history_rounded,
            selected: _showSavedHistory,
            onTap: () {
              _refreshSavedAttempts(forceRemote: true);
              setState(() => _showSavedHistory = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _modeToggleOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AsterTheme.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? AsterTheme.onPrimary(context) : AsterTheme.textMuted(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? AsterTheme.onPrimary(context) : AsterTheme.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTimeShort(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y · $hh:$mm';
  }

  Widget _buildSavedHistoryCard(bool isDesktop) {
    final all = _savedAttempts;
    final filtered = _historyGroupFilter == null
        ? all
        : all.where((a) => a.groupKey == _historyGroupFilter).toList();

    // Agrupa por simulado (groupKey) para comparar evolução das últimas vezes
    final grouped = <String, List<SavedExamAttempt>>{};
    for (final attempt in all) {
      grouped.putIfAbsent(attempt.groupKey, () => []).add(attempt);
    }

    final avgScore = all.isEmpty
        ? 0
        : (all.fold<double>(0, (acc, a) => acc + a.scorePercentage) / all.length).round();
    final totalQuestionsAnswered = all.fold<int>(0, (acc, a) => acc + a.answeredCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const NoesisCollapsedMenuSpacer(width: 82),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AsterTheme.primary(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.history_rounded, color: AsterTheme.onPrimary(context), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIMULADOS REALIZADOS & EVOLUÇÃO',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                                color: AsterTheme.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Revise questões, consulte o gabarito e compare seu desempenho ao longo das tentativas',
                              style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildTopModeToggle(),
                  ],
                ),
              ),
            ],
          ),
        ),
        SoftClayCard(
          padding: EdgeInsets.all(isDesktop ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

          if (all.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Column(
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 40, color: AsterTheme.primary(context).withValues(alpha: 0.65)),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum simulado salvo ainda',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AsterTheme.text(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ao finalizar qualquer simulado (ou clicar em "Encerrar & Review"), ele fica salvo aqui automaticamente para você revisar e acompanhar sua evolução.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 12.5, color: AsterTheme.textMuted(context)),
                  ),
                  const SizedBox(height: 16),
                  SoftClayPillButton(
                    text: 'Gerar Primeiro Simulado',
                    icon: Icons.auto_awesome,
                    onPressed: () => setState(() => _showSavedHistory = false),
                  ),
                ],
              ),
            )
          else ...[
            // Resumo geral
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                alignment: WrapAlignment.spaceAround,
                children: [
                  _historyMetricTile('Simulados Salvos', '${all.length}', AsterTheme.primary(context)),
                  _historyMetricTile('Provas Distintas', '${grouped.length}', AsterConstants.ambar),
                  _historyMetricTile('Média Geral', '$avgScore%', AsterConstants.menta),
                  _historyMetricTile('Questões Respondidas', '$totalQuestionsAnswered', AsterTheme.text(context)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Comparativo por simulado (últimas realizações)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DESEMPENHO POR SIMULADO (ÚLTIMAS REALIZAÇÕES)',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
                if (_historyGroupFilter != null)
                  TextButton(
                    onPressed: () => setState(() => _historyGroupFilter = null),
                    child: const Text('Mostrar todos'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: grouped.entries.map((entry) {
                  final groupAttempts = entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final latest = groupAttempts.first;
                  final previous = groupAttempts.length > 1 ? groupAttempts[1] : null;
                  final delta = previous != null
                      ? (latest.scorePercentage - previous.scorePercentage).round()
                      : null;
                  final isSelected = _historyGroupFilter == entry.key;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => setState(() {
                        _historyGroupFilter = isSelected ? null : entry.key;
                      }),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      child: Container(
                        width: 245,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AsterTheme.primary(context).withValues(alpha: 0.12)
                              : AsterTheme.surfaceAlt(context),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(
                            color: isSelected
                                ? AsterTheme.primary(context)
                                : AsterTheme.textMuted(context).withValues(alpha: 0.15),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    latest.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: AsterTheme.text(context),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${groupAttempts.length}x',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AsterTheme.primary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Última: ${latest.scorePercentage.round()}%',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: latest.scorePercentage >= 70
                                        ? AsterConstants.menta
                                        : AsterConstants.ambar,
                                  ),
                                ),
                                if (delta != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    delta >= 0 ? '+$delta% vs ant.' : '$delta% vs ant.',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: delta >= 0 ? AsterConstants.menta : AsterConstants.coral,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Últimas: ${groupAttempts.take(4).map((a) => "${a.scorePercentage.round()}%").join(" · ")}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),

            Text(
              'HISTÓRICO DE TENTATIVAS (${filtered.length})',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AsterTheme.textMuted(context),
              ),
            ),
            const SizedBox(height: 10),

            ...filtered.map((attempt) {
              final groupAttempts = grouped[attempt.groupKey] ?? [attempt];
              final pos = groupAttempts.indexWhere((a) => a.id == attempt.id);
              final prevAttempt = (pos != -1 && pos + 1 < groupAttempts.length)
                  ? groupAttempts[pos + 1]
                  : null;
              final deltaVsPrev = prevAttempt != null
                  ? (attempt.scorePercentage - prevAttempt.scorePercentage).round()
                  : null;
              final scorePct = attempt.scorePercentage.round();
              final scoreColor = scorePct >= 70
                  ? AsterConstants.menta
                  : (scorePct >= 45 ? AsterConstants.ambar : AsterConstants.coral);
              final mins = attempt.elapsedSeconds ~/ 60;
              final secs = attempt.elapsedSeconds % 60;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AsterTheme.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  border: Border(left: BorderSide(color: scoreColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    attempt.title,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: AsterTheme.text(context),
                                    ),
                                  ),
                                  SoftClayTag(
                                    label: '$scorePct% (${attempt.correctCount}/${attempt.loadedCount})',
                                    color: scoreColor,
                                  ),
                                  if (deltaVsPrev != null)
                                    SoftClayTag(
                                      label: deltaVsPrev >= 0
                                          ? '+$deltaVsPrev% vs última'
                                          : '$deltaVsPrev% vs última',
                                      color: deltaVsPrev >= 0 ? AsterConstants.menta : AsterConstants.coral,
                                    ),
                                  if (attempt.timeExpired)
                                    const SoftClayTag(
                                      label: 'Tempo Esgotado',
                                      color: AsterConstants.coral,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${attempt.subject} · ${_formatDateTimeShort(attempt.createdAt)} · Duração: ${mins}m ${secs.toString().padLeft(2, "0")}s · ${attempt.correctCount} acertos, ${attempt.wrongCount} erros, ${attempt.blankCount} em branco',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Excluir do histórico',
                          onPressed: () => _deleteSavedAttempt(attempt.id),
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: AsterTheme.textMuted(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openSavedAttemptForReview(attempt),
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: const Text('Revisar Questões'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openSavedAttemptCompletionReport(attempt),
                          icon: const Icon(Icons.analytics_outlined, size: 15),
                          label: const Text('Ver Comparativo & Review IA'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _retakeSavedAttempt(attempt),
                          icon: const Icon(Icons.replay_rounded, size: 15),
                          label: const Text('Refazer Simulado'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    ),
      ],
    );
  }

  Widget _historyMetricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.textMuted(context)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  // ─── Card Gerador de Simulado ───
  Widget _buildGeneratorCard(bool isDesktop) {
    final query = _examSearchController.text.trim().toLowerCase();
    final filteredModels = ExamModelsCatalog.byCategory(_selectedCategory).where((m) {
      if (query.isEmpty) return true;
      return m.name.toLowerCase().contains(query) ||
          m.badge.toLowerCase().contains(query) ||
          m.topic.toLowerCase().contains(query) ||
          m.subject.toLowerCase().contains(query);
    }).toList();

    final estimatedMinutes = _questionCount * 2;
    final batchCount = (_questionCount / GeminiService.quizBatchSize).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const NoesisCollapsedMenuSpacer(width: 82),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AsterTheme.primary(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome, color: AsterTheme.onPrimary(context), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GERAR NOVO SIMULADO COM IA',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                                color: AsterTheme.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Escolha o modelo oficial da prova (38 bancas), defina até ${GeminiService.quizMaxQuestions} questões ou anexe apostilas RAG',
                              style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildTopModeToggle(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AsterTheme.primary(context).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 14, color: AsterTheme.primary(context)),
                              const SizedBox(width: 5),
                              Text(
                                GeminiService.currentProvider.label,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AsterTheme.primary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SoftClayCard(
          padding: EdgeInsets.all(isDesktop ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

          // ── Seletor Completo de Modelo de Prova Oficial ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'MODELO DE PROVA OFICIAL (${ExamModelsCatalog.models.length} BANCAS)',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _selectExamModel(null),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedExamModel == null
                        ? AsterTheme.primary(context).withValues(alpha: 0.15)
                        : AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(
                      color: _selectedExamModel == null ? AsterTheme.primary(context) : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'Modo Livre (Sem Modelo)',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _selectedExamModel == null ? AsterTheme.primary(context) : AsterTheme.textMuted(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filtros de Categoria + Busca rápida
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ExamCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      final count = ExamModelsCatalog.byCategory(cat).length;
                      final catColor = _resolveExamAccent(cat.color);
                      final catOnColor = _onAccentColor(catColor);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? catColor : AsterTheme.surfaceAlt(context),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon, size: 13, color: isSelected ? catOnColor : AsterTheme.textMuted(context)),
                                const SizedBox(width: 5),
                                Text(
                                  '${cat.label} ($count)',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? catOnColor : AsterTheme.text(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _examSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      hintText: 'Filtrar prova (ENEM, SAT, OAB...)',
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: AsterTheme.textMuted(context)),
                      suffixIcon: _examSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              onPressed: () {
                                _examSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _examSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                hintText: 'Filtrar prova (ENEM, FUVEST, SAT, DELE, OAB...)',
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: AsterTheme.textMuted(context)),
                suffixIcon: _examSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14),
                        onPressed: () {
                          _examSearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Lista rolável compacta com os modelos filtrados
          Container(
            constraints: const BoxConstraints(maxHeight: 228),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            ),
            child: filteredModels.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Nenhum modelo encontrado para "${_examSearchController.text}".',
                        style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredModels.map((model) {
                        final isSelected = _selectedExamModel?.id == model.id;
                        final accent = _resolveExamAccent(model.accent);
                        final onAccent = _onAccentColor(accent);

                        return InkWell(
                          onTap: () => _selectExamModel(model),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.14)
                                  : AsterTheme.card(context),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              border: Border.all(
                                color: isSelected ? accent : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(model.icon, size: 15, color: isSelected ? accent : AsterTheme.text(context)),
                                const SizedBox(width: 6),
                                Text(
                                  model.name,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? accent : AsterTheme.text(context),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? accent : AsterTheme.surfaceInset(context),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    model.badge,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? onAccent : AsterTheme.textMuted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),

          // Banner do Modelo Ativo (Blueprint .md + Visualização + Qtd recomendada)
          if (_selectedExamModel != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final modelAccent = _resolveExamAccent(_selectedExamModel!.accent);
                final modelOnAccent = _onAccentColor(modelAccent);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: modelAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(color: modelAccent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_selectedExamModel!.icon, size: 18, color: modelAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Modelo Selecionado: ${_selectedExamModel!.name} · ${_selectedExamModel!.optionsFormat}',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.text(context),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showBlueprintPreviewDialog(_selectedExamModel!),
                            icon: const Icon(Icons.menu_book_outlined, size: 15),
                            label: const Text('Ver Parâmetros (.md)'),
                            style: TextButton.styleFrom(
                              foregroundColor: modelAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              textStyle: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedExamModel!.summary,
                        style: GoogleFonts.manrope(fontSize: 11.5, color: AsterTheme.textMuted(context)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _applyExamBlueprint = !_applyExamBlueprint),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _applyExamBlueprint
                                    ? modelAccent
                                    : AsterTheme.card(context),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _applyExamBlueprint ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                    size: 13,
                                    color: _applyExamBlueprint ? modelOnAccent : AsterTheme.textMuted(context),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Espelhar regras da banca (.md) na IA',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _applyExamBlueprint ? modelOnAccent : AsterTheme.text(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final isQuick = _questionCount == 15 && _selectedExamModel!.recommendedCount != 15;
                              _setQuestionCount(isQuick ? _selectedExamModel!.recommendedCount : 15);
                            },
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AsterTheme.card(context),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                border: Border.all(color: modelAccent.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    (_questionCount == 15 && _selectedExamModel!.recommendedCount != 15)
                                        ? Icons.assignment_outlined
                                        : Icons.flash_on_rounded,
                                    size: 13,
                                    color: modelAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (_questionCount == 15 && _selectedExamModel!.recommendedCount != 15)
                                        ? 'Prova Completa (${_selectedExamModel!.recommendedCount} Q)'
                                        : 'Treino Rápido (15 Q)',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: modelAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 22),

          // ── Campos de Área e Tópico ──
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Área / Matéria',
                      hintText: 'Ex: Cybersegurança, Matemática, Constitucional...',
                      prefixIcon: Icon(Icons.category_outlined, size: 18, color: AsterTheme.primary(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      labelText: 'Tópico ou Exame',
                      hintText: 'Ex: ENEM Natureza, CompTIA SY0-701, OAB Ética...',
                      prefixIcon: Icon(Icons.school_outlined, size: 18, color: AsterTheme.primary(context)),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Área / Matéria',
                hintText: 'Ex: Cybersegurança, Cloud...',
                prefixIcon: Icon(Icons.category_outlined, size: 18, color: AsterTheme.primary(context)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: 'Tópico ou Exame',
                hintText: 'Ex: CompTIA Security+, ENEM, OAB...',
                prefixIcon: Icon(Icons.school_outlined, size: 18, color: AsterTheme.primary(context)),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Seletor Visual de Dificuldade ──
          Text(
            'NÍVEL DE PROFUNDIDADE',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              return isWide
                  ? Row(
                      children: _difficultyLevels.map((lvl) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: _buildDifficultyOptionCard(lvl),
                          ),
                        );
                      }).toList(),
                    )
                  : Column(
                      children: _difficultyLevels.map((lvl) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildDifficultyOptionCard(lvl),
                        );
                      }).toList(),
                    );
            },
          ),
          const SizedBox(height: 24),

          // ── Quantidade de Questões (3 a 200) ──
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'QUANTIDADE DE QUESTÕES (3 A ${GeminiService.quizMaxQuestions})',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AsterTheme.textMuted(context),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (batchCount > 1)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AsterTheme.primary(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        '$batchCount lotes IA (${GeminiService.quizBatchSize} Q/lote)',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.primary(context),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(context),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Text(
                      '⏱️ ${_formatEstimatedMinutes(estimatedMinutes)}',
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.textMuted(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [5, 10, 15, 30, 45, 60, 90, 120, 150, 180, 200].map((count) {
              final isSelected = _questionCount == count;
              return InkWell(
                onTap: () => _setQuestionCount(count),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AsterTheme.primary(context) : AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                  child: Text(
                    '$count Q',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AsterTheme.onPrimary(context) : AsterTheme.text(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              IconButton(
                onPressed: _questionCount > 3 ? () => _setQuestionCount(_questionCount - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                color: AsterTheme.primary(context),
                tooltip: 'Diminuir 1 questão',
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AsterTheme.primary(context),
                    inactiveTrackColor: AsterTheme.surfaceInset(context),
                    thumbColor: AsterTheme.primary(context),
                    overlayColor: AsterTheme.primary(context).withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _questionCount.toDouble().clamp(3, GeminiService.quizMaxQuestions.toDouble()),
                    min: 3,
                    max: GeminiService.quizMaxQuestions.toDouble(),
                    divisions: GeminiService.quizMaxQuestions - 3,
                    onChanged: (val) => _setQuestionCount(val.round()),
                  ),
                ),
              ),
              IconButton(
                onPressed: _questionCount < GeminiService.quizMaxQuestions ? () => _setQuestionCount(_questionCount + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                color: AsterTheme.primary(context),
                tooltip: 'Aumentar 1 questão',
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _questionCountInputController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.primary(context),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (txt) {
                    final parsed = int.tryParse(txt);
                    if (parsed != null) {
                      _setQuestionCount(parsed);
                    } else {
                      _setQuestionCount(_questionCount);
                    }
                  },
                  onChanged: (txt) {
                    final parsed = int.tryParse(txt);
                    if (parsed != null && parsed >= 3 && parsed <= GeminiService.quizMaxQuestions) {
                      setState(() => _questionCount = parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Opção de Anexar Documento Extra para RAG ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AsterTheme.surfaceAlt(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Icon(Icons.feed_outlined, size: 18, color: AsterTheme.primary(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Base de Estudo para a IA (Flashcards, Cadernos & Apostilas)',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13, color: AsterTheme.text(context)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Anexe seus baralhos, cadernos ou edital/PDF para a IA gerar questões com base no seu material',
                      style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.textMuted(context)),
                    ),
                    value: _useDocument,
                    activeColor: AsterTheme.primary(context),
                    onChanged: (val) => setState(() => _useDocument = val),
                  ),
                ),

                // Atalhos sempre acessíveis para anexar Flashcards e Cadernos do Noesis
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showAttachFlashcardsDialog,
                      icon: const Icon(Icons.style_outlined, size: 16),
                      label: Text(
                        _selectedDeckIds.isEmpty
                            ? 'Anexar Flashcards'
                            : 'Flashcards (${_selectedDeckIds.length})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showAttachNotebooksDialog,
                      icon: const Icon(Icons.menu_book_outlined, size: 16),
                      label: Text(
                        _selectedNotebookIds.isEmpty
                            ? 'Anexar Cadernos'
                            : 'Cadernos (${_selectedNotebookIds.length})',
                      ),
                    ),
                  ],
                ),

                if (_selectedDeckIds.isNotEmpty || _selectedNotebookIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._availableDecks
                          .where((d) => _selectedDeckIds.contains(d.id))
                          .map(
                            (deck) => InputChip(
                              avatar: Icon(Icons.style_rounded, size: 15, color: AsterTheme.primary(context)),
                              label: Text(
                                '${deck.title} (${deck.cards.length} cards)',
                                style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                              onDeleted: () => setState(() => _selectedDeckIds.remove(deck.id)),
                            ),
                          ),
                      ..._availableNotebooks
                          .where((n) => _selectedNotebookIds.contains(n.id))
                          .map(
                            (nb) => InputChip(
                              avatar: const Icon(Icons.menu_book_rounded, size: 15, color: AsterConstants.menta),
                              label: Text(
                                '${nb.title} (${nb.notes.length} notas)',
                                style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                              onDeleted: () => setState(() => _selectedNotebookIds.remove(nb.id)),
                            ),
                          ),
                    ],
                  ),
                ],

                if (_useDocument) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SoftClayPillButton(
                        text: 'Anexar PDF / MD / TXT',
                        icon: Icons.attach_file_rounded,
                        isSecondary: true,
                        onPressed: _pickDocumentFile,
                      ),
                      if (_uploadedFileName != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AsterTheme.card(context),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.description_outlined, size: 15, color: AsterTheme.primary(context)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _uploadedFileName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterTheme.text(context)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _uploadedFileName = null;
                                      _documentTextController.clear();
                                    });
                                  },
                                  child: Icon(Icons.close_rounded, size: 16, color: AsterTheme.textMuted(context)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _documentTextController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      fillColor: AsterTheme.card(context),
                      labelText: 'Trechos de Provas Anteriores ou Edital',
                      hintText: 'Cole questões antigas ou ementa técnica para a IA espelhar o estilo da banca...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_isGenerating && _generatedTotal > GeminiService.quizBatchSize) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              child: LinearProgressIndicator(
                value: _generatedTotal > 0 ? (_generatedProgress / _generatedTotal).clamp(0.05, 1.0) : null,
                minHeight: 7,
                backgroundColor: AsterTheme.surfaceInset(context),
                valueColor: AlwaysStoppedAnimation(AsterTheme.primary(context)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gerando em lotes para garantir precisão sem truncamento: $_generatedProgress / $_generatedTotal questões prontas...',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
            ),
            const SizedBox(height: 16),
          ],

          // ── Botões de Ação Final ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 560;
              final btnLabel = _isGenerating
                  ? (_generatedTotal > GeminiService.quizBatchSize
                      ? 'Gerando $_generatedProgress / $_generatedTotal questões...'
                      : 'Gerando Simulado com ${GeminiService.currentProvider.label}...')
                  : 'Criar Prova Interativa ($_questionCount Q) com IA';

              final createBtn = SoftClayPillButton(
                text: btnLabel,
                icon: _isGenerating ? null : Icons.psychology_rounded,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                fontSize: 14,
                iconSize: 18,
                onPressed: _isGenerating ? null : _startGenerateQuiz,
              );

              final demoBtn = SoftClayPillButton(
                text: 'Testar com Demo',
                icon: Icons.play_circle_outline_rounded,
                isSecondary: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                fontSize: 14,
                iconSize: 18,
                onPressed: _loadDemoMockQuiz,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    createBtn,
                    const SizedBox(height: 12),
                    demoBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: createBtn,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: demoBtn,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
      ],
    );
  }

  // ─── Card Individual do Seletor de Dificuldade ───
  Widget _buildDifficultyOptionCard(Map<String, dynamic> lvl) {
    final isSelected = _difficulty == lvl['id'];
    final color = (lvl['color'] as Color?) ?? AsterTheme.primary(context);
    final selectedIconColor = lvl['color'] == null ? AsterTheme.onPrimary(context) : Colors.white;

    return InkWell(
      onTap: () => setState(() => _difficulty = lvl['id']),
      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.10) : AsterTheme.surfaceAlt(context),
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? color : AsterTheme.surfaceInset(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    lvl['icon'] as IconData,
                    size: 15,
                    color: isSelected ? selectedIconColor : AsterTheme.textMuted(context),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 16, color: color)
                else
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AsterTheme.surfaceInset(context), width: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lvl['title'] as String,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : AsterTheme.text(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              lvl['desc'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 11,
                height: 1.35,
                color: AsterTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReviewFilter { all, wrong, correct, blank }

/// Modal completo de finalização: Comparativo Acertos/Erros/Brancos + Review Pedagógica com IA.
class _ExamCompletionDialog extends StatefulWidget {
  const _ExamCompletionDialog({
    this.attemptId,
    required this.examModelName,
    required this.subject,
    required this.topic,
    required this.questions,
    required this.targetTotalCount,
    required this.userAnswers,
    required this.elapsedSeconds,
    this.initialAiReview,
    this.previousGroupAttempts = const [],
    this.onAiReviewReady,
    required this.onJumpToQuestion,
    required this.onNewSimulado,
  });

  final String? attemptId;
  final String? examModelName;
  final String subject;
  final String topic;
  final List<Map<String, dynamic>> questions;
  final int targetTotalCount;
  final Map<int, int> userAnswers;
  final int elapsedSeconds;
  final String? initialAiReview;
  final List<SavedExamAttempt> previousGroupAttempts;
  final void Function(String review)? onAiReviewReady;
  final void Function(int index) onJumpToQuestion;
  final VoidCallback onNewSimulado;

  @override
  State<_ExamCompletionDialog> createState() => _ExamCompletionDialogState();
}

class _ExamCompletionDialogState extends State<_ExamCompletionDialog> {
  _ReviewFilter _filter = _ReviewFilter.all;
  bool _isLoadingReview = false;
  String? _aiReviewMarkdown;

  @override
  void initState() {
    super.initState();
    if (widget.initialAiReview != null && widget.initialAiReview!.trim().isNotEmpty) {
      _aiReviewMarkdown = widget.initialAiReview;
    } else {
      _loadAiReview();
    }
  }

  Future<void> _loadAiReview() async {
    setState(() => _isLoadingReview = true);
    try {
      final review = await GeminiService.generateQuizPerformanceReview(
        subject: widget.subject,
        topic: widget.topic,
        examModelName: widget.examModelName,
        questions: widget.questions,
        userAnswers: widget.userAnswers,
        elapsedSeconds: widget.elapsedSeconds,
      );
      if (mounted) {
        setState(() {
          _aiReviewMarkdown = review;
          _isLoadingReview = false;
        });
        widget.onAiReviewReady?.call(review);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiReviewMarkdown = 'Não foi possível gerar a análise automática da IA agora ($e).';
          _isLoadingReview = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLoaded = widget.questions.length;
    int correctCount = 0;
    int wrongCount = 0;
    int blankCount = 0;

    final items = <({
      int index,
      String status,
      String stem,
      String userLabel,
      String correctLabel,
    })>[];
    const letters = ['A', 'B', 'C', 'D', 'E'];

    for (int i = 0; i < totalLoaded; i++) {
      final q = widget.questions[i];
      final correctIdx = q['correct_index'] as int? ?? 0;
      final selectedIdx = widget.userAnswers[i];
      final options = (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final rawStem = (q['question'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final shortStem = rawStem.length > 90 ? '${rawStem.substring(0, 90)}...' : rawStem;
      String cleanOpt(int idx) {
        if (idx < 0 || idx >= options.length) return letters[idx % letters.length];
        return options[idx]
            .trim()
            .replaceFirst(RegExp(r'^(?:\([A-Ea-e1-5]\)|[A-Ea-e1-5][).:\-])\s+'), '')
            .trim();
      }
      final rightLetter = letters[correctIdx % letters.length];
      final rightText = cleanOpt(correctIdx);

      if (selectedIdx == null) {
        blankCount++;
        items.add((
          index: i,
          status: 'blank',
          stem: shortStem,
          userLabel: 'Não respondida',
          correctLabel: '$rightLetter) $rightText',
        ));
      } else if (selectedIdx == correctIdx) {
        correctCount++;
        final userLetter = letters[selectedIdx % letters.length];
        items.add((
          index: i,
          status: 'correct',
          stem: shortStem,
          userLabel: '$userLetter) ${cleanOpt(selectedIdx)}',
          correctLabel: '$rightLetter) $rightText',
        ));
      } else {
        wrongCount++;
        final userLetter = letters[selectedIdx % letters.length];
        items.add((
          index: i,
          status: 'wrong',
          stem: shortStem,
          userLabel: '$userLetter) ${cleanOpt(selectedIdx)}',
          correctLabel: '$rightLetter) $rightText',
        ));
      }
    }

    final answeredCount = correctCount + wrongCount;
    final scorePercent = totalLoaded > 0 ? ((correctCount / totalLoaded) * 100).round() : 0;
    final accuracyAnswered = answeredCount > 0 ? ((correctCount / answeredCount) * 100).round() : 0;
    final isApproved = scorePercent >= 70;
    final elapsedMins = widget.elapsedSeconds ~/ 60;
    final elapsedSecs = widget.elapsedSeconds % 60;

    final filteredItems = items.where((item) {
      return switch (_filter) {
        _ReviewFilter.all => true,
        _ReviewFilter.wrong => item.status == 'wrong',
        _ReviewFilter.correct => item.status == 'correct',
        _ReviewFilter.blank => item.status == 'blank',
      };
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
      backgroundColor: AsterTheme.card(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cabeçalho ──
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isApproved ? AsterConstants.menta : AsterConstants.ambar).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved ? Icons.emoji_events_rounded : Icons.analytics_rounded,
                      color: isApproved ? AsterConstants.menta : AsterConstants.ambar,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApproved ? 'Excelente Aproveitamento!' : 'Relatório & Comparativo do Simulado',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AsterTheme.text(context),
                          ),
                        ),
                        Text(
                          '${widget.examModelName ?? widget.topic} · $totalLoaded${widget.targetTotalCount > totalLoaded ? "/${widget.targetTotalCount}" : ""} questões · Tempo: ${elapsedMins}m ${elapsedSecs.toString().padLeft(2, "0")}s',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AsterTheme.textMuted(context)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Placar Comparativo (4 Cards + Barra Proporcional) ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AsterTheme.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricCol('Acertos', '$correctCount', AsterConstants.menta),
                        _metricCol('Erros', '$wrongCount', AsterConstants.coral),
                        _metricCol('Em Branco', '$blankCount', AsterTheme.textMuted(context)),
                        _metricCol(
                          'Precisão / XP',
                          '${answeredCount > 0 ? accuracyAnswered : scorePercent}% · +${correctCount * 10} XP',
                          AsterTheme.primary(context),
                        ),
                      ],
                    ),
                    if (totalLoaded > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              if (correctCount > 0)
                                Expanded(
                                  flex: correctCount,
                                  child: Container(color: AsterConstants.menta),
                                ),
                              if (wrongCount > 0)
                                Expanded(
                                  flex: wrongCount,
                                  child: Container(color: AsterConstants.coral),
                                ),
                              if (blankCount > 0)
                                Expanded(
                                  flex: blankCount,
                                  child: Container(color: AsterTheme.surfaceInset(context)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Comparativo com últimas vezes que fez este simulado ──
              if (widget.previousGroupAttempts.isNotEmpty) ...[
                Builder(builder: (context) {
                  final prev = widget.previousGroupAttempts.first;
                  final delta = scorePercent - prev.scorePercentage.round();
                  final deltaColor = delta >= 0 ? AsterConstants.menta : AsterConstants.coral;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.2)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up_rounded, size: 16, color: AsterTheme.primary(context)),
                            const SizedBox(width: 6),
                            Text(
                              'EVOLUÇÃO NESTE SIMULADO:',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AsterTheme.primary(context),
                              ),
                            ),
                          ],
                        ),
                        SoftClayTag(
                          label: delta >= 0
                              ? '+$delta% vs última (${prev.scorePercentage.round()}%)'
                              : '$delta% vs última (${prev.scorePercentage.round()}%)',
                          color: deltaColor,
                        ),
                        Text(
                          'Anteriores: ${widget.previousGroupAttempts.take(4).map((a) => "${a.scorePercentage.round()}%").join(" · ")}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // ── Conteúdo Rolável: Comparativo Questão a Questão + Review IA ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seção Review Pedagógica da IA
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AsterTheme.primary(context).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 17, color: AsterTheme.primary(context)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'REVIEW DA IA · O QUE MELHORAR',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: AsterTheme.primary(context),
                                    ),
                                  ),
                                ),
                                if (!_isLoadingReview)
                                  TextButton.icon(
                                    onPressed: _loadAiReview,
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Reanalisar'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AsterTheme.primary(context),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      textStyle: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingReview)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AsterTheme.primary(context)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Analisando suas respostas certas, erros e distratores para montar recomendações...',
                                        style: GoogleFonts.manrope(fontSize: 12.5, color: AsterTheme.textMuted(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              MarkdownBody(
                                data: _aiReviewMarkdown ?? '',
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  h3: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.text(context),
                                  ),
                                  p: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    height: 1.55,
                                    color: AsterTheme.text(context),
                                  ),
                                  listBullet: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    color: AsterTheme.primary(context),
                                    fontWeight: FontWeight.w800,
                                  ),
                                  strong: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.text(context),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Filtros do Comparativo
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'COMPARATIVO DAS QUESTÕES',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                              color: AsterTheme.textMuted(context),
                            ),
                          ),
                          _filterPill('Todas ($totalLoaded)', _ReviewFilter.all, AsterTheme.primary(context)),
                          _filterPill('Erros ($wrongCount)', _ReviewFilter.wrong, AsterConstants.coral),
                          _filterPill('Acertos ($correctCount)', _ReviewFilter.correct, AsterConstants.menta),
                          _filterPill('Em branco ($blankCount)', _ReviewFilter.blank, AsterTheme.textMuted(context)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (filteredItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AsterTheme.surfaceAlt(context),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          ),
                          child: Text(
                            'Nenhuma questão nesta categoria.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(fontSize: 12.5, color: AsterTheme.textMuted(context)),
                          ),
                        )
                      else
                        ...filteredItems.map((item) {
                          final isCorrect = item.status == 'correct';
                          final isWrong = item.status == 'wrong';
                          final statusColor = isCorrect
                              ? AsterConstants.menta
                              : (isWrong ? AsterConstants.coral : AsterTheme.textMuted(context));
                          final statusLabel = isCorrect
                              ? 'Acertou'
                              : (isWrong ? 'Errou' : 'Em branco');

                          return InkWell(
                            onTap: () => widget.onJumpToQuestion(item.index),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AsterTheme.surfaceAlt(context),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                border: Border(left: BorderSide(color: statusColor, width: 3.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Q${item.index + 1}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: GoogleFonts.manrope(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Ir para Q${item.index + 1} →',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AsterTheme.primary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.stem,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AsterTheme.text(context),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        'Sua resposta: ${item.userLabel}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isCorrect ? AsterConstants.menta : (isWrong ? AsterConstants.coral : AsterTheme.textMuted(context)),
                                        ),
                                      ),
                                      if (!isCorrect)
                                        Text(
                                          'Gabarito: ${item.correctLabel}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AsterConstants.menta,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Rodapé de Ações ──
              Row(
                children: [
                  Expanded(
                    child: SoftClayPillButton(
                      text: 'Revisar Gabarito',
                      isSecondary: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftClayPillButton(
                      text: 'Novo Simulado',
                      onPressed: widget.onNewSimulado,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.textMuted(context)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _filterPill(String label, _ReviewFilter target, Color color) {
    final selected = _filter == target;
    final onSelected = ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? const Color(0xFF111111)
        : Colors.white;
    return InkWell(
      onTap: () => setState(() => _filter = target),
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : AsterTheme.surfaceAlt(context),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? onSelected : AsterTheme.text(context),
          ),
        ),
      ),
    );
  }
}
