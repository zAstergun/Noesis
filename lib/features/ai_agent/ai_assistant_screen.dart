import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../../core/noesis_agent_tools.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';
import '../../main.dart';
import '../../widgets/noesis_logo.dart';
import '../../widgets/vip_privileges.dart';
import 'data/ai_chat_history_repository.dart';
import '../quizzes/quiz_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../flashcards/models/flashcard_model.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  /// Hook opcional para simular seleção de arquivos em testes de widget.
  @visibleForTesting
  static Future<List<NoesisAttachment>> Function()? filePickerOverrideForTesting;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Content> _conversationHistory = [];
  final List<NoesisAttachment> _attachments = [];
  List<NoesisQuickSuggestion> _quickSuggestions = const [
    NoesisQuickSuggestion(
      id: 'loading_plan',
      label: '✨ Plano de estudo de hoje',
      prompt: 'Leia tudo o que tenho na minha conta e monte um plano objetivo para hoje.',
    ),
    NoesisQuickSuggestion(
      id: 'loading_quiz',
      label: '📝 Simulado de diagnóstico',
      prompt: 'Crie um simulado de 5 questões sobre os temas que venho estudando.',
    ),
  ];
  bool _isLoading = false;
  bool _hasDismissedCapabilities = false;
  bool _isAttachMenuOpen = false;
  final GlobalKey _attachAnchorKey = GlobalKey();
  String? _activeSessionId;
  DateTime? _activeSessionCreatedAt;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageInputChanged);
    _loadContextualSuggestions();
  }

  Future<void> _loadContextualSuggestions() async {
    try {
      final loaded = await NoesisAgentTools.buildContextualQuickSuggestions();
      if (mounted && loaded.isNotEmpty) {
        setState(() => _quickSuggestions = loaded);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageInputChanged);
    _messageController.dispose();
    super.dispose();
  }

  bool get _hasConfiguredAiKey =>
      (GeminiService.apiKey?.trim().isNotEmpty ?? false) ||
      GeminiService.provider == 'custom';

  void _onMessageInputChanged() {
    if (!_hasDismissedCapabilities && _messageController.text.isNotEmpty) {
      setState(() => _hasDismissedCapabilities = true);
    }
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _conversationHistory.clear();
      _attachments.clear();
      _messageController.clear();
      _hasDismissedCapabilities = false;
      _activeSessionId = null;
      _activeSessionCreatedAt = null;
    });
  }

  Future<void> _persistCurrentSessionIfVip() async {
    if (!SupabaseService.isCurrentUserVip || _messages.isEmpty) return;
    final now = DateTime.now();
    _activeSessionId ??= 'chat-${now.microsecondsSinceEpoch}';
    _activeSessionCreatedAt ??= now;

    String title = 'Conversa Noesis AI';
    for (final m in _messages) {
      if (m['role'] == 'user') {
        final raw = (m['text'] ?? '').toString().trim();
        if (raw.isNotEmpty) {
          title = raw.length > 52 ? '${raw.substring(0, 49)}...' : raw;
          break;
        }
      }
    }

    await AiChatHistoryRepository.upsertSession(
      AiChatSession(
        id: _activeSessionId!,
        title: title,
        createdAt: _activeSessionCreatedAt!,
        updatedAt: now,
        messages: List<Map<String, dynamic>>.from(_messages),
      ),
    );
  }

  void _restoreSession(AiChatSession session) {
    setState(() {
      _activeSessionId = session.id;
      _activeSessionCreatedAt = session.createdAt;
      _messages
        ..clear()
        ..addAll(session.messages.map((m) => Map<String, dynamic>.from(m)));
      _conversationHistory.clear();
      for (final m in _messages) {
        final role = m['role']?.toString();
        final txt = (m['text'] ?? '').toString();
        if (txt.isEmpty) continue;
        if (role == 'user') {
          _conversationHistory.add(Content.text(txt));
        } else if (role == 'ai') {
          _conversationHistory.add(Content.model([TextPart(txt)]));
        }
      }
      _hasDismissedCapabilities = true;
    });
  }

  Future<void> _openHistoryDialog() async {
    if (!SupabaseService.isCurrentUserVip) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 3),
            content: const Text(
              'O histórico de conversas do Noesis AI é exclusivo para membros VIP.',
            ),
            action: SnackBarAction(
              label: 'Ver VIP',
              onPressed: () {
                if (mounted) showVipPrivilegesModal(context);
              },
            ),
          ),
        );
      await showVipPrivilegesModal(context);
      return;
    }

    var sessions = await AiChatHistoryRepository.loadAll();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final primaryCol = AsterTheme.primary(ctx);
            return Dialog(
              key: const Key('ai_history_dialog'),
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
                child: Container(
                  decoration: BoxDecoration(
                    color: AsterTheme.card(ctx),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                    border: Border.all(color: AsterTheme.surfaceInset(ctx)),
                    boxShadow: Theme.of(ctx).brightness == Brightness.dark
                        ? AsterConstants.clayDarkShadow
                        : AsterConstants.clayShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                        decoration: BoxDecoration(
                          color: AsterTheme.surfaceAlt(ctx),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AsterConstants.radiusLarge),
                          ),
                          border: Border(bottom: BorderSide(color: AsterTheme.surfaceInset(ctx))),
                        ),
                        child: Row(
                          children: [
                            const VipCrownIcon(size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Histórico do Noesis AI',
                                        style: GoogleFonts.manrope(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AsterTheme.text(ctx),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                                    ],
                                  ),
                                  Text(
                                    'Retome conversas anteriores a qualquer momento',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11.5,
                                      color: AsterTheme.textMuted(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (sessions.isNotEmpty)
                              TextButton(
                                key: const Key('ai_history_clear_all_button'),
                                onPressed: () async {
                                  await AiChatHistoryRepository.clearAll();
                                  sessions = const [];
                                  setDialogState(() {});
                                },
                                child: Text(
                                  'Limpar tudo',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AsterConstants.coral,
                                  ),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Fechar',
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: Icon(Icons.close_rounded, color: AsterTheme.textMuted(ctx)),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: sessions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 36,
                                      color: AsterTheme.textMuted(ctx).withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Nenhuma conversa salva ainda',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AsterTheme.text(ctx),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Suas próximas conversas com o Noesis AI serão salvas automaticamente aqui.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: AsterTheme.textMuted(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.all(14),
                                itemCount: sessions.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final item = sessions[index];
                                  final isCurrent = item.id == _activeSessionId;
                                  return InkWell(
                                    key: Key('ai_history_item_${item.id}'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _restoreSession(item);
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? primaryCol.withValues(alpha: 0.12)
                                            : AsterTheme.surfaceAlt(ctx),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isCurrent
                                              ? primaryCol
                                              : AsterTheme.surfaceInset(ctx),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 18,
                                            color: isCurrent ? primaryCol : AsterTheme.textMuted(ctx),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: AsterTheme.text(ctx),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.previewText,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 11.5,
                                                    color: AsterTheme.textMuted(ctx),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Excluir conversa',
                                            onPressed: () async {
                                              await AiChatHistoryRepository.deleteSession(item.id);
                                              sessions = await AiChatHistoryRepository.loadAll();
                                              setDialogState(() {});
                                            },
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 17,
                                              color: AsterTheme.textMuted(ctx),
                                            ),
                                          ),
                                        ],
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
      },
    );
  }

  String? _buildAttachmentContext(List<NoesisAttachment> items) {
    if (items.isEmpty) return null;
    final buf = StringBuffer();
    for (final item in items) {
      buf
        ..writeln('=== ANEXO (${item.iconLabel}): ${item.title} ===')
        ..writeln('Resumo: ${item.subtitle}')
        ..writeln(item.content)
        ..writeln();
    }
    return buf.toString().trim();
  }

  Future<void> _pickLocalFiles() async {
    if (AiAssistantScreen.filePickerOverrideForTesting != null) {
      final picked = await AiAssistantScreen.filePickerOverrideForTesting!();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        for (final item in picked) {
          if (!_attachments.any((a) => a.id == item.id)) {
            _attachments.add(item);
          }
        }
      });
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Selecionar arquivos para o Noesis AI',
      );
      if (files.isEmpty || !mounted) return;

      final added = <NoesisAttachment>[];
      for (final file in files) {
        List<int>? bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {
          bytes = null;
        }
        final fileSize = bytes?.length ?? 0;

        final ext = (file.extension ?? '').toLowerCase();
        String contentText;
        final isTextLike = const {
          'txt',
          'md',
          'csv',
          'json',
          'yaml',
          'yml',
          'xml',
          'html',
          'log',
          'dart',
          'py',
          'js',
          'ts',
          'sql',
        }.contains(ext);

        if (bytes != null && isTextLike) {
          String decoded;
          try {
            decoded = utf8.decode(bytes, allowMalformed: true);
          } catch (_) {
            decoded = latin1.decode(bytes, allowInvalid: true);
          }
          contentText = decoded.length > 12000 ? '${decoded.substring(0, 12000)}\n...(truncado)' : decoded;
        } else if (bytes != null && ext == 'pdf') {
          final asciiMatches = RegExp(r'[A-Za-zÀ-ÿ0-9 ,.;:!?()/_\-\n]{5,}').allMatches(
            latin1.decode(bytes, allowInvalid: true),
          );
          final extracted = asciiMatches.map((m) => m.group(0)!).take(120).join(' ');
          contentText = extracted.trim().length > 40
              ? (extracted.length > 8000 ? extracted.substring(0, 8000) : extracted)
              : 'Arquivo PDF anexado: ${file.name} (${(fileSize / 1024).toStringAsFixed(1)} KB).';
        } else {
          contentText = 'Arquivo anexado: ${file.name} (tipo .${ext.isEmpty ? "bin" : ext}, '
              '${(fileSize / 1024).toStringAsFixed(1)} KB).';
        }

        added.add(
          NoesisAttachment(
            id: 'file:${file.name}:$fileSize:${DateTime.now().millisecondsSinceEpoch}',
            kind: 'file',
            title: file.name,
            subtitle: '${(fileSize / 1024).toStringAsFixed(1)} KB · .${ext.isEmpty ? "arquivo" : ext}',
            content: contentText,
          ),
        );
      }

      if (mounted && added.isNotEmpty) {
        setState(() => _attachments.addAll(added));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 4),
              content: Text('Não foi possível anexar arquivo: $e'),
            ),
          );
      }
    }
  }

  Future<void> _openNoesisItemPicker() async {
    final items = await NoesisAgentTools.listAttachableItems();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String filterKind = 'all';
        String query = '';
        final selectedIds = _attachments.map((a) => a.id).toSet();

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = items.where((item) {
              if (filterKind != 'all' && item.kind != filterKind) return false;
              if (query.isNotEmpty) {
                final hay = '${item.title} ${item.subtitle} ${item.iconLabel}'.toLowerCase();
                if (!hay.contains(query.toLowerCase())) return false;
              }
              return true;
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              title: Text(
                'Anexar Item do Noesis',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              content: SizedBox(
                width: 480,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrar simulados, cadernos, flashcards ou trilhas...',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                      ),
                      onChanged: (val) => setModalState(() => query = val.trim()),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            for (final entry in const [
                              ('all', 'Todos', Icons.apps_rounded),
                              ('quiz', 'Simulados', Icons.assignment_rounded),
                              ('notebook', 'Cadernos', Icons.menu_book_rounded),
                              ('flashcard_deck', 'Flashcards', Icons.style_rounded),
                              ('roadmap', 'Trilhas', Icons.route_rounded),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: SoftClayChoiceChip(
                                  label: entry.$2,
                                  icon: entry.$3,
                                  selected: filterKind == entry.$1,
                                  compact: true,
                                  onTap: () => setModalState(() => filterKind = entry.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum item encontrado na sua conta.',
                                style: GoogleFonts.manrope(color: AsterConstants.textMuted, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final item = filtered[idx];
                                final checked = selectedIds.contains(item.id);
                                return CheckboxListTile(
                                  value: checked,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: AsterTheme.primary(context),
                                  title: Text(
                                    item.title,
                                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                  subtitle: Text(
                                    '${item.iconLabel} · ${item.subtitle}',
                                    style: GoogleFonts.manrope(fontSize: 11.5, color: AsterConstants.textMuted),
                                  ),
                                  onChanged: (v) {
                                    setModalState(() {
                                      if (v == true) {
                                        selectedIds.add(item.id);
                                      } else {
                                        selectedIds.remove(item.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterConstants.textMuted)),
                ),
                SoftClayPillButton(
                  text: 'Anexar Selecionados',
                  onPressed: () {
                    setState(() {
                      // Mantém arquivos locais já anexados e sincroniza os itens selecionados do Noesis
                      _attachments.removeWhere((a) => a.kind != 'file' && !selectedIds.contains(a.id));
                      for (final item in items) {
                        if (selectedIds.contains(item.id) &&
                            !_attachments.any((existing) => existing.id == item.id)) {
                          _attachments.add(item);
                        }
                      }
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAttachMenu() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final box = _attachAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.of(context).size;
    final Rect buttonRect = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size)
        : Rect.fromLTWH(24, overlaySize.height - 76, 40, 40);

    final double popoverWidth = (overlaySize.width - 24).clamp(240.0, 348.0);

    setState(() => _isAttachMenuOpen = true);
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Fechar menu de anexos',
      barrierColor: Colors.black.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 210),
      pageBuilder: (ctx, _, _) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard;
        final borderCol = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AsterTheme.primary(ctx).withValues(alpha: 0.14);

        return CustomSingleChildLayout(
          delegate: _AttachPopoverLayoutDelegate(
            anchorRect: buttonRect,
            maxWidth: popoverWidth,
          ),
          child: Material(
            key: const Key('ai_attach_popover_menu'),
            color: Colors.transparent,
            child: Container(
              width: popoverWidth,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Text(
                      'ANEXAR AO CONTEXTO',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                  ),
                  _buildAttachMenuOption(
                    ctx,
                    key: const Key('attach_file_option'),
                    icon: Icons.upload_file_rounded,
                    accent: AsterTheme.primary(ctx),
                    title: 'Anexar Arquivo do Dispositivo',
                    subtitle: 'TXT, Markdown, CSV, JSON, PDF ou documentos de estudo',
                    isDark: isDark,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickLocalFiles();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildAttachMenuOption(
                    ctx,
                    key: const Key('attach_noesis_item_option'),
                    icon: Icons.library_books_rounded,
                    accent: AsterConstants.menta,
                    title: 'Anexar Item do Noesis',
                    subtitle: 'Simulados, Cadernos, Baralhos de Flashcards ou Trilhas',
                    isDark: isDark,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openNoesisItemPicker();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final isClosing = animation.status == AnimationStatus.reverse;
        final curved = CurvedAnimation(
          parent: animation,
          curve: isClosing ? Curves.easeInCubic : Curves.easeOutBack,
        );
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(fade),
            child: ScaleTransition(
              alignment: Alignment.bottomLeft,
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
    if (mounted) {
      setState(() => _isAttachMenuOpen = false);
    }
  }

  Widget _buildAttachMenuOption(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? quickText]) async {
    if (!_hasConfiguredAiKey) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 4),
            content: const Text(
              'Você precisa configurar uma chave de IA em Configurações para usar o Noesis AI.',
            ),
            action: SnackBarAction(
              label: 'Configurações',
              onPressed: () {
                messenger.hideCurrentSnackBar();
                RootScreen.switchTab(6);
              },
            ),
          ),
        );
      return;
    }

    final rawText = quickText ?? _messageController.text.trim();
    final pendingAttachments = List<NoesisAttachment>.from(_attachments);
    if (rawText.isEmpty && pendingAttachments.isEmpty) return;

    final text = rawText.isNotEmpty
        ? rawText
        : 'Analise e revise os itens anexados (${pendingAttachments.map((a) => a.title).join(', ')}).';
    final attachmentContext = _buildAttachmentContext(pendingAttachments);

    _messageController.clear();
    setState(() {
      _attachments.clear();
      _messages.add({
        'role': 'user',
        'text': text,
        'time': 'Agora',
        if (pendingAttachments.isNotEmpty) 'attachments': pendingAttachments,
      });
      _isLoading = true;
    });

    try {
      final reply = await GeminiService.executeAgentChat(
        userMessage: text,
        history: _conversationHistory,
        attachmentContext: attachmentContext,
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
        unawaited(_persistCurrentSessionIfVip());
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
        _loadContextualSuggestions();
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

    return Column(
      children: [
        // Header do Chat (alinhado ao lado do ícone de menu recolhido)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              const NoesisCollapsedMenuSpacer(width: 82),
              const NoesisLogo(
                key: Key('ai_header_logo'),
                size: 36,
                withShadow: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Noesis AI',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _hasConfiguredAiKey ? AsterConstants.menta : AsterConstants.ambar,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _hasConfiguredAiKey
                                ? 'Tutor inteligente · conectado aos seus estudos'
                                : 'Configure sua IA em Configurações',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SupabaseService.isVipNotifier,
                builder: (context, _, _) {
                  final isVip = SupabaseService.isCurrentUserVip;
                  return Tooltip(
                    message: isVip
                        ? 'Histórico de conversas (VIP)'
                        : 'Histórico de conversas · Exclusivo VIP',
                    child: InkWell(
                      key: const Key('ai_history_button'),
                      onTap: _openHistoryDialog,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isVip
                              ? AsterTheme.primary(context).withValues(alpha: 0.12)
                              : AsterTheme.surfaceAlt(context),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          border: Border.all(
                            color: isVip
                                ? AsterTheme.primary(context).withValues(alpha: 0.35)
                                : AsterVipColors.gold.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: isVip ? AsterTheme.primary(context) : AsterTheme.text(context),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Histórico',
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isVip ? AsterTheme.primary(context) : AsterTheme.text(context),
                              ),
                            ),
                            if (!isVip) ...[
                              const SizedBox(width: 5),
                              const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('ai_clear_chat_button'),
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                tooltip: 'Limpar conversa',
                onPressed: _resetChat,
              ),
            ],
          ),
        ),

        Expanded(
          child: SoftClayCard(
            height: double.infinity,
            width: double.infinity,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (!_hasConfiguredAiKey) _buildMissingKeyNotice(isDark),

          // Mensagens do Chat ou Boas-Vindas de Capacidades
          Expanded(
            child: _messages.isEmpty
                ? (!_hasDismissedCapabilities
                    ? _buildCapabilitiesOverview(isDark, isDesktop)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AsterTheme.primary(context).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.auto_awesome_rounded, size: 26, color: AsterTheme.primary(context)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Pronto para executar seu pedido',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pressione Enter ou toque em Enviar para começar.',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final msg = _messages[idx];
                      final role = msg['role'];
                      final isDark = Theme.of(context).brightness == Brightness.dark;

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
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
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
                                        color: AsterTheme.primary(context),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        boxShadow: AsterTheme.primaryShadow(context),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, size: 16, color: AsterTheme.onPrimary(context)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Iniciar Simulado Agora 🚀',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: AsterTheme.onPrimary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                 ] else if (actionName == 'create_flashcards' || actionName == 'update_flashcard_deck') ...[
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
                                         color: AsterTheme.primary(context),
                                         borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                         boxShadow: AsterTheme.primaryShadow(context),
                                       ),
                                       child: Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           Icon(Icons.style_rounded, size: 16, color: AsterTheme.onPrimary(context)),
                                           const SizedBox(width: 6),
                                           Text(
                                             'Praticar Flashcards Agora 🎴',
                                             style: GoogleFonts.manrope(
                                               fontSize: 11.5,
                                               fontWeight: FontWeight.w800,
                                               color: AsterTheme.onPrimary(context),
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ),
                                 ] else if (actionName == 'schedule_calendar_event' || actionName == 'update_calendar_event') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(5),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterTheme.card(context),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.calendar_month_rounded, size: 14, color: AsterTheme.primary(context)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ver no Calendário 📅',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AsterTheme.primary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (actionName == 'log_study_session' || actionName == 'update_study_session') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(7),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterTheme.card(context),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterConstants.menta.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_stories_rounded, size: 14, color: AsterConstants.menta),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ver no Diário de Estudos 📊',
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
                                ] else if (actionName == 'create_notebook_or_note' || actionName == 'update_notebook_or_note') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(3),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterTheme.card(context),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.menu_book_rounded, size: 14, color: AsterTheme.primary(context)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Abrir Cadernos 📓',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AsterTheme.primary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (actionName == 'create_roadmap' || actionName == 'update_roadmap') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(8),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterTheme.card(context),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterConstants.menta.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.route_rounded, size: 14, color: AsterConstants.menta),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Abrir Trilhas 🗺️',
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
                                ] else if (actionName == 'set_weekly_goal') ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => RootScreen.switchTab(0),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AsterTheme.card(context),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.dashboard_rounded, size: 14, color: AsterTheme.primary(context)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Ver Meta no Dashboard 🎯',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AsterTheme.primary(context),
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
                                        color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(Icons.auto_awesome_rounded, size: 13, color: AsterTheme.primary(context)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Noesis AI',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AsterTheme.primary(context),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AsterTheme.primary(context).withValues(alpha: 0.08),
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
                                        ScaffoldMessenger.of(context)
                                          ..clearSnackBars()
                                          ..showSnackBar(
                                            const SnackBar(
                                              persist: false,
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
                                        color: AsterTheme.primary(context),
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF191A26) : const Color(0xFFF1F1F8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AsterConstants.surfaceInset.withValues(alpha: 0.6)),
                                      ),
                                      listBullet: GoogleFonts.manrope(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AsterTheme.primary(context),
                                      ),
                                      blockquote: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: AsterConstants.textMuted,
                                      ),
                                      blockquoteDecoration: BoxDecoration(
                                        border: Border(left: BorderSide(color: AsterTheme.primary(context), width: 3)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final userAttachments = msg['attachments'] as List<NoesisAttachment>?;
                      final primaryCol = AsterTheme.primary(context);
                      final onPrimaryCol = AsterTheme.onPrimary(context);
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 680 : MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryCol,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(6),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: AsterTheme.primaryShadow(context, primaryCol),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (userAttachments != null && userAttachments.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: userAttachments
                                      .map(
                                        (att) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: onPrimaryCol.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.attach_file_rounded, size: 13, color: onPrimaryCol),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${att.iconLabel}: ${att.title}',
                                                style: GoogleFonts.manrope(
                                                  color: onPrimaryCol,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                msg['text'],
                                style: GoogleFonts.manrope(
                                  color: onPrimaryCol,
                                  fontSize: 13.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AsterTheme.primary(context))),
                  const SizedBox(width: 8),
                  Text('Noesis AI processando ação...', style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted)),
                ],
              ),
            ),

          // Sugestões Rápidas Contextuais (baseadas na atividade real no Noesis)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _quickSuggestions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _buildQuickChip(
                      _quickSuggestions[i].label,
                      () => _sendMessage(_quickSuggestions[i].prompt),
                      tooltip: _quickSuggestions[i].tooltip,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Chips dos Itens Anexados (Arquivos & Itens do Noesis)
          if (_attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _attachments.map((att) {
                    return Chip(
                      backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.12),
                      side: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.35)),
                      avatar: Icon(
                        att.kind == 'file' ? Icons.insert_drive_file_rounded : Icons.library_books_rounded,
                        size: 15,
                        color: AsterTheme.primary(context),
                      ),
                      label: Text(
                        '${att.iconLabel}: ${att.title}',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 15),
                      onDeleted: () => setState(() => _attachments.removeWhere((a) => a.id == att.id)),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Campo de Entrada Soft Clay
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    key: _attachAnchorKey,
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: _isAttachMenuOpen
                          ? AsterTheme.primary(context).withValues(alpha: 0.14)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      key: const Key('ai_attach_button'),
                      tooltip: 'Anexar arquivo ou item do Noesis',
                      onPressed: _openAttachMenu,
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _isAttachMenuOpen ? 0.125 : 0.0,
                        child: Icon(
                          Icons.attach_file_rounded,
                          color: AsterTheme.primary(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Pergunte ou peça uma ação (simulado, agenda, caderno, anexe itens)...',
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
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context),
                      shape: BoxShape.circle,
                      boxShadow: AsterTheme.primaryShadow(context),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.send_rounded, size: 16, color: AsterTheme.onPrimary(context)),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
        ),
      ],
    );
  }

  Widget _buildMissingKeyNotice(bool isDark) {
    final primaryCol = AsterTheme.primary(context);
    return Container(
      key: const Key('ai_missing_key_notice'),
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AsterConstants.ambar.withValues(alpha: isDark ? 0.14 : 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AsterConstants.ambar.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AsterConstants.ambar.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 19,
              color: AsterConstants.ambar,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure uma chave de IA para usar o assistente',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Adicione sua chave de API em Configurações para habilitar o envio de mensagens e ações automáticas.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => RootScreen.switchTab(6),
            icon: const Icon(Icons.settings_rounded, size: 15),
            label: const Text('Configurar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryCol,
              foregroundColor: AsterTheme.onPrimary(context),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              textStyle: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesOverview(bool isDark, bool isDesktop) {
    final primaryCol = AsterTheme.primary(context);
    final secondaryCol = AsterTheme.secondary(context);
    final capabilities = [
      (
        icon: Icons.calendar_month_rounded,
        color: primaryCol,
        title: 'Calendário & Agenda',
        description: 'Agende aulas, provas e revisões por horário natural, edite compromissos ou remova eventos.',
        samplePrompt: 'Crie um aviso no calendário de uma prova para as 11 da manhã de hoje',
      ),
      (
        icon: Icons.timer_rounded,
        color: secondaryCol,
        title: 'Diário & Meta Semanal',
        description: 'Registre sessões de estudo, ajuste sua meta semanal de horas e edite ou apague registros.',
        samplePrompt: 'Registre 1h30 de estudo de Criptografia sobre AES-GCM',
      ),
      (
        icon: Icons.assignment_rounded,
        color: primaryCol,
        title: 'Simulados Personalizados',
        description: 'Crie simulados sob medida, revise seus acertos e erros ou remova simulados antigos.',
        samplePrompt: 'Crie um simulado de 5 questões sobre OWASP Top 10',
      ),
      (
        icon: Icons.style_rounded,
        color: secondaryCol,
        title: 'Flashcards Cognitivos',
        description: 'Gere baralhos de repetição espaçada, adicione cartões novos e foque no que falta dominar.',
        samplePrompt: 'Crie flashcards de Criptografia com foco em TLS 1.3',
      ),
      (
        icon: Icons.menu_book_rounded,
        color: primaryCol,
        title: 'Cadernos & Trilhas',
        description: 'Crie e atualize anotações de estudo, marque revisões e monte trilhas semanais completas.',
        samplePrompt: 'Crie uma trilha de 4 semanas para dominar Redes e Segurança',
      ),
      (
        icon: Icons.attach_file_rounded,
        color: secondaryCol,
        title: 'Leitura da Conta & Anexos',
        description: 'Leia todos os dados da sua conta e anexe arquivos ou itens do Noesis usando o ícone de clipe.',
        samplePrompt: 'Leia minha conta e faça um plano de revisão do que está pendente',
      ),
    ];

    return SingleChildScrollView(
      key: const Key('ai_capabilities_overview'),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 18, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const NoesisLogo(
                key: Key('ai_hero_logo'),
                size: 56,
                withShadow: true,
              ),
              const SizedBox(height: 14),
              Text(
                'O que o Noesis AI pode fazer por você',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Conectado a todas as páginas da sua conta. Toque em um exemplo ou comece a digitar abaixo:',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 600
                      ? (constraints.maxWidth - 14) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: capabilities.map((cap) {
                      return SizedBox(
                        width: cardWidth,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            _messageController.text = cap.samplePrompt;
                            _messageController.selection = TextSelection.fromPosition(
                              TextPosition(offset: cap.samplePrompt.length),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AsterConstants.surfaceAltDark.withValues(alpha: 0.75)
                                  : AsterConstants.surfaceAlt.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: cap.color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: cap.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(cap.icon, size: 19, color: cap.color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cap.title,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cap.description,
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, {String? tooltip}) {
    final primaryCol = AsterTheme.primary(context);
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primaryCol.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: primaryCol),
        ),
      ),
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }
}

class _AttachPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchorRect;
  final double maxWidth;

  const _AttachPopoverLayoutDelegate({
    required this.anchorRect,
    required this.maxWidth,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: maxWidth.clamp(120.0, constraints.maxWidth - 24.0),
      maxHeight: (constraints.maxHeight - 24.0).clamp(120.0, double.infinity),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = (size.width - childSize.width - 12.0).clamp(12.0, double.infinity);
    final x = anchorRect.left.clamp(12.0, maxX);
    final aboveY = anchorRect.top - childSize.height - 8.0;
    final belowY = anchorRect.bottom + 8.0;
    final y = aboveY >= 12.0
        ? aboveY
        : belowY.clamp(12.0, (size.height - childSize.height - 12.0).clamp(12.0, double.infinity));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _AttachPopoverLayoutDelegate oldDelegate) =>
      oldDelegate.anchorRect != anchorRect || oldDelegate.maxWidth != maxWidth;
}
