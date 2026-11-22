import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';

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
  bool _isListening = false;

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      _openVoiceInputDialog();
    }
  }

  void _openVoiceInputDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final commands = [
              'Registre 1h30 de estudo de Criptografia',
              'Agende uma revisão para amanhã às 14:00',
              'Crie um simulado de 5 questões sobre OWASP',
              'Faça um resumo dos modos de operação AES',
              'Como funciona o nonce reuse em criptografia?',
            ];

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E202E) : AsterConstants.surfaceCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AsterConstants.clayShadow,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AsterConstants.textFaint.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AsterConstants.coral.withValues(alpha: 0.12),
                        border: Border.all(color: AsterConstants.coral.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.mic_rounded, size: 34, color: AsterConstants.coral),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Entrada por Voz · Noesis AI',
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AsterConstants.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fale naturalmente ou toque em uma sugestão para transcrever e enviar:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF9093B5) : AsterConstants.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: commands.map((cmd) {
                        return InkWell(
                          onTap: () {
                            _messageController.text = cmd;
                            Navigator.pop(ctx);
                            setState(() => _isListening = false);
                            _sendMessage();
                          },
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF26283B) : AsterConstants.surfaceAlt,
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              border: Border.all(
                                color: isDark ? const Color(0xFF383A54) : AsterConstants.surfaceInset,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mic_rounded, size: 14, color: AsterConstants.lavanda),
                                const SizedBox(width: 6),
                                Text(
                                  cmd,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AsterConstants.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AsterConstants.textMuted,
                              side: const BorderSide(color: AsterConstants.surfaceInset),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _isListening = false);
                            },
                            child: Text('Fechar', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (GeminiService.apiKey != null) {
      _apiKeyController.text = GeminiService.apiKey!;
    }
    _loadInitialMockChat();
  }

  void _loadInitialMockChat() {
    // Configura o histórico inicial idêntico ao print clay-06 de Obsidian
    _messages.addAll([
      {
        'role': 'user',
        'text': 'registra 1h30 de criptografia, estudei AES-GCM e nonce reuse',
        'time': '09:42',
      },
      {
        'role': 'tool',
        'status': 'completed',
        'text': 'log_session() · 1h30 registrada em Criptografia n...',
      },
      {
        'role': 'tool',
        'status': 'completed',
        'text': 'update_notes() · tags: aes-gcm, nonce-reuse',
      },
      {
        'role': 'ai',
        'text':
            'Feito ✅ Sessão de 1h30 salva em Criptografia. Isso fecha 42 dias de streak. Notei que seus últimos 3 simulados erraram questões de modos de operação — quer que eu monte 10 questões focadas nisso?',
      },
      {
        'role': 'user',
        'text': 'sim, e agenda pra sexta',
      },
      {
        'role': 'tool',
        'status': 'completed',
        'text': 'generate_quiz(rag) · 10 questões · AES/GCM/CB...',
      },
      {
        'role': 'tool',
        'status': 'running',
        'text': 'calendar.create() · Sex 14:00 · Revisão Criptogr...',
      },
    ]);
  }

  void _openApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AsterConstants.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
        title: Text(
          'Configurar Google Gemini API Key',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AsterConstants.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insira sua chave do Google AI Studio para executar ações com Function Calling no Supabase.',
              style: GoogleFonts.manrope(color: AsterConstants.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'AI Studio Gemini API Key'),
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
                  const SnackBar(content: Text('Chave Gemini configurada com sucesso!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (GeminiService.apiKey == null || GeminiService.apiKey!.isEmpty) {
      _openApiKeyDialog();
      return;
    }

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
          _messages.add({'role': 'ai', 'text': reply});
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
        0,
        isDesktop ? 28.0 : 16.0,
        16.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _buildChatCard(isDesktop),
        ),
      ),
    );
  }

  // ─── Widget: Cartão do Chat Noesis AI ───
  Widget _buildChatCard(bool isDesktop) {
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
                      style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                    ),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AsterConstants.menta, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'agente ativo · 6 ferramentas',
                          style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.key_rounded, size: 20, color: AsterConstants.lavanda),
                  tooltip: 'Configurar Gemini API Key',
                  onPressed: _openApiKeyDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22, color: AsterConstants.textDark),
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
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AsterConstants.textMuted),
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
          const Divider(),

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
                            color: AsterConstants.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Peça para criar simulados, resumir tópicos ou agendar revisões.',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AsterConstants.textMuted,
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
                            child: Row(
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
                                        isCompleted ? 'AÇÃO EXECUTADA' : 'EXECUTANDO...',
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
                  Text('Noesis AI pensando...', style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted)),
                ],
              ),
            ),

          if (_isListening)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AsterConstants.coral.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(color: AsterConstants.coral.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AsterConstants.coral, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Microfone ativo · Fale ou escolha um comando rápido de voz',
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: AsterConstants.coral),
                      ),
                    ),
                    InkWell(
                      onTap: _openVoiceInputDialog,
                      child: Text(
                        'Ver opções',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: AsterConstants.lavanda),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _isListening = false),
                      child: const Icon(Icons.close_rounded, size: 16, color: AsterConstants.textMuted),
                    ),
                  ],
                ),
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
                color: AsterConstants.surfaceAlt,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Pergunte ou peça uma ação...',
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 20,
                      color: _isListening ? AsterConstants.coral : AsterConstants.lavanda,
                    ),
                    tooltip: _isListening ? 'Parar gravação' : 'Falar com Noesis AI',
                    onPressed: _toggleListening,
                  ),
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
