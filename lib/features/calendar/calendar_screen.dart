import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/supabase_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _activeViewMode = 'Semana'; // 'Dia', 'Semana', 'Mês', 'Timeline'

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
          backgroundColor: AsterConstants.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusLarge)),
          title: Text(
            'Novo Bloco / Agendamento',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: AsterConstants.textDark),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Título do Bloco (ex: Prova Security+, Revisão de Redes)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Categoria Semântica'),
                  items: const [
                    DropdownMenuItem(value: 'study', child: Text('Estudo Teórico (Lavanda)')),
                    DropdownMenuItem(value: 'review', child: Text('Revisão Espaçada (Menta)')),
                    DropdownMenuItem(value: 'lab', child: Text('Lab / Simulado (Âmbar)')),
                    DropdownMenuItem(value: 'exam', child: Text('Prova Oficial / Prazos (Coral)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Detalhes ou Objetivos'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.manrope(color: AsterConstants.textMuted)),
            ),
            SoftClayPillButton(
              text: 'Agendar Bloco',
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
                      const SnackBar(content: Text('Bloco agendado com sucesso!')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.calendarEventsStream(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28.0 : 16.0,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header do Calendário ───
              _buildTopHeader(isDesktop),
              const SizedBox(height: 18),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grade Semanal de Blocos (Timeline)
                    Expanded(flex: 7, child: _buildWeeklyTimelineGrid(events)),
                    const SizedBox(width: 20),
                    // Painel Lateral: Mini Mês + Próximos Marcos + Sugestão AI
                    Expanded(flex: 3, child: _buildRightSidePanel(events)),
                  ],
                )
              else ...[
                _buildRightSidePanel(events),
                const SizedBox(height: 16),
                _buildWeeklyTimelineGrid(events),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ─── Widget: Top Header com Controles e Legenda ───
  Widget _buildTopHeader(bool isDesktop) {
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capitalizedMonth,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AsterConstants.textDark,
                  ),
                ),
                Text(
                  'Semana 12 · 11h planejadas · prova Security+ em 2 dias',
                  style: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
                ),
              ],
            ),
            const Spacer(),

            // Seletor de Modo de Exibição
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AsterConstants.surfaceCard,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                boxShadow: AsterConstants.claySubtleShadow,
              ),
              child: Row(
                children: ['Dia', 'Semana', 'Mês', 'Timeline'].map((mode) {
                  final isSelected = _activeViewMode == mode;
                  return InkWell(
                    onTap: () => setState(() => _activeViewMode = mode),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AsterConstants.lavanda : Colors.transparent,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        mode,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AsterConstants.textDark,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),

            // Navegação Rápida
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AsterConstants.surfaceCard,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                boxShadow: AsterConstants.claySubtleShadow,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _focusedDay = DateTime.now()),
                    child: Text('Hoje', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterConstants.textDark)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _focusedDay = _focusedDay.subtract(const Duration(days: 7))),
                    child: const Icon(Icons.chevron_left_rounded, size: 18, color: AsterConstants.textDark),
                  ),
                  InkWell(
                    onTap: () => setState(() => _focusedDay = _focusedDay.add(const Duration(days: 7))),
                    child: const Icon(Icons.chevron_right_rounded, size: 18, color: AsterConstants.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Barra de Legenda Semântica Soft Clay
        Row(
          children: [
            const SoftClayTag(label: 'Estudo', color: AsterConstants.lavanda),
            const SizedBox(width: 8),
            const SoftClayTag(label: 'Revisão', color: AsterConstants.menta),
            const SizedBox(width: 8),
            const SoftClayTag(label: 'Lab / Simulado', color: AsterConstants.ambar),
            const SizedBox(width: 8),
            const SoftClayTag(label: 'Prova / Compromisso', color: AsterConstants.coral),
            const Spacer(),
            SoftClayPillButton(
              text: '+ Novo bloco',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: _openAddEventDialog,
            ),
          ],
        ),
      ],
    );
  }

  // ─── Widget: Grade da Linha do Tempo Semanal (07h às 22h) ───
  Widget _buildWeeklyTimelineGrid(List<Map<String, dynamic>> realEvents) {
    final days = [
      {'name': 'Seg', 'num': '16'},
      {'name': 'Ter', 'num': '17'},
      {'name': 'Qua', 'num': '18', 'isToday': true},
      {'name': 'Qui', 'num': '19'},
      {'name': 'Sex', 'num': '20'},
      {'name': 'Sáb', 'num': '21'},
      {'name': 'Dom', 'num': '22'},
    ];

    final hours = [
      '07h', '08h', '09h', '10h', '11h', '12h', '13h', '14h', '15h', '16h', '17h', '18h', '19h', '20h', '21h', '22h'
    ];

    // Blocos mock fiéis ao print clay-07 de Obsidian
    final mockGridBlocks = [
      {'dayCol': 0, 'hourIdx': 1, 'title': 'Criptografia · ...', 'sub': 'Estudo · 1.5h', 'color': AsterConstants.lavanda},
      {'dayCol': 1, 'hourIdx': 2, 'title': 'Lab OWASP · S...', 'sub': 'Lab · 2h', 'color': AsterConstants.ambar},
      {'dayCol': 2, 'hourIdx': 1, 'title': 'Criptografia · ...', 'sub': 'Estudo · 1.5h', 'color': AsterConstants.lavanda},
      {'dayCol': 2, 'hourIdx': 7, 'title': 'Mentoria', 'sub': 'Compromisso · 1h', 'color': AsterConstants.coral},
      {'dayCol': 3, 'hourIdx': 3, 'title': 'Simulado #12', 'sub': 'Prova · 1.5h', 'color': AsterConstants.ambar},
      {'dayCol': 4, 'hourIdx': 2, 'title': 'Deep work · Cl...', 'sub': 'Estudo · 3h', 'color': AsterConstants.menta},
      {'dayCol': 4, 'hourIdx': 7, 'title': 'Revisão Cript...', 'sub': 'Revisão · 1h', 'color': AsterConstants.lavanda},
      {'dayCol': 4, 'hourIdx': 9, 'title': 'Security+ · Pr...', 'sub': 'Prova · 2h', 'color': AsterConstants.coral},
      {'dayCol': 5, 'hourIdx': 3, 'title': 'Planejamento', 'sub': 'Compromisso · 1h', 'color': AsterConstants.ambar},
      {'dayCol': 0, 'hourIdx': 12, 'title': 'Raft & Paxos', 'sub': 'Estudo · 1h', 'color': AsterConstants.coral},
      {'dayCol': 1, 'hourIdx': 14, 'title': 'IAM Policies', 'sub': 'Estudo · 1h', 'color': AsterConstants.menta},
      {'dayCol': 3, 'hourIdx': 13, 'title': 'Revisão espa...', 'sub': 'Revisão · 1h', 'color': AsterConstants.menta},
    ];

    return SoftClayCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // Cabeçalho dos Dias da Semana
          Row(
            children: [
              const SizedBox(width: 48), // Espaço para as horas
              ...days.map((d) {
                final isToday = d['isToday'] == true;
                return Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          d['name'] as String,
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterConstants.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isToday ? AsterConstants.lavanda : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              d['num'] as String,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isToday ? Colors.white : AsterConstants.textDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),

          // Grade de Horários
          SizedBox(
            height: 480,
            child: ListView.builder(
              itemCount: hours.length,
              itemBuilder: (context, hIdx) {
                return SizedBox(
                  height: 38,
                  child: Row(
                    children: [
                      // Rótulo da Hora
                      SizedBox(
                        width: 48,
                        child: Text(
                          hours[hIdx],
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AsterConstants.textMuted),
                        ),
                      ),

                      // Células dos Dias
                      ...List.generate(7, (dIdx) {
                        final block = mockGridBlocks.firstWhere(
                          (b) => b['dayCol'] == dIdx && b['hourIdx'] == hIdx,
                          orElse: () => {},
                        );

                        if (block.isNotEmpty) {
                          final color = block['color'] as Color;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border(left: BorderSide(color: color, width: 3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    block['title'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                                  ),
                                  Text(
                                    block['sub'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(fontSize: 8, color: AsterConstants.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(1),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AsterConstants.surfaceInset, width: 0.5)),
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
        ],
      ),
    );
  }

  // ─── Widget: Painel Lateral (Mini Calendário + Marcos + Sugestão AI) ───
  Widget _buildRightSidePanel(List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mini Calendário do Mês
        SoftClayCard(
          padding: const EdgeInsets.all(16),
          child: TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded, size: 18, color: AsterConstants.textDark),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded, size: 18, color: AsterConstants.textDark),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(
                color: AsterConstants.lavanda,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AsterConstants.lavanda.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textDark),
              weekendTextStyle: GoogleFonts.manrope(fontSize: 12, color: AsterConstants.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Próximos Marcos (Exames e Prazos)
        SoftClayCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próximos marcos',
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
              ),
              const SizedBox(height: 14),

              _buildMilestoneRow('Sex 20', 'Prova Security+', '16:00 · Pearson VUE', AsterConstants.coral),
              const SizedBox(height: 10),
              _buildMilestoneRow('Qui 26', 'Simulado AWS SAA', '40 questões · 65 min', AsterConstants.ambar),
              const SizedBox(height: 10),
              _buildMilestoneRow('Abr 02', 'Revisão geral Cripto', 'sugerido pela AI', AsterConstants.menta),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sugestão Proativa do Noesis AI
        SoftClayCard(
          padding: const EdgeInsets.all(20),
          color: AsterConstants.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: AsterConstants.lavanda),
                  const SizedBox(width: 6),
                  Text(
                    'Noesis AI',
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: AsterConstants.lavanda),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Quinta está livre das 15h às 18h. Quer um bloco de 2h de Redes antes da prova?',
                style: GoogleFonts.manrope(fontSize: 12, height: 1.45, color: AsterConstants.textDark),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SoftClayPillButton(
                    text: 'Sim, agendar',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bloco de 2h de Redes agendado para quinta às 15:00!')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  SoftClayPillButton(
                    text: 'Agora não',
                    isSecondary: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneRow(String date, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            date,
            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: AsterConstants.textDark),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(fontSize: 10, color: AsterConstants.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
