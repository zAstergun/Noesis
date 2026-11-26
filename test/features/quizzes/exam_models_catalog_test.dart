import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/flashcards/models/flashcard_model.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/quizzes/data/exam_models_catalog.dart';
import 'package:noesis/features/quizzes/data/saved_exams_repository.dart';
import 'package:noesis/features/quizzes/quiz_screen.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    await SavedExamsRepository.clearForTest();
  });

  test('ExamModelsCatalog contains 39 presets covering all 38 .md files', () async {
    expect(ExamModelsCatalog.models.length, 39);

    final ids = <String>{};
    final assetPaths = <String>{};
    for (final model in ExamModelsCatalog.models) {
      expect(ids.add(model.id), isTrue, reason: 'Duplicate model id: ${model.id}');
      assetPaths.add(model.assetPath);
      expect(model.recommendedCount, inInclusiveRange(3, 200));
      expect(File(model.assetPath).existsSync(), isTrue, reason: 'Missing file: ${model.assetPath}');

      final loaded = await ExamModelsCatalog.loadBlueprint(model);
      expect(loaded, isNotNull, reason: 'Could not load asset: ${model.assetPath}');
      expect(loaded!.trim().length, greaterThan(500));
    }
    expect(assetPaths.length, 38);
  });

  test('GeminiService.generateQuiz supports generating up to 200 questions', () async {
    GeminiService.apiKey = '';
    GeminiService.provider = 'google';

    int lastProgress = 0;
    final questions = await GeminiService.generateQuiz(
      subject: 'Segurança da Informação',
      topic: 'CompTIA Security+ SY0-701',
      examModelName: 'CompTIA Security+',
      numberOfQuestions: 200,
      onProgress: (generated, total) {
        lastProgress = generated;
        expect(total, 200);
      },
    );

    expect(questions.length, 200);
    expect(lastProgress, 200);
    expect(questions.first['options'], isA<List>());
  });

  test('GeminiService JSON parser handles trailing commas and truncated arrays', () {
    const malformedWithTrailingCommasAndTruncation = '''
```json
[
  {
    "question": "Questão 1 do ENEM",
    "code_snippet": "",
    "options": ["A", "B", "C", "D", "E",],
    "correct_index": 2,
    "explanation": "Explicação 1.",
  },
  {
    "question": "Questão 2 completa",
    "options": ["A", "B", "C", "D", "E"],
    "correct_index": 0,
    "explanation": "Explicação 2."
  },
  {
    "question": "Questão 3 truncada pelo limite de tokens...
''';

    final parsed = GeminiService.parseJsonPayloadForTest(malformedWithTrailingCommasAndTruncation);
    expect(parsed.length, 2);
    expect(parsed[0]['question'], 'Questão 1 do ENEM');
    expect(parsed[1]['question'], 'Questão 2 completa');
  });

  testWidgets('QuizScreen allows selecting exam model, 200 Qs, and opening 200Q map', (tester) async {
    await TestAppHarness.pumpInHarness(tester, const QuizScreen());

    // Select Vestibulares BR category and ENEM model
    final vestCat = find.textContaining('Vestibulares BR');
    await tester.ensureVisible(vestCat);
    await tester.tap(vestCat);
    await tester.pumpAndSettle();

    final enemChip = find.text('ENEM (INEP)');
    expect(enemChip, findsOneWidget);
    await tester.ensureVisible(enemChip);
    await tester.tap(enemChip);
    await tester.pumpAndSettle();

    expect(find.textContaining('Modelo Selecionado: ENEM (INEP)'), findsOneWidget);
    // Selecting ENEM must auto-configure 90 questions immediately
    expect(find.text('Criar Prova Interativa (90 Q) com IA'), findsOneWidget);

    // Quick toggle button switches between Treino Rápido (15 Q) and Prova Completa (90 Q)
    await tester.tap(find.text('Treino Rápido (15 Q)'));
    await tester.pumpAndSettle();
    expect(find.text('Criar Prova Interativa (15 Q) com IA'), findsOneWidget);
    expect(find.text('Prova Completa (90 Q)'), findsOneWidget);

    // Select 200 Q pill
    final q200Pill = find.text('200 Q');
    await tester.ensureVisible(q200Pill);
    await tester.tap(q200Pill);
    await tester.pumpAndSettle();

    expect(find.text('Criar Prova Interativa (200 Q) com IA'), findsOneWidget);

    // Load 200Q exam into QuizScreen runner and verify Question Map navigation
    GeminiService.apiKey = '';
    GeminiService.provider = 'google';
    final questions200 = await GeminiService.generateQuiz(
      subject: 'Ensino Médio · ENEM',
      topic: 'ENEM',
      examModelName: 'ENEM (INEP)',
      numberOfQuestions: 200,
    );
    QuizScreen.startQuiz(
      title: 'ENEM Simulado Completo',
      subject: 'Ensino Médio · ENEM',
      questions: questions200,
      difficulty: 'Médio / Prático',
    );
    await tester.pumpAndSettle();

    expect(find.text('Questão 1 / 200'), findsOneWidget);
    expect(find.text('1/200'), findsOneWidget);

    // Open Question Map and jump to Q200
    await tester.tap(find.text('1/200'));
    await tester.pumpAndSettle();
    expect(find.text('Mapa da Prova (200 questões)'), findsOneWidget);

    final q200Tile = find.text('200');
    await tester.scrollUntilVisible(
      q200Tile,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(q200Tile);
    await tester.pumpAndSettle();

    expect(find.text('Questão 200 / 200'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('QuizScreen formats supporting text, Fonte, LaTeX math, clean question stem, and opens comparative AI review modal', (tester) async {
    GeminiService.apiKey = '';
    GeminiService.provider = 'google';
    await TestAppHarness.pumpInHarness(tester, const QuizScreen());

    QuizScreen.startQuiz(
      title: 'ENEM Matemática e Geografia',
      subject: 'Ensino Médio · ENEM',
      questions: [
        {
          'question':
              'Texto-base:\n> Um investidor aplica R\$ 10.000,00 a uma taxa de \$10\\%\$ ao ano.\nFonte: IBGE, 2024.\n\nComando:\nConsiderando a dinâmica financeira, o montante após 3 anos é',
          'code_snippet': '',
          'options': [
            'A) R\$ 13.000,00',
            'B) R\$ 13.310,00',
            'C) R\$ 14.000,00',
          ],
          'correct_index': 1,
          'explanation': '**Gabarito B:** Capitalização composta a 10% resulta em R\$ 13.310,00.',
          'rag_sources': ['ENEM (INEP)', 'Matemática Financeira'],
        },
        {
          'question': 'Qual bioma brasileiro sofre maior pressão da fronteira agrícola do Cerrado?',
          'code_snippet': '',
          'options': [
            'Pampa',
            'Cerrado',
            'Caatinga',
          ],
          'correct_index': 1,
          'explanation': 'O Cerrado concentra a expansão do agronegócio exportador.',
          'rag_sources': ['ENEM (INEP)', 'Geografia'],
        },
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('TEXTO DE APOIO'), findsOneWidget);
    expect(find.text('COMANDO'), findsNothing);
    expect(find.textContaining('Considerando a dinâmica financeira'), findsOneWidget);
    expect(find.text('Fonte: IBGE, 2024.'), findsOneWidget);
    // LaTeX $10\%$ cleaned to 10%, currency R$ 10.000,00 preserved
    expect(find.textContaining('10%'), findsOneWidget);
    expect(find.textContaining('R\$ 10.000,00'), findsOneWidget);
    expect(find.textContaining(r'$10\%$'), findsNothing);
    // Prefix stripped
    expect(find.text('R\$ 13.310,00'), findsOneWidget);
    expect(find.textContaining('B) R\$'), findsNothing);

    // Answer Q1 wrong (option 0) and go to Q2 and answer right (option 1)
    await tester.tap(find.text('R\$ 13.000,00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrado'));
    await tester.pumpAndSettle();

    // Finish exam -> opens comparative report & AI review modal
    await tester.tap(find.text('Finalizar Prova'));
    await tester.pumpAndSettle();

    expect(find.text('REVIEW DA IA · O QUE MELHORAR'), findsOneWidget);
    expect(find.text('COMPARATIVO DAS QUESTÕES'), findsOneWidget);
    expect(find.text('Erros (1)'), findsOneWidget);
    expect(find.text('Acertos (1)'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  test('ExamModelsCatalog resolves sequential contiguous discipline blocks without alternating', () {
    final enem = ExamModelsCatalog.findByName('ENEM (INEP)')!;
    final schedule90 = enem.resolveSectionPerQuestion(90);
    expect(schedule90.length, 90);
    // Caderno 1: 23 Linguagens -> 23 Humanas -> 22 Natureza -> 22 Matemática (sem misturar)
    final lingCount = schedule90.take(23).where((d) => d == 'Linguagens, Códigos e suas Tecnologias').length;
    expect(lingCount, 23);
    expect(schedule90[23], 'Ciências Humanas e suas Tecnologias');
    expect(schedule90.last, 'Matemática e suas Tecnologias');

    // Mudança de bloco acontece exatamente 3 vezes em toda a prova (4 cadernos contíguos)
    int transitions = 0;
    for (int i = 1; i < schedule90.length; i++) {
      if (schedule90[i] != schedule90[i - 1]) transitions++;
    }
    expect(transitions, 3);

    // Todos os 39 modelos geram escalas sequenciais válidas
    for (final m in ExamModelsCatalog.models) {
      expect(m.sections, isNotEmpty, reason: 'Missing sections on ${m.id}');
      final sch = m.resolveSectionPerQuestion(m.recommendedCount);
      expect(sch.length, m.recommendedCount);
    }
  });

  testWidgets('QuizScreen detects Texto de Apoio with trailing Fonte and incomplete ENEM stem and renders discipline tag', (tester) async {
    GeminiService.apiKey = '';
    GeminiService.provider = 'google';
    await TestAppHarness.pumpInHarness(tester, const QuizScreen());

    QuizScreen.startQuiz(
      title: 'ENEM Linguagens',
      subject: 'Ensino Médio · ENEM',
      questions: [
        {
          'discipline': 'Linguagens, Códigos e suas Tecnologias',
          'question':
              'O trecho a seguir é parte de uma crônica moderna que aborda o impacto das novas tecnologias de comunicação nas relações cotidianas.\n\n'
              '"O elevador parecia um confessionário silencioso, onde todos evitavam o olhar do outro, absortos no brilho azulado de suas telas de vidro. Antes, dizíamos ao menos um \'bom dia\' protocolar; hoje, o silêncio é preenchido pelo scroll infinito de feeds que nunca acabam, tornando-nos estranhos que habitam o mesmo metro quadrado."\n\n'
              'A linguagem e a temática do texto construído revelam uma reflexão crítica sobre\n\n'
              'Fonte: Acervo de literatura contemporânea.',
          'code_snippet': '',
          'options': [
            'a ampliação dos laços afetivos presenciais',
            'o isolamento relacional mediado pelas telas',
            'a extinção da língua portuguesa escrita',
          ],
          'correct_index': 1,
          'explanation': 'A crônica retrata o distanciamento presencial causado pela imersão nas telas.',
          'rag_sources': ['ENEM (INEP)', 'Linguagens, Códigos e suas Tecnologias'],
        },
        {
          'discipline': 'Ciências da Natureza e suas Tecnologias · Física',
          'supporting_text': 'Uma ambulância se aproxima com a sirene ligada em direção a um observador em repouso.',
          'source_citation': 'Fonte: Adaptado de Halliday & Resnick.',
          'question': 'Durante a aproximação, a frequência sonora percebida pelo observador é',
          'code_snippet': '',
          'options': [
            'maior que a emitida pela fonte',
            'menor que a emitida pela fonte',
          ],
          'correct_index': 0,
          'explanation': 'Pelo efeito Doppler, a aproximação relativa aumenta a frequência aparente.',
          'rag_sources': ['ENEM (INEP)', 'Física'],
        },
      ],
    );
    await tester.pumpAndSettle();

    // Screenshot 2 regression check: TEXTO DE APOIO + Fonte inside it + discipline pill + stem outside
    expect(find.text('Linguagens, Códigos e suas Tecnologias'), findsOneWidget);
    expect(find.text('TEXTO DE APOIO'), findsOneWidget);
    expect(find.text('Fonte: Acervo de literatura contemporânea.'), findsOneWidget);
    expect(
      find.textContaining('A linguagem e a temática do texto construído revelam uma reflexão crítica sobre'),
      findsOneWidget,
    );

    // Avança para Q2 e valida supporting_text estruturado + tag da nova disciplina
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.text('Ciências da Natureza e suas Tecnologias · Física'), findsOneWidget);
    expect(find.text('TEXTO DE APOIO'), findsOneWidget);
    expect(find.text('Fonte: Adaptado de Halliday & Resnick.'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  test('ExamCategory.all starts with popular exams like ENEM, FUVEST, and TOEFL before IT certs', () {
    final all = ExamModelsCatalog.byCategory(ExamCategory.all);
    final topIds = all.take(10).map((e) => e.id).toList();
    expect(topIds.first, 'enem');
    expect(topIds, containsAll(['enem', 'fuvest', 'unicamp', 'unesp', 'oab', 'toefl', 'ielts', 'sat']));
    final enemIdx = all.indexWhere((m) => m.id == 'enem');
    final comptiaIdx = all.indexWhere((m) => m.id == 'comptia_security_plus');
    expect(enemIdx, lessThan(comptiaIdx));
  });

  testWidgets('QuizScreen shows Tempo Esgotado alert when timer hits zero', (tester) async {
    GeminiService.apiKey = '';
    await TestAppHarness.pumpInHarness(tester, const QuizScreen());

    QuizScreen.startQuiz(
      title: 'Simulado Rápido',
      subject: 'Ensino Médio · ENEM',
      durationSeconds: 1,
      questions: [
        {
          'discipline': 'Matemática e suas Tecnologias',
          'question': 'Quanto é 2 + 2?',
          'options': ['3', '4', '5'],
          'correct_index': 1,
          'explanation': '2 + 2 = 4.',
        },
      ],
    );
    await tester.pumpAndSettle();

    // Avança 2 segundos para disparar a expiração do timer
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Tempo Esgotado!'), findsOneWidget);
    expect(find.text('00:00 · Esgotado'), findsOneWidget);

    await tester.tap(find.text('Continuar Revisando'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo Esgotado!'), findsNothing);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('QuizScreen saves completed exams, switches via top toggle, and compares performance across attempts', (tester) async {
    GeminiService.apiKey = '';
    await TestAppHarness.pumpInHarness(tester, const QuizScreen());

    // Pré-popula 1 tentativa anterior do mesmo simulado com 0% para validar comparação
    final sampleQuestions = [
      {
        'discipline': 'Linguagens',
        'question': 'Qual é a alternativa correta?',
        'options': ['Errada', 'Certa'],
        'correct_index': 1,
        'explanation': 'B é correta.',
      },
      {
        'discipline': 'Matemática',
        'question': 'Quanto é 5 × 5?',
        'options': ['25', '30'],
        'correct_index': 0,
        'explanation': '5 × 5 = 25.',
      },
    ];
    await SavedExamsRepository.saveAttempt(
      SavedExamsRepository.buildAttempt(
        id: 'prev-attempt-1',
        subject: 'Ensino Médio · ENEM',
        topic: 'ENEM Revisão',
        difficulty: 'Médio / Prático',
        questions: sampleQuestions,
        userAnswers: const {0: 0, 1: 1}, // 0/2 = 0%
        elapsedSeconds: 95,
        targetTotalCount: 2,
      ),
      syncRemote: false,
    );

    // Nova execução acertando 2/2 = 100%
    QuizScreen.startQuiz(
      title: 'ENEM Revisão',
      subject: 'Ensino Médio · ENEM',
      questions: sampleQuestions,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Certa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();

    // Finalizar -> salva automaticamente e exibe comparação (+100% vs última)
    await tester.tap(find.text('Finalizar Prova'));
    await tester.pumpAndSettle();

    expect(find.text('EVOLUÇÃO NESTE SIMULADO:'), findsOneWidget);
    expect(find.text('+100% vs última (0%)'), findsOneWidget);

    // Volta para o gerador e usa o botão superior para alternar para Simulados Realizados (2)
    await tester.tap(find.text('Novo Simulado').last);
    await tester.pumpAndSettle();

    final toggleHistoryBtn = find.text('Realizados (2)');
    expect(toggleHistoryBtn, findsOneWidget);
    await tester.tap(toggleHistoryBtn);
    await tester.pumpAndSettle();

    expect(find.text('SIMULADOS REALIZADOS & EVOLUÇÃO'), findsOneWidget);
    expect(find.text('DESEMPENHO POR SIMULADO (ÚLTIMAS REALIZAÇÕES)'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('Última: 100%'), findsOneWidget);

    // Reabre questões no Modo Revisão
    await tester.tap(find.text('Revisar Questões').first);
    await tester.pumpAndSettle();
    expect(find.text('Modo Revisão'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  test('SavedExamAttempt.fromSupabaseRow decodes full and legacy noesis_quizzes rows', () {
    final richRow = {
      'id': '00000000-0000-0000-0000-000000000123',
      'attempt_key': 'sim-1795559999',
      'group_key': 'model:enem',
      'exam_model_id': 'enem',
      'exam_model_name': 'ENEM (INEP)',
      'title': 'ENEM (INEP)',
      'subject': 'Ensino Médio · ENEM',
      'topic': 'ENEM 90Q',
      'difficulty': 'Médio / Prático',
      'target_total_count': 90,
      'questions_data': [
        {
          'discipline': 'Linguagens',
          'question': 'Pergunta 1',
          'options': ['A', 'B'],
          'correct_index': 1,
        },
      ],
      'user_answers': {'0': 1},
      'correct_count': 1,
      'wrong_count': 0,
      'blank_count': 0,
      'score_percentage': 100.0,
      'time_spent_seconds': 42,
      'time_expired': false,
      'ai_review_markdown': '### 1. Diagnóstico\nBom resultado.',
      'completed_at': '2026-11-24T20:10:00Z',
    };

    final parsedRich = SavedExamAttempt.fromSupabaseRow(richRow);
    expect(parsedRich.id, 'sim-1795559999');
    expect(parsedRich.groupKey, 'model:enem');
    expect(parsedRich.examModelId, 'enem');
    expect(parsedRich.examModelName, 'ENEM (INEP)');
    expect(parsedRich.userAnswers[0], 1);
    expect(parsedRich.aiReviewMarkdown, contains('Bom resultado'));
    expect(parsedRich.scorePercentage, 100.0);

    final legacyRow = {
      'id': 'legacy-uuid-1',
      'title': 'FUVEST 2025',
      'subject': 'Vestibular',
      'questions_data': [
        {'question': 'Q1', 'options': ['A', 'B'], 'correct_index': 0},
        {'question': 'Q2', 'options': ['A', 'B'], 'correct_index': 1},
      ],
      'score_percentage': 50.0,
      'time_spent_seconds': 180,
      'completed_at': '2026-11-20T12:00:00Z',
    };

    final parsedLegacy = SavedExamAttempt.fromSupabaseRow(legacyRow);
    expect(parsedLegacy.id, 'legacy-uuid-1');
    expect(parsedLegacy.correctCount, 1);
    expect(parsedLegacy.wrongCount, 1);
    expect(parsedLegacy.elapsedSeconds, 180);
  });

  test('QuizScreen.buildStudyReferenceContext consolidates flashcards, notebooks, and extra document text', () {
    final deck = FlashcardDeck(
      id: 'deck-test',
      title: 'Biologia Celular',
      subject: 'Biologia',
      description: 'Organelas e respiração',
      createdAt: DateTime(2026),
      cards: [
        Flashcard(
          id: 'c1',
          front: 'Qual organela produz ATP?',
          back: 'Mitocôndria.',
          tags: ['Citologia'],
        ),
      ],
    );
    final notebook = StudyNotebook(
      id: 'nb-test',
      title: 'Resumo de Ecologia',
      subject: 'Biologia',
      notes: [
        StudyNote(
          id: 'n1',
          notebookId: 'nb-test',
          title: 'Ciclo do Nitrogênio',
          content: 'Fixação biológica por Rhizobium.',
          tags: ['Ecologia'],
        ),
      ],
    );

    final contextText = QuizScreen.buildStudyReferenceContext(
      decks: [deck],
      notebooks: [notebook],
      documentText: 'Edital complementar ENEM.',
    );

    expect(contextText, isNotNull);
    expect(contextText, contains('BARALHO DE FLASHCARDS ANEXADO: Biologia Celular'));
    expect(contextText, contains('Qual organela produz ATP?'));
    expect(contextText, contains('CADERNO DE ESTUDOS ANEXADO: Resumo de Ecologia'));
    expect(contextText, contains('Fixação biológica por Rhizobium.'));
    expect(contextText, contains('Edital complementar ENEM.'));
  });

  testWidgets('QuizScreen allows attaching flashcard decks and notebooks from pickers', (tester) async {
    final testDeck = FlashcardDeck(
      id: 'deck-picker-test',
      title: 'Criptografia & Certificação Security+',
      subject: 'Criptografia',
      description: 'Baralho para picker',
      cards: [
        Flashcard(id: 'c-pick-1', front: 'AES?', back: 'Cifra simétrica.'),
      ],
      createdAt: DateTime.now(),
    );
    final testNb = StudyNotebook(
      id: 'nb-picker-test',
      title: 'Arquitetura Cloud & Infraestrutura',
      subject: 'Tecnologia',
      description: 'Caderno para picker',
      notes: [
        StudyNote(
          id: 'n-pick-1',
          notebookId: 'nb-picker-test',
          title: 'VPC Subnets',
          content: 'Subnets públicas e privadas.',
        ),
      ],
    );
    await SupabaseService.saveFlashcardDeck(testDeck);
    await SupabaseService.saveNotebook(testNb);
    addTearDown(() async {
      await SupabaseService.deleteFlashcardDeck(testDeck.id);
      await SupabaseService.deleteNotebook(testNb.id);
    });

    await TestAppHarness.pumpInHarness(tester, const QuizScreen());

    final attachDecksBtn = find.text('Anexar Flashcards');
    await tester.ensureVisible(attachDecksBtn);
    await tester.tap(attachDecksBtn);
    await tester.pumpAndSettle();

    expect(find.text('Anexar Baralhos de Flashcards'), findsOneWidget);
    final deckTile = find.text('Criptografia & Certificação Security+');
    expect(deckTile, findsOneWidget);
    await tester.tap(deckTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Flashcards (1)'), findsOneWidget);

    final attachNbBtn = find.text('Anexar Cadernos');
    await tester.ensureVisible(attachNbBtn);
    await tester.tap(attachNbBtn);
    await tester.pumpAndSettle();

    expect(find.text('Anexar Cadernos de Estudo'), findsOneWidget);
    final nbTile = find.text('Arquitetura Cloud & Infraestrutura');
    expect(nbTile, findsOneWidget);
    await tester.tap(nbTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Cadernos (1)'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('QuizScreen highlights Modo Livre card and toggles cleanly between free and official model modes',
      (tester) async {
    await TestAppHarness.pumpInHarness(
      tester,
      const QuizScreen(),
      screenSize: const Size(1280, 900),
    );

    expect(find.byKey(const Key('quiz_mode_selector_bar')), findsOneWidget);
    expect(find.byKey(const Key('quiz_official_model_mode_card')), findsOneWidget);
    expect(find.byKey(const Key('quiz_free_mode_card')), findsOneWidget);
    expect(find.text('Modo Livre (Sem Modelo)'), findsOneWidget);

    // Ativa Modo Livre
    await tester.ensureVisible(find.byKey(const Key('quiz_free_mode_card')));
    await tester.tap(find.byKey(const Key('quiz_free_mode_card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quiz_free_mode_active_banner')), findsOneWidget);
    expect(find.text('Modo Livre Ativo · Criação Personalizada'), findsOneWidget);

    // Retorna para Modelo de Prova Oficial
    await tester.tap(find.byKey(const Key('quiz_official_model_mode_card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiz_free_mode_active_banner')), findsNothing);
    expect(find.text('ENEM (INEP)'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });
}
