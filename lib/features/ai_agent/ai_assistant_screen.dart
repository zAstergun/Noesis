import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';
import '../../main.dart';
import '../quizzes/quiz_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../flashcards/models/flashcard_model.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _messageController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Content> _conversationHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (GeminiService.apiKey != null) {
      _apiKeyController.text = GeminiService.apiKey!;
    }
    _loadInitialMockChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _loadInitialMockChat() {
    _messages.addAll([
      {
        'role': 'user',
        'text': 'registra 1h30 de criptografia, estudei AES-GCM e nonce reuse',
        'time': '09:42',
      },
      {
        'role': 'tool',
        'status': 'completed',
        'text': 'log_session() · 1h30 registrada em Criptografia',
        'actionName': 'log_study_session',
      },
      {
        'role': 'ai',
        'text':
            'Feito ✅ Sessão de 1h30 salva em Criptografia. Isso fecha 42 dias de streak.\n\nNotei que seus últimos simulados focaram em modos de operação — criei um simulado com 5 questões de alto nível técnico sobre isso caso queira praticar!',
      },
      {
        'role': 'tool',
        'status': 'completed',
        'text': 'quiz.create() · 5 questões · Modos de Operação AES & GCM',
        'actionName': 'create_quiz',
        'data': {
          'title': 'Modos de Operação AES & GCM',
          'subject': 'Criptografia',
          'difficulty': 'Avançado / Nível Certificação',
        },
      },
    ]);
  }

  void _openApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          title: Text(
            'Configurar Provedor de IA',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Insira sua chave de API para habilitar o modelo oficial em nuvem com raciocínio ao vivo.',
                style: GoogleFonts.manrope(color: AsterConstants.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Chave de API (Google, OpenAI, etc.)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterConstants.textMuted)),
            ),
            SoftClayPillButton(
              text: 'Salvar Chave',
              onPressed: () {
                final key = _apiKeyController.text.trim();
                if (key.isNotEmpty) {
                  GeminiService.initialize(key);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chave de IA configurada com sucesso!')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': 'Agora'});
      _isLoading = true;
    });

    try {
      final reply = await GeminiService.executeAgentChat(
        userMessage: text,
        history: _conversationHistory,
      );

      _conversationHistory.add(Content.text(text));
      _conversationHistory.add(Content.model([TextPart(reply)]));

      if (mounted) {
        setState(() {
          for (final act in GeminiService.lastExecutedActions) {
            _messages.add({
              'role': 'tool',
              'status': act.status,
              'text': act.summary,
              'actionName': act.name,
              'parameters': act.parameters,
              'data': act.data,
            });
          }
          _messages.add({
            'role': 'ai',
            'text': reply,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': 'Erro ao processar mensagem: ${e.toString()}',
            'isError': true,
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 28.0 : 16.0,
        20.0,
        isDesktop ? 28.0 : 16.0,
        20.0,
      ),
      child: _buildChatCard(isDesktop),
    );
  }

  Widget _buildChatCard(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SoftClayCard(
      height: double.infinity,
      width: double.infinity,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header do Chat
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AsterConstants.lavanda,
                    shape: BoxShape.circle,
                    boxShadow: AsterConstants.primaryButtonShadow,
                  ),
                  child: const Center(
                    child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Noesis AI',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AsterConstants.menta, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'agente ativo · ferramentas operacionais',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.key_rounded, size: 20, color: AsterConstants.lavanda),
                  tooltip: 'Configurar Chave de API',
                  onPressed: _openApiKeyDialog,
                ),
                IconButton(
                  icon: Icon(Icons.add_rounded, size: 22, color: isDark ? AsterConstants.textLight : AsterConstants.textDark),
                  tooltip: 'Restaurar exemplo',
                  onPressed: () {
                    setState(() {
                      _messages.clear();
                      _conversationHistory.clear();
                      _loadInitialMockChat();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                  tooltip: 'Limpar conversa',
                  onPressed: () {
                    setState(() {
                      _messages.clear();
                      _conversationHistory.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
          ),

          // Mensagens do Chat
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AsterConstants.lavanda.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, size: 28, color: AsterConstants.lavanda),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Como posso ajudar seus estudos hoje?',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Peça para criar simulados, registrar estudos, agendar revisões ou resumir tópicos.',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final msg = _messages[idx];
                      final role = msg['role'];

                      // Renderizar Cartões de Ação Executada (Tool Calling)
                      if (role == 'tool') {
                        final isCompleted = msg['status'] == 'completed';
                        final color = isCompleted ? AsterConstants.menta : AsterConstants.ambar;
                        final actionName = msg['actionName'] as String?;
                        final actionData = msg['data'] as Map<String, dynamic>?;

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            constraints: BoxConstraints(maxWidth: isDesktop ? 680 : double.infinity),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded,
                                      size: 16,
                                      color: color,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCompleted ? 'AÇÃO EXECUTADA NO NOESIS' : 'EXECUTANDO...',
                                            style: GoogleFonts.manrope(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            msg['text'],
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11,
                                              color: AsterConstants.textDark,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Botão de Ação Direta para cada ferramenta criada
                                if (actionName == 'create_quiz') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      if (actionData != null && actionData['questions_data'] != null) {
                                        QuizScreen.startQuiz(
                                          title: actionData['title'] ?? 'Simulado Noesis',
                                          subject: actionData['subject'] ?? 'Tecnologia',
                                          questions: List<Map<String, dynamic>>.from(actionData['questions_data']),
                                          difficulty: actionData['difficulty'],
                                        );
                                      }
                                      RootScreen.switchTab(1);
                                    },
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterConstants.lavanda,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        boxShadow: AsterConstants.primaryButtonShadow,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Iniciar Simulado Agora 🚀',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (actionName == 'create_flashcards') ...[
                                   const SizedBox(height: 8),
                                   InkWell(
                                     onTap: () {
                                       if (actionData != null) {
                                         FlashcardsScreen.startDeck(FlashcardDeck.fromMap(actionData));
                                       }
                                       RootScreen.switchTab(2);
                                     },
                                     borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                     child: Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                       decoration: BoxDecoration(
                                         color: AsterConstants.lavanda,
                                         borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                         boxShadow: AsterConstants.primaryButtonShadow,
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           const Icon(Icons.style_rounded, size: 16, color: Colors.white),
                                           const SizedBox(width: 6),
                                           Text(
                                             'Praticar Flashcards Agora 🎴',
                                             style: GoogleFonts.manrope(
                                               fontSize: 11.5,
                                               fontWeight: FontWeight.w800,
                                               color: Colors.white,
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                 ] else if (actionName == 'schedule_calendar_event') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(4),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterConstants.surfaceCard,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterConstants.lavanda.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_month_rounded, size: 14, color: AsterConstants.lavanda),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ver no Calendário 📅',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AsterConstants.lavanda,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (actionName == 'log_study_session') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(0),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterConstants.surfaceCard,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterConstants.menta.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.dashboard_rounded, size: 14, color: AsterConstants.menta),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ver no Dashboard 📊',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AsterConstants.menta,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      final isUser = role == 'user';
                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      if (!isUser) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 760 : MediaQuery.of(context).size.width * 0.88,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF26283B) : AsterConstants.surfaceCard,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              border: Border.all(
                                color: isDark ? const Color(0xFF383A54) : AsterConstants.surfaceInset.withValues(alpha: 0.8),
                                width: 1.2,
                              ),
                              boxShadow: AsterConstants.clayListShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AsterConstants.lavanda.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.auto_awesome_rounded, size: 13, color: AsterConstants.lavanda),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Noesis AI',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AsterConstants.lavanda,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AsterConstants.lavanda.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                      ),
                                      child: Text(
                                        GeminiService.model,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          color: isDark ? const Color(0xFF9093B5) : AsterConstants.textMuted,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),

                                    // Botão Copiar
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.copy_rounded, size: 14, color: AsterConstants.textMuted),
                                      tooltip: 'Copiar resposta',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: msg['text']));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            duration: Duration(seconds: 1),
                                            content: Text('Resposta copiada para a área de transferência!'),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                RepaintBoundary(
                                  child: MarkdownBody(
                                    data: msg['text'],
                                    selectable: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: GoogleFonts.manrope(
                                        fontSize: 13.5,
                                        height: 1.55,
                                        color: isDark ? Colors.white : AsterConstants.textDark,
                                      ),
                                      strong: GoogleFonts.manrope(
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : AsterConstants.textDark,
                                      ),
                                      em: GoogleFonts.manrope(
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? const Color(0xFFB5B7CE) : AsterConstants.textMuted,
                                      ),
                                      h1: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AsterConstants.textDark),
                                      h2: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AsterConstants.textDark),
                                      h3: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AsterConstants.textDark),
                                      code: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        backgroundColor: isDark ? const Color(0xFF1E202E) : AsterConstants.surfaceInset.withValues(alpha: 0.5),
                                        color: AsterConstants.lavanda,
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF191A26) : const Color(0xFFF1F1F8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AsterConstants.surfaceInset.withValues(alpha: 0.6)),
                                      ),
                                      listBullet: GoogleFonts.manrope(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AsterConstants.lavanda,
                                      ),
                                      blockquote: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: AsterConstants.textMuted,
                                      ),
                                      blockquoteDecoration: const BoxDecoration(
                                        border: Border(left: BorderSide(color: AsterConstants.lavanda, width: 3)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 680 : MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: const BoxDecoration(
                            color: AsterConstants.lavanda,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(6),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: AsterConstants.primaryButtonShadow,
                          ),
                          child: Text(
                            msg['text'],
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AsterConstants.lavanda)),
                  const SizedBox(width: 8),
                  Text('Noesis AI processando ação...', style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted)),
                ],
              ),
            ),

          // Sugestões Rápidas de Ação
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('✨ Criar simulado sobre OWASP', () => _sendMessage('Crie um simulado de 5 questões sobre OWASP Top 10')),
                  const SizedBox(width: 8),
                  _buildQuickChip('✨ Agendar revisão sexta às 14h', () => _sendMessage('Agende uma revisão de Criptografia para sexta-feira às 14:00')),
                  const SizedBox(width: 8),
                  _buildQuickChip('✨ Resumo de Criptografia', () => _sendMessage('Faça um resumo dos principais conceitos de Criptografia')),
                  const SizedBox(width: 8),
                  _buildQuickChip('✨ Registre 1h30 de estudo', () => _sendMessage('Registre 1h30 de estudo de Criptografia')),
                  const SizedBox(width: 8),
                  _buildQuickChip('🎴 Flashcards de Criptografia', () => _sendMessage('Gere flashcards sobre Criptografia')),
                ],
              ),
            ),
          ),

          // Campo de Entrada Soft Clay
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Pergunte ou peça uma ação (simulado, agenda, tracker)...',
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AsterConstants.lavanda,
                      shape: BoxShape.circle,
                      boxShadow: AsterConstants.primaryButtonShadow,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AsterConstants.lavanda.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterConstants.lavanda),
        ),
      ),
    );
  }
}
