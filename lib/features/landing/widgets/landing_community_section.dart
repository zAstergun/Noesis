import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/localization/noesis_l10n.dart';
import '../../../core/theme.dart';
import '../../../widgets/insight_icon.dart';
import '../../../widgets/vip_privileges.dart';
import 'landing_motion.dart';

/// Seção Comunidade ("Estudar em grupo muda o jogo") modelada fielmente sobre
/// o workspace real de `StudyGroupsScreen` (Lista de Grupos, Cabeçalho com
/// matéria/código/Convite @, abas horizontais Chat, Simulados, Flashcards,
/// Cadernos, Trilhas, Diário de Estudo e Ranking Interno de Insights).
class LandingCommunitySection extends StatefulWidget {
  const LandingCommunitySection({super.key, required this.width});

  final double width;

  @override
  State<LandingCommunitySection> createState() => _LandingCommunitySectionState();
}

class _LandingCommunitySectionState extends State<LandingCommunitySection> {
  int _selectedGroupIndex = 0;
  String _selectedTab = 'chat';
  String? _selectedDiaryMember;

  static List<
      ({
        String name,
        String subject,
        String description,
        String inviteCode,
        int members,
        bool isLeader,
      })> get _groups => [
    (
      name: NoesisL10n.tr('Estruturas & Algoritmos'),
      subject: NoesisL10n.tr('Computação'),
      description: NoesisL10n.tr('Árvores balanceadas, grafos, revisão espaçada e simulados semanais.'),
      inviteCode: 'NOE-4920',
      members: 14,
      isLeader: true,
    ),
    (
      name: NoesisL10n.tr('OAB & Constitucional'),
      subject: NoesisL10n.tr('Direito'),
      description: NoesisL10n.tr('Questões comentadas de 1ª e 2ª fase + cadernos colaborativos de súmulas.'),
      inviteCode: 'NOE-8134',
      members: 22,
      isLeader: false,
    ),
    (
      name: NoesisL10n.tr('Medicina & USMLE'),
      subject: NoesisL10n.tr('Medicina'),
      description: NoesisL10n.tr('Casos clínicos com RAG, baralhos 3D espaçados e metas diárias no Diário.'),
      inviteCode: 'NOE-6051',
      members: 18,
      isLeader: false,
    ),
  ];

  static List<({String id, String label, IconData icon})> get _tabs => [
    (id: 'chat', label: NoesisL10n.tr('Chat (3)'), icon: Icons.forum_rounded),
    (id: 'exams', label: NoesisL10n.tr('Simulados (3)'), icon: Icons.assignment_rounded),
    (id: 'flashcards', label: NoesisL10n.tr('Flashcards (3)'), icon: Icons.style_rounded),
    (id: 'notebooks', label: NoesisL10n.tr('Cadernos (3)'), icon: Icons.menu_book_rounded),
    (id: 'roadmaps', label: NoesisL10n.tr('Trilhas (2)'), icon: Icons.route_rounded),
    (id: 'diary', label: NoesisL10n.tr('Diário de Estudo'), icon: Icons.auto_stories_rounded),
    (id: 'ranking', label: NoesisL10n.tr('Ranking'), icon: Icons.emoji_events_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.width < 640;
    final isWide = widget.width >= 960;
    final primary = AsterTheme.primary(context);
    final onPrimary = AsterTheme.onPrimary(context);
    final cardCol = AsterTheme.card(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final group = _groups[_selectedGroupIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: cardCol.withValues(alpha: isDark ? 0.9 : 0.85),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(
                      color: insetCol.withValues(alpha: isDark ? 0.75 : 0.95),
                    ),
                    boxShadow: isDark
                        ? AsterConstants.claySubtleDarkShadow
                        : AsterConstants.claySubtleShadow,
                  ),
                  child: Text(
                    context.tr('Grupos de Estudo'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: mutedCol,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('Estudar em grupo muda o jogo'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: isWide ? 48 : (isCompact ? 30 : 38),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.4,
                    height: 1.08,
                    color: textCol,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('Compartilhe cadernos, baralhos, simulados e trilhas, acompanhe o Diário de Estudos por participante e suba no Ranking Interno de Insights.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: isCompact ? 15 : 17,
                    height: 1.55,
                    color: mutedCol,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 34),

        // Container Soft Clay replicando o fluxo real de Grupos de Estudo
        Container(
          padding: EdgeInsets.all(isCompact ? 14 : 26),
          decoration: BoxDecoration(
            color: cardCol.withValues(alpha: isDark ? 0.96 : 0.94),
            borderRadius: BorderRadius.circular(isCompact ? 26 : 36),
            border: Border.all(color: insetCol.withValues(alpha: isDark ? 0.8 : 0.95)),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Seletor de grupos reais (cards de grupo do usuário)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 780
                      ? 3
                      : (constraints.maxWidth >= 500 ? 2 : 1);
                  const gap = 12.0;
                  final itemW = (constraints.maxWidth - (cols - 1) * gap) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: List.generate(_groups.length, (i) {
                      final g = _groups[i];
                      final on = i == _selectedGroupIndex;
                      return SizedBox(
                        width: itemW,
                        child: LandingHoverLift(
                          liftY: -2.0,
                          child: InkWell(
                            onTap: () => setState(() {
                              _selectedGroupIndex = i;
                              _selectedDiaryMember = null;
                            }),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: kLandingFluidCurve,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: on ? altCol : cardCol,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: on
                                      ? primary
                                      : insetCol.withValues(alpha: 0.85),
                                  width: on ? 1.6 : 1.0,
                                ),
                                boxShadow: on
                                    ? AsterTheme.primaryShadow(context, primary)
                                        .map((s) => BoxShadow(
                                              color: s.color.withValues(alpha: 0.14),
                                              blurRadius: 14,
                                              offset: const Offset(0, 6),
                                            ))
                                        .toList()
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: on ? 0.18 : 0.11),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.groups_rounded,
                                      size: 20,
                                      color: primary,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr(g.name),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: textCol,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              context.tr(g.subject),
                                              style: GoogleFonts.manrope(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: primary,
                                              ),
                                            ),
                                            Text(
                                              context.tr(' · {count} membros', {'count': g.members}),
                                              style: GoogleFonts.manrope(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: mutedCol,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (g.isLeader)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AsterVipColors.gold.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(
                                          AsterConstants.radiusPill,
                                        ),
                                      ),
                                      child: Text(
                                        context.tr('Líder'),
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AsterVipColors.goldDark,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 2. Cabeçalho real do grupo ativo (matéria, código de convite, Copiar Link, Convidar @)
              Container(
                padding: EdgeInsets.all(isCompact ? 14 : 18),
                decoration: BoxDecoration(
                  color: altCol,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: insetCol.withValues(alpha: 0.75)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cardCol,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: insetCol),
                              ),
                              child: Icon(Icons.arrow_back_rounded, size: 18, color: mutedCol),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      group.name,
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: isCompact ? 17 : 20,
                                        fontWeight: FontWeight.w700,
                                        color: textCol,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.13),
                                        borderRadius: BorderRadius.circular(
                                          AsterConstants.radiusPill,
                                        ),
                                      ),
                                      child: Text(
                                        context.tr(group.subject),
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('{members} membros · Código {code}', {'members': group.members, 'code': group.inviteCode}),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: mutedCol,
                                  ),
                                ),
                              ],
                              ),
                            ),
                          ],
                        ),
                        if (!isCompact)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: cardCol,
                                  borderRadius: BorderRadius.circular(
                                    AsterConstants.radiusPill,
                                  ),
                                  border: Border.all(color: insetCol),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.link_rounded, size: 15, color: textCol),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.tr('Copiar Link'),
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(
                                    AsterConstants.radiusPill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1_rounded,
                                      size: 15,
                                      color: onPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.tr('Convidar @'),
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(group.description),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: mutedCol,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Abas reais em Wrap horizontal (iguais a _buildGroupHeaderAndTabs)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tabs.map((t) {
                  final on = _selectedTab == t.id;
                  return InkWell(
                    onTap: () => setState(() => _selectedTab = t.id),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: kLandingFluidCurve,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8.5,
                      ),
                      decoration: BoxDecoration(
                        color: on ? primary : cardCol,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        border: Border.all(
                          color: on ? Colors.transparent : insetCol,
                        ),
                        boxShadow: on
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                  spreadRadius: -2,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            t.icon,
                            size: 15,
                            color: on ? onPrimary : mutedCol,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr(t.label),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: on ? FontWeight.w800 : FontWeight.w700,
                              color: on ? onPrimary : textCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 4. Conteúdo da aba ativa com transição sequencial sem sobreposição
              Container(
                padding: EdgeInsets.all(isCompact ? 14 : 18),
                decoration: BoxDecoration(
                  color: altCol,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: insetCol.withValues(alpha: 0.75)),
                ),
                child: LandingSequentialSwitcher(
                  outDuration: const Duration(milliseconds: 120),
                  inDuration: const Duration(milliseconds: 280),
                  outOffset: const Offset(0, 6),
                  inOffset: const Offset(0, 10),
                  child: KeyedSubtree(
                    key: ValueKey('comm_${_selectedGroupIndex}_$_selectedTab'),
                    child: _buildTabBody(
                      context,
                      group: group,
                      cardCol: cardCol,
                      insetCol: insetCol,
                      primary: primary,
                      onPrimary: onPrimary,
                      textCol: textCol,
                      mutedCol: mutedCol,
                      isCompact: isCompact,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody(
    BuildContext context, {
    required ({
      String name,
      String subject,
      String description,
      String inviteCode,
      int members,
      bool isLeader,
    }) group,
    required Color cardCol,
    required Color insetCol,
    required Color primary,
    required Color onPrimary,
    required Color textCol,
    required Color mutedCol,
    required bool isCompact,
  }) {
    if (_selectedTab == 'chat') {
      final msgs = switch (_selectedGroupIndex) {
        1 => [
            (
              initial: 'D',
              name: 'Davi',
              handle: '@davi.jur',
              time: '18:02',
              text: context.tr('Subi o simulado OAB Comentado de Direito Constitucional no grupo.'),
              color: AsterConstants.ambar,
              isMine: false,
              isLeader: false,
            ),
            (
              initial: 'M',
              name: 'Marina',
              handle: '@marina',
              time: '18:05',
              text: context.tr('Vou resolver agora e comparar nossas pontuações no Ranking do grupo.'),
              color: AsterConstants.lavanda,
              isMine: false,
              isLeader: true,
            ),
            (
              initial: 'V',
              name: context.tr('Você'),
              handle: '@${NoesisL10n.tr('estudante')}',
              time: '18:09',
              text: context.tr('Também compartilhei o baralho 3D de Controle de Constitucionalidade.'),
              color: AsterConstants.menta,
              isMine: true,
              isLeader: false,
            ),
          ],
        2 => [
            (
              initial: 'C',
              name: 'Caio',
              handle: '@caio.med',
              time: '14:20',
              text: context.tr('Montei uma trilha compartilhada de USMLE Step 1 para revisar esta semana.'),
              color: AsterConstants.coral,
              isMine: false,
              isLeader: false,
            ),
            (
              initial: 'M',
              name: 'Marina',
              handle: '@marina',
              time: '14:24',
              text: context.tr('Estou fechando um bloco de 50m no Diário e já entro no baralho!'),
              color: AsterConstants.lavanda,
              isMine: false,
              isLeader: true,
            ),
            (
              initial: 'V',
              name: context.tr('Você'),
              handle: '@${NoesisL10n.tr('estudante')}',
              time: '14:30',
              text: context.tr('Bora! +24 Insights garantidos na sessão de hoje.'),
              color: AsterConstants.menta,
              isMine: true,
              isLeader: false,
            ),
          ],
        _ => [
            (
              initial: 'M',
              name: 'Marina',
              handle: '@marina',
              time: '09:12',
              text: context.tr('Bloco de 50 minutos registrado no Diário. Quem entra no simulado de Árvores AVL?'),
              color: AsterConstants.lavanda,
              isMine: false,
              isLeader: true,
            ),
            (
              initial: 'C',
              name: 'Caio',
              handle: '@caio.dev',
              time: '09:14',
              text: context.tr('Eu! Vou revisar os flashcards 3D de Tabela Hash primeiro.'),
              color: AsterConstants.coral,
              isMine: false,
              isLeader: false,
            ),
            (
              initial: 'V',
              name: context.tr('Você'),
              handle: '@${NoesisL10n.tr('estudante')}',
              time: '09:18',
              text: context.tr('Compartilhei meu caderno de Complexidade O(n) na aba Cadernos.'),
              color: AsterConstants.menta,
              isMine: true,
              isLeader: false,
            ),
          ],
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.forum_rounded, size: 17, color: primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Chat do Grupo'),
                      style: GoogleFonts.manrope(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    Text(
                      context.tr('Converse, tire dúvidas e combine metas com os membros'),
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: mutedCol,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(msgs.length, (i) {
            final m = msgs[i];
            final bubble = Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.isMine ? primary.withValues(alpha: 0.13) : cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: m.isMine ? primary.withValues(alpha: 0.35) : insetCol,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        context.tr(m.name),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: m.isMine ? primary : textCol,
                        ),
                      ),
                      Text(
                        m.handle,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedCol,
                        ),
                      ),
                      if (m.isLeader)
                        Text(
                          context.tr('· Líder'),
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AsterVipColors.goldDark,
                          ),
                        ),
                      Text(
                        m.time,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: mutedCol,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(m.text),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.4,
                      color: textCol,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );

            return LandingEntrance(
              delay: Duration(milliseconds: i * 55),
              duration: const Duration(milliseconds: 380),
              offsetY: 12,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment:
                      m.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!m.isMine) ...[
                      _LandingUserAvatar(
                        nameOrHandle: m.handle,
                        initial: m.initial,
                        fallbackColor: m.color,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(child: bubble),
                    if (m.isMine) ...[
                      const SizedBox(width: 8),
                      _LandingUserAvatar(
                        nameOrHandle: m.handle,
                        initial: m.initial,
                        fallbackColor: primary,
                        textColor: onPrimary,
                        size: 32,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    if (_selectedTab == 'diary') {
      final logs = [
        (user: '@marina', name: 'Marina', subject: context.tr('Árvores AVL & Rotações'), mins: '55m', time: context.tr('Hoje · 09:12')),
        (user: '@caio', name: 'Caio', subject: context.tr('Grafos & Dijkstra'), mins: '1h 20m', time: context.tr('Hoje · 11:05')),
        (user: '@luna', name: 'Luna', subject: context.tr('Programação Dinâmica'), mins: '45m', time: context.tr('Ontem · 20:30')),
      ].where((l) => _selectedDiaryMember == null || l.user == _selectedDiaryMember).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Diário de Estudos por Participante'),
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                  Text(
                    context.tr('Veja o que cada membro estudou e filtre por pessoa'),
                    style: GoogleFonts.manrope(fontSize: 11.5, color: mutedCol),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [null, '@marina', '@caio', '@luna'].map((u) {
                  final sel = _selectedDiaryMember == u;
                  return InkWell(
                    onTap: () => setState(() => _selectedDiaryMember = u),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    child: Container(
                      padding: EdgeInsetsDirectional.fromSTEB(u == null ? 10 : 6, 5, 10, 5),
                      decoration: BoxDecoration(
                        color: sel ? primary.withValues(alpha: 0.16) : cardCol,
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        border: Border.all(color: sel ? primary : insetCol),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (u != null) ...[
                            _LandingUserAvatar(
                              nameOrHandle: u,
                              initial: u.substring(1, 2).toUpperCase(),
                              fallbackColor: primary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            u ?? context.tr('Todos (3)'),
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: sel ? primary : textCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(logs.length, (i) {
            final l = logs[i];
            return LandingEntrance(
              delay: Duration(milliseconds: i * 50),
              duration: const Duration(milliseconds: 360),
              offsetY: 10,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: insetCol.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _LandingUserAvatar(
                          nameOrHandle: l.user,
                          initial: l.name.substring(0, 1),
                          fallbackColor: primary,
                          size: 38,
                        ),
                        PositionedDirectional(
                          end: -2,
                          bottom: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AsterConstants.menta,
                              shape: BoxShape.circle,
                              border: Border.all(color: cardCol, width: 1.6),
                            ),
                            child: const Icon(
                              Icons.timer_rounded,
                              size: 9.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l.name} (${l.user}) · ${context.tr(l.subject)}',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textCol,
                            ),
                          ),
                          Text(
                            context.tr(l.time),
                            style: GoogleFonts.manrope(fontSize: 11, color: mutedCol),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l.mins,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AsterConstants.menta,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    if (_selectedTab == 'ranking') {
      final ranked = [
        (name: 'Marina', handle: '@marina', stats: context.tr('14h20m no grupo'), insights: '420'),
        (name: 'Caio', handle: '@caio', stats: context.tr('11h50m no grupo'), insights: '365'),
        (name: 'Luna', handle: '@luna', stats: context.tr('10h15m no grupo'), insights: '310'),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const InsightCoinIcon(size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('Ranking Interno de Insights (Estudo no Grupo)'),
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(ranked.length, (i) {
            final r = ranked[i];
            return LandingEntrance(
              delay: Duration(milliseconds: i * 55),
              duration: const Duration(milliseconds: 360),
              offsetY: 10,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: insetCol.withValues(alpha: 0.85)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${i + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: i == 0 ? AsterVipColors.goldDark : mutedCol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _LandingUserAvatar(
                      nameOrHandle: r.name,
                      initial: r.name.substring(0, 1),
                      fallbackColor: i == 0 ? primary : AsterConstants.menta,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: textCol,
                            ),
                          ),
                          Text(
                            '${r.handle} · ${context.tr(r.stats)}',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: mutedCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const InsightCoinIcon(size: 15),
                    const SizedBox(width: 5),
                    Text(
                      r.insights,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textCol,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    if (_selectedTab == 'exams') {
      return _buildSimuladosTab(
        group: group,
        cardCol: cardCol,
        insetCol: insetCol,
        primary: primary,
        onPrimary: onPrimary,
        textCol: textCol,
        mutedCol: mutedCol,
        isCompact: isCompact,
      );
    }

    if (_selectedTab == 'flashcards') {
      return _buildFlashcardsTab(
        group: group,
        cardCol: cardCol,
        insetCol: insetCol,
        primary: primary,
        onPrimary: onPrimary,
        textCol: textCol,
        mutedCol: mutedCol,
        isCompact: isCompact,
      );
    }

    if (_selectedTab == 'notebooks') {
      return _buildCadernosTab(
        group: group,
        cardCol: cardCol,
        insetCol: insetCol,
        primary: primary,
        textCol: textCol,
        mutedCol: mutedCol,
        isCompact: isCompact,
      );
    }

    return _buildTrilhasTab(
      group: group,
      cardCol: cardCol,
      insetCol: insetCol,
      primary: primary,
      textCol: textCol,
      mutedCol: mutedCol,
      isCompact: isCompact,
    );
  }

  Widget _buildSimuladosTab({
    required ({
      String name,
      String subject,
      String description,
      String inviteCode,
      int members,
      bool isLeader,
    }) group,
    required Color cardCol,
    required Color insetCol,
    required Color primary,
    required Color onPrimary,
    required Color textCol,
    required Color mutedCol,
    required bool isCompact,
  }) {
    final exams = switch (_selectedGroupIndex) {
      1 => [
          (
            title: context.tr('OAB 1ª Fase · Constitucional'),
            tag: context.tr('Banca FGV · 20 questões'),
            accuracy: context.tr('82% acerto do grupo'),
            author: '@davi.jur',
            accent: AsterConstants.ambar,
          ),
          (
            title: context.tr('Controle de Constitucionalidade'),
            tag: context.tr('RAG · PDF Comentado · 12q'),
            accuracy: context.tr('88% acerto do grupo'),
            author: '@marina',
            accent: AsterConstants.menta,
          ),
        ],
      2 => [
          (
            title: context.tr('USMLE Step 1 · Neuroanatomia'),
            tag: context.tr('Oficial · 25 questões'),
            accuracy: context.tr('79% acerto do grupo'),
            author: '@caio.med',
            accent: AsterConstants.coral,
          ),
          (
            title: context.tr('Cardiologia Clínica · Casos RAG'),
            tag: context.tr('Anexo .pdf · 15 questões'),
            accuracy: context.tr('86% acerto do grupo'),
            author: '@marina',
            accent: AsterConstants.menta,
          ),
        ],
      _ => [
          (
            title: context.tr('Simulado · Árvores AVL & Grafos'),
            tag: context.tr('RAG · 15 questões'),
            accuracy: context.tr('84% acerto do grupo'),
            author: '@marina',
            accent: AsterConstants.ambar,
          ),
          (
            title: context.tr('Prova Comentada · Tabela Hash & O(n)'),
            tag: context.tr('Banca POSCOMP · 10q'),
            accuracy: context.tr('90% acerto do grupo'),
            author: '@caio.dev',
            accent: AsterConstants.menta,
          ),
        ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_rounded, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  context.tr('Simulados Compartilhados · {subject}', {'subject': context.tr(group.subject)}),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Text(
                context.tr('+ Anexar Simulado'),
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = !isCompact && constraints.maxWidth >= 560;
            const gap = 12.0;
            final cardW = twoCols ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(exams.length, (i) {
                final ex = exams[i];
                return SizedBox(
                  width: cardW,
                  child: LandingEntrance(
                    delay: Duration(milliseconds: i * 65),
                    duration: const Duration(milliseconds: 360),
                    offsetY: 10,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: cardCol,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: insetCol.withValues(alpha: 0.85)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ex.accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: Text(
                                  context.tr(ex.tag),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color.lerp(ex.accent, textCol, 0.35),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                ex.author,
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: mutedCol,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr(ex.title),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 15, color: AsterConstants.menta),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  context.tr(ex.accuracy),
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: mutedCol,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: Text(
                                  context.tr('Resolver →'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFlashcardsTab({
    required ({
      String name,
      String subject,
      String description,
      String inviteCode,
      int members,
      bool isLeader,
    }) group,
    required Color cardCol,
    required Color insetCol,
    required Color primary,
    required Color onPrimary,
    required Color textCol,
    required Color mutedCol,
    required bool isCompact,
  }) {
    final decks = switch (_selectedGroupIndex) {
      1 => [
          (title: NoesisL10n.tr('Súmulas Vinculantes STF'), total: 32, easy: 18, good: 9, hard: 5, owner: '@marina'),
          (title: NoesisL10n.tr('Remédios Constitucionais'), total: 18, easy: 11, good: 5, hard: 2, owner: '@davi.jur'),
        ],
      2 => [
          (title: NoesisL10n.tr('Farmacologia Autonômica 3D'), total: 40, easy: 22, good: 12, hard: 6, owner: '@caio.med'),
          (title: NoesisL10n.tr('Ciclo Cardíaco & ECG'), total: 24, easy: 16, good: 6, hard: 2, owner: '@marina'),
        ],
      _ => [
          (title: NoesisL10n.tr('Tabela Hash & Árvores Balanceadas'), total: 28, easy: 16, good: 8, hard: 4, owner: '@marina'),
          (title: NoesisL10n.tr('Complexidade Assintótica O(n)'), total: 20, easy: 14, good: 4, hard: 2, owner: '@caio.dev'),
        ],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_rounded, size: 18, color: primary),
                const SizedBox(width: 8),
                Text(
                  context.tr('Baralhos 3D & Revisão Espaçada · {group}', {'group': context.tr(group.name)}),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                  ),
                ),
              ],
            ),
            Text(
              context.tr('Fácil 🟢 · Bom 🟡 · Difícil 🔴'),
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: mutedCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = !isCompact && constraints.maxWidth >= 560;
            const gap = 12.0;
            final cardW = twoCols ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(decks.length, (i) {
                final d = decks[i];
                return SizedBox(
                  width: cardW,
                  child: LandingEntrance(
                    delay: Duration(milliseconds: i * 65),
                    duration: const Duration(milliseconds: 360),
                    offsetY: 10,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: cardCol,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: insetCol.withValues(alpha: 0.85)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: Text(
                                  context.tr('{count} cartões 3D', {'count': d.total}),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                d.owner,
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: mutedCol,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr(d.title),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Barra segmentada SRS real (Fácil / Bom / Difícil)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 7,
                              child: Row(
                                children: [
                                  Expanded(flex: d.easy, child: Container(color: AsterConstants.menta)),
                                  Expanded(flex: d.good, child: Container(color: AsterConstants.ambar)),
                                  Expanded(flex: d.hard, child: Container(color: AsterConstants.coral)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('{easy} fáceis · {good} bons · {hard} difíceis', {
                                    'easy': d.easy,
                                    'good': d.good,
                                    'hard': d.hard,
                                  }),
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: mutedCol,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: Text(
                                  context.tr('Revisar 3D'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCadernosTab({
    required ({
      String name,
      String subject,
      String description,
      String inviteCode,
      int members,
      bool isLeader,
    }) group,
    required Color cardCol,
    required Color insetCol,
    required Color primary,
    required Color textCol,
    required Color mutedCol,
    required bool isCompact,
  }) {
    final notes = switch (_selectedGroupIndex) {
      1 => (
          list: [
            NoesisL10n.tr('Controle Difuso x Concentrado'),
            NoesisL10n.tr('Cláusulas Pétreas (Art. 60 §4º)'),
            NoesisL10n.tr('Súmulas Comentadas'),
          ],
          noteTitle: NoesisL10n.tr('Controle Difuso vs. Concentrado'),
          author: NoesisL10n.tr('Editado por @davi.jur · Markdown'),
          body: NoesisL10n.tr(
              '• Controle Difuso: qualquer juiz ou tribunal analisa incidenter tantum (caso concreto).\n• Controle Concentrado (ADI/ADC/ADPF): STF decide com efeito erga omnes e vinculante.'),
          tip: NoesisL10n.tr('Dica para prova: verificar modulação temporal (quórum de 2/3 no STF).'),
        ),
      2 => (
          list: [
            NoesisL10n.tr('Fisiologia Renal & Néfron'),
            NoesisL10n.tr('Protocolo Sepse & Lactato'),
            NoesisL10n.tr('Antiarrítmicos (Classes I–IV)'),
          ],
          noteTitle: NoesisL10n.tr('Fisiologia Renal · Filtração Glomerular'),
          author: NoesisL10n.tr('Editado por @caio.med · Markdown'),
          body: NoesisL10n.tr(
              '• TFG normal: ~125 mL/min (regulada por arteríola aferente e eferente).\n• Alça de Henle ascendente espessa: reabsorve Na⁺/K⁺/2Cl⁻ — alvo dos diuréticos de alça.'),
          tip: NoesisL10n.tr('Flashcard ligado: revisar mecanismo da furosemida.'),
        ),
      _ => (
          list: [
            NoesisL10n.tr('Complexidade & Notação Big-O'),
            NoesisL10n.tr('Árvores AVL vs. Rubro-Negra'),
            NoesisL10n.tr('Tabela Hash & Colisões'),
          ],
          noteTitle: NoesisL10n.tr('Complexidade & Árvores Balanceadas'),
          author: NoesisL10n.tr('Editado por @luna · Markdown'),
          body: NoesisL10n.tr(
              '• Árvore AVL: altura estrita h ≤ 1.44·log₂(n) — ideal quando há muito mais buscas do que inserções.\n• Tabela Hash: acesso médio O(1) usando espalhamento e fator de carga α controlado.'),
          tip: NoesisL10n.tr('Conectado ao Simulado #1 e ao baralho principal do grupo.'),
        ),
    };

    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(notes.list.length, (i) {
        final on = i == 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: on ? primary.withValues(alpha: 0.14) : cardCol,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? primary.withValues(alpha: 0.4) : insetCol.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 15, color: on ? primary : mutedCol),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.tr(notes.list[i]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: on ? primary : textCol,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );

    final previewPane = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: insetCol.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(notes.noteTitle),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AsterConstants.menta.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  'Markdown',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AsterConstants.menta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            context.tr(notes.author),
            style: GoogleFonts.manrope(fontSize: 11.5, color: mutedCol, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(notes.body),
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.5,
              color: textCol,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: BorderDirectional(start: BorderSide(color: primary, width: 3)),
            ),
            child: Text(
              context.tr(notes.tip),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
          ),
        ],
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [sidebar, const SizedBox(height: 8), previewPane],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 230, child: sidebar),
        const SizedBox(width: 14),
        Expanded(child: previewPane),
      ],
    );
  }

  Widget _buildTrilhasTab({
    required ({
      String name,
      String subject,
      String description,
      String inviteCode,
      int members,
      bool isLeader,
    }) group,
    required Color cardCol,
    required Color insetCol,
    required Color primary,
    required Color textCol,
    required Color mutedCol,
    required bool isCompact,
  }) {
    final steps = switch (_selectedGroupIndex) {
      1 => [
          (title: NoesisL10n.tr('Teoria Fundamental & Art. 5º'), status: NoesisL10n.tr('Concluída'), done: true, current: false),
          (title: NoesisL10n.tr('Organização do Estado & Poderes'), status: NoesisL10n.tr('Concluída'), done: true, current: false),
          (title: NoesisL10n.tr('Simulado RAG FGV Comentado'), status: NoesisL10n.tr('Em andamento · 65%'), done: false, current: true),
          (title: NoesisL10n.tr('Revisão Espaçada de Súmulas'), status: NoesisL10n.tr('Próxima etapa'), done: false, current: false),
        ],
      2 => [
          (title: NoesisL10n.tr('Módulo 1 · Fisiologia Base'), status: NoesisL10n.tr('Concluída'), done: true, current: false),
          (title: NoesisL10n.tr('Módulo 2 · Farmacologia Clínica'), status: NoesisL10n.tr('Concluída'), done: true, current: false),
          (title: NoesisL10n.tr('Simulado Integrado USMLE'), status: NoesisL10n.tr('Em andamento · 50%'), done: false, current: true),
          (title: NoesisL10n.tr('Revisão Final em Grupo'), status: NoesisL10n.tr('Próxima etapa'), done: false, current: false),
        ],
      _ => [
          (title: NoesisL10n.tr('Análise Assintótica & Big-O'), status: NoesisL10n.tr('Concluída'), done: true, current: false),
          (title: NoesisL10n.tr('Listas, Pilhas, Filas & Hash'), status: NoesisL10n.tr('Concluída'), done: true, current: false),
          (title: NoesisL10n.tr('Árvores AVL & Grafos · Simulado'), status: NoesisL10n.tr('Em andamento · 70%'), done: false, current: true),
          (title: NoesisL10n.tr('Programação Dinâmica + Revisão 3D'), status: NoesisL10n.tr('Próxima etapa'), done: false, current: false),
        ],
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: insetCol.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('Trilha Guiada · {group}', {'group': context.tr(group.name)}),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AsterConstants.menta.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Text(
                  context.tr('68% concluída'),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AsterConstants.menta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final st = steps[i];
            return LandingEntrance(
              delay: Duration(milliseconds: i * 50),
              duration: const Duration(milliseconds: 350),
              offsetY: 8,
              child: Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: st.done
                            ? AsterConstants.menta
                            : (st.current ? primary.withValues(alpha: 0.15) : insetCol.withValues(alpha: 0.5)),
                        shape: BoxShape.circle,
                        border: st.current ? Border.all(color: primary, width: 1.6) : null,
                      ),
                      child: Center(
                        child: st.done
                            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: st.current ? primary : mutedCol,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr(st.title),
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: st.current || st.done ? FontWeight.w800 : FontWeight.w600,
                          color: textCol,
                        ),
                      ),
                    ),
                    Text(
                      context.tr(st.status),
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: st.done
                            ? AsterConstants.menta
                            : (st.current ? primary : mutedCol),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LandingUserAvatar extends StatelessWidget {
  const _LandingUserAvatar({
    required this.nameOrHandle,
    required this.initial,
    required this.fallbackColor,
    required this.size,
    this.textColor = Colors.white,
  });

  final String nameOrHandle;
  final String initial;
  final Color fallbackColor;
  final double size;
  final Color textColor;

  static String? _assetFor(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('marina')) return 'assets/images/avatar_marina.jpg';
    if (lower.contains('luna')) return 'assets/images/avatar_luna.jpg';
    if (lower.contains('caio') || lower.contains('davi')) {
      return 'assets/images/avatar_davi.jpg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetFor(nameOrHandle);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fallbackColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.manrope(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
    );

    if (asset == null) return fallback;

    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
