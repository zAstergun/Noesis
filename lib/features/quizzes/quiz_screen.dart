import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../core/gemini_service.dart';
import '../../core/supabase_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Configuração da Geração
  final _subjectController = TextEditingController(text: 'Cybersegurança');
  final _topicController = TextEditingController(text: 'Web Security (OWASP Top 10)');
  final _documentTextController = TextEditingController();
  int _questionCount = 5;
  String _difficulty = 'Avançado / Nível Certificação';
  bool _useDocument = false;
  String? _uploadedFileName;

  // Estado da Execução do Simulado
  bool _isGenerating = false;
  List<Map<String, dynamic>>? _activeQuestions;
  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {}; // { questionIndex: selectedOptionIndex }
  bool _isExamCompleted = false;
  DateTime? _examStartTime;
  double _finalScore = 0.0;

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
          final text = utf8.decode(bytes);
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

  Future<void> _startGenerateQuiz() async {
    if (GeminiService.apiKey == null || GeminiService.apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure sua Gemini API Key na aba do Assistente de IA primeiro!')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeQuestions = null;
      _isExamCompleted = false;
      _userAnswers.clear();
      _currentQuestionIndex = 0;
    });

    try {
      final questions = await GeminiService.generateQuiz(
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        referenceDocumentText: _useDocument && _documentTextController.text.trim().isNotEmpty
            ? _documentTextController.text.trim()
            : null,
        numberOfQuestions: _questionCount,
        difficulty: _difficulty,
      );

      if (mounted) {
        setState(() {
          _activeQuestions = questions;
          _examStartTime = DateTime.now();
        });
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

  void _finishExam() async {
    if (_activeQuestions == null) return;
    int correctCount = 0;
    for (int i = 0; i < _activeQuestions!.length; i++) {
      final correctIdx = _activeQuestions![i]['correct_index'] as int;
      if (_userAnswers[i] == correctIdx) {
        correctCount++;
      }
    }

    final score = (correctCount / _activeQuestions!.length) * 100;
    final durationSeconds = _examStartTime != null ? DateTime.now().difference(_examStartTime!).inSeconds : 0;

    setState(() {
      _finalScore = score;
      _isExamCompleted = true;
    });

    // Salvar resultado automaticamente no Supabase
    try {
      await SupabaseService.saveQuizResult(
        title: '${_subjectController.text.trim()} - ${_topicController.text.trim()}',
        subject: _subjectController.text.trim(),
        questionsData: _activeQuestions!,
        scorePercentage: score,
        timeSpentSeconds: durationSeconds,
      );
    } catch (e) {
      debugPrint('Erro ao salvar no Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Questões & Provas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_activeQuestions == null && !_isGenerating) ...[
              // FORMULÁRIO DE GERAÇÃO
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology, color: AsterConstants.secondary),
                          SizedBox(width: 8),
                          Text(
                            'CRIAR NOVO SIMULADO COM IA',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1, color: AsterConstants.textLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(labelText: 'Matéria / Área (ex: Programação, Cybersegurança)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _topicController,
                        decoration: const InputDecoration(labelText: 'Tópico ou Certificação (ex: Docker, CISSP, CompTIA Security+)'),
                      ),
                      const SizedBox(height: 14),

                      // Nível de Dificuldade
                      DropdownButtonFormField<String>(
                        initialValue: _difficulty,
                        dropdownColor: AsterConstants.surfaceDark,
                        decoration: const InputDecoration(labelText: 'Nível da Prova'),
                        items: const [
                          DropdownMenuItem(value: 'Iniciante / Fundamentos', child: Text('Iniciante / Fundamentos')),
                          DropdownMenuItem(value: 'Médio / Prático', child: Text('Médio / Prático')),
                          DropdownMenuItem(value: 'Avançado / Nível Certificação', child: Text('Avançado / Nível Certificação')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _difficulty = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Quantidade de Questões
                      Row(
                        children: [
                          const Text('Quantidade de Questões: ', style: TextStyle(color: AsterConstants.textMuted)),
                          Text('$_questionCount', style: const TextStyle(fontWeight: FontWeight.bold, color: AsterConstants.secondary)),
                        ],
                      ),
                      Slider(
                        value: _questionCount.toDouble(),
                        min: 3,
                        max: 15,
                        divisions: 12,
                        activeColor: AsterConstants.secondary,
                        onChanged: (val) => setState(() => _questionCount = val.toInt()),
                      ),
                      const SizedBox(height: 12),

                      // Switch: Usar Documento / Provas Anteriores
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Guiar por Documento ou Provas Anteriores', style: TextStyle(fontSize: 14)),
                        subtitle: const Text('A IA espelha o estilo, terminologia e nível de provas que você enviar', style: TextStyle(fontSize: 12, color: AsterConstants.textDim)),
                        value: _useDocument,
                        activeColor: AsterConstants.secondary,
                        onChanged: (val) => setState(() => _useDocument = val),
                      ),

                      if (_useDocument) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickDocumentFile,
                              style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.surfaceDark),
                              icon: const Icon(Icons.attach_file, color: AsterConstants.secondary),
                              label: Text(_uploadedFileName != null ? 'Arquivo: $_uploadedFileName' : 'Anexar Prova / Apostila'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _documentTextController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Conteúdo ou Texto de Referência (ou digite/cole aqui)',
                            hintText: 'Cole questões antigas, gabaritos comentados ou trechos do edital...',
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _startGenerateQuiz,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Gerar Simulado Agora'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_isGenerating) ...[
              // LOADING SCREEN
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: const [
                    CircularProgressIndicator(color: AsterConstants.secondary),
                    SizedBox(height: 20),
                    Text(
                      'Gerando questões inéditas e gabarito técnico detalhado...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AsterConstants.textMuted),
                    ),
                  ],
                ),
              ),
            ] else if (_activeQuestions != null && !_isExamCompleted) ...[
              // EXAM RUNNER
              _buildExamRunner(),
            ] else if (_isExamCompleted) ...[
              // EXAM RESULTS
              _buildExamResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamRunner() {
    final q = _activeQuestions![_currentQuestionIndex];
    final options = List<String>.from(q['options']);
    final selectedOption = _userAnswers[_currentQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUESTÃO ${_currentQuestionIndex + 1} DE ${_activeQuestions!.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AsterConstants.secondary),
            ),
            Text(
              '${_userAnswers.length} respondidas',
              style: const TextStyle(color: AsterConstants.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _activeQuestions!.length,
          color: AsterConstants.secondary,
          backgroundColor: AsterConstants.surfaceDark,
        ),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              q['question'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4, color: AsterConstants.textLight),
            ),
          ),
        ),
        const SizedBox(height: 16),

        ...List.generate(options.length, (idx) {
          final isSelected = selectedOption == idx;
          final letters = ['A', 'B', 'C', 'D', 'E'];
          final letter = idx < letters.length ? letters[idx] : '$idx';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _userAnswers[_currentQuestionIndex] = idx;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AsterConstants.primary.withValues(alpha: 0.2) : AsterConstants.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AsterConstants.secondary : AsterConstants.borderDark,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AsterConstants.secondary : AsterConstants.cardDark,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : AsterConstants.textLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        options[idx],
                        style: const TextStyle(color: AsterConstants.textLight, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentQuestionIndex > 0)
              OutlinedButton(
                onPressed: () => setState(() => _currentQuestionIndex--),
                child: const Text('Anterior'),
              )
            else
              const SizedBox.shrink(),
            if (_currentQuestionIndex < _activeQuestions!.length - 1)
              ElevatedButton(
                onPressed: () => setState(() => _currentQuestionIndex++),
                child: const Text('Próxima'),
              )
            else
              ElevatedButton.icon(
                onPressed: _finishExam,
                style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.secondary),
                icon: const Icon(Icons.check, color: Colors.black),
                label: const Text('Finalizar Prova', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildExamResults() {
    int correctCount = 0;
    for (int i = 0; i < _activeQuestions!.length; i++) {
      if (_userAnswers[i] == (_activeQuestions![i]['correct_index'] as int)) {
        correctCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('RESULTADO DO SIMULADO', style: TextStyle(color: AsterConstants.textMuted, letterSpacing: 1.2, fontSize: 12)),
                const SizedBox(height: 12),
                Text(
                  '${_finalScore.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: _finalScore >= 70 ? AsterConstants.secondary : AsterConstants.accentRose,
                  ),
                ),
                Text(
                  '$correctCount de ${_activeQuestions!.length} questões corretas',
                  style: const TextStyle(fontSize: 16, color: AsterConstants.textLight),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _activeQuestions = null;
                      _isExamCompleted = false;
                    });
                  },
                  child: const Text('Criar Outro Simulado'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const Text('GABARITO COMENTADO & EXPLICAÇÕES', style: TextStyle(fontWeight: FontWeight.bold, color: AsterConstants.textMuted, fontSize: 13)),
        const SizedBox(height: 12),

        ...List.generate(_activeQuestions!.length, (idx) {
          final q = _activeQuestions![idx];
          final correctIdx = q['correct_index'] as int;
          final userIdx = _userAnswers[idx];
          final isCorrect = userIdx == correctIdx;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? AsterConstants.secondary : AsterConstants.accentRose,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Questão ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(q['question'], style: const TextStyle(color: AsterConstants.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(
                    'Correta: ${q['options'][correctIdx]}',
                    style: const TextStyle(color: AsterConstants.secondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (!isCorrect && userIdx != null)
                    Text(
                      'Sua resposta: ${q['options'][userIdx]}',
                      style: const TextStyle(color: AsterConstants.accentRose, fontSize: 13),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AsterConstants.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '💡 ${q['explanation'] ?? ''}',
                      style: const TextStyle(color: AsterConstants.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
