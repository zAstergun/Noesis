import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/audio_service.dart';
import '../../core/constants.dart';
import '../../core/gemini_service.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import 'models/flashcard_model.dart';
import 'utils/deck_file_importer.dart';

enum _DeckStatusFilter { all, toReview, completed }

class FlashcardsScreen extends StatefulWidget {
  static final ValueNotifier<FlashcardDeck?> externalDeckStarter = ValueNotifier<FlashcardDeck?>(null);

  static void startDeck(FlashcardDeck deck) {
    externalDeckStarter.value = deck;
  }

  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => FlashcardsScreenState();
}

class FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  @visibleForTesting
  void openImportDeckReviewDialogForTesting(DeckFileContent fileContent, {List<Flashcard>? initialCards}) {
    _openImportDeckReviewDialog(fileContent, initialCards: initialCards);
  }

  @visibleForTesting
  void openSplitExistingDeckDialogForTesting(FlashcardDeck deck) {
    _openSplitExistingDeckDialog(deck);
  }

  @visibleForTesting
  static Future<String?> Function()? audioPickerOverrideForTesting;

  Future<String?> _pickAudioFileHelper() async {
    if (audioPickerOverrideForTesting != null) {
      return await audioPickerOverrideForTesting!();
    }
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Selecionar arquivo de áudio MP3',
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'weba'],
      );
      if (files.isEmpty) return null;
      final file = files.first;
      List<int>? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        bytes = null;
      }
      if (bytes == null || bytes.isEmpty) return null;

      if (bytes.length > 15 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O arquivo de áudio deve ter no máximo 15MB.')),
          );
        }
        return null;
      }

      final ext = (file.name.contains('.') ? file.name.split('.').last : 'mp3').toLowerCase();
      final mime = ext == 'wav'
          ? 'audio/wav'
          : (ext == 'ogg' ? 'audio/ogg' : (ext == 'm4a' || ext == 'aac' ? 'audio/aac' : 'audio/mp3'));
      final b64 = base64Encode(bytes);
      return 'data:$mime;base64,$b64';
    } catch (e) {
      debugPrint('Erro ao selecionar arquivo de áudio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao anexar arquivo de áudio: $e')),
        );
      }
      return null;
    }
  }

  List<FlashcardDeck> _decks = [];
  bool _isLoading = true;
  String _selectedSubjectFilter = 'Todos';
  _DeckStatusFilter _statusFilter = _DeckStatusFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Active study session state
  FlashcardDeck? _activeStudyDeck;
  List<Flashcard> _studyQueue = [];
  final Set<String> _requeuedCardIds = {};
  bool _studyPendingOnly = true;
  int _activeCardIndex = 0;
  bool _isCardFlipped = false;
  late final AnimationController _flipAnimationController;
  late final Animation<double> _flipAnimation;

  // Study session statistics
  final Stopwatch _studyStopwatch = Stopwatch();
  int _sessionEasyCount = 0;
  int _sessionGoodCount = 0;
  int _sessionHardCount = 0;
  bool _isSessionFinished = false;

  @override
  void initState() {
    super.initState();
    _flipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipAnimationController, curve: Curves.easeInOutCubic),
    );

    _loadDecks();
    FlashcardsScreen.externalDeckStarter.addListener(_onExternalDeckStarted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FlashcardsScreen.externalDeckStarter.value != null) {
        _onExternalDeckStarted();
      }
    });
  }

  @override
  void dispose() {
    FlashcardsScreen.externalDeckStarter.removeListener(_onExternalDeckStarted);
    _searchController.dispose();
    _flipAnimationController.dispose();
    super.dispose();
  }

  void _onExternalDeckStarted() {
    final deck = FlashcardsScreen.externalDeckStarter.value;
    if (deck != null && mounted) {
      _startStudySession(deck);
      FlashcardsScreen.externalDeckStarter.value = null;
    }
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    final decks = await SupabaseService.getFlashcardDecks();
    if (mounted) {
      setState(() {
        _decks = decks;
        _isLoading = false;
      });
    }
  }

  void _startStudySession(FlashcardDeck deck, {bool reviewAll = false}) {
    if (deck.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este baralho ainda não tem cartões. Adicione cartões antes de estudar!')),
      );
      return;
    }

    final pendingCards = deck.cardsToReview();
    final usePendingOnly = !reviewAll && pendingCards.isNotEmpty;
    final queue = usePendingOnly
        ? List<Flashcard>.from(pendingCards)
        : List<Flashcard>.from(deck.cards);

    setState(() {
      _activeStudyDeck = deck;
      _studyQueue = queue;
      _requeuedCardIds.clear();
      _studyPendingOnly = usePendingOnly;
      _activeCardIndex = 0;
      _isCardFlipped = false;
      _sessionEasyCount = 0;
      _sessionGoodCount = 0;
      _sessionHardCount = 0;
      _isSessionFinished = false;
      _studyStopwatch.reset();
      _studyStopwatch.start();
    });
    _flipAnimationController.reset();
  }

  void _toggleCardFlip() {
    if (_flipAnimationController.isAnimating) return;
    HapticFeedback.lightImpact();
    if (_isCardFlipped) {
      _flipAnimationController.reverse();
    } else {
      _flipAnimationController.forward();
    }
    setState(() {
      _isCardFlipped = !_isCardFlipped;
    });
  }

  void _rateCurrentCard(String difficulty) async {
    if (_activeStudyDeck == null || _studyQueue.isEmpty) return;
    HapticFeedback.mediumImpact();

    final currentCard = _studyQueue[_activeCardIndex];
    final now = DateTime.now();

    if (difficulty == 'easy') _sessionEasyCount++;
    if (difficulty == 'good') _sessionGoodCount++;
    if (difficulty == 'hard') _sessionHardCount++;

    await SupabaseService.updateCardReview(
      deckId: _activeStudyDeck!.id,
      cardId: currentCard.id,
      difficulty: difficulty,
    );

    final updatedCard = currentCard.copyWith(
      difficulty: difficulty,
      reviewCount: currentCard.reviewCount + 1,
      lastReviewed: now,
    );

    final updatedDeckCards = List<Flashcard>.from(_activeStudyDeck!.cards);
    final deckCardIdx = updatedDeckCards.indexWhere((c) => c.id == currentCard.id);
    if (deckCardIdx != -1) {
      updatedDeckCards[deckCardIdx] = updatedCard;
    }
    final updatedDeck = _activeStudyDeck!.copyWith(cards: updatedDeckCards);

    // Atualiza estado do baralho na lista em memória imediatamente
    final deckIdx = _decks.indexWhere((d) => d.id == updatedDeck.id);
    if (deckIdx != -1) {
      _decks[deckIdx] = updatedDeck;
    }

    // Cartões marcados como 'hard' ainda não foram aprendidos: retornam para o fim da fila
    // enquanto cartões 'good' e 'easy' não voltam na sessão atual.
    final nextQueue = List<Flashcard>.from(_studyQueue);
    nextQueue[_activeCardIndex] = updatedCard;
    if (difficulty == 'hard') {
      nextQueue.add(updatedCard);
      _requeuedCardIds.add(updatedCard.id);
      if (mounted && _studyQueue.length - _activeCardIndex == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Cartão difícil mantido na fila para reforço ativo.'),
          ),
        );
      }
    } else {
      _requeuedCardIds.remove(updatedCard.id);
    }

    if (_activeCardIndex + 1 < nextQueue.length) {
      AudioService().stopAudio();
      if (_isCardFlipped) {
        _flipAnimationController.reverse();
      }
      setState(() {
        _activeStudyDeck = updatedDeck;
        _studyQueue = nextQueue;
        _activeCardIndex++;
        _isCardFlipped = false;
      });
    } else {
      AudioService().stopAudio();
      _studyStopwatch.stop();
      setState(() {
        _activeStudyDeck = updatedDeck;
        _studyQueue = nextQueue;
        _isSessionFinished = true;
      });
    }
  }

  void _exitStudySession() {
    AudioService().stopAudio();
    _studyStopwatch.stop();
    setState(() {
      _activeStudyDeck = null;
      _studyQueue = [];
      _requeuedCardIds.clear();
    });
    _loadDecks();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AsterTheme.primary(context);
    }
  }

  List<String> get _uniqueSubjects {
    final set = <String>{'Todos'};
    for (final deck in _decks) {
      if (deck.subject.isNotEmpty) set.add(deck.subject);
    }
    return set.toList();
  }

  List<FlashcardDeck> get _filteredDecks {
    return _decks.where((deck) {
      final matchesSubject = _selectedSubjectFilter == 'Todos' || deck.subject == _selectedSubjectFilter;
      final matchesStatus = switch (_statusFilter) {
        _DeckStatusFilter.all => true,
        _DeckStatusFilter.toReview => deck.pendingReviewCount() > 0,
        _DeckStatusFilter.completed => deck.isCompleted(),
      };
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          deck.title.toLowerCase().contains(query) ||
          deck.description.toLowerCase().contains(query) ||
          deck.subject.toLowerCase().contains(query) ||
          deck.cards.any((c) => c.front.toLowerCase().contains(query) || c.back.toLowerCase().contains(query));
      return matchesSubject && matchesStatus && matchesSearch;
    }).toList();
  }

  // ----------------------------------------------------
  // UPLOAD E IMPORTAÇÃO DE ARQUIVOS (ANKI, TXT, MD)
  // ----------------------------------------------------
  Future<DeckFileContent?> _pickFileHelper() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Selecionar baralho Anki (.apkg), Markdown ou Texto',
        type: FileType.custom,
        allowedExtensions: ['apkg', 'colpkg', 'anki', 'txt', 'md', 'csv', 'tsv', 'json', 'zip'],
      );
      if (files.isNotEmpty) {
        final file = files.first;
        List<int>? bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {
          bytes = null;
        }
        if (bytes != null && bytes.isNotEmpty) {
          return DeckFileImporter.parse(file.name, bytes);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ler arquivo: $e')),
        );
      }
    }
    return null;
  }

  Future<void> _pickAndImportFile() async {
    final parsed = await _pickFileHelper();
    if (parsed == null || !mounted) return;

    if (parsed.parsedCards.isNotEmpty) {
      _openImportDeckReviewDialog(parsed);
    } else {
      _openGenerateCardsFromFileDialog(parsed);
    }
  }

  // ----------------------------------------------------
  // MODAL: REVISAR E EDITAR CARTÕES DO ARQUIVO IMPORTADO
  // ----------------------------------------------------
  void _openImportDeckReviewDialog(DeckFileContent fileContent, {List<Flashcard>? initialCards}) {
    final List<Flashcard> editableCards = List.from(initialCards ?? fileContent.parsedCards);
    final titleCtrl = TextEditingController(
      text: fileContent.suggestedTitle.isNotEmpty ? fileContent.suggestedTitle : 'Novo Baralho',
    );
    final subjectCtrl = TextEditingController(
      text: fileContent.suggestedSubject.isNotEmpty ? fileContent.suggestedSubject : 'Geral',
    );
    final searchCtrl = TextEditingController();
    String cardSearchQuery = '';
    int currentPage = 0;
    const int pageSize = 20;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final query = cardSearchQuery.toLowerCase().trim();

            final List<int> matchingIndices = [];
            for (int i = 0; i < editableCards.length; i++) {
              if (query.isEmpty ||
                  editableCards[i].front.toLowerCase().contains(query) ||
                  editableCards[i].back.toLowerCase().contains(query)) {
                matchingIndices.add(i);
              }
            }

            final totalPages = (matchingIndices.length / pageSize).ceil().clamp(1, 9999);
            if (currentPage >= totalPages) currentPage = totalPages - 1;
            if (currentPage < 0) currentPage = 0;

            final pageIndices = matchingIndices.skip(currentPage * pageSize).take(pageSize).toList();

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 900,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.style_rounded, color: AsterTheme.primary(context), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Revisar e Importar Flashcards 📚',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  '${fileContent.fileName} · ${editableCards.length} cartões encontrados (edite como preferir)',
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
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (editableCards.length > 20) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AsterTheme.primary(context).withValues(alpha: 0.14),
                                AsterConstants.menta.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            border: Border.all(
                              color: AsterTheme.primary(context).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AsterTheme.primary(context).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.auto_awesome_rounded, color: AsterTheme.primary(context), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Baralho Volumoso Detectado (${editableCards.length} cartões)',
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AsterConstants.ambar.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                          ),
                                          child: Text(
                                            '> 20 cartões',
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AsterConstants.ambar,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'A IA pode analisar o conteúdo e separar automaticamente esses cartões em baralhos temáticos menores para um aprendizado com melhor retenção.',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11.5,
                                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        final title = titleCtrl.text.trim().isNotEmpty
                                            ? titleCtrl.text.trim()
                                            : fileContent.suggestedTitle;
                                        final subject = subjectCtrl.text.trim().isNotEmpty
                                            ? subjectCtrl.text.trim()
                                            : fileContent.suggestedSubject;
                                        Navigator.pop(dialogCtx);
                                        _triggerAiDeckSplit(
                                          cards: editableCards,
                                          baseTitle: title,
                                          baseSubject: subject,
                                          fileContent: fileContent,
                                        );
                                      },
                                icon: const Icon(Icons.splitscreen_rounded, size: 16),
                                label: const Text('Separar com IA ✨'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsterTheme.primary(context),
                                  foregroundColor: AsterTheme.onPrimary(context),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Baralho Title & Subject Config
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TÍTULO DO BARALHO',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: titleCtrl,
                                  enabled: !isSaving,
                                  decoration: const InputDecoration(
                                    hintText: 'Nome do baralho...',
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
                                  'MATÉRIA / DISCIPLINA',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: subjectCtrl,
                                  enabled: !isSaving,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: Idiomas, Segurança...',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Toolbar: Search + Add Card
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              onChanged: (val) {
                                setDialogState(() {
                                  cardSearchQuery = val;
                                  currentPage = 0;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Pesquisar cartões (${matchingIndices.length}/${editableCards.length})...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                suffixIcon: cardSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 16),
                                        onPressed: () {
                                          searchCtrl.clear();
                                          setDialogState(() {
                                            cardSearchQuery = '';
                                            currentPage = 0;
                                          });
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Novo Cartão'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                            ),
                            onPressed: isSaving
                                ? null
                                : () {
                                    setDialogState(() {
                                      editableCards.add(Flashcard(
                                        id: 'card-${DateTime.now().millisecondsSinceEpoch}',
                                        front: '',
                                        back: '',
                                        tags: [subjectCtrl.text.trim()],
                                      ));
                                      cardSearchQuery = '';
                                      searchCtrl.clear();
                                      currentPage = (editableCards.length / pageSize).ceil() - 1;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Scrollable Cards List
                      Expanded(
                        child: matchingIndices.isEmpty
                            ? Center(
                                child: Text(
                                  editableCards.isEmpty
                                      ? 'Nenhum cartão neste baralho ainda. Adicione um novo cartão acima!'
                                      : 'Nenhum cartão corresponde à pesquisa "$cardSearchQuery".',
                                  style: GoogleFonts.manrope(
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: pageIndices.length,
                                itemBuilder: (listCtx, i) {
                                  final masterIdx = pageIndices[i];
                                  final card = editableCards[masterIdx];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
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
                                        // Card Header
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                              ),
                                              child: Text(
                                                '#${masterIdx + 1}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: AsterTheme.primary(context),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (card.tags.isNotEmpty) ...[
                                              Text(
                                                card.tags.join(', '),
                                                style: GoogleFonts.manrope(
                                                  fontSize: 10.5,
                                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (card.hasAudio) ...[
                                              ValueListenableBuilder<String?>(
                                                valueListenable: AudioService().currentlyPlayingUrl,
                                                builder: (ctx, playingUrl, _) {
                                                  final isPlaying = playingUrl == card.audioUrl;
                                                  return GestureDetector(
                                                    onTap: () {
                                                      if (card.audioUrl != null) {
                                                        AudioService().playAudio(card.audioUrl!);
                                                      }
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: isPlaying ? AsterTheme.primary(context) : AsterTheme.primary(context).withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                                                            size: 13,
                                                            color: isPlaying ? Colors.white : AsterTheme.primary(context),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            isPlaying ? 'Tocando' : 'Áudio Anexado',
                                                            style: GoogleFonts.manrope(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: isPlaying ? Colors.white : AsterTheme.primary(context),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.upload_file_rounded, size: 14),
                                                tooltip: 'Trocar arquivo de áudio MP3',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: isSaving
                                                    ? null
                                                    : () async {
                                                        final audio = await _pickAudioFileHelper();
                                                        if (audio != null) {
                                                          setDialogState(() {
                                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(audioUrl: audio);
                                                          });
                                                          AudioService().playAudio(audio);
                                                        }
                                                      },
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 14),
                                                tooltip: 'Remover áudio',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: isSaving
                                                    ? null
                                                    : () {
                                                        setDialogState(() {
                                                          editableCards[masterIdx] = editableCards[masterIdx].copyWith(clearAudio: true);
                                                        });
                                                      },
                                              ),
                                            ] else ...[
                                              GestureDetector(
                                                onTap: isSaving
                                                    ? null
                                                    : () async {
                                                        final audio = await _pickAudioFileHelper();
                                                        if (audio != null) {
                                                          setDialogState(() {
                                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(audioUrl: audio);
                                                          });
                                                          AudioService().playAudio(audio);
                                                        }
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.audio_file_rounded, size: 12, color: AsterTheme.primary(context)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Anexar MP3',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AsterTheme.primary(context),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: isSaving
                                                    ? null
                                                    : () async {
                                                        final text = card.front.isNotEmpty ? card.front : card.back;
                                                        if (text.isEmpty) return;
                                                        final audio = await AudioService.generateAiSpeech(text: text);
                                                        if (audio != null) {
                                                          setDialogState(() {
                                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(audioUrl: audio);
                                                          });
                                                          AudioService().playAudio(audio);
                                                        }
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AsterConstants.menta.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.auto_awesome_rounded, size: 12, color: AsterConstants.menta),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Gerar Áudio IA',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AsterConstants.menta,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                              tooltip: 'Excluir cartão',
                                              onPressed: isSaving
                                                  ? null
                                                  : () {
                                                      setDialogState(() {
                                                        editableCards.removeAt(masterIdx);
                                                      });
                                                    },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Frente / Pergunta
                                        Text(
                                          'FRENTE / PERGUNTA',
                                          style: GoogleFonts.manrope(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          key: ValueKey('front-${card.id}-$masterIdx'),
                                          initialValue: card.front,
                                          enabled: !isSaving,
                                          maxLines: null,
                                          minLines: 1,
                                          decoration: InputDecoration(
                                            hintText: 'Escreva a pergunta ou conceito...',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                            filled: true,
                                          ),
                                          onChanged: (val) {
                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(front: val);
                                          },
                                        ),
                                        const SizedBox(height: 10),

                                        // Verso / Resposta
                                        Text(
                                          'VERSO / RESPOSTA',
                                          style: GoogleFonts.manrope(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          key: ValueKey('back-${card.id}-$masterIdx'),
                                          initialValue: card.back,
                                          enabled: !isSaving,
                                          maxLines: null,
                                          minLines: 2,
                                          decoration: InputDecoration(
                                            hintText: 'Escreva a resposta e explicação...',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                            filled: true,
                                          ),
                                          onChanged: (val) {
                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(back: val);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Pagination Controls & Save Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (totalPages > 1)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  tooltip: 'Página anterior',
                                  onPressed: currentPage > 0
                                      ? () => setDialogState(() => currentPage--)
                                      : null,
                                ),
                                Text(
                                  'Pág ${currentPage + 1} de $totalPages',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  tooltip: 'Próxima página',
                                  onPressed: currentPage < totalPages - 1
                                      ? () => setDialogState(() => currentPage++)
                                      : null,
                                ),
                              ],
                            )
                          else
                            Text(
                              '${editableCards.length} cartões prontos',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (editableCards.length > 20) ...[
                                OutlinedButton.icon(
                                  icon: Icon(Icons.splitscreen_rounded, size: 16, color: AsterTheme.primary(context)),
                                  label: Text(
                                    'Separar com IA ✨',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AsterTheme.primary(context),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AsterTheme.primary(context)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                  ),
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          final title = titleCtrl.text.trim().isNotEmpty
                                              ? titleCtrl.text.trim()
                                              : fileContent.suggestedTitle;
                                          final subject = subjectCtrl.text.trim().isNotEmpty
                                              ? subjectCtrl.text.trim()
                                              : fileContent.suggestedSubject;
                                          Navigator.pop(dialogCtx);
                                          _triggerAiDeckSplit(
                                            cards: editableCards,
                                            baseTitle: title,
                                            baseSubject: subject,
                                            fileContent: fileContent,
                                          );
                                        },
                                ),
                                const SizedBox(width: 8),
                              ],
                              SoftClayPillButton(
                                text: 'Salvar Baralho (${editableCards.length}) 🚀',
                                icon: Icons.check_circle_rounded,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final title = titleCtrl.text.trim().isNotEmpty
                                            ? titleCtrl.text.trim()
                                            : fileContent.suggestedTitle;
                                        final subject = subjectCtrl.text.trim().isNotEmpty
                                            ? subjectCtrl.text.trim()
                                            : fileContent.suggestedSubject;

                                        final validCards = editableCards
                                            .where((c) => c.front.trim().isNotEmpty || c.back.trim().isNotEmpty)
                                            .toList();

                                        if (validCards.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Adicione pelo menos 1 cartão válido com pergunta ou resposta.')),
                                          );
                                          return;
                                        }

                                        // Prompt de separação inteligente quando o baralho for grande (> 20 cartões)
                                        if (validCards.length > 20) {
                                          final shouldSplit = await showDialog<bool>(
                                            context: dialogCtx,
                                            builder: (askCtx) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium)),
                                              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                              title: Row(
                                                children: [
                                                  Icon(Icons.auto_awesome_rounded, color: AsterTheme.primary(context), size: 22),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Separar Baralho com IA?',
                                                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                              content: Text(
                                                'Este baralho contém ${validCards.length} cartões (acima de 20). Estudar baralhos menores e temáticos proporciona muito mais retenção cognitiva.\n\nDeseja que a IA faça a separação automática em baralhos temáticos agora?',
                                                style: GoogleFonts.manrope(fontSize: 13),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(askCtx, false),
                                                  child: Text('Salvar Como Baralho Único', style: GoogleFonts.manrope()),
                                                ),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AsterTheme.primary(context),
                                                    foregroundColor: AsterTheme.onPrimary(context),
                                                  ),
                                                  onPressed: () => Navigator.pop(askCtx, true),
                                                  icon: const Icon(Icons.splitscreen_rounded, size: 16),
                                                  label: const Text('Dividir com IA ✨'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (shouldSplit == true) {
                                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                            _triggerAiDeckSplit(
                                              cards: validCards,
                                              baseTitle: title,
                                              baseSubject: subject,
                                              fileContent: fileContent,
                                            );
                                            return;
                                          }
                                        }

                                        setDialogState(() => isSaving = true);
                                        try {
                                          final deck = FlashcardDeck(
                                            id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
                                            title: title,
                                            subject: subject,
                                            description: 'Importado de ${fileContent.fileName} (${validCards.length} cartões).',
                                            cards: validCards,
                                            createdAt: DateTime.now(),
                                          );

                                          await SupabaseService.saveFlashcardDeck(deck);
                                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                          if (!mounted) return;
                                          await _loadDecks();
                                          if (!mounted) return;

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Baralho "$title" salvo com ${validCards.length} cartões! 🎉')),
                                          );
                                          _startStudySession(deck);
                                        } catch (e) {
                                          if (dialogCtx.mounted) setDialogState(() => isSaving = false);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Erro ao salvar baralho: $e')),
                                          );
                                        }
                                      },
                              ),
                            ],
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
  // DISPARAR SEPARAÇÃO DE FLASHCARDS VOLUMOSOS COM IA
  // ----------------------------------------------------
  Future<void> _triggerAiDeckSplit({
    required List<Flashcard> cards,
    required String baseTitle,
    required String baseSubject,
    DeckFileContent? fileContent,
    String? existingDeckId,
    bool deleteOriginalOnSave = false,
    int targetCardsPerDeck = 30,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadCtx) {
        final isDark = Theme.of(loadCtx).brightness == Brightness.dark;
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
              boxShadow: AsterConstants.claySubtleShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation(AsterTheme.primary(context)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Organizando Baralhos com IA 🧠✨',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Analisando o conteúdo dos ${cards.length} cartões e agrupando em blocos de ~$targetCardsPerDeck...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final proposedDecks = await GeminiService.splitFlashcardsIntoDecks(
        cards: cards,
        baseTitle: baseTitle,
        baseSubject: baseSubject,
        targetCardsPerDeck: targetCardsPerDeck,
      );

      if (mounted) {
        Navigator.pop(context); // Fechar loading
        _openAiDeckSplitReviewDialog(
          proposedDecks: proposedDecks,
          originalCards: cards,
          baseTitle: baseTitle,
          baseSubject: baseSubject,
          fileContent: fileContent,
          existingDeckId: existingDeckId,
          deleteOriginalOnSave: deleteOriginalOnSave,
          initialTargetCardsPerDeck: targetCardsPerDeck,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fechar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao separar baralhos com IA: $e')),
        );
      }
    }
  }

  // ----------------------------------------------------
  // TELA DE CONCLUSÃO: REVISAR E EDITAR DIVISÃO DOS BARALHOS COM IA
  // ----------------------------------------------------
  void _openAiDeckSplitReviewDialog({
    required List<FlashcardDeck> proposedDecks,
    required List<Flashcard> originalCards,
    required String baseTitle,
    required String baseSubject,
    DeckFileContent? fileContent,
    String? existingDeckId,
    bool deleteOriginalOnSave = false,
    int initialTargetCardsPerDeck = 30,
  }) {
    final List<_AiSplitDeckEditor> editors = proposedDecks.map((d) {
      return _AiSplitDeckEditor(
        id: d.id,
        titleCtrl: TextEditingController(text: d.title),
        subjectCtrl: TextEditingController(text: d.subject),
        descriptionCtrl: TextEditingController(text: d.description),
        colorHex: d.colorHex,
        cards: List<Flashcard>.from(d.cards),
        isExpanded: false,
      );
    }).toList();

    int currentTargetCards = initialTargetCardsPerDeck;
    bool isReorganizing = false;
    bool isSavingAll = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final totalCards = editors.fold<int>(0, (sum, e) => sum + e.cards.length);

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 960,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.auto_awesome_motion_rounded, color: AsterTheme.primary(context), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Divisão de Baralhos por IA 🗂️✨',
                                      style: GoogleFonts.manrope(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AsterConstants.menta.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                      ),
                                      child: Text(
                                        '${editors.length} Baralhos Gerados',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AsterConstants.menta,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'A IA organizou $totalCards cartões em baralhos temáticos específicos. Ajuste a nomeação e detalhes de cada um antes de concluir:',
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
                            onPressed: isSavingAll ? null : () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Barra de Informações & Métricas Rápidas
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(
                            color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AsterConstants.ambar),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Edite os títulos dos baralhos livremente. Você também pode expandir para ver os cartões e transferir entre baralhos.',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Novo Baralho'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                              ),
                              onPressed: isSavingAll
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        editors.add(_AiSplitDeckEditor(
                                          id: 'deck-custom-${DateTime.now().millisecondsSinceEpoch}',
                                          titleCtrl: TextEditingController(text: '$baseTitle · Parte ${editors.length + 1}'),
                                          subjectCtrl: TextEditingController(text: baseSubject),
                                          descriptionCtrl: TextEditingController(text: 'Novo sub-baralho personalizado.'),
                                          colorHex: '4A6BF5',
                                          cards: [],
                                          isExpanded: true,
                                        ));
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Seletor de Tamanho por Baralho
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(
                            color: AsterTheme.primary(context).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: AsterTheme.primary(context)),
                            const SizedBox(width: 8),
                            Text(
                              'Tamanho por baralho:',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Wrap(
                              spacing: 6,
                              children: [20, 30, 40, 50, 100].map((size) {
                                final isSelected = currentTargetCards == size;
                                return ChoiceChip(
                                  label: Text(
                                    size == 30 ? '$size cards ✨' : '$size cards',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? AsterTheme.onPrimary(context) : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AsterTheme.primary(context),
                                  backgroundColor: isDark ? AsterConstants.surfaceCardDark : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (isReorganizing || isSavingAll)
                                      ? null
                                      : (selected) async {
                                          if (selected && currentTargetCards != size) {
                                            setDialogState(() {
                                              currentTargetCards = size;
                                              isReorganizing = true;
                                            });
                                            try {
                                              final newDecks = await GeminiService.splitFlashcardsIntoDecks(
                                                cards: originalCards,
                                                baseTitle: baseTitle,
                                                baseSubject: baseSubject,
                                                targetCardsPerDeck: size,
                                              );
                                              setDialogState(() {
                                                editors.clear();
                                                editors.addAll(newDecks.map((d) => _AiSplitDeckEditor(
                                                  id: d.id,
                                                  titleCtrl: TextEditingController(text: d.title),
                                                  subjectCtrl: TextEditingController(text: d.subject),
                                                  descriptionCtrl: TextEditingController(text: d.description),
                                                  colorHex: d.colorHex,
                                                  cards: List<Flashcard>.from(d.cards),
                                                  isExpanded: false,
                                                )));
                                                isReorganizing = false;
                                              });
                                            } catch (_) {
                                              setDialogState(() => isReorganizing = false);
                                            }
                                          }
                                        },
                                );
                              }).toList(),
                            ),
                            const Spacer(),
                            if (isReorganizing) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AsterTheme.primary(context)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Reorganizando...',
                                style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.primary(context), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Lista Scrollável dos Baralhos Separados
                      Expanded(
                        child: ListView.builder(
                          itemCount: editors.length,
                          itemBuilder: (listCtx, i) {
                            final editor = editors[i];
                            final deckColor = _parseColor(editor.colorHex);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
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
                                  // Top Colored Header Row
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: deckColor.withValues(alpha: 0.12),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(AsterConstants.radiusMedium),
                                        topRight: Radius.circular(AsterConstants.radiusMedium),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: deckColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Baralho #${i + 1}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? AsterConstants.surfaceCardDark : Colors.white,
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                          ),
                                          child: Text(
                                            '${editor.cards.length} cartões',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: deckColor,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          icon: Icon(
                                            editor.isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                            size: 18,
                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                          ),
                                          label: Text(
                                            editor.isExpanded ? 'Recolher' : 'Ver cartões (${editor.cards.length})',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                            ),
                                          ),
                                          onPressed: () {
                                            setDialogState(() {
                                              editor.isExpanded = !editor.isExpanded;
                                            });
                                          },
                                        ),
                                        if (editors.length > 1) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                            tooltip: 'Remover este baralho e mover cartões para o anterior',
                                            onPressed: isSavingAll
                                                ? null
                                                : () {
                                                    setDialogState(() {
                                                      final removedCards = editor.cards;
                                                      editors.removeAt(i);
                                                      if (removedCards.isNotEmpty && editors.isNotEmpty) {
                                                        final target = i > 0 ? i - 1 : 0;
                                                        editors[target].cards.addAll(removedCards);
                                                      }
                                                    });
                                                  },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Edit inputs
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'TÍTULO DO BARALHO (EDITÁVEL)',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: 0.6,
                                                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(Icons.edit_rounded, size: 12, color: AsterTheme.primary(context)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextFormField(
                                                    controller: editor.titleCtrl,
                                                    enabled: !isSavingAll,
                                                    decoration: InputDecoration(
                                                      hintText: 'Nome do baralho gerado pela IA...',
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                                      filled: true,
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
                                                    'MATÉRIA / DISCIPLINA',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.6,
                                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextFormField(
                                                    controller: editor.subjectCtrl,
                                                    enabled: !isSavingAll,
                                                    decoration: InputDecoration(
                                                      hintText: 'Ex: Criptografia...',
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                                      filled: true,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Expandable Cards Section
                                        if (editor.isExpanded) ...[
                                          const SizedBox(height: 14),
                                          Divider(color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Cartões neste baralho (${editor.cards.length}):',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                ),
                                              ),
                                              Text(
                                                'Você pode transferir cartões para outro baralho',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 10.5,
                                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (editor.cards.isEmpty)
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isDark ? AsterConstants.surfaceCardDark : Colors.white,
                                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                              ),
                                              child: Text(
                                                'Nenhum cartão neste baralho. Mova cartões de outros baralhos para cá.',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                ),
                                              ),
                                            )
                                          else
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: editor.cards.length,
                                              itemBuilder: (cardCtx, cIdx) {
                                                final c = editor.cards[cIdx];
                                                final frontCut = c.front.trim().replaceAll('\n', ' ');
                                                final backCut = c.back.trim().replaceAll('\n', ' ');

                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? AsterConstants.surfaceCardDark : Colors.white,
                                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                                    border: Border.all(
                                                      color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        '#${cIdx + 1}',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: AsterTheme.primary(context),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              frontCut.isNotEmpty ? frontCut : '(Frente vazia)',
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.manrope(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                              ),
                                                            ),
                                                            Text(
                                                              backCut.isNotEmpty ? backCut : '(Verso vazio)',
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
                                                      if (editors.length > 1) ...[
                                                        PopupMenuButton<int>(
                                                          tooltip: 'Mover para outro baralho',
                                                          icon: const Icon(Icons.drive_file_move_outline, size: 16),
                                                          onSelected: (targetIdx) {
                                                            setDialogState(() {
                                                              final cardToMove = editor.cards.removeAt(cIdx);
                                                              editors[targetIdx].cards.add(cardToMove);
                                                            });
                                                          },
                                                          itemBuilder: (mCtx) => [
                                                            for (int t = 0; t < editors.length; t++)
                                                              if (t != i)
                                                                PopupMenuItem(
                                                                  value: t,
                                                                  child: Text(
                                                                    'Mover para Baralho #${t + 1} (${editors[t].titleCtrl.text.isNotEmpty ? editors[t].titleCtrl.text : 'Sem título'})',
                                                                    style: GoogleFonts.manrope(fontSize: 12),
                                                                  ),
                                                                ),
                                                          ],
                                                        ),
                                                      ],
                                                      IconButton(
                                                        icon: const Icon(Icons.close_rounded, size: 16, color: AsterConstants.coral),
                                                        tooltip: 'Remover cartão',
                                                        onPressed: isSavingAll
                                                            ? null
                                                            : () {
                                                                setDialogState(() {
                                                                  editor.cards.removeAt(cIdx);
                                                                });
                                                              },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Footer Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: Text(fileContent != null ? 'Voltar ao Baralho Único' : 'Cancelar'),
                            onPressed: isSavingAll
                                ? null
                                : () {
                                    Navigator.pop(dialogCtx);
                                    if (fileContent != null) {
                                      _openImportDeckReviewDialog(fileContent, initialCards: originalCards);
                                    }
                                  },
                          ),
                          SoftClayPillButton(
                            text: 'Salvar Todos os Baralhos (${editors.where((e) => e.cards.isNotEmpty).length}) 🚀',
                            icon: Icons.check_circle_rounded,
                            onPressed: isSavingAll
                                ? null
                                : () async {
                                    final validDecks = editors.where((e) => e.cards.isNotEmpty).toList();
                                    if (validDecks.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Nenhum baralho possui cartões válidos para salvar.')),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSavingAll = true);
                                    try {
                                      final List<FlashcardDeck> savedDecks = [];
                                      final now = DateTime.now();

                                      for (int i = 0; i < validDecks.length; i++) {
                                        final e = validDecks[i];
                                        final title = e.titleCtrl.text.trim().isNotEmpty
                                            ? e.titleCtrl.text.trim()
                                            : '$baseTitle · Parte ${i + 1}';
                                        final subject = e.subjectCtrl.text.trim().isNotEmpty
                                            ? e.subjectCtrl.text.trim()
                                            : baseSubject;

                                        final sourceLabel = fileContent != null ? 'importado de ${fileContent.fileName}' : 'dividido de $baseTitle';
                                        final deck = FlashcardDeck(
                                          id: 'deck-${now.millisecondsSinceEpoch}-$i',
                                          title: title,
                                          subject: subject,
                                          description: 'Baralho temático $sourceLabel (${e.cards.length} cartões).',
                                          cards: e.cards,
                                          createdAt: now.add(Duration(seconds: i)),
                                          colorHex: e.colorHex,
                                        );

                                        await SupabaseService.saveFlashcardDeck(deck);
                                        savedDecks.add(deck);
                                      }

                                      // Se veio de um baralho existente e foi configurado para substituir o original
                                      if (existingDeckId != null && deleteOriginalOnSave) {
                                        await SupabaseService.deleteFlashcardDeck(existingDeckId);
                                      }

                                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                      if (!mounted) return;
                                      await _loadDecks();
                                      if (!mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 ${savedDecks.length} baralhos temáticos criados com sucesso! Bons estudos!'),
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );

                                      if (savedDecks.isNotEmpty) {
                                        _startStudySession(savedDecks.first);
                                      }
                                    } catch (e) {
                                      if (dialogCtx.mounted) setDialogState(() => isSavingAll = false);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erro ao salvar baralhos: $e')),
                                      );
                                    }
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
  // MODAL: GERAR CARTÕES DE ARQUIVO TEXTO COM IA
  // ----------------------------------------------------
  void _openGenerateCardsFromFileDialog(DeckFileContent fileContent) {
    final titleCtrl = TextEditingController(text: fileContent.suggestedTitle);
    final subjectCtrl = TextEditingController(text: fileContent.suggestedSubject);
    int count = 8;
    String difficulty = 'Médio / Prático';
    bool isGenerating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
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
                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.auto_awesome_rounded, color: AsterTheme.primary(context), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gerar Flashcards do Arquivo ✨',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  '${fileContent.fileName} (${fileContent.formattedSize})',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isGenerating)
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AsterTheme.primary(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'Detectamos notas/resumos no arquivo. A IA lerá o texto para formular os cartões técnicos, e você poderá revisar e editar cada um antes de salvar.',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Tema / Título
                      Text(
                        'TÍTULO DO BARALHO',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        enabled: !isGenerating,
                        decoration: const InputDecoration(hintText: 'Nome do baralho...'),
                      ),
                      const SizedBox(height: 14),

                      // Matéria e Quantidade
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MATÉRIA / DISCIPLINA',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: subjectCtrl,
                                  enabled: !isGenerating,
                                  decoration: const InputDecoration(hintText: 'Ex: Idiomas, Segurança...'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUANTIDADE',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: count,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 5, child: Text('5 cartões')),
                                        DropdownMenuItem(value: 8, child: Text('8 cartões')),
                                        DropdownMenuItem(value: 12, child: Text('12 cartões')),
                                        DropdownMenuItem(value: 16, child: Text('16 cartões')),
                                      ],
                                      onChanged: isGenerating
                                          ? null
                                          : (val) {
                                              if (val != null) setDialogState(() => count = val);
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (isGenerating)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: AsterTheme.primary(context)),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'A IA está formulando seus flashcards...',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AsterTheme.primary(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SoftClayPillButton(
                              text: 'Gerar e Revisar ✨',
                              icon: Icons.auto_awesome_rounded,
                              onPressed: () async {
                                final topic = titleCtrl.text.trim().isNotEmpty
                                    ? titleCtrl.text.trim()
                                    : fileContent.suggestedTitle;
                                final subject = subjectCtrl.text.trim().isNotEmpty
                                    ? subjectCtrl.text.trim()
                                    : fileContent.suggestedSubject;

                                setDialogState(() => isGenerating = true);
                                try {
                                  final cardsData = await GeminiService.generateFlashcards(
                                    subject: subject,
                                    topic: topic,
                                    count: count,
                                    difficulty: difficulty,
                                    contextNotes: fileContent.rawText,
                                  );

                                  final generatedCards = cardsData.asMap().entries.map((e) {
                                    final val = e.value;
                                    return Flashcard(
                                      id: 'fc-${DateTime.now().millisecondsSinceEpoch}-${e.key}',
                                      front: val['front']?.toString() ?? 'Pergunta',
                                      back: val['back']?.toString() ?? 'Resposta',
                                      tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject],
                                    );
                                  }).toList();

                                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                  if (!mounted) return;

                                  // Abre o modal de revisão e edição com os cartões gerados pela IA!
                                  _openImportDeckReviewDialog(fileContent, initialCards: generatedCards);
                                } catch (e) {
                                  if (dialogCtx.mounted) setDialogState(() => isGenerating = false);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro ao gerar flashcards: $e')),
                                  );
                                }
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
  // MODAL: GERAR FLASHCARDS COM IA
  // ----------------------------------------------------
  void _openGenerateAiFlashcardsDialog() {
    final topicCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(text: 'Tecnologia');
    final notesCtrl = TextEditingController();
    int count = 6;
    String difficulty = 'Médio / Prático';
    bool isGenerating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: SingleChildScrollView(
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
                                color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              ),
                              child: Icon(Icons.auto_awesome_rounded, color: AsterTheme.primary(context), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gerar Flashcards com IA ✨',
                                    style: GoogleFonts.manrope(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Crie baralhos focados em temas específicos com Active Recall',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isGenerating)
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tema Específico
                        Text(
                          'TEMA ESPECÍFICO *',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: topicCtrl,
                          enabled: !isGenerating,
                          decoration: InputDecoration(
                            hintText: 'Ex: Criptografia Assimétrica, OWASP Injection, K8s Pod Lifecycle...',
                            hintStyle: GoogleFonts.manrope(fontSize: 13, color: isDark ? AsterConstants.textFaintDark : AsterConstants.textFaint),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Matéria e Quantidade
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MATÉRIA / DISCIPLINA',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: subjectCtrl,
                                    enabled: !isGenerating,
                                    decoration: const InputDecoration(
                                      hintText: 'Ex: Segurança, Cloud, Algoritmos',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QUANTIDADE',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: count,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                        items: const [
                                          DropdownMenuItem(value: 5, child: Text('5 cartões')),
                                          DropdownMenuItem(value: 8, child: Text('8 cartões')),
                                          DropdownMenuItem(value: 12, child: Text('12 cartões')),
                                          DropdownMenuItem(value: 16, child: Text('16 cartões')),
                                        ],
                                        onChanged: isGenerating ? null : (val) {
                                          if (val != null) setDialogState(() => count = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Nível de Dificuldade
                        Text(
                          'NÍVEL DE PROFUNDIDADE',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Iniciante / Conceitos', 'Médio / Prático', 'Avançado / Técnico'].map((level) {
                            final isSel = difficulty == level;
                            return ChoiceChip(
                              label: Text(level),
                              selected: isSel,
                              selectedColor: AsterTheme.primary(context),
                              labelStyle: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? Colors.white : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                              ),
                              onSelected: isGenerating ? null : (selected) {
                                if (selected) setDialogState(() => difficulty = level);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Anotações opcionais / Contexto
                        Text(
                          'MATERIAL DE APOIO / ANOTAÇÕES (OPCIONAL)',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesCtrl,
                          enabled: !isGenerating,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Cole um resumo, trecho de documentação ou tópicos essenciais para guiar a IA...',
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (isGenerating)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AsterTheme.primary(context)),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'A IA está gerando seus flashcards técnicos...',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AsterTheme.primary(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SoftClayPillButton(
                                text: 'Gerar Flashcards ✨',
                                icon: Icons.auto_awesome_rounded,
                                onPressed: () async {
                                  final topic = topicCtrl.text.trim();
                                  final subject = subjectCtrl.text.trim().isEmpty ? 'Geral' : subjectCtrl.text.trim();
                                  if (topic.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Por favor, informe o tema específico para gerar os flashcards.')),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isGenerating = true);
                                  try {
                                    final cardsData = await GeminiService.generateFlashcards(
                                      subject: subject,
                                      topic: topic,
                                      count: count,
                                      difficulty: difficulty,
                                      contextNotes: notesCtrl.text.trim(),
                                    );

                                    final flashcards = cardsData.asMap().entries.map((e) {
                                      final val = e.value;
                                      return Flashcard(
                                        id: 'fc-${DateTime.now().millisecondsSinceEpoch}-${e.key}',
                                        front: val['front']?.toString() ?? 'Pergunta',
                                        back: val['back']?.toString() ?? 'Resposta',
                                        tags: val['tags'] is List ? List<String>.from(val['tags']) : [subject, topic],
                                      );
                                    }).toList();

                                    final deck = FlashcardDeck(
                                      id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
                                      title: topic,
                                      subject: subject,
                                      description: 'Baralho de retenção ativa sobre $topic ($difficulty).',
                                      cards: flashcards,
                                      createdAt: DateTime.now(),
                                    );

                                    await SupabaseService.saveFlashcardDeck(deck);
                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    if (!mounted) return;
                                    await _loadDecks();
                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Baralho "${deck.title}" criado com ${deck.cards.length} cartões! 🎉')),
                                    );

                                    // Launch study session immediately
                                    _startStudySession(deck);
                                  } catch (e) {
                                    if (dialogCtx.mounted) {
                                      setDialogState(() => isGenerating = false);
                                    }
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erro ao gerar flashcards: $e')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
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
  // MODAL: CRIAR BARALHO MANUALMENTE
  // ----------------------------------------------------
  void _openCreateManualDeckDialog() {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController(text: 'Tecnologia');
    final descCtrl = TextEditingController();
    final List<Map<String, dynamic>> cardsControllers = [
      {'front': TextEditingController(), 'back': TextEditingController(), 'audioUrl': null},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AsterConstants.menta.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: const Icon(Icons.style_rounded, color: AsterConstants.menta, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Criar Novo Baralho',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  'Adicione perguntas e respostas personalizadas para o seu estudo',
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

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: titleCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Título do Baralho *',
                                        hintText: 'Ex: Resumo de Redes & Protocolos',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: subjectCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Matéria *',
                                        hintText: 'Ex: Redes',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: descCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Descrição (opcional)',
                                  hintText: 'Ex: Principais tópicos para a prova de sexta',
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'CARTÕES (${cardsControllers.length})',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Adicionar Cartão'),
                                    onPressed: () {
                                      setDialogState(() {
                                        cardsControllers.add({
                                          'front': TextEditingController(),
                                          'back': TextEditingController(),
                                          'audioUrl': null,
                                        });
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              ...cardsControllers.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final ctrls = entry.value;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
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
                                      Row(
                                        children: [
                                          Text(
                                            'Cartão #${idx + 1}',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AsterTheme.primary(context),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (ctrls['audioUrl'] != null) ...[
                                            ValueListenableBuilder<String?>(
                                              valueListenable: AudioService().currentlyPlayingUrl,
                                              builder: (ctx, playingUrl, _) {
                                                final isPlaying = playingUrl == ctrls['audioUrl'];
                                                return GestureDetector(
                                                  onTap: () {
                                                    AudioService().playAudio(ctrls['audioUrl'] as String);
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isPlaying ? AsterTheme.primary(context) : AsterTheme.primary(context).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 12, color: isPlaying ? Colors.white : AsterTheme.primary(context)),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          isPlaying ? 'Tocando' : 'Áudio Anexado',
                                                          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: isPlaying ? Colors.white : AsterTheme.primary(context)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.upload_file_rounded, size: 14),
                                              tooltip: 'Trocar MP3',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () async {
                                                final audio = await _pickAudioFileHelper();
                                                if (audio != null) {
                                                  setDialogState(() {
                                                    ctrls['audioUrl'] = audio;
                                                  });
                                                  AudioService().playAudio(audio);
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, size: 14),
                                              tooltip: 'Remover áudio',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                setDialogState(() {
                                                  ctrls['audioUrl'] = null;
                                                });
                                              },
                                            ),
                                          ] else ...[
                                            GestureDetector(
                                              onTap: () async {
                                                final audio = await _pickAudioFileHelper();
                                                if (audio != null) {
                                                  setDialogState(() {
                                                    ctrls['audioUrl'] = audio;
                                                  });
                                                  AudioService().playAudio(audio);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.audio_file_rounded, size: 12, color: AsterTheme.primary(context)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Anexar MP3',
                                                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () async {
                                                final f = (ctrls['front'] as TextEditingController).text.trim();
                                                final b = (ctrls['back'] as TextEditingController).text.trim();
                                                final text = f.isNotEmpty ? f : b;
                                                if (text.isEmpty) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Digite o conteúdo da frente ou verso para gerar o áudio.')),
                                                  );
                                                  return;
                                                }
                                                final audio = await AudioService.generateAiSpeech(text: text);
                                                if (audio != null) {
                                                  setDialogState(() {
                                                    ctrls['audioUrl'] = audio;
                                                  });
                                                  AudioService().playAudio(audio);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AsterConstants.menta.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.auto_awesome_rounded, size: 12, color: AsterConstants.menta),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Gerar Áudio IA',
                                                      style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: AsterConstants.menta),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (cardsControllers.length > 1)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                setDialogState(() {
                                                  cardsControllers.removeAt(idx);
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: ctrls['front'] as TextEditingController,
                                        decoration: const InputDecoration(
                                          hintText: 'Frente: Pergunta, termo ou conceito...',
                                          filled: false,
                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: ctrls['back'] as TextEditingController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          hintText: 'Verso: Resposta, explicação ou regra mnemônica...',
                                          filled: false,
                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text('Cancelar', style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted)),
                          ),
                          const SizedBox(width: 12),
                          SoftClayPillButton(
                            text: 'Salvar Baralho',
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              final subject = subjectCtrl.text.trim().isEmpty ? 'Geral' : subjectCtrl.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor, informe um título para o baralho.')),
                                );
                                return;
                              }

                              final List<Flashcard> cards = [];
                              for (int i = 0; i < cardsControllers.length; i++) {
                                final f = (cardsControllers[i]['front'] as TextEditingController).text.trim();
                                final b = (cardsControllers[i]['back'] as TextEditingController).text.trim();
                                final audio = cardsControllers[i]['audioUrl'] as String?;
                                if (f.isNotEmpty || b.isNotEmpty) {
                                  cards.add(Flashcard(
                                    id: 'fc-${DateTime.now().millisecondsSinceEpoch}-$i',
                                    front: f.isNotEmpty ? f : 'Pergunta #${i + 1}',
                                    back: b.isNotEmpty ? b : 'Resposta #${i + 1}',
                                    audioUrl: audio,
                                    tags: [subject],
                                  ));
                                }
                              }

                              if (cards.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Adicione pelo menos um cartão com frente e verso.')),
                                );
                                return;
                              }

                              final deck = FlashcardDeck(
                                id: 'deck-${DateTime.now().millisecondsSinceEpoch}',
                                title: title,
                                subject: subject,
                                description: descCtrl.text.trim(),
                                cards: cards,
                                createdAt: DateTime.now(),
                              );

                              await SupabaseService.saveFlashcardDeck(deck);
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                              if (!mounted) return;
                              await _loadDecks();
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Baralho "$title" criado com sucesso!')),
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
  // MODAL: ADICIONAR CARTÃO A BARALHO EXISTENTE
  // ----------------------------------------------------
  void _openAddCardDialog(FlashcardDeck deck) {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    String? newAudioUrl;
    bool isGeneratingAudio = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Novo Cartão em "${deck.title}"',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: frontCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Frente (Pergunta ou Conceito)',
                          hintText: 'Ex: O que é o princípio do menor privilégio?',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: backCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Verso (Resposta ou Explicação)',
                          hintText: 'Ex: Conceder apenas os acessos estritamente necessários para executar uma tarefa.',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Barra de Áudio Opcional
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          border: Border.all(
                            color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              newAudioUrl != null ? Icons.audiotrack_rounded : Icons.mic_none_rounded,
                              size: 18,
                              color: newAudioUrl != null ? AsterTheme.primary(context) : AsterConstants.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                newAudioUrl != null ? 'Áudio anexado ao cartão' : 'Adicionar áudio / narração (opcional)',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: newAudioUrl != null ? FontWeight.w700 : FontWeight.w500,
                                  color: newAudioUrl != null
                                      ? (isDark ? AsterConstants.textLight : AsterConstants.textDark)
                                      : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                ),
                              ),
                            ),
                            if (newAudioUrl != null) ...[
                              ValueListenableBuilder<String?>(
                                valueListenable: AudioService().currentlyPlayingUrl,
                                builder: (_, playingUrl, child) {
                                  final isPlaying = playingUrl == newAudioUrl;
                                  return OutlinedButton.icon(
                                    icon: Icon(isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 14),
                                    label: Text(isPlaying ? 'Pausar' : 'Ouvir'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => AudioService().playAudio(newAudioUrl!),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AsterConstants.coral),
                                tooltip: 'Remover áudio',
                                onPressed: () => setDialogState(() => newAudioUrl = null),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                icon: const Icon(Icons.upload_file_rounded, size: 14),
                                label: const Text('Anexar MP3'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () async {
                                  final audio = await _pickAudioFileHelper();
                                  if (audio != null) {
                                    setDialogState(() => newAudioUrl = audio);
                                    AudioService().playAudio(audio);
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                icon: isGeneratingAudio
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.auto_awesome_rounded, size: 12),
                                label: Text(isGeneratingAudio ? 'Gerando...' : 'Gerar IA ✨'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsterTheme.primary(context),
                                  foregroundColor: AsterTheme.onPrimary(context),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: isGeneratingAudio
                                    ? null
                                    : () async {
                                        final text = frontCtrl.text.trim().isNotEmpty ? frontCtrl.text.trim() : backCtrl.text.trim();
                                        if (text.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Digite a pergunta ou resposta antes de gerar o áudio.')),
                                          );
                                          return;
                                        }
                                        setDialogState(() => isGeneratingAudio = true);
                                        final audio = await AudioService.generateAiSpeech(text: text);
                                        setDialogState(() {
                                          newAudioUrl = audio;
                                          isGeneratingAudio = false;
                                        });
                                        if (audio != null) {
                                          AudioService().playAudio(audio);
                                        }
                                      },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text('Cancelar', style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted)),
                          ),
                          const SizedBox(width: 12),
                          SoftClayPillButton(
                            text: 'Adicionar',
                            onPressed: () async {
                              final f = frontCtrl.text.trim();
                              final b = backCtrl.text.trim();
                              if (f.isEmpty && b.isEmpty) return;

                              final newCard = Flashcard(
                                id: 'fc-${DateTime.now().millisecondsSinceEpoch}',
                                front: f.isNotEmpty ? f : 'Conceito',
                                back: b.isNotEmpty ? b : 'Explicação',
                                tags: [deck.subject],
                                audioUrl: newAudioUrl,
                              );

                              final updatedCards = List<Flashcard>.from(deck.cards)..add(newCard);
                              final updatedDeck = deck.copyWith(cards: updatedCards);
                              await SupabaseService.saveFlashcardDeck(updatedDeck);
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                              if (!mounted) return;
                              await _loadDecks();
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cartão adicionado com sucesso!')),
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
  // MODAL: EDITAR BARALHO E GERENCIAR CARTÕES
  // ----------------------------------------------------
  void _openEditDeckDialog(FlashcardDeck deck) {
    final List<Flashcard> editableCards = List.from(deck.cards);
    final titleCtrl = TextEditingController(text: deck.title);
    final subjectCtrl = TextEditingController(text: deck.subject);
    final descCtrl = TextEditingController(text: deck.description);
    final searchCtrl = TextEditingController();
    String cardSearchQuery = '';
    int currentPage = 0;
    const int pageSize = 20;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final query = cardSearchQuery.toLowerCase().trim();

            final List<int> matchingIndices = [];
            for (int i = 0; i < editableCards.length; i++) {
              if (query.isEmpty ||
                  editableCards[i].front.toLowerCase().contains(query) ||
                  editableCards[i].back.toLowerCase().contains(query)) {
                matchingIndices.add(i);
              }
            }

            final totalPages = (matchingIndices.length / pageSize).ceil().clamp(1, 9999);
            if (currentPage >= totalPages) currentPage = totalPages - 1;
            if (currentPage < 0) currentPage = 0;

            final pageIndices = matchingIndices.skip(currentPage * pageSize).take(pageSize).toList();

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 900,
                  maxHeight: MediaQuery.of(dialogCtx).size.height * 0.90,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.edit_note_rounded, color: AsterTheme.primary(context), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Editar Baralho ✏️',
                                  style: GoogleFonts.manrope(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  '${editableCards.length} cartões · Edite as informações e conteúdo como desejar',
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
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Informações do Baralho (Título, Matéria e Descrição)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TÍTULO DO BARALHO *',
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
                                  enabled: !isSaving,
                                  decoration: InputDecoration(
                                    hintText: 'Nome do baralho...',
                                    fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                  'MATÉRIA / DISCIPLINA',
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
                                  enabled: !isSaving,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: Criptografia, Inglês...',
                                    fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            enabled: !isSaving,
                            decoration: InputDecoration(
                              hintText: 'Descrição sobre os temas deste baralho...',
                              fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Barra de pesquisa e Novo Cartão
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              enabled: !isSaving,
                              decoration: InputDecoration(
                                hintText: 'Pesquisar cartões (${editableCards.length})...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  cardSearchQuery = val;
                                  currentPage = 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Novo Cartão'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              side: BorderSide(color: AsterTheme.primary(context)),
                              foregroundColor: AsterTheme.primary(context),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                            ),
                            onPressed: isSaving
                                ? null
                                : () {
                                    setDialogState(() {
                                      editableCards.insert(
                                        0,
                                        Flashcard(
                                          id: 'fc-manual-${DateTime.now().millisecondsSinceEpoch}',
                                          front: '',
                                          back: '',
                                          tags: [subjectCtrl.text.trim().isNotEmpty ? subjectCtrl.text.trim() : 'Geral'],
                                        ),
                                      );
                                      currentPage = 0;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Lista de Cartões
                      Expanded(
                        child: editableCards.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum cartão neste baralho ainda.\nClique em "+ Novo Cartão" para adicionar!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: pageIndices.length,
                                separatorBuilder: (listCtx, index) => const SizedBox(height: 12),
                                itemBuilder: (listCtx, pIdx) {
                                  final masterIdx = pageIndices[pIdx];
                                  final card = editableCards[masterIdx];

                                  return Container(
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
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                              ),
                                              child: Text(
                                                '#${masterIdx + 1}',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: AsterTheme.primary(context),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Áudio
                                            if (card.audioUrl != null) ...[
                                              ValueListenableBuilder<String?>(
                                                valueListenable: AudioService().currentlyPlayingUrl,
                                                builder: (vCtx, playingUrl, _) {
                                                  final isPlaying = playingUrl == card.audioUrl;
                                                  return GestureDetector(
                                                    onTap: () {
                                                      AudioService().playAudio(card.audioUrl!);
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: isPlaying ? AsterTheme.primary(context) : AsterTheme.primary(context).withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                                                            size: 12,
                                                            color: isPlaying ? Colors.white : AsterTheme.primary(context),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            isPlaying ? 'Tocando' : 'Áudio Anexado',
                                                            style: GoogleFonts.manrope(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: isPlaying ? Colors.white : AsterTheme.primary(context),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.upload_file_rounded, size: 14),
                                                tooltip: 'Trocar arquivo de áudio MP3',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: isSaving
                                                    ? null
                                                    : () async {
                                                        final audio = await _pickAudioFileHelper();
                                                        if (audio != null) {
                                                          setDialogState(() {
                                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(audioUrl: audio);
                                                          });
                                                          AudioService().playAudio(audio);
                                                        }
                                                      },
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 14),
                                                tooltip: 'Remover áudio',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: isSaving
                                                    ? null
                                                    : () {
                                                        setDialogState(() {
                                                          editableCards[masterIdx] = editableCards[masterIdx].copyWith(clearAudio: true);
                                                        });
                                                      },
                                              ),
                                            ] else ...[
                                              GestureDetector(
                                                onTap: isSaving
                                                    ? null
                                                    : () async {
                                                        final audio = await _pickAudioFileHelper();
                                                        if (audio != null) {
                                                          setDialogState(() {
                                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(audioUrl: audio);
                                                          });
                                                          AudioService().playAudio(audio);
                                                        }
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.audio_file_rounded, size: 12, color: AsterTheme.primary(context)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Anexar MP3',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AsterTheme.primary(context),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: isSaving
                                                    ? null
                                                    : () async {
                                                        final text = card.front.isNotEmpty ? card.front : card.back;
                                                        if (text.isEmpty) return;
                                                        final audio = await AudioService.generateAiSpeech(text: text);
                                                        if (audio != null) {
                                                          setDialogState(() {
                                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(audioUrl: audio);
                                                          });
                                                          AudioService().playAudio(audio);
                                                        }
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AsterConstants.menta.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.auto_awesome_rounded, size: 12, color: AsterConstants.menta),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Gerar Áudio IA',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: AsterConstants.menta,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                              tooltip: 'Excluir cartão',
                                              onPressed: isSaving
                                                  ? null
                                                  : () {
                                                      setDialogState(() {
                                                        editableCards.removeAt(masterIdx);
                                                      });
                                                    },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Frente / Pergunta
                                        Text(
                                          'FRENTE / PERGUNTA',
                                          style: GoogleFonts.manrope(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          key: ValueKey('deck-edit-front-${card.id}-$masterIdx'),
                                          initialValue: card.front,
                                          enabled: !isSaving,
                                          maxLines: null,
                                          minLines: 1,
                                          decoration: InputDecoration(
                                            hintText: 'Escreva a pergunta ou conceito...',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                            filled: true,
                                          ),
                                          onChanged: (val) {
                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(front: val);
                                          },
                                        ),
                                        const SizedBox(height: 10),

                                        // Verso / Resposta
                                        Text(
                                          'VERSO / RESPOSTA',
                                          style: GoogleFonts.manrope(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          key: ValueKey('deck-edit-back-${card.id}-$masterIdx'),
                                          initialValue: card.back,
                                          enabled: !isSaving,
                                          maxLines: null,
                                          minLines: 2,
                                          decoration: InputDecoration(
                                            hintText: 'Escreva a resposta e explicação...',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            fillColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                            filled: true,
                                          ),
                                          onChanged: (val) {
                                            editableCards[masterIdx] = editableCards[masterIdx].copyWith(back: val);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Rodapé: Paginação e Salvar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (totalPages > 1)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  tooltip: 'Página anterior',
                                  onPressed: currentPage > 0 ? () => setDialogState(() => currentPage--) : null,
                                ),
                                Text(
                                  'Pág ${currentPage + 1} de $totalPages',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  tooltip: 'Próxima página',
                                  onPressed: currentPage < totalPages - 1 ? () => setDialogState(() => currentPage++) : null,
                                ),
                              ],
                            )
                          else
                            Text(
                              '${editableCards.length} cartões no baralho',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.save_rounded, size: 18),
                                label: Text(isSaving ? 'Salvando...' : 'Salvar Baralho 💾'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsterTheme.primary(context),
                                  foregroundColor: AsterTheme.onPrimary(context),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final newTitle = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : deck.title;
                                        final newSubject = subjectCtrl.text.trim().isNotEmpty ? subjectCtrl.text.trim() : deck.subject;
                                        final newDesc = descCtrl.text.trim();

                                        final validCards = editableCards
                                            .where((c) => c.front.trim().isNotEmpty || c.back.trim().isNotEmpty)
                                            .toList();

                                        if (validCards.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('O baralho precisa ter pelo menos um cartão com conteúdo.')),
                                          );
                                          return;
                                        }

                                        setDialogState(() => isSaving = true);

                                        final updatedDeck = deck.copyWith(
                                          title: newTitle,
                                          subject: newSubject,
                                          description: newDesc,
                                          cards: validCards,
                                        );

                                        await SupabaseService.saveFlashcardDeck(updatedDeck);

                                        if (dialogCtx.mounted) {
                                          Navigator.pop(dialogCtx);
                                        }

                                        if (!mounted) return;
                                        await _loadDecks();
                                        if (!mounted) return;

                                        if (_activeStudyDeck != null && _activeStudyDeck!.id == updatedDeck.id) {
                                          setState(() {
                                            _activeStudyDeck = updatedDeck;
                                          });
                                        }

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Baralho "$newTitle" atualizado com sucesso! 🎉')),
                                        );
                                      },
                              ),
                            ],
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
  // CONFIRMAÇÃO DE EXCLUSÃO DE BARALHO
  // ----------------------------------------------------
  void _confirmDeleteDeck(FlashcardDeck deck) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          title: Text('Excluir Baralho?', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          content: Text('Tem certeza que deseja excluir "${deck.title}" e seus ${deck.cards.length} cartões?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.manrope(color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AsterConstants.coral),
              onPressed: () async {
                await SupabaseService.deleteFlashcardDeck(deck.id);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (!mounted) return;
                await _loadDecks();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Baralho excluído com sucesso.')),
                );
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_activeStudyDeck != null) {
      return _buildStudyView(isDark);
    }

    final filtered = _filteredDecks;
    final totalCards = _decks.fold<int>(0, (sum, d) => sum + d.cardCount);
    final masteredCards = _decks.fold<int>(0, (sum, d) => sum + d.masteredCount);
    final totalPendingCards = _decks.fold<int>(0, (sum, d) => sum + d.pendingReviewCount());
    final toReviewDecksCount = _decks.where((d) => d.pendingReviewCount() > 0).length;
    final completedDecksCount = _decks.where((d) => d.isCompleted()).length;
    final avgRetention = _decks.isEmpty ? 0 : (_decks.fold<double>(0.0, (sum, d) => sum + d.progressPercentage) / _decks.length * 100).toInt();

    return SoftClayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AsterTheme.primary(context)),
                )
              : CustomScrollView(
                  slivers: [
                    // Header e Ações
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const NoesisCollapsedMenuSpacer(width: 82),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            ),
                                            child: Text(
                                              'ACTIVE RECALL ENGINE',
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.0,
                                                color: AsterTheme.primary(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Flashcards Cognitivos',
                                        style: GoogleFonts.manrope(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.8,
                                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Domine conceitos técnicos complexos através de repetição espaçada e recuperação ativa.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                                      label: const Text('Importar Arquivo'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        side: BorderSide(color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                      ),
                                      onPressed: _pickAndImportFile,
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: const Text('Novo Baralho'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        side: BorderSide(color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                      ),
                                      onPressed: _openCreateManualDeckDialog,
                                    ),
                                    SoftClayPillButton(
                                      text: 'Gerar com IA ✨',
                                      icon: Icons.auto_awesome_rounded,
                                      onPressed: _openGenerateAiFlashcardsDialog,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Barra de Métricas Rápidas
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                                border: Border.all(
                                  color: isDark ? AsterConstants.surfaceInsetDark : Colors.white.withValues(alpha: 0.8),
                                ),
                                boxShadow: AsterConstants.clayShadow,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem('Baralhos Ativos', '${_decks.length}', AsterTheme.primary(context), isDark),
                                  _buildDivider(isDark),
                                  _buildStatItem('Total de Cartões', '$totalCards', AsterConstants.menta, isDark),
                                  _buildDivider(isDark),
                                  InkWell(
                                    key: const Key('flashcards_review_queue_stat'),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    onTap: _openReviewQueueDialog,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: _buildStatItem(
                                        'Para Revisar',
                                        '$totalPendingCards',
                                        totalPendingCards > 0 ? AsterConstants.coral : AsterConstants.menta,
                                        isDark,
                                      ),
                                    ),
                                  ),
                                  _buildDivider(isDark),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    onTap: () => setState(() => _statusFilter = _DeckStatusFilter.completed),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: _buildStatItem('Dominados (Fácil)', '$masteredCards', AsterConstants.ambar, isDark),
                                    ),
                                  ),
                                  _buildDivider(isDark),
                                  _buildStatItem('Retenção Média', '$avgRetention%', AsterTheme.primary(context), isDark),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Painel Soft Clay de Busca, Revisão e Filtros
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                                border: Border.all(
                                  color: isDark ? AsterConstants.surfaceInsetDark : Colors.white.withValues(alpha: 0.85),
                                ),
                                boxShadow: AsterConstants.claySubtleShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: (val) => setState(() => _searchQuery = val),
                                          decoration: InputDecoration(
                                            hintText: 'Buscar por título, conceito ou pergunta...',
                                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                            filled: true,
                                            fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                                                      _searchController.clear();
                                                      setState(() => _searchQuery = '');
                                                    },
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        key: const Key('open_review_queue_button'),
                                        onTap: _openReviewQueueDialog,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: totalPendingCards > 0
                                                ? AsterConstants.coral.withValues(alpha: 0.12)
                                                : AsterConstants.menta.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            border: Border.all(
                                              color: (totalPendingCards > 0 ? AsterConstants.coral : AsterConstants.menta)
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                totalPendingCards > 0
                                                    ? Icons.pending_actions_rounded
                                                    : Icons.verified_rounded,
                                                size: 16,
                                                color: totalPendingCards > 0
                                                    ? AsterConstants.coral
                                                    : AsterConstants.menta,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                totalPendingCards > 0
                                                    ? 'O que revisar ($totalPendingCards)'
                                                    : 'Tudo em dia ✓',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: totalPendingCards > 0
                                                      ? AsterConstants.coral
                                                      : AsterConstants.menta,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Filtro por Status de Aprendizado / Domínio
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _buildStatusFilterPill(
                                        key: const Key('filter_status_all'),
                                        label: 'Todos (${_decks.length})',
                                        icon: Icons.layers_rounded,
                                        selected: _statusFilter == _DeckStatusFilter.all,
                                        activeColor: AsterTheme.primary(context),
                                        isDark: isDark,
                                        onTap: () => setState(() => _statusFilter = _DeckStatusFilter.all),
                                      ),
                                      _buildStatusFilterPill(
                                        key: const Key('filter_status_to_review'),
                                        label: 'Para Revisar ($toReviewDecksCount)',
                                        icon: Icons.bolt_rounded,
                                        selected: _statusFilter == _DeckStatusFilter.toReview,
                                        activeColor: AsterConstants.coral,
                                        isDark: isDark,
                                        onTap: () => setState(() => _statusFilter = _DeckStatusFilter.toReview),
                                      ),
                                      _buildStatusFilterPill(
                                        key: const Key('filter_status_completed'),
                                        label: 'Completos / Dominados ($completedDecksCount)',
                                        icon: Icons.check_circle_rounded,
                                        selected: _statusFilter == _DeckStatusFilter.completed,
                                        activeColor: AsterConstants.menta,
                                        isDark: isDark,
                                        onTap: () => setState(() => _statusFilter = _DeckStatusFilter.completed),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Chips Soft Clay de Matéria
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _uniqueSubjects.map((sub) {
                                        final isSel = _selectedSubjectFilter == sub;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                            onTap: () => setState(() => _selectedSubjectFilter = sub),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isSel
                                                    ? AsterTheme.primary(context)
                                                    : AsterTheme.surfaceAlt(context),
                                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                boxShadow: isSel ? AsterTheme.primaryShadow(context) : null,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isSel) ...[
                                                    Icon(Icons.check_rounded, size: 14, color: AsterTheme.onPrimary(context)),
                                                    const SizedBox(width: 5),
                                                  ],
                                                  Text(
                                                    sub,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 12,
                                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                                      color: isSel
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
                          ],
                        ),
                      ),
                    ),

                    // Grid de Baralhos
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.style_outlined, size: 48, color: isDark ? AsterConstants.textFaintDark : AsterConstants.textFaint),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Nenhum baralho encontrado para "$_searchQuery".'
                                      : (_statusFilter == _DeckStatusFilter.completed
                                          ? 'Nenhum baralho completo ou dominado ainda.'
                                          : (_statusFilter == _DeckStatusFilter.toReview
                                              ? 'Nenhum baralho pendente de revisão no momento! 🎉'
                                              : 'Nenhum baralho nesta matéria.')),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SoftClayPillButton(
                                  text: _statusFilter != _DeckStatusFilter.all
                                      ? 'Mostrar Todos os Baralhos'
                                      : 'Gerar com IA ✨',
                                  onPressed: _statusFilter != _DeckStatusFilter.all
                                      ? () => setState(() {
                                            _statusFilter = _DeckStatusFilter.all;
                                            _selectedSubjectFilter = 'Todos';
                                          })
                                      : _openGenerateAiFlashcardsDialog,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 440,
                            mainAxisExtent: 284,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final deck = filtered[index];
                              return _buildDeckCard(deck, isDark);
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color accent, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: accent,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
    );
  }

  Widget _buildStatusFilterPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.16)
              : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.55)
                : Colors.transparent,
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

  void _openReviewQueueDialog({FlashcardDeck? focusDeck}) {
    final now = DateTime.now();
    final decksWithPending = (focusDeck != null ? [focusDeck] : _decks)
        .map((d) => (deck: d, pending: d.cardsToReview(referenceDate: now)))
        .where((entry) => entry.pending.isNotEmpty)
        .toList()
      ..sort((a, b) => b.pending.length.compareTo(a.pending.length));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
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
                          color: AsterConstants.coral.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pending_actions_rounded, size: 20, color: AsterConstants.coral),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              focusDeck != null
                                  ? 'Pendências · ${focusDeck.title}'
                                  : 'Central de Revisão Inteligente',
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                              ),
                            ),
                            Text(
                              'Cartões já aprendidos (Fácil) não entram na fila automática.',
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
                  const SizedBox(height: 16),

                  if (decksWithPending.isEmpty)
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
                            'Tudo em dia! Nenhum cartão pendente para aprender.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: decksWithPending.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) {
                          final item = decksWithPending[idx];
                          final deck = item.deck;
                          final pending = item.pending;
                          final hardCount = pending.where((c) => c.difficulty == 'hard').length;
                          final newCount = pending.where((c) => c.difficulty == 'unreviewed').length;
                          final dueGoodCount = pending.length - hardCount - newCount;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deck.title,
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${pending.length} pendente${pending.length == 1 ? '' : 's'} · '
                                            '$hardCount difíceis · $newCount novos · $dueGoodCount revisão 24h+',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SoftClayPillButton(
                                      text: 'Estudar (${pending.length})',
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        _startStudySession(deck);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...pending.take(3).map((card) {
                                  final reason = card.reviewReason(referenceDate: now);
                                  final badgeColor = card.difficulty == 'hard'
                                      ? AsterConstants.coral
                                      : (card.difficulty == 'unreviewed'
                                          ? AsterTheme.primary(context)
                                          : AsterConstants.ambar);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                          ),
                                          child: Text(
                                            reason,
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            card.front,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
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
  }

  // ----------------------------------------------------
  // MODAL: SEPARAR BARALHO EXISTENTE EM BARALHOS MENORES
  // ----------------------------------------------------
  void _openSplitExistingDeckDialog(FlashcardDeck deck) {
    if (deck.cards.length < 5) return;
    int selectedCardsPerDeck = 30;
    bool replaceOriginal = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final estimatedDecks = (deck.cards.length / selectedCardsPerDeck).ceil().clamp(2, 60);

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                              color: AsterTheme.primary(context).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            ),
                            child: Icon(Icons.splitscreen_rounded, color: AsterTheme.primary(context), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dividir Baralho com IA 🗂️✨',
                                  style: GoogleFonts.manrope(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                  ),
                                ),
                                Text(
                                  '${deck.title} · ${deck.cards.length} cartões',
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

                      Text(
                        'A IA irá analisar o conteúdo e agrupar os cartões em sub-baralhos temáticos menores para um aprendizado com retenção superior.',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'TAMANHO DESEJADO POR BARALHO',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [20, 30, 40, 50].map((size) {
                          final isSelected = selectedCardsPerDeck == size;
                          return ChoiceChip(
                            label: Text(
                              size == 30 ? '$size cartões (Ideal) ✨' : '$size cartões',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AsterTheme.onPrimary(context) : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AsterTheme.primary(context),
                            backgroundColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                            onSelected: (sel) {
                              if (sel) {
                                setDialogState(() => selectedCardsPerDeck = size);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AsterConstants.menta.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: AsterConstants.menta),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Serão gerados cerca de $estimatedDecks baralhos temáticos com nomes automáticos.',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AsterConstants.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      CheckboxListTile(
                        value: replaceOriginal,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: AsterTheme.primary(context),
                        title: Text(
                          'Substituir baralho original pelos novos baralhos menores',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Remove o baralho volumoso original após salvar para evitar duplicatas.',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() => replaceOriginal = val ?? true);
                        },
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.manrope(
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SoftClayPillButton(
                            text: 'Dividir com IA ✨',
                            icon: Icons.splitscreen_rounded,
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              _triggerAiDeckSplit(
                                cards: deck.cards,
                                baseTitle: deck.title,
                                baseSubject: deck.subject,
                                existingDeckId: deck.id,
                                deleteOriginalOnSave: replaceOriginal,
                                targetCardsPerDeck: selectedCardsPerDeck,
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

  Widget _buildDeckCard(FlashcardDeck deck, bool isDark) {
    final color = _parseColor(deck.colorHex);
    final progress = deck.progressPercentage;
    final pendingCount = deck.pendingReviewCount();
    final isCompleted = deck.isCompleted();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        border: Border.all(
          color: isCompleted
              ? AsterConstants.menta.withValues(alpha: 0.45)
              : (isDark ? AsterConstants.surfaceInsetDark : Colors.white.withValues(alpha: 0.8)),
        ),
        boxShadow: AsterConstants.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Subject chip, Pending/Complete badge & Options
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  deck.subject.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (deck.cards.isNotEmpty)
                GestureDetector(
                  onTap: pendingCount > 0 ? () => _openReviewQueueDialog(focusDeck: deck) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isCompleted ? AsterConstants.menta : AsterConstants.coral)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Text(
                      isCompleted ? 'Completo ✓' : '$pendingCount p/ revisar',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isCompleted ? AsterConstants.menta : AsterConstants.coral,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 20, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusMedium)),
                onSelected: (val) {
                  if (val == 'review_all') _startStudySession(deck, reviewAll: true);
                  if (val == 'check_pending') _openReviewQueueDialog(focusDeck: deck);
                  if (val == 'edit') _openEditDeckDialog(deck);
                  if (val == 'add') _openAddCardDialog(deck);
                  if (val == 'split') _openSplitExistingDeckDialog(deck);
                  if (val == 'delete') _confirmDeleteDeck(deck);
                },
                itemBuilder: (ctx) => [
                  if (pendingCount > 0)
                    const PopupMenuItem(
                      value: 'check_pending',
                      child: Row(
                        children: [
                          Icon(Icons.pending_actions_rounded, size: 18, color: AsterConstants.coral),
                          SizedBox(width: 8),
                          Text('Ver O Que Falta Revisar'),
                        ],
                      ),
                    ),
                  if (deck.cards.isNotEmpty)
                    PopupMenuItem(
                      value: 'review_all',
                      child: Row(
                        children: [
                          Icon(Icons.replay_rounded, size: 18, color: AsterTheme.primary(context)),
                          const SizedBox(width: 8),
                          const Text('Revisar Todos os Cartões'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Editar Baralho'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Adicionar Cartão'),
                      ],
                    ),
                  ),
                  if (deck.cards.length >= 10)
                    PopupMenuItem(
                      value: 'split',
                      child: Row(
                        children: [
                          Icon(Icons.splitscreen_rounded, size: 18, color: AsterTheme.primary(context)),
                          const SizedBox(width: 8),
                          const Text('Dividir em Baralhos Menores ✨'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                        SizedBox(width: 8),
                        Text('Excluir Baralho', style: TextStyle(color: AsterConstants.coral)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            deck.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            deck.description.isNotEmpty ? deck.description : 'Sem descrição.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
            ),
          ),
          const Spacer(),

          // Progress Bar & Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${deck.cardCount} cartões · ${deck.masteredCount} dominados',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  if (deck.cards.length > 20) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openSplitExistingDeckDialog(deck),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AsterTheme.primary(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.splitscreen_rounded, size: 10, color: AsterTheme.primary(context)),
                            const SizedBox(width: 3),
                            Text(
                              'Dividir IA ✨',
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
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
              Text(
                '${(progress * 100).toInt()}% dominado',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceInset,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 14),

          // Bottom Action: Estudar Somente Pendentes (ou Revisar Tudo quando completo)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(isCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 18),
              label: Text(
                deck.cards.isEmpty
                    ? 'Sem cartões'
                    : (isCompleted ? 'Revisar Tudo 🔄' : 'Estudar Agora 🚀'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted ? AsterConstants.menta : color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
              ),
              onPressed: deck.cards.isEmpty
                  ? null
                  : () => _startStudySession(deck, reviewAll: isCompleted),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // MODAL: EDITAR CARTÃO DURANTE A SESSÃO DE ESTUDO
  // ----------------------------------------------------
  void _openEditCurrentCardDialog(Flashcard card) {
    if (_activeStudyDeck == null) return;
    final frontCtrl = TextEditingController(text: card.front);
    final backCtrl = TextEditingController(text: card.back);
    String? frontAudioUrl = card.effectiveFrontAudio;
    String? backAudioUrl = card.effectiveBackAudio;
    int audioTab = 0; // 0 = Pergunta (Frente), 1 = Resposta (Verso)
    bool isSaving = false;
    bool isGeneratingAudio = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
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
                                color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                              ),
                              child: Icon(Icons.edit_note_rounded, color: AsterTheme.primary(context), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Editar Flashcard ✍️',
                                    style: GoogleFonts.manrope(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Cartão ${_activeCardIndex + 1} de ${_activeStudyDeck!.cards.length} · ${_activeStudyDeck!.title}',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isSaving)
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Frente (Pergunta ou Conceito)
                        Text(
                          'FRENTE (PERGUNTA OU CONCEITO) *',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: frontCtrl,
                          enabled: !isSaving,
                          maxLines: null,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Escreva a pergunta ou conceito...',
                            fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Verso (Resposta ou Explicação)
                        Text(
                          'VERSO (RESPOSTA OU EXPLICAÇÃO) *',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: backCtrl,
                          enabled: !isSaving,
                          maxLines: null,
                          minLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Escreva a resposta e explicação...',
                            fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Seção de Áudio do Cartão
                        Row(
                          children: [
                            Text(
                              'ÁUDIO DO CARTÃO 🎙️',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => setDialogState(() => audioTab = 0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: audioTab == 0 ? AsterTheme.primary(context) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Pergunta (Frente)',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: audioTab == 0 ? Colors.white : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                            ),
                                          ),
                                          if (frontAudioUrl != null) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.volume_up_rounded, size: 12, color: audioTab == 0 ? Colors.white : AsterConstants.menta),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setDialogState(() => audioTab = 1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: audioTab == 1 ? AsterTheme.primary(context) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Resposta (Verso)',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: audioTab == 1 ? Colors.white : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                            ),
                                          ),
                                          if (backAudioUrl != null) ...[
                                            const SizedBox(width: 4),
                                            Icon(Icons.volume_up_rounded, size: 12, color: audioTab == 1 ? Colors.white : AsterConstants.menta),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (ctx) {
                            final isFrontTab = audioTab == 0;
                            final currentAudio = isFrontTab ? frontAudioUrl : backAudioUrl;
                            final currentText = isFrontTab ? frontCtrl.text.trim() : backCtrl.text.trim();
                            final sideLabel = isFrontTab ? 'Pergunta' : 'Resposta';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                border: Border.all(
                                  color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                ),
                              ),
                              child: currentAudio != null && currentAudio.isNotEmpty
                                  ? Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AsterTheme.primary(context).withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.audiotrack_rounded, color: AsterTheme.primary(context), size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Áudio Anexado',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                ),
                                              ),
                                              Text(
                                                'Disponível para a $sideLabel do cartão',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ValueListenableBuilder<String?>(
                                          valueListenable: AudioService().currentlyPlayingUrl,
                                          builder: (ctx, playingUrl, _) {
                                            final isPlaying = playingUrl == currentAudio;
                                            return OutlinedButton.icon(
                                              onPressed: () {
                                                AudioService().playAudio(currentAudio);
                                              },
                                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 16),
                                              label: Text(isPlaying ? 'Pausar' : 'Ouvir'),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                                          tooltip: 'Trocar arquivo de áudio MP3',
                                          onPressed: (isSaving || isGeneratingAudio)
                                              ? null
                                              : () async {
                                                  final audio = await _pickAudioFileHelper();
                                                  if (audio != null) {
                                                    setDialogState(() {
                                                      if (isFrontTab) {
                                                        frontAudioUrl = audio;
                                                      } else {
                                                        backAudioUrl = audio;
                                                      }
                                                    });
                                                    AudioService().playAudio(audio);
                                                  }
                                                },
                                        ),
                                        IconButton(
                                          icon: isGeneratingAudio
                                              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AsterTheme.primary(context)))
                                              : Icon(Icons.auto_awesome_rounded, size: 18, color: AsterTheme.primary(context)),
                                          tooltip: 'Regerar áudio com IA ✨',
                                          onPressed: (isSaving || isGeneratingAudio)
                                              ? null
                                              : () async {
                                                  if (currentText.isEmpty) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Escreva o texto da $sideLabel antes de gerar o áudio.')),
                                                    );
                                                    return;
                                                  }
                                                  setDialogState(() => isGeneratingAudio = true);
                                                  try {
                                                    final audioData = await AudioService.generateAiSpeech(text: currentText);
                                                    if (audioData != null) {
                                                      setDialogState(() {
                                                        if (isFrontTab) {
                                                          frontAudioUrl = audioData;
                                                        } else {
                                                          backAudioUrl = audioData;
                                                        }
                                                        isGeneratingAudio = false;
                                                      });
                                                      AudioService().playAudio(audioData);
                                                    } else {
                                                      setDialogState(() => isGeneratingAudio = false);
                                                      if (dialogCtx.mounted) {
                                                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                                          const SnackBar(content: Text('Não foi possível gerar áudio no momento.')),
                                                        );
                                                      }
                                                    }
                                                  } catch (_) {
                                                    setDialogState(() => isGeneratingAudio = false);
                                                  }
                                                },
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                          tooltip: 'Remover áudio',
                                          onPressed: isSaving
                                              ? null
                                              : () {
                                                  setDialogState(() {
                                                    if (isFrontTab) {
                                                      frontAudioUrl = null;
                                                    } else {
                                                      backAudioUrl = null;
                                                    }
                                                  });
                                                },
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AsterConstants.menta.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.mic_none_rounded, color: AsterConstants.menta, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Sem áudio anexado na $sideLabel. Você pode anexar um MP3 ou gerar a narração com IA!',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: (isSaving || isGeneratingAudio)
                                              ? null
                                              : () async {
                                                  final audio = await _pickAudioFileHelper();
                                                  if (audio != null) {
                                                    setDialogState(() {
                                                      if (isFrontTab) {
                                                        frontAudioUrl = audio;
                                                      } else {
                                                        backAudioUrl = audio;
                                                      }
                                                    });
                                                    AudioService().playAudio(audio);
                                                  }
                                                },
                                          icon: const Icon(Icons.upload_file_rounded, size: 14),
                                          label: const Text('Anexar MP3'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton.icon(
                                          onPressed: (isSaving || isGeneratingAudio)
                                              ? null
                                              : () async {
                                                  if (currentText.isEmpty) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Escreva o texto da $sideLabel antes de gerar o áudio.')),
                                                    );
                                                    return;
                                                  }
                                                  setDialogState(() => isGeneratingAudio = true);
                                                  try {
                                                    final audioData = await AudioService.generateAiSpeech(text: currentText);
                                                    if (audioData != null) {
                                                      setDialogState(() {
                                                        if (isFrontTab) {
                                                          frontAudioUrl = audioData;
                                                        } else {
                                                          backAudioUrl = audioData;
                                                        }
                                                        isGeneratingAudio = false;
                                                      });
                                                      AudioService().playAudio(audioData);
                                                    } else {
                                                      setDialogState(() => isGeneratingAudio = false);
                                                      if (dialogCtx.mounted) {
                                                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                                          const SnackBar(content: Text('Não foi possível gerar áudio no momento.')),
                                                        );
                                                      }
                                                    }
                                                  } catch (e) {
                                                    setDialogState(() => isGeneratingAudio = false);
                                                  }
                                                },
                                          icon: isGeneratingAudio
                                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                              : const Icon(Icons.auto_awesome_rounded, size: 14),
                                          label: Text(isGeneratingAudio ? 'Gerando...' : 'Gerar com IA ✨'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AsterTheme.primary(context),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.manrope(
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SoftClayPillButton(
                              text: 'Salvar Alterações',
                              icon: Icons.check_circle_rounded,
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final newFront = frontCtrl.text.trim();
                                      final newBack = backCtrl.text.trim();
                                      if (newFront.isEmpty || newBack.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('A frente e o verso não podem ficar vazios.')),
                                        );
                                        return;
                                      }

                                      setDialogState(() => isSaving = true);
                                      final updatedCard = card.copyWith(
                                        front: newFront,
                                        back: newBack,
                                        audioUrl: frontAudioUrl ?? backAudioUrl,
                                        frontAudioUrl: frontAudioUrl,
                                        backAudioUrl: backAudioUrl,
                                        clearAudio: frontAudioUrl == null && backAudioUrl == null,
                                        clearFrontAudio: frontAudioUrl == null,
                                        clearBackAudio: backAudioUrl == null,
                                      );

                                      // Atualizar no baralho ativo e na fila de estudo
                                      final updatedCards = List<Flashcard>.from(_activeStudyDeck!.cards);
                                      final targetIdx = updatedCards.indexWhere((c) => c.id == card.id);
                                      if (targetIdx != -1) {
                                        updatedCards[targetIdx] = updatedCard;
                                      }
                                      if (_activeCardIndex < _studyQueue.length) {
                                        _studyQueue[_activeCardIndex] = updatedCard;
                                      }

                                      final updatedDeck = FlashcardDeck(
                                        id: _activeStudyDeck!.id,
                                        title: _activeStudyDeck!.title,
                                        subject: _activeStudyDeck!.subject,
                                        description: _activeStudyDeck!.description,
                                        cards: updatedCards,
                                        createdAt: _activeStudyDeck!.createdAt,
                                        colorHex: _activeStudyDeck!.colorHex,
                                        iconCode: _activeStudyDeck!.iconCode,
                                      );

                                      await SupabaseService.saveFlashcardDeck(updatedDeck);

                                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                                      if (!mounted) return;

                                      setState(() {
                                        _activeStudyDeck = updatedDeck;
                                        final deckIdx = _decks.indexWhere((d) => d.id == updatedDeck.id);
                                        if (deckIdx != -1) {
                                          _decks[deckIdx] = updatedDeck;
                                        }
                                      });

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Cartão atualizado com sucesso! ✍️')),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
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
  // MODO DE ESTUDO 3D & REPETIÇÃO ESPAÇADA
  // ----------------------------------------------------
  Widget _buildStudyView(bool isDark) {
    final deck = _activeStudyDeck!;
    if (_isSessionFinished || _studyQueue.isEmpty) {
      return _buildFinishedSessionView(isDark);
    }

    final card = _studyQueue[_activeCardIndex];
    final color = _parseColor(deck.colorHex);
    final total = _studyQueue.length;
    final progress = (_activeCardIndex + 1) / total;
    final isRequeued = _requeuedCardIds.contains(card.id);

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SoftClayBackground(
      child: Scaffold(
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
                    onPressed: _exitStudySession,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                    Text(
                      'Cartão ${_activeCardIndex + 1} de $total · ${_studyPendingOnly ? 'Somente pendentes' : 'Revisão completa'}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                  ],
                ),
                actions: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.edit_outlined, size: 15, color: AsterTheme.primary(context)),
              label: Text(
                'Editar Cartão',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AsterTheme.primary(context),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _openEditCurrentCardDialog(card),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: Icon(Icons.edit_note_rounded, size: 17, color: AsterTheme.primary(context)),
              label: Text(
                'Editar Baralho',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AsterTheme.primary(context),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _openEditDeckDialog(deck),
            ),
            const SizedBox(width: 14),
          ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceInset,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            );
          },
        ),
      ),
      body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Atalhos de Teclado Dica
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: AsterTheme.primary(context)),
                        const SizedBox(width: 6),
                        Text(
                          isRequeued
                              ? 'Cartão difícil voltou na fila para reforço'
                              : 'Toque no cartão para virar e conferir a resposta',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isRequeued
                                ? AsterConstants.coral
                                : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3D Flip Card
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleCardFlip,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final angle = _flipAnimation.value * math.pi;
                          final isShowingFront = angle < (math.pi / 2);

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // perspective
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isShowingFront
                                ? _buildCardFace(
                                    isFront: true,
                                    card: card,
                                    isDark: isDark,
                                    color: color,
                                  )
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: _buildCardFace(
                                      isFront: false,
                                      card: card,
                                      isDark: isDark,
                                      color: color,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Barra de Avaliação Animada (Revelada apenas com a resposta virada)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isCardFlipped
                        ? Column(
                            key: const ValueKey('rating_buttons'),
                            children: [
                              Text(
                                'Como foi a sua lembrança deste conceito?',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildRatingButton(
                                    label: 'Difícil 🔴',
                                    subtitle: 'Errei / Revisar logo',
                                    color: AsterConstants.coral,
                                    onTap: () => _rateCurrentCard('hard'),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildRatingButton(
                                    label: 'Bom 🟡',
                                    subtitle: 'Lembrei com esforço',
                                    color: AsterConstants.ambar,
                                    onTap: () => _rateCurrentCard('good'),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildRatingButton(
                                    label: 'Fácil 🟢',
                                    subtitle: 'Dominei o conceito',
                                    color: AsterConstants.menta,
                                    onTap: () => _rateCurrentCard('easy'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : InkWell(
                            key: const ValueKey('flip_button_prompt'),
                            onTap: _toggleCardFlip,
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                border: Border.all(
                                  color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                ),
                                boxShadow: AsterConstants.clayShadow,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flip_camera_android_rounded, size: 16, color: AsterTheme.primary(context)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ver Resposta (Virar Cartão) 👆',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AsterTheme.primary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace({
    required bool isFront,
    required Flashcard card,
    required bool isDark,
    required Color color,
  }) {
    final sideAudio = card.audioForSide(isFront);
    final hasSideAudio = card.hasAudioForSide(isFront);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        border: Border.all(
          color: isFront ? (isDark ? AsterConstants.surfaceInsetDark : Colors.white) : color.withValues(alpha: 0.5),
          width: isFront ? 1.5 : 2.0,
        ),
        boxShadow: AsterConstants.clayShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isFront ? AsterTheme.primary(context) : color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  isFront ? 'FRENTE · ACTIVE RECALL' : 'VERSO · EXPLICAÇÃO',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isFront ? AsterTheme.primary(context) : color,
                  ),
                ),
              ),
              const Spacer(),
              // Botão para editar o cartão diretamente durante o estudo
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openEditCurrentCardDialog(card),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: AsterTheme.primary(context)),
                      const SizedBox(width: 4),
                      Text(
                        'Editar',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isFront ? Icons.flip_camera_android_rounded : Icons.check_circle_outline_rounded,
                size: 20,
                color: isDark ? AsterConstants.textFaintDark : AsterConstants.textFaint,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isFront ? card.front : card.back,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: isFront ? 20 : 16,
                        height: 1.5,
                        fontWeight: isFront ? FontWeight.w800 : FontWeight.w600,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        letterSpacing: isFront ? -0.4 : -0.2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // BOTÃO DE ÁUDIO NO CARTÃO (SEPARADO PARA PERGUNTA E RESPOSTA)
                    if (hasSideAudio && sideAudio != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable: AudioService().currentlyPlayingUrl,
                            builder: (ctx, playingUrl, _) {
                              final isPlaying = playingUrl == sideAudio;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  AudioService().playAudio(sideAudio);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isPlaying
                                        ? AsterTheme.primary(context)
                                        : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    border: Border.all(
                                      color: isPlaying
                                          ? AsterTheme.primary(context)
                                          : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                                      width: 1.5,
                                    ),
                                    boxShadow: isPlaying
                                        ? [
                                            BoxShadow(
                                              color: AsterTheme.primary(context).withValues(alpha: 0.35),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                                        size: 16,
                                        color: isPlaying ? Colors.white : AsterTheme.primary(context),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isPlaying ? 'Ouvindo Áudio...' : 'Ouvir Áudio 🔊',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isPlaying ? Colors.white : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(Icons.auto_awesome_rounded, size: 16, color: AsterTheme.primary(context)),
                            tooltip: isFront ? 'Regerar áudio da Pergunta com IA ✨' : 'Regerar áudio da Resposta com IA ✨',
                            onPressed: () async {
                              await _generateAndAttachStudySideAudio(card: card, isFront: isFront);
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await _generateAndAttachStudySideAudio(card: card, isFront: isFront);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            border: Border.all(
                              color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 13, color: AsterTheme.primary(context)),
                              const SizedBox(width: 6),
                              Text(
                                'Gerar Áudio com IA ✨',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
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
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isFront ? 'Toque para revelar a resposta 👆' : 'Toque para desvirar 🔄',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // RESUMO DE CONCLUSÃO DA SESSÃO DE ESTUDO
  // ----------------------------------------------------
  Widget _buildFinishedSessionView(bool isDark) {
    final deck = _activeStudyDeck!;
    final totalStudied = _studyQueue.length;
    final remainingPending = deck.cardsToReview();
    final minutesSpent = (_studyStopwatch.elapsedMilliseconds / 60000).ceil();

    return SoftClayBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                  boxShadow: AsterConstants.clayShadow,
                  border: Border.all(color: isDark ? AsterConstants.surfaceInsetDark : Colors.white),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AsterConstants.menta.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, size: 36, color: AsterConstants.menta),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      remainingPending.isEmpty ? 'Baralho Completo! 🎉' : 'Sessão Concluída! 🎉',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      remainingPending.isEmpty
                          ? 'Todos os cartões de "${deck.title}" foram aprendidos ou revisados. Cartões dominados não voltarão até vencer o intervalo.'
                          : 'Você concluiu esta rodada em "${deck.title}". Ainda faltam ${remainingPending.length} cartões pendentes.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Estatísticas da rodada
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryMetric('Fácil 🟢', '$_sessionEasyCount', AsterConstants.menta),
                          _buildSummaryMetric('Bom 🟡', '$_sessionGoodCount', AsterConstants.ambar),
                          _buildSummaryMetric('Difícil 🔴', '$_sessionHardCount', AsterConstants.coral),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão registrar no Tracker de Estudos
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.timer_outlined, size: 18),
                        label: Text('Registrar ${minutesSpent}min no Tracker de Estudos ⏱️'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                        ),
                        onPressed: () async {
                          await SupabaseService.addStudySession(
                            subject: deck.subject,
                            topic: 'Revisão de Flashcards: ${deck.title}',
                            durationMinutes: minutesSpent > 0 ? minutesSpent : 15,
                            studyDate: DateTime.now(),
                            notes: 'Revisão de $totalStudied cartões via repetição espaçada no Noesis.',
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sessão registrada no seu Dashboard! 📊')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _startStudySession(
                              deck,
                              reviewAll: remainingPending.isEmpty,
                            ),
                            child: Text(
                              remainingPending.isEmpty
                                  ? 'Revisar Tudo Novamente'
                                  : 'Continuar Pendentes (${remainingPending.length})',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SoftClayPillButton(
                            text: 'Concluir',
                            onPressed: _exitStudySession,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndAttachStudySideAudio({
    required Flashcard card,
    required bool isFront,
  }) async {
    final textToSpeak = isFront ? card.front : card.back;
    if (textToSpeak.trim().isEmpty) return;

    final sideName = isFront ? 'da Pergunta' : 'da Resposta';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gerando áudio $sideName com IA... ✨'),
        duration: const Duration(seconds: 2),
      ),
    );

    final audioData = await AudioService.generateAiSpeech(text: textToSpeak);
    if (audioData != null && mounted && _activeStudyDeck != null) {
      final updatedCard = isFront
          ? card.copyWith(frontAudioUrl: audioData, audioUrl: audioData)
          : card.copyWith(backAudioUrl: audioData);

      final updatedCards = List<Flashcard>.from(_activeStudyDeck!.cards);
      final cardIdx = updatedCards.indexWhere((c) => c.id == card.id);
      if (cardIdx != -1) {
        updatedCards[cardIdx] = updatedCard;
      }

      final updatedDeck = FlashcardDeck(
        id: _activeStudyDeck!.id,
        title: _activeStudyDeck!.title,
        subject: _activeStudyDeck!.subject,
        description: _activeStudyDeck!.description,
        cards: updatedCards,
        createdAt: _activeStudyDeck!.createdAt,
        colorHex: _activeStudyDeck!.colorHex,
        iconCode: _activeStudyDeck!.iconCode,
      );

      await SupabaseService.saveFlashcardDeck(updatedDeck);

      if (mounted) {
        setState(() {
          if (_activeCardIndex < _studyQueue.length &&
              _studyQueue[_activeCardIndex].id == card.id) {
            _studyQueue[_activeCardIndex] = updatedCard;
          }
          _activeStudyDeck = updatedDeck;
          final dIdx = _decks.indexWhere((d) => d.id == updatedDeck.id);
          if (dIdx != -1) _decks[dIdx] = updatedDeck;
        });

        AudioService().playAudio(audioData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Áudio $sideName anexado com sucesso ao cartão! 🎙️'),
          ),
        );
      }
    }
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AiSplitDeckEditor {
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController subjectCtrl;
  final TextEditingController descriptionCtrl;
  final String colorHex;
  final List<Flashcard> cards;
  bool isExpanded;

  _AiSplitDeckEditor({
    required this.id,
    required this.titleCtrl,
    required this.subjectCtrl,
    required this.descriptionCtrl,
    required this.colorHex,
    required this.cards,
    this.isExpanded = false,
  });
}
