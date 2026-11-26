import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/audio_service.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/core/theme.dart';
import 'package:noesis/features/flashcards/flashcards_screen.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/flashcards/utils/deck_file_importer.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature: Flashcards & Active Recall System', () {
    test('1. Flashcard & FlashcardDeck models serialize and compute progress correctly', () {
      final card1 = Flashcard(
        id: 'c1',
        front: 'O que é AES-GCM?',
        back: 'Modo AEAD com confidencialidade e autenticidade.',
        difficulty: 'easy',
      );
      final card2 = Flashcard(
        id: 'c2',
        front: 'O que é RSA?',
        back: 'Cifra assimétrica baseada em fatoração.',
        difficulty: 'hard',
      );
      final card3 = Flashcard(
        id: 'c3',
        front: 'O que é SHA-256?',
        back: 'Função de hash unidirecional.',
        difficulty: 'good',
      );

      final deck = FlashcardDeck(
        id: 'test-deck',
        title: 'Criptografia Prática',
        subject: 'Criptografia',
        description: 'Baralho de teste.',
        cards: [card1, card2, card3],
        createdAt: DateTime(2026, 11, 23),
      );

      expect(deck.cardCount, equals(3));
      expect(deck.masteredCount, equals(1));
      expect(deck.goodCount, equals(1));
      expect(deck.hardCount, equals(1));
      // (1.0 + 0.25 + 0.65) / 3 = 1.9 / 3 = ~0.633
      expect(deck.progressPercentage, greaterThan(0.6));

      // Test map serialization roundtrip
      final map = deck.toMap();
      final roundtripDeck = FlashcardDeck.fromMap(map);
      expect(roundtripDeck.id, equals(deck.id));
      expect(roundtripDeck.cards.length, equals(3));
      expect(roundtripDeck.cards.first.front, equals(card1.front));
    });

    test('2. SupabaseService starts without fake seeded decks and supports deck persistence', () async {
      final initialDecks = await SupabaseService.getFlashcardDecks();
      expect(initialDecks, isA<List<FlashcardDeck>>());

      // Create and save custom deck
      final newDeck = FlashcardDeck(
        id: 'custom-deck-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Kubernetes Pods & Services',
        subject: 'DevOps',
        description: 'Conceitos de orquestração.',
        cards: [
          Flashcard(
            id: 'k1',
            front: 'O que é um Pod?',
            back: 'Menor unidade executável no Kubernetes.',
          ),
        ],
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(newDeck);
      final updatedDecks = await SupabaseService.getFlashcardDecks();
      expect(updatedDecks.any((d) => d.id == newDeck.id), isTrue);

      // Update card review
      await SupabaseService.updateCardReview(
        deckId: newDeck.id,
        cardId: 'k1',
        difficulty: 'easy',
      );
      final reloadedDecks = await SupabaseService.getFlashcardDecks();
      final savedDeck = reloadedDecks.firstWhere((d) => d.id == newDeck.id);
      expect(savedDeck.cards.first.difficulty, equals('easy'));
      expect(savedDeck.cards.first.reviewCount, equals(1));

      // Delete deck
      await SupabaseService.deleteFlashcardDeck(newDeck.id);
      final postDeleteDecks = await SupabaseService.getFlashcardDecks();
      expect(postDeleteDecks.any((d) => d.id == newDeck.id), isFalse);
    });

    test('3. GeminiService generates flashcards autonomously for specific topics', () async {
      final cards = await GeminiService.generateFlashcards(
        subject: 'Segurança',
        topic: 'OWASP Top 10 e Injection',
        count: 3,
        difficulty: 'Médio / Prático',
      );

      expect(cards, isNotEmpty);
      expect(cards.first.containsKey('front'), isTrue);
      expect(cards.first.containsKey('back'), isTrue);
      expect(cards.first.containsKey('tags'), isTrue);
    });

    testWidgets('4. FlashcardsScreen renders decks, metrics, and executes study flip session',
        (WidgetTester tester) async {
      final seededTestDeck = FlashcardDeck(
        id: 'test-ui-deck-1',
        title: 'Criptografia & Segurança',
        subject: 'Criptografia',
        description: 'Baralho de revisão para teste de UI.',
        cards: [
          Flashcard(
            id: 'fc-ui-1',
            front: 'O que é AES-GCM?',
            back: 'Modo de operação AEAD com confidencialidade e integridade.',
            difficulty: 'unreviewed',
          ),
          Flashcard(
            id: 'fc-ui-2',
            front: 'O que é Perfect Forward Secrecy?',
            back: 'Troca efêmera de chaves que protege sessões passadas.',
            difficulty: 'unreviewed',
          ),
        ],
        createdAt: DateTime.now(),
      );
      await SupabaseService.saveFlashcardDeck(seededTestDeck);
      addTearDown(() => SupabaseService.deleteFlashcardDeck(seededTestDeck.id));

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      // Verify screen title and action buttons
      expect(find.text('Flashcards Cognitivos'), findsOneWidget);
      expect(find.text('ACTIVE RECALL ENGINE'), findsNothing);
      expect(find.text('Gerar com IA ✨'), findsAtLeastNWidgets(1));
      expect(find.text('Novo Baralho'), findsOneWidget);

      // Verify metric labels
      expect(find.text('Baralhos Ativos'), findsOneWidget);
      expect(find.text('Total de Cartões'), findsOneWidget);

      // Verify at least one pre-seeded deck card is displayed
      expect(find.textContaining('Criptografia'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Estudar Agora 🚀'), findsAtLeastNWidgets(1));

      // Tap 'Estudar Agora' on the first available deck
      await tester.tap(find.textContaining('Estudar Agora 🚀').first);
      await tester.pumpAndSettle();

      // Verify study view mounts with card front and flip prompt, but NO rating buttons
      expect(find.text('FRENTE · ACTIVE RECALL'), findsOneWidget);
      expect(find.text('Toque para revelar a resposta 👆'), findsOneWidget);
      expect(find.text('Ver Resposta (Virar Cartão) 👆'), findsOneWidget);
      expect(find.text('Editar Cartão'), findsOneWidget);
      expect(find.text('Difícil 🔴'), findsNothing);
      expect(find.text('Bom 🟡'), findsNothing);
      expect(find.text('Fácil 🟢'), findsNothing);

      // Test editing card during progression
      await tester.tap(find.text('Editar Cartão'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Flashcard ✍️'), findsOneWidget);
      expect(find.text('Salvar Alterações'), findsOneWidget);

      // Modify front text
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Conceito Editado Durante o Estudo!');
      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      // Verify card immediately displays the edited text
      expect(find.text('Conceito Editado Durante o Estudo!'), findsOneWidget);

      // Tap card or prompt button to flip (Active Recall reveal)
      await tester.tap(find.text('Ver Resposta (Virar Cartão) 👆'));
      await tester.pumpAndSettle();

      // Verify flipped back face and animated appearance of rating buttons
      expect(find.text('VERSO · EXPLICAÇÃO'), findsOneWidget);
      expect(find.text('Toque para desvirar 🔄'), findsOneWidget);
      expect(find.text('Difícil 🔴'), findsOneWidget);
      expect(find.text('Bom 🟡'), findsOneWidget);
      expect(find.text('Fácil 🟢'), findsOneWidget);

      // Rate card as 'Fácil 🟢'
      await tester.tap(find.text('Fácil 🟢'));
      await tester.pumpAndSettle();

      // Return to deck list
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Back on main screen
      expect(find.text('Flashcards Cognitivos'), findsOneWidget);
      expect(find.text('Importar Arquivo'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });

    test('5. DeckFileImporter parses Anki tab-delimited cards, Markdown and TXT files', () {
      // 5.1 Anki tab-separated export format
      const ankiRaw = '#separator:tab\n#html:true\n'
          'O que é TLS Handshake?\tProtocolo de negociação de chaves e cifras seguras.\tsegurança criptografia\n'
          'Qual a porta padrão do HTTPS?\tPorta TCP 443.\tredes web\n'
          'O que é Perfect Forward Secrecy (PFS)?\tGarante que o comprometimento da chave privada de longo prazo não compromete sessões passadas.\tcriptografia\n';
      
      final ankiBytes = utf8.encode(ankiRaw);
      final ankiParsed = DeckFileImporter.parse('anki_seguranca_redes.txt', ankiBytes);

      expect(ankiParsed.fileName, equals('anki_seguranca_redes.txt'));
      expect(ankiParsed.isAnkiFormat, isTrue);
      expect(ankiParsed.parsedCards.length, equals(3));
      expect(ankiParsed.parsedCards.first.front, equals('O que é TLS Handshake?'));
      expect(ankiParsed.parsedCards.first.back, contains('Protocolo de negociação'));
      expect(ankiParsed.suggestedSubject, equals('Criptografia'));

      // 5.2 Markdown Q&A format
      const mdRaw = '# Resumo de Algoritmos\n\n'
          'Q: O que é complexidade assintótica?\n'
          'A: É o comportamento do algoritmo quando o tamanho da entrada tende ao infinito (Big-O).\n\n'
          'Q: Como funciona o algoritmo de Dijkstra?\n'
          'A: Encontra os caminhos mais curtos a partir de um vértice de origem usando fila de prioridade.\n';

      final mdBytes = utf8.encode(mdRaw);
      final mdParsed = DeckFileImporter.parse('algoritmos_grafos.md', mdBytes);

      expect(mdParsed.fileName, equals('algoritmos_grafos.md'));
      expect(mdParsed.isAnkiFormat, isTrue); // Structured Q&A detected
      expect(mdParsed.parsedCards.length, equals(2));
      expect(mdParsed.parsedCards.first.front, contains('complexidade assintótica'));
      expect(mdParsed.suggestedSubject, equals('Algoritmos'));

      // 5.3 Plain text context notes (no structured Q&A)
      const txtRaw = 'AWS Lambda é um serviço de computação serverless orientado a eventos. '
          'Ele executa código em resposta a triggers do S3, SQS e DynamoDB sem gerenciar servidores EC2.';

      final txtBytes = utf8.encode(txtRaw);
      final txtParsed = DeckFileImporter.parse('aws_serverless_resumo.txt', txtBytes);

      expect(txtParsed.fileName, equals('aws_serverless_resumo.txt'));
      expect(txtParsed.isAnkiFormat, isFalse);
      expect(txtParsed.parsedCards, isEmpty);
      expect(txtParsed.suggestedSubject, equals('Cloud & DevOps'));
      expect(txtParsed.rawText, contains('AWS Lambda'));
    });

    test('6. DeckFileImporter parses native Anki package (.apkg) ZIP archives containing collection.anki2', () {
      final pageSize = 4096;
      final dbBytes = List<int>.filled(pageSize * 2, 0);

      // SQLite Header
      final headerStr = 'SQLite format 3\x00';
      for (int i = 0; i < headerStr.length; i++) {
        dbBytes[i] = headerStr.codeUnitAt(i);
      }
      dbBytes[16] = (pageSize >> 8) & 0xFF;
      dbBytes[17] = pageSize & 0xFF;

      // Deck name JSON in page 1
      final deckJsonStr = '{"1": {"id": 1, "name": "Default"}, "1700000": {"id": 1700000, "name": "Criptografia e Redes Avançadas", "desc": "Baralho Anki"}}';
      final deckJsonBytes = utf8.encode(deckJsonStr);
      for (int i = 0; i < deckJsonBytes.length; i++) {
        dbBytes[200 + i] = deckJsonBytes[i];
      }

      // Page 2: Table Leaf page (offset 4096)
      final p2 = pageSize;
      dbBytes[p2 + 0] = 0x0D; // Leaf table b-tree
      dbBytes[p2 + 3] = 0;
      dbBytes[p2 + 4] = 1; // 1 cell

      final flds = 'O que é AES-256?\x1fPadrão de criptografia simétrica com chave de 256 bits.';
      final fldsBytes = utf8.encode(flds);
      final stText = fldsBytes.length * 2 + 13;

      // Simple varint encoder
      List<int> encVarint(int v) {
        if (v < 0x80) return [v];
        final res = <int>[];
        int val = v;
        while (val > 0) {
          res.insert(0, (val & 0x7F) | (res.isEmpty ? 0 : 0x80));
          val >>= 7;
        }
        return res;
      }

      final stBytes = encVarint(stText);
      final headerSize = 1 + 1 + stBytes.length;
      final payloadHeader = [headerSize, 1, ...stBytes];
      final payload = [...payloadHeader, 1, ...fldsBytes];

      final cellOffset = pageSize - payload.length - 4;
      dbBytes[p2 + cellOffset + 0] = payload.length; // payload len
      dbBytes[p2 + cellOffset + 1] = 1;              // rowid
      for (int i = 0; i < payload.length; i++) {
        dbBytes[p2 + cellOffset + 2 + i] = payload[i];
      }

      // Pointer at header offset 8
      dbBytes[p2 + 8] = (cellOffset >> 8) & 0xFF;
      dbBytes[p2 + 9] = cellOffset & 0xFF;

      // Build APKG zip
      final archive = Archive();
      archive.addFile(ArchiveFile('collection.anki2', dbBytes.length, dbBytes));
      final apkgBytes = ZipEncoder().encode(archive);

      final apkgParsed = DeckFileImporter.parse('seguranca_apkg_deck.apkg', apkgBytes);

      expect(apkgParsed.fileName, equals('seguranca_apkg_deck.apkg'));
      expect(apkgParsed.isAnkiFormat, isTrue);
      expect(apkgParsed.suggestedTitle, equals('Criptografia e Redes Avançadas'));
      expect(apkgParsed.suggestedSubject, equals('Criptografia'));
      expect(apkgParsed.parsedCards.length, equals(1));
      expect(apkgParsed.parsedCards.first.front, equals('O que é AES-256?'));
      expect(apkgParsed.parsedCards.first.back, contains('criptografia simétrica'));
      expect(apkgParsed.rawText, contains('Baralho Anki: Criptografia e Redes Avançadas'));
    });

    test('7. DeckFileImporter infers Idiomas for grammar/language decks and supports card copyWith editing', () {
      const grammarRaw = 'Present Perfect\tUsado para ações no passado com conexão com o presente.\tgrammar\n'
          'Past Simple\tUsado para ações terminadas em momento definido do passado.\tgrammar\n';
      final parsed = DeckFileImporter.parse('01 - Grammar Lessons (Todas as 53 Aulas).txt', utf8.encode(grammarRaw));

      expect(parsed.suggestedSubject, equals('Idiomas'));
      expect(parsed.parsedCards.length, equals(2));

      // Test card editing via copyWith
      final editedCard = parsed.parsedCards.first.copyWith(
        front: 'Qual o uso do Present Perfect?',
        back: 'Ações iniciadas no passado com relevância no presente.',
      );
      expect(editedCard.front, equals('Qual o uso do Present Perfect?'));
      expect(editedCard.back, contains('relevância no presente'));
    });

    test('8. GeminiService splits large flashcard decks (> 20 cards) into thematic sub-decks with zero card loss', () async {
      // 8.1 <= 20 cards returns a single unified deck
      final smallCards = List.generate(
        15,
        (i) => Flashcard(id: 'c$i', front: 'Conceito $i', back: 'Explicação $i'),
      );
      final singleDeck = await GeminiService.splitFlashcardsIntoDecks(
        cards: smallCards,
        baseTitle: 'Fundamentos de Redes',
        baseSubject: 'Redes',
      );
      expect(singleDeck.length, equals(1));
      expect(singleDeck.first.cards.length, equals(15));
      expect(singleDeck.first.title, contains('Fundamentos de Redes'));

      // 8.2 > 20 cards (25 cards) triggers thematic AI separation
      final largeCards = List.generate(
        25,
        (i) => Flashcard(
          id: 'large-$i',
          front: 'Pergunta sobre Criptografia & Redes $i',
          back: 'Resposta detalhada do algoritmo ou protocolo $i',
          tags: i < 12 ? ['criptografia', 'cifras'] : ['redes', 'protocolos'],
        ),
      );

      final splitDecks = await GeminiService.splitFlashcardsIntoDecks(
        cards: largeCards,
        baseTitle: 'Segurança e Redes Avançadas',
        baseSubject: 'Segurança',
      );

      expect(splitDecks.length, greaterThanOrEqualTo(2));
      final totalCardsInSplit = splitDecks.fold<int>(0, (sum, d) => sum + d.cards.length);
      expect(totalCardsInSplit, equals(25)); // 100% card preservation
      for (final deck in splitDecks) {
        expect(deck.title, isNotEmpty);
        expect(deck.subject, isNotEmpty);
        expect(deck.colorHex, isNotEmpty);
        expect(deck.cards, isNotEmpty);
      }
    });

    testWidgets('9. FlashcardsScreen provides AI deck splitting for > 20 cards and allows editing deck titles before saving', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      final state = tester.state<FlashcardsScreenState>(find.byType(FlashcardsScreen));

      final testCards = List.generate(
        22,
        (i) => Flashcard(
          id: 'card-$i',
          front: 'Pergunta $i sobre Arquitetura Cloud',
          back: 'Resposta detalhada $i sobre VPC e EC2',
          tags: ['Cloud', 'DevOps'],
        ),
      );

      state.openImportDeckReviewDialogForTesting(
        DeckFileContent(
          fileName: 'cloud_architecture.txt',
          fileSizeBytes: 2048,
          rawText: 'AWS Cloud Architecture Notes',
          suggestedTitle: 'AWS Cloud Architecture',
          suggestedSubject: 'Cloud & DevOps',
          isAnkiFormat: true,
          parsedCards: testCards,
        ),
      );
      await tester.pumpAndSettle();

      // Verify the banner is shown because cards > 20
      expect(find.textContaining('Baralho Volumoso Detectado'), findsOneWidget);
      expect(find.text('> 20 cartões'), findsOneWidget);
      expect(find.text('Separar com IA ✨'), findsAtLeastNWidgets(1));

      // Tap Separar com IA ✨
      await tester.tap(find.text('Separar com IA ✨').first);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify AI Split Review Dialog mounts
      expect(find.text('Divisão de Baralhos por IA 🗂️✨'), findsOneWidget);
      expect(find.textContaining('Baralho #1'), findsOneWidget);
      expect(find.textContaining('Baralho #2'), findsOneWidget);
      expect(find.text('TÍTULO DO BARALHO (EDITÁVEL)'), findsAtLeastNWidgets(2));

      // Modify the title of the first deck
      final titleInputs = find.byType(TextFormField);
      expect(titleInputs, findsAtLeastNWidgets(2));
      await tester.enterText(titleInputs.first, 'AWS Cloud: Módulo 1 Editado pelo Usuário');
      await tester.pumpAndSettle();

      expect(find.text('AWS Cloud: Módulo 1 Editado pelo Usuário'), findsOneWidget);

      // Save all decks
      await tester.tap(find.textContaining('Salvar Todos os Baralhos'));
      await tester.pumpAndSettle();

      // Verify success feedback and immediate start of study session with edited deck
      expect(find.textContaining('criados com sucesso'), findsOneWidget);
      expect(find.text('FRENTE · ACTIVE RECALL'), findsOneWidget);
      expect(find.textContaining('AWS Cloud: Módulo 1 Editado pelo Usuário'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });

    test('10. DeckFileImporter parses Anki packages, extracts audio media files and cleans sound markers', () async {
      final archive = Archive();
      // Mock note table text in anki2 / anki21
      final mockAnkiContent = utf8.encode(
        'CREATE TABLE notes (flds text);\n'
        'INSERT INTO notes VALUES (\'[Grammar] I speak English.\x1fEu falo inglês.\x1f01, I, speak, English.mp3\');\n'
        'INSERT INTO notes VALUES (\'This file requires a newer version of Anki.\x1fThis file requires a newer version\x1f\');\n'
      );
      archive.addFile(ArchiveFile('collection.anki2', mockAnkiContent.length, mockAnkiContent));

      // Mock media mapping JSON
      final mediaJson = jsonEncode({'0': '01, I, speak, English.mp3'});
      archive.addFile(ArchiveFile('media', mediaJson.length, utf8.encode(mediaJson)));

      // Mock audio binary file named '0'
      final mockAudioBytes = [0xFF, 0xFB, 0x90, 0x64, 0x00, 0x00, 0x00, 0x00];
      archive.addFile(ArchiveFile('0', mockAudioBytes.length, mockAudioBytes));

      final zipBytes = ZipEncoder().encode(archive);

      final parsed = DeckFileImporter.parse(
        'english_grammar.apkg',
        zipBytes,
      );

      expect(parsed.isAnkiFormat, isTrue);
      // Stub note "This file requires a newer version of Anki." should be ignored
      expect(parsed.parsedCards.length, equals(1));
      final card = parsed.parsedCards.first;
      expect(card.front, contains('I speak English'));
      expect(card.back, contains('Eu falo inglês'));
      // [sound:...] should not leak into tags
      expect(card.tags.any((t) => t.contains('[sound:')), isFalse);
      expect(card.tags.any((t) => t.contains('.mp3')), isFalse);
      // Audio should be properly extracted as a data URI
      expect(card.hasAudio, isTrue);
      expect(card.audioUrl, startsWith('data:audio/mp3;base64,'));
    });

    test('11. DeckFileImporter cleans [sound:...] and sound tags from raw text lines', () async {
      const rawText = '#separator:tab\n'
          '#html:true\n'
          '#tags column:3\n'
          '[Grammar] I speak English.\tEu falo inglês.\t[sound:01, I, speak, English.mp3]\n'
          'How are you?\tComo vai você?\tconversacao\n';

      final parsed = DeckFileImporter.parse(
        'grammar.txt',
        utf8.encode(rawText),
      );

      expect(parsed.parsedCards.length, equals(2));
      final card1 = parsed.parsedCards[0];
      expect(card1.front, equals('[Grammar] I speak English.'));
      expect(card1.back, equals('Eu falo inglês.'));
      // Tags must NOT contain the sound reference
      expect(card1.tags, isNot(contains('[sound:01, I, speak, English.mp3]')));
      expect(card1.tags, isNot(contains('01, I, speak, English.mp3')));

      final card2 = parsed.parsedCards[1];
      expect(card2.tags, contains('conversacao'));
    });

    test('12. AudioService produces audio data URI or speech audio format', () async {
      final audioData = await AudioService.generateAiSpeech(text: 'Hello world! Welcome to Noesis.');
      // Should return either a base64 Data URI or speech streaming URL
      if (audioData != null) {
        expect(audioData, anyOf(startsWith('data:audio/'), startsWith('https://')));
      }
    });

    testWidgets('13. FlashcardsScreen displays audio button when card has audio and AI button when card has no audio', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cardWithAudio = Flashcard(
        id: 'audio-card-1',
        front: 'What is symmetric cryptography?',
        back: 'Uses the same key for encryption and decryption.',
        audioUrl: 'data:audio/mp3;base64,//uQZAAAAAAAAAAAAAAAAAAAAAA',
      );

      final cardWithoutAudio = Flashcard(
        id: 'no-audio-card-2',
        front: 'What is asymmetric cryptography?',
        back: 'Uses a public key and a private key pair.',
      );

      final audioDeck = FlashcardDeck(
        id: 'audio-test-deck',
        title: 'Criptografia com Áudio',
        subject: 'Segurança',
        description: 'Baralho com áudio narrado.',
        cards: [cardWithAudio, cardWithoutAudio],
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(audioDeck);

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      // Open study session
      await tester.tap(find.text('Estudar Agora 🚀').first);
      await tester.pumpAndSettle();

      // First card has audio attached: should show 'Ouvir Áudio 🔊'
      expect(find.text('Ouvir Áudio 🔊'), findsOneWidget);

      // Tap 'Ouvir Áudio 🔊'
      await tester.tap(find.text('Ouvir Áudio 🔊'));
      await tester.pump();

      // Open card edit modal
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Flashcard ✍️'), findsOneWidget);
      expect(find.text('ÁUDIO DO CARTÃO 🎙️'), findsOneWidget);
      expect(find.text('Áudio Anexado'), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);

      // Close edit modal
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      // Reveal answer and rate easy to advance to second card (without audio)
      await tester.tap(find.text('Ver Resposta (Virar Cartão) 👆'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fácil 🟢'));
      await tester.pumpAndSettle();

      // Second card does NOT have audio: should show 'Gerar Áudio com IA ✨'
      expect(find.text('Gerar Áudio com IA ✨'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });

    test('14. GeminiService.splitFlashcardsIntoDecks respects targetCardsPerDeck', () async {
      final cards60 = List.generate(
        60,
        (i) => Flashcard(
          id: 'c_$i',
          front: 'Frente do Cartão #$i',
          back: 'Verso explicativo do Cartão #$i',
        ),
      );

      // Split 60 cards into ~20 per deck -> 3 decks
      final decks20 = await GeminiService.splitFlashcardsIntoDecks(
        cards: cards60,
        baseTitle: 'Gramática de Inglês',
        baseSubject: 'Idiomas',
        targetCardsPerDeck: 20,
      );
      expect(decks20.length, equals(3));
      for (final d in decks20) {
        expect(d.cards.length, equals(20));
        expect(d.title, contains('Gramática de Inglês'));
        expect(d.subject, equals('Idiomas'));
      }

      // Split 60 cards into ~30 per deck -> 2 decks
      final decks30 = await GeminiService.splitFlashcardsIntoDecks(
        cards: cards60,
        baseTitle: 'Gramática de Inglês',
        baseSubject: 'Idiomas',
        targetCardsPerDeck: 30,
      );
      expect(decks30.length, equals(2));
      for (final d in decks30) {
        expect(d.cards.length, equals(30));
        expect(d.title, contains('Gramática de Inglês'));
      }
    });

    testWidgets('15. FlashcardsScreen allows splitting an existing deck into smaller decks and re-splitting', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cards60 = List.generate(
        60,
        (i) => Flashcard(
          id: 'card_split_$i',
          front: 'Questão sobre Redes #$i',
          back: 'Resposta sobre Protocolos #$i',
        ),
      );

      final bigDeck = FlashcardDeck(
        id: 'big-deck-split-test',
        title: 'Redes TCP/IP Volume Completo',
        subject: 'Redes',
        description: 'Baralho volumoso com 60 cartões.',
        cards: cards60,
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(bigDeck);

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      expect(find.text('Redes TCP/IP Volume Completo'), findsOneWidget);

      // Deck has > 20 cards so it displays 'Dividir IA ✨' badge
      final splitBadge = find.text('Dividir IA ✨');
      expect(splitBadge, findsOneWidget);

      // Tap on the badge to open the split configuration modal
      await tester.tap(splitBadge);
      await tester.pumpAndSettle();

      expect(find.textContaining('Dividir Baralho com IA'), findsOneWidget);
      expect(find.text('TAMANHO DESEJADO POR BARALHO'), findsOneWidget);
      expect(find.text('Substituir baralho original pelos novos baralhos menores'), findsOneWidget);

      // Tap 'Dividir com IA ✨' button to start division
      await tester.tap(find.widgetWithText(SoftClayPillButton, 'Dividir com IA ✨'));
      await tester.pumpAndSettle();

      // Review dialog should open
      expect(find.text('Divisão de Baralhos por IA 🗂️✨'), findsOneWidget);
      expect(find.text('Tamanho por baralho:'), findsOneWidget);
      expect(find.text('20 cards'), findsOneWidget);
      expect(find.text('30 cards ✨'), findsOneWidget);

      // Reorganize using size chips: switch to 20 cards
      await tester.tap(find.text('20 cards'));
      await tester.pumpAndSettle();

      // Tap 'Salvar Todos os Baralhos'
      final saveButton = find.textContaining('Salvar Todos os Baralhos');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Original deck was replaced by smaller sub-decks
      final decks = await SupabaseService.getFlashcardDecks();
      expect(decks.any((d) => d.id == 'big-deck-split-test'), isFalse);
      expect(decks.any((d) => d.title.contains('Redes TCP/IP Volume Completo')), isTrue);

      await TestAppHarness.drainAsync(tester);
    });

    test('16. GeminiService validates eligible free tier models and excludes utility/non-chat models', () {
      expect(GeminiService.isEligibleGeminiAssistantModel('gemini-1.5-flash'), isTrue);
      expect(GeminiService.isEligibleGeminiAssistantModel('gemini-2.0-flash'), isTrue);
      expect(GeminiService.isEligibleGeminiAssistantModel('gemini-1.5-pro'), isTrue);
      expect(GeminiService.isEligibleGeminiAssistantModel('gemini-2.5-flash'), isTrue);

      // Utility, specialized or experimental non-chat models must be excluded
      expect(GeminiService.isEligibleGeminiAssistantModel('gemini-3.5-transcribe'), isFalse);
      expect(GeminiService.isEligibleGeminiAssistantModel('gemini-robotics-er-2-preview'), isFalse);
      expect(GeminiService.isEligibleGeminiAssistantModel('text-embedding-004'), isFalse);
      expect(GeminiService.isEligibleGeminiAssistantModel('imagen-3.0-generate-002'), isFalse);
    });

    testWidgets('17. FlashcardsScreen allows uploading an MP3 audio file to a card in edit modal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        FlashcardsScreenState.audioPickerOverrideForTesting = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const mockUploadedAudio = 'data:audio/mp3;base64,//uQZUploadMockAudioData123';
      FlashcardsScreenState.audioPickerOverrideForTesting = () async => mockUploadedAudio;

      final cardNoAudio = Flashcard(
        id: 'upload-audio-card-1',
        front: 'O que é zero trust architecture?',
        back: 'Nunca confiar, sempre verificar cada requisição.',
      );

      final deck = FlashcardDeck(
        id: 'upload-audio-deck',
        title: 'Segurança Zero Trust',
        subject: 'Segurança',
        description: 'Baralho para teste de upload de MP3.',
        cards: [cardNoAudio],
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(deck);

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      // Start study
      await tester.tap(find.text('Estudar Agora 🚀').first);
      await tester.pumpAndSettle();

      // Open card edit modal
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Flashcard ✍️'), findsOneWidget);
      expect(find.text('ÁUDIO DO CARTÃO 🎙️'), findsOneWidget);
      expect(find.text('Anexar MP3'), findsOneWidget);
      expect(find.text('Gerar com IA ✨'), findsOneWidget);

      // Tap 'Anexar MP3' to upload audio file
      await tester.tap(find.text('Anexar MP3'));
      await tester.pumpAndSettle();

      // Should now show attached audio and option to change MP3
      expect(find.text('Áudio Anexado'), findsOneWidget);
      expect(find.byTooltip('Trocar arquivo de áudio MP3'), findsOneWidget);

      // Save changes
      await tester.tap(find.text('Salvar Alterações'));
      await tester.pumpAndSettle();

      // Card in database has updated audioUrl
      final decks = await SupabaseService.getFlashcardDecks();
      final savedDeck = decks.firstWhere((d) => d.id == 'upload-audio-deck');
      expect(savedDeck.cards.first.audioUrl, equals(mockUploadedAudio));
      expect(savedDeck.cards.first.hasAudio, isTrue);

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('18. FlashcardsScreen allows attaching MP3 and generating AI audio in Create Manual Deck dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        FlashcardsScreenState.audioPickerOverrideForTesting = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const mockManualDeckAudio = 'data:audio/mp3;base64,//uQZManualDeckAudioMock999';
      FlashcardsScreenState.audioPickerOverrideForTesting = () async => mockManualDeckAudio;

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      // Open "Novo Baralho"
      expect(find.text('Novo Baralho'), findsOneWidget);
      await tester.tap(find.text('Novo Baralho'));
      await tester.pumpAndSettle();

      expect(find.text('Criar Novo Baralho'), findsOneWidget);
      expect(find.text('Anexar MP3'), findsOneWidget);
      expect(find.text('Gerar Áudio IA'), findsOneWidget);

      // Tap 'Anexar MP3' to attach audio
      await tester.tap(find.text('Anexar MP3'));
      await tester.pumpAndSettle();

      // Card #1 should now show 'Tocando' while playing or 'Áudio Anexado'
      expect(find.text('Tocando'), findsOneWidget);
      expect(find.byTooltip('Trocar MP3'), findsOneWidget);

      await AudioService().stopAudio();
      await tester.pumpAndSettle();
      expect(find.text('Áudio Anexado'), findsOneWidget);

      // AudioService can play and stop without errors
      await AudioService().playAudio('speech:pt-BR:Teste de sintetizador');
      expect(AudioService().currentlyPlayingUrl.value, equals('speech:pt-BR:Teste de sintetizador'));
      await AudioService().stopAudio();
      expect(AudioService().currentlyPlayingUrl.value, isNull);

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('19. FlashcardsScreen allows editing a deck and managing its cards from deck card popup menu', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deckToEdit = FlashcardDeck(
        id: 'deck-to-edit-1',
        title: 'Arquitetura Cloud & Resiliência',
        subject: 'Cloud / AWS',
        description: 'Conceitos de VPC e alta disponibilidade.',
        cards: [
          Flashcard(
            id: 'c-edit-1',
            front: 'O que é um VPC Peering?',
            back: 'Conexão de rede entre duas VPCs.',
          ),
          Flashcard(
            id: 'c-edit-2',
            front: 'O que é um Internet Gateway?',
            back: 'Componente que permite comunicação entre VPC e Internet.',
          ),
        ],
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(deckToEdit);

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      expect(find.text('Arquitetura Cloud & Resiliência'), findsOneWidget);

      // Open popup menu on the deck card
      final popupMenuFinder = find.byIcon(Icons.more_horiz_rounded).first;
      await tester.tap(popupMenuFinder);
      await tester.pumpAndSettle();

      // Should show 'Editar Baralho' in the menu
      expect(find.text('Editar Baralho'), findsOneWidget);
      expect(find.text('Adicionar Cartão'), findsOneWidget);
      expect(find.text('Excluir Baralho'), findsOneWidget);

      // Tap 'Editar Baralho'
      await tester.tap(find.text('Editar Baralho'));
      await tester.pumpAndSettle();

      // Verify the modal opened with deck details
      expect(find.text('Editar Baralho ✏️'), findsOneWidget);
      expect(find.text('TÍTULO DO BARALHO *'), findsOneWidget);
      expect(find.text('MATÉRIA / DISCIPLINA'), findsOneWidget);
      expect(find.text('Novo Cartão'), findsOneWidget);
      expect(find.text('Salvar Baralho 💾'), findsOneWidget);

      // Verify existing cards are present
      expect(find.text('O que é um VPC Peering?'), findsOneWidget);

      // Save deck
      await tester.tap(find.text('Salvar Baralho 💾'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Baralho ✏️'), findsNothing);
      expect(find.text('Arquitetura Cloud & Resiliência'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });

    test('20. AudioService.detectLanguage accurately distinguishes English from Portuguese and other languages', () {
      // Frases em inglês (comum em baralhos de idiomas e termos técnicos)
      expect(AudioService.detectLanguage('[Grammar] I speak English.'), equals('en-US'));
      expect(AudioService.detectLanguage('Good morning! How are you doing today?'), equals('en-US'));
      expect(AudioService.detectLanguage('What is symmetric cryptography and why is it fast?'), equals('en-US'));
      expect(AudioService.detectLanguage('Diffie-Hellman ephemeral key exchange'), equals('en-US'));
      expect(AudioService.detectLanguage("I don't think this will work without an API key"), equals('en-US'));

      // Frases em português (comum em explicações e matérias nacionais)
      expect(AudioService.detectLanguage('Eu falo inglês e estudo diariamente.'), equals('pt-BR'));
      expect(AudioService.detectLanguage('A simétrica (AES, ChaCha20) usa uma única chave compartilhada para cifrar.'), equals('pt-BR'));
      expect(AudioService.detectLanguage('Propriedade que assegura que o vazamento futuro da chave privada não compromete sessões passadas.'), equals('pt-BR'));
      expect(AudioService.detectLanguage('Qual é a diferença entre processo e thread no sistema operacional?'), equals('pt-BR'));

      // Frases em espanhol
      expect(AudioService.detectLanguage('¿Cómo estás mi amigo? Yo no hablo inglés muy bien.'), equals('es-ES'));
    });

    testWidgets('21. FlashcardsScreen supports independent audio for Question (Front) and Answer (Back)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Cartão sem áudio inicial
      final cardDual = Flashcard(
        id: 'card-dual-audio',
        front: 'What is public key cryptography?',
        back: 'Criptografia que utiliza um par de chaves pública e privada.',
      );

      final deck = FlashcardDeck(
        id: 'deck-dual-audio',
        title: 'Criptografia Avançada',
        subject: 'Segurança',
        description: 'Teste de áudio independente frente e verso.',
        cards: [cardDual],
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(deck);

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
      );

      // Inicia sessão de estudos
      await tester.tap(find.text('Estudar Agora 🚀').first);
      await tester.pumpAndSettle();

      // Na Frente (Pergunta): deve exibir 'Gerar Áudio com IA ✨'
      expect(find.text('What is public key cryptography?'), findsOneWidget);
      expect(find.text('Gerar Áudio com IA ✨'), findsOneWidget);

      // Clica para gerar áudio da Pergunta
      await tester.tap(find.text('Gerar Áudio com IA ✨'));
      await tester.pumpAndSettle();

      // Agora a Frente deve estar reproduzindo ou pronta para ouvir ('Ouvindo Áudio...' ou 'Ouvir Áudio 🔊')
      expect(find.textContaining('Ouv'), findsOneWidget);
      await AudioService().stopAudio();
      await tester.pumpAndSettle();
      expect(find.text('Ouvir Áudio 🔊'), findsOneWidget);

      // Vira o cartão para o Verso (Resposta)
      await tester.tap(find.text('Toque para revelar a resposta 👆'));
      await tester.pumpAndSettle();

      // No Verso: como o áudio gerado foi apenas da pergunta, o verso AINDA DEVE EXIBIR 'Gerar Áudio com IA ✨'!
      expect(find.text('Criptografia que utiliza um par de chaves pública e privada.'), findsOneWidget);
      expect(find.text('Gerar Áudio com IA ✨'), findsOneWidget);

      // Clica para gerar áudio da Resposta
      await tester.tap(find.text('Gerar Áudio com IA ✨'));
      await tester.pumpAndSettle();

      // Agora o Verso também possui seu próprio áudio
      expect(find.textContaining('Ouv'), findsOneWidget);
      await AudioService().stopAudio();
      await tester.pumpAndSettle();
      expect(find.text('Ouvir Áudio 🔊'), findsOneWidget);

      // Desvira de volta para a Frente: a frente AINDA possui o áudio da pergunta intacto!
      await tester.tap(find.text('Toque para desvirar 🔄'));
      await tester.pumpAndSettle();
      expect(find.text('What is public key cryptography?'), findsOneWidget);
      expect(find.text('Ouvir Áudio 🔊'), findsOneWidget);

      // Abre o modal de edição e verifica os dois controles (Pergunta e Resposta)
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Flashcard ✍️'), findsOneWidget);
      expect(find.text('Pergunta (Frente)'), findsOneWidget);
      expect(find.text('Resposta (Verso)'), findsOneWidget);
      expect(find.text('Áudio Anexado'), findsOneWidget);

      // Alterna para a aba Resposta no modal
      await tester.tap(find.text('Resposta (Verso)'));
      await tester.pumpAndSettle();
      expect(find.text('Áudio Anexado'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await TestAppHarness.drainAsync(tester);
    });

    test('22. Flashcard.needsReview and FlashcardDeck.cardsToReview skip already learned cards and prioritize unlearned ones', () {
      final now = DateTime(2026, 11, 24, 18, 0);
      final learnedEasy = Flashcard(
        id: 'learned-easy',
        front: 'Já dominado',
        back: 'Resposta dominada',
        difficulty: 'easy',
        reviewCount: 3,
        lastReviewed: now.subtract(const Duration(days: 5)),
      );
      final studiedGoodToday = Flashcard(
        id: 'studied-good-today',
        front: 'Estudado hoje com Bom',
        back: 'Em consolidação',
        difficulty: 'good',
        reviewCount: 1,
        lastReviewed: now.subtract(const Duration(hours: 2)),
      );
      final dueGood = Flashcard(
        id: 'due-good',
        front: 'Revisão espaçada vencida',
        back: 'Revisar após 24h',
        difficulty: 'good',
        reviewCount: 1,
        lastReviewed: now.subtract(const Duration(hours: 30)),
      );
      final hardCard = Flashcard(
        id: 'hard-card',
        front: 'Cartão difícil',
        back: 'Precisa aprender',
        difficulty: 'hard',
        reviewCount: 1,
        lastReviewed: now.subtract(const Duration(minutes: 10)),
      );
      final unreviewedCard = Flashcard(
        id: 'new-card',
        front: 'Cartão novo',
        back: 'Nunca estudado',
        difficulty: 'unreviewed',
      );

      expect(learnedEasy.needsReview(referenceDate: now), isFalse);
      expect(studiedGoodToday.needsReview(referenceDate: now), isFalse);
      expect(dueGood.needsReview(referenceDate: now), isTrue);
      expect(hardCard.needsReview(referenceDate: now), isTrue);
      expect(unreviewedCard.needsReview(referenceDate: now), isTrue);

      final deck = FlashcardDeck(
        id: 'priority-deck',
        title: 'Baralho Prioridade',
        subject: 'Teste',
        description: 'Teste de fila',
        cards: [learnedEasy, studiedGoodToday, dueGood, unreviewedCard, hardCard],
        createdAt: now,
      );

      final queue = deck.cardsToReview(referenceDate: now);
      expect(queue.map((c) => c.id).toList(), equals(['hard-card', 'new-card', 'due-good']));
      expect(deck.pendingReviewCount(referenceDate: now), equals(3));
      expect(deck.isCompleted(referenceDate: now), isFalse);

      final masteredDeck = FlashcardDeck(
        id: 'done-deck',
        title: 'Baralho Concluído',
        subject: 'Teste',
        description: 'Tudo dominado',
        cards: [learnedEasy, studiedGoodToday],
        createdAt: now,
      );
      expect(masteredDeck.isCompleted(referenceDate: now), isTrue);
    });

    testWidgets('23. FlashcardsScreen filters completed decks, opens review queue, skips mastered cards, and requeues hard cards only',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final completedDeck = FlashcardDeck(
        id: 'completed-deck-test',
        title: 'Redes TCP/IP Completo',
        subject: 'Redes',
        description: 'Baralho totalmente dominado.',
        cards: [
          Flashcard(
            id: 'net-1',
            front: 'Qual camada trata roteamento IP?',
            back: 'Camada 3 (Rede)',
            difficulty: 'easy',
            reviewCount: 2,
            lastReviewed: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );

      final mixedDeck = FlashcardDeck(
        id: 'mixed-deck-test',
        title: 'Banco de Dados SQL',
        subject: 'Dados',
        description: 'Mistura dominados e pendentes.',
        cards: [
          Flashcard(
            id: 'sql-easy',
            front: 'Cartão Já Dominado SQL',
            back: 'Não deve aparecer',
            difficulty: 'easy',
            reviewCount: 2,
            lastReviewed: DateTime.now(),
          ),
          Flashcard(
            id: 'sql-pending',
            front: 'O que é ACID em transações?',
            back: 'Atomicidade, Consistência, Isolamento e Durabilidade.',
            difficulty: 'unreviewed',
          ),
        ],
        createdAt: DateTime.now(),
      );

      await SupabaseService.saveFlashcardDeck(completedDeck);
      await SupabaseService.saveFlashcardDeck(mixedDeck);

      await TestAppHarness.pumpInHarness(
        tester,
        const FlashcardsScreen(),
        screenSize: const Size(1440, 960),
      );
      await tester.pumpAndSettle();

      // Filtra apenas por Completos / Dominados
      await tester.tap(find.byKey(const Key('filter_status_completed')));
      await tester.pumpAndSettle();
      expect(find.text('Redes TCP/IP Completo'), findsOneWidget);
      expect(find.text('Banco de Dados SQL'), findsNothing);
      expect(find.text('Completo ✓'), findsOneWidget);

      // Volta para Todos e abre a Central de Revisão Inteligente
      await tester.tap(find.byKey(const Key('filter_status_all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_review_queue_button')));
      await tester.pumpAndSettle();
      expect(find.text('Central de Revisão Inteligente'), findsOneWidget);
      expect(find.text('Banco de Dados SQL'), findsOneWidget);

      // Fecha modal e estuda o baralho misto: deve pular 'Cartão Já Dominado SQL' e mostrar apenas 'O que é ACID em transações?'
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      // Busca especificamente por 'ACID' para isolar o baralho misto e iniciar estudo
      await tester.enterText(find.byType(TextField).first, 'Banco de Dados SQL');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Estudar Agora 🚀').first);
      await tester.pumpAndSettle();

      expect(find.text('O que é ACID em transações?'), findsOneWidget);
      expect(find.text('Cartão Já Dominado SQL'), findsNothing);
      expect(find.textContaining('Cartão 1 de 1'), findsOneWidget);

      // Vira e marca como Difícil -> cartão volta para a fila!
      await tester.tap(find.text('Ver Resposta (Virar Cartão) 👆'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Difícil 🔴'));
      await tester.pumpAndSettle();

      expect(find.text('O que é ACID em transações?'), findsOneWidget);
      expect(find.textContaining('Cartão difícil voltou na fila'), findsOneWidget);

      // Agora marca como Fácil -> conclui o baralho e não volta mais!
      await tester.tap(find.text('Ver Resposta (Virar Cartão) 👆'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fácil 🟢'));
      await tester.pumpAndSettle();

      expect(find.text('Baralho Completo! 🎉'), findsOneWidget);
      await TestAppHarness.drainAsync(tester);
    });
  });
}
