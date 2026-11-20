import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
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
    _messages.add({
      'role': 'ai',
      'text': 'Olá! Eu sou o assistente Noesis AI. Posso registrar seus estudos, agendar revisões no calendário ou resumir seu progresso. Como posso te ajudar hoje?',
    });
  }

  void _openApiKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AsterConstants.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Configurar Google Gemini API Key', style: TextStyle(color: AsterConstants.textLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insira sua chave de API do Google AI Studio para ativar as respostas inteligentes e ações autônomas.',
              style: TextStyle(color: AsterConstants.textMuted, fontSize: 13),
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
            child: const Text('Cancelar', style: TextStyle(color: AsterConstants.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final key = _apiKeyController.text.trim();
              if (key.isNotEmpty) {
                GeminiService.initialize(key);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chave de API configurada!')),
                );
              }
            },
            child: const Text('Salvar Chave'),
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
      _messages.add({'role': 'user', 'text': text});
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AsterConstants.secondary, size: 20),
            SizedBox(width: 8),
            Text('Noesis AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.key,
              color: GeminiService.apiKey != null ? AsterConstants.secondary : AsterConstants.accentRose,
            ),
            tooltip: 'Configurar Gemini API Key',
            onPressed: _openApiKeyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sugestões Rápidas de Ação
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.timer_outlined, size: 16, color: AsterConstants.secondary),
                  label: const Text('Registrar 1h de estudo', style: TextStyle(fontSize: 12)),
                  backgroundColor: AsterConstants.surfaceDark,
                  side: const BorderSide(color: AsterConstants.borderDark),
                  onPressed: () => _sendMessage('Registrei 1 hora de estudo em Algoritmos com o tema Grafos hoje.'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.event_outlined, size: 16, color: AsterConstants.primary),
                  label: const Text('Agendar Prova no Calendário', style: TextStyle(fontSize: 12)),
                  backgroundColor: AsterConstants.surfaceDark,
                  side: const BorderSide(color: AsterConstants.borderDark),
                  onPressed: () => _sendMessage('Agende uma prova de certificação para a próxima segunda-feira às 14:00.'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.analytics_outlined, size: 16, color: AsterConstants.accentAmber),
                  label: const Text('Ver Meus Estudos', style: TextStyle(fontSize: 12)),
                  backgroundColor: AsterConstants.surfaceDark,
                  side: const BorderSide(color: AsterConstants.borderDark),
                  onPressed: () => _sendMessage('Consulte meus estudos recentes e me diga o resumo.'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AsterConstants.borderDark),

          // Lista de Mensagens
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                final isUser = msg['role'] == 'user';
                final isError = msg['isError'] == true;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AsterConstants.primary
                          : (isError ? AsterConstants.accentRose.withValues(alpha: 0.2) : AsterConstants.surfaceDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser ? AsterConstants.primary : AsterConstants.borderDark,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 14, color: isError ? AsterConstants.accentRose : AsterConstants.secondary),
                              const SizedBox(width: 4),
                              Text(
                                'Noesis AI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isError ? AsterConstants.accentRose : AsterConstants.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          msg['text'],
                          style: TextStyle(
                            color: isError ? AsterConstants.accentRose : AsterConstants.textLight,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AsterConstants.secondary),
                  ),
                  SizedBox(width: 10),
                  Text('Processando dados & executando ações...', style: TextStyle(color: AsterConstants.textDim, fontSize: 12)),
                ],
              ),
            ),

          // Campo de Entrada de Mensagem
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AsterConstants.surfaceDark,
              border: Border(top: BorderSide(color: AsterConstants.borderDark)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Pergunte, registre estudos ou agende compromissos...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : () => _sendMessage(),
                  icon: const Icon(Icons.send_rounded, color: AsterConstants.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
