import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';

/// Abre um modal Soft Clay para editar as metas semanal e diária de estudos.
Future<int?> showWeeklyGoalEditorDialog(
  BuildContext context, {
  int? currentWeekStudiedMinutes,
  int? currentDayStudiedMinutes,
  bool startInDailyMode = false,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _WeeklyGoalEditorDialog(
      currentWeekStudiedMinutes: currentWeekStudiedMinutes,
      currentDayStudiedMinutes: currentDayStudiedMinutes,
      startInDailyMode: startInDailyMode,
    ),
  );
}

/// Abre o editor de metas já focado na Meta Diária de estudos.
Future<int?> showDailyGoalEditorDialog(
  BuildContext context, {
  int? currentWeekStudiedMinutes,
  int? currentDayStudiedMinutes,
}) {
  return showWeeklyGoalEditorDialog(
    context,
    currentWeekStudiedMinutes: currentWeekStudiedMinutes,
    currentDayStudiedMinutes: currentDayStudiedMinutes,
    startInDailyMode: true,
  );
}

class _WeeklyGoalEditorDialog extends StatefulWidget {
  final int? currentWeekStudiedMinutes;
  final int? currentDayStudiedMinutes;
  final bool startInDailyMode;

  const _WeeklyGoalEditorDialog({
    this.currentWeekStudiedMinutes,
    this.currentDayStudiedMinutes,
    this.startInDailyMode = false,
  });

  @override
  State<_WeeklyGoalEditorDialog> createState() => _WeeklyGoalEditorDialogState();
}

class _WeeklyGoalEditorDialogState extends State<_WeeklyGoalEditorDialog> {
  static const List<int> _weeklyPresetHours = [10, 15, 20, 25, 30, 40, 50];
  static const List<int> _dailyPresetMinutes = [30, 60, 120, 180, 240, 360, 480];

  late final TextEditingController _weeklyHoursController;
  late final TextEditingController _weeklyMinutesController;
  late final TextEditingController _dailyHoursController;
  late final TextEditingController _dailyMinutesController;

  late bool _isDailyMode;
  late bool _weeklyEnabled;
  late bool _dailyEnabled;
  bool _weeklyDirty = false;
  bool _dailyDirty = false;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isDailyMode = widget.startInDailyMode;
    final initialWeekly = SupabaseService.weeklyGoalMinutesNotifier.value;
    _weeklyEnabled = initialWeekly > 0;
    final seededWeekly = initialWeekly > 0 ? initialWeekly : SupabaseService.defaultWeeklyGoalMinutes;
    _weeklyHoursController = TextEditingController(text: '${seededWeekly ~/ 60}');
    _weeklyMinutesController = TextEditingController(text: '${seededWeekly % 60}');

    final initialDaily = SupabaseService.dailyGoalMinutesNotifier.value;
    _dailyEnabled = initialDaily > 0;
    final seededDaily = initialDaily > 0 ? initialDaily : SupabaseService.defaultDailyGoalMinutes;
    _dailyHoursController = TextEditingController(text: '${seededDaily ~/ 60}');
    _dailyMinutesController = TextEditingController(text: '${seededDaily % 60}');
  }

  @override
  void dispose() {
    _weeklyHoursController.dispose();
    _weeklyMinutesController.dispose();
    _dailyHoursController.dispose();
    _dailyMinutesController.dispose();
    super.dispose();
  }

  int get _draftWeeklyMinutes {
    final h = int.tryParse(_weeklyHoursController.text.trim()) ?? 0;
    final m = int.tryParse(_weeklyMinutesController.text.trim()) ?? 0;
    return h * 60 + m;
  }

  int get _draftDailyMinutes {
    final h = int.tryParse(_dailyHoursController.text.trim()) ?? 0;
    final m = int.tryParse(_dailyMinutesController.text.trim()) ?? 0;
    return h * 60 + m;
  }

  void _setWeeklyMinutes(int totalMinutes) {
    final clamped = totalMinutes.clamp(
      SupabaseService.minWeeklyGoalMinutes,
      SupabaseService.maxWeeklyGoalMinutes,
    );
    setState(() {
      _weeklyHoursController.text = '${clamped ~/ 60}';
      _weeklyMinutesController.text = '${clamped % 60}';
      _weeklyDirty = true;
      _errorText = null;
    });
  }

  void _setDailyMinutes(int totalMinutes) {
    final clamped = totalMinutes.clamp(
      SupabaseService.minDailyGoalMinutes,
      SupabaseService.maxDailyGoalMinutes,
    );
    setState(() {
      _dailyHoursController.text = '${clamped ~/ 60}';
      _dailyMinutesController.text = '${clamped % 60}';
      _dailyDirty = true;
      _errorText = null;
    });
  }

  Future<void> _save() async {
    final saveWeekly = !_isDailyMode || _weeklyDirty;
    final saveDaily = _isDailyMode || _dailyDirty;

    int? validatedWeekly;
    if (saveWeekly) {
      if (!_weeklyEnabled) {
        validatedWeekly = 0;
      } else {
        final wh = int.tryParse(_weeklyHoursController.text.trim()) ?? 0;
        final wm = int.tryParse(_weeklyMinutesController.text.trim()) ?? 0;
        if (wh < 0 || wm < 0 || wm > 59) {
          setState(() {
            _isDailyMode = false;
            _errorText = 'Informe horas válidas e minutos entre 0 e 59.';
          });
          return;
        }
        final wTotal = wh * 60 + wm;
        if (wTotal < SupabaseService.minWeeklyGoalMinutes ||
            wTotal > SupabaseService.maxWeeklyGoalMinutes) {
          setState(() {
            _isDailyMode = false;
            _errorText = 'A meta semanal deve ficar entre 30 minutos e 168 horas.';
          });
          return;
        }
        validatedWeekly = wTotal;
      }
    }

    int? validatedDaily;
    if (saveDaily) {
      if (!_dailyEnabled) {
        validatedDaily = 0;
      } else {
        final dh = int.tryParse(_dailyHoursController.text.trim()) ?? 0;
        final dm = int.tryParse(_dailyMinutesController.text.trim()) ?? 0;
        if (dh < 0 || dm < 0 || dm > 59) {
          setState(() {
            _isDailyMode = true;
            _errorText = 'Informe horas válidas e minutos entre 0 e 59.';
          });
          return;
        }
        final dTotal = dh * 60 + dm;
        if (dTotal < SupabaseService.minDailyGoalMinutes ||
            dTotal > SupabaseService.maxDailyGoalMinutes) {
          setState(() {
            _isDailyMode = true;
            _errorText = 'A meta diária deve ficar entre 15 minutos e 24 horas.';
          });
          return;
        }
        validatedDaily = dTotal;
      }
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    if (validatedWeekly != null) {
      await SupabaseService.saveWeeklyGoalMinutes(validatedWeekly);
    }
    if (validatedDaily != null) {
      await SupabaseService.saveDailyGoalMinutes(validatedDaily);
    }

    if (!mounted) return;
    final poppedValue = _isDailyMode
        ? (validatedDaily ?? SupabaseService.dailyGoalMinutesNotifier.value)
        : (validatedWeekly ?? SupabaseService.weeklyGoalMinutesNotifier.value);
    Navigator.of(context).pop(poppedValue);

    String labelFor(int val, String emptyLabel) =>
        val <= 0 ? emptyLabel : SupabaseService.formatGoalDuration(val);

    String snackMessage;
    if (validatedWeekly != null && validatedDaily != null) {
      snackMessage =
          'Metas atualizadas · Diária: ${labelFor(validatedDaily, 'sem meta')} · Semanal: ${labelFor(validatedWeekly, 'sem meta')}.';
    } else if (validatedDaily != null) {
      snackMessage = validatedDaily <= 0
          ? 'Meta diária desativada (modo livre).'
          : 'Meta diária atualizada para ${SupabaseService.formatGoalDuration(validatedDaily)}!';
    } else {
      snackMessage = validatedWeekly! <= 0
          ? 'Meta semanal desativada (modo livre).'
          : 'Meta semanal atualizada para ${SupabaseService.formatGoalDuration(validatedWeekly)}!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AsterConstants.menta,
        content: Text(snackMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActiveEnabled = _isDailyMode ? _dailyEnabled : _weeklyEnabled;
    final draftTotal = _isDailyMode ? _draftDailyMinutes : _draftWeeklyMinutes;
    final minAllowed = _isDailyMode
        ? SupabaseService.minDailyGoalMinutes
        : SupabaseService.minWeeklyGoalMinutes;
    final safeTotal = draftTotal > 0 ? draftTotal : 1;
    final studied = _isDailyMode
        ? widget.currentDayStudiedMinutes
        : widget.currentWeekStudiedMinutes;
    final pct = studied != null ? ((studied / safeTotal) * 100).round().clamp(0, 999) : null;

    final secondaryHelperText = _isDailyMode
        ? (draftTotal >= 15
            ? 'Equivalente: ~${SupabaseService.formatGoalDuration(draftTotal * 7)}/semana'
            : 'Mínimo: 15m')
        : (draftTotal >= 30
            ? 'Média: ~${SupabaseService.formatGoalDuration((draftTotal / 7).round())}/dia'
            : 'Mínimo: 30m');

    return Dialog(
      backgroundColor: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isDailyMode ? Icons.today_rounded : Icons.track_changes_rounded,
                      size: 20,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDailyMode ? 'Editar Meta Diária' : 'Editar Meta Semanal',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        Text(
                          _isDailyMode
                              ? 'Defina sua carga horária alvo de estudos por dia.'
                              : 'Defina sua carga horária alvo de estudos por semana.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ─── Seletor de Modo: Semanal vs Diária ───
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        key: const Key('goal_mode_weekly_tab'),
                        label: 'Meta Semanal',
                        icon: Icons.date_range_rounded,
                        selected: !_isDailyMode,
                        isDark: isDark,
                        onTap: () => setState(() {
                          _isDailyMode = false;
                          _errorText = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildModeTab(
                        key: const Key('goal_mode_daily_tab'),
                        label: 'Meta Diária',
                        icon: Icons.today_rounded,
                        selected: _isDailyMode,
                        isDark: isDark,
                        onTap: () => setState(() {
                          _isDailyMode = true;
                          _errorText = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Ativar / optar por não ter meta ───
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  border: Border.all(
                    color: isActiveEnabled
                        ? AsterTheme.primary(context).withValues(alpha: 0.25)
                        : AsterTheme.surfaceInset(context),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDailyMode ? 'Ativar meta diária' : 'Ativar meta semanal',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isActiveEnabled
                                ? 'Desative se preferir estudar sem meta fixa ${_isDailyMode ? 'por dia' : 'por semana'}.'
                                : 'Modo livre ativo · nenhuma cobrança de meta ${_isDailyMode ? 'diária' : 'semanal'}.',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      key: Key(
                        _isDailyMode ? 'goal_daily_enabled_switch' : 'goal_weekly_enabled_switch',
                      ),
                      value: isActiveEnabled,
                      onChanged: (enabled) => setState(() {
                        if (_isDailyMode) {
                          _dailyEnabled = enabled;
                          _dailyDirty = true;
                        } else {
                          _weeklyEnabled = enabled;
                          _weeklyDirty = true;
                        }
                        _errorText = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!isActiveEnabled) ...[
                Container(
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
                          Icon(
                            Icons.spa_outlined,
                            size: 18,
                            color: AsterTheme.secondary(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isDailyMode
                                  ? 'Sem meta diária definida'
                                  : 'Sem meta semanal definida',
                              style: GoogleFonts.manrope(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Seu tempo estudado continua sendo registrado normalmente no Diário e na Consistência, sem metas ou alertas ${_isDailyMode ? 'diários' : 'semanais'}.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                      if (studied != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _isDailyMode
                              ? 'Estudado hoje: ${SupabaseService.formatGoalDuration(studied)}'
                              : 'Estudado na semana: ${SupabaseService.formatGoalDuration(studied)}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.secondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // ─── Atalhos rápidos ───
                Text(
                  'ATALHOS RÁPIDOS',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (_isDailyMode
                          ? _dailyPresetMinutes
                          : _weeklyPresetHours.map((h) => h * 60).toList())
                      .map((presetMinutes) {
                    final isSelected = draftTotal == presetMinutes;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      onTap: () => _isDailyMode
                          ? _setDailyMinutes(presetMinutes)
                          : _setWeeklyMinutes(presetMinutes),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AsterTheme.primary(context)
                              : (isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          border: Border.all(
                            color: isSelected
                                ? AsterTheme.primary(context)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : AsterTheme.primary(context).withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Text(
                          SupabaseService.formatGoalDuration(presetMinutes),
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AsterConstants.textLight : AsterConstants.textDark),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ─── Ajuste personalizado ───
                Text(
                  'AJUSTE PERSONALIZADO',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key(_isDailyMode ? 'daily_goal_hours_field' : 'weekly_goal_hours_field'),
                        controller: _isDailyMode ? _dailyHoursController : _weeklyHoursController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {
                          if (_isDailyMode) {
                            _dailyDirty = true;
                          } else {
                            _weeklyDirty = true;
                          }
                          _errorText = null;
                        }),
                        decoration: InputDecoration(
                          labelText: _isDailyMode ? 'Horas / dia' : 'Horas / semana',
                          suffixText: 'h',
                          filled: true,
                          fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: Key(
                          _isDailyMode ? 'daily_goal_minutes_field' : 'weekly_goal_minutes_field',
                        ),
                        controller: _isDailyMode ? _dailyMinutesController : _weeklyMinutesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {
                          if (_isDailyMode) {
                            _dailyDirty = true;
                          } else {
                            _weeklyDirty = true;
                          }
                          _errorText = null;
                        }),
                        decoration: InputDecoration(
                          labelText: 'Minutos extra',
                          suffixText: 'min',
                          filled: true,
                          fillColor: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _isDailyMode
                          ? _setDailyMinutes(draftTotal - 15)
                          : _setWeeklyMinutes(draftTotal - 60),
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      label: Text(_isDailyMode ? '15m' : '1h'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _isDailyMode
                          ? _setDailyMinutes(draftTotal + 15)
                          : _setWeeklyMinutes(draftTotal + 60),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(_isDailyMode ? '15m' : '1h'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        secondaryHelperText,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),

                if (studied != null && pct != null && draftTotal >= minAllowed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isDailyMode ? 'Prévia de hoje' : 'Prévia da semana atual',
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                            Text(
                              '${SupabaseService.formatGoalDuration(studied)} / ${SupabaseService.formatGoalDuration(draftTotal)} · $pct%',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AsterConstants.menta,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (studied / safeTotal).clamp(0.0, 1.0),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          backgroundColor:
                              isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
                          valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AsterConstants.coral,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SoftClayPillButton(
                    text: _isSaving ? 'Salvando...' : 'Salvar Meta',
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AsterTheme.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? Colors.white
                  : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
