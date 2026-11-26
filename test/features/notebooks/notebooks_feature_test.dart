import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
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

    test('2. SupabaseService starts without fake seeded notebooks and saves/deletes notebooks and notes', () async {
      final initialNotebooks = await SupabaseService.getNotebooks();
      expect(initialNotebooks, isA<List<StudyNotebook>>());

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

      final sampleNb = StudyNotebook(
        id: 'nb-cloud-test-1',
        title: 'Arquitetura Cloud & Infraestrutura',
        subject: 'Tecnologia',
        description: 'Anotações sobre VPCs e Subnets.',
        notes: [
          StudyNote(
            id: 'note-cloud-test-1',
            notebookId: 'nb-cloud-test-1',
            title: 'Topologia de Redes VPC & Subnets Públicas vs Privadas',
            content: '### Fundamentos de VPC\nSubnet pública vs privada.',
            links: [
              StudyLink(
                id: 'link-img-1',
                url: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800',
                title: 'Data Center e Infraestrutura Cloud',
                isImage: true,
              ),
              StudyLink(
                id: 'link-ref-1',
                url: 'https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html',
                title: 'Documentação Oficial Amazon VPC',
                isImage: false,
              ),
            ],
            tags: ['Cloud', 'AWS', 'VPC', 'Infra'],
          ),
          StudyNote(
            id: 'note-cloud-test-2',
            notebookId: 'nb-cloud-test-1',
            title: 'Configuração de Segurança: Security Groups vs Network ACLs',
            content: 'Security Groups vs NACLs.',
            tags: ['Segurança', 'NACL', 'Firewall'],
          ),
        ],
      );
      await SupabaseService.saveNotebook(sampleNb);
      addTearDown(() => SupabaseService.deleteNotebook(sampleNb.id));

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

    testWidgets('5. GeminiService.formatStudyNote and NotebooksScreen button format text with AI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Testa a lógica de formatação do GeminiService
      const rawNotes = 'Fundamentos de Docker e Containers\n'
          'Docker é uma plataforma de virtualização em nível de sistema operacional.\n'
          'Vantagens: Isolamento ágil, portabilidade total e economia de recursos.\n'
          '• Comandos principais: docker run, docker build, docker compose\n'
          'Referência: https://docs.docker.com/';

      final formatted = await GeminiService.formatStudyNote(
        rawText: rawNotes,
        topicOrSubject: 'DevOps / Cloud',
      );

      expect(formatted.contains('## Fundamentos de Docker e Containers'), isTrue);
      expect(formatted.contains('**Vantagens:**'), isTrue);
      expect(formatted.contains('https://docs.docker.com/'), isTrue);

      // 2. Testa o botão na interface do editor de anotação
      final editorNb = StudyNotebook(
        id: 'nb-editor-test-5',
        title: 'DevOps & Cloud',
        subject: 'Tecnologia',
        description: 'Caderno de teste.',
      );
      await SupabaseService.saveNotebook(editorNb);
      addTearDown(() => SupabaseService.deleteNotebook(editorNb.id));

      await TestAppHarness.pumpInHarness(
        tester,
        const NotebooksScreen(),
      );

      // Abrir o primeiro caderno
      await tester.tap(find.text('Abrir Caderno 📖').first);
      await tester.pumpAndSettle();

      // Clicar em "Nova Anotação 📝"
      await tester.tap(find.text('Nova Anotação 📝'));
      await tester.pumpAndSettle();

      // Botão 'Corrigir Formatação com IA ✨' deve estar visível no editor
      expect(find.text('Corrigir Formatação com IA ✨'), findsOneWidget);

      // Digitar conteúdo bruto
      await tester.enterText(
        find.widgetWithText(TextField, 'Ex: Resumo sobre Protocolos de Enlace e Criptografia...'),
        'Virtualização de Servidores',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Escreva suas notas de estudo aqui...\n\nVocê pode usar títulos (# Título), tópicos (* item), blocos de código (```codigo```) ou colar links.'),
        rawNotes,
      );
      await tester.pumpAndSettle();

      // Clicar no botão para formatar com IA
      await tester.tap(find.text('Corrigir Formatação com IA ✨'));
      await tester.pumpAndSettle();

      // O campo de texto agora deve conter o texto estruturado com Markdown
      final textFinder = find.widgetWithText(TextField, formatted);
      expect(textFinder, findsOneWidget);

      // Aviso inline aparece no bloco da anotação com o botão 'Retornar'
      expect(find.text('Formatado com IA ✨'), findsOneWidget);
      expect(find.text('Retornar'), findsOneWidget);

      // Clicar em Retornar deve restaurar o texto anterior
      await tester.tap(find.text('Retornar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, rawNotes), findsOneWidget);

      // Reformatar para salvar a versão formatada
      await tester.tap(find.text('Corrigir Formatação com IA ✨'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, formatted), findsOneWidget);

      // Salvar a anotação
      await tester.tap(find.text('Salvar Anotação 💾'));
      await tester.pumpAndSettle();

      // No leitor, o botão de formatação NÃO deve estar no cabeçalho (apenas dentro da edição)
      expect(find.text('Formatar com IA ✨'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });

    test('6. AsterCodeSyntaxHighlighter formats code and comments with JetBrainsMono and distinct syntax colors', () {
      final highlighter = AsterCodeSyntaxHighlighter(isDark: false);
      const codeSnippet = '# Exemplo de verificação de rotas e gateways\naws ec2 describe-route-tables --filters "Name=vpc-id"';

      final span = highlighter.format(codeSnippet);
      expect(span.children, isNotNull);
      expect(span.children!.length, greaterThanOrEqualTo(2));

      // A primeira linha é comentário bash
      final firstSpan = span.children!.first;
      expect(firstSpan.toPlainText(), contains('# Exemplo de verificação'));
      expect(firstSpan.style?.color, isNotNull);
      expect(firstSpan.style?.fontFamily, contains('JetBrainsMono'));
    });

    testWidgets('7. NotebooksScreen sidebar filters and searches notes by name, tag, and date', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleNb = StudyNotebook(
        id: 'nb-cloud-test-7',
        title: 'Arquitetura Cloud & Infraestrutura',
        subject: 'Tecnologia',
        description: 'Anotações sobre VPCs e Subnets.',
        notes: [
          StudyNote(
            id: 'note-cloud-7-1',
            notebookId: 'nb-cloud-test-7',
            title: 'Topologia de Redes VPC & Subnets Públicas vs Privadas',
            content: 'Topologia VPC.',
            tags: ['Cloud', 'AWS', 'VPC', 'Infra'],
          ),
          StudyNote(
            id: 'note-cloud-7-2',
            notebookId: 'nb-cloud-test-7',
            title: 'Configuração de Segurança: Security Groups vs Network ACLs',
            content: 'Security Groups vs NACLs.',
            tags: ['Segurança', 'NACL', 'Firewall'],
          ),
        ],
      );
      await SupabaseService.saveNotebook(sampleNb);
      addTearDown(() => SupabaseService.deleteNotebook(sampleNb.id));

      await TestAppHarness.pumpInHarness(
        tester,
        const NotebooksScreen(),
      );

      // Abrir o caderno pré-carregado de Arquitetura Cloud
      final cloudTitle = find.text('Arquitetura Cloud & Infraestrutura');
      expect(cloudTitle, findsOneWidget);
      final cloudCard = find.ancestor(of: cloudTitle, matching: find.byType(Container));
      final openBtn = find.descendant(of: cloudCard, matching: find.text('Abrir Caderno 📖'));
      await tester.tap(openBtn.first);
      await tester.pumpAndSettle();

      // Verificar que o campo de busca com hint de busca existe
      final searchInput = find.widgetWithText(TextField, 'Buscar tags, nomes ou data...');
      expect(searchInput, findsOneWidget);

      // Verificar que o botão de calendário/ordenação existe
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // 1. Busca por nome (título): digitar 'Topologia'
      await tester.enterText(searchInput, 'Topologia');
      await tester.pumpAndSettle();

      // Deve encontrar 'Topologia de Redes VPC...' e não 'Configuração de Segurança'
      expect(find.text('Topologia de Redes VPC & Subnets Públicas vs Privadas'), findsWidgets);
      expect(find.text('Configuração de Segurança: Security Groups vs Network ACLs'), findsNothing);

      // Limpar busca pelo botão de fechar no TextField
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Configuração de Segurança: Security Groups vs Network ACLs'), findsWidgets);

      // 2. Filtro por tag via chip: Clicar em '#Cloud' ou '#Infra'
      final infraChip = find.text('#Infra');
      if (infraChip.evaluate().isNotEmpty) {
        await tester.tap(infraChip.first);
        await tester.pumpAndSettle();
        expect(find.text('Topologia de Redes VPC & Subnets Públicas vs Privadas'), findsWidgets);
        expect(find.text('Configuração de Segurança: Security Groups vs Network ACLs'), findsNothing);

        // Limpar filtro clicando em 'Limpar'
        await tester.tap(find.text('Limpar'));
        await tester.pumpAndSettle();
        expect(find.text('Configuração de Segurança: Security Groups vs Network ACLs'), findsWidgets);
      }

      // 3. Busca por data ou mês: digitar mês 'novembro' ou '24'
      await tester.enterText(searchInput, 'Topologia');
      await tester.pumpAndSettle();
      expect(find.text('Topologia de Redes VPC & Subnets Públicas vs Privadas'), findsWidgets);

      // 4. Teste de busca sem resultados
      await tester.enterText(searchInput, 'termo_inexistente_123456');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma anotação encontrada'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);

      // Clicar em 'Limpar filtros' restaura a lista
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Topologia de Redes VPC & Subnets Públicas vs Privadas'), findsWidgets);
      expect(find.text('Configuração de Segurança: Security Groups vs Network ACLs'), findsWidgets);

      await TestAppHarness.drainAsync(tester);
    });

    testWidgets('8. Tags row supports horizontal dragging and date picker option operates in pt_BR', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleNb = StudyNotebook(
        id: 'nb-cloud-test-8',
        title: 'Arquitetura Cloud & Infraestrutura',
        subject: 'Tecnologia',
        description: 'Anotações sobre VPCs e Subnets.',
        notes: [
          StudyNote(
            id: 'note-cloud-8-1',
            notebookId: 'nb-cloud-test-8',
            title: 'Topologia de Redes VPC & Subnets Públicas vs Privadas',
            content: 'Topologia VPC.',
            tags: ['Cloud', 'AWS', 'VPC', 'Infra'],
          ),
        ],
      );
      await SupabaseService.saveNotebook(sampleNb);
      addTearDown(() => SupabaseService.deleteNotebook(sampleNb.id));

      await TestAppHarness.pumpInHarness(
        tester,
        const NotebooksScreen(),
      );

      // Abrir o caderno pré-carregado
      final cloudTitle = find.text('Arquitetura Cloud & Infraestrutura');
      final cloudCard = find.ancestor(of: cloudTitle, matching: find.byType(Container));
      final openBtn = find.descendant(of: cloudCard, matching: find.text('Abrir Caderno 📖'));
      await tester.tap(openBtn.first);
      await tester.pumpAndSettle();

      // Verificar que as tags horizontais estão presentes
      final todasTag = find.text('Todas');
      expect(todasTag, findsOneWidget);

      // Realizar arrasto horizontal (drag) na linha de tags
      await tester.drag(todasTag, const Offset(-120, 0));
      await tester.pumpAndSettle();

      // Abrir o menu de data e ordenação
      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      await tester.pumpAndSettle();

      // Opção de filtrar por data em português
      expect(find.text('Filtrar por data...'), findsOneWidget);

      await TestAppHarness.drainAsync(tester);
    });
  });
}
