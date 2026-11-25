import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';

/// Abre um modal Soft Clay para editar a meta semanal de estudos do usuário.
Future<int?> showWeeklyGoalEditorDialog(
  BuildContext context, {
  int? currentWeekStudiedMinutes,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _WeeklyGoalEditorDialog(
      currentWeekStudiedMinutes: currentWeekStudiedMinutes,
    ),
  );
}

class _WeeklyGoalEditorDialog extends StatefulWidget {
  final int? currentWeekStudiedMinutes;

  const _WeeklyGoalEditorDialog({this.currentWeekStudiedMinutes});

  @override
  State<_WeeklyGoalEditorDialog> createState() => _WeeklyGoalEditorDialogState();
}

class _WeeklyGoalEditorDialogState extends State<_WeeklyGoalEditorDialog> {
  static const List<int> _presetHours = [10, 15, 20, 25, 30, 40, 50];

  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialTotal = SupabaseService.weeklyGoalMinutesNotifier.value;
    _hoursController = TextEditingController(text: '${initialTotal ~/ 60}');
    _minutesController = TextEditingController(text: '${initialTotal % 60}');
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  int get _draftTotalMinutes {
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    return h * 60 + m;
  }

  void _setTotalMinutes(int totalMinutes) {
    final clamped = totalMinutes.clamp(
      SupabaseService.minWeeklyGoalMinutes,
      SupabaseService.maxWeeklyGoalMinutes,
    );
    setState(() {
      _hoursController.text = '${clamped ~/ 60}';
      _minutesController.text = '${clamped % 60}';
      _errorText = null;
    });
  }

  Future<void> _save() async {
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;

    if (h < 0 || m < 0 || m > 59) {
      setState(() {
        _errorText = 'Informe horas válidas e minutos entre 0 e 59.';
      });
      return;
    }

    final total = h * 60 + m;
    if (total < SupabaseService.minWeeklyGoalMinutes ||
        total > SupabaseService.maxWeeklyGoalMinutes) {
      setState(() {
        _errorText = 'A meta semanal deve ficar entre 30 minutos e 168 horas.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    await SupabaseService.saveWeeklyGoalMinutes(total);

    if (!mounted) return;
    Navigator.of(context).pop(total);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AsterConstants.menta,
        content: Text(
          'Meta semanal atualizada para ${SupabaseService.formatGoalDuration(total)}!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draftTotal = _draftTotalMinutes;
    final safeTotal = draftTotal > 0 ? draftTotal : 1;
    final dailyAvgMinutes = (draftTotal / 7).round();
    final studied = widget.currentWeekStudiedMinutes;
    final pct = studied != null ? ((studied / safeTotal) * 100).round().clamp(0, 999) : null;

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
                      Icons.track_changes_rounded,
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
                          'Editar Meta Semanal',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        Text(
                          'Defina sua carga horária alvo de estudos por semana.',
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
              const SizedBox(height: 18),

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
                children: _presetHours.map((hours) {
                  final presetMinutes = hours * 60;
                  final isSelected = draftTotal == presetMinutes;
                  return InkWell(
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    onTap: () => _setTotalMinutes(presetMinutes),
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
                        '${hours}h',
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
                      key: const Key('weekly_goal_hours_field'),
                      controller: _hoursController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _errorText = null),
                      decoration: InputDecoration(
                        labelText: 'Horas / semana',
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
                      key: const Key('weekly_goal_minutes_field'),
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() => _errorText = null),
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
                    onPressed: () => _setTotalMinutes(draftTotal - 60),
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    label: const Text('1h'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _setTotalMinutes(draftTotal + 60),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('1h'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    draftTotal >= 30
                        ? 'Média: ~${SupabaseService.formatGoalDuration(dailyAvgMinutes)}/dia'
                        : 'Mínimo: 30m',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                    ),
                  ),
                ],
              ),

              if (studied != null && pct != null && draftTotal >= 30) ...[
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
                            'Prévia da semana atual',
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
}
