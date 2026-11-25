import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/core/gemini_service.dart';
import 'package:noesis/features/roadmaps/data/roadmaps_repository.dart';
import 'package:noesis/features/roadmaps/roadmaps_screen.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  setUp(() async {
    await RoadmapsRepository.clearForTest();
  });

  testWidgets('RoadmapsScreen allows creating a manual roadmap, adding/editing steps, and tracking subtopics', (tester) async {
    await TestAppHarness.pumpInHarness(tester, const RoadmapsScreen());

    expect(find.text('TRILHAS DE ESTUDO (ROADMAP)'), findsOneWidget);
    expect(find.text('Nenhuma trilha de estudos criada ainda'), findsOneWidget);

    // Cria nova trilha manual
    await tester.tap(find.text('Nova Trilha Manual'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título da Trilha'),
      'Trilha Cálculo I',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Matéria / Área'),
      'Matemática',
    );
    await tester.tap(find.text('Criar Trilha'));
    await tester.pumpAndSettle();

    expect(find.text('Trilha Cálculo I'), findsWidgets);
    expect(find.text('1. Fundamentos de Matemática'), findsOneWidget);

    // Adiciona uma etapa nova manualmente com subtópico
    await tester.tap(find.text('Adicionar Etapa'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título da Etapa'),
      '2. Limites e Continuidade',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Novo subtópico'),
      'Resolver 10 limites laterais',
    );
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar Etapa').last);
    await tester.pumpAndSettle();

    expect(find.text('2. Limites e Continuidade'), findsOneWidget);
    expect(find.text('Resolver 10 limites laterais'), findsOneWidget);

    // Marca o subtópico como concluído e verifica que a etapa muda para Concluída
    await tester.tap(find.text('Resolver 10 limites laterais'));
    await tester.pumpAndSettle();
    expect(find.text('Concluída'), findsOneWidget);

    // Edita metadados da trilha
    await tester.tap(find.text('Editar Trilha'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Título da Trilha'),
      'Trilha Cálculo Completo',
    );
    await tester.tap(find.text('Salvar Alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Trilha Cálculo Completo'), findsWidgets);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('RoadmapsScreen creates roadmap with AI (offline/autonomous fallback) and opens from RootScreen', (tester) async {
    GeminiService.apiKey = '';
    GeminiService.provider = 'google';
    await TestAppHarness.pumpInHarness(tester, const RootScreen());

    final guestBtn = find.textContaining('Entrar sem login');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestBtn.first);
      await tester.tap(guestBtn.first);
      await tester.pumpAndSettle();
    }

    final navItem = find.text('Trilhas');
    expect(navItem, findsOneWidget);
    await tester.tap(navItem);
    await tester.pumpAndSettle();

    expect(find.byType(RoadmapsScreen), findsOneWidget);

    await tester.tap(find.text('Criar com IA'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Objetivo da Trilha'),
      'Aprovação ENEM Medicina',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Matéria / Área Principal'),
      'Biologia e Química',
    );
    await tester.tap(find.text('Gerar com IA'));
    await tester.pumpAndSettle();

    expect(find.text('Aprovação ENEM Medicina'), findsWidgets);
    expect(find.text('1. Diagnóstico e Fundamentos de Biologia e Química'), findsOneWidget);
    // Verifica informações ricas do que será aprendido geradas pela IA
    expect(find.text('O QUE VOCÊ VAI APRENDER NESTA ETAPA'), findsWidgets);
    expect(find.textContaining('Meta prática:'), findsWidgets);

    // Alterna para Mapa Visual, conclui subtópico no mapa e confirma sincronização na Lista
    final mapBtn = find.text('Mapa Visual');
    await tester.ensureVisible(mapBtn);
    await tester.tap(mapBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Objetivo Final:'), findsOneWidget);
    final firstSubtopic = find.text('Mapeamento de conceitos-chave de Biologia e Química');
    await tester.ensureVisible(firstSubtopic);
    await tester.tap(firstSubtopic);
    await tester.pumpAndSettle();

    // Volta para Lista e confirma que o subtópico permanece concluído
    final listBtn = find.text('Lista');
    await tester.ensureVisible(listBtn);
    await tester.tap(listBtn);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_box_rounded), findsAtLeastNWidgets(1));

    await TestAppHarness.drainAsync(tester);
  });
}
