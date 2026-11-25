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

  testWidgets('NotebooksScreen shows study-focused metrics instead of links and images counts', (tester) async {
    await TestAppHarness.pumpInHarness(tester, const NotebooksScreen());

    expect(find.text('Cadernos Ativos'), findsOneWidget);
    expect(find.text('Anotações Totais'), findsOneWidget);
    expect(find.text('Atualizadas (7d)'), findsOneWidget);
    expect(find.text('Tempo de Revisão'), findsOneWidget);

    expect(find.text('Links de Estudo'), findsNothing);
    expect(find.text('Imagens Anexadas'), findsNothing);

    await TestAppHarness.drainAsync(tester);
  });

  test('StudyNote and StudyNotebook review tracking serializes and prioritizes marked or stale notes', () {
    final now = DateTime(2026, 11, 24, 20, 0);
    final freshNote = StudyNote(
      id: 'n-fresh',
      notebookId: 'nb-r',
      title: 'Nota Recente Em Dia',
      content: 'Resumo atualizado.',
      updatedAt: now.subtract(const Duration(hours: 6)),
    );
    final markedNote = StudyNote(
      id: 'n-marked',
      notebookId: 'nb-r',
      title: 'Nota Marcada Para Revisar',
      content: 'Conteúdo marcado.',
      needsReview: true,
      updatedAt: now.subtract(const Duration(hours: 2)),
    );
    final staleNote = StudyNote(
      id: 'n-stale',
      notebookId: 'nb-r',
      title: 'Nota Antiga (10d)',
      content: 'Conteúdo antigo.',
      updatedAt: now.subtract(const Duration(days: 10)),
    );

    expect(freshNote.shouldReview(referenceDate: now), isFalse);
    expect(markedNote.shouldReview(referenceDate: now), isTrue);
    expect(staleNote.shouldReview(referenceDate: now), isTrue);

    final roundtrip = StudyNote.fromMap(markedNote.toMap());
    expect(roundtrip.needsReview, isTrue);

    final nb = StudyNotebook(
      id: 'nb-r',
      title: 'Caderno Revisão',
      subject: 'Tecnologia',
      notes: [freshNote, staleNote, markedNote],
    );
    final due = nb.notesToReview(referenceDate: now);
    expect(due.map((e) => e.id).toList(), equals(['n-marked', 'n-stale']));
    expect(nb.pendingReviewCount(referenceDate: now), equals(2));
    expect(nb.isUpToDate(referenceDate: now), isFalse);
  });

  testWidgets('NotebooksScreen lets user check what needs review, mark notes for review, filter, and complete reviews',
      (tester) async {
    final nb = StudyNotebook(
      id: 'nb-review-ui',
      title: 'Caderno Segurança Web',
      subject: 'Segurança',
      description: 'Revisão OWASP e JWT.',
      notes: [
        StudyNote(
          id: 'note-ui-1',
          notebookId: 'nb-review-ui',
          title: 'JWT Claims & Validação',
          content: 'Sempre validar alg e exp.',
          needsReview: false,
          updatedAt: DateTime.now(),
        ),
      ],
    );
    await SupabaseService.saveNotebook(nb);

    await TestAppHarness.pumpInHarness(
      tester,
      const NotebooksScreen(),
      screenSize: const Size(1440, 960),
    );
    await tester.pumpAndSettle();

    // Abre a Central de Revisão dos Cadernos e entra na aba de marcação
    await tester.tap(find.byKey(const Key('notebooks_review_queue_button')));
    await tester.pumpAndSettle();
    expect(find.text('Revisão dos Cadernos de Estudo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notebooks_dialog_mark_tab')));
    await tester.pumpAndSettle();

    // Marca a anotação para revisão
    final checkbox = find.byKey(const Key('mark_review_checkbox_note-ui-1'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // Fecha modal e filtra por 'Para Revisar'
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notebooks_filter_to_review')));
    await tester.pumpAndSettle();
    expect(find.text('Caderno Segurança Web'), findsOneWidget);

    // Abre novamente pela Central de Revisão e vai direto para a nota via 'Revisar'
    await tester.tap(find.byKey(const Key('notebooks_review_queue_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_complete_review_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('note_complete_review_button')));
    await tester.pumpAndSettle();

    // Após concluir revisão, botão Concluir Revisão desaparece e nota sai de pendentes
    expect(find.byKey(const Key('note_complete_review_button')), findsNothing);
    expect(find.text('Marcar p/ revisar'), findsOneWidget);

    await SupabaseService.deleteNotebook('nb-review-ui');
    await TestAppHarness.drainAsync(tester);
  });
}
