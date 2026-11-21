import 'package:flutter/material.dart';
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
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 12.0,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Painel Esquerdo: Área de Trabalho (Notas e Métricas)
                Expanded(flex: 5, child: _buildWorkspaceLeftPanel()),
                const SizedBox(width: 20),
                // Painel Direito: Chat do Agente Noesis AI
                Expanded(flex: 6, child: _buildChatCard()),
              ],
            )
          : _buildChatCard(),
    );
  }

  // ─── Widget: Painel da Área de Trabalho (Contexto do Estudo) ───
  Widget _buildWorkspaceLeftPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Área de trabalho',
                    style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w900, color: AsterConstants.textDark),
                  ),
                  Text(
                    'Criptografia · notas e materiais',
                    style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.key, size: 20, color: AsterConstants.lavanda),
                    tooltip: 'Chave Gemini',
                    onPressed: _openApiKeyDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card: Notas Ativas
          SoftClayCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 18, color: AsterConstants.coral),
                        const SizedBox(width: 8),
                        Text(
                          'AES-GCM — notas',
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                        ),
                      ],
                    ),
                    Text(
                      'editado agora',
                      style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Esqueleto de Linhas Suaves do Texto da Nota
                ...List.generate(4, (i) {
                  return Container(
                    height: 8,
                    margin: const EdgeInsets.only(bottom: 8),
                    width: i == 3 ? 140 : double.infinity,
                    decoration: BoxDecoration(
                      color: AsterConstants.surfaceInset.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Tags de Estudo
                const Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    SoftClayTag(label: 'aes-gcm', color: AsterConstants.lavanda),
                    SoftClayTag(label: 'nonce-reuse', color: AsterConstants.lavanda),
                    SoftClayTag(label: 'revisar', color: AsterConstants.ambar),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card: Progresso nas Disciplinas
          SoftClayCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progresso · Security+',
                  style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                ),
                const SizedBox(height: 16),

                _buildProgressItem('Criptografia', 0.82, AsterConstants.lavanda),
                const SizedBox(height: 12),
                _buildProgressItem('Cloud', 0.64, AsterConstants.menta),
                const SizedBox(height: 12),
                _buildProgressItem('AppSec', 0.71, AsterConstants.ambar),
                const SizedBox(height: 12),
                _buildProgressItem('Redes', 0.45, AsterConstants.coral),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card: Consistência últimas 30 semanas
          SoftClayCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consistência · últimas 30 semanas',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AsterConstants.textDark),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 30,
                    itemBuilder: (context, col) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(4, (row) {
                            final active = (col * 4 + row) % 3 == 0;
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active ? AsterConstants.menta : AsterConstants.surfaceInset,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, double fraction, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: AsterConstants.textDark)),
            Text('${(fraction * 100).toInt()}%', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: AsterConstants.surfaceInset,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ─── Widget: Cartão do Chat Noesis AI ───
  Widget _buildChatCard() {
    return SoftClayCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header do Chat
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AsterConstants.lavanda,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Noesis AI',
                      style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
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
                  icon: const Icon(Icons.add_rounded, size: 20, color: AsterConstants.textDark),
                  tooltip: 'Nova conversa',
                  onPressed: () {
                    setState(() {
                      _messages.clear();
                      _conversationHistory.clear();
                      _loadInitialMockChat();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AsterConstants.textMuted),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Divider(),

          // Mensagens do Chat
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                final role = msg['role'];

                // Renderizar Cartões de Ação Executada (Tool Calling)
                if (role == 'tool') {
                  final isCompleted = msg['status'] == 'completed';
                  final color = isCompleted ? AsterConstants.menta : AsterConstants.ambar;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCompleted ? 'AÇÃO EXECUTADA' : 'EXECUTANDO...',
                              style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: color),
                            ),
                            Text(
                              msg['text'],
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AsterConstants.textDark, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                final isUser = role == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.42),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? AsterConstants.lavanda : AsterConstants.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isUser ? AsterConstants.primaryButtonShadow : AsterConstants.claySubtleShadow,
                    ),
                    child: Text(
                      msg['text'],
                      style: GoogleFonts.manrope(
                        color: isUser ? Colors.white : AsterConstants.textDark,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
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

          // Sugestões Rápidas de Ação
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildQuickChip('✨ Criar simulado sobre OWASP', () => _sendMessage('Crie um simulado de 5 questões sobre OWASP Top 10')),
                const SizedBox(width: 8),
                _buildQuickChip('✨ Agendar revisão sexta às 14h', () => _sendMessage('Agende uma revisão de Criptografia para sexta-feira às 14:00')),
              ],
            ),
          ),

          // Campo de Entrada Soft Clay
          Padding(
            padding: const EdgeInsets.all(14),
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
                    icon: const Icon(Icons.mic_none_rounded, size: 20, color: AsterConstants.textMuted),
                    onPressed: () {},
                  ),
                  Container(
                    width: 34,
                    height: 34,
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
