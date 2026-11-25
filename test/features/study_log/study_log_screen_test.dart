import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noesis/features/study_log/study_log_screen.dart';
import 'package:noesis/main.dart';
import '../../e2e/harness/test_app_harness.dart';

void main() {
  setUpAll(() async {
    await TestAppHarness.setUpTestEnvironment();
  });

  testWidgets('StudyLogScreen lets user log daily study duration and topic, edit it, and view totals', (tester) async {
    await TestAppHarness.pumpInHarness(tester, const StudyLogScreen());

    expect(find.text('DIÁRIO DE ESTUDOS'), findsOneWidget);
    expect(find.text('REGISTRO RÁPIDO DO DIA'), findsOneWidget);

    // Preenche matéria e o que foi estudado
    await tester.enterText(
      find.widgetWithText(TextField, 'Matéria / Disciplina'),
      'Biologia',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'O que você estudou?'),
      'Genética Mendeliana e 15 questões ENEM',
    );

    // Seleciona atalho 1h 30m
    final chip90 = find.byKey(const ValueKey('quick_dur_90'));
    await tester.ensureVisible(chip90);
    await tester.tap(chip90);
    await tester.pumpAndSettle();

    // Salva registro
    final saveBtn = find.text('Salvar Estudo');
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verifica aparição na linha do tempo diária e totalizador do dia
    expect(find.text('Genética Mendeliana e 15 questões ENEM'), findsOneWidget);
    expect(find.textContaining('Total do dia:'), findsWidgets);

    // Abre edição do registro recém-criado e salva alteração
    final editBtn = find.byIcon(Icons.edit_outlined).first;
    await tester.ensureVisible(editBtn);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(find.text('Editar Registro de Estudo'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'O que foi estudado'),
      'Genética Mendeliana + Segunda Lei de Mendel',
    );
    await tester.tap(find.text('Salvar Alterações'));
    await tester.pumpAndSettle();

    expect(find.text('Genética Mendeliana + Segunda Lei de Mendel'), findsOneWidget);

    // Abre confirmação de exclusão ao clicar na lixeira e confirma
    final delBtn = find.byIcon(Icons.delete_outline_rounded).first;
    await tester.ensureVisible(delBtn);
    await tester.tap(delBtn);
    await tester.pumpAndSettle();

    expect(find.text('Excluir registro de estudo?'), findsOneWidget);
    await tester.tap(find.text('Excluir Registro'));
    await tester.pumpAndSettle();

    expect(find.text('Genética Mendeliana + Segunda Lei de Mendel'), findsNothing);

    await TestAppHarness.drainAsync(tester);
  });

  testWidgets('RootScreen switches to Diário de Estudos tab (index 7) and renders StudyLogScreen', (tester) async {
    await TestAppHarness.pumpInHarness(tester, const RootScreen());

    // Entra no modo visitante se a tela de autenticação estiver ativa
    final guestBtn = find.textContaining('Entrar sem login');
    if (guestBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(guestBtn.first);
      await tester.tap(guestBtn.first);
      await tester.pumpAndSettle();
    }

    final navItem = find.text('Diário de Estudos');
    expect(navItem, findsOneWidget);
    await tester.tap(navItem);
    await tester.pumpAndSettle();

    expect(find.byType(StudyLogScreen), findsOneWidget);
    expect(find.text('DIÁRIO DE ESTUDOS'), findsOneWidget);

    await TestAppHarness.drainAsync(tester);
  });

  test('StudyLogScreen adapts subject and duration suggestions strictly to user history', () {
    final sessions = [
      {'subject': 'Matemática', 'duration_minutes': 240},
      {'subject': 'Matemática', 'duration_minutes': 240},
      {'subject': 'Matemática', 'duration_minutes': 50},
      {'subject': 'Redação', 'duration_minutes': 240},
    ];

    final subjects = StudyLogScreen.resolvePersonalizedSubjects(sessions);
    expect(subjects, ['Matemática', 'Redação']);
    expect(subjects, isNot(contains('Criptografia')));
    expect(subjects, isNot(contains('Cloud / AWS')));

    final durations = StudyLogScreen.resolvePersonalizedDurations(sessions);
    expect(durations, containsAll([50, 240])); // 50m e 4h aprendidos do usuário
    expect(StudyLogScreen.resolvePreferredDuration(sessions), 240);
  });
}
