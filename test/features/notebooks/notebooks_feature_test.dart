import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/supabase_service.dart';
import 'package:noesis/features/notebooks/models/notebook_model.dart';
import 'package:noesis/features/notebooks/notebooks_screen.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  group('Feature: Cadernos de Estudo & Anotações com Imagens e Links', () {
    test('1. StudyNotebook, StudyNote and StudyLink models serialize and extract images correctly', () {
      final imgLink = StudyLink(
        id: 'link-1',
        url: 'https://images.unsplash.com/photo-example.png',
        title: 'Diagrama de Arquitetura',
        isImage: true,
      );

      final docLink = StudyLink(
        id: 'link-2',
        url: 'https://aws.amazon.com/vpc/',
        title: 'AWS VPC Docs',
        isImage: false,
      );

      final note = StudyNote(
        id: 'note-1',
        notebookId: 'nb-1',
        title: 'Anotação de Teste',
        content: '# Título\nTexto explicativo com imagem markdown ![figura](https://example.com/inline-diagram.jpg)',
        links: [imgLink, docLink],
        tags: ['Redes', 'Cloud'],
      );

      final notebook = StudyNotebook(
        id: 'nb-1',
        title: 'Sistemas Distribuídos',
        subject: 'Tecnologia',
        description: 'Caderno de estudo sobre redes.',
        notes: [note],
      );

      expect(notebook.noteCount, equals(1));
      expect(notebook.totalLinksCount, equals(2));
      // Deve extrair a imagem da lista de links E a imagem markdown inline!
      expect(note.allImageUrls.length, equals(2));
      expect(note.allImageUrls, contains('https://images.unsplash.com/photo-example.png'));
      expect(note.allImageUrls, contains('https://example.com/inline-diagram.jpg'));
      expect(note.generalLinks.length, equals(1));
      expect(note.generalLinks.first.title, equals('AWS VPC Docs'));

      // Teste de serialização
      final jsonStr = notebook.toJson();
      final deserialized = StudyNotebook.fromJson(jsonStr);
      expect(deserialized.id, equals('nb-1'));
      expect(deserialized.title, equals('Sistemas Distribuídos'));
      expect(deserialized.notes.first.title, equals('Anotação de Teste'));
    });

    test('2. SupabaseService loads pre-seeded notebooks, saves and deletes notebooks and notes', () async {
      final initialNotebooks = await SupabaseService.getNotebooks();
      expect(initialNotebooks.isNotEmpty, isTrue);

      final testNb = StudyNotebook(
        id: 'nb-test-custom',
        title: 'Algoritmos e Estruturas de Dados',
        subject: 'Ciência da Computação',
        description: 'Grafos, árvores balanceadas e complexidade.',
        notes: [],
      );

      await SupabaseService.saveNotebook(testNb);
      var notebooks = await SupabaseService.getNotebooks();
      expect(notebooks.any((n) => n.id == 'nb-test-custom'), isTrue);

      // Adicionar anotação
      final newNote = StudyNote(
        id: 'note-algo-1',
        notebookId: 'nb-test-custom',
        title: 'Dijkstra & A* Pathfinding',
        content: 'Algoritmo de caminho mínimo usando fila de prioridade.',
        links: [
          StudyLink(
            id: 'link-graph-img',
            url: 'https://images.unsplash.com/photo-graph.jpg',
            title: 'Grafo Ponderado',
            isImage: true,
          ),
        ],
      );

      await SupabaseService.saveNote('nb-test-custom', newNote);
      notebooks = await SupabaseService.getNotebooks();
      final updatedNb = notebooks.firstWhere((n) => n.id == 'nb-test-custom');
      expect(updatedNb.notes.length, equals(1));
      expect(updatedNb.notes.first.title, equals('Dijkstra & A* Pathfinding'));

      // Excluir anotação
      await SupabaseService.deleteNote('nb-test-custom', 'note-algo-1');
      notebooks = await SupabaseService.getNotebooks();
      expect(notebooks.firstWhere((n) => n.id == 'nb-test-custom').notes.isEmpty, isTrue);

      // Excluir caderno
      await SupabaseService.deleteNotebook('nb-test-custom');
      notebooks = await SupabaseService.getNotebooks();
      expect(notebooks.any((n) => n.id == 'nb-test-custom'), isFalse);
    });

    testWidgets('3. NotebooksScreen renders notebooks list, filters and opens a notebook with image and link rendering', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await TestAppHarness.pumpInHarness(
        tester,
        const NotebooksScreen(),
      );

      expect(find.text('Cadernos de Estudo 📚'), findsOneWidget);
      expect(find.text('Novo Caderno'), findsOneWidget);
      expect(find.text('Cadernos Ativos'), findsOneWidget);
      expect(find.text('Anotações Totais'), findsOneWidget);

      // Deve listar o caderno pré-sementeado de Arquitetura Cloud
      expect(find.text('Arquitetura Cloud & Infraestrutura'), findsOneWidget);
      expect(find.text('Abrir Caderno 📖'), findsWidgets);

      // Abrir o primeiro caderno
      await tester.tap(find.text('Abrir Caderno 📖').first);
      await tester.pumpAndSettle();

      // Deve estar na visualização interna do caderno
      expect(find.text('Nova Anotação 📝'), findsOneWidget);
      expect(find.text('Topologia de Redes VPC & Subnets Públicas vs Privadas'), findsWidgets);

      // Deve renderizar a imagem do link que foi enviado!
      expect(find.text('Imagens Anexadas ao Estudo (1)'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Abrir Imagem'), findsOneWidget);

      // Deve renderizar o link de documentação oficial
      expect(find.text('Documentação Oficial Amazon VPC'), findsOneWidget);
      expect(find.text('Visitar'), findsOneWidget);

      // Testar botão de voltar à lista geral de cadernos
      await tester.tap(find.byTooltip('Voltar à lista de cadernos'));
      await tester.pumpAndSettle();

      expect(find.text('Cadernos de Estudo 📚'), findsOneWidget);
      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('4. NotebooksScreen allows creating a new notebook and adding a note with image link', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await TestAppHarness.pumpInHarness(
        tester,
        const NotebooksScreen(),
      );

      // Clicar em "Novo Caderno"
      await tester.tap(find.text('Novo Caderno'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Caderno de Estudo 📚'), findsOneWidget);
      expect(find.text('TÍTULO DO CADERNO *'), findsOneWidget);

      // Preencher formulário de caderno
      await tester.enterText(find.widgetWithText(TextField, 'Ex: Criptografia & Redes, Direito Constitucional...'), 'Direito Digital & LGPD');
      await tester.pumpAndSettle();

      // Salvar caderno
      await tester.tap(find.text('Criar Caderno'));
      await tester.pumpAndSettle();

      expect(find.text('Direito Digital & LGPD'), findsOneWidget);

      // Abrir o novo caderno
      final openButtons = find.text('Abrir Caderno 📖');
      await tester.tap(openButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Caderno vazio.'), findsOneWidget);

      // Clicar em "Nova Anotação 📝"
      await tester.tap(find.text('Nova Anotação 📝'));
      await tester.pumpAndSettle();

      expect(find.text('Nova Anotação 📝'), findsWidgets);
      expect(find.text('TÍTULO DA ANOTAÇÃO *'), findsOneWidget);
      expect(find.text('LINKS & IMAGENS ANEXADAS 🖼️'), findsOneWidget);

      // Preencher anotação
      await tester.enterText(find.widgetWithText(TextField, 'Ex: Resumo sobre Protocolos de Enlace e Criptografia...'), 'Bases Legais do Artigo 7º da LGPD');
      await tester.enterText(find.widgetWithText(TextField, 'Escreva suas notas de estudo aqui...\n\nVocê pode usar títulos (# Título), tópicos (* item), blocos de código (```codigo```) ou colar links.'), '### Resumo Executivo\nA LGPD estabelece dez bases legais autônomas para tratamento de dados pessoais.');

      // Adicionar link de imagem
      await tester.enterText(find.widgetWithText(TextField, 'https://.../diagrama.png'), 'https://images.unsplash.com/photo-lgpd-map.jpg');
      await tester.enterText(find.widgetWithText(TextField, 'Legenda da imagem (opcional)'), 'Mapa Mental das Bases Legais');
      await tester.tap(find.text('Adicionar Imagem'));
      await tester.pumpAndSettle();

      expect(find.text('Mapa Mental das Bases Legais'), findsOneWidget);

      // Salvar a anotação
      await tester.tap(find.text('Salvar Anotação 💾'));
      await tester.pumpAndSettle();

      // Verificar que a anotação e sua imagem renderizada agora aparecem na tela do caderno
      expect(find.text('Bases Legais do Artigo 7º da LGPD'), findsWidgets);
      expect(find.text('Imagens Anexadas ao Estudo (1)'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });
  });
}
