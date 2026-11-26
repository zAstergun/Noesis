import 'package:flutter/foundation.dart';

/// Configuração de escopo de Grupo para que as telas principais
/// (Cadernos, Flashcards, Simulados e Trilhas) funcionem com paridade
/// completa de criação, IA e interação diretamente dentro de um Grupo de Estudos.
class StudyGroupFeatureScope {
  const StudyGroupFeatureScope({
    required this.groupId,
    required this.canEdit,
    required this.canRemove,
    this.onAttachExisting,
    this.onFeedback,
  });

  final String groupId;
  final bool canEdit;
  final bool canRemove;
  final VoidCallback? onAttachExisting;
  final void Function(String message, {bool isError})? onFeedback;
}
