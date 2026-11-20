import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/supabase_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'study';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _openAddEventDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AsterConstants.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Novo Evento / Compromisso', style: TextStyle(color: AsterConstants.textLight)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Título (ex: Prova Security+, Revisão de Redes)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  dropdownColor: AsterConstants.surfaceDark,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: const [
                    DropdownMenuItem(value: 'study', child: Text('Bloco de Estudo')),
                    DropdownMenuItem(value: 'exam', child: Text('Prova / Certificação')),
                    DropdownMenuItem(value: 'work', child: Text('Trabalho / Projeto')),
                    DropdownMenuItem(value: 'personal', child: Text('Compromisso Pessoal')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descrição / Detalhes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AsterConstants.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = _titleController.text.trim();
                if (title.isNotEmpty) {
                  final start = _selectedDay ?? DateTime.now();
                  final end = start.add(const Duration(hours: 1));

                  await SupabaseService.addCalendarEvent(
                    title: title,
                    description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
                    category: _selectedCategory,
                    startTime: start,
                    endTime: end,
                  );

                  if (mounted && ctx.mounted) {
                    Navigator.pop(ctx);
                    _titleController.clear();
                    _descController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Evento agendado com sucesso!')),
                    );
                  }
                }
              },
              child: const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'exam':
        return AsterConstants.accentRose;
      case 'work':
        return AsterConstants.accentOrange;
      case 'personal':
        return AsterConstants.accentAmber;
      case 'study':
      default:
        return AsterConstants.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário & Compromissos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AsterConstants.secondary),
            tooltip: 'Agendar Evento',
            onPressed: _openAddEventDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.calendarEventsStream(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];

          // Filtrar eventos do dia selecionado
          final selectedEvents = events.where((e) {
            if (_selectedDay == null) return false;
            final start = DateTime.parse(e['start_time']);
            return isSameDay(start, _selectedDay);
          }).toList();

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    eventLoader: (day) {
                      return events.where((e) {
                        final start = DateTime.parse(e['start_time']);
                        return isSameDay(start, day);
                      }).toList();
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AsterConstants.primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: AsterConstants.primary),
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AsterConstants.secondary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: AsterConstants.accentOrange,
                        shape: BoxShape.circle,
                      ),
                      defaultTextStyle: const TextStyle(color: AsterConstants.textLight),
                      weekendTextStyle: const TextStyle(color: AsterConstants.textMuted),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AsterConstants.textLight),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDay != null
                          ? 'EVENTOS EM ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
                          : 'SELECIONE UM DIA',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AsterConstants.textMuted,
                      ),
                    ),
                    Text('${selectedEvents.length} eventos', style: const TextStyle(color: AsterConstants.textDim, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: selectedEvents.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum evento neste dia.',
                          style: TextStyle(color: AsterConstants.textDim),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: selectedEvents.length,
                        itemBuilder: (context, idx) {
                          final event = selectedEvents[idx];
                          final cat = (event['category'] as String?) ?? 'study';
                          final start = DateTime.parse(event['start_time']);

                          return Card(
                            child: ListTile(
                              leading: Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(cat),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              title: Text(
                                event['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AsterConstants.textLight),
                              ),
                              subtitle: Text(
                                '${DateFormat('HH:mm').format(start)} • ${event['description'] ?? cat.toUpperCase()}',
                                style: const TextStyle(color: AsterConstants.textMuted, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
