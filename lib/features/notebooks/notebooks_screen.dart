import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants.dart';
import '../../core/supabase_service.dart';
import 'models/notebook_model.dart';

class NotebooksScreen extends StatefulWidget {
  const NotebooksScreen({super.key});

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  List<StudyNotebook> _notebooks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedSubjectFilter = 'Todos';

  // Caderno atualmente aberto (null = lista geral de cadernos)
  StudyNotebook? _selectedNotebook;
  // Anotação atualmente selecionada para leitura no caderno
  StudyNote? _selectedNote;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotebooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotebooks() async {
    setState(() => _isLoading = true);
    final data = await SupabaseService.getNotebooks();
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
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AsterConstants.lavanda;
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
                      Row(
                        children: palette.map((colorItem) {
                          final isSelected = selectedColor == colorItem['hex'];
                          final colorVal = _parseColor(colorItem['hex']!);
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedColor = colorItem['hex']!),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
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
                        }).toList(),
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

                                    await SupabaseService.saveNotebook(newNb);

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
                await SupabaseService.deleteNotebook(notebook.id);
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
    bool isSaving = false;

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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      Text(
                                        'Dica: use ![legenda](url) para imagens inline',
                                        style: GoogleFonts.manrope(fontSize: 10, color: AsterConstants.lavanda),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: TextField(
                                      controller: contentCtrl,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: InputDecoration(
                                        hintText: 'Escreva suas notas de estudo aqui...\n\nVocê pode usar títulos (# Título), tópicos (* item), blocos de código (```codigo```) ou colar links.',
                                        fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                        filled: true,
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
                                              ChoiceChip(
                                                label: const Text('Imagem 🖼️'),
                                                selected: isImageToggle,
                                                onSelected: (val) => setModalState(() => isImageToggle = true),
                                              ),
                                              const SizedBox(width: 6),
                                              ChoiceChip(
                                                label: const Text('Link Web 🔗'),
                                                selected: !isImageToggle,
                                                onSelected: (val) => setModalState(() => isImageToggle = false),
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
                                                backgroundColor: AsterConstants.lavanda,
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
                                                        color: link.isImage ? AsterConstants.menta : AsterConstants.lavanda,
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
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                              backgroundColor: AsterConstants.lavanda,
                              foregroundColor: Colors.white,
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
                                      createdAt: note?.createdAt ?? DateTime.now(),
                                    );

                                    await SupabaseService.saveNote(notebook.id, updatedNote);

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
                await SupabaseService.deleteNote(notebook.id, note.id);
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
      return const Center(child: CircularProgressIndicator(color: AsterConstants.lavanda));
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
          nb.notes.any((n) => n.title.toLowerCase().contains(query) || n.content.toLowerCase().contains(query));

      final matchesSubject = _selectedSubjectFilter == 'Todos' || nb.subject == _selectedSubjectFilter;
      return matchesQuery && matchesSubject;
    }).toList();

    int totalNotes = 0;
    int totalLinks = 0;
    int totalImages = 0;
    for (final nb in _notebooks) {
      totalNotes += nb.noteCount;
      totalLinks += nb.totalLinksCount;
      totalImages += nb.totalImagesCount;
    }

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cadernos de Estudo 📚',
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
                              color: AsterConstants.lavanda.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Text(
                              '${_notebooks.length} Cadernos',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AsterConstants.lavanda,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Organize seus resumos conceituais, salve links de referência e visualize imagens anexadas para memorização ativa.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Novo Caderno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AsterConstants.lavanda,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                  ),
                  onPressed: () => _openNotebookModal(),
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
                      color: AsterConstants.lavanda,
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
                      title: 'Links de Estudo',
                      value: '$totalLinks',
                      icon: Icons.link_rounded,
                      color: AsterConstants.ambar,
                      isDark: isDark,
                    ),
                    _buildMetricCard(
                      title: 'Imagens Anexadas',
                      value: '$totalImages',
                      icon: Icons.image_rounded,
                      color: AsterConstants.coral,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),

            // Barra de Busca e Filtros por Disciplina
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar cadernos, anotações ou termos-chave...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Chips de Disciplina
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subjects.map((sub) {
                  final isSelected = _selectedSubjectFilter == sub;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(sub),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedSubjectFilter = sub),
                      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                      selectedColor: AsterConstants.lavanda.withValues(alpha: 0.2),
                      checkmarkColor: AsterConstants.lavanda,
                      labelStyle: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AsterConstants.lavanda : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        side: BorderSide(
                          color: isSelected ? AsterConstants.lavanda : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                        style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.lavanda, foregroundColor: Colors.white),
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
                                const Spacer(),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz_rounded, size: 20, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium)),
                                  onSelected: (val) {
                                    if (val == 'edit') _openNotebookModal(notebook: nb);
                                    if (val == 'delete') _confirmDeleteNotebook(nb);
                                  },
                                  itemBuilder: (popCtx) => [
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

                            // Estatísticas (Anotações, Links, Imagens)
                            Row(
                              children: [
                                _buildBadge(Icons.note_alt_outlined, '${nb.noteCount} notas', isDark),
                                const SizedBox(width: 10),
                                _buildBadge(Icons.link_rounded, '${nb.totalLinksCount} links', isDark),
                                const SizedBox(width: 10),
                                _buildBadge(Icons.image_outlined, '${nb.totalImagesCount} imagens', isDark),
                              ],
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
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedNotebook = nb;
                                    _selectedNote = nb.notes.isNotEmpty ? nb.notes.first : null;
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

  // ----------------------------------------------------
  // 2. VISÃO INTERNA DO CADERNO (ANOTAÇÕES, LINKS & IMAGENS)
  // ----------------------------------------------------
  Widget _buildNotebookDetailView(bool isDark) {
    final notebook = _selectedNotebook!;
    final nbColor = _parseColor(notebook.colorHex);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar à lista de cadernos',
          onPressed: () {
            setState(() {
              _selectedNotebook = null;
              _selectedNote = null;
            });
          },
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
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
            ),
            onPressed: () => _openNoteEditorModal(),
          ),
          const SizedBox(width: 16),
        ],
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
              children: [
                // Coluna Esquerda: Lista de Anotações do Caderno
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
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: notebook.notes.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final n = notebook.notes[idx];
                        final isSelected = _selectedNote?.id == n.id;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedNote = n),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AsterConstants.lavanda.withValues(alpha: 0.15) : AsterConstants.lavanda.withValues(alpha: 0.12))
                                  : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              border: Border.all(
                                color: isSelected
                                    ? AsterConstants.lavanda
                                    : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AsterConstants.lavanda
                                        : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                  ),
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
                                      const Icon(Icons.link_rounded, size: 12, color: AsterConstants.lavanda),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${n.generalLinks.length}',
                                        style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterConstants.lavanda),
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
                ),

                // Coluna Direita: Leitor e Renderizador Completo da Anotação
                Expanded(
                  child: _selectedNote == null
                      ? Center(
                          child: Text(
                            'Selecione uma anotação à esquerda para visualizar.',
                            style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                          ),
                        )
                      : _buildNoteReaderView(_selectedNote!, isDark),
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
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: Text(
                                  '#$t',
                                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterConstants.lavanda),
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
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
                onPressed: () => _openNoteEditorModal(note: note),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AsterConstants.coral),
                tooltip: 'Excluir anotação',
                onPressed: () => _confirmDeleteNote(note),
              ),
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
                                      color: AsterConstants.lavanda,
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
                      code: GoogleFonts.firaCode(
                        fontSize: 12.5,
                        backgroundColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(
                          color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                        ),
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
                          color: AsterConstants.lavanda.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.link_rounded, size: 18, color: AsterConstants.lavanda),
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
                          const Icon(Icons.language_rounded, size: 18, color: AsterConstants.lavanda),
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
                                    color: AsterConstants.lavanda,
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
                              backgroundColor: AsterConstants.lavanda,
                              foregroundColor: Colors.white,
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
