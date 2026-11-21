import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Configuração da Geração
  final _subjectController = TextEditingController(text: 'Cybersegurança');
  final _topicController = TextEditingController(text: 'CompTIA Security+ SY0-701');
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
  final bool _showExplanation = true;
  int _remainingSeconds = 38 * 60 + 12; // 38:12 como no mock
  Timer? _examTimer;

  @override
  void initState() {
    super.initState();
    // Carregar simulado de demonstração pré-configurado idêntico ao print de Obsidian
    _loadDemoMockQuiz();
  }

  void _loadDemoMockQuiz() {
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
        'rag_sources': ['OWASP Top 10 2021 · A10', 'AWS IMDSv2 docs', 'Suas notas · 12/03'],
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
    _userAnswers[0] = 1; // Selecionou B no mock
  }

  void _startTimer() {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _examTimer?.cancel();
      }
    });
  }

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
        const SnackBar(content: Text('Configure sua Gemini API Key na aba do Noesis AI primeiro!')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeQuestions = null;
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
          _remainingSeconds = _questionCount * 120; // 2 min por questão
          _startTimer();
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

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header do Simulado (Breadcrumbs + Tags + Timer) ───
          _buildSimuladoTopHeader(isDesktop),
          const SizedBox(height: 16),

          if (_activeQuestions != null && _activeQuestions!.isNotEmpty) ...[
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
            const SizedBox(height: 20),
            _buildBottomExamControls(),
          ] else ...[
            _buildGeneratorCard(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Widget: Top Header com Breadcrumb e Timer ───
  Widget _buildSimuladoTopHeader(bool isDesktop) {
    final totalQ = _activeQuestions?.length ?? 40;
    final currQ = _currentQuestionIndex + 1;
    final progress = (_currentQuestionIndex + 1) / totalQ;

    return Column(
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIMULADO · COMPTIA SECURITY+ SY0-701',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AsterConstants.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Questão $currQ / $totalQ',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AsterConstants.textDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SoftClayTag(label: 'AppSec', color: AsterConstants.ambar),
                    const SizedBox(width: 6),
                    const SoftClayTag(label: 'Dificuldade: Alta', color: AsterConstants.lavanda),
                  ],
                ),
              ],
            ),
            const Spacer(),

            // Timer Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AsterConstants.surfaceCard,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                boxShadow: AsterConstants.claySubtleShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AsterConstants.lavanda),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimer(_remainingSeconds),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AsterConstants.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Botão Flag
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AsterConstants.surfaceCard,
                shape: BoxShape.circle,
                boxShadow: AsterConstants.claySubtleShadow,
              ),
              child: const Icon(Icons.flag_outlined, size: 16, color: AsterConstants.textMuted),
            ),
            const SizedBox(width: 8),

            // Botão Fechar Simulado
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AsterConstants.surfaceCard,
                shape: BoxShape.circle,
                boxShadow: AsterConstants.claySubtleShadow,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, size: 18, color: AsterConstants.textDark),
                onPressed: () {
                  setState(() => _activeQuestions = null);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Barra de Progresso com Percentual
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AsterConstants.surfaceInset,
                  valueColor: const AlwaysStoppedAnimation(AsterConstants.lavanda),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AsterConstants.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Widget: Painel Esquerdo (Enunciado + Terminal Mac Code + Gabarito RAG) ───
  Widget _buildQuestionLeftPanel() {
    final currentQ = _activeQuestions![_currentQuestionIndex];
    final questionText = currentQ['question'] ?? '';
    final codeSnippet = currentQ['code_snippet'] ?? '';
    final explanation = currentQ['explanation'] ?? '';
    final hasAnswered = _userAnswers.containsKey(_currentQuestionIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftClayCard(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                questionText,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: AsterConstants.textDark,
                ),
              ),
              const SizedBox(height: 18),

              // Bloco de Código Estilo Terminal macOS
              if (codeSnippet.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AsterConstants.surfaceAlt,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pontos do macOS (Vermelho, Amarelo, Verde)
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Text(
                            'python · flask',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AsterConstants.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        codeSnippet,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          height: 1.6,
                          color: AsterConstants.textDark,
                          fontWeight: FontWeight.w600,
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

        // Cartão de Gabarito & Explicação Pedagógica Instantânea
        if (hasAnswered && _showExplanation) ...[
          const SizedBox(height: 16),
          SoftClayCard(
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
                            'Gabarito: B',
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
                        color: AsterConstants.lavanda.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        '+10 XP',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: AsterConstants.lavanda),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  explanation,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.5,
                    color: AsterConstants.textDark,
                  ),
                ),
                const SizedBox(height: 16),

                // Fontes RAG Anexadas
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      'FONTES RAG: ',
                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: AsterConstants.textMuted),
                    ),
                    _buildRagChip('OWASP Top 10 2021 · A10'),
                    _buildRagChip('AWS IMDSv2 docs'),
                    _buildRagChip('Suas notas · 12/03'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AsterConstants.surfaceAlt,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 12, color: AsterConstants.lavanda),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AsterConstants.textDark),
          ),
        ],
      ),
    );
  }

  // ─── Widget: Painel Direito com as 4 Alternativas ───
  Widget _buildAlternativesRightPanel() {
    final currentQ = _activeQuestions![_currentQuestionIndex];
    final List<dynamic> options = currentQ['options'] ?? [];
    final correctIdx = currentQ['correct_index'] as int? ?? 1;
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
            color: AsterConstants.textMuted,
          ),
        ),
        const SizedBox(height: 12),

        ...options.asMap().entries.map((entry) {
          final idx = entry.key;
          final optText = entry.value.toString();
          final isSelected = selectedIdx == idx;
          final isCorrect = idx == correctIdx;

          Color badgeBg = AsterConstants.surfaceAlt;
          Color badgeText = AsterConstants.textDark;
          Color cardBg = AsterConstants.surfaceCard;
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
            badgeBg = AsterConstants.lavanda;
            badgeText = Colors.white;
            borderColor = AsterConstants.lavanda;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              boxShadow: AsterConstants.claySubtleShadow,
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
                      // Badge da Letra
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

                      // Texto da Alternativa
                      Expanded(
                        child: Text(
                          optText,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: AsterConstants.textDark,
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

  // ─── Widget: Controles Inferiores de Navegação ───
  Widget _buildBottomExamControls() {
    final totalQ = _activeQuestions?.length ?? 1;
    final isLast = _currentQuestionIndex == totalQ - 1;

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

        // Pontos de Paginação
        Row(
          children: List.generate(totalQ, (idx) {
            final isCurrent = idx == _currentQuestionIndex;
            return Container(
              width: isCurrent ? 14 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: isCurrent ? AsterConstants.lavanda : AsterConstants.surfaceInset,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const Spacer(),

        SoftClayPillButton(
          text: isLast ? 'Finalizar Prova' : 'Próxima',
          icon: isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
          onPressed: () {
            if (!isLast) {
              setState(() => _currentQuestionIndex++);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Simulado concluído! Gabarito salvo no histórico.')),
              );
            }
          },
        ),
      ],
    );
  }

  // ─── Widget: Card Gerador de Simulado (Formulário Soft Clay) ───
  Widget _buildGeneratorCard() {
    return SoftClayCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AsterConstants.lavanda,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GERAR NOVO SIMULADO COM IA',
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                  ),
                  Text(
                    'Espelhe provas técnicas oficiais ou crie questões por tema livre',
                    style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Área / Matéria (ex: Cybersegurança, Cloud)'),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _topicController,
            decoration: const InputDecoration(labelText: 'Tópico ou Exame (ex: CompTIA Security+, AWS Solutions Architect)'),
          ),
          const SizedBox(height: 14),

          // Nível de Dificuldade
          DropdownButtonFormField<String>(
            value: _difficulty,
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
          const SizedBox(height: 18),

          Row(
            children: [
              Text('Quantidade de Questões: ', style: GoogleFonts.manrope(color: AsterConstants.textMuted)),
              Text('$_questionCount', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AsterConstants.lavanda)),
            ],
          ),
          Slider(
            value: _questionCount.toDouble(),
            min: 3,
            max: 15,
            divisions: 12,
            activeColor: AsterConstants.lavanda,
            onChanged: (val) => setState(() => _questionCount = val.toInt()),
          ),
          const SizedBox(height: 14),

          // Opção de anexar prova para RAG
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Espelhar Prova ou Apostila Anexada (RAG)', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text('Gera questões idênticas à banca examinadora dos seus arquivos', style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted)),
            value: _useDocument,
            activeColor: AsterConstants.lavanda,
            onChanged: (val) => setState(() => _useDocument = val),
          ),

          if (_useDocument) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SoftClayPillButton(
                  text: _uploadedFileName != null ? 'Arquivo: $_uploadedFileName' : 'Anexar PDF / MD / TXT',
                  icon: Icons.attach_file_rounded,
                  isSecondary: true,
                  onPressed: _pickDocumentFile,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _documentTextController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Trechos de Provas Anteriores ou Edital',
                hintText: 'Cole questões antigas para a IA extrair a estilística...',
              ),
            ),
          ],
          const SizedBox(height: 24),

          SoftClayPillButton(
            text: _isGenerating ? 'Gerando Simulado com Gemini...' : 'Criar Prova Interativa',
            icon: Icons.psychology_rounded,
            padding: const EdgeInsets.symmetric(vertical: 16),
            onPressed: _isGenerating ? null : _startGenerateQuiz,
          ),
        ],
      ),
    );
  }
}
