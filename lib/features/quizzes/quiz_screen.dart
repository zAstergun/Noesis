import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';

String _decodeUtf8Bytes(List<int> bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ─── Configuração da Geração ───
  final _subjectController = TextEditingController(text: 'Cybersegurança');
  final _topicController = TextEditingController(text: 'CompTIA Security+ SY0-701');
  final _documentTextController = TextEditingController();
  int _questionCount = 5;
  String _difficulty = 'Avançado / Nível Certificação';
  bool _useDocument = false;
  String? _uploadedFileName;

  // ─── Presets de Exames Oficiais ───
  final List<Map<String, dynamic>> _examPresets = [
    {
      'icon': Icons.shield_outlined,
      'label': 'CompTIA Security+',
      'badge': 'SY0-701',
      'subject': 'Cybersegurança',
      'topic': 'CompTIA Security+ SY0-701',
      'difficulty': 'Avançado / Nível Certificação',
      'count': 5,
      'accent': AsterConstants.lavanda,
    },
    {
      'icon': Icons.cloud_outlined,
      'label': 'AWS Solutions Architect',
      'badge': 'SAA-C03',
      'subject': 'Cloud Computing',
      'topic': 'AWS Solutions Architect Associate (SAA-C03)',
      'difficulty': 'Avançado / Nível Certificação',
      'count': 5,
      'accent': AsterConstants.ambar,
    },
    {
      'icon': Icons.lock_outline_rounded,
      'label': 'OWASP Top 10 & AppSec',
      'badge': 'AppSec',
      'subject': 'Segurança de Software',
      'topic': 'OWASP Top 10 · Vulnerabilidades e Mitigações',
      'difficulty': 'Médio / Prático',
      'count': 5,
      'accent': AsterConstants.coral,
    },
    {
      'icon': Icons.vpn_key_outlined,
      'label': 'Criptografia & PKI',
      'badge': 'Crypto',
      'subject': 'Segurança da Informação',
      'topic': 'Criptografia Simétrica, Assimétrica e PKI',
      'difficulty': 'Avançado / Nível Certificação',
      'count': 5,
      'accent': AsterConstants.lavanda,
    },
    {
      'icon': Icons.flutter_dash,
      'label': 'Flutter Architecture',
      'badge': 'Mobile',
      'subject': 'Engenharia de Software',
      'topic': 'Flutter State Management, BLoC e Clean Architecture',
      'difficulty': 'Médio / Prático',
      'count': 5,
      'accent': AsterConstants.menta,
    },
    {
      'icon': Icons.hub_outlined,
      'label': 'Kubernetes & CKA',
      'badge': 'DevOps',
      'subject': 'Infraestrutura & DevOps',
      'topic': 'Kubernetes Pods, Services, Ingress e Redes CKA',
      'difficulty': 'Médio / Prático',
      'count': 5,
      'accent': AsterConstants.ambar,
    },
  ];

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
      'color': AsterConstants.lavanda,
    },
  ];

  // ─── Estado da Execução do Simulado ───
  bool _isGenerating = false;
  List<Map<String, dynamic>>? _activeQuestions;
  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {}; // { questionIndex: selectedOptionIndex }
  final Set<int> _flaggedQuestions = {}; // Questões marcadas para revisão
  final bool _showExplanation = true;
  int _remainingSeconds = 38 * 60 + 12; // 38:12 no mock
  late final ValueNotifier<int> _timerNotifier;
  Timer? _examTimer;

  @override
  void initState() {
    super.initState();
    _timerNotifier = ValueNotifier<int>(_remainingSeconds);
    // Inicia na tela do Gerador com opção imediata de carregar a Demo
    _activeQuestions = null;
  }

  void _loadDemoMockQuiz() {
    setState(() {
      _subjectController.text = 'Cybersegurança';
      _topicController.text = 'CompTIA Security+ SY0-701';
      _difficulty = 'Avançado / Nível Certificação';
      _questionCount = 2;
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
      _remainingSeconds = 38 * 60 + 12;
      _startTimer();
    });
  }

  void _startTimer() {
    _examTimer?.cancel();
    _timerNotifier.value = _remainingSeconds;
    _examTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _timerNotifier.value = _remainingSeconds;
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

  Future<void> _startGenerateQuiz() async {
    final isCustom = GeminiService.provider == 'custom';
    final hasKey = GeminiService.apiKey != null && GeminiService.apiKey!.trim().isNotEmpty;

    if (!isCustom && !hasKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

    setState(() {
      _isGenerating = true;
      _activeQuestions = null;
      _userAnswers.clear();
      _flaggedQuestions.clear();
      _currentQuestionIndex = 0;
    });

    try {
      final questions = await GeminiService.generateQuiz(
        subject: _subjectController.text.trim().isEmpty ? 'Geral' : _subjectController.text.trim(),
        topic: _topicController.text.trim().isEmpty ? 'Conhecimentos Gerais' : _topicController.text.trim(),
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

  void _showExamCompletionDialog() {
    final totalQ = _activeQuestions?.length ?? 1;
    int correctCount = 0;

    for (int i = 0; i < totalQ; i++) {
      final q = _activeQuestions![i];
      final correctIdx = q['correct_index'] as int? ?? 0;
      if (_userAnswers[i] == correctIdx) {
        correctCount++;
      }
    }

    final scorePercent = ((correctCount / totalQ) * 100).toInt();
    final isApproved = scorePercent >= 70;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
        backgroundColor: AsterConstants.surfaceCard,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (isApproved ? AsterConstants.menta : AsterConstants.ambar).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved ? Icons.emoji_events_rounded : Icons.auto_awesome_rounded,
                  color: isApproved ? AsterConstants.menta : AsterConstants.ambar,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isApproved ? 'Excelente Aproveitamento!' : 'Simulado Finalizado!',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AsterConstants.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Você acertou $correctCount de $totalQ questões ($scorePercent%).',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 14, color: AsterConstants.textMuted),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Pontuação', style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted)),
                        const SizedBox(height: 4),
                        Text('$scorePercent%', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AsterConstants.lavanda)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: AsterConstants.surfaceInset),
                    Column(
                      children: [
                        Text('XP Ganho', style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted)),
                        const SizedBox(height: 4),
                        Text('+${correctCount * 10} XP', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AsterConstants.menta)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: AsterConstants.surfaceInset),
                    Column(
                      children: [
                        Text('Status', style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          isApproved ? 'Aprovado' : 'Revisão',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isApproved ? AsterConstants.menta : AsterConstants.coral,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SoftClayPillButton(
                      text: 'Revisar Gabarito',
                      isSecondary: true,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SoftClayPillButton(
                      text: 'Novo Simulado',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _activeQuestions = null;
                          _examTimer?.cancel();
                        });
                      },
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

  @override
  void dispose() {
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
          // Se houver simulado ativo, mostra o Header do Exame + Questão + Alternativas
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
          ] else ...[
            // Quando não há simulado ativo, mostra Header do Gerador e Formulário Sofisticado
            _buildGeneratorHeader(isDesktop),
            const SizedBox(height: 18),
            _buildGeneratorCard(isDesktop),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Header da Tela do Gerador (Quando Nenhum Simulado está Rodando) ───
  Widget _buildGeneratorHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: BoxDecoration(
        color: AsterConstants.surfaceCard,
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        boxShadow: AsterConstants.clayShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AsterConstants.lavanda.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.psychology_rounded, color: AsterConstants.lavanda, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SoftClayTag(
                      label: 'NOESIS QUIZ ENGINE · IA',
                      color: AsterConstants.lavanda,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        '${GeminiService.currentProvider.label} · ${GeminiService.model}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AsterConstants.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Banco de Simulados & Exames Técnicos',
                  style: GoogleFonts.manrope(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AsterConstants.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Espelhe provas de bancas examinadoras oficiais, treine com questões dinâmicas ou carregue apostilas para RAG.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AsterConstants.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            SoftClayPillButton(
              text: 'Carregar Exame Demo',
              icon: Icons.play_circle_outline_rounded,
              isSecondary: true,
              onPressed: _loadDemoMockQuiz,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Header do Simulado em Andamento (Breadcrumbs + Tags + Timer) ───
  Widget _buildSimuladoTopHeader(bool isDesktop) {
    final totalQ = _activeQuestions?.length ?? 1;
    final currQ = _currentQuestionIndex + 1;
    final progress = currQ / totalQ;

    final subjectStr = _subjectController.text.trim().isEmpty ? 'GERAL' : _subjectController.text.trim().toUpperCase();
    final topicStr = _topicController.text.trim().isEmpty ? 'SIMULADO TÉCNICO' : _topicController.text.trim().toUpperCase();
    final isFlagged = _flaggedQuestions.contains(_currentQuestionIndex);

    return Column(
      children: [
        Row(
          children: [
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
                      color: AsterConstants.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Questão $currQ / $totalQ',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AsterConstants.textDark,
                        ),
                      ),
                      SoftClayTag(
                        label: _subjectController.text.trim().isNotEmpty ? _subjectController.text.trim() : 'Geral',
                        color: AsterConstants.ambar,
                      ),
                      SoftClayTag(
                        label: _difficulty.split(' / ').first,
                        color: AsterConstants.lavanda,
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                  ValueListenableBuilder<int>(
                    valueListenable: _timerNotifier,
                    builder: (context, secs, _) {
                      return Text(
                        _formatTimer(secs),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AsterConstants.textDark,
                        ),
                      );
                    },
                  ),
                ],
              ),
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
                    color: isFlagged ? AsterConstants.ambar.withValues(alpha: 0.15) : AsterConstants.surfaceCard,
                    shape: BoxShape.circle,
                    boxShadow: AsterConstants.claySubtleShadow,
                    border: isFlagged ? Border.all(color: AsterConstants.ambar, width: 1.5) : null,
                  ),
                  child: Icon(
                    isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                    size: 16,
                    color: isFlagged ? AsterConstants.ambar : AsterConstants.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botão Fechar Simulado (Voltar ao Gerador)
            Tooltip(
              message: 'Sair do Simulado e voltar ao Gerador',
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AsterConstants.surfaceCard,
                  shape: BoxShape.circle,
                  boxShadow: AsterConstants.claySubtleShadow,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, size: 18, color: AsterConstants.textDark),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
                        title: Text('Sair do Simulado?', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                        content: Text(
                          'Seu progresso atual nesta sessão será encerrado e você voltará ao menu de geração.',
                          style: GoogleFonts.manrope(fontSize: 13, color: AsterConstants.textMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Continuar Prova'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _activeQuestions = null;
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

        // Barra de Progresso com Percentual
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                backgroundColor: AsterConstants.surfaceInset,
                valueColor: const AlwaysStoppedAnimation(AsterConstants.lavanda),
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

  // ─── Widget: Painel Esquerdo (Enunciado + Bloco Terminal Code + Gabarito RAG) ───
  Widget _buildQuestionLeftPanel() {
    final currentQ = _activeQuestions![_currentQuestionIndex];
    final questionText = currentQ['question'] ?? '';
    final codeSnippet = currentQ['code_snippet'] ?? '';
    final explanation = currentQ['explanation'] ?? '';
    final hasAnswered = _userAnswers.containsKey(_currentQuestionIndex);
    final correctIdx = currentQ['correct_index'] as int? ?? 0;
    final letters = ['A', 'B', 'C', 'D', 'E'];
    final correctLetter = letters[correctIdx % letters.length];

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
                            'código-fonte de referência',
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

        // Cartão de Gabarito & Explicação Pedagógica Instantânea
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
                    _buildRagChip('Noesis Vault · Notas'),
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

  // ─── Widget: Painel Direito com as Alternativas ───
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

        // Pontos de Paginação com indicação de marcada (flag)
        Row(
          children: List.generate(totalQ, (idx) {
            final isCurrent = idx == _currentQuestionIndex;
            final isFlagged = _flaggedQuestions.contains(idx);
            final isAnswered = _userAnswers.containsKey(idx);

            Color dotColor = AsterConstants.surfaceInset;
            if (isFlagged) {
              dotColor = AsterConstants.ambar;
            } else if (isCurrent) {
              dotColor = AsterConstants.lavanda;
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
        ),
        const Spacer(),

        SoftClayPillButton(
          text: isLast ? 'Finalizar Prova' : 'Próxima',
          icon: isLast ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
          onPressed: () {
            if (!isLast) {
              setState(() => _currentQuestionIndex++);
            } else {
              _showExamCompletionDialog();
            }
          },
        ),
      ],
    );
  }

  // ─── Widget: Card Gerador de Simulado (Formulário Moderno & Soft Clay) ───
  Widget _buildGeneratorCard(bool isDesktop) {
    return SoftClayCard(
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header do Card com Ícone Concêntrico e Status da IA ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AsterConstants.lavanda,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GERAR NOVO SIMULADO COM IA',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        color: AsterConstants.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Escolha um template rápido ou personalize a disciplina, nível e fontes',
                      style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AsterConstants.lavanda.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: AsterConstants.lavanda),
                    const SizedBox(width: 5),
                    Text(
                      GeminiService.currentProvider.label,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AsterConstants.lavanda,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Templates Rápidos (1-Clique) ──
          Text(
            'EXAMES & TEMPLATES RÁPIDOS',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AsterConstants.textMuted,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examPresets.map((preset) {
              final isSelected = _topicController.text == preset['topic'];
              final accent = preset['accent'] as Color;

              return InkWell(
                onTap: () {
                  setState(() {
                    _subjectController.text = preset['subject'];
                    _topicController.text = preset['topic'];
                    _difficulty = preset['difficulty'];
                    _questionCount = preset['count'];
                  });
                },
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.15) : AsterConstants.surfaceAlt,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(
                      color: isSelected ? accent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(preset['icon'] as IconData, size: 15, color: isSelected ? accent : AsterConstants.textDark),
                      const SizedBox(width: 6),
                      Text(
                        preset['label'] as String,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? accent : AsterConstants.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : AsterConstants.surfaceInset,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          preset['badge'] as String,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AsterConstants.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          // ── Campos de Área e Tópico ──
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Área / Matéria',
                      hintText: 'Ex: Cybersegurança, Cloud, Redes...',
                      prefixIcon: Icon(Icons.category_outlined, size: 18, color: AsterConstants.lavanda),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Tópico ou Exame',
                      hintText: 'Ex: CompTIA Security+, AWS SAA...',
                      prefixIcon: Icon(Icons.school_outlined, size: 18, color: AsterConstants.lavanda),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Área / Matéria',
                hintText: 'Ex: Cybersegurança, Cloud...',
                prefixIcon: Icon(Icons.category_outlined, size: 18, color: AsterConstants.lavanda),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Tópico ou Exame',
                hintText: 'Ex: CompTIA Security+, AWS SAA...',
                prefixIcon: Icon(Icons.school_outlined, size: 18, color: AsterConstants.lavanda),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Seletor Visual de Dificuldade (3 Cards Soft Clay) ──
          Text(
            'NÍVEL DE PROFUNDIDADE',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AsterConstants.textMuted,
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

          // ── Quantidade de Questões com Pills Rápidas e Slider ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUANTIDADE DE QUESTÕES',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AsterConstants.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  '⏱️ ~${_questionCount * 2} min estimados (2 min/questão)',
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterConstants.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              // Botões Rápidos de Quantidade
              Wrap(
                spacing: 6,
                children: [5, 10, 15, 20].map((count) {
                  final isSelected = _questionCount == count;
                  return InkWell(
                    onTap: () => setState(() => _questionCount = count),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AsterConstants.lavanda : AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        '$count Q',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AsterConstants.textDark,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AsterConstants.lavanda,
                    inactiveTrackColor: AsterConstants.surfaceInset,
                    thumbColor: AsterConstants.lavanda,
                    overlayColor: AsterConstants.lavanda.withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _questionCount.toDouble(),
                    min: 3,
                    max: 20,
                    divisions: 17,
                    onChanged: (val) => setState(() => _questionCount = val.toInt()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                alignment: Alignment.center,
                child: Text(
                  '$_questionCount',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AsterConstants.lavanda,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Opção de Anexar Documento para RAG ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AsterConstants.surfaceAlt,
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Icon(Icons.feed_outlined, size: 18, color: AsterConstants.lavanda),
                        const SizedBox(width: 8),
                        Text(
                          'Espelhar Apostila ou Prova Anterior (RAG)',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 13, color: AsterConstants.textDark),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'A IA analisa arquivos ou anotações e reproduz a estilística e pegadinhas exatas da sua banca',
                      style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted),
                    ),
                    value: _useDocument,
                    activeColor: AsterConstants.lavanda,
                    onChanged: (val) => setState(() => _useDocument = val),
                  ),
                ),

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
                              color: AsterConstants.surfaceCard,
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              border: Border.all(color: AsterConstants.lavanda.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description_outlined, size: 15, color: AsterConstants.lavanda),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _uploadedFileName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterConstants.textDark),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _uploadedFileName = null;
                                      _documentTextController.clear();
                                    });
                                  },
                                  child: const Icon(Icons.close_rounded, size: 16, color: AsterConstants.textMuted),
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
                    decoration: const InputDecoration(
                      labelText: 'Trechos de Provas Anteriores ou Edital',
                      hintText: 'Cole questões antigas ou ementa técnica para a IA espelhar o estilo da banca...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Botões de Ação Final (Criar com IA ou Testar Demo) ──
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SoftClayPillButton(
                  text: _isGenerating
                      ? 'Gerando Simulado com ${GeminiService.currentProvider.label}...'
                      : 'Criar Prova Interativa com IA',
                  icon: _isGenerating ? null : Icons.psychology_rounded,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: _isGenerating ? null : _startGenerateQuiz,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SoftClayPillButton(
                  text: 'Testar com Demo',
                  icon: Icons.play_circle_outline_rounded,
                  isSecondary: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: _loadDemoMockQuiz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Card Individual do Seletor de Dificuldade ───
  Widget _buildDifficultyOptionCard(Map<String, dynamic> lvl) {
    final isSelected = _difficulty == lvl['id'];
    final color = lvl['color'] as Color;

    return InkWell(
      onTap: () => setState(() => _difficulty = lvl['id']),
      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.10) : AsterConstants.surfaceAlt,
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
                    color: isSelected ? color : AsterConstants.surfaceInset,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    lvl['icon'] as IconData,
                    size: 15,
                    color: isSelected ? Colors.white : AsterConstants.textMuted,
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
                      border: Border.all(color: AsterConstants.surfaceInset, width: 1.5),
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
                color: isSelected ? color : AsterConstants.textDark,
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
                color: AsterConstants.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
