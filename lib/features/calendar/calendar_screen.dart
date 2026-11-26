import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/noesis_agent_tools.dart';
import '../../core/theme.dart';
import '../../core/supabase_service.dart';
import '../../widgets/vip_rgb_theme_editor.dart';

class CalendarCategory {
  final String id;
  final String label;
  final Color color;
  final String hex;
  final IconData icon;

  const CalendarCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.hex,
    required this.icon,
  });

  CalendarCategory copyWith({
    String? id,
    String? label,
    Color? color,
    String? hex,
    IconData? icon,
  }) {
    return CalendarCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      color: color ?? this.color,
      hex: hex ?? this.hex,
      icon: icon ?? this.icon,
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String _activeViewMode = 'Semana'; // 'Dia', 'Semana', 'Mês', 'Timeline'
  String? _selectedCategoryFilter; // null = Todos, ou 'study', 'review', 'lab', 'exam'

  late final ValueNotifier<DateTime> _selectedDayNotifier;
  late final ValueNotifier<String> _activeViewModeNotifier;
  late final ValueNotifier<String?> _selectedCategoryFilterNotifier;

  bool _aiSuggestionDismissed = false;
  bool _aiSuggestionScheduled = false;
  String? _scheduledRecommendationTitle;
  List<CalendarAiRecommendation> _aiRecommendations = [];
  int _aiRecommendationIndex = 0;
  String _lastEventsSignature = '';

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _dialogCategory = 'study';
  String _dialogColorHex = '#7C6CF0';
  late DateTime _dialogDate;
  int _dialogStartHour = 9;
  int _dialogStartMinute = 0;
  int _dialogDurationMinutes = 60; // 30, 60, 90, 120, 180

  static final Map<String, CalendarCategory> _categoryInfo = {
    'study': const CalendarCategory(id: 'study', label: 'Estudo', color: AsterConstants.lavanda, hex: '#7C6CF0', icon: Icons.menu_book_rounded),
    'review': const CalendarCategory(id: 'review', label: 'Revisão', color: AsterConstants.menta, hex: '#3CCF9A', icon: Icons.replay_rounded),
    'lab': const CalendarCategory(id: 'lab', label: 'Lab / Simulado', color: AsterConstants.ambar, hex: '#F5A623', icon: Icons.science_rounded),
    'exam': const CalendarCategory(id: 'exam', label: 'Prova / Compromisso', color: AsterConstants.coral, hex: '#FF7A90', icon: Icons.event_available_rounded),
  };

  static const List<({String name, IconData icon})> _availableCategoryIcons = [
    (name: 'Estudo', icon: Icons.menu_book_rounded),
    (name: 'Revisão', icon: Icons.replay_rounded),
    (name: 'Lab', icon: Icons.science_rounded),
    (name: 'Prova', icon: Icons.event_available_rounded),
    (name: 'Código', icon: Icons.code_rounded),
    (name: 'Computador', icon: Icons.laptop_mac_rounded),
    (name: 'Alvo / Foco', icon: Icons.track_changes_rounded),
    (name: 'Trabalho', icon: Icons.work_outline_rounded),
    (name: 'Treino', icon: Icons.fitness_center_rounded),
    (name: 'Café', icon: Icons.local_cafe_rounded),
    (name: 'Ideia', icon: Icons.lightbulb_outline_rounded),
    (name: 'Fogo', icon: Icons.local_fire_department_rounded),
    (name: 'Estrela', icon: Icons.star_rounded),
    (name: 'Música', icon: Icons.headphones_rounded),
    (name: 'Chave / Segurança', icon: Icons.vpn_key_rounded),
    (name: 'Bug / Testes', icon: Icons.bug_report_rounded),
  ];

  static const List<({String name, Color color, String hex})> _colorPalette = [
    (name: 'Lavanda', color: AsterConstants.lavanda, hex: '#7C6CF0'),
    (name: 'Menta', color: AsterConstants.menta, hex: '#3CCF9A'),
    (name: 'Âmbar', color: AsterConstants.ambar, hex: '#F5A623'),
    (name: 'Coral', color: AsterConstants.coral, hex: '#FF7A90'),
    (name: 'Azul Céu', color: Color(0xFF3B82F6), hex: '#3B82F6'),
    (name: 'Índigo', color: Color(0xFF6366F1), hex: '#6366F1'),
    (name: 'Púrpura', color: Color(0xFF8B5CF6), hex: '#8B5CF6'),
    (name: 'Turquesa', color: Color(0xFF06B6D4), hex: '#06B6D4'),
    (name: 'Laranja', color: Color(0xFFF97316), hex: '#F97316'),
    (name: 'Rosa', color: Color(0xFFEC4899), hex: '#EC4899'),
  ];

  late final Stream<List<Map<String, dynamic>>> _eventsStream;
  final Map<String, DateTime> _parsedDateCache = {};
  late final ScrollController _weekScrollController;
  bool _isDraggingCalendarEvent = false;
  String? _draggingEventId;
  final ValueNotifier<({int dayIdx, int startMinutes, int durationMinutes, Color color, String title})?>
      _dragPreviewNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _dialogDate = _selectedDay;
    _weekScrollController = ScrollController(initialScrollOffset: 7 * 58.0);
    _selectedDayNotifier = ValueNotifier<DateTime>(_selectedDay);
    _activeViewModeNotifier = ValueNotifier<String>(_activeViewMode);
    _selectedCategoryFilterNotifier = ValueNotifier<String?>(_selectedCategoryFilter);
    _eventsStream = SupabaseService.calendarEventsStream().distinct((prev, next) {
      if (prev.length != next.length) return false;
      for (int i = 0; i < prev.length; i++) {
        if (!mapEquals(prev[i], next[i])) return false;
      }
      return true;
    });
    _refreshAiRecommendations();
  }

  Future<void> _refreshAiRecommendations([List<Map<String, dynamic>>? currentEvents]) async {
    try {
      final recs = await NoesisAgentTools.buildCalendarRecommendations(
        calendarEvents: currentEvents,
      );
      if (!mounted || recs.isEmpty) return;
      setState(() {
        _aiRecommendations = recs;
        if (_aiRecommendationIndex >= recs.length) {
          _aiRecommendationIndex = 0;
        }
      });
    } catch (_) {}
  }

  void _syncRecommendationsIfEventsChanged(List<Map<String, dynamic>> rawEvents) {
    final sig = '${rawEvents.length}:${rawEvents.map((e) => '${e['id']}_${e['start_time']}').take(12).join('|')}';
    if (sig != _lastEventsSignature) {
      _lastEventsSignature = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshAiRecommendations(rawEvents);
        }
      });
    }
  }

  @override
  void dispose() {
    _weekScrollController.dispose();
    _dragPreviewNotifier.dispose();
    _selectedDayNotifier.dispose();
    _activeViewModeNotifier.dispose();
    _selectedCategoryFilterNotifier.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _rescheduleEventByDrag(Map<String, dynamic> event, DateTime newStart) async {
    final id = event['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final oldStart = _parseDateTime(event['start_time']);
    final oldEnd = _parseDateTime(event['end_time']);
    final durationMinutes = oldEnd.difference(oldStart).inMinutes.clamp(15, 720);

    if (newStart.year == oldStart.year &&
        newStart.month == oldStart.month &&
        newStart.day == oldStart.day &&
        newStart.hour == oldStart.hour &&
        newStart.minute == oldStart.minute) {
      return;
    }

    final newEnd = newStart.add(Duration(minutes: durationMinutes));
    final title = (event['title'] ?? 'Bloco').toString();

    _parsedDateCache.clear();
    setState(() {
      _selectedDay = newStart;
      _focusedDay = newStart;
      _selectedDayNotifier.value = newStart;
    });

    try {
      await SupabaseService.updateCalendarEvent(
        id: id,
        startTime: newStart,
        endTime: newEnd,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              backgroundColor: AsterConstants.coral,
              content: Text('Não foi possível mover o bloco. Tente novamente.'),
            ),
          );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: AsterTheme.primary(context),
            content: Text(
              'Bloco "$title" movido para ${DateFormat("E, d/MM 'às' HH:mm", 'pt_BR').format(newStart)}.',
              style: GoogleFonts.manrope(
                color: AsterTheme.onPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
    }
  }

  Color _resolveCalendarColor(Color raw) =>
      raw == AsterConstants.lavanda ? AsterTheme.primary(context) : raw;

  bool _isDarkTheme(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _subtleBorderColor(BuildContext context, [double? strength]) {
    final card = AsterTheme.card(context);
    final ink = AsterTheme.text(context);
    final t = strength ?? (_isDarkTheme(context) ? 0.16 : 0.13);
    return Color.lerp(card, ink, t) ?? AsterTheme.surfaceInset(context);
  }

  double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _readableAccent(Color accent, Color background) {
    if (_contrastRatio(accent, background) >= 4.0) return accent;
    final bgDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final target = bgDark ? Colors.white : const Color(0xFF141624);
    for (final t in const [0.25, 0.4, 0.55, 0.7, 0.85]) {
      final candidate = Color.lerp(accent, target, t)!;
      if (_contrastRatio(candidate, background) >= 4.2) return candidate;
    }
    return target;
  }

  ThemeData _themedPickerTheme(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final cardBg = AsterTheme.card(context);
    final textCol = AsterTheme.text(context);
    final accentAction = _readableAccent(cs.primary, cardBg);
    return base.copyWith(
      datePickerTheme: DatePickerThemeData(
        backgroundColor: cardBg,
        headerBackgroundColor: cs.primary,
        headerForegroundColor: cs.onPrimary,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          if (states.contains(WidgetState.disabled)) {
            return AsterTheme.textMuted(context).withValues(alpha: 0.45);
          }
          return textCol;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          return accentAction;
        }),
        todayBorder: BorderSide(color: accentAction, width: 1.4),
        weekdayStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AsterTheme.textMuted(context),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: accentAction,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AsterTheme.textMuted(context),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Color _onColor(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.light
          ? const Color(0xFF111111)
          : Colors.white;

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim().toUpperCase();
      return Color(int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
    } catch (_) {
      return AsterConstants.lavanda;
    }
  }

  Widget _buildColorPaletteWrap({
    required String currentHex,
    required ValueChanged<String> onHexChanged,
  }) {
    final isPreset = _colorPalette.any(
      (p) => p.hex.toUpperCase() == currentHex.toUpperCase(),
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._colorPalette.map((p) {
          final isSelected = currentHex.toUpperCase() == p.hex.toUpperCase();
          return InkWell(
            onTap: () => onHexChanged(p.hex),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.color,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: p.color.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
                    )
                  : null,
            ),
          );
        }),
        VipRgbColorTrigger(
          currentColor: _parseHexColor(currentHex),
          isCustomSelected: !isPreset,
          onColorSelected: (c) => onHexChanged(VipRgbSpectrumPicker.colorToHex(c)),
        ),
      ],
    );
  }

  Color _getCategoryColor(String? cat) =>
      _resolveCalendarColor(_categoryInfo[cat]?.color ?? AsterConstants.lavanda);
  String _getCategoryLabel(String? cat) => _categoryInfo[cat]?.label ?? 'Estudo';
  IconData _getCategoryIcon(String? cat) => _categoryInfo[cat]?.icon ?? Icons.menu_book_rounded;

  Color _getEventColor(Map<String, dynamic> event) {
    if (event['color'] != null) {
      final cStr = event['color'].toString();
      if (cStr.startsWith('#')) {
        final hex = cStr.replaceAll('#', '').toUpperCase();
        if (hex == '7C6CF0') return AsterTheme.primary(context);
        try {
          final parsed = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
          return _resolveCalendarColor(parsed);
        } catch (_) {}
      } else if (int.tryParse(cStr) != null) {
        return _resolveCalendarColor(Color(int.parse(cStr)));
      }
    }
    return _getCategoryColor(event['category']);
  }

  DateTime _parseDateTime(dynamic val) {
    if (val is DateTime) return val.toLocal();
    if (val is String) {
      final cached = _parsedDateCache[val];
      if (cached != null) return cached;
      try {
        final parsed = DateTime.parse(val).toLocal();
        _parsedDateCache[val] = parsed;
        return parsed;
      } catch (_) {}
    }
    return DateTime.now();
  }

  List<Map<String, dynamic>> _getEventsForDay(List<Map<String, dynamic>> allEvents, DateTime day) {
    final y = day.year;
    final m = day.month;
    final d = day.day;
    return allEvents.where((evt) {
      final start = _parseDateTime(evt['start_time']);
      return start.year == y && start.month == m && start.day == d;
    }).toList();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> events, [String? filter]) {
    final cat = filter ?? _selectedCategoryFilter;
    if (cat == null) return events;
    return events.where((e) => e['category'] == cat).toList();
  }

  void _confirmDeleteEvent(Map<String, dynamic> event) {
    final title = event['title'] ?? 'Bloco';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AsterTheme.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AsterConstants.coral.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AsterConstants.coral, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Excluir Bloco',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  color: AsterTheme.text(context),
                ),
              ),
            ],
          ),
          content: Text(
            'Tem certeza que deseja remover o bloco "$title" da sua agenda?',
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.4,
              color: AsterTheme.textMuted(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.manrope(color: AsterTheme.textMuted(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AsterConstants.coral,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _deleteEventWithUndo(event);
              },
              child: Text('Sim, Excluir', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _deleteEventWithUndo(Map<String, dynamic> event) async {
    final id = event['id']?.toString() ?? '';
    final title = event['title'] ?? 'Bloco';
    if (id.isEmpty) return;

    try {
      await SupabaseService.deleteCalendarEvent(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              backgroundColor: AsterConstants.coral,
              content: Text('Não foi possível excluir o bloco. Tente novamente.'),
            ),
          );
      }
      return;
    }

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 4),
            backgroundColor: AsterConstants.surfaceDark,
            content: Text(
              'Bloco "$title" excluído com sucesso.',
              style: const TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Desfazer',
              textColor: AsterConstants.ambar,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                SupabaseService.addCalendarEvent(
                  title: event['title'] ?? '',
                  description: event['description'],
                  category: event['category'] ?? 'study',
                  color: event['color'],
                  startTime: _parseDateTime(event['start_time']),
                  endTime: _parseDateTime(event['end_time']),
                ).catchError((_) => <String, dynamic>{});
              },
            ),
          ),
        );
    }
  }

  void _openAddEventDialog({DateTime? prefilledDate, int? prefilledHour}) {
    _dialogDate = prefilledDate ?? _selectedDay;
    _dialogStartHour = prefilledHour ?? 9;
    _dialogStartMinute = 0;
    _dialogDurationMinutes = 60;
    final initialCat = _selectedCategoryFilter != null && _categoryInfo.containsKey(_selectedCategoryFilter)
        ? _selectedCategoryFilter!
        : (_categoryInfo.containsKey('study') ? 'study' : _categoryInfo.keys.first);
    _dialogCategory = initialCat;
    _dialogColorHex = _categoryInfo[_dialogCategory]?.hex ?? '#7C6CF0';
    _titleController.clear();
    _descController.clear();

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final cardBg = AsterTheme.card(context);
          final textCol = AsterTheme.text(context);
          final primaryCol = AsterTheme.primary(context);
          final readablePrimary = _readableAccent(primaryCol, cardBg);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
              side: BorderSide(color: _subtleBorderColor(context, 0.16), width: 1),
            ),
            title: Text(
              'Novo Bloco / Agendamento',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: textCol,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.manrope(color: textCol),
                    decoration: const InputDecoration(
                      labelText: 'Título do Bloco',
                      hintText: 'ex: Prova Security+, Revisão de Redes',
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _categoryInfo.containsKey(_dialogCategory) ? _dialogCategory : _categoryInfo.keys.first,
                    dropdownColor: cardBg,
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textCol),
                    decoration: const InputDecoration(labelText: 'Categoria Semântica'),
                    items: [
                      ..._categoryInfo.entries.map((e) {
                        final catColor = _resolveCalendarColor(e.value.color);
                        return DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(e.value.label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textCol)),
                            ],
                          ),
                        );
                      }),
                      DropdownMenuItem(
                        value: '__add_category__',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 15, color: readablePrimary),
                            const SizedBox(width: 8),
                            Text(
                              '+ Nova Categoria...',
                              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: readablePrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__add_category__') {
                        _openAddEditCategoryDialog(
                          onSaved: () {
                            setModalState(() {
                              _dialogCategory = _categoryInfo.keys.last;
                              _dialogColorHex = _categoryInfo.values.last.hex;
                            });
                          },
                        );
                      } else if (val != null) {
                        setModalState(() {
                          _dialogCategory = val;
                          _dialogColorHex = _categoryInfo[val]?.hex ?? '#7C6CF0';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // ─── Seletor de Cores Personalizadas ───
                  Text(
                    'Cor do Bloco',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textCol),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPaletteWrap(
                    currentHex: _dialogColorHex,
                    onHexChanged: (hex) => setModalState(() => _dialogColorHex = hex),
                  ),
                  const SizedBox(height: 16),

                  // Seletor de Data
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dialogDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        locale: const Locale('pt', 'BR'),
                        builder: (pickerCtx, child) => Theme(
                          data: _themedPickerTheme(pickerCtx),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => _dialogDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AsterTheme.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(color: _subtleBorderColor(context, 0.14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: readablePrimary),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_dialogDate),
                                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textCol),
                              ),
                            ],
                          ),
                          Icon(Icons.edit_calendar_rounded, size: 16, color: AsterTheme.textMuted(context)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Seletor de Horário e Duração
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<int>(
                          value: _dialogStartHour,
                          dropdownColor: cardBg,
                          style: GoogleFonts.manrope(fontSize: 13, color: textCol),
                          decoration: const InputDecoration(labelText: 'Horário de Início'),
                          items: List.generate(24, (i) => i).map((h) {
                            final hStr = '${h.toString().padLeft(2, '0')}:00';
                            return DropdownMenuItem(value: h, child: Text(hStr, style: GoogleFonts.manrope(fontSize: 13, color: textCol)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => _dialogStartHour = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<int>(
                          value: _dialogDurationMinutes,
                          dropdownColor: cardBg,
                          style: GoogleFonts.manrope(fontSize: 13, color: textCol),
                          decoration: const InputDecoration(labelText: 'Duração'),
                          items: [
                            DropdownMenuItem(value: 30, child: Text('30 min', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                            DropdownMenuItem(value: 60, child: Text('1 hora', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                            DropdownMenuItem(value: 90, child: Text('1h 30m', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                            DropdownMenuItem(value: 120, child: Text('2 horas', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                            DropdownMenuItem(value: 180, child: Text('3 horas', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => _dialogDurationMinutes = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    style: GoogleFonts.manrope(color: textCol),
                    decoration: const InputDecoration(
                      labelText: 'Detalhes ou Objetivos (opcional)',
                      hintText: 'Capítulos, links de lab, requisitos de estudo...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterTheme.textMuted(context))),
              ),
              SoftClayPillButton(
                text: isSaving ? 'Salvando...' : 'Agendar Bloco',
                onPressed: isSaving
                    ? null
                    : () async {
                        final title = _titleController.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Por favor, informe o título do bloco.')),
                          );
                          return;
                        }

                        final start = DateTime(
                          _dialogDate.year,
                          _dialogDate.month,
                          _dialogDate.day,
                          _dialogStartHour,
                          _dialogStartMinute,
                        );
                        final end = start.add(Duration(minutes: _dialogDurationMinutes));

                        setModalState(() => isSaving = true);
                        try {
                          await SupabaseService.addCalendarEvent(
                            title: title,
                            description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
                            category: _dialogCategory,
                            color: _dialogColorHex,
                            startTime: start,
                            endTime: end,
                          );
                        } catch (e) {
                          if (ctx.mounted) {
                            setModalState(() => isSaving = false);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AsterConstants.coral,
                                content: Text('Erro ao salvar bloco no calendário. Verifique sua conexão e tente novamente.'),
                              ),
                            );
                          }
                          return;
                        }

                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        _titleController.clear();
                        _descController.clear();
                        setState(() {
                          _selectedDay = _dialogDate;
                          _focusedDay = _dialogDate;
                          _selectedDayNotifier.value = _dialogDate;
                          if (_selectedCategoryFilter != null &&
                              _selectedCategoryFilter != _dialogCategory) {
                            _selectedCategoryFilter = null;
                            _selectedCategoryFilterNotifier.value = null;
                          }
                        });
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            backgroundColor: AsterTheme.primary(this.context),
                            content: Text(
                              'Bloco "$title" agendado com sucesso!',
                              style: GoogleFonts.manrope(
                                color: AsterTheme.onPrimary(this.context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventDetailsDialog(Map<String, dynamic> event) {
    final title = event['title'] ?? 'Sem título';
    final desc = event['description'] ?? '';
    final category = event['category'] ?? 'study';
    final start = _parseDateTime(event['start_time']);
    final end = _parseDateTime(event['end_time']);
    final isCompleted = event['is_completed'] == true;
    final color = _getEventColor(event);
    final label = _getCategoryLabel(category);
    final icon = _getCategoryIcon(category);

    final duration = end.difference(start);
    final durationHours = duration.inMinutes / 60.0;
    final durationStr = durationHours == durationHours.truncateToDouble()
        ? '${durationHours.toInt()}h'
        : '${durationHours.toStringAsFixed(1)}h';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = _isDarkTheme(ctx);
        final cardBg = AsterTheme.card(ctx);
        final textCol = AsterTheme.text(ctx);
        final primaryCol = AsterTheme.primary(ctx);
        final readableColor = _readableAccent(color, cardBg);
        final readablePrimary = _readableAccent(primaryCol, cardBg);
        final readableCoral = _readableAccent(AsterConstants.coral, cardBg);
        final statusRaw = isCompleted ? AsterConstants.menta : AsterConstants.ambar;
        final statusReadable = _readableAccent(statusRaw, cardBg);

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            side: BorderSide(color: _subtleBorderColor(ctx, 0.16), width: 1),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.24 : 0.15), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: readableColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    Text(label, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: readableColor)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cartão Interativo de Data e Horário (Toque para trocar data/horário)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditEventDialog(event);
                },
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryCol.withValues(alpha: isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(color: readablePrimary.withValues(alpha: 0.32), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 18, color: readablePrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(start)} · ${DateFormat('HH:mm').format(start)} às ${DateFormat('HH:mm').format(end)} ($durationStr)',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textCol,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Toque para remarcar data ou horário ✏️',
                              style: GoogleFonts.manrope(fontSize: 10.5, color: readablePrimary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_calendar_rounded, size: 16, color: readablePrimary),
                    ],
                  ),
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(ctx),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(color: _subtleBorderColor(ctx, 0.12), width: 1),
                  ),
                  child: Text(
                    desc,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.4,
                      color: textCol,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Status:',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AsterTheme.textMuted(ctx),
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusRaw.withValues(alpha: isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                  child: Text(
                    isCompleted ? 'Concluído' : 'Pendente',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusReadable,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: readableCoral,
                  side: BorderSide(color: readableCoral, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text('Excluir', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteEvent(event);
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: readablePrimary,
                  side: BorderSide(color: readablePrimary, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                ),
                icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                label: Text('Editar', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openEditEventDialog(event);
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final id = event['id']?.toString() ?? '';
                  if (id.isNotEmpty) {
                    try {
                      await SupabaseService.toggleCalendarEventCompleted(id, !isCompleted);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AsterConstants.coral,
                            content: Text('Não foi possível atualizar o status do bloco.'),
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(
                  isCompleted ? 'Marcar Pendente' : 'Marcar Concluído',
                  style: GoogleFonts.manrope(color: readablePrimary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              SoftClayPillButton(
                text: 'Fechar',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ],
      );
    },
  );
}

  void _openEditEventDialog(Map<String, dynamic> event) {
    final eventId = event['id']?.toString() ?? '';
    final start = _parseDateTime(event['start_time']);
    final end = _parseDateTime(event['end_time']);
    final duration = end.difference(start);

    DateTime editDate = start;
    int editStartHour = start.hour;
    int editStartMinute = start.minute;
    int editDurationMinutes = duration.inMinutes.clamp(15, 480);
    String editCategory = event['category'] ?? 'study';
    String editColorHex = event['color'] ?? (_categoryInfo[editCategory]?.hex ?? '#7C6CF0');
    final titleEditController = TextEditingController(text: event['title'] ?? '');
    final descEditController = TextEditingController(text: event['description'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final cardBg = AsterTheme.card(context);
          final textCol = AsterTheme.text(context);
          final primaryCol = AsterTheme.primary(context);
          final readablePrimary = _readableAccent(primaryCol, cardBg);
          final computedStart = DateTime(
            editDate.year,
            editDate.month,
            editDate.day,
            editStartHour,
            editStartMinute,
          );
          final computedEnd = computedStart.add(Duration(minutes: editDurationMinutes));
          final durH = editDurationMinutes / 60.0;
          final durStr = durH == durH.truncateToDouble() ? '${durH.toInt()}h' : '${durH.toStringAsFixed(1)}h';
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
              side: BorderSide(color: _subtleBorderColor(context, 0.16), width: 1),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryCol.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_calendar_rounded, size: 20, color: readablePrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar Data & Horário da Tarefa',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: textCol,
                        ),
                      ),
                      Text(
                        'Altere o dia, horário ou tempo estimado',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleEditController,
                    style: GoogleFonts.manrope(color: textCol),
                    decoration: const InputDecoration(
                      labelText: 'Título do Bloco',
                      hintText: 'ex: Prova Security+, Revisão de Redes',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── 1. Seletor de Data Interativo ───
                  Text(
                    'DATA DA TAREFA',
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AsterTheme.textMuted(context)),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: editDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        locale: const Locale('pt', 'BR'),
                        builder: (pickerCtx, child) => Theme(
                          data: _themedPickerTheme(pickerCtx),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => editDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AsterTheme.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(color: readablePrimary.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: readablePrimary),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(editDate),
                                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: textCol),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryCol.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 12, color: readablePrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Trocar Data',
                                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: readablePrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── 2. Seletor de Horário e Duração ───
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HORÁRIO DE INÍCIO',
                              style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AsterTheme.textMuted(context)),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: editStartHour,
                              dropdownColor: cardBg,
                              style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: textCol),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              items: List.generate(24, (i) => i).map((h) {
                                final hStr = '${h.toString().padLeft(2, '0')}:${editStartMinute.toString().padLeft(2, '0')}';
                                return DropdownMenuItem(
                                  value: h,
                                  child: Text(hStr, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: textCol)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => editStartHour = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DURAÇÃO',
                              style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AsterTheme.textMuted(context)),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: [15, 30, 45, 60, 90, 120, 180, 240].contains(editDurationMinutes) ? editDurationMinutes : 60,
                              dropdownColor: cardBg,
                              style: GoogleFonts.manrope(fontSize: 13, color: textCol),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              items: [
                                DropdownMenuItem(value: 15, child: Text('15 min', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 30, child: Text('30 min', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 45, child: Text('45 min', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 60, child: Text('1 hora', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 90, child: Text('1h 30m', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 120, child: Text('2 horas', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 180, child: Text('3 horas', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                                DropdownMenuItem(value: 240, child: Text('4 horas', style: GoogleFonts.manrope(fontSize: 13, color: textCol))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => editDurationMinutes = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Resumo do Horário Calculado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryCol.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: readablePrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Horário final: ${DateFormat('HH:mm').format(computedStart)} às ${DateFormat('HH:mm').format(computedEnd)} ($durStr)',
                          style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: textCol),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _categoryInfo.containsKey(editCategory) ? editCategory : _categoryInfo.keys.first,
                    dropdownColor: cardBg,
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textCol),
                    decoration: const InputDecoration(labelText: 'Categoria Semântica'),
                    items: [
                      ..._categoryInfo.entries.map((e) {
                        final catColor = _resolveCalendarColor(e.value.color);
                        return DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(e.value.label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textCol)),
                            ],
                          ),
                        );
                      }),
                      DropdownMenuItem(
                        value: '__add_category__',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 15, color: readablePrimary),
                            const SizedBox(width: 8),
                            Text(
                              '+ Nova Categoria...',
                              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: readablePrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__add_category__') {
                        _openAddEditCategoryDialog(
                          onSaved: () {
                            setModalState(() {
                              editCategory = _categoryInfo.keys.last;
                              editColorHex = _categoryInfo.values.last.hex;
                            });
                          },
                        );
                      } else if (val != null) {
                        setModalState(() {
                          editCategory = val;
                          editColorHex = _categoryInfo[val]?.hex ?? '#7C6CF0';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Seletor de Cor
                  Text(
                    'Cor do Bloco',
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: textCol),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPaletteWrap(
                    currentHex: editColorHex,
                    onHexChanged: (hex) => setModalState(() => editColorHex = hex),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descEditController,
                    maxLines: 2,
                    style: GoogleFonts.manrope(color: textCol),
                    decoration: const InputDecoration(
                      labelText: 'Detalhes ou Objetivos (opcional)',
                      hintText: 'Capítulos, links de lab, requisitos de estudo...',
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        titleEditController.dispose();
                        descEditController.dispose();
                      },
                child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterTheme.textMuted(context))),
              ),
              SoftClayPillButton(
                text: isSaving ? 'Salvando...' : 'Salvar Alterações',
                onPressed: isSaving
                    ? null
                    : () async {
                        final newTitle = titleEditController.text.trim();
                        if (newTitle.isEmpty) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Por favor, informe o título do bloco.')),
                          );
                          return;
                        }

                        final newStart = DateTime(
                          editDate.year,
                          editDate.month,
                          editDate.day,
                          editStartHour,
                          editStartMinute,
                        );
                        final newEnd = newStart.add(Duration(minutes: editDurationMinutes));

                        setModalState(() => isSaving = true);
                        try {
                          await SupabaseService.updateCalendarEvent(
                            id: eventId,
                            title: newTitle,
                            description: descEditController.text.trim().isNotEmpty ? descEditController.text.trim() : null,
                            category: editCategory,
                            color: editColorHex,
                            startTime: newStart,
                            endTime: newEnd,
                          );
                        } catch (_) {
                          if (ctx.mounted) {
                            setModalState(() => isSaving = false);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AsterConstants.coral,
                                content: Text('Não foi possível salvar as alterações. Tente novamente.'),
                              ),
                            );
                          }
                          return;
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        titleEditController.dispose();
                        descEditController.dispose();
                        if (!mounted) return;

                        setState(() {
                          _selectedDay = editDate;
                          _focusedDay = editDate;
                          _selectedDayNotifier.value = editDate;
                          if (_selectedCategoryFilter != null &&
                              _selectedCategoryFilter != editCategory) {
                            _selectedCategoryFilter = null;
                            _selectedCategoryFilterNotifier.value = null;
                          }
                        });

                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            backgroundColor: AsterTheme.primary(this.context),
                            content: Text(
                              'Bloco "$newTitle" remarcado para ${DateFormat("d 'de' MMMM", 'pt_BR').format(editDate)} às ${DateFormat('HH:mm').format(newStart)}!',
                              style: GoogleFonts.manrope(
                                color: AsterTheme.onPrimary(this.context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Gerenciamento Dinâmico de Categorias (Adicionar, Editar e Excluir) ───
  void _showCategoryManagerDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AsterTheme.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AsterTheme.primary(context).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.tune_rounded, size: 20, color: AsterTheme.primary(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerenciar Categorias',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AsterTheme.text(context),
                        ),
                      ),
                      Text(
                        'Crie, edite ou remova categorias do seu calendário',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botão de Adicionar Categoria
                  InkWell(
                    onTap: () {
                      _openAddEditCategoryDialog(
                        onSaved: () {
                          setDialogState(() {});
                          setState(() {});
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AsterTheme.primary(context).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(color: AsterTheme.primary(context).withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: AsterTheme.primary(context)),
                          const SizedBox(width: 8),
                          Text(
                            'Criar Nova Categoria',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AsterTheme.primary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'CATEGORIAS EXISTENTES (${_categoryInfo.length})',
                    style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AsterTheme.textMuted(context)),
                  ),
                  const SizedBox(height: 8),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView(
                      shrinkWrap: true,
                      children: _categoryInfo.values.map((cat) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AsterTheme.surfaceAlt(context),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            border: Border.all(color: AsterTheme.surfaceInset(context), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(cat.icon, size: 17, color: cat.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.label,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                    Text(
                                      cat.hex,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_rounded, size: 18, color: AsterTheme.primary(context)),
                                tooltip: 'Editar Categoria',
                                onPressed: () {
                                  _openAddEditCategoryDialog(
                                    categoryToEdit: cat,
                                    onSaved: () {
                                      setDialogState(() {});
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AsterConstants.coral),
                                tooltip: 'Excluir Categoria',
                                onPressed: () {
                                  if (_categoryInfo.length <= 1) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Você deve manter pelo menos uma categoria no calendário.')),
                                    );
                                    return;
                                  }

                                  showDialog(
                                    context: context,
                                    builder: (deleteCtx) {
                                      return AlertDialog(
                                        backgroundColor: AsterTheme.card(context),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
                                        title: Text(
                                          'Excluir categoria "${cat.label}"?',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w800,
                                            color: AsterTheme.text(context),
                                          ),
                                        ),
                                        content: Text(
                                          'Tem certeza que deseja remover esta categoria? Os blocos já agendados continuarão salvos com suas cores.',
                                          style: GoogleFonts.manrope(
                                            color: AsterTheme.textMuted(context),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(deleteCtx),
                                            child: Text(
                                              'Cancelar',
                                              style: GoogleFonts.manrope(color: AsterTheme.textMuted(context)),
                                            ),
                                          ),
                                        SoftClayPillButton(
                                          text: 'Excluir',
                                          color: AsterConstants.coral,
                                          onPressed: () {
                                            Navigator.pop(deleteCtx);
                                            setState(() {
                                              _categoryInfo.remove(cat.id);
                                              if (_selectedCategoryFilter == cat.id) {
                                                _selectedCategoryFilter = null;
                                              }
                                            });
                                            setDialogState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Categoria "${cat.label}" excluída.')),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SoftClayPillButton(
                text: 'Concluir',
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddEditCategoryDialog({CalendarCategory? categoryToEdit, VoidCallback? onSaved}) {
    final isEditing = categoryToEdit != null;
    final nameController = TextEditingController(text: categoryToEdit?.label ?? '');
    String selectedHex = categoryToEdit?.hex ?? _colorPalette.first.hex;
    Color selectedColor = categoryToEdit?.color ?? _colorPalette.first.color;
    IconData selectedIcon = categoryToEdit?.icon ?? _availableCategoryIcons.first.icon;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AsterTheme.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(selectedIcon, size: 20, color: selectedColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditing ? 'Editar Categoria' : 'Nova Categoria',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AsterTheme.text(context),
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Categoria',
                        hintText: 'ex: Criptografia, Inglês, Redes',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── 1. Escolher Cor ───
                    Text(
                      'COR DA CATEGORIA',
                      style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AsterTheme.textMuted(context)),
                    ),
                    const SizedBox(height: 8),
                    _buildColorPaletteWrap(
                      currentHex: selectedHex,
                      onHexChanged: (hex) {
                        setModalState(() {
                          selectedHex = hex;
                          selectedColor = _parseHexColor(hex);
                        });
                      },
                    ),
                    const SizedBox(height: 18),

                    // ─── 2. Escolher Ícone ───
                    Text(
                      'ÍCONE DA CATEGORIA',
                      style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AsterTheme.textMuted(context)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableCategoryIcons.map((item) {
                        final isSelected = selectedIcon == item.icon;

                        return InkWell(
                          onTap: () => setModalState(() => selectedIcon = item.icon),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withValues(alpha: 0.2)
                                  : AsterTheme.surfaceAlt(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? selectedColor : AsterTheme.surfaceInset(context),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              size: 19,
                              color: isSelected ? selectedColor : AsterTheme.text(context),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  nameController.dispose();
                  Navigator.pop(ctx);
                },
                child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterTheme.textMuted(context))),
              ),
              SoftClayPillButton(
                text: isEditing ? 'Salvar Alterações' : 'Criar Categoria',
                onPressed: () {
                  final label = nameController.text.trim();
                  if (label.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, informe o nome da categoria.')),
                    );
                    return;
                  }

                  final id = isEditing
                      ? categoryToEdit.id
                      : 'cat_${DateTime.now().millisecondsSinceEpoch}';

                  setState(() {
                    _categoryInfo[id] = CalendarCategory(
                      id: id,
                      label: label,
                      color: selectedColor,
                      hex: selectedHex,
                      icon: selectedIcon,
                    );
                  });

                  nameController.dispose();
                  Navigator.pop(ctx);
                  onSaved?.call();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AsterTheme.primary(context),
                      content: Text('Categoria "$label" ${isEditing ? "atualizada" : "criada"} com sucesso!'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _scheduleAiRecommendation() async {
    final rec = _aiRecommendations.isNotEmpty
        ? _aiRecommendations[_aiRecommendationIndex % _aiRecommendations.length]
        : null;
    if (rec == null) return;

    try {
      await SupabaseService.addCalendarEvent(
        title: rec.eventTitle,
        description: rec.eventDescription,
        category: rec.category,
        color: rec.colorHex,
        startTime: rec.startTime,
        endTime: rec.endTime,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AsterConstants.coral,
            content: Text('Erro ao agendar sugestão no calendário. Tente novamente.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _aiSuggestionScheduled = true;
        _scheduledRecommendationTitle = rec.eventTitle;
        _focusedDay = rec.startTime;
        _selectedDay = rec.startTime;
        _selectedDayNotifier.value = rec.startTime;
        if (_selectedCategoryFilter != null &&
            _selectedCategoryFilter != rec.category) {
          _selectedCategoryFilter = null;
          _selectedCategoryFilterNotifier.value = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AsterTheme.primary(context),
          content: Text(
            '${rec.eventTitle} agendado para ${DateFormat("EEEE, d 'de' MMMM 'às' HH:mm", 'pt_BR').format(rec.startTime)}!',
            style: GoogleFonts.manrope(
              color: AsterTheme.onPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        final rawEvents = snapshot.data ?? [];
        _syncRecommendationsIfEventsChanged(rawEvents);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28.0 : 16.0,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header do Calendário ───
              _buildTopHeader(rawEvents, isDesktop),
              const SizedBox(height: 18),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Área Principal Dinâmica: Semana, Dia, Mês ou Timeline
                    Expanded(
                      flex: 7,
                      child: _buildMainViewContent(rawEvents),
                    ),
                    const SizedBox(width: 20),
                    // Painel Lateral: Mini Mês Interativo + Próximos Marcos + Sugestão AI
                    Expanded(
                      flex: 3,
                      child: _buildRightSidePanel(rawEvents),
                    ),
                  ],
                )
              else ...[
                _buildRightSidePanel(rawEvents),
                const SizedBox(height: 16),
                _buildMainViewContent(rawEvents),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ─── Header do Calendário (Mês, Navegação, Resumo e Filtros) ───
  Widget _buildTopHeader(List<Map<String, dynamic>> allEvents, bool isDesktop) {
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);

    final monday = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekEvents = allEvents.where((e) {
      final st = _parseDateTime(e['start_time']);
      return st.isAfter(monday.subtract(const Duration(seconds: 1))) &&
          st.isBefore(sunday.add(const Duration(hours: 23, minutes: 59)));
    }).toList();

    double totalHours = 0;
    for (final e in weekEvents) {
      final st = _parseDateTime(e['start_time']);
      final et = _parseDateTime(e['end_time']);
      totalHours += et.difference(st).inMinutes / 60.0;
    }
    final hoursStr = totalHours == totalHours.truncateToDouble() ? '${totalHours.toInt()}h' : '${totalHours.toStringAsFixed(1)}h';

    final upcomingExams = allEvents.where((e) {
      final st = _parseDateTime(e['start_time']);
      return e['category'] == 'exam' && st.isAfter(DateTime.now().subtract(const Duration(hours: 2)));
    }).toList();

    String examSummary = '';
    if (upcomingExams.isNotEmpty) {
      upcomingExams.sort((a, b) => _parseDateTime(a['start_time']).compareTo(_parseDateTime(b['start_time'])));
      final nextExam = upcomingExams.first;
      final daysDiff = _parseDateTime(nextExam['start_time']).difference(DateTime.now()).inDays;
      final daysText = daysDiff <= 0
          ? 'hoje'
          : daysDiff == 1
              ? 'amanhã'
              : 'em $daysDiff dias';
      examSummary = ' · ${nextExam['title']} $daysText';
    }

    final weekNumber = ((_focusedDay.difference(DateTime(_focusedDay.year, 1, 1)).inDays) / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const NoesisCollapsedMenuSpacer(width: 82),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capitalizedMonth,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AsterTheme.text(context),
                  ),
                ),
                Text(
                  'Semana $weekNumber · $hoursStr planejadas${examSummary.isNotEmpty ? examSummary : ' · ${weekEvents.length} blocos'}',
                  style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                ),
              ],
            ),
            const Spacer(),

            // Seletor de Modo de Exibição
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AsterTheme.card(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                border: Border.all(color: _subtleBorderColor(context, 0.16), width: 1),
                boxShadow: AsterConstants.claySubtleShadow,
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: _activeViewModeNotifier,
                builder: (context, activeMode, _) {
                  return Row(
                    children: ['Dia', 'Semana', 'Mês', 'Timeline'].map((mode) {
                      final isSelected = activeMode == mode;
                      final primaryCol = AsterTheme.primary(context);
                      final onPrimaryCol = AsterTheme.onPrimary(context);
                      return InkWell(
                        onTap: () {
                          _activeViewMode = mode;
                          _activeViewModeNotifier.value = mode;
                        },
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryCol : Colors.transparent,
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          ),
                          child: Text(
                            mode,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? onPrimaryCol : AsterTheme.text(context),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),

            // Navegação Rápida (Hoje independente + Chevrons Circulares com toque suave)
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    final now = DateTime.now();
                    _focusedDay = now;
                    _selectedDay = now;
                    _selectedDayNotifier.value = now;
                  }),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AsterTheme.card(context),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      border: Border.all(color: _subtleBorderColor(context, 0.16), width: 1),
                      boxShadow: AsterConstants.claySubtleShadow,
                    ),
                    child: Text(
                      'Hoje',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AsterTheme.card(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(color: _subtleBorderColor(context, 0.16), width: 1),
                    boxShadow: AsterConstants.claySubtleShadow,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _navigateDate(isForward: false),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AsterTheme.surfaceAlt(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: _subtleBorderColor(context, 0.12), width: 1),
                          ),
                          child: Icon(Icons.chevron_left_rounded, size: 18, color: AsterTheme.text(context)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _navigateDate(isForward: true),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AsterTheme.surfaceAlt(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: _subtleBorderColor(context, 0.12), width: 1),
                          ),
                          child: Icon(Icons.chevron_right_rounded, size: 18, color: AsterTheme.text(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Barra de Legenda Semântica / Filtros Interativos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterPill('Todos', null, AsterTheme.text(context)),
              const SizedBox(width: 8),
              ..._categoryInfo.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterPill(e.value.label, e.key, _resolveCalendarColor(e.value.color)),
                );
              }),
              InkWell(
                onTap: _showCategoryManagerDialog,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(color: _subtleBorderColor(context, 0.18), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: _readableAccent(AsterTheme.primary(context), AsterTheme.surfaceAlt(context))),
                      const SizedBox(width: 5),
                      Text(
                        'Categorias',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AsterTheme.text(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SoftClayPillButton(
                text: '+ Novo bloco',
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                onPressed: () => _openAddEventDialog(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, String? categoryKey, Color color) {
    return ValueListenableBuilder<String?>(
      valueListenable: _selectedCategoryFilterNotifier,
      builder: (context, activeFilter, _) {
        final isSelected = activeFilter == categoryKey;
        final isDark = _isDarkTheme(context);
        final cardBg = AsterTheme.card(context);
        final resolvedColor = _resolveCalendarColor(color);
        final dotColor = _readableAccent(resolvedColor, cardBg);
        final onSelected = _onColor(resolvedColor);

        return InkWell(
          onTap: () {
            _selectedCategoryFilter = categoryKey;
            _selectedCategoryFilterNotifier.value = categoryKey;
          },
          onLongPress: categoryKey != null
              ? () {
                  final cat = _categoryInfo[categoryKey];
                  if (cat != null) {
                    _openAddEditCategoryDialog(
                      categoryToEdit: cat,
                      onSaved: () => setState(() {}),
                    );
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? resolvedColor
                  : resolvedColor.withValues(alpha: isDark ? 0.18 : 0.11),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              border: isSelected
                  ? null
                  : Border.all(
                      color: dotColor.withValues(alpha: isDark ? 0.45 : 0.35),
                      width: 1,
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected ? onSelected : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? onSelected : AsterTheme.text(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateDate({required bool isForward}) {
    setState(() {
      if (_activeViewMode == 'Dia') {
        final step = isForward ? 1 : -1;
        _focusedDay = _focusedDay.add(Duration(days: step));
        _selectedDay = _focusedDay;
      } else if (_activeViewMode == 'Mês') {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month + (isForward ? 1 : -1),
          _focusedDay.day,
        );
      } else {
        final step = isForward ? 7 : -7;
        _focusedDay = _focusedDay.add(Duration(days: step));
      }
      _selectedDayNotifier.value = _selectedDay;
    });
  }

  // ─── Seletor de Visão Principal ───
  Widget _buildMainViewContent(List<Map<String, dynamic>> rawEvents) {
    return ValueListenableBuilder<String?>(
      valueListenable: _selectedCategoryFilterNotifier,
      builder: (context, catFilter, _) {
        final events = _applyFilter(rawEvents, catFilter);

        return ValueListenableBuilder<String>(
          valueListenable: _activeViewModeNotifier,
          builder: (context, activeMode, _) {
            return ValueListenableBuilder<DateTime>(
              valueListenable: _selectedDayNotifier,
              builder: (context, selectedDay, _) {
                switch (activeMode) {
                  case 'Dia':
                    return _buildDayView(events);
                  case 'Mês':
                    return _buildMonthView(events);
                  case 'Timeline':
                    return _buildTimelineView(events);
                  case 'Semana':
                  default:
                    return _buildWeeklyTimelineGrid(events);
                }
              },
            );
          },
        );
      },
    );
  }

  // ─── 1. Visão Semanal Aprimorada: Linha do Tempo Contínua e Altura Proporcional ───
  Widget _buildWeeklyTimelineGrid(List<Map<String, dynamic>> events) {
    final monday = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    // Dia completo: 00:00 até 23:59 (24 horas)
    const startHour = 0;
    const endHour = 24;
    const totalHours = endHour - startHour; // 24
    const double hourHeight = 58.0;
    const double totalGridHeight = totalHours * hourHeight;

    final now = DateTime.now();
    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final primaryCol = AsterTheme.primary(context);
    final readablePrimary = _readableAccent(primaryCol, cardBg);
    final hGridLine = _subtleBorderColor(context, isDark ? 0.16 : 0.13);
    final vGridLine = _subtleBorderColor(context, isDark ? 0.11 : 0.09);

    return RepaintBoundary(
      child: SoftClayCard(
        padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Cabeçalho dos Dias da Semana
          Row(
            children: [
              const SizedBox(width: 48), // Espaço para as horas
              ...List.generate(7, (dIdx) {
                final d = weekDays[dIdx];
                final isToday = isSameDay(d, now);
                final isSelected = isSameDay(d, _selectedDayNotifier.value);

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      _selectedDay = d;
                      _selectedDayNotifier.value = d;
                      _focusedDay = d;
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected && !isToday ? primaryCol.withValues(alpha: isDark ? 0.14 : 0.10) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            dayNames[dIdx],
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isToday ? readablePrimary : AsterTheme.text(context).withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? primaryCol
                                  : (isSelected ? primaryCol.withValues(alpha: isDark ? 0.24 : 0.16) : Colors.transparent),
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected && !isToday
                                  ? Border.all(color: readablePrimary, width: 1.5)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                d.day.toString(),
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isToday
                                      ? AsterTheme.onPrimary(context)
                                      : (isSelected ? readablePrimary : AsterTheme.text(context)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: hGridLine, height: 1, thickness: 1),

          // Grade Contínua de Horários com Scroll (00h às 23h)
          SizedBox(
            height: 520,
            child: Scrollbar(
              controller: _weekScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _weekScrollController,
                physics: _isDraggingCalendarEvent
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: LayoutBuilder(
                  builder: (gridCtx, gridConstraints) {
                    final colWidth = ((gridConstraints.maxWidth - 48.0) / 7.0).clamp(64.0, 240.0);
                    return SizedBox(
                      height: totalGridHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Coluna de Rótulos de Horas
                          SizedBox(
                            width: 48,
                            child: Stack(
                              children: List.generate(totalHours, (idx) {
                                final h = startHour + idx;
                                return Positioned(
                                  top: idx * hourHeight,
                                  child: Text(
                                    '${h.toString().padLeft(2, '0')}h',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      color: AsterTheme.text(context).withValues(alpha: isDark ? 0.74 : 0.68),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // Colunas dos 7 Dias da Semana (com DragTarget para arrastar blocos)
                          ...List.generate(7, (dIdx) {
                            final cellDate = weekDays[dIdx];
                            final isToday = isSameDay(cellDate, now);

                            // Eventos que caem neste dia usando cache
                            final dayEvents = _getEventsForDay(events, cellDate);

                            return Expanded(
                              child: RepaintBoundary(
                                child: Builder(
                                  builder: (colCtx) {
                                    int resolveMinutesFromOffset(Offset globalOffset, Map<String, dynamic> evt) {
                                      final box = colCtx.findRenderObject() as RenderBox?;
                                      if (box == null) {
                                        final st = _parseDateTime(evt['start_time']);
                                        return st.hour * 60 + st.minute;
                                      }
                                      final localDy = box.globalToLocal(globalOffset).dy;
                                      final snappedHalfHours = (localDy / (hourHeight / 2)).round().clamp(0, 47);
                                      return snappedHalfHours * 30;
                                    }

                                    return DragTarget<Map<String, dynamic>>(
                                      onWillAcceptWithDetails: (_) => true,
                                      onMove: (details) {
                                        final startMins = resolveMinutesFromOffset(details.offset, details.data);
                                        final st = _parseDateTime(details.data['start_time']);
                                        final et = _parseDateTime(details.data['end_time']);
                                        final durMins = et.difference(st).inMinutes.clamp(30, 480);
                                        final nextPreview = (
                                          dayIdx: dIdx,
                                          startMinutes: startMins,
                                          durationMinutes: durMins,
                                          color: _getEventColor(details.data),
                                          title: (details.data['title'] ?? 'Bloco').toString(),
                                        );
                                        if (_dragPreviewNotifier.value != nextPreview) {
                                          _dragPreviewNotifier.value = nextPreview;
                                        }
                                      },
                                      onLeave: (_) {
                                        if (_dragPreviewNotifier.value?.dayIdx == dIdx) {
                                          _dragPreviewNotifier.value = null;
                                        }
                                      },
                                      onAcceptWithDetails: (details) {
                                        final targetMins = _dragPreviewNotifier.value?.dayIdx == dIdx
                                            ? _dragPreviewNotifier.value!.startMinutes
                                            : resolveMinutesFromOffset(details.offset, details.data);
                                        _dragPreviewNotifier.value = null;
                                        final newStart = DateTime(
                                          cellDate.year,
                                          cellDate.month,
                                          cellDate.day,
                                          targetMins ~/ 60,
                                          targetMins % 60,
                                        );
                                        _rescheduleEventByDrag(details.data, newStart);
                                      },
                                      builder: (context, candidateData, rejectedData) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: candidateData.isNotEmpty
                                                ? primaryCol.withValues(alpha: isDark ? 0.10 : 0.07)
                                                : (isToday ? primaryCol.withValues(alpha: isDark ? 0.06 : 0.045) : Colors.transparent),
                                            border: Border(
                                              right: BorderSide(
                                                color: vGridLine,
                                                width: 1.0,
                                              ),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              // 1. Linhas de Fundo Horárias (com toque para agendar)
                                              ...List.generate(totalHours, (hIdx) {
                                                final currentH = startHour + hIdx;
                                                return Positioned(
                                                  top: hIdx * hourHeight,
                                                  left: 0,
                                                  right: 0,
                                                  height: hourHeight,
                                                  child: InkWell(
                                                    onTap: () => _openAddEventDialog(prefilledDate: cellDate, prefilledHour: currentH),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(color: hGridLine, width: 1.0),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),

                                              // 2. Linha do Horário Atual
                                              if (isToday && now.hour >= startHour && now.hour < endHour)
                                                Positioned(
                                                  top: ((now.hour - startHour) + (now.minute / 60.0)) * hourHeight,
                                                  left: 0,
                                                  right: 0,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 7,
                                                        height: 7,
                                                        decoration: BoxDecoration(
                                                          color: _readableAccent(AsterConstants.coral, cardBg),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          height: 1.8,
                                                          color: _readableAccent(AsterConstants.coral, cardBg).withValues(alpha: 0.85),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                              // 3. Prévia ao vivo do horário de destino enquanto arrasta
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: ValueListenableBuilder<
                                                      ({int dayIdx, int startMinutes, int durationMinutes, Color color, String title})?>(
                                                    valueListenable: _dragPreviewNotifier,
                                                    builder: (ctx, preview, _) {
                                                      if (preview == null || preview.dayIdx != dIdx) {
                                                        return const SizedBox.shrink();
                                                      }
                                                      final previewTop =
                                                          ((preview.startMinutes / 60.0) * hourHeight).clamp(0.0, totalGridHeight - 20.0);
                                                      final previewHeight =
                                                          ((preview.durationMinutes / 60.0) * hourHeight - 4.0)
                                                              .clamp(28.0, totalGridHeight - previewTop);
                                                      final previewStartDt = DateTime(
                                                        cellDate.year,
                                                        cellDate.month,
                                                        cellDate.day,
                                                        preview.startMinutes ~/ 60,
                                                        preview.startMinutes % 60,
                                                      );
                                                      final previewColor = _readableAccent(preview.color, cardBg);
                                                      return Stack(
                                                        children: [
                                                          Positioned(
                                                            top: previewTop,
                                                            left: 2,
                                                            right: 2,
                                                            height: previewHeight,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: preview.color.withValues(alpha: isDark ? 0.34 : 0.24),
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(color: previewColor, width: 1.8),
                                                              ),
                                                              child: Text(
                                                                '${DateFormat('HH:mm').format(previewStartDt)} · ${preview.title}',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: GoogleFonts.manrope(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: previewColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),

                                              // 4. Blocos de Eventos arrastáveis com Altura Proporcional e Botão de Excluir Direto
                                              ...dayEvents.map((evt) {
                                                final st = _parseDateTime(evt['start_time']);
                                                final et = _parseDateTime(evt['end_time']);
                                                final color = _getEventColor(evt);
                                                final readableColor = _readableAccent(color, cardBg);
                                                final category = evt['category'] ?? 'study';
                                                final title = evt['title'] ?? 'Sem título';
                                                final isCompleted = evt['is_completed'] == true;

                                                // Calcula posição e altura proporcional
                                                final eventStartHours = (st.hour - startHour) + (st.minute / 60.0);
                                                final durationHours = (et.difference(st).inMinutes / 60.0).clamp(0.4, 8.0);

                                                final top = (eventStartHours * hourHeight).clamp(0.0, totalGridHeight - 20.0);
                                                final height = (durationHours * hourHeight - 4.0).clamp(28.0, totalGridHeight - top);

                                                final durStr = durationHours == durationHours.truncateToDouble()
                                                    ? '${durationHours.toInt()}h'
                                                    : '${durationHours.toStringAsFixed(1)}h';

                                                Widget buildEventCard({required bool isFeedback}) {
                                                  return ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: isFeedback ? null : () => _showEventDetailsDialog(evt),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: isFeedback
                                                                ? Color.alphaBlend(
                                                                    color.withValues(alpha: isDark ? 0.34 : 0.24),
                                                                    cardBg,
                                                                  )
                                                                : color.withValues(
                                                                    alpha: isDark
                                                                        ? (isCompleted ? 0.12 : 0.24)
                                                                        : (isCompleted ? 0.09 : 0.16),
                                                                  ),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(
                                                              color: readableColor.withValues(
                                                                alpha: isFeedback ? 0.85 : (isDark ? 0.45 : 0.35),
                                                              ),
                                                              width: isFeedback ? 1.5 : 1.0,
                                                            ),
                                                          ),
                                                          child: Stack(
                                                            children: [
                                                              Positioned(
                                                                left: 0,
                                                                top: 0,
                                                                bottom: 0,
                                                                width: 4,
                                                                child: ColoredBox(color: readableColor),
                                                              ),
                                                              // Conteúdo do Bloco
                                                              Padding(
                                                                padding: EdgeInsets.fromLTRB(9, 4, isFeedback ? 8 : 22, 4),
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    Text(
                                                                      title,
                                                                      maxLines: height > 70 ? 2 : 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: GoogleFonts.manrope(
                                                                        fontSize: 10.5,
                                                                        fontWeight: FontWeight.w800,
                                                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                                        color: isCompleted ? AsterTheme.textMuted(context) : AsterTheme.text(context),
                                                                      ),
                                                                    ),
                                                                    if (height > 44)
                                                                      Text(
                                                                        '${_getCategoryLabel(category)} · $durStr',
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: GoogleFonts.manrope(
                                                                          fontSize: 9,
                                                                          fontWeight: FontWeight.w700,
                                                                          color: readableColor,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),

                                                              // Botão de Excluir Rápido (X no canto superior direito)
                                                              if (!isFeedback)
                                                                Positioned(
                                                                  top: 2,
                                                                  right: 2,
                                                                  child: InkWell(
                                                                    onTap: () => _confirmDeleteEvent(evt),
                                                                    borderRadius: BorderRadius.circular(10),
                                                                    child: Container(
                                                                      width: 18,
                                                                      height: 18,
                                                                      decoration: BoxDecoration(
                                                                        color: cardBg.withValues(alpha: 0.92),
                                                                        shape: BoxShape.circle,
                                                                        border: Border.all(color: _subtleBorderColor(context, 0.2), width: 0.8),
                                                                      ),
                                                                      child: Icon(
                                                                        Icons.close_rounded,
                                                                        size: 11,
                                                                        color: _readableAccent(AsterConstants.coral, cardBg),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                return Positioned(
                                                  top: top,
                                                  left: 2,
                                                  right: 2,
                                                  height: height,
                                                  child: Listener(
                                                    onPointerDown: (_) {
                                                      if (!_isDraggingCalendarEvent) {
                                                        setState(() => _isDraggingCalendarEvent = true);
                                                      }
                                                    },
                                                    onPointerUp: (_) {
                                                      if (_draggingEventId == null && _isDraggingCalendarEvent) {
                                                        setState(() => _isDraggingCalendarEvent = false);
                                                      }
                                                    },
                                                    onPointerCancel: (_) {
                                                      if (_draggingEventId == null && _isDraggingCalendarEvent) {
                                                        setState(() => _isDraggingCalendarEvent = false);
                                                      }
                                                    },
                                                    child: MouseRegion(
                                                      cursor: SystemMouseCursors.grab,
                                                      child: Draggable<Map<String, dynamic>>(
                                                        data: evt,
                                                        maxSimultaneousDrags: 1,
                                                        onDragStarted: () {
                                                          setState(() {
                                                            _isDraggingCalendarEvent = true;
                                                            _draggingEventId = evt['id']?.toString();
                                                          });
                                                        },
                                                        onDragEnd: (_) {
                                                          _dragPreviewNotifier.value = null;
                                                          if (mounted) {
                                                            setState(() {
                                                              _isDraggingCalendarEvent = false;
                                                              _draggingEventId = null;
                                                            });
                                                          }
                                                        },
                                                        onDraggableCanceled: (_, _) {
                                                          _dragPreviewNotifier.value = null;
                                                          if (mounted) {
                                                            setState(() {
                                                              _isDraggingCalendarEvent = false;
                                                              _draggingEventId = null;
                                                            });
                                                          }
                                                        },
                                                        onDragCompleted: () {
                                                          _dragPreviewNotifier.value = null;
                                                          if (mounted) {
                                                            setState(() {
                                                              _isDraggingCalendarEvent = false;
                                                              _draggingEventId = null;
                                                            });
                                                          }
                                                        },
                                                        feedback: Material(
                                                          color: Colors.transparent,
                                                          elevation: 6,
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: SizedBox(
                                                            width: (colWidth - 4).clamp(72.0, 220.0),
                                                            height: height,
                                                            child: buildEventCard(isFeedback: true),
                                                          ),
                                                        ),
                                                        childWhenDragging: Opacity(
                                                          opacity: 0.28,
                                                          child: buildEventCard(isFeedback: false),
                                                        ),
                                                        child: buildEventCard(isFeedback: false),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ─── 2. Visão Diária Detalhada ───
  Widget _buildDayView(List<Map<String, dynamic>> allEvents) {
    final dayEvents = _getEventsForDay(allEvents, _selectedDay);
    final hours = List.generate(24, (i) => i);
    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final rowLine = _subtleBorderColor(context, isDark ? 0.15 : 0.12);

    return SoftClayCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(_selectedDay),
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AsterTheme.text(context)),
                  ),
                  Text(
                    '${dayEvents.length} bloco(s) agendados para este dia',
                    style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                  ),
                ],
              ),
              SoftClayPillButton(
                text: '+ Adicionar neste dia',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onPressed: () => _openAddEventDialog(prefilledDate: _selectedDay),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: rowLine, height: 1, thickness: 1),
          const SizedBox(height: 8),

          SizedBox(
            height: 480,
            child: ListView.builder(
              physics: _isDraggingCalendarEvent
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              itemCount: hours.length,
              itemBuilder: (context, idx) {
                final h = hours[idx];
                final slotEvents = dayEvents.where((e) => _parseDateTime(e['start_time']).hour == h).toList();
                final primaryCol = AsterTheme.primary(context);

                return DragTarget<Map<String, dynamic>>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (details) {
                    _rescheduleEventByDrag(
                      details.data,
                      DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, h, 0),
                    );
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isDropHovered = candidateData.isNotEmpty;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isDropHovered ? primaryCol.withValues(alpha: isDark ? 0.14 : 0.09) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: rowLine, width: 1.0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDropHovered
                                    ? _readableAccent(primaryCol, cardBg)
                                    : AsterTheme.text(context).withValues(alpha: isDark ? 0.76 : 0.72),
                              ),
                            ),
                          ),
                          Expanded(
                            child: slotEvents.isNotEmpty
                                ? Column(
                                    children: slotEvents.map((evt) {
                                      final color = _getEventColor(evt);
                                      final readableColor = _readableAccent(color, cardBg);
                                      final isCompleted = evt['is_completed'] == true;

                                      Widget buildDayEventCard({required bool isFeedback}) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isFeedback
                                                    ? Color.alphaBlend(
                                                        color.withValues(alpha: isDark ? 0.34 : 0.24),
                                                        cardBg,
                                                      )
                                                    : color.withValues(
                                                        alpha: isDark ? (isCompleted ? 0.12 : 0.22) : (isCompleted ? 0.08 : 0.14),
                                                      ),
                                                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                                border: Border.all(
                                                  color: readableColor.withValues(
                                                    alpha: isFeedback ? 0.85 : (isDark ? 0.42 : 0.34),
                                                  ),
                                                  width: isFeedback ? 1.5 : 1.0,
                                                ),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Positioned(
                                                    left: 0,
                                                    top: 0,
                                                    bottom: 0,
                                                    width: 4,
                                                    child: ColoredBox(color: readableColor),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.drag_indicator_rounded, size: 16, color: readableColor.withValues(alpha: 0.75)),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: InkWell(
                                                            onTap: isFeedback ? null : () => _showEventDetailsDialog(evt),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  evt['title'] ?? '',
                                                                  style: GoogleFonts.manrope(
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w800,
                                                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                                    color: AsterTheme.text(context),
                                                                  ),
                                                                ),
                                                                if ((evt['description'] ?? '').isNotEmpty)
                                                                  Text(
                                                                    evt['description'],
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.textMuted(context)),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        if (!isFeedback) ...[
                                                          IconButton(
                                                            icon: Icon(
                                                              isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                              size: 20,
                                                              color: isCompleted ? _readableAccent(AsterConstants.menta, cardBg) : AsterTheme.textMuted(context),
                                                            ),
                                                            onPressed: () {
                                                              final id = evt['id']?.toString() ?? '';
                                                              if (id.isNotEmpty) {
                                                                SupabaseService.toggleCalendarEventCompleted(id, !isCompleted).catchError((_) {});
                                                              }
                                                            },
                                                          ),
                                                          IconButton(
                                                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: _readableAccent(AsterConstants.coral, cardBg)),
                                                            tooltip: 'Excluir bloco',
                                                            onPressed: () => _confirmDeleteEvent(evt),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return Listener(
                                        onPointerDown: (_) {
                                          if (!_isDraggingCalendarEvent) {
                                            setState(() => _isDraggingCalendarEvent = true);
                                          }
                                        },
                                        onPointerUp: (_) {
                                          if (_draggingEventId == null && _isDraggingCalendarEvent) {
                                            setState(() => _isDraggingCalendarEvent = false);
                                          }
                                        },
                                        onPointerCancel: (_) {
                                          if (_draggingEventId == null && _isDraggingCalendarEvent) {
                                            setState(() => _isDraggingCalendarEvent = false);
                                          }
                                        },
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: Draggable<Map<String, dynamic>>(
                                            data: evt,
                                            maxSimultaneousDrags: 1,
                                            onDragStarted: () {
                                              setState(() {
                                                _isDraggingCalendarEvent = true;
                                                _draggingEventId = evt['id']?.toString();
                                              });
                                            },
                                            onDragEnd: (_) {
                                              if (mounted) {
                                                setState(() {
                                                  _isDraggingCalendarEvent = false;
                                                  _draggingEventId = null;
                                                });
                                              }
                                            },
                                            onDraggableCanceled: (_, _) {
                                              if (mounted) {
                                                setState(() {
                                                  _isDraggingCalendarEvent = false;
                                                  _draggingEventId = null;
                                                });
                                              }
                                            },
                                            onDragCompleted: () {
                                              if (mounted) {
                                                setState(() {
                                                  _isDraggingCalendarEvent = false;
                                                  _draggingEventId = null;
                                                });
                                              }
                                            },
                                            feedback: Material(
                                              color: Colors.transparent,
                                              elevation: 6,
                                              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                              child: SizedBox(
                                                width: 320,
                                                child: buildDayEventCard(isFeedback: true),
                                              ),
                                            ),
                                            childWhenDragging: Opacity(
                                              opacity: 0.3,
                                              child: buildDayEventCard(isFeedback: false),
                                            ),
                                            child: buildDayEventCard(isFeedback: false),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : InkWell(
                                    onTap: () => _openAddEventDialog(prefilledDate: _selectedDay, prefilledHour: h),
                                    child: Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        isDropHovered
                                            ? 'Soltar aqui para mover às ${h.toString().padLeft(2, '0')}:00'
                                            : '+ toque para agendar às ${h.toString().padLeft(2, '0')}:00',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          fontWeight: isDropHovered ? FontWeight.w700 : FontWeight.w500,
                                          color: isDropHovered ? _readableAccent(primaryCol, cardBg) : AsterTheme.textMuted(context),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  CalendarBuilders _buildTableCalendarBuilders({
    required BuildContext context,
    required double marginH,
    required double marginV,
    required double radius,
    required double fontSize,
    required double dotSize,
  }) {
    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final primaryCol = AsterTheme.primary(context);
    final onPrimaryCol = AsterTheme.onPrimary(context);
    final readablePrimary = _readableAccent(primaryCol, cardBg);

    return CalendarBuilders(
      selectedBuilder: (context, day, focusedDay) {
        final isToday = isSameDay(DateTime.now(), day);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
          decoration: BoxDecoration(
            color: isToday ? primaryCol : primaryCol.withValues(alpha: isDark ? 0.25 : 0.16),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isToday ? onPrimaryCol : readablePrimary,
              width: 1.7,
            ),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: primaryCol.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: isToday ? onPrimaryCol : readablePrimary,
            ),
          ),
        );
      },
      todayBuilder: (context, day, focusedDay) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
          decoration: BoxDecoration(
            color: primaryCol,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: primaryCol.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: GoogleFonts.manrope(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: onPrimaryCol,
            ),
          ),
        );
      },
      markerBuilder: (context, day, events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final isToday = isSameDay(DateTime.now(), day);
        final bgForDots = isToday ? primaryCol : cardBg;
        final visibleEvents = events.take(3).toList();
        return Positioned(
          bottom: marginV + 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: visibleEvents.map((e) {
              final rawCol = e is Map<String, dynamic> ? _getEventColor(e) : AsterConstants.coral;
              final dotCol = isToday ? onPrimaryCol : _readableAccent(rawCol, bgForDots);
              return Container(
                width: dotSize,
                height: dotSize,
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                decoration: BoxDecoration(
                  color: dotCol,
                  shape: BoxShape.circle,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ─── 3. Visão Mensal (Grid Expandido) ───
  Widget _buildMonthView(List<Map<String, dynamic>> allEvents) {
    final selectedEvents = _getEventsForDay(allEvents, _selectedDay);
    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final primaryCol = AsterTheme.primary(context);
    final onPrimaryCol = AsterTheme.onPrimary(context);
    final readablePrimary = _readableAccent(primaryCol, cardBg);
    final dividerCol = _subtleBorderColor(context, isDark ? 0.16 : 0.13);

    return SoftClayCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: TableCalendar(
              locale: 'pt_BR',
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              rowHeight: 46.0,
              selectedDayPredicate: (day) => isSameDay(_selectedDayNotifier.value, day),
              onDaySelected: (selectedDay, focusedDay) {
                _selectedDay = selectedDay;
                _selectedDayNotifier.value = selectedDay;
                _focusedDay = focusedDay;
              },
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              eventLoader: (day) => _getEventsForDay(allEvents, day),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextFormatter: (date, locale) {
                  final m = DateFormat('MMMM yyyy', 'pt_BR').format(date);
                  return m.isNotEmpty ? m[0].toUpperCase() + m.substring(1) : m;
                },
                titleTextStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: AsterTheme.text(context)),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, size: 20, color: AsterTheme.text(context)),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, size: 20, color: AsterTheme.text(context)),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                dowTextFormatter: (date, locale) {
                  final dayStr = DateFormat.E('pt_BR').format(date).replaceAll('.', '');
                  return dayStr.isNotEmpty ? dayStr[0].toUpperCase() + dayStr.substring(1) : dayStr;
                },
                weekdayStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterTheme.text(context)),
                weekendStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterTheme.textMuted(context)),
              ),
              calendarStyle: CalendarStyle(
                cellMargin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                todayDecoration: BoxDecoration(
                  color: primaryCol,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryCol.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                selectedDecoration: BoxDecoration(
                  color: primaryCol.withValues(alpha: isDark ? 0.25 : 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: readablePrimary, width: 1.8),
                ),
                todayTextStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: onPrimaryCol),
                selectedTextStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: readablePrimary),
                markerDecoration: BoxDecoration(
                  color: _readableAccent(AsterConstants.coral, cardBg),
                  borderRadius: BorderRadius.circular(3),
                ),
                defaultTextStyle: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.text(context)),
                weekendTextStyle: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.text(context).withValues(alpha: isDark ? 0.76 : 0.70)),
                outsideTextStyle: GoogleFonts.manrope(fontSize: 13, color: AsterTheme.textMuted(context).withValues(alpha: 0.58)),
              ),
              calendarBuilders: _buildTableCalendarBuilders(
                context: context,
                marginH: 5,
                marginV: 3,
                radius: 10,
                fontSize: 13,
                dotSize: 5.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: dividerCol, height: 1, thickness: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Blocos em ${DateFormat("d 'de' MMMM", 'pt_BR').format(_selectedDay)} (${selectedEvents.length})',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterTheme.text(context)),
              ),
              SoftClayPillButton(
                text: '+ Adicionar',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onPressed: () => _openAddEventDialog(prefilledDate: _selectedDay),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (selectedEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nenhum bloco agendado para este dia.',
                  style: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context)),
                ),
              ),
            )
          else
            ...selectedEvents.map((evt) {
              final color = _getEventColor(evt);
              final readableColor = _readableAccent(color, cardBg);
              final st = _parseDateTime(evt['start_time']);
              final et = _parseDateTime(evt['end_time']);
              final isCompleted = evt['is_completed'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? (isCompleted ? 0.11 : 0.22) : (isCompleted ? 0.08 : 0.14)),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      border: Border.all(
                        color: readableColor.withValues(alpha: isDark ? 0.42 : 0.34),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 4,
                          child: ColoredBox(color: readableColor),
                        ),
                        InkWell(
                          onTap: () => _showEventDetailsDialog(evt),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                            child: Row(
                              children: [
                                Text(
                                  '${DateFormat('HH:mm').format(st)} - ${DateFormat('HH:mm').format(et)}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: readableColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    evt['title'] ?? '',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      color: AsterTheme.text(context),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: _readableAccent(AsterConstants.coral, cardBg)),
                                  tooltip: 'Excluir bloco',
                                  onPressed: () => _confirmDeleteEvent(evt),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── 4. Visão Timeline (Feed Cronológico de Agendamentos) ───
  Widget _buildTimelineView(List<Map<String, dynamic>> allEvents) {
    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final dividerCol = _subtleBorderColor(context, isDark ? 0.16 : 0.13);

    if (allEvents.isEmpty) {
      return SoftClayCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_note_rounded, size: 40, color: AsterTheme.textMuted(context)),
              const SizedBox(height: 12),
              Text(
                'Nenhum evento agendado.',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 12),
              SoftClayPillButton(
                text: '+ Adicionar Primeiro Bloco',
                onPressed: () => _openAddEventDialog(),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<Map<String, dynamic>>.from(allEvents);
    sorted.sort((a, b) => _parseDateTime(a['start_time']).compareTo(_parseDateTime(b['start_time'])));

    return SoftClayCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Linha do Tempo Cronológica (${sorted.length} blocos)',
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: AsterTheme.text(context)),
              ),
              SoftClayPillButton(
                text: '+ Novo bloco',
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onPressed: () => _openAddEventDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: dividerCol, height: 1, thickness: 1),
          const SizedBox(height: 8),

          ...sorted.map((evt) {
            final st = _parseDateTime(evt['start_time']);
            final et = _parseDateTime(evt['end_time']);
            final cat = evt['category'] ?? 'study';
            final color = _getEventColor(evt);
            final readableColor = _readableAccent(color, cardBg);
            final isCompleted = evt['is_completed'] == true;

            final duration = et.difference(st);
            final durHours = duration.inMinutes / 60.0;
            final durStr = durHours == durHours.truncateToDouble() ? '${durHours.toInt()}h' : '${durHours.toStringAsFixed(1)}h';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? (isCompleted ? 0.11 : 0.22) : (isCompleted ? 0.08 : 0.14)),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    border: Border.all(
                      color: readableColor.withValues(alpha: isDark ? 0.42 : 0.34),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: ColoredBox(color: readableColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showEventDetailsDialog(evt),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: isDark ? 0.28 : 0.18),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getCategoryLabel(cat),
                                            style: GoogleFonts.manrope(fontSize: 9.5, fontWeight: FontWeight.w800, color: readableColor),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${DateFormat("d 'de' MMM", 'pt_BR').format(st)} · ${DateFormat('HH:mm').format(st)} às ${DateFormat('HH:mm').format(et)} ($durStr)',
                                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AsterTheme.textMuted(context)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      evt['title'] ?? '',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                    if ((evt['description'] ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          evt['description'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.textMuted(context)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isCompleted ? _readableAccent(AsterConstants.menta, cardBg) : AsterTheme.textMuted(context),
                                size: 20,
                              ),
                              onPressed: () {
                                final id = evt['id']?.toString() ?? '';
                                if (id.isNotEmpty) {
                                  SupabaseService.toggleCalendarEventCompleted(id, !isCompleted).catchError((_) {});
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: _readableAccent(AsterConstants.coral, cardBg)),
                              tooltip: 'Excluir bloco',
                              onPressed: () => _confirmDeleteEvent(evt),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Painel Lateral Direito (Mini Calendário + Marcos + Sugestão AI) ───
  Widget _buildRightSidePanel(List<Map<String, dynamic>> allEvents) {
    final upcomingMilestones = allEvents.where((e) {
      final st = _parseDateTime(e['start_time']);
      return st.isAfter(DateTime.now().subtract(const Duration(hours: 12))) || e['category'] == 'exam' || e['category'] == 'lab';
    }).toList();
    upcomingMilestones.sort((a, b) => _parseDateTime(a['start_time']).compareTo(_parseDateTime(b['start_time'])));

    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final primaryCol = AsterTheme.primary(context);
    final onPrimaryCol = AsterTheme.onPrimary(context);
    final readablePrimary = _readableAccent(primaryCol, cardBg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini Calendário do Mês (Totalmente Interativo e Vinculado)
        SoftClayCard(
          padding: const EdgeInsets.all(16),
          child: RepaintBoundary(
            child: ValueListenableBuilder<DateTime>(
              valueListenable: _selectedDayNotifier,
              builder: (context, currentSelectedDay, _) {
                return TableCalendar(
                  locale: 'pt_BR',
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  currentDay: DateTime.now(),
                  rowHeight: 38.0,
                  selectedDayPredicate: (day) => isSameDay(currentSelectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    _selectedDay = selectedDay;
                    _selectedDayNotifier.value = selectedDay;
                    _focusedDay = focusedDay;
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                  },
                  eventLoader: (day) => _getEventsForDay(allEvents, day),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextFormatter: (date, locale) {
                      final m = DateFormat('MMMM yyyy', 'pt_BR').format(date);
                      return m.isNotEmpty ? m[0].toUpperCase() + m.substring(1) : m;
                    },
                    titleTextStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterTheme.text(context)),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, size: 18, color: AsterTheme.text(context)),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, size: 18, color: AsterTheme.text(context)),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    dowTextFormatter: (date, locale) {
                      final dayStr = DateFormat.E('pt_BR').format(date).replaceAll('.', '');
                      return dayStr.isNotEmpty ? dayStr[0].toUpperCase() + dayStr.substring(1) : dayStr;
                    },
                    weekdayStyle: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.text(context)),
                    weekendStyle: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.textMuted(context)),
                  ),
                  calendarStyle: CalendarStyle(
                    cellMargin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    todayDecoration: BoxDecoration(
                      color: primaryCol,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: primaryCol.withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    selectedDecoration: BoxDecoration(
                      color: primaryCol.withValues(alpha: isDark ? 0.25 : 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: readablePrimary, width: 1.8),
                    ),
                    todayTextStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: onPrimaryCol),
                    selectedTextStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: readablePrimary),
                    markerDecoration: BoxDecoration(
                      color: _readableAccent(AsterConstants.coral, cardBg),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    defaultTextStyle: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.text(context)),
                    weekendTextStyle: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.text(context).withValues(alpha: isDark ? 0.76 : 0.70)),
                    outsideTextStyle: GoogleFonts.manrope(fontSize: 12, color: AsterTheme.textMuted(context).withValues(alpha: 0.58)),
                  ),
                  calendarBuilders: _buildTableCalendarBuilders(
                    context: context,
                    marginH: 3,
                    marginV: 2,
                    radius: 8,
                    fontSize: 12,
                    dotSize: 4.5,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Próximos Marcos (Extraídos Dinamicamente)
        SoftClayCard.list(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próximos marcos',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterTheme.text(context)),
              ),
              const SizedBox(height: 14),

              if (upcomingMilestones.isEmpty)
                Text(
                  'Nenhum marco futuro registrado.',
                  style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.textMuted(context)),
                )
              else
                ...upcomingMilestones.take(4).map((m) {
                  final st = _parseDateTime(m['start_time']);
                  final dateBadge = DateFormat("E d", 'pt_BR').format(st);
                  final color = _getEventColor(m);
                  final timeSub = DateFormat('HH:mm').format(st);
                  final desc = m['description'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDay = st;
                          _focusedDay = st;
                          _selectedDayNotifier.value = st;
                        });
                      },
                      child: _buildMilestoneRow(
                        dateBadge,
                        m['title'] ?? '',
                        '$timeSub${desc.isNotEmpty ? ' · $desc' : ''}',
                        color,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sugestão Proativa do Noesis AI (Agendamento Real Contextualizado)
        if (!_aiSuggestionDismissed)
          Builder(
            builder: (context) {
              final rec = _aiRecommendations.isNotEmpty
                  ? _aiRecommendations[_aiRecommendationIndex % _aiRecommendations.length]
                  : null;
              final aiCardBg = AsterTheme.surfaceAlt(context);
              final aiAccent = _readableAccent(primaryCol, aiCardBg);
              return SoftClayCard.list(
                key: const Key('calendar_ai_suggestion_card'),
                padding: const EdgeInsets.all(20),
                color: aiCardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: aiAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Noesis AI',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: aiAccent),
                        ),
                        const Spacer(),
                        if (!_aiSuggestionScheduled && _aiRecommendations.length > 1) ...[
                          IconButton(
                            key: const Key('calendar_ai_next_suggestion'),
                            tooltip: 'Ver outra sugestão',
                            icon: Icon(Icons.refresh_rounded, size: 15, color: aiAccent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _aiRecommendationIndex =
                                    (_aiRecommendationIndex + 1) % _aiRecommendations.length;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 14, color: AsterTheme.textMuted(context)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _aiSuggestionDismissed = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiSuggestionScheduled
                          ? '✅ ${_scheduledRecommendationTitle ?? "Bloco"} adicionado ao seu calendário com sucesso!'
                          : (rec?.message ?? 'Analisando sua agenda e prioridades de estudo...'),
                      style: GoogleFonts.manrope(fontSize: 12, height: 1.45, color: AsterTheme.text(context)),
                    ),
                    const SizedBox(height: 14),
                    if (!_aiSuggestionScheduled && rec != null)
                      Row(
                        children: [
                          SoftClayPillButton(
                            text: 'Sim, agendar',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            onPressed: _scheduleAiRecommendation,
                          ),
                          const SizedBox(width: 8),
                          SoftClayPillButton(
                            text: 'Agora não',
                            isSecondary: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            onPressed: () => setState(() => _aiSuggestionDismissed = true),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMilestoneRow(String date, String title, String subtitle, Color color) {
    final isDark = _isDarkTheme(context);
    final cardBg = AsterTheme.card(context);
    final readableColor = _readableAccent(color, cardBg);

    return Row(
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.22 : 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: readableColor.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Text(
            date,
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: readableColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterTheme.text(context)),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(fontSize: 10, color: AsterTheme.textMuted(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
