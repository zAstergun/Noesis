import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants.dart';
import '../../core/gemini_service.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../widgets/vip_rgb_theme_editor.dart';
import '../study_groups/data/study_groups_service.dart';
import '../study_groups/models/study_group_feature_scope.dart';
import 'models/notebook_model.dart';

enum _NotebookReviewFilter { all, toReview, upToDate }

class NotebooksScreen extends StatefulWidget {
  const NotebooksScreen({super.key, this.groupScope});

  final StudyGroupFeatureScope? groupScope;

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  List<StudyNotebook> _notebooks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedSubjectFilter = 'Todos';
  _NotebookReviewFilter _notebookReviewFilter = _NotebookReviewFilter.all;

  // Caderno atualmente aberto (null = lista geral de cadernos)
  StudyNotebook? _selectedNotebook;
  // Anotação atualmente selecionada para leitura no caderno
  StudyNote? _selectedNote;

  final TextEditingController _searchCtrl = TextEditingController();

  // Estados de busca e filtros internos do caderno aberto
  String _notesSearchQuery = '';
  final TextEditingController _notesSearchCtrl = TextEditingController();
  final ScrollController _tagsScrollCtrl = ScrollController();
  String _selectedTagFilter = 'Todas';
  DateTime? _selectedDateFilter;
  String _noteSortOrder = 'recent'; // 'recent' | 'oldest'
  bool _onlyNotesToReview = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupScope != null) {
      StudyGroupsService.instance.groupsNotifier.addListener(_onGroupListChanged);
    }
    _loadNotebooks();
  }

  void _onGroupListChanged() {
    if (mounted) _loadNotebooks();
  }

  @override
  void dispose() {
    if (widget.groupScope != null) {
      StudyGroupsService.instance.groupsNotifier.removeListener(_onGroupListChanged);
    }
    _searchCtrl.dispose();
    _notesSearchCtrl.dispose();
    _tagsScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotebooks() async {
    final scope = widget.groupScope;
    if (scope == null) {
      setState(() => _isLoading = true);
    }
    final data = scope != null
        ? StudyGroupsService.instance.groupNotebooks(scope.groupId)
        : await SupabaseService.getNotebooks();
    if (!mounted) return;
    setState(() {
      _notebooks = data;
      _isLoading = false;
      // Atualiza o caderno selecionado caso já estivesse aberto
      if (_selectedNotebook != null) {
        final found = _notebooks.firstWhere(
          (nb) => nb.id == _selectedNotebook!.id,
          orElse: () => _selectedNotebook!,
        );
        _selectedNotebook = found;
        if (_selectedNote != null) {
          final noteFound = found.notes.firstWhere(
            (n) => n.id == _selectedNote!.id,
            orElse: () => found.notes.isNotEmpty ? found.notes.first : _selectedNote!,
          );
          _selectedNote = noteFound;
        }
      }
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim().toUpperCase();
      if (clean == '7C6CF0') return AsterTheme.primary(context);
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AsterTheme.primary(context);
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível abrir o link: $url')),
          );
        }
      }
    }
  }

  // ----------------------------------------------------
  // MODAL: CRIAR OU EDITAR CADERNO
  // ----------------------------------------------------
  void _openNotebookModal({StudyNotebook? notebook}) {
    final isEditing = notebook != null;
    final titleCtrl = TextEditingController(text: notebook?.title ?? '');
    final subjectCtrl = TextEditingController(text: notebook?.subject ?? 'Tecnologia');
    final descCtrl = TextEditingController(text: notebook?.description ?? '');
    String selectedColor = notebook?.colorHex ?? '7C6CF0';
    bool isSaving = false;

    final List<Map<String, String>> palette = [
      {'name': 'Lavanda', 'hex': '7C6CF0'},
      {'name': 'Menta', 'hex': '5DC6A1'},
      {'name': 'Pêssego', 'hex': 'F7A072'},
      {'name': 'Céu', 'hex': '4EA8DE'},
      {'name': 'Rosa', 'hex': 'E07A5F'},
      {'name': 'Violeta', 'hex': '9B5DE5'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _parseColor(selectedColor).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.menu_book_rounded, color: _parseColor(selectedColor), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Editar Caderno ✏️' : 'Novo Caderno de Estudo 📚',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  isEditing ? 'Atualize as informações do seu caderno' : 'Crie um espaço temático para anotações, links e imagens',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Título
                      Text(
                        'TÍTULO DO CADERNO *',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Criptografia & Redes, Direito Constitucional...',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Matéria
                      Text(
                        'DISCIPLINA / MATÉRIA',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: subjectCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Tecnologia, Direito, Idiomas, Matemática...',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Descrição
                      Text(
                        'DESCRIÇÃO (OPCIONAL)',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Objetivo, ementa ou foco deste caderno...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cor Temática
                      Text(
                        'COR DE DESTAQUE',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...palette.map((colorItem) {
                            final isSelected = selectedColor == colorItem['hex'];
                            final colorVal = _parseColor(colorItem['hex']!);
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedColor = colorItem['hex']!),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colorVal,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colorVal.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                              ),
                            );
                          }),
                          VipRgbColorTrigger(
                            currentColor: _parseColor(selectedColor),
                            isCustomSelected: !palette.any(
                              (c) => (c['hex'] ?? '').toUpperCase() == selectedColor.toUpperCase(),
                            ),
                            onColorSelected: (picked) {
                              setModalState(() {
                                selectedColor = VipRgbSpectrumPicker.colorToHex(
                                  picked,
                                  includeHash: false,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ações
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: isSaving
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(isSaving ? 'Salvando...' : (isEditing ? 'Salvar Alterações' : 'Criar Caderno')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _parseColor(selectedColor),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final title = titleCtrl.text.trim();
                                    final subject = subjectCtrl.text.trim().isNotEmpty ? subjectCtrl.text.trim() : 'Geral';
                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Por favor, informe o título do caderno.')),
                                      );
                                      return;
                                    }

                                    setModalState(() => isSaving = true);

                                    final newNb = StudyNotebook(
                                      id: notebook?.id ?? 'nb-${DateTime.now().millisecondsSinceEpoch}',
                                      title: title,
                                      subject: subject,
                                      description: descCtrl.text.trim(),
                                      colorHex: selectedColor,
                                      iconCode: notebook?.iconCode ?? 0xe3e6,
                                      notes: notebook?.notes ?? [],
                                      createdAt: notebook?.createdAt ?? DateTime.now(),
                                    );

                                    final scope = widget.groupScope;
                                    if (scope != null) {
                                      await StudyGroupsService.instance.saveGroupNotebook(scope.groupId, newNb);
                                    } else {
                                      await SupabaseService.saveNotebook(newNb);
                                    }

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    if (!mounted) return;
                                    await _loadNotebooks();
                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Caderno "$title" ${isEditing ? "atualizado" : "criado"} com sucesso! 🎉')),
                                    );
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
      },
    );
  }

  // ----------------------------------------------------
  // CONFIRMAR EXCLUSÃO DE CADERNO
  // ----------------------------------------------------
  void _confirmDeleteNotebook(StudyNotebook notebook) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Excluir Caderno?', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          content: Text('Tem certeza que deseja excluir "${notebook.title}" e todas as suas ${notebook.notes.length} anotações? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.coral),
              onPressed: () async {
                Navigator.pop(ctx);
                final scope = widget.groupScope;
                if (scope != null) {
                  await StudyGroupsService.instance.deleteGroupNotebook(scope.groupId, notebook.id);
                } else {
                  await SupabaseService.deleteNotebook(notebook.id);
                }
                if (mounted) {
                  if (_selectedNotebook?.id == notebook.id) {
                    setState(() {
                      _selectedNotebook = null;
                      _selectedNote = null;
                    });
                  }
                  await _loadNotebooks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Caderno "${notebook.title}" excluído.')),
                    );
                  }
                }
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // MODAL: CRIAR OU EDITAR ANOTAÇÃO
  // ----------------------------------------------------
  void _openNoteEditorModal({StudyNote? note}) {
    if (_selectedNotebook == null) return;
    final notebook = _selectedNotebook!;
    final isEditing = note != null;

    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');
    final tagsCtrl = TextEditingController(text: note?.tags.join(', ') ?? notebook.subject);

    final List<StudyLink> draftLinks = List.from(note?.links ?? []);
    bool draftNeedsReview = note?.needsReview ?? false;
    bool isSaving = false;
    bool isFormattingWithAi = false;
    String? previousNoteText;

    // Controladores para adicionar link/imagem
    final newUrlCtrl = TextEditingController();
    final newTitleCtrl = TextEditingController();
    bool isImageToggle = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 860,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.90,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _parseColor(notebook.colorHex).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.note_alt_rounded, color: _parseColor(notebook.colorHex), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Editar Anotação 📝' : 'Nova Anotação 📝',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  'Caderno: ${notebook.title} · Anote conceitos, adicione referências e links com imagens renderizadas',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Título & Tags
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TÍTULO DA ANOTAÇÃO *',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: titleCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: Resumo sobre Protocolos de Enlace e Criptografia...',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TAGS (SEPARADAS POR VÍRGULA)',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: tagsCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: Redes, TLS, Resumo',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Conteúdo (Editor Markdown)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Campo de Texto da Anotação
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CONTEÚDO DA ANOTAÇÃO (SUPORTA MARKDOWN) *',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                        border: Border.all(
                                          color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 46),
                                              child: TextField(
                                                controller: contentCtrl,
                                                maxLines: null,
                                                expands: true,
                                                textAlignVertical: TextAlignVertical.top,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 13.5,
                                                  height: 1.5,
                                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: 'Escreva suas notas de estudo aqui...\n\nVocê pode usar títulos (# Título), tópicos (* item), blocos de código (```codigo```) ou colar links.',
                                                  border: InputBorder.none,
                                                  enabledBorder: InputBorder.none,
                                                  focusedBorder: InputBorder.none,
                                                  contentPadding: EdgeInsets.zero,
                                                  filled: false,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Barra de Ações e Aviso posicionada dentro do bloco da anotação (canto inferior direito)
                                          Positioned(
                                            bottom: 8,
                                            right: 10,
                                            child: previousNoteText != null
                                                // Aviso inline que aparece SOMENTE no bloco da anotação com botão para retornar
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                      border: Border.all(
                                                        color: isDark ? AsterConstants.surfaceInsetDark : const Color(0xFFCBD5E1),
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.08),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded, size: 13, color: AsterConstants.menta),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Formatado com IA ✨',
                                                          style: GoogleFonts.manrope(
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        InkWell(
                                                          onTap: () {
                                                            contentCtrl.text = previousNoteText!;
                                                            setModalState(() => previousNoteText = null);
                                                          },
                                                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                            decoration: BoxDecoration(
                                                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                              border: Border.all(
                                                                color: AsterTheme.primary(context).withValues(alpha: 0.4),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(Icons.undo_rounded, size: 12, color: AsterTheme.primary(context)),
                                                                const SizedBox(width: 3),
                                                                Text(
                                                                  'Retornar',
                                                                  style: GoogleFonts.manrope(
                                                                    fontSize: 10.5,
                                                                    fontWeight: FontWeight.w800,
                                                                    color: AsterTheme.primary(context),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        InkWell(
                                                          onTap: () => setModalState(() => previousNoteText = null),
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(2),
                                                            child: Icon(
                                                              Icons.close_rounded,
                                                              size: 14,
                                                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                // Botão de Formatação com IA (visível quando não há aviso ativo)
                                                : Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: (isSaving || isFormattingWithAi)
                                                          ? null
                                                          : () async {
                                                              final raw = contentCtrl.text.trim();
                                                              if (raw.isEmpty) {
                                                                return;
                                                              }

                                                              final originalText = contentCtrl.text;
                                                              setModalState(() {
                                                                isFormattingWithAi = true;
                                                                previousNoteText = null;
                                                              });
                                                              try {
                                                                final formatted = await GeminiService.formatStudyNote(
                                                                  rawText: raw,
                                                                  topicOrSubject: notebook.subject,
                                                                );
                                                                if (formatted.trim().isNotEmpty) {
                                                                  contentCtrl.text = formatted.trim();
                                                                  setModalState(() {
                                                                    previousNoteText = originalText;
                                                                  });
                                                                }
                                                              } catch (e) {
                                                                debugPrint('Erro ao formatar com IA: $e');
                                                              } finally {
                                                                setModalState(() => isFormattingWithAi = false);
                                                              }
                                                            },
                                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: isFormattingWithAi
                                                              ? AsterTheme.primary(context).withValues(alpha: 0.2)
                                                              : (isDark ? const Color(0xFF26204E) : const Color(0xFFF3F0FF)),
                                                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                          border: Border.all(
                                                            color: isDark ? AsterTheme.primary(context) : AsterTheme.primary(context).withValues(alpha: 0.7),
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                              blurRadius: 4,
                                                              offset: const Offset(0, 1),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (isFormattingWithAi) ...[
                                                              SizedBox(
                                                                width: 12,
                                                                height: 12,
                                                                child: CircularProgressIndicator(strokeWidth: 2, color: AsterTheme.primary(context)),
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'Formatando...',
                                                                style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
                                                              ),
                                                            ] else ...[
                                                              Icon(Icons.auto_awesome_rounded, size: 12, color: AsterTheme.primary(context)),
                                                              const SizedBox(width: 5),
                                                              Text(
                                                                'Corrigir Formatação com IA ✨',
                                                                style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Painel Lateral: Adicionar Links e Imagens
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                  border: Border.all(
                                    color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LINKS & IMAGENS ANEXADAS 🖼️',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Adicione URLs de sites de estudo ou links de imagens para renderização visual automática na anotação.',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Formulário rápido para adicionar novo Link / Imagem
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              SoftClayChoiceChip(
                                                label: 'Imagem 🖼️',
                                                icon: Icons.image_rounded,
                                                selected: isImageToggle,
                                                compact: true,
                                                onTap: () => setModalState(() => isImageToggle = true),
                                              ),
                                              const SizedBox(width: 8),
                                              SoftClayChoiceChip(
                                                label: 'Link Web 🔗',
                                                icon: Icons.link_rounded,
                                                selected: !isImageToggle,
                                                compact: true,
                                                onTap: () => setModalState(() => isImageToggle = false),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: newUrlCtrl,
                                            decoration: InputDecoration(
                                              hintText: isImageToggle ? 'https://.../diagrama.png' : 'https://exemplo.com/artigo',
                                              prefixIcon: Icon(isImageToggle ? Icons.image_rounded : Icons.link_rounded, size: 16),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            onChanged: (_) => setModalState(() {}),
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: newTitleCtrl,
                                            decoration: InputDecoration(
                                              hintText: isImageToggle ? 'Legenda da imagem (opcional)' : 'Título do link de referência',
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Prévia ao vivo da imagem se digitada!
                                          if (isImageToggle && newUrlCtrl.text.trim().startsWith('http')) ...[
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                newUrlCtrl.text.trim(),
                                                height: 90,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, stack) => Container(
                                                  height: 60,
                                                  alignment: Alignment.center,
                                                  color: AsterConstants.coral.withValues(alpha: 0.1),
                                                  child: Text(
                                                    'URL de imagem inválida ou inacessível',
                                                    style: GoogleFonts.manrope(fontSize: 10, color: AsterConstants.coral),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],

                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.add_rounded, size: 16),
                                              label: Text(isImageToggle ? 'Adicionar Imagem' : 'Adicionar Link'),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                backgroundColor: AsterTheme.primary(context),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () {
                                                final url = newUrlCtrl.text.trim();
                                                if (url.isEmpty || !url.startsWith('http')) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Por favor, informe uma URL válida iniciando com http:// ou https://')),
                                                  );
                                                  return;
                                                }

                                                final title = newTitleCtrl.text.trim().isNotEmpty
                                                    ? newTitleCtrl.text.trim()
                                                    : (isImageToggle ? 'Imagem de Estudo' : url);

                                                setModalState(() {
                                                  draftLinks.add(
                                                    StudyLink(
                                                      id: 'link-${DateTime.now().millisecondsSinceEpoch}',
                                                      url: url,
                                                      title: title,
                                                      isImage: isImageToggle,
                                                    ),
                                                  );
                                                  newUrlCtrl.clear();
                                                  newTitleCtrl.clear();
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Lista de links já adicionados
                                    Expanded(
                                      child: draftLinks.isEmpty
                                          ? Center(
                                              child: Text(
                                                'Nenhum link ou imagem adicionado ainda.',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                ),
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount: draftLinks.length,
                                              separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                                              itemBuilder: (ctx, idx) {
                                                final link = draftLinks[idx];
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        link.isImage ? Icons.image_rounded : Icons.link_rounded,
                                                        size: 16,
                                                        color: link.isImage ? AsterConstants.menta : AsterTheme.primary(context),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              link.title,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.manrope(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                              ),
                                                            ),
                                                            Text(
                                                              link.url,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.manrope(
                                                                fontSize: 9.5,
                                                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.close_rounded, size: 14, color: AsterConstants.coral),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () {
                                                          setModalState(() => draftLinks.removeAt(idx));
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rodapé do Modal
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            onTap: () => setModalState(() => draftNeedsReview = !draftNeedsReview),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: draftNeedsReview
                                    ? AsterConstants.ambar.withValues(alpha: 0.16)
                                    : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                border: Border.all(
                                  color: draftNeedsReview
                                      ? AsterConstants.ambar
                                      : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    draftNeedsReview ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                                    size: 16,
                                    color: draftNeedsReview ? AsterConstants.ambar : AsterTheme.primary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    draftNeedsReview ? 'Marcada para revisão' : 'Marcar para revisar',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: draftNeedsReview
                                          ? AsterConstants.ambar
                                          : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: isSaving
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(isSaving ? 'Salvando...' : 'Salvar Anotação 💾'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AsterTheme.primary(context),
                              foregroundColor: AsterTheme.onPrimary(context),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final title = titleCtrl.text.trim();
                                    final content = contentCtrl.text.trim();
                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Por favor, informe o título da anotação.')),
                                      );
                                      return;
                                    }

                                    setModalState(() => isSaving = true);

                                    final parsedTags = tagsCtrl.text
                                        .split(',')
                                        .map((t) => t.trim())
                                        .where((t) => t.isNotEmpty)
                                        .toList();

                                    final updatedNote = StudyNote(
                                      id: note?.id ?? 'note-${DateTime.now().millisecondsSinceEpoch}',
                                      notebookId: notebook.id,
                                      title: title,
                                      content: content,
                                      links: draftLinks,
                                      tags: parsedTags.isNotEmpty ? parsedTags : [notebook.subject],
                                      needsReview: draftNeedsReview,
                                      lastReviewedAt: note?.lastReviewedAt,
                                      reviewCount: note?.reviewCount ?? 0,
                                      createdAt: note?.createdAt ?? DateTime.now(),
                                    );

                                    final scope = widget.groupScope;
                                    if (scope != null) {
                                      await StudyGroupsService.instance.saveGroupNote(
                                        scope.groupId,
                                        notebook.id,
                                        updatedNote,
                                      );
                                    } else {
                                      await SupabaseService.saveNote(notebook.id, updatedNote);
                                    }

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    if (!mounted) return;
                                    await _loadNotebooks();
                                    if (!mounted) return;

                                    setState(() {
                                      _selectedNote = updatedNote;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Anotação "$title" salva com sucesso! 🎉')),
                                    );
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
      },
    );
  }

  // ----------------------------------------------------
  // CONFIRMAR EXCLUSÃO DE ANOTAÇÃO
  // ----------------------------------------------------
  void _confirmDeleteNote(StudyNote note) {
    if (_selectedNotebook == null) return;
    final notebook = _selectedNotebook!;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Excluir Anotação?', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          content: Text('Deseja excluir permanentemente a anotação "${note.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.coral),
              onPressed: () async {
                Navigator.pop(ctx);
                final scope = widget.groupScope;
                if (scope != null) {
                  await StudyGroupsService.instance.deleteGroupNote(scope.groupId, notebook.id, note.id);
                } else {
                  await SupabaseService.deleteNote(notebook.id, note.id);
                }
                if (mounted) {
                  setState(() {
                    if (_selectedNote?.id == note.id) {
                      _selectedNote = null;
                    }
                  });
                  await _loadNotebooks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Anotação "${note.title}" excluída.')),
                    );
                  }
                }
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // BUILD PRINCIPAL
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AsterTheme.primary(context)));
    }

    if (_selectedNotebook != null) {
      return _buildNotebookDetailView(isDark);
    }

    return _buildNotebooksGridView(isDark);
  }

  // ----------------------------------------------------
  // 1. VISÃO GERAL: GRID DE CADERNOS
  // ----------------------------------------------------
  Widget _buildNotebooksGridView(bool isDark) {
    final subjects = <String>{'Todos'};
    for (final nb in _notebooks) {
      if (nb.subject.isNotEmpty) subjects.add(nb.subject);
    }

    final query = _searchQuery.toLowerCase().trim();
    final filteredNotebooks = _notebooks.where((nb) {
      final matchesQuery = query.isEmpty ||
          nb.title.toLowerCase().contains(query) ||
          nb.subject.toLowerCase().contains(query) ||
          nb.description.toLowerCase().contains(query) ||
          nb.notes.any((n) {
            final dateShort = DateFormat('dd/MM').format(n.updatedAt);
            final dateFull = DateFormat('dd/MM/yyyy').format(n.updatedAt);
            final month = _monthNamePt(n.updatedAt.month);
            return n.title.toLowerCase().contains(query) ||
                n.content.toLowerCase().contains(query) ||
                n.tags.any((t) => t.toLowerCase().contains(query.replaceAll('#', ''))) ||
                dateShort.contains(query) ||
                dateFull.contains(query) ||
                month.contains(query);
          });

      final matchesSubject = _selectedSubjectFilter == 'Todos' || nb.subject == _selectedSubjectFilter;
      final matchesReviewFilter = switch (_notebookReviewFilter) {
        _NotebookReviewFilter.all => true,
        _NotebookReviewFilter.toReview => nb.pendingReviewCount() > 0,
        _NotebookReviewFilter.upToDate => nb.isUpToDate(),
      };
      return matchesQuery && matchesSubject && matchesReviewFilter;
    }).toList();

    int totalNotes = 0;
    int recentNotes7d = 0;
    int totalWords = 0;
    int totalNotesToReview = 0;
    int notebooksToReviewCount = 0;
    int notebooksUpToDateCount = 0;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    for (final nb in _notebooks) {
      totalNotes += nb.noteCount;
      final pendingNb = nb.pendingReviewCount();
      totalNotesToReview += pendingNb;
      if (pendingNb > 0) notebooksToReviewCount++;
      if (nb.isUpToDate()) notebooksUpToDateCount++;
      for (final note in nb.notes) {
        if (!note.updatedAt.isBefore(sevenDaysAgo)) {
          recentNotes7d++;
        }
        final trimmed = note.content.trim();
        if (trimmed.isNotEmpty) {
          totalWords += trimmed.split(RegExp(r'\s+')).length;
        }
      }
    }
    final estimatedReviewMinutes = totalNotes == 0 ? 0 : (totalWords / 180).ceil().clamp(1, 9999);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.groupScope == null) const NoesisCollapsedMenuSpacer(width: 82),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.groupScope != null ? 'Cadernos do Grupo 📚' : 'Cadernos de Estudo 📚',
                            style: GoogleFonts.manrope(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Text(
                              '${_notebooks.length} Cadernos',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.primary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.groupScope != null
                            ? 'Crie cadernos, formate anotações com IA ✨ ou anexe seus próprios cadernos ao grupo.'
                            : 'Organize seus resumos conceituais, salve links de referência e visualize imagens anexadas para memorização ativa.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.groupScope == null || widget.groupScope!.canEdit)
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (widget.groupScope?.onAttachExisting != null)
                        OutlinedButton.icon(
                          key: const Key('group_attach_notebook_button'),
                          onPressed: widget.groupScope!.onAttachExisting,
                          icon: const Icon(Icons.attach_file_rounded, size: 18),
                          label: const Text('Anexar Meu Caderno'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                          ),
                        ),
                      ElevatedButton.icon(
                        key: widget.groupScope != null ? const Key('group_create_notebook_button') : null,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Novo Caderno'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AsterTheme.primary(context),
                          foregroundColor: AsterTheme.onPrimary(context),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                        ),
                        onPressed: () => _openNotebookModal(),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Métricas em Cards Soft Clay
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 800;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 2.4 : 1.8,
                  children: [
                    _buildMetricCard(
                      title: 'Cadernos Ativos',
                      value: '${_notebooks.length}',
                      icon: Icons.menu_book_rounded,
                      color: AsterTheme.primary(context),
                      isDark: isDark,
                    ),
                    _buildMetricCard(
                      title: 'Anotações Totais',
                      value: '$totalNotes',
                      icon: Icons.note_alt_rounded,
                      color: AsterConstants.menta,
                      isDark: isDark,
                    ),
                    _buildMetricCard(
                      title: 'Atualizadas (7d)',
                      value: '$recentNotes7d',
                      icon: Icons.update_rounded,
                      color: AsterConstants.ambar,
                      isDark: isDark,
                    ),
                    _buildMetricCard(
                      title: 'Tempo de Revisão',
                      value: estimatedReviewMinutes > 0 ? '~$estimatedReviewMinutes min' : '0 min',
                      icon: Icons.schedule_rounded,
                      color: AsterConstants.coral,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),

            // Barra de Busca, Central de Revisão e Filtros Soft Clay
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                border: Border.all(
                  color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                ),
                boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.claySubtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Pesquisar cadernos, anotações ou termos-chave...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              borderSide: BorderSide(color: AsterTheme.primary(context), width: 1.4),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        key: const Key('notebooks_review_queue_button'),
                        onTap: () => _openNotebooksReviewDialog(),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: totalNotesToReview > 0
                                ? AsterConstants.ambar.withValues(alpha: 0.14)
                                : AsterConstants.menta.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            border: Border.all(
                              color: (totalNotesToReview > 0 ? AsterConstants.ambar : AsterConstants.menta)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                totalNotesToReview > 0
                                    ? Icons.bookmark_added_rounded
                                    : Icons.verified_rounded,
                                size: 16,
                                color: totalNotesToReview > 0 ? AsterConstants.ambar : AsterConstants.menta,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                totalNotesToReview > 0
                                    ? 'Revisar e Marcar ($totalNotesToReview)'
                                    : 'Revisar e Marcar ✓',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: totalNotesToReview > 0 ? AsterConstants.ambar : AsterConstants.menta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filtros por Status de Revisão
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildNotebookFilterChip(
                        key: const Key('notebooks_filter_all'),
                        label: 'Todos (${_notebooks.length})',
                        icon: Icons.menu_book_rounded,
                        selected: _notebookReviewFilter == _NotebookReviewFilter.all,
                        activeColor: AsterTheme.primary(context),
                        isDark: isDark,
                        onTap: () => setState(() => _notebookReviewFilter = _NotebookReviewFilter.all),
                      ),
                      _buildNotebookFilterChip(
                        key: const Key('notebooks_filter_to_review'),
                        label: 'Para Revisar ($notebooksToReviewCount)',
                        icon: Icons.bookmark_rounded,
                        selected: _notebookReviewFilter == _NotebookReviewFilter.toReview,
                        activeColor: AsterConstants.ambar,
                        isDark: isDark,
                        onTap: () => setState(() => _notebookReviewFilter = _NotebookReviewFilter.toReview),
                      ),
                      _buildNotebookFilterChip(
                        key: const Key('notebooks_filter_up_to_date'),
                        label: 'Em Dia ($notebooksUpToDateCount)',
                        icon: Icons.check_circle_rounded,
                        selected: _notebookReviewFilter == _NotebookReviewFilter.upToDate,
                        activeColor: AsterConstants.menta,
                        isDark: isDark,
                        onTap: () => setState(() => _notebookReviewFilter = _NotebookReviewFilter.upToDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chips de Disciplina Soft Clay
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: subjects.map((sub) {
                        final isSelected = _selectedSubjectFilter == sub;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            onTap: () => setState(() => _selectedSubjectFilter = sub),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AsterTheme.primary(context)
                                    : AsterTheme.surfaceAlt(context),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                boxShadow: isSelected ? AsterTheme.primaryShadow(context) : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    Icon(Icons.check_rounded, size: 14, color: AsterTheme.onPrimary(context)),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    sub,
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? AsterTheme.onPrimary(context)
                                          : AsterTheme.text(context),
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
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Grid de Cadernos
            if (filteredNotebooks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 54, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                      const SizedBox(height: 14),
                      Text(
                        'Nenhum caderno encontrado.',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Crie um novo caderno para organizar seus estudos com links e imagens!',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Criar Primeiro Caderno'),
                        style: ElevatedButton.styleFrom(backgroundColor: AsterTheme.primary(context), foregroundColor: Colors.white),
                        onPressed: () => _openNotebookModal(),
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final crossAxisCount = isWide ? 3 : (constraints.maxWidth > 600 ? 2 : 1);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: isWide ? 1.35 : 1.25,
                    ),
                    itemCount: filteredNotebooks.length,
                    itemBuilder: (ctx, idx) {
                      final nb = filteredNotebooks[idx];
                      final nbColor = _parseColor(nb.colorHex);

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                          border: Border.all(
                            color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                          ),
                          boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: nbColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  ),
                                  child: Text(
                                    nb.subject.toUpperCase(),
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: nbColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (nb.noteCount > 0) ...[
                                  Builder(
                                    builder: (_) {
                                      final pendingCount = nb.pendingReviewCount();
                                      final isUpToDate = pendingCount == 0;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        onTap: () => _openNotebooksReviewDialog(focusNotebook: nb),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (isUpToDate ? AsterConstants.menta : AsterConstants.ambar)
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                          ),
                                          child: Text(
                                            isUpToDate ? 'Em dia ✓' : '$pendingCount p/ revisar',
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isUpToDate ? AsterConstants.menta : AsterConstants.ambar,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                                const Spacer(),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz_rounded, size: 20, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium)),
                                  onSelected: (val) {
                                    if (val == 'review_manage') {
                                      _openNotebooksReviewDialog(focusNotebook: nb, startInMarkMode: true);
                                    }
                                    if (val == 'edit') _openNotebookModal(notebook: nb);
                                    if (val == 'delete') _confirmDeleteNotebook(nb);
                                  },
                                  itemBuilder: (popCtx) => [
                                    const PopupMenuItem(
                                      value: 'review_manage',
                                      child: Row(
                                        children: [
                                          Icon(Icons.bookmark_added_rounded, size: 18, color: AsterConstants.ambar),
                                          SizedBox(width: 8),
                                          Text('Marcar o que revisar'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_note_rounded, size: 18),
                                          SizedBox(width: 8),
                                          Text('Editar Caderno'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                          SizedBox(width: 8),
                                          Text('Excluir Caderno', style: TextStyle(color: AsterConstants.coral)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Título do Caderno
                            Text(
                              nb.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nb.description.isNotEmpty ? nb.description : 'Sem descrição.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                            const Spacer(),

                            // Estatísticas úteis (Anotações, Tópicos e Última Revisão)
                            Builder(
                              builder: (_) {
                                final uniqueTags = <String>{};
                                var lastEdit = nb.updatedAt;
                                for (final note in nb.notes) {
                                  uniqueTags.addAll(note.tags);
                                  if (note.updatedAt.isAfter(lastEdit)) {
                                    lastEdit = note.updatedAt;
                                  }
                                }
                                final updatedStr = DateFormat('dd/MM').format(lastEdit);
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildBadge(Icons.note_alt_outlined, '${nb.noteCount} notas', isDark),
                                    _buildBadge(Icons.tag_rounded, '${uniqueTags.length} tópicos', isDark),
                                    _buildBadge(Icons.update_rounded, 'Atual. $updatedStr', isDark),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            // Botão Abrir Caderno
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.auto_stories_rounded, size: 16),
                                label: const Text('Abrir Caderno 📖'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: nbColor,
                                  foregroundColor: ThemeData.estimateBrightnessForColor(nbColor) == Brightness.light
                                      ? const Color(0xFF111111)
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedNotebook = nb;
                                    _selectedNote = nb.notes.isNotEmpty ? nb.notes.first : null;
                                    _notesSearchQuery = '';
                                    _notesSearchCtrl.clear();
                                    _selectedTagFilter = 'Todas';
                                    _selectedDateFilter = null;
                                    _noteSortOrder = 'recent';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
        boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookFilterChip({
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.16)
              : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          border: Border.all(
            color: selected ? activeColor.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? activeColor
                  : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? activeColor
                    : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleNoteReviewMark(StudyNotebook notebook, StudyNote note) async {
    final updated = note.copyWith(
      needsReview: !note.needsReview,
      updatedAt: note.updatedAt,
    );
    final scope = widget.groupScope;
    if (scope != null) {
      await StudyGroupsService.instance.saveGroupNote(notebook.id.isNotEmpty ? scope.groupId : scope.groupId, notebook.id, updated);
    } else {
      await SupabaseService.saveNote(notebook.id, updated);
    }
    await _loadNotebooks();
    if (!mounted) return;
    setState(() {
      if (_selectedNote?.id == note.id) {
        _selectedNote = updated;
      }
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: updated.needsReview ? AsterConstants.ambar : AsterTheme.primary(context),
          content: Text(
            updated.needsReview
                ? '"${note.title}" marcada para revisão!'
                : 'Marcação de revisão removida de "${note.title}".',
          ),
        ),
      );
  }

  Future<void> _completeNoteReview(StudyNotebook notebook, StudyNote note) async {
    final now = DateTime.now();
    final updated = note.copyWith(
      needsReview: false,
      lastReviewedAt: now,
      reviewCount: note.reviewCount + 1,
      updatedAt: note.updatedAt,
    );
    final scope = widget.groupScope;
    int groupEarned = 0;
    if (scope != null) {
      await StudyGroupsService.instance.saveGroupNote(scope.groupId, notebook.id, updated);
      final res = await StudyGroupsService.instance.recordGroupNotebookReviewById(
        scope.groupId,
        notebook.id,
        note.id,
        notebook.title,
      );
      groupEarned = res.earnedInsights;
    } else {
      await SupabaseService.saveNote(notebook.id, updated);
    }
    await _loadNotebooks();
    if (!mounted) return;
    setState(() {
      if (_selectedNote?.id == note.id) {
        _selectedNote = updated;
      }
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: AsterConstants.menta,
          content: Text(
            groupEarned > 0
                ? 'Revisão de "${note.title}" concluída! +$groupEarned Insights no grupo ✓'
                : 'Revisão de "${note.title}" concluída! ✓',
          ),
        ),
      );
  }

  void _openNotebooksReviewDialog({
    StudyNotebook? focusNotebook,
    bool startInMarkMode = false,
  }) {
    bool isMarkMode = startInMarkMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final now = DateTime.now();
            final sourceNotebooks = focusNotebook != null
                ? _notebooks.where((n) => n.id == focusNotebook.id).toList()
                : _notebooks;

            final dueEntries = <({StudyNotebook notebook, StudyNote note})>[];
            final allEntries = <({StudyNotebook notebook, StudyNote note})>[];

            for (final nb in sourceNotebooks) {
              for (final n in nb.notesToReview(referenceDate: now)) {
                dueEntries.add((notebook: nb, note: n));
              }
              for (final n in nb.notes) {
                allEntries.add((notebook: nb, note: n));
              }
            }

            dueEntries.sort((a, b) {
              if (a.note.needsReview != b.note.needsReview) {
                return a.note.needsReview ? -1 : 1;
              }
              return (a.note.lastReviewedAt ?? a.note.updatedAt)
                  .compareTo(b.note.lastReviewedAt ?? b.note.updatedAt);
            });

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680, maxHeight: 700),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AsterConstants.ambar.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bookmark_added_rounded, size: 20, color: AsterConstants.ambar),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  focusNotebook != null
                                      ? 'Revisão · ${focusNotebook.title}'
                                      : 'Revisão dos Cadernos de Estudo',
                                  style: GoogleFonts.manrope(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  'Veja o que precisa ser revisado e marque ou conclua revisões rapidamente.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Alternador: O que revisar vs Marcar anotações
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => isMarkMode = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: !isMarkMode ? AsterTheme.primary(context) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Para Revisar (${dueEntries.length})',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: !isMarkMode
                                            ? AsterTheme.onPrimary(context)
                                            : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                key: const Key('notebooks_dialog_mark_tab'),
                                onTap: () => setDialogState(() => isMarkMode = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: isMarkMode ? AsterTheme.primary(context) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Marcar o que revisar (${allEntries.length})',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isMarkMode
                                            ? AsterTheme.onPrimary(context)
                                            : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (!isMarkMode && dueEntries.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                          decoration: BoxDecoration(
                            color: AsterConstants.menta.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.verified_rounded, size: 36, color: AsterConstants.menta),
                              const SizedBox(height: 10),
                              Text(
                                'Nenhuma anotação pendente de revisão!',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use a aba "Marcar o que revisar" para escolher tópicos que deseja revisar.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: isMarkMode ? allEntries.length : dueEntries.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, idx) {
                              final entry = isMarkMode ? allEntries[idx] : dueEntries[idx];
                              final nb = entry.notebook;
                              final n = entry.note;
                              final nbColor = _parseColor(nb.colorHex);
                              final reason = n.reviewStatusReason(referenceDate: now);

                              if (isMarkMode) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    border: Border.all(
                                      color: n.needsReview
                                          ? AsterConstants.ambar.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        key: Key('mark_review_checkbox_${n.id}'),
                                        value: n.needsReview,
                                        activeColor: AsterConstants.ambar,
                                        onChanged: (_) async {
                                          await _toggleNoteReviewMark(nb, n);
                                          if (dialogCtx.mounted) {
                                            setDialogState(() {});
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.manrope(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                              ),
                                            ),
                                            Text(
                                              '${nb.title} · ~${n.estimatedReviewMinutes} min · $reason',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.manrope(
                                                fontSize: 11,
                                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: nbColor.withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                ),
                                                child: Text(
                                                  nb.title,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: nbColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (n.needsReview ? AsterConstants.ambar : AsterConstants.coral)
                                                      .withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                ),
                                                child: Text(
                                                  reason,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: n.needsReview ? AsterConstants.ambar : AsterConstants.coral,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            n.title,
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                            ),
                                          ),
                                          Text(
                                            'Leitura ~${n.estimatedReviewMinutes} min · Revisada ${n.reviewCount}x',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Marcar como revisada agora',
                                      icon: const Icon(Icons.check_circle_outline_rounded, color: AsterConstants.menta),
                                      onPressed: () async {
                                        await _completeNoteReview(nb, n);
                                        if (dialogCtx.mounted) {
                                          setDialogState(() {});
                                        }
                                      },
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AsterTheme.primary(context),
                                        foregroundColor: AsterTheme.onPrimary(context),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        setState(() {
                                          _selectedNotebook = nb;
                                          _selectedNote = n;
                                          _notesSearchQuery = '';
                                          _notesSearchCtrl.clear();
                                          _selectedTagFilter = 'Todas';
                                          _selectedDateFilter = null;
                                          _onlyNotesToReview = false;
                                        });
                                      },
                                      child: const Text('Revisar'),
                                    ),
                                  ],
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

  Widget _buildBadge(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
          ),
        ),
      ],
    );
  }

  String _monthNamePt(int month) {
    const months = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  // ----------------------------------------------------
  // 2. VISÃO INTERNA DO CADERNO (ANOTAÇÕES, LINKS & IMAGENS)
  // ----------------------------------------------------
  Widget _buildNotebookDetailView(bool isDark) {
    final notebook = _selectedNotebook!;
    final nbColor = _parseColor(notebook.colorHex);

    final allTags = <String>{'Todas'};
    for (final n in notebook.notes) {
      for (final t in n.tags) {
        final clean = t.trim();
        if (clean.isNotEmpty) allTags.add(clean);
      }
    }

    final query = _notesSearchQuery.trim().toLowerCase();
    final filteredNotes = notebook.notes.where((n) {
      // 1. Busca por texto (nome/título, tags, conteúdo ou data)
      if (query.isNotEmpty) {
        final titleMatch = n.title.toLowerCase().contains(query);
        final contentMatch = n.content.toLowerCase().contains(query);
        final tagMatch = n.tags.any((t) => t.toLowerCase().contains(query.replaceAll('#', '')));
        final dateShortMatch = DateFormat('dd/MM').format(n.updatedAt).contains(query);
        final dateFullMatch = DateFormat('dd/MM/yyyy').format(n.updatedAt).contains(query);
        final monthName = _monthNamePt(n.updatedAt.month);
        final monthMatch = monthName.contains(query);
        if (!titleMatch && !contentMatch && !tagMatch && !dateShortMatch && !dateFullMatch && !monthMatch) {
          return false;
        }
      }

      // 2. Filtro por tag selecionada
      if (_selectedTagFilter != 'Todas') {
        final hasTag = n.tags.any((t) => t.trim().toLowerCase() == _selectedTagFilter.toLowerCase());
        if (!hasTag) return false;
      }

      // 3. Filtro por data específica
      if (_selectedDateFilter != null) {
        final matchesDate = n.updatedAt.year == _selectedDateFilter!.year &&
            n.updatedAt.month == _selectedDateFilter!.month &&
            n.updatedAt.day == _selectedDateFilter!.day;
        if (!matchesDate) return false;
      }

      // 4. Filtro rápido: somente notas que devem ser revisadas
      if (_onlyNotesToReview && !n.shouldReview()) {
        return false;
      }

      return true;
    }).toList();

    // Ordenação
    if (_noteSortOrder == 'recent') {
      filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else if (_noteSortOrder == 'oldest') {
      filteredNotes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    } else if (_noteSortOrder == 'az') {
      filteredNotes.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    final currentReadingNote = _selectedNote ?? (filteredNotes.isNotEmpty ? filteredNotes.first : null);

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<bool>(
          valueListenable: AsterTheme.sidebarCollapsedNotifier,
          builder: (context, isCollapsed, _) {
            final shiftLeft = isDesktop && isCollapsed;
            return AppBar(
              leadingWidth: shiftLeft ? 138 : null,
              leading: Padding(
                padding: EdgeInsets.only(left: shiftLeft ? 84 : 0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Voltar à lista de cadernos',
                  onPressed: () {
                    setState(() {
                      _selectedNotebook = null;
                      _selectedNote = null;
                      _notesSearchQuery = '';
                      _notesSearchCtrl.clear();
                      _selectedTagFilter = 'Todas';
                      _selectedDateFilter = null;
                      _noteSortOrder = 'recent';
                    });
                  },
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        notebook.title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: nbColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          notebook.subject,
                          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: nbColor),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${notebook.notes.length} anotações · ${notebook.totalLinksCount} links · ${notebook.totalImagesCount} imagens',
                    style: GoogleFonts.manrope(fontSize: 11, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                  ),
                ],
              ),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Editar Caderno'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _openNotebookModal(notebook: notebook),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nova Anotação 📝'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nbColor,
                    foregroundColor: ThemeData.estimateBrightnessForColor(nbColor) == Brightness.light
                        ? const Color(0xFF111111)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                  ),
                  onPressed: () => _openNoteEditorModal(),
                ),
                const SizedBox(width: 16),
              ],
            );
          },
        ),
      ),
      body: notebook.notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note_rounded, size: 58, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                  const SizedBox(height: 14),
                  Text(
                    'Caderno vazio.',
                    style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Adicione sua primeira anotação para começar a estudar este tema.',
                    style: GoogleFonts.manrope(fontSize: 13, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Criar Nova Anotação'),
                    style: ElevatedButton.styleFrom(backgroundColor: nbColor, foregroundColor: Colors.white),
                    onPressed: () => _openNoteEditorModal(),
                  ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coluna Esquerda: Lista de Anotações do Caderno com Busca e Filtros
                SizedBox(
                  width: 320,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Barra de Busca e Menu de Data/Ordenação
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: TextField(
                                        controller: _notesSearchCtrl,
                                        style: GoogleFonts.manrope(fontSize: 12.5),
                                        decoration: InputDecoration(
                                          hintText: 'Buscar tags, nomes ou data...',
                                          hintStyle: GoogleFonts.manrope(
                                            fontSize: 11.5,
                                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                          ),
                                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                          suffixIcon: _notesSearchQuery.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.close_rounded, size: 16),
                                                  splashRadius: 16,
                                                  onPressed: () {
                                                    setState(() {
                                                      _notesSearchCtrl.clear();
                                                      _notesSearchQuery = '';
                                                    });
                                                  },
                                                )
                                              : null,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                          filled: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            borderSide: BorderSide(
                                              color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            borderSide: BorderSide(
                                              color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            borderSide: BorderSide(
                                              color: AsterTheme.primary(context),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        onChanged: (val) => setState(() => _notesSearchQuery = val),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
                                    tooltip: 'Filtrar ou ordenar por data',
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium)),
                                    icon: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _selectedDateFilter != null || _noteSortOrder != 'recent'
                                            ? AsterTheme.primary(context).withValues(alpha: 0.15)
                                            : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(
                                          color: _selectedDateFilter != null || _noteSortOrder != 'recent'
                                              ? AsterTheme.primary(context)
                                              : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.calendar_month_rounded,
                                        size: 18,
                                        color: _selectedDateFilter != null || _noteSortOrder != 'recent'
                                            ? AsterTheme.primary(context)
                                            : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                      ),
                                    ),
                                    onSelected: (val) async {
                                      if (val == 'pick_date') {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDateFilter ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2035),
                                          locale: const Locale('pt', 'BR'),
                                          helpText: 'Selecionar Data',
                                          cancelText: 'Cancelar',
                                          confirmText: 'OK',
                                          builder: (context, child) {
                                            return Theme(
                                              data: isDark
                                                  ? ThemeData.dark().copyWith(
                                                      colorScheme: ColorScheme.dark(
                                                        primary: AsterTheme.primary(context),
                                                        onPrimary: AsterTheme.onPrimary(context),
                                                        surface: AsterConstants.surfaceCardDark,
                                                        onSurface: AsterConstants.textLight,
                                                      ),
                                                    )
                                                  : ThemeData.light().copyWith(
                                                      colorScheme: ColorScheme.light(
                                                        primary: AsterTheme.primary(context),
                                                        onPrimary: AsterTheme.onPrimary(context),
                                                        surface: AsterConstants.surfaceCard,
                                                        onSurface: AsterConstants.textDark,
                                                      ),
                                                    ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() => _selectedDateFilter = picked);
                                        }
                                      } else if (val == 'clear_date') {
                                        setState(() => _selectedDateFilter = null);
                                      } else if (val == 'recent' || val == 'oldest' || val == 'az') {
                                        setState(() => _noteSortOrder = val);
                                      }
                                    },
                                    itemBuilder: (popCtx) => [
                                      PopupMenuItem(
                                        value: 'pick_date',
                                        child: Row(
                                          children: [
                                            Icon(Icons.event_rounded, size: 18, color: AsterTheme.primary(context)),
                                            const SizedBox(width: 8),
                                            Text(
                                              _selectedDateFilter == null
                                                  ? 'Filtrar por data...'
                                                  : 'Alterar data (${DateFormat('dd/MM/yyyy').format(_selectedDateFilter!)})',
                                              style: GoogleFonts.manrope(fontSize: 12.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_selectedDateFilter != null)
                                        const PopupMenuItem(
                                          value: 'clear_date',
                                          child: Row(
                                            children: [
                                              Icon(Icons.clear_rounded, size: 18, color: AsterConstants.coral),
                                              SizedBox(width: 8),
                                              Text('Remover filtro de data', style: TextStyle(color: AsterConstants.coral, fontSize: 12.5)),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'recent',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_downward_rounded,
                                              size: 16,
                                              color: _noteSortOrder == 'recent' ? AsterTheme.primary(context) : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Mais recentes primeiro',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: _noteSortOrder == 'recent' ? FontWeight.w700 : FontWeight.w500,
                                                color: _noteSortOrder == 'recent' ? AsterTheme.primary(context) : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'oldest',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_upward_rounded,
                                              size: 16,
                                              color: _noteSortOrder == 'oldest' ? AsterTheme.primary(context) : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Mais antigas primeiro',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: _noteSortOrder == 'oldest' ? FontWeight.w700 : FontWeight.w500,
                                                color: _noteSortOrder == 'oldest' ? AsterTheme.primary(context) : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'az',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.sort_by_alpha_rounded,
                                              size: 16,
                                              color: _noteSortOrder == 'az' ? AsterTheme.primary(context) : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Ordem Alfabética (A-Z)',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: _noteSortOrder == 'az' ? FontWeight.w700 : FontWeight.w500,
                                                color: _noteSortOrder == 'az' ? AsterTheme.primary(context) : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  InkWell(
                                    key: const Key('notebook_detail_only_review_toggle'),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    onTap: () => setState(() => _onlyNotesToReview = !_onlyNotesToReview),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _onlyNotesToReview
                                            ? AsterConstants.ambar.withValues(alpha: 0.16)
                                            : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        border: Border.all(
                                          color: _onlyNotesToReview
                                              ? AsterConstants.ambar
                                              : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bookmark_rounded,
                                            size: 13,
                                            color: _onlyNotesToReview ? AsterConstants.ambar : AsterTheme.primary(context),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Só p/ revisar (${notebook.pendingReviewCount()})',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _onlyNotesToReview
                                                  ? AsterConstants.ambar
                                                  : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Chips de Tags horizontais se houver tags
                              if (allTags.length > 1) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 32,
                                  child: Listener(
                                    onPointerSignal: (pointerSignal) {
                                      if (pointerSignal is PointerScrollEvent && _tagsScrollCtrl.hasClients) {
                                        final target = (_tagsScrollCtrl.offset + pointerSignal.scrollDelta.dy)
                                            .clamp(0.0, _tagsScrollCtrl.position.maxScrollExtent);
                                        _tagsScrollCtrl.jumpTo(target);
                                      }
                                    },
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context).copyWith(
                                        dragDevices: {
                                          PointerDeviceKind.touch,
                                          PointerDeviceKind.mouse,
                                          PointerDeviceKind.trackpad,
                                          PointerDeviceKind.stylus,
                                        },
                                      ),
                                      child: ListView(
                                        controller: _tagsScrollCtrl,
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                        children: allTags.map((tag) {
                                          final isSelected = _selectedTagFilter == tag;
                                          final labelText = tag == 'Todas' ? 'Todas' : '#$tag';
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                              onTap: () => setState(() => _selectedTagFilter = tag),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AsterTheme.primary(context).withValues(alpha: 0.18)
                                                      : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AsterTheme.primary(context)
                                                        : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                                    width: isSelected ? 1.5 : 1,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    labelText,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 11,
                                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                      color: isSelected
                                                          ? AsterTheme.primary(context)
                                                          : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              // Indicador de Filtro Ativo
                              if (_selectedDateFilter != null || _selectedTagFilter != 'Todas' || _notesSearchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (_selectedDateFilter != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.calendar_today_rounded, size: 10, color: AsterTheme.primary(context)),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(_selectedDateFilter!),
                                              style: GoogleFonts.manrope(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: AsterTheme.primary(context),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () => setState(() => _selectedDateFilter = null),
                                              child: Icon(Icons.close_rounded, size: 12, color: AsterTheme.primary(context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      '${filteredNotes.length} de ${notebook.notes.length}',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10.5,
                                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _notesSearchCtrl.clear();
                                          _notesSearchQuery = '';
                                          _selectedTagFilter = 'Todas';
                                          _selectedDateFilter = null;
                                        });
                                      },
                                      child: Text(
                                        'Limpar',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AsterTheme.primary(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                        ),

                        // Lista de Anotações ou Estado Vazio
                        Expanded(
                          child: filteredNotes.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off_rounded,
                                          size: 38,
                                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Nenhuma anotação encontrada',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tente alterar os termos da busca, tags ou data.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton.icon(
                                          icon: const Icon(Icons.refresh_rounded, size: 14),
                                          label: const Text('Limpar filtros'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AsterTheme.primary(context),
                                            textStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _notesSearchCtrl.clear();
                                              _notesSearchQuery = '';
                                              _selectedTagFilter = 'Todas';
                                              _selectedDateFilter = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: filteredNotes.length,
                                  separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                                  itemBuilder: (ctx, idx) {
                                    final n = filteredNotes[idx];
                                    final isSelected = currentReadingNote?.id == n.id;

                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedNote = n),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark ? AsterTheme.primary(context).withValues(alpha: 0.15) : AsterTheme.primary(context).withValues(alpha: 0.12))
                                              : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                          border: Border.all(
                                            color: isSelected
                                                ? AsterTheme.primary(context)
                                                : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
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
                                                      n.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected
                                                            ? AsterTheme.primary(context)
                                                            : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  GestureDetector(
                                                    key: Key('note_list_mark_${n.id}'),
                                                    onTap: () => _toggleNoteReviewMark(notebook, n),
                                                    child: Icon(
                                                      n.needsReview
                                                          ? Icons.bookmark_rounded
                                                          : Icons.bookmark_add_outlined,
                                                      size: 18,
                                                      color: n.needsReview
                                                          ? AsterConstants.ambar
                                                          : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n.content.isNotEmpty ? n.content.replaceAll(RegExp(r'[#*`\n]'), ' ').trim() : 'Sem texto.',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.manrope(
                                                fontSize: 11.5,
                                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                              ),
                                            ),
                                            if (n.tags.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: n.tags.take(3).map((t) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? AsterConstants.surfaceInsetDark
                                                          : AsterConstants.surfaceInset,
                                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                    ),
                                                    child: Text(
                                                      '#$t',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (n.allImageUrls.isNotEmpty) ...[
                                                  const Icon(Icons.image_rounded, size: 12, color: AsterConstants.menta),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${n.allImageUrls.length}',
                                                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterConstants.menta),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (n.generalLinks.isNotEmpty) ...[
                                                  Icon(Icons.link_rounded, size: 12, color: AsterTheme.primary(context)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${n.generalLinks.length}',
                                                    style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                const Spacer(),
                                                Text(
                                                  DateFormat('dd/MM').format(n.updatedAt),
                                                  style: GoogleFonts.manrope(fontSize: 10, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                                ),
                                              ],
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

                // Coluna Direita: Leitor e Renderizador Completo da Anotação
                Expanded(
                  child: currentReadingNote == null
                      ? Center(
                          child: Text(
                            'Selecione uma anotação à esquerda para visualizar.',
                            style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                          ),
                        )
                      : _buildNoteReaderView(currentReadingNote, isDark),
                ),
              ],
            ),
    );
  }

  // ----------------------------------------------------
  // 3. LEITOR & RENDERIZADOR DA ANOTAÇÃO (TEXTO, LINKS E IMAGENS)
  // ----------------------------------------------------
  Widget _buildNoteReaderView(StudyNote note, bool isDark) {
    final images = note.allImageUrls;
    final generalLinks = note.generalLinks;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 24, 36, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de Título da Anotação e Ações
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Atualizado em ${DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_BR').format(note.updatedAt)}',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        if (note.tags.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Wrap(
                            spacing: 6,
                            children: note.tags.map((t) {
                              return GestureDetector(
                                onTap: () => setState(() => _selectedTagFilter = t),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    ),
                                    child: Text(
                                      '#$t',
                                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('note_toggle_review_button'),
                icon: Icon(
                  note.needsReview ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  size: 16,
                  color: note.needsReview ? AsterConstants.ambar : AsterTheme.primary(context),
                ),
                label: Text(note.needsReview ? 'Marcada p/ revisar' : 'Marcar p/ revisar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: note.needsReview ? AsterConstants.ambar : null,
                  side: BorderSide(
                    color: note.needsReview
                        ? AsterConstants.ambar.withValues(alpha: 0.6)
                        : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                  ),
                ),
                onPressed: _selectedNotebook == null
                    ? null
                    : () => _toggleNoteReviewMark(_selectedNotebook!, note),
              ),
              if ((note.shouldReview() || widget.groupScope != null) && _selectedNotebook != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: const Key('note_complete_review_button'),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(widget.groupScope != null ? 'Concluir Leitura' : 'Concluir Revisão'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AsterConstants.menta,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _completeNoteReview(_selectedNotebook!, note),
                ),
              ],
              if (widget.groupScope == null || widget.groupScope!.canEdit) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  onPressed: () => _openNoteEditorModal(note: note),
                ),
              ],
              if (widget.groupScope == null || widget.groupScope!.canRemove) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AsterConstants.coral),
                  tooltip: 'Excluir anotação',
                  onPressed: () => _confirmDeleteNote(note),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ─── RENDERIZAÇÃO DAS IMAGENS DO LINK (REQUISITO FUNDAMENTAL) ───
          if (images.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                border: Border.all(
                  color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                ),
                boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AsterConstants.menta.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_rounded, size: 18, color: AsterConstants.menta),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Imagens Anexadas ao Estudo (${images.length})',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Galeria de imagens renderizadas a partir dos links
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: images.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                    itemBuilder: (imgCtx, iIdx) {
                      final imgUrl = images[iIdx];
                      // Encontra legenda correspondente caso exista nos links
                      final matchingLink = note.links.where((l) => l.url == imgUrl).firstOrNull;
                      final caption = matchingLink?.title.isNotEmpty == true && matchingLink!.title != imgUrl
                          ? matchingLink.title
                          : null;

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(
                            color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Imagem Renderizada
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 480),
                              child: Image.network(
                                imgUrl,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 180,
                                    alignment: Alignment.center,
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: AsterTheme.primary(context),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        const Icon(Icons.broken_image_rounded, size: 36, color: AsterConstants.coral),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Não foi possível carregar a imagem da URL:\n$imgUrl',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.coral),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Barra de legenda e ação para abrir imagem em nova aba
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      caption ?? imgUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                    label: const Text('Abrir Imagem'),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    onPressed: () => _launchExternalUrl(imgUrl),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],

          // ─── CONTEÚDO FORMATADO (MARKDOWN & TEXTO) ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
              border: Border.all(
                color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
              ),
              boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
            ),
            child: note.content.trim().isEmpty
                ? Text(
                    'Esta anotação ainda não possui texto explicativo. Clique em "Editar" para adicionar.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  )
                : MarkdownBody(
                    data: note.content,
                    selectable: true,
                    syntaxHighlighter: AsterCodeSyntaxHighlighter(isDark: isDark),
                    onTapLink: (text, href, title) {
                      if (href != null) _launchExternalUrl(href);
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: GoogleFonts.manrope(
                        fontSize: 14.5,
                        height: 1.65,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                      h1: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                      h2: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                      h3: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                      strong: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                      code: GoogleFonts.jetBrainsMono(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AsterTheme.primary(context),
                        backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.12),
                      ),
                      codeblockPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      codeblockDecoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: AsterTheme.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: AsterTheme.primary(context),
                            width: 4,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      listBullet: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AsterTheme.primary(context),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 22),

          // ─── LINKS DE REFERÊNCIA & DOCUMENTAÇÃO ───
          if (generalLinks.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                border: Border.all(
                  color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                ),
                boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AsterTheme.primary(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.link_rounded, size: 18, color: AsterTheme.primary(context)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Links & Referências Úteis (${generalLinks.length})',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...generalLinks.map((link) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(
                          color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.language_rounded, size: 18, color: AsterTheme.primary(context)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  link.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  link.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: AsterTheme.primary(context),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('Visitar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AsterTheme.primary(context),
                              foregroundColor: AsterTheme.onPrimary(context),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _launchExternalUrl(link.url),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Syntax Highlighter para renderização refinada e autêntica de blocos de código em anotações Markdown
class AsterCodeSyntaxHighlighter extends SyntaxHighlighter {
  final bool isDark;
  AsterCodeSyntaxHighlighter({required this.isDark});

  @override
  TextSpan format(String source) {
    final lines = source.split('\n');
    final spans = <TextSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      final isLast = (i == lines.length - 1);
      final lineBreak = isLast ? '' : '\n';

      if (trimmed.startsWith('#') || trimmed.startsWith('//') || trimmed.startsWith(';') || trimmed.startsWith('--')) {
        // Linha de comentário (bash '#', comentários em código, etc.)
        spans.add(
          TextSpan(
            text: '$line$lineBreak',
            style: GoogleFonts.jetBrainsMono(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        );
      } else {
        // Linha de comando ou código com destaque de sintaxe
        final words = line.split(' ');
        final lineSpans = <TextSpan>[];

        for (var w = 0; w < words.length; w++) {
          final word = words[w];
          final space = (w == words.length - 1) ? '' : ' ';

          Color wordColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
          FontWeight weight = FontWeight.w400;

          if (w == 0 && (word.startsWith(RegExp(r'[a-zA-Z]')))) {
            // Comando inicial (ex: aws, docker, git, npm, flutter)
            wordColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
            weight = FontWeight.w700;
          } else if (word.startsWith('-')) {
            // Flags e opções (ex: --filters, -it, --name)
            wordColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
            weight = FontWeight.w500;
          } else if (word.startsWith('"') || word.startsWith("'")) {
            // Strings e argumentos literais
            wordColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
            weight = FontWeight.w400;
          } else if (word == '=' || word == '|' || word == '&&' || word == '||') {
            wordColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777);
            weight = FontWeight.w700;
          }

          lineSpans.add(
            TextSpan(
              text: '$word$space',
              style: GoogleFonts.jetBrainsMono(
                color: wordColor,
                fontSize: 13,
                fontWeight: weight,
                height: 1.55,
              ),
            ),
          );
        }

        lineSpans.add(
          TextSpan(
            text: lineBreak,
            style: GoogleFonts.jetBrainsMono(fontSize: 13, height: 1.55),
          ),
        );

        spans.add(TextSpan(children: lineSpans));
      }
    }

    return TextSpan(children: spans);
  }
}
