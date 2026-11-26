import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/gemini_service.dart';
import '../../core/theme.dart';
import '../study_groups/data/study_groups_service.dart';
import '../study_groups/models/study_group_feature_scope.dart';
import 'data/roadmaps_repository.dart';
import 'models/roadmap_model.dart';

enum _RoadmapViewMode { list, graph }

/// Tela de **Trilhas (Roadmap)**: permite criar roadmaps de estudo manualmente
/// ou via IA, alternar entre visualização em Lista e Mapa Visual
/// com sincronização compartilhada de conclusões, e salvar tudo no Supabase.
class RoadmapsScreen extends StatefulWidget {
  const RoadmapsScreen({super.key, this.groupScope});

  final StudyGroupFeatureScope? groupScope;

  @override
  State<RoadmapsScreen> createState() => _RoadmapsScreenState();
}

class _RoadmapsScreenState extends State<RoadmapsScreen> {
  List<StudyRoadmap> _roadmaps = [];
  String? _selectedRoadmapId;
  bool _isLoading = true;
  _RoadmapViewMode _viewMode = _RoadmapViewMode.list;

  @override
  void initState() {
    super.initState();
    if (widget.groupScope != null) {
      StudyGroupsService.instance.groupsNotifier.addListener(_onGroupListChanged);
    }
    _loadRoadmaps(forceRemote: true);
  }

  void _onGroupListChanged() {
    if (mounted) _loadRoadmaps();
  }

  @override
  void dispose() {
    if (widget.groupScope != null) {
      StudyGroupsService.instance.groupsNotifier.removeListener(_onGroupListChanged);
    }
    super.dispose();
  }

  Future<void> _loadRoadmaps({bool forceRemote = false}) async {
    final scope = widget.groupScope;
    final list = scope != null
        ? StudyGroupsService.instance.groupRoadmaps(scope.groupId)
        : await RoadmapsRepository.loadAll(forceRemote: forceRemote);
    if (!mounted) return;
    setState(() {
      _roadmaps = list;
      if (list.isEmpty) {
        _selectedRoadmapId = null;
      } else if (_selectedRoadmapId == null || !list.any((r) => r.id == _selectedRoadmapId)) {
        _selectedRoadmapId = list.first.id;
      }
      _isLoading = false;
    });
  }

  StudyRoadmap? get _activeRoadmap {
    if (_roadmaps.isEmpty) return null;
    return _roadmaps.where((r) => r.id == _selectedRoadmapId).firstOrNull ?? _roadmaps.first;
  }

  Future<void> _persistRoadmap(StudyRoadmap updated) async {
    final scope = widget.groupScope;
    final List<StudyRoadmap> nextList;
    if (scope != null) {
      await StudyGroupsService.instance.saveGroupRoadmap(scope.groupId, updated);
      nextList = StudyGroupsService.instance.groupRoadmaps(scope.groupId);
    } else {
      nextList = await RoadmapsRepository.saveRoadmap(updated);
    }
    if (!mounted) return;
    setState(() {
      _roadmaps = nextList;
      _selectedRoadmapId = updated.id;
    });
  }

  Future<void> _openCreateAiDialog() async {
    final generated = await showDialog<StudyRoadmap>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AiRoadmapDialog(),
    );
    if (generated != null) {
      await _persistRoadmap(generated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trilha "${generated.title}" criada com ${generated.totalSteps} etapas!')),
        );
      }
    }
  }

  Future<void> _openManualRoadmapDialog({StudyRoadmap? editing}) async {
    final result = await showDialog<StudyRoadmap>(
      context: context,
      builder: (_) => _RoadmapMetaDialog(existing: editing),
    );
    if (result != null) {
      await _persistRoadmap(result);
    }
  }

  Future<void> _openStepEditor(StudyRoadmap roadmap, {int? stepIndex}) async {
    final existingStep = stepIndex != null ? roadmap.steps[stepIndex] : null;
    final editedStep = await showDialog<RoadmapStep>(
      context: context,
      builder: (_) => _StepEditorDialog(existing: existingStep),
    );
    if (editedStep == null) return;

    final updatedSteps = List<RoadmapStep>.from(roadmap.steps);
    if (stepIndex != null) {
      updatedSteps[stepIndex] = editedStep;
    } else {
      updatedSteps.add(editedStep);
    }
    await _persistRoadmap(roadmap.copyWith(steps: updatedSteps));
  }

  Future<void> _cycleStepStatus(StudyRoadmap roadmap, int stepIndex) async {
    final step = roadmap.steps[stepIndex];
    final nextStatus = switch (step.status) {
      RoadmapStepStatus.todo => RoadmapStepStatus.doing,
      RoadmapStepStatus.doing => RoadmapStepStatus.done,
      RoadmapStepStatus.done => RoadmapStepStatus.todo,
    };

    var subs = step.subtopics;
    if (nextStatus == RoadmapStepStatus.done && subs.isNotEmpty) {
      subs = subs.map((s) => s.copyWith(done: true)).toList();
    } else if (nextStatus == RoadmapStepStatus.todo && subs.isNotEmpty) {
      subs = subs.map((s) => s.copyWith(done: false)).toList();
    }

    final updatedSteps = List<RoadmapStep>.from(roadmap.steps);
    updatedSteps[stepIndex] = step.copyWith(status: nextStatus, subtopics: subs);
    await _persistRoadmap(roadmap.copyWith(steps: updatedSteps));
    final scope = widget.groupScope;
    if (scope != null && nextStatus == RoadmapStepStatus.done) {
      final res = await StudyGroupsService.instance.recordGroupRoadmapStepDone(
        scope.groupId,
        roadmap.id,
        step.id,
        step.title,
      );
      if (mounted && res.earnedInsights > 0 && res.message != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(res.message!)));
      }
    }
  }

  Future<void> _toggleSubtopic(StudyRoadmap roadmap, int stepIndex, int subIndex) async {
    final step = roadmap.steps[stepIndex];
    final subs = List<RoadmapSubtopic>.from(step.subtopics);
    final current = subs[subIndex];
    subs[subIndex] = current.copyWith(done: !current.done);

    final doneCount = subs.where((s) => s.done).length;
    RoadmapStepStatus newStatus = step.status;
    if (subs.isNotEmpty) {
      if (doneCount == subs.length) {
        newStatus = RoadmapStepStatus.done;
      } else if (doneCount > 0) {
        newStatus = RoadmapStepStatus.doing;
      } else if (step.status == RoadmapStepStatus.done) {
        newStatus = RoadmapStepStatus.todo;
      }
    }

    final updatedSteps = List<RoadmapStep>.from(roadmap.steps);
    updatedSteps[stepIndex] = step.copyWith(subtopics: subs, status: newStatus);
    await _persistRoadmap(roadmap.copyWith(steps: updatedSteps));
    final scope = widget.groupScope;
    if (scope != null && newStatus == RoadmapStepStatus.done) {
      final res = await StudyGroupsService.instance.recordGroupRoadmapStepDone(
        scope.groupId,
        roadmap.id,
        step.id,
        step.title,
      );
      if (mounted && res.earnedInsights > 0 && res.message != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(res.message!)));
      }
    }
  }

  Future<void> _moveStep(StudyRoadmap roadmap, int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= roadmap.steps.length) return;
    final updatedSteps = List<RoadmapStep>.from(roadmap.steps);
    final moved = updatedSteps.removeAt(index);
    updatedSteps.insert(target, moved);
    await _persistRoadmap(roadmap.copyWith(steps: updatedSteps));
  }

  Future<void> _deleteStep(StudyRoadmap roadmap, int index) async {
    final updatedSteps = List<RoadmapStep>.from(roadmap.steps)..removeAt(index);
    await _persistRoadmap(roadmap.copyWith(steps: updatedSteps));
  }

  Future<void> _confirmDeleteRoadmap(StudyRoadmap roadmap) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AsterConstants.coral.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: AsterConstants.coral, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Excluir trilha?',
                          style: GoogleFonts.manrope(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A trilha "${roadmap.title}" (${roadmap.totalSteps} etapas) será removida do seu histórico.',
                    style: GoogleFonts.manrope(fontSize: 13, color: AsterConstants.textMuted),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SoftClayPillButton(
                        text: 'Cancelar',
                        isSecondary: true,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AsterConstants.coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Excluir Trilha'),
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

    if (confirmed == true) {
      final scope = widget.groupScope;
      final List<StudyRoadmap> list;
      if (scope != null) {
        await StudyGroupsService.instance.deleteGroupRoadmap(scope.groupId, roadmap.id);
        list = StudyGroupsService.instance.groupRoadmaps(scope.groupId);
      } else {
        list = await RoadmapsRepository.deleteRoadmap(roadmap.id);
      }
      if (!mounted) return;
      setState(() {
        _roadmaps = list;
        _selectedRoadmapId = list.isNotEmpty ? list.first.id : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _activeRoadmap;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 16.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho + Seletor de Trilhas ──
          ValueListenableBuilder<bool>(
            valueListenable: AsterTheme.sidebarCollapsedNotifier,
            builder: (context, isCollapsed, child) {
              return Padding(
                padding: EdgeInsets.only(
                  left: (widget.groupScope == null && isDesktop && isCollapsed) ? 84 : 0,
                ),
                child: child,
              );
            },
            child: SoftClayCard(
              padding: EdgeInsets.all(isDesktop ? 28 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final titleBlock = Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AsterTheme.primary(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.route_rounded, color: AsterTheme.onPrimary(context), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRILHAS DE ESTUDO (ROADMAP)',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Crie trilhas manualmente ou com IA, visualize em Lista ou Mapa Visual e edite cada etapa',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final actionRow = (widget.groupScope != null && !widget.groupScope!.canEdit)
                        ? const SizedBox.shrink()
                        : Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (widget.groupScope?.onAttachExisting != null)
                                OutlinedButton.icon(
                                  key: const Key('group_attach_roadmap_button'),
                                  onPressed: widget.groupScope!.onAttachExisting,
                                  icon: const Icon(Icons.attach_file_rounded, size: 17),
                                  label: const Text('Anexar Minha Trilha'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    ),
                                  ),
                                ),
                              SoftClayPillButton(
                                key: widget.groupScope != null ? const Key('group_create_roadmap_button') : null,
                                text: 'Nova Trilha Manual',
                                icon: Icons.add_rounded,
                                isSecondary: true,
                                onPressed: () => _openManualRoadmapDialog(),
                              ),
                              SoftClayPillButton(
                                text: 'Criar com IA',
                                icon: Icons.auto_awesome,
                                onPressed: _openCreateAiDialog,
                              ),
                            ],
                          );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 14),
                          actionRow,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 16),
                        actionRow,
                      ],
                    );
                  },
                ),

                if (_roadmaps.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _roadmaps.map((rm) {
                      final isSelected = rm.id == active?.id;
                      final pct = (rm.progress * 100).round();
                      return InkWell(
                        onTap: () => setState(() => _selectedRoadmapId = rm.id),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: isDesktop ? 250 : double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AsterTheme.primary(context).withValues(alpha: 0.12)
                                : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            border: Border.all(
                              color: isSelected
                                  ? AsterTheme.primary(context)
                                  : AsterTheme.primary(context).withValues(alpha: 0.15),
                              width: isSelected ? 1.6 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      rm.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: pct == 100 ? AsterConstants.menta : AsterTheme.primary(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rm.subject} · ${rm.completedSteps}/${rm.totalSteps} etapas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(fontSize: 11, color: AsterConstants.textMuted),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                child: LinearProgressIndicator(
                                  value: rm.progress,
                                  minHeight: 5,
                                  backgroundColor: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                                  valueColor: AlwaysStoppedAnimation(
                                    pct == 100 ? AsterConstants.menta : AsterTheme.primary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (active == null)
            SoftClayCard(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.route_rounded, size: 30, color: AsterTheme.primary(context)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Nenhuma trilha de estudos criada ainda',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Peça para a IA montar um roadmap passo a passo para seu objetivo ou crie uma trilha manual do zero.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(fontSize: 13, color: AsterConstants.textMuted),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      SoftClayPillButton(
                        text: 'Gerar Trilha com IA',
                        icon: Icons.auto_awesome,
                        onPressed: _openCreateAiDialog,
                      ),
                      SoftClayPillButton(
                        text: 'Criar Trilha Manual',
                        icon: Icons.add_rounded,
                        isSecondary: true,
                        onPressed: () => _openManualRoadmapDialog(),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            _buildRoadmapDetail(active, isDesktop, isDark),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewOptionPill(
            label: 'Lista',
            icon: Icons.view_agenda_outlined,
            selected: _viewMode == _RoadmapViewMode.list,
            onTap: () => setState(() => _viewMode = _RoadmapViewMode.list),
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _viewOptionPill(
            label: 'Mapa Visual',
            icon: Icons.account_tree_rounded,
            selected: _viewMode == _RoadmapViewMode.graph,
            onTap: () => setState(() => _viewMode = _RoadmapViewMode.graph),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _viewOptionPill({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AsterTheme.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? AsterTheme.onPrimary(context) : AsterConstants.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected
                    ? AsterTheme.onPrimary(context)
                    : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapDetail(StudyRoadmap roadmap, bool isDesktop, bool isDark) {
    final pct = (roadmap.progress * 100).round();

    return SoftClayCard(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      SoftClayTag(label: roadmap.subject, color: AsterTheme.primary(context)),
                      SoftClayTag(label: roadmap.level, color: AsterConstants.ambar),
                      SoftClayTag(
                        label: '${roadmap.estimatedWeeks} sem · ~${roadmap.totalEstimatedHours}h',
                        color: AsterConstants.menta,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    roadmap.title,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                    ),
                  ),
                  if (roadmap.goal.trim().isNotEmpty && roadmap.goal.trim() != roadmap.title.trim()) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Objetivo: ${roadmap.goal}',
                      style: GoogleFonts.manrope(fontSize: 13, color: AsterConstants.textMuted),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildViewModeToggle(isDark),
                  OutlinedButton.icon(
                    onPressed: () => _openManualRoadmapDialog(editing: roadmap),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar Trilha'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openStepEditor(roadmap),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Adicionar Etapa'),
                  ),
                  IconButton(
                    tooltip: 'Excluir trilha',
                    onPressed: () => _confirmDeleteRoadmap(roadmap),
                    icon: const Icon(Icons.delete_outline_rounded, color: AsterConstants.coral),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Barra de progresso geral
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'PROGRESSO DO ROADMAP',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: AsterConstants.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$pct% concluído · ${roadmap.completedSteps}/${roadmap.totalSteps} etapas',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pct == 100 ? AsterConstants.menta : AsterTheme.primary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: LinearProgressIndicator(
                    value: roadmap.progress,
                    minHeight: 8,
                    backgroundColor: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                    valueColor: AlwaysStoppedAnimation(
                      pct == 100 ? AsterConstants.menta : AsterTheme.primary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (roadmap.steps.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Column(
                children: [
                  Text(
                    'Esta trilha ainda não possui etapas.',
                    style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: AsterConstants.textMuted),
                  ),
                  const SizedBox(height: 12),
                  SoftClayPillButton(
                    text: 'Adicionar Primeira Etapa',
                    icon: Icons.add_rounded,
                    onPressed: () => _openStepEditor(roadmap),
                  ),
                ],
              ),
            )
          else if (_viewMode == _RoadmapViewMode.graph)
            _buildRoadmapGraphView(roadmap, isDesktop, isDark)
          else
            _buildListTimelineView(roadmap, isDark),
        ],
      ),
    );
  }

  /// Visualização detalhada em Lista com objetivos de aprendizagem, tópicos e metas.
  Widget _buildListTimelineView(StudyRoadmap roadmap, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: roadmap.steps.asMap().entries.map((entry) {
        final idx = entry.key;
        final step = entry.value;
        final isLast = idx == roadmap.steps.length - 1;
        final statusColor = _colorForStatus(step.status);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coluna do conector visual da trilha
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _cycleStepStatus(roadmap, idx),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: step.status == RoadmapStepStatus.todo
                              ? (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt)
                              : statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: statusColor, width: 2),
                        ),
                        child: Center(
                          child: step.status == RoadmapStepStatus.done
                              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                              : Text(
                                  '${idx + 1}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: step.status == RoadmapStepStatus.doing ? Colors.white : statusColor,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: step.status == RoadmapStepStatus.done
                                ? AsterConstants.menta.withValues(alpha: 0.5)
                                : (isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Card da etapa
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border(left: BorderSide(color: statusColor, width: 4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () => _cycleStepStatus(roadmap, idx),
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                      child: SoftClayTag(label: step.status.label, color: statusColor),
                                    ),
                                    SoftClayTag(
                                      label: '~${step.estimatedHours}h',
                                      color: AsterConstants.ambar,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  step.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                    decoration: step.status == RoadmapStepStatus.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (idx > 0)
                            IconButton(
                              tooltip: 'Mover para cima',
                              onPressed: () => _moveStep(roadmap, idx, -1),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 17, color: AsterConstants.textMuted),
                            ),
                          if (!isLast)
                            IconButton(
                              tooltip: 'Mover para baixo',
                              onPressed: () => _moveStep(roadmap, idx, 1),
                              icon: const Icon(Icons.arrow_downward_rounded, size: 17, color: AsterConstants.textMuted),
                            ),
                          IconButton(
                            tooltip: 'Editar etapa',
                            onPressed: () => _openStepEditor(roadmap, stepIndex: idx),
                            icon: const Icon(Icons.edit_outlined, size: 17, color: AsterConstants.textMuted),
                          ),
                          IconButton(
                            tooltip: 'Remover etapa',
                            onPressed: () => _deleteStep(roadmap, idx),
                            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AsterConstants.coral),
                          ),
                        ],
                      ),

                      if (step.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          step.description,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            height: 1.5,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],

                      if (step.learningObjectives.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, size: 14, color: AsterTheme.primary(context)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'O QUE VOCÊ VAI APRENDER NESTA ETAPA',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.7,
                                      color: AsterTheme.primary(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...step.learningObjectives.map(
                                (obj) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('•  ', style: GoogleFonts.manrope(color: AsterTheme.primary(context), fontWeight: FontWeight.w900)),
                                      Expanded(
                                        child: Text(
                                          obj,
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (step.keyTopics.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: step.keyTopics.map((topic) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AsterTheme.primary(context).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Text(
                                topic,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AsterTheme.primary(context),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      if (step.practicalMilestone.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.flag_outlined, size: 15, color: AsterConstants.menta),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Meta prática: ${step.practicalMilestone}',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AsterConstants.menta,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (step.subtopics.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...step.subtopics.asMap().entries.map((subEntry) {
                          final subIdx = subEntry.key;
                          final sub = subEntry.value;
                          return InkWell(
                            onTap: () => _toggleSubtopic(roadmap, idx, subIdx),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    sub.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    size: 18,
                                    color: sub.done ? AsterConstants.menta : AsterConstants.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: sub.done ? FontWeight.w600 : FontWeight.w700,
                                        color: sub.done
                                            ? AsterConstants.textMuted
                                            : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                        decoration: sub.done ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],

                      if (step.resources.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: step.resources.map((res) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 12, color: AsterTheme.primary(context)),
                                  const SizedBox(width: 5),
                                  Text(
                                    res,
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AsterConstants.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Visualização em diagrama visual: trilha central conectada a ramos
  /// laterais de subtópicos e detalhes clicáveis com estado 100% compartilhado.
  Widget _buildRoadmapGraphView(StudyRoadmap roadmap, bool isDesktop, bool isDark) {
    final surfaceAlt = isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt;
    final lineColor = isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          // Legenda interativa do mapa visual
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _graphLegendItem('Concluída', AsterConstants.menta),
              _graphLegendItem('Em andamento', AsterTheme.primary(context)),
              _graphLegendItem('A fazer', AsterConstants.textMuted),
              Text(
                '· Clique nos nós para alternar status ou nos ramos para concluir subtópicos',
                style: GoogleFonts.manrope(fontSize: 11.5, color: AsterConstants.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nó raiz do Roadmap
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AsterTheme.primary(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              boxShadow: AsterTheme.primaryShadow(context),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_rounded, size: 16, color: AsterTheme.onPrimary(context)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    roadmap.title,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AsterTheme.onPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          ...roadmap.steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final statusColor = _colorForStatus(step.status);
            final isLast = idx == roadmap.steps.length - 1;

            // Divide ramos entre lado esquerdo e direito no desktop (alternando e balanceando)
            final leftSubtopics = <(int, RoadmapSubtopic)>[];
            final rightSubtopics = <(int, RoadmapSubtopic)>[];
            for (int i = 0; i < step.subtopics.length; i++) {
              if (i.isEven) {
                leftSubtopics.add((i, step.subtopics[i]));
              } else {
                rightSubtopics.add((i, step.subtopics[i]));
              }
            }

            final centerNode = InkWell(
              onTap: () => _cycleStepStatus(roadmap, idx),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              child: Container(
                constraints: BoxConstraints(maxWidth: isDesktop ? 310 : double.infinity),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: step.status == RoadmapStepStatus.done
                      ? AsterConstants.menta.withValues(alpha: 0.14)
                      : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  border: Border.all(
                    color: statusColor,
                    width: step.status == RoadmapStepStatus.todo ? 1.5 : 2.2,
                  ),
                  boxShadow: AsterConstants.claySubtleShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          child: Center(
                            child: step.status == RoadmapStepStatus.done
                                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                : Text(
                                    '${idx + 1}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.status.label.toUpperCase(),
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                              color: statusColor,
                            ),
                          ),
                        ),
                        Text(
                          '~${step.estimatedHours}h',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.ambar,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _openStepEditor(roadmap, stepIndex: idx),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined, size: 15, color: AsterConstants.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.title,
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                        decoration: step.status == RoadmapStepStatus.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (step.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        step.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(fontSize: 11.5, color: AsterConstants.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            );

            return Column(
              children: [
                // Conector vertical na espinha central
                Container(
                  width: 3,
                  height: 24,
                  color: step.status == RoadmapStepStatus.done ? AsterConstants.menta : lineColor,
                ),

                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ramo Esquerdo (Subtópicos pares + Conceitos)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ...leftSubtopics.map(
                              (pair) => _buildGraphBranchNode(
                                title: pair.$2.title,
                                done: pair.$2.done,
                                alignRight: true,
                                branchColor: statusColor,
                                isDark: isDark,
                                onTap: () => _toggleSubtopic(roadmap, idx, pair.$1),
                              ),
                            ),
                            if (step.learningObjectives.isNotEmpty)
                              _buildGraphInfoBranch(
                                label: 'Aprender',
                                text: step.learningObjectives.first,
                                alignRight: true,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                      if (leftSubtopics.isNotEmpty || step.learningObjectives.isNotEmpty)
                        Container(width: 24, height: 2.5, color: statusColor.withValues(alpha: 0.45)),

                      centerNode,

                      if (rightSubtopics.isNotEmpty || step.practicalMilestone.isNotEmpty)
                        Container(width: 24, height: 2.5, color: statusColor.withValues(alpha: 0.45)),

                      // Ramo Direito (Subtópicos ímpares + Meta prática)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...rightSubtopics.map(
                              (pair) => _buildGraphBranchNode(
                                title: pair.$2.title,
                                done: pair.$2.done,
                                alignRight: false,
                                branchColor: statusColor,
                                isDark: isDark,
                                onTap: () => _toggleSubtopic(roadmap, idx, pair.$1),
                              ),
                            ),
                            if (step.practicalMilestone.trim().isNotEmpty)
                              _buildGraphInfoBranch(
                                label: 'Meta prática',
                                text: step.practicalMilestone,
                                alignRight: false,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  centerNode,
                  if (step.subtopics.isNotEmpty || step.learningObjectives.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 8),
                      child: Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: statusColor.withValues(alpha: 0.45), width: 2.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...step.subtopics.asMap().entries.map(
                                  (pair) => _buildGraphBranchNode(
                                    title: pair.value.title,
                                    done: pair.value.done,
                                    alignRight: false,
                                    branchColor: statusColor,
                                    isDark: isDark,
                                    onTap: () => _toggleSubtopic(roadmap, idx, pair.key),
                                  ),
                                ),
                            if (step.practicalMilestone.trim().isNotEmpty)
                              _buildGraphInfoBranch(
                                label: 'Meta prática',
                                text: step.practicalMilestone,
                                alignRight: false,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],

                if (isLast) ...[
                  Container(
                    width: 3,
                    height: 20,
                    color: step.status == RoadmapStepStatus.done ? AsterConstants.menta : lineColor,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: roadmap.progress >= 1.0
                          ? AsterConstants.menta
                          : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      border: Border.all(
                        color: roadmap.progress >= 1.0 ? AsterConstants.menta : lineColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      roadmap.progress >= 1.0 ? 'Trilha Concluída!' : 'Objetivo Final: ${roadmap.goal.isNotEmpty ? roadmap.goal : roadmap.title}',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: roadmap.progress >= 1.0 ? Colors.white : AsterConstants.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGraphBranchNode({
    required String title,
    required bool done,
    required bool alignRight,
    required Color branchColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: done
                ? AsterConstants.menta.withValues(alpha: 0.14)
                : (isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: done ? AsterConstants.menta : branchColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: done ? AsterConstants.menta : AsterConstants.textMuted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  textAlign: alignRight ? TextAlign.right : TextAlign.left,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w800,
                    color: done
                        ? AsterConstants.textMuted
                        : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphInfoBranch({
    required String label,
    required String text,
    required bool alignRight,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AsterTheme.primary(context).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.22)),
        ),
        child: Text(
          '$label: $text',
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _graphLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
        ),
      ],
    );
  }

  Color _colorForStatus(RoadmapStepStatus status) {
    return switch (status) {
      RoadmapStepStatus.done => AsterConstants.menta,
      RoadmapStepStatus.doing => AsterTheme.primary(context),
      RoadmapStepStatus.todo => AsterConstants.textMuted,
    };
  }
}

InputDecoration _roadmapFieldDecoration({
  required BuildContext context,
  required bool isDark,
  required String label,
  String? hint,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 17, color: AsterTheme.primary(context)) : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.16)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AsterTheme.primary(context).withValues(alpha: 0.16)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AsterTheme.primary(context), width: 1.6),
    ),
  );
}

class _AiRoadmapDialog extends StatefulWidget {
  const _AiRoadmapDialog();

  @override
  State<_AiRoadmapDialog> createState() => _AiRoadmapDialogState();
}

class _AiRoadmapDialogState extends State<_AiRoadmapDialog> {
  final _goalCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController(text: '6');
  final _hoursCtrl = TextEditingController(text: '10');
  final _notesCtrl = TextEditingController();
  String _level = 'Intermediário';
  bool _isGenerating = false;
  String? _error;

  static const _levels = ['Iniciante', 'Intermediário', 'Avançado'];

  @override
  void dispose() {
    _goalCtrl.dispose();
    _subjectCtrl.dispose();
    _weeksCtrl.dispose();
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final goal = _goalCtrl.text.trim();
    final subj = _subjectCtrl.text.trim();
    if (goal.isEmpty && subj.isEmpty) {
      setState(() => _error = 'Informe seu objetivo ou a matéria principal da trilha.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final weeks = (int.tryParse(_weeksCtrl.text.trim()) ?? 6).clamp(1, 52);
      final hours = (int.tryParse(_hoursCtrl.text.trim()) ?? 10).clamp(1, 80);
      final roadmap = await GeminiService.generateStudyRoadmap(
        goal: goal.isEmpty ? 'Dominar $subj' : goal,
        subject: subj.isEmpty ? goal : subj,
        level: _level,
        estimatedWeeks: weeks,
        hoursPerWeek: hours,
        extraNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(roadmap);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = 'Erro ao gerar trilha: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AsterTheme.primary(context), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gerar Trilha (Roadmap) com IA',
                          style: GoogleFonts.manrope(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        Text(
                          'A IA detalha o que você vai aprender, conceitos-chave, metas e subtópicos.',
                          style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!_isGenerating)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AsterConstants.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _goalCtrl,
                        enabled: !_isGenerating,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Objetivo da Trilha',
                          hint: 'Ex.: Dominar Cálculo I, ENEM 800+, Certificação AWS...',
                          prefixIcon: Icons.flag_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subjectCtrl,
                        enabled: !_isGenerating,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Matéria / Área Principal',
                          hint: 'Ex.: Matemática, Medicina, Cloud, Direito...',
                          prefixIcon: Icons.book_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'NÍVEL ATUAL',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _levels.map((lvl) {
                          final selected = _level == lvl;
                          return InkWell(
                            onTap: _isGenerating ? null : () => setState(() => _level = lvl),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AsterTheme.primary(context)
                                    : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                border: Border.all(
                                  color: selected
                                      ? AsterTheme.primary(context)
                                      : AsterTheme.primary(context).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                lvl,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? AsterTheme.onPrimary(context)
                                      : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weeksCtrl,
                              enabled: !_isGenerating,
                              keyboardType: TextInputType.number,
                              decoration: _roadmapFieldDecoration(context: context, isDark: isDark, label: 'Semanas'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _hoursCtrl,
                              enabled: !_isGenerating,
                              keyboardType: TextInputType.number,
                              decoration: _roadmapFieldDecoration(context: context, isDark: isDark, label: 'Horas/semana'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        enabled: !_isGenerating,
                        maxLines: 3,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Prioridades ou dificuldades (opcional)',
                          hint: 'Ex.: Focar em probabilidade, geometria espacial e revisão semanal...',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.coral,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftClayPillButton(
                    text: 'Cancelar',
                    isSecondary: true,
                    onPressed: _isGenerating ? () {} : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  SoftClayPillButton(
                    text: _isGenerating ? 'Gerando Roadmap...' : 'Gerar com IA',
                    icon: Icons.auto_awesome,
                    onPressed: _isGenerating ? () {} : _generate,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadmapMetaDialog extends StatefulWidget {
  const _RoadmapMetaDialog({this.existing});

  final StudyRoadmap? existing;

  @override
  State<_RoadmapMetaDialog> createState() => _RoadmapMetaDialogState();
}

class _RoadmapMetaDialogState extends State<_RoadmapMetaDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _goalCtrl;
  late final TextEditingController _subjCtrl;
  late final TextEditingController _weeksCtrl;
  late String _level;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _goalCtrl = TextEditingController(text: widget.existing?.goal ?? '');
    _subjCtrl = TextEditingController(text: widget.existing?.subject ?? '');
    _weeksCtrl = TextEditingController(text: (widget.existing?.estimatedWeeks ?? 4).toString());
    _level = widget.existing?.level ?? 'Intermediário';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _goalCtrl.dispose();
    _subjCtrl.dispose();
    _weeksCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final subj = _subjCtrl.text.trim();
    if (title.isEmpty || subj.isEmpty) {
      setState(() => _error = 'Preencha o título da trilha e a matéria.');
      return;
    }

    final weeks = (int.tryParse(_weeksCtrl.text.trim()) ?? 4).clamp(1, 52);
    final now = DateTime.now();
    final existing = widget.existing;
    final roadmap = existing != null
        ? existing.copyWith(
            title: title,
            goal: _goalCtrl.text.trim(),
            subject: subj,
            level: _level,
            estimatedWeeks: weeks,
          )
        : StudyRoadmap(
            id: 'roadmap-${now.millisecondsSinceEpoch}',
            title: title,
            goal: _goalCtrl.text.trim(),
            subject: subj,
            level: _level,
            estimatedWeeks: weeks,
            createdAt: now,
            updatedAt: now,
            steps: [
              RoadmapStep(
                id: 'step-1-${now.millisecondsSinceEpoch}',
                title: '1. Fundamentos de $subj',
                description: 'Primeiros conceitos e organização do material.',
                estimatedHours: 4,
                status: RoadmapStepStatus.doing,
              ),
            ],
          );

    Navigator.of(context).pop(roadmap);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existing != null;
    return Dialog(
      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Informações da Trilha' : 'Nova Trilha Manual',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                  label: 'Título da Trilha',
                  hint: 'Ex.: Trilha ENEM Matemática Completa',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjCtrl,
                decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                  label: 'Matéria / Área',
                  hint: 'Ex.: Matemática, Direito, Inglês...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goalCtrl,
                decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                  label: 'Objetivo (opcional)',
                  hint: 'Ex.: Gabaritar funções e probabilidade',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: const ['Iniciante', 'Intermediário', 'Avançado'].contains(_level)
                          ? _level
                          : 'Intermediário',
                      decoration: _roadmapFieldDecoration(context: context, isDark: isDark, label: 'Nível'),
                      items: const ['Iniciante', 'Intermediário', 'Avançado']
                          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _level = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weeksCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _roadmapFieldDecoration(context: context, isDark: isDark, label: 'Semanas'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: AsterConstants.coral),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftClayPillButton(
                    text: 'Cancelar',
                    isSecondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  SoftClayPillButton(
                    text: isEditing ? 'Salvar Alterações' : 'Criar Trilha',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepEditorDialog extends StatefulWidget {
  const _StepEditorDialog({this.existing});

  final RoadmapStep? existing;

  @override
  State<_StepEditorDialog> createState() => _StepEditorDialogState();
}

class _StepEditorDialogState extends State<_StepEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _objectivesCtrl;
  late final TextEditingController _topicsCtrl;
  late final TextEditingController _milestoneCtrl;
  late final TextEditingController _subtopicInputCtrl;
  late final TextEditingController _resourcesCtrl;
  late RoadmapStepStatus _status;
  late List<RoadmapSubtopic> _subtopics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _hoursCtrl = TextEditingController(text: (widget.existing?.estimatedHours ?? 4).toString());
    _objectivesCtrl = TextEditingController(
      text: (widget.existing?.learningObjectives ?? const []).join('\n'),
    );
    _topicsCtrl = TextEditingController(
      text: (widget.existing?.keyTopics ?? const []).join(', '),
    );
    _milestoneCtrl = TextEditingController(text: widget.existing?.practicalMilestone ?? '');
    _subtopicInputCtrl = TextEditingController();
    _resourcesCtrl = TextEditingController(text: (widget.existing?.resources ?? const []).join(', '));
    _status = widget.existing?.status ?? RoadmapStepStatus.todo;
    _subtopics = List<RoadmapSubtopic>.from(widget.existing?.subtopics ?? const []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _hoursCtrl.dispose();
    _objectivesCtrl.dispose();
    _topicsCtrl.dispose();
    _milestoneCtrl.dispose();
    _subtopicInputCtrl.dispose();
    _resourcesCtrl.dispose();
    super.dispose();
  }

  void _addSubtopic() {
    final text = _subtopicInputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtopics.add(
        RoadmapSubtopic(
          id: 'sub-${DateTime.now().microsecondsSinceEpoch}',
          title: text,
        ),
      );
      _subtopicInputCtrl.clear();
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Informe o título da etapa.');
      return;
    }
    final hours = (int.tryParse(_hoursCtrl.text.trim()) ?? 4).clamp(1, 200);
    final objectivesList = _objectivesCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final topicsList = _topicsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final resList = _resourcesCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final step = RoadmapStep(
      id: widget.existing?.id ?? 'step-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descCtrl.text.trim(),
      estimatedHours: hours,
      status: _status,
      learningObjectives: objectivesList,
      keyTopics: topicsList,
      practicalMilestone: _milestoneCtrl.text.trim(),
      subtopics: _subtopics,
      resources: resList,
    );
    Navigator.of(context).pop(step);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existing != null;
    return Dialog(
      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Etapa do Roadmap' : 'Nova Etapa do Roadmap',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Título da Etapa',
                          hint: 'Ex.: 2. Funções Quadráticas e Gráficos',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Descrição geral da etapa',
                          hint: 'O que estudar e como ela se conecta ao objetivo...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _objectivesCtrl,
                        maxLines: 3,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'O que será aprendido (1 objetivo por linha)',
                          hint: 'Compreender o conceito X...\nAplicar a técnica Y...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _topicsCtrl,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Conceitos-chave (separados por vírgula)',
                          hint: 'Ex.: Vértice, Discriminante, Raízes reais',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _milestoneCtrl,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Meta prática de validação (opcional)',
                          hint: 'Ex.: Resolver 20 questões atingindo 80%',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<RoadmapStepStatus>(
                              initialValue: _status,
                              decoration: _roadmapFieldDecoration(context: context, isDark: isDark, label: 'Status'),
                              items: RoadmapStepStatus.values
                                  .map((st) => DropdownMenuItem(value: st, child: Text(st.label)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _status = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _hoursCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _roadmapFieldDecoration(context: context, isDark: isDark, label: 'Horas estimadas'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SUBTÓPICOS / CHECKLIST',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: AsterConstants.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subtopicInputCtrl,
                              onSubmitted: (_) => _addSubtopic(),
                              decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                                label: 'Novo subtópico',
                                hint: 'Ex.: Resolver 15 questões de vértice da parábola',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Adicionar subtópico',
                            onPressed: _addSubtopic,
                            icon: Icon(Icons.add_circle_rounded, color: AsterTheme.primary(context), size: 28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._subtopics.asMap().entries.map((entry) {
                        final i = entry.key;
                        final sub = entry.value;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: sub.done,
                            activeColor: AsterConstants.menta,
                            onChanged: (v) {
                              setState(() {
                                _subtopics[i] = sub.copyWith(done: v == true);
                              });
                            },
                          ),
                          title: Text(sub.title, style: GoogleFonts.manrope(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 17, color: AsterConstants.coral),
                            onPressed: () => setState(() => _subtopics.removeAt(i)),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _resourcesCtrl,
                        decoration: _roadmapFieldDecoration(context: context,
                          isDark: isDark,
                          label: 'Materiais / Ações sugeridas (separados por vírgula)',
                          hint: 'Ex.: Caderno de Matemática, Simulado ENEM',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.coral,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftClayPillButton(
                    text: 'Cancelar',
                    isSecondary: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  SoftClayPillButton(
                    text: isEditing ? 'Salvar Etapa' : 'Adicionar Etapa',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
