import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import '../../../core/localization/noesis_l10n.dart';
import '../../../core/shop_service.dart';
import '../../../core/theme.dart';
import '../../../widgets/insight_icon.dart';
import '../../../widgets/profile_settings_dialog.dart' show buildAvatarImageProvider;
import '../../../widgets/vip_privileges.dart';
import '../../flashcards/models/flashcard_model.dart';
import '../../notebooks/models/notebook_model.dart';
import '../../notebooks/notebooks_screen.dart';
import '../../profile/data/social_connections_service.dart';
import '../../profile/models/user_profile_model.dart';
import '../../quizzes/data/saved_exams_repository.dart';
import '../../roadmaps/models/roadmap_model.dart';
import '../../tracker/dashboard_analytics.dart';
import '../data/study_groups_service.dart';
import '../models/study_group_model.dart';

typedef GroupFeedbackCallback = void Function(String msg, {bool isError});

InputDecoration noesisGroupInputDecoration(
  BuildContext context, {
  required String hintText,
  IconData? prefixIcon,
  String? prefixText,
  String? labelText,
  String? suffixText,
}) {
  final primaryCol = AsterTheme.primary(context);
  final insetCol = AsterTheme.surfaceInset(context);
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixText: prefixText,
    suffixText: suffixText,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 18, color: AsterTheme.textMuted(context))
        : null,
    hintStyle: GoogleFonts.manrope(
      fontSize: 13,
      color: AsterTheme.textMuted(context).withValues(alpha: 0.8),
    ),
    filled: true,
    fillColor: AsterTheme.surfaceAlt(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: insetCol),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: insetCol),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: primaryCol, width: 1.8),
    ),
  );
}

Widget _fieldLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AsterTheme.textMuted(context),
      ),
    ),
  );
}

/// Container padrão refinado de modais do ecossistema Noesis para Grupos de Estudo.
class NoesisGroupModalShell extends StatelessWidget {
  final Key? modalKey;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final double maxWidth;
  final double maxHeight;
  final bool scrollableBody;

  const NoesisGroupModalShell({
    super.key,
    this.modalKey,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.body,
    this.footer,
    this.maxWidth = 520,
    this.maxHeight = 640,
    this.scrollableBody = true,
  });

  @override
  Widget build(BuildContext context) {
    final primaryCol = iconColor ?? AsterTheme.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inset = AsterTheme.surfaceInset(context);

    return Dialog(
      key: modalKey,
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AsterTheme.card(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: inset),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryCol.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: primaryCol),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                          if ((subtitle ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Fechar'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AsterTheme.surfaceAlt(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: inset),

              // Body
              Flexible(
                child: scrollableBody
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        child: body,
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        child: body,
                      ),
              ),

              // Footer
              if (footer != null) ...[
                Divider(height: 1, color: inset),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                  child: footer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Gerencia o ciclo de vida dos `TextEditingController` até que a animação de
/// saída da rota do modal finalize completamente.
class GroupDialogControllersHost extends StatefulWidget {
  final List<String> initialTexts;
  final Widget Function(BuildContext context, List<TextEditingController> ctrls) builder;

  const GroupDialogControllersHost({
    super.key,
    required this.initialTexts,
    required this.builder,
  });

  @override
  State<GroupDialogControllersHost> createState() => _GroupDialogControllersHostState();
}

class _GroupDialogControllersHostState extends State<GroupDialogControllersHost> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.initialTexts.map((t) => TextEditingController(text: t)).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}

Widget _modalFooterButtons(
  BuildContext context, {
  Key? confirmKey,
  required String confirmLabel,
  required VoidCallback onConfirm,
  String? cancelLabel,
  IconData? confirmIcon,
}) {
  final effectiveCancelLabel = cancelLabel ?? context.tr('Cancelar');
  final primaryCol = AsterTheme.primary(context);
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AsterTheme.textMuted(context),
          side: BorderSide(color: AsterTheme.surfaceInset(context)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          ),
        ),
        child: Text(
          effectiveCancelLabel,
          style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(width: 10),
      ElevatedButton.icon(
        key: confirmKey,
        onPressed: onConfirm,
        icon: Icon(confirmIcon ?? Icons.check_rounded, size: 16),
        label: Text(
          confirmLabel,
          style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCol,
          foregroundColor: AsterTheme.onPrimary(context),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          ),
        ),
      ),
    ],
  );
}

// -----------------------------------------------------------------------------
// 1. MODAL CRIAR GRUPO
// -----------------------------------------------------------------------------
Future<void> showCreateGroupModal(
  BuildContext context, {
  required void Function(String groupId) onCreated,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: ['', NoesisL10n.tr('Geral'), ''],
      builder: (dialogCtx, ctrls) {
        final nameCtrl = ctrls[0];
        final subjectCtrl = ctrls[1];
        final descCtrl = ctrls[2];
        return NoesisGroupModalShell(
          icon: Icons.group_add_rounded,
          title: dialogCtx.tr('Criar Grupo de Estudos'),
          subtitle: dialogCtx.tr('Reúna colegas para estudar juntos em um só espaço'),
          maxWidth: 460,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Nome do grupo *')),
              TextField(
                key: const Key('create_group_name_field'),
                controller: nameCtrl,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Squad CompTIA Security+'),
                  prefixIcon: Icons.groups_rounded,
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel(dialogCtx, dialogCtx.tr('Matéria / Foco')),
              TextField(
                controller: subjectCtrl,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Cibersegurança, ENEM, Cloud AWS'),
                  prefixIcon: Icons.label_outline_rounded,
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel(dialogCtx, dialogCtx.tr('Descrição (opcional)')),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Objetivos, horários ou regras rápidas do grupo'),
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmKey: const Key('create_group_confirm_button'),
            confirmLabel: dialogCtx.tr('Criar Grupo'),
            confirmIcon: Icons.rocket_launch_rounded,
            onConfirm: () async {
              final res = await StudyGroupsService.instance.createGroup(
                name: nameCtrl.text,
                subject: subjectCtrl.text,
                description: descCtrl.text,
              );
              if (!dialogCtx.mounted) return;
              if (res.ok && res.group != null) {
                Navigator.of(dialogCtx).pop();
                onCreated(res.group!.id);
                onFeedback(res.message ?? NoesisL10n.tr('Grupo criado!'));
              } else {
                onFeedback(res.error ?? NoesisL10n.tr('Erro ao criar grupo.'), isError: true);
              }
            },
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 2. MODAL ENTRAR POR LINK OU CÓDIGO
// -----------------------------------------------------------------------------
Future<void> showJoinGroupModal(
  BuildContext context, {
  required void Function(String groupId) onJoined,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: const [''],
      builder: (dialogCtx, ctrls) {
        final codeCtrl = ctrls[0];
        return NoesisGroupModalShell(
          icon: Icons.link_rounded,
          title: dialogCtx.tr('Entrar por Link ou Código'),
          subtitle: dialogCtx.tr('Cole o convite compartilhado pelo líder do grupo'),
          maxWidth: 440,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Link ou código de convite')),
              TextField(
                key: const Key('join_group_code_field'),
                controller: codeCtrl,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('NOE-A1B2C3 ou https://noesis.asterdev.me/grupos/...'),
                  prefixIcon: Icons.vpn_key_outlined,
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmKey: const Key('join_group_confirm_button'),
            confirmLabel: dialogCtx.tr('Entrar no Grupo'),
            confirmIcon: Icons.login_rounded,
            onConfirm: () async {
              final res = await StudyGroupsService.instance.joinByInviteLinkOrCode(
                codeOrLink: codeCtrl.text,
              );
              if (!dialogCtx.mounted) return;
              if (res.ok && res.group != null) {
                Navigator.of(dialogCtx).pop();
                onJoined(res.group!.id);
                onFeedback(res.message ?? NoesisL10n.tr('Você entrou no grupo!'));
              } else {
                onFeedback(res.error ?? NoesisL10n.tr('Convite inválido.'), isError: true);
              }
            },
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 3. MODAL CONVIDAR PELO @USUARIO
// -----------------------------------------------------------------------------
Future<void> showInviteMemberModal(
  BuildContext context, {
  required StudyGroup group,
  required GroupFeedbackCallback onFeedback,
}) async {
  await SocialConnectionsService.instance.init();
  if (!context.mounted) return;
  final existingIds = group.members.map((m) => m.userId).toSet();
  final existingHandles = group.members.map((m) => m.username.toLowerCase()).toSet();

  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: const [''],
      builder: (dialogCtx, ctrls) {
        final userCtrl = ctrls[0];
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final social = SocialConnectionsService.instance;
            final suggestions = social.inviteSuggestionsForGroup(
              excludeUserIds: existingIds,
              excludeUsernames: existingHandles,
              query: userCtrl.text,
            );

            return NoesisGroupModalShell(
              icon: Icons.person_add_alt_1_rounded,
              title: dialogCtx.tr('Convidar para "{name}"', {'name': group.name}),
              subtitle: dialogCtx.tr('Escolha alguém das suas conexões ou digite o @usuario'),
              maxWidth: 480,
              maxHeight: 620,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _fieldLabel(dialogCtx, dialogCtx.tr('@usuario do colega')),
                  TextField(
                    key: const Key('invite_username_field'),
                    controller: userCtrl,
                    onChanged: (_) => setModalState(() {}),
                    decoration: noesisGroupInputDecoration(
                      dialogCtx,
                      hintText: dialogCtx.tr('nome_do_colega'),
                      prefixText: '@',
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _fieldLabel(dialogCtx, dialogCtx.tr('Sugestões rápidas')),
                    Column(
                      children: [
                        for (int idx = 0; idx < (suggestions.length > 6 ? 6 : suggestions.length); idx++) ...[
                          if (idx > 0) const SizedBox(height: 6),
                          Builder(
                            builder: (_) {
                              final p = suggestions[idx];
                              final isMutual = social.isMutualConnection(p.userId, username: p.username);
                              return Container(
                                key: Key('invite_suggestion_row_${p.userId}'),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AsterTheme.surfaceAlt(dialogCtx),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: isMutual
                                        ? AsterConstants.menta.withValues(alpha: 0.45)
                                        : AsterTheme.surfaceInset(dialogCtx),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    GroupMemberAvatar(
                                      displayName: p.displayName,
                                      avatarUrl: p.avatarUrl,
                                      isVip: p.isVip,
                                      radius: 15,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                p.displayName,
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AsterTheme.text(dialogCtx),
                                                ),
                                              ),
                                              if (isMutual)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: AsterConstants.menta.withValues(alpha: 0.14),
                                                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                  ),
                                                  child: Text(
                                                    dialogCtx.tr('Mútuo'),
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: AsterConstants.menta,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            '@${p.username}',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AsterTheme.textMuted(dialogCtx),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      key: Key('invite_quick_${p.userId}'),
                                      onPressed: () async {
                                        final res = await StudyGroupsService.instance.inviteMemberByUsername(
                                          groupId: group.id,
                                          username: p.username,
                                          displayNameHint: p.displayName,
                                        );
                                        if (!dialogCtx.mounted) return;
                                        if (res.ok) {
                                          Navigator.of(dialogCtx).pop();
                                          onFeedback(res.message ?? NoesisL10n.tr('Convite enviado!'));
                                        } else {
                                          onFeedback(res.error ?? NoesisL10n.tr('Erro ao convidar.'), isError: true);
                                        }
                                      },
                                      child: Text(
                                        dialogCtx.tr('Convidar'),
                                        style: GoogleFonts.manrope(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AsterTheme.primary(dialogCtx),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(dialogCtx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AsterTheme.surfaceInset(dialogCtx)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 17, color: AsterTheme.primary(dialogCtx)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.inviteLink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AsterTheme.text(dialogCtx),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: group.inviteLink));
                            onFeedback(NoesisL10n.tr('Link copiado ({code})!', {'code': group.inviteCode}));
                          },
                          child: Text(dialogCtx.tr('Copiar')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              footer: _modalFooterButtons(
                dialogCtx,
                confirmKey: const Key('invite_username_confirm_button'),
                confirmLabel: dialogCtx.tr('Convidar'),
                confirmIcon: Icons.send_rounded,
                cancelLabel: dialogCtx.tr('Fechar'),
                onConfirm: () async {
                  final res = await StudyGroupsService.instance.inviteMemberByUsername(
                    groupId: group.id,
                    username: userCtrl.text,
                  );
                  if (!dialogCtx.mounted) return;
                  if (res.ok) {
                    Navigator.of(dialogCtx).pop();
                    onFeedback(res.message ?? NoesisL10n.tr('Convite enviado!'));
                  } else {
                    onFeedback(res.error ?? NoesisL10n.tr('Erro ao convidar.'), isError: true);
                  }
                },
              ),
            );
          },
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 4. MODAL REGISTRAR NO DIÁRIO DO GRUPO
// -----------------------------------------------------------------------------
Future<void> showAddStudyLogModal(
  BuildContext context, {
  required StudyGroup group,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: [group.subject, '', '0', '30', ''],
      builder: (dialogCtx, ctrls) {
        final subjCtrl = ctrls[0];
        final topicCtrl = ctrls[1];
        final hrsCtrl = ctrls[2];
        final minsCtrl = ctrls[3];
        final notesCtrl = ctrls[4];
        int readTotalMins() {
          final h = int.tryParse(hrsCtrl.text.trim()) ?? 0;
          final m = int.tryParse(minsCtrl.text.trim()) ?? 0;
          return (h < 0 ? 0 : h) * 60 + (m < 0 ? 0 : m);
        }

        return NoesisGroupModalShell(
          icon: Icons.auto_stories_rounded,
          iconColor: AsterConstants.menta,
          title: dialogCtx.tr('Registrar no Diário do Grupo'),
          subtitle: dialogCtx.tr('Sessões contam tempo estudado e Insights para o ranking interno'),
          maxWidth: 470,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Matéria')),
              TextField(
                key: const Key('group_log_subject_field'),
                controller: subjCtrl,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Redes, Segurança, Direito...'),
                  prefixIcon: Icons.book_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel(dialogCtx, dialogCtx.tr('Tópico estudado')),
              TextField(
                key: const Key('group_log_topic_field'),
                controller: topicCtrl,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: VPC & Subnets, Criptografia assimétrica...'),
                  prefixIcon: Icons.topic_outlined,
                ),
              ),
              const SizedBox(height: 14),
              StatefulBuilder(
                builder: (ctx, setChips) {
                  final currentMins = readTotalMins();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel(
                        dialogCtx,
                        dialogCtx.tr('Duração ({duration})', {
                          'duration': DashboardAnalytics.formatReadableDuration(currentMins),
                        }),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('group_log_hours_field'),
                              controller: hrsCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setChips(() {}),
                              decoration: noesisGroupInputDecoration(
                                dialogCtx,
                                hintText: '0',
                                labelText: dialogCtx.tr('Horas'),
                                suffixText: dialogCtx.tr('h'),
                                prefixIcon: Icons.schedule_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              key: const Key('group_log_minutes_field'),
                              controller: minsCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setChips(() {}),
                              decoration: noesisGroupInputDecoration(
                                dialogCtx,
                                hintText: '30',
                                labelText: dialogCtx.tr('Minutos'),
                                suffixText: dialogCtx.tr('min'),
                                prefixIcon: Icons.timer_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [15, 30, 45, 60, 90, 120, 180].map((m) {
                          final selected = currentMins == m;
                          return SoftClayChoiceChip(
                            key: Key('group_log_duration_chip_$m'),
                            label: DashboardAnalytics.formatReadableDuration(m),
                            selected: selected,
                            compact: true,
                            onTap: () {
                              hrsCtrl.text = '${m ~/ 60}';
                              minsCtrl.text = '${m % 60}';
                              setChips(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _fieldLabel(dialogCtx, dialogCtx.tr('Observações (opcional)')),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Resumo rápido ou pontos de dúvida para o grupo'),
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmKey: const Key('group_log_save_button'),
            confirmLabel: dialogCtx.tr('Salvar Sessão'),
            confirmIcon: Icons.add_task_rounded,
            onConfirm: () async {
              final mins = readTotalMins();
              final res = await StudyGroupsService.instance.addStudyLogEntry(
                groupId: group.id,
                subject: subjCtrl.text,
                topic: topicCtrl.text,
                durationMinutes: mins,
                notes: notesCtrl.text,
              );
              if (!dialogCtx.mounted) return;
              if (res.ok) {
                Navigator.of(dialogCtx).pop();
                onFeedback(res.message ?? NoesisL10n.tr('Sessão registrada!'));
              } else {
                onFeedback(res.error ?? NoesisL10n.tr('Erro ao registrar.'), isError: true);
              }
            },
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 5. MODAL ANEXAR CONTEÚDO PESSOAL (PRIVADO POR CONTA)
// -----------------------------------------------------------------------------
Future<void> showAttachPersonalContentModal(
  BuildContext context, {
  required StudyGroup group,
  required StudyGroupContentKind kind,
  required GroupFeedbackCallback onFeedback,
}) async {
  final personal = await StudyGroupsService.instance.loadAttachablePersonalContent();
  if (!context.mounted) return;

  final (title, icon, emptyText) = switch (kind) {
    StudyGroupContentKind.notebook => (
        NoesisL10n.tr('Anexar Meu Caderno'),
        Icons.menu_book_rounded,
        NoesisL10n.tr('Você ainda não possui cadernos pessoais disponíveis para anexar.'),
      ),
    StudyGroupContentKind.deck => (
        NoesisL10n.tr('Anexar Meu Baralho'),
        Icons.style_rounded,
        NoesisL10n.tr('Você ainda não possui baralhos de flashcards disponíveis na sua conta.'),
      ),
    StudyGroupContentKind.exam => (
        NoesisL10n.tr('Anexar Meu Simulado'),
        Icons.assignment_rounded,
        NoesisL10n.tr('Você ainda não possui simulados salvos disponíveis para anexar.'),
      ),
    StudyGroupContentKind.roadmap => (
        NoesisL10n.tr('Anexar Minha Trilha'),
        Icons.route_rounded,
        NoesisL10n.tr('Você ainda não possui trilhas disponíveis na sua conta.'),
      ),
  };

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final List<Widget> items = [];

      Widget buildItemTile({
        required IconData itemIcon,
        required Color accent,
        required String itemTitle,
        required String itemSubtitle,
        required Future<StudyGroupActionResult> Function() onTap,
      }) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AsterTheme.surfaceAlt(dialogCtx),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final res = await onTap();
                if (!dialogCtx.mounted) return;
                Navigator.of(dialogCtx).pop();
                onFeedback(
                  res.ok ? (res.message ?? NoesisL10n.tr('Anexado!')) : (res.error ?? NoesisL10n.tr('Erro ao anexar.')),
                  isError: !res.ok,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(itemIcon, size: 18, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemTitle,
                            style: GoogleFonts.manrope(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(dialogCtx),
                            ),
                          ),
                          Text(
                            itemSubtitle,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: AsterTheme.textMuted(dialogCtx),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AsterTheme.primary(dialogCtx).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        dialogCtx.tr('Anexar'),
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.primary(dialogCtx),
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

      switch (kind) {
        case StudyGroupContentKind.notebook:
          for (final nb in personal.notebooks) {
            items.add(
              buildItemTile(
                itemIcon: Icons.menu_book_rounded,
                accent: AsterConstants.lavanda,
                itemTitle: nb.title,
                itemSubtitle: dialogCtx.tr(
                  '{subject} · {count} anotações',
                  {'subject': nb.subject, 'count': nb.notes.length},
                ),
                onTap: () => StudyGroupsService.instance.attachNotebook(
                  groupId: group.id,
                  notebook: nb,
                ),
              ),
            );
          }
        case StudyGroupContentKind.deck:
          for (final dk in personal.decks) {
            items.add(
              buildItemTile(
                itemIcon: Icons.style_rounded,
                accent: AsterConstants.menta,
                itemTitle: dk.title,
                itemSubtitle: dialogCtx.tr(
                  '{subject} · {count} cartões',
                  {'subject': dk.subject, 'count': dk.cards.length},
                ),
                onTap: () => StudyGroupsService.instance.attachDeck(
                  groupId: group.id,
                  deck: dk,
                ),
              ),
            );
          }
        case StudyGroupContentKind.exam:
          for (final ex in personal.exams) {
            items.add(
              buildItemTile(
                itemIcon: Icons.assignment_rounded,
                accent: AsterConstants.ambar,
                itemTitle: ex.title,
                itemSubtitle: dialogCtx.tr(
                  '{subject} · {count} questões',
                  {'subject': ex.subject, 'count': ex.questions.length},
                ),
                onTap: () => StudyGroupsService.instance.attachExam(
                  groupId: group.id,
                  exam: ex,
                ),
              ),
            );
          }
        case StudyGroupContentKind.roadmap:
          for (final rm in personal.roadmaps) {
            items.add(
              buildItemTile(
                itemIcon: Icons.route_rounded,
                accent: AsterTheme.primary(dialogCtx),
                itemTitle: rm.title,
                itemSubtitle: dialogCtx.tr(
                  '{subject} · {count} etapas',
                  {'subject': rm.subject, 'count': rm.steps.length},
                ),
                onTap: () => StudyGroupsService.instance.attachRoadmap(
                  groupId: group.id,
                  roadmap: rm,
                ),
              ),
            );
          }
      }

      return NoesisGroupModalShell(
        modalKey: const Key('group_attach_personal_dialog'),
        icon: icon,
        title: title,
        subtitle: dialogCtx.tr('Privacidade garantida: apenas você vê os itens da sua conta antes de anexar'),
        maxWidth: 520,
        maxHeight: 520,
        body: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(icon, size: 32, color: AsterTheme.textMuted(dialogCtx)),
                    const SizedBox(height: 10),
                    Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AsterTheme.textMuted(dialogCtx),
                      ),
                    ),
                  ],
                ),
              )
            : Column(mainAxisSize: MainAxisSize.min, children: items),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
              ),
              child: Text(dialogCtx.tr('Fechar')),
            ),
          ],
        ),
      );
    },
  );
}

// -----------------------------------------------------------------------------
// 6. MODAIS DE CRIAÇÃO DIRETA DENTRO DO GRUPO
// -----------------------------------------------------------------------------
Future<void> showCreateGroupNotebookModal(
  BuildContext context, {
  required StudyGroup group,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: ['', group.subject, '', ''],
      builder: (dialogCtx, ctrls) {
        return NoesisGroupModalShell(
          icon: Icons.menu_book_rounded,
          iconColor: AsterConstants.lavanda,
          title: dialogCtx.tr('Novo Caderno do Grupo'),
          subtitle: dialogCtx.tr('Criado diretamente para os membros estudarem e lerem aqui'),
          maxWidth: 540,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Título do caderno *')),
              TextField(
                key: const Key('group_create_nb_title_field'),
                controller: ctrls[0],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Resumo de Redes TCP/IP'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Matéria')),
              TextField(
                controller: ctrls[1],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Redes e Infraestrutura'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Título da 1ª anotação')),
              TextField(
                controller: ctrls[2],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Camadas OSI vs TCP/IP'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Conteúdo em Markdown')),
              TextField(
                key: const Key('group_create_nb_content_field'),
                controller: ctrls[3],
                maxLines: 5,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Use # títulos, **negrito**, listas ou ```blocos de código```'),
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmKey: const Key('group_create_nb_confirm_button'),
            confirmLabel: dialogCtx.tr('Criar Caderno'),
            onConfirm: () async {
              final res = await StudyGroupsService.instance.createGroupNotebook(
                groupId: group.id,
                title: ctrls[0].text,
                subject: ctrls[1].text,
                noteTitle: ctrls[2].text,
                noteContent: ctrls[3].text,
              );
              if (!dialogCtx.mounted) return;
              if (res.ok) {
                Navigator.of(dialogCtx).pop();
                onFeedback(res.message ?? NoesisL10n.tr('Caderno criado no grupo!'));
              } else {
                onFeedback(res.error ?? NoesisL10n.tr('Erro ao criar caderno.'), isError: true);
              }
            },
          ),
        );
      },
    ),
  );
}

Future<void> showCreateGroupDeckModal(
  BuildContext context, {
  required StudyGroup group,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: ['', group.subject, ''],
      builder: (dialogCtx, ctrls) {
        return NoesisGroupModalShell(
          icon: Icons.style_rounded,
          iconColor: AsterConstants.menta,
          title: dialogCtx.tr('Novo Baralho do Grupo'),
          subtitle: dialogCtx.tr('Adicione um flashcard por linha no formato Pergunta | Resposta'),
          maxWidth: 540,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Título do baralho *')),
              TextField(
                key: const Key('group_create_deck_title_field'),
                controller: ctrls[0],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Portas TCP Essenciais'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Matéria')),
              TextField(
                controller: ctrls[1],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Redes'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Cartões (Pergunta | Resposta por linha) *')),
              TextField(
                key: const Key('group_create_deck_cards_field'),
                controller: ctrls[2],
                maxLines: 5,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Porta HTTPS? | 443\nPorta SSH? | 22'),
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmKey: const Key('group_create_deck_confirm_button'),
            confirmLabel: dialogCtx.tr('Criar Baralho'),
            onConfirm: () async {
              final now = DateTime.now();
              final cards = <Flashcard>[];
              final lines = ctrls[2].text.split('\n');
              for (int i = 0; i < lines.length; i++) {
                final parts = lines[i].split('|');
                if (parts.length >= 2 &&
                    parts[0].trim().isNotEmpty &&
                    parts.sublist(1).join('|').trim().isNotEmpty) {
                  cards.add(
                    Flashcard(
                      id: 'gfc_${now.microsecondsSinceEpoch}_$i',
                      front: parts[0].trim(),
                      back: parts.sublist(1).join('|').trim(),
                    ),
                  );
                }
              }
              final res = await StudyGroupsService.instance.createGroupDeck(
                groupId: group.id,
                title: ctrls[0].text,
                subject: ctrls[1].text,
                cards: cards,
              );
              if (!dialogCtx.mounted) return;
              if (res.ok) {
                Navigator.of(dialogCtx).pop();
                onFeedback(res.message ?? NoesisL10n.tr('Baralho criado no grupo!'));
              } else {
                onFeedback(
                  res.error ?? NoesisL10n.tr('Informe ao menos uma linha Pergunta | Resposta.'),
                  isError: true,
                );
              }
            },
          ),
        );
      },
    ),
  );
}

Future<void> showCreateGroupExamModal(
  BuildContext context, {
  required StudyGroup group,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: ['', group.subject, '', '', ''],
      builder: (dialogCtx, ctrls) {
        return NoesisGroupModalShell(
          icon: Icons.assignment_rounded,
          iconColor: AsterConstants.ambar,
          title: dialogCtx.tr('Novo Simulado do Grupo'),
          subtitle: dialogCtx.tr('Crie uma questão rápida para o grupo resolver e pontuar aqui dentro'),
          maxWidth: 540,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Título do simulado *')),
              TextField(
                controller: ctrls[0],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Checkpoint Semanal de Cloud'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Matéria')),
              TextField(
                controller: ctrls[1],
                decoration: noesisGroupInputDecoration(dialogCtx, hintText: dialogCtx.tr('Ex.: Cloud')),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Enunciado da questão *')),
              TextField(
                controller: ctrls[2],
                maxLines: 2,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Digite a pergunta...'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Alternativa correta *')),
              TextField(
                controller: ctrls[3],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Resposta certa'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Outras alternativas (separadas por ;) *')),
              TextField(
                controller: ctrls[4],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Opção B; Opção C; Opção D'),
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmLabel: dialogCtx.tr('Criar Simulado'),
            onConfirm: () async {
              final prompt = ctrls[2].text.trim();
              final correct = ctrls[3].text.trim();
              final others = ctrls[4]
                  .text
                  .split(';')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (prompt.isEmpty || correct.isEmpty || others.isEmpty) {
                onFeedback(
                  NoesisL10n.tr('Preencha enunciado, resposta correta e alternativas.'),
                  isError: true,
                );
                return;
              }
              final res = await StudyGroupsService.instance.createGroupExam(
                groupId: group.id,
                title: ctrls[0].text,
                subject: ctrls[1].text,
                questions: [
                  {
                    'question': prompt,
                    'options': [correct, ...others],
                    'correct_index': 0,
                  },
                ],
              );
              if (!dialogCtx.mounted) return;
              if (res.ok) {
                Navigator.of(dialogCtx).pop();
                onFeedback(res.message ?? NoesisL10n.tr('Simulado criado no grupo!'));
              } else {
                onFeedback(res.error ?? NoesisL10n.tr('Erro ao criar simulado.'), isError: true);
              }
            },
          ),
        );
      },
    ),
  );
}

Future<void> showCreateGroupRoadmapModal(
  BuildContext context, {
  required StudyGroup group,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => GroupDialogControllersHost(
      initialTexts: ['', group.subject, '', ''],
      builder: (dialogCtx, ctrls) {
        return NoesisGroupModalShell(
          icon: Icons.route_rounded,
          title: dialogCtx.tr('Nova Trilha do Grupo'),
          subtitle: dialogCtx.tr('Defina as etapas para o grupo acompanhar e concluir em conjunto'),
          maxWidth: 520,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(dialogCtx, dialogCtx.tr('Título da trilha *')),
              TextField(
                controller: ctrls[0],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Rumo à Certificação AWS SAA'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Matéria')),
              TextField(
                controller: ctrls[1],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Arquitetura Cloud'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Objetivo')),
              TextField(
                controller: ctrls[2],
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('Ex.: Dominar redes, IAM e alta disponibilidade'),
                ),
              ),
              const SizedBox(height: 12),
              _fieldLabel(dialogCtx, dialogCtx.tr('Etapas (uma por linha) *')),
              TextField(
                controller: ctrls[3],
                maxLines: 4,
                decoration: noesisGroupInputDecoration(
                  dialogCtx,
                  hintText: dialogCtx.tr('1. Fundamentos de VPC\n2. Subnets e NAT Gateway\n3. IAM & Policies'),
                ),
              ),
            ],
          ),
          footer: _modalFooterButtons(
            dialogCtx,
            confirmLabel: dialogCtx.tr('Criar Trilha'),
            onConfirm: () async {
              final now = DateTime.now();
              final lines = ctrls[3]
                  .text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final steps = [
                for (int i = 0; i < lines.length; i++)
                  RoadmapStep(
                    id: 'gstep_${now.microsecondsSinceEpoch}_$i',
                    title: lines[i],
                  ),
              ];
              final res = await StudyGroupsService.instance.createGroupRoadmap(
                groupId: group.id,
                title: ctrls[0].text,
                subject: ctrls[1].text,
                goal: ctrls[2].text,
                steps: steps,
              );
              if (!dialogCtx.mounted) return;
              if (res.ok) {
                Navigator.of(dialogCtx).pop();
                onFeedback(res.message ?? NoesisL10n.tr('Trilha criada no grupo!'));
              } else {
                onFeedback(res.error ?? NoesisL10n.tr('Informe título e etapas.'), isError: true);
              }
            },
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 7. VISUALIZADOR & EDITOR DE CADERNO (MARKDOWN RENDERIZADO DENTRO DO GRUPO)
// -----------------------------------------------------------------------------
Future<void> showGroupNotebookModal(
  BuildContext context, {
  required StudyGroup group,
  required SharedGroupItem<StudyNotebook> item,
  required bool canEdit,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _GroupNotebookModal(
      groupId: group.id,
      initialItem: item,
      canEdit: canEdit,
      onFeedback: onFeedback,
    ),
  );
}

class _GroupNotebookModal extends StatefulWidget {
  final String groupId;
  final SharedGroupItem<StudyNotebook> initialItem;
  final bool canEdit;
  final GroupFeedbackCallback onFeedback;

  const _GroupNotebookModal({
    required this.groupId,
    required this.initialItem,
    required this.canEdit,
    required this.onFeedback,
  });

  @override
  State<_GroupNotebookModal> createState() => _GroupNotebookModalState();
}

class _GroupNotebookModalState extends State<_GroupNotebookModal> {
  int _selectedIndex = 0;
  bool _addingNote = false;
  final _noteTitleCtrl = TextEditingController();
  final _noteContentCtrl = TextEditingController();
  final Set<String> _completedNoteIds = {};

  @override
  void dispose() {
    _noteTitleCtrl.dispose();
    _noteContentCtrl.dispose();
    super.dispose();
  }

  SharedGroupItem<StudyNotebook> _currentItem() {
    final groups = StudyGroupsService.instance.groupsNotifier.value;
    for (final g in groups) {
      if (g.id == widget.groupId) {
        for (final nb in g.sharedNotebooks) {
          if (nb.shareId == widget.initialItem.shareId) return nb;
        }
      }
    }
    return widget.initialItem;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryCol = AsterTheme.primary(context);

    return ValueListenableBuilder<List<StudyGroup>>(
      valueListenable: StudyGroupsService.instance.groupsNotifier,
      builder: (context, _, _) {
        final item = _currentItem();
        final nb = item.data;
        final notes = nb.notes;
        final safeIdx = notes.isEmpty ? 0 : _selectedIndex.clamp(0, notes.length - 1);
        final currentNote = notes.isEmpty ? null : notes[safeIdx];

        return NoesisGroupModalShell(
          modalKey: const Key('group_notebook_modal'),
          icon: Icons.menu_book_rounded,
          iconColor: AsterConstants.lavanda,
          title: nb.title,
          subtitle: context.tr(
            '{subject} · {count} anotações · por @{handle}',
            {'subject': nb.subject, 'count': notes.length, 'handle': item.sharedByHandle},
          ),
          maxWidth: 780,
          maxHeight: 680,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < notes.length; i++)
                      SoftClayChoiceChip(
                        label: notes[i].title,
                        icon: Icons.description_outlined,
                        selected: safeIdx == i && !_addingNote,
                        compact: true,
                        onTap: () => setState(() {
                          _selectedIndex = i;
                          _addingNote = false;
                        }),
                      ),
                    if (widget.canEdit)
                      SoftClayChoiceChip(
                        label: context.tr('Nova anotação'),
                        icon: Icons.add_rounded,
                        selected: _addingNote,
                        accentColor: AsterConstants.menta,
                        compact: true,
                        onTap: () => setState(() => _addingNote = !_addingNote),
                      ),
                  ],
                ),
              if (notes.isEmpty && widget.canEdit && !_addingNote)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _addingNote = true),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(context.tr('Adicionar primeira anotação')),
                  ),
                ),
              const SizedBox(height: 14),
              if (_addingNote) ...[
                _fieldLabel(context, context.tr('Título da anotação *')),
                TextField(
                  controller: _noteTitleCtrl,
                  decoration: noesisGroupInputDecoration(
                    context,
                    hintText: context.tr('Ex.: Resumo de Roteamento'),
                  ),
                ),
                const SizedBox(height: 12),
                _fieldLabel(context, context.tr('Conteúdo (Markdown) *')),
                TextField(
                  controller: _noteContentCtrl,
                  maxLines: 6,
                  decoration: noesisGroupInputDecoration(
                    context,
                    hintText: context.tr('Escreva suas notas com # títulos, **destaque** ou ```código```'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _addingNote = false),
                      child: Text(context.tr('Cancelar')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final res = await StudyGroupsService.instance.addNoteToGroupNotebook(
                          groupId: widget.groupId,
                          shareId: item.shareId,
                          noteTitle: _noteTitleCtrl.text,
                          noteContent: _noteContentCtrl.text,
                        );
                        if (!mounted) return;
                        if (res.ok) {
                          _noteTitleCtrl.clear();
                          _noteContentCtrl.clear();
                          setState(() {
                            _addingNote = false;
                            _selectedIndex = notes.length;
                          });
                          widget.onFeedback(res.message ?? NoesisL10n.tr('Anotação adicionada!'));
                        } else {
                          widget.onFeedback(res.error ?? NoesisL10n.tr('Erro ao salvar.'), isError: true);
                        }
                      },
                      child: Text(context.tr('Salvar Anotação')),
                    ),
                  ],
                ),
              ] else if (currentNote == null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    context.tr('Este caderno ainda não possui anotações.'),
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AsterTheme.surfaceInset(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentNote.title,
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.text(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: AsterTheme.surfaceInset(context)),
                      const SizedBox(height: 14),
                      MarkdownBody(
                        data: currentNote.content.trim().isEmpty
                            ? context.tr('_Sem conteúdo._')
                            : currentNote.content,
                        selectable: true,
                        syntaxHighlighter: AsterCodeSyntaxHighlighter(isDark: isDark),
                        onTapLink: (_, href, _) async {
                          if (href == null) return;
                          final uri = Uri.tryParse(href);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: GoogleFonts.manrope(
                            fontSize: 14,
                            height: 1.65,
                            color: AsterTheme.text(context),
                          ),
                          h1: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                          h2: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                          h3: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                          strong: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(context),
                          ),
                          code: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: primaryCol,
                            backgroundColor: primaryCol.withValues(alpha: 0.12),
                          ),
                          codeblockPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          codeblockDecoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: primaryCol.withValues(alpha: 0.1),
                            border: BorderDirectional(
                              start: BorderSide(color: primaryCol, width: 4),
                            ),
                          ),
                          blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          listBullet: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryCol,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentNote != null && !_addingNote)
                ElevatedButton.icon(
                  key: Key('group_notebook_complete_btn_${currentNote.id}'),
                  onPressed: _completedNoteIds.contains(currentNote.id)
                      ? null
                      : () async {
                          final res = await StudyGroupsService.instance.recordGroupNotebookStudy(
                            groupId: widget.groupId,
                            shareId: item.shareId,
                            noteId: currentNote.id,
                            notebookTitle: nb.title,
                          );
                          if (!mounted) return;
                          setState(() => _completedNoteIds.add(currentNote.id));
                          if (res.message != null) widget.onFeedback(res.message!);
                        },
                  icon: Icon(
                    _completedNoteIds.contains(currentNote.id)
                        ? Icons.check_circle_rounded
                        : Icons.auto_awesome_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _completedNoteIds.contains(currentNote.id)
                        ? context.tr('Leitura concluída')
                        : context.tr('Concluir leitura (+3 Insights)'),
                    style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AsterConstants.menta,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                ),
                child: Text(context.tr('Fechar')),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 8. ESTUDO DE FLASHCARDS 100% DENTRO DO GRUPO
// -----------------------------------------------------------------------------
Future<void> showGroupDeckStudyModal(
  BuildContext context, {
  required StudyGroup group,
  required SharedGroupItem<FlashcardDeck> item,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _GroupDeckStudyDialog(
      groupId: group.id,
      item: item,
      onFeedback: onFeedback,
    ),
  );
}

class _GroupDeckStudyDialog extends StatefulWidget {
  final String groupId;
  final SharedGroupItem<FlashcardDeck> item;
  final GroupFeedbackCallback onFeedback;

  const _GroupDeckStudyDialog({
    required this.groupId,
    required this.item,
    required this.onFeedback,
  });

  @override
  State<_GroupDeckStudyDialog> createState() => _GroupDeckStudyDialogState();
}

class _GroupDeckStudyDialogState extends State<_GroupDeckStudyDialog> {
  int _index = 0;
  bool _flipped = false;
  bool _finished = false;
  int _sessionInsights = 0;

  Future<void> _rateCard(String quality) async {
    final cards = widget.item.data.cards;
    if (_index >= cards.length) return;
    final card = cards[_index];
    final res = await StudyGroupsService.instance.recordGroupFlashcardReview(
      groupId: widget.groupId,
      shareId: widget.item.shareId,
      cardId: card.id,
      deckTitle: widget.item.data.title,
      quality: quality,
    );
    if (!mounted) return;
    setState(() {
      _sessionInsights += res.earnedInsights;
      if (_index + 1 >= cards.length) {
        _finished = true;
      } else {
        _index++;
        _flipped = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.item.data;
    final cards = deck.cards;
    final primaryCol = AsterTheme.primary(context);

    return NoesisGroupModalShell(
      modalKey: const Key('group_deck_study_modal'),
      icon: Icons.style_rounded,
      iconColor: AsterConstants.menta,
      title: deck.title,
      subtitle: context.tr('{subject} · Estudando dentro do grupo', {'subject': deck.subject}),
      maxWidth: 580,
      maxHeight: 580,
      body: cards.isEmpty
          ? Text(
              context.tr('Este baralho ainda não possui cartões.'),
              style: GoogleFonts.manrope(color: AsterTheme.textMuted(context)),
            )
          : _finished
              ? Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AsterConstants.menta.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        size: 30,
                        color: AsterConstants.menta,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('Sessão concluída no grupo!'),
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const InsightCoinIcon(size: 16),
                        const SizedBox(width: 6),
                        Text(
                          context.tr(
                            '+{insights} Insights somados ao ranking do grupo',
                            {'insights': _sessionInsights},
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _index = 0;
                        _flipped = false;
                        _finished = false;
                      }),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: Text(context.tr('Estudar novamente')),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('Cartão {current} de {total}', {'current': _index + 1, 'total': cards.length}),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryCol,
                          ),
                        ),
                        Row(
                          children: [
                            const InsightCoinIcon(size: 14),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('+{insights} no grupo', {'insights': _sessionInsights}),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_index + 1) / cards.length,
                        minHeight: 6,
                        backgroundColor: AsterTheme.surfaceAlt(context),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryCol),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      key: const Key('group_flashcard_flip_area'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _flipped = !_flipped),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(minHeight: 190),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _flipped
                              ? primaryCol.withValues(alpha: 0.08)
                              : AsterTheme.surfaceAlt(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _flipped
                                ? primaryCol.withValues(alpha: 0.45)
                                : AsterTheme.surfaceInset(context),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _flipped ? context.tr('RESPOSTA') : context.tr('PERGUNTA'),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: primaryCol,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _flipped ? cards[_index].back : cards[_index].front,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.45,
                                color: AsterTheme.text(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_flipped)
                      ElevatedButton.icon(
                        key: const Key('group_flashcard_reveal_button'),
                        onPressed: () => setState(() => _flipped = true),
                        icon: const Icon(Icons.flip_rounded, size: 18),
                        label: Text(context.tr('Mostrar Resposta')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryCol,
                          foregroundColor: AsterTheme.onPrimary(context),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _rateButton(context.tr('Errei'), AsterConstants.coral, () => _rateCard('again'), key: const Key('group_fc_rate_again')),
                          _rateButton(context.tr('Difícil (+1)'), AsterConstants.ambar, () => _rateCard('hard'), key: const Key('group_fc_rate_hard')),
                          _rateButton(context.tr('Bom (+2)'), primaryCol, () => _rateCard('good'), key: const Key('group_fc_rate_good')),
                          _rateButton(context.tr('Fácil (+2)'), AsterConstants.menta, () => _rateCard('easy'), key: const Key('group_fc_rate_easy')),
                        ],
                      ),
                  ],
                ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
            ),
            child: Text(context.tr('Sair para o Grupo')),
          ),
        ],
      ),
    );
  }

  Widget _rateButton(
    String label,
    Color color,
    VoidCallback onTap, {
    Key? key,
  }) {
    return ElevatedButton(
      key: key,
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 9. SIMULADO INTERATIVO 100% DENTRO DO GRUPO
// -----------------------------------------------------------------------------
Future<void> showGroupExamRunnerModal(
  BuildContext context, {
  required StudyGroup group,
  required SharedGroupItem<SavedExamAttempt> item,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _GroupExamRunnerDialog(
      groupId: group.id,
      item: item,
      onFeedback: onFeedback,
    ),
  );
}

class _GroupExamRunnerDialog extends StatefulWidget {
  final String groupId;
  final SharedGroupItem<SavedExamAttempt> item;
  final GroupFeedbackCallback onFeedback;

  const _GroupExamRunnerDialog({
    required this.groupId,
    required this.item,
    required this.onFeedback,
  });

  @override
  State<_GroupExamRunnerDialog> createState() => _GroupExamRunnerDialogState();
}

class _GroupExamRunnerDialogState extends State<_GroupExamRunnerDialog> {
  int _index = 0;
  int? _selectedOption;
  bool _confirmed = false;
  bool _finished = false;
  int _correctCount = 0;
  int _sessionInsights = 0;
  DateTime _shownAt = ShopService.currentNow();

  Future<void> _confirmAnswer() async {
    final q = widget.item.data.questions[_index];
    final correctIdx = (q['correct_index'] as num?)?.toInt() ?? 0;
    final isCorrect = _selectedOption == correctIdx;
    final elapsed = ShopService.currentNow().difference(_shownAt);

    final res = await StudyGroupsService.instance.recordGroupExamQuestionAnswer(
      groupId: widget.groupId,
      shareId: widget.item.shareId,
      examTitle: widget.item.data.title,
      questionIndex: _index,
      isCorrect: isCorrect,
      elapsedSinceShown: elapsed.inSeconds >= 3 ? elapsed : null,
    );
    if (!mounted) return;
    setState(() {
      _confirmed = true;
      if (isCorrect) _correctCount++;
      _sessionInsights += res.earnedInsights;
    });
  }

  Future<void> _nextQuestion() async {
    final total = widget.item.data.questions.length;
    if (_index + 1 < total) {
      setState(() {
        _index++;
        _selectedOption = null;
        _confirmed = false;
        _shownAt = ShopService.currentNow();
      });
      return;
    }

    final pct = total == 0 ? 0.0 : (_correctCount / total) * 100.0;
    final comp = await StudyGroupsService.instance.recordGroupExamCompletion(
      groupId: widget.groupId,
      shareId: widget.item.shareId,
      examTitle: widget.item.data.title,
      scorePercentage: pct,
    );
    if (!mounted) return;
    setState(() {
      _finished = true;
      _sessionInsights += comp.earnedInsights;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.item.data;
    final questions = exam.questions;
    final primaryCol = AsterTheme.primary(context);

    return NoesisGroupModalShell(
      modalKey: const Key('group_exam_runner_modal'),
      icon: Icons.assignment_rounded,
      iconColor: AsterConstants.ambar,
      title: exam.title,
      subtitle: context.tr('{subject} · Resolvendo dentro do grupo', {'subject': exam.subject}),
      maxWidth: 660,
      maxHeight: 640,
      body: questions.isEmpty
          ? Text(context.tr('Este simulado não possui questões.'))
          : _finished
              ? Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded, size: 48, color: AsterConstants.ambar),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('Simulado Finalizado!'),
                      style: GoogleFonts.manrope(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AsterTheme.text(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Acertos: {correct} de {total} ({pct}%)',
                        {
                          'correct': _correctCount,
                          'total': questions.length,
                          'pct': ((_correctCount / questions.length) * 100).round(),
                        },
                      ),
                      style: GoogleFonts.manrope(fontSize: 14, color: AsterTheme.textMuted(context)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const InsightCoinIcon(size: 16),
                        const SizedBox(width: 6),
                        Text(
                          context.tr(
                            '+{insights} Insights somados ao ranking do grupo',
                            {'insights': _sessionInsights},
                          ),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: primaryCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _index = 0;
                        _selectedOption = null;
                        _confirmed = false;
                        _finished = false;
                        _correctCount = 0;
                        _sessionInsights = 0;
                        _shownAt = ShopService.currentNow();
                      }),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: Text(context.tr('Refazer no Grupo')),
                    ),
                  ],
                )
              : Builder(
                  builder: (context) {
                    final q = questions[_index];
                    final opts = ((q['options'] as List?) ?? const [])
                        .map((e) => e.toString())
                        .toList();
                    final correctIdx = (q['correct_index'] as num?)?.toInt() ?? 0;
                    final explanation = (q['explanation'] ?? '').toString().trim();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr(
                                'Questão {current} de {total}',
                                {'current': _index + 1, 'total': questions.length},
                              ),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: primaryCol,
                              ),
                            ),
                            Text(
                              context.tr('+{insights} Insights no grupo', {'insights': _sessionInsights}),
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (q['question'] ?? q['statement'] ?? '').toString(),
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: AsterTheme.text(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (int i = 0; i < opts.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              key: Key('group_exam_option_$i'),
                              borderRadius: BorderRadius.circular(14),
                              onTap: _confirmed ? null : () => setState(() => _selectedOption = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _confirmed
                                      ? (i == correctIdx
                                          ? AsterConstants.menta.withValues(alpha: 0.16)
                                          : (i == _selectedOption
                                              ? AsterConstants.coral.withValues(alpha: 0.16)
                                              : AsterTheme.surfaceAlt(context)))
                                      : (_selectedOption == i
                                          ? primaryCol.withValues(alpha: 0.14)
                                          : AsterTheme.surfaceAlt(context)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _confirmed
                                        ? (i == correctIdx
                                            ? AsterConstants.menta
                                            : (i == _selectedOption
                                                ? AsterConstants.coral
                                                : AsterTheme.surfaceInset(context)))
                                        : (_selectedOption == i
                                            ? primaryCol
                                            : AsterTheme.surfaceInset(context)),
                                  ),
                                ),
                                child: Text(
                                  '${String.fromCharCode(65 + i)}) ${opts[i]}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AsterTheme.text(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_confirmed && explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryCol.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              explanation,
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                color: AsterTheme.text(context),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
            ),
            child: Text(context.tr('Fechar')),
          ),
          if (!_finished && questions.isNotEmpty) ...[
            const SizedBox(width: 10),
            ElevatedButton(
              key: Key(_confirmed ? 'group_exam_next_btn' : 'group_exam_confirm_btn'),
              onPressed: _selectedOption == null
                  ? null
                  : (_confirmed ? _nextQuestion : _confirmAnswer),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryCol,
                foregroundColor: AsterTheme.onPrimary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
              ),
              child: Text(
                _confirmed
                    ? (_index + 1 >= questions.length
                        ? context.tr('Finalizar')
                        : context.tr('Próxima'))
                    : context.tr('Confirmar Resposta'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 10. TRILHA INTERATIVA 100% DENTRO DO GRUPO
// -----------------------------------------------------------------------------
Future<void> showGroupRoadmapModal(
  BuildContext context, {
  required StudyGroup group,
  required SharedGroupItem<StudyRoadmap> item,
  required GroupFeedbackCallback onFeedback,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => ValueListenableBuilder<List<StudyGroup>>(
      valueListenable: StudyGroupsService.instance.groupsNotifier,
      builder: (dialogCtx, groups, _) {
        SharedGroupItem<StudyRoadmap> liveItem = item;
        for (final g in groups) {
          if (g.id == group.id) {
            for (final rm in g.sharedRoadmaps) {
              if (rm.shareId == item.shareId) liveItem = rm;
            }
          }
        }
        final rm = liveItem.data;
        final primaryCol = AsterTheme.primary(dialogCtx);

        return NoesisGroupModalShell(
          modalKey: const Key('group_roadmap_modal'),
          icon: Icons.route_rounded,
          title: rm.title,
          subtitle: dialogCtx.tr(
            '{subject} · {percent}% concluída no grupo',
            {'subject': rm.subject, 'percent': (rm.progress * 100).round()},
          ),
          maxWidth: 620,
          maxHeight: 620,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: rm.progress,
                  minHeight: 7,
                  backgroundColor: AsterTheme.surfaceAlt(dialogCtx),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryCol),
                ),
              ),
              const SizedBox(height: 14),
              if (rm.goal.isNotEmpty) ...[
                Text(
                  rm.goal,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: AsterTheme.textMuted(dialogCtx),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              for (final step in rm.steps) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(dialogCtx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: step.status == RoadmapStepStatus.done
                            ? AsterConstants.menta.withValues(alpha: 0.45)
                            : AsterTheme.surfaceInset(dialogCtx),
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          key: Key('group_roadmap_toggle_${step.id}'),
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final next = step.status == RoadmapStepStatus.done
                                ? RoadmapStepStatus.todo
                                : RoadmapStepStatus.done;
                            final res = await StudyGroupsService.instance.toggleGroupRoadmapStep(
                              groupId: group.id,
                              shareId: liveItem.shareId,
                              stepId: step.id,
                              nextStatus: next,
                            );
                            if (res.message != null) onFeedback(res.message!);
                          },
                          child: Icon(
                            step.status == RoadmapStepStatus.done
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: step.status == RoadmapStepStatus.done
                                ? AsterConstants.menta
                                : AsterTheme.textMuted(dialogCtx),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AsterTheme.text(dialogCtx),
                                ),
                              ),
                              if (step.description.isNotEmpty)
                                Text(
                                  step.description,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AsterTheme.textMuted(dialogCtx),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          step.status.localizedLabel,
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: step.status == RoadmapStepStatus.done
                                ? AsterConstants.menta
                                : AsterTheme.textMuted(dialogCtx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  ),
                ),
                child: Text(dialogCtx.tr('Fechar')),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// -----------------------------------------------------------------------------
// 11. AVATAR & MODAL DE PERFIL DO MEMBRO DENTRO DO GRUPO
// -----------------------------------------------------------------------------
String _initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first.replaceAll('@', '');
    if (s.isEmpty) return '?';
    return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class GroupMemberAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final bool isVip;
  final double radius;
  final bool showVipBadge;
  final VoidCallback? onTap;
  final Key? avatarKey;

  const GroupMemberAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isVip = false,
    this.radius = 18,
    this.showVipBadge = false,
    this.onTap,
    this.avatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final primaryCol = AsterTheme.primary(context);
    final provider = buildAvatarImageProvider(avatarUrl);
    final initials = _initialsForName(displayName);

    final circle = VipAvatarCircle(
      isVip: isVip,
      showBadge: showVipBadge,
      badgeSize: VipBadgeSize.xs,
      fallbackBorderColor: AsterTheme.surfaceInset(context),
      borderWidth: isVip ? 2.0 : 1.0,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: primaryCol.withValues(alpha: 0.14),
        backgroundImage: provider,
        onBackgroundImageError: provider != null ? (_, _) {} : null,
        child: provider == null
            ? Text(
                initials,
                style: GoogleFonts.manrope(
                  fontSize: radius * 0.68,
                  fontWeight: FontWeight.w800,
                  color: primaryCol,
                ),
              )
            : null,
      ),
    );

    if (onTap == null) {
      return avatarKey != null ? KeyedSubtree(key: avatarKey, child: circle) : circle;
    }
    return Tooltip(
      message: context.tr('Ver perfil de {name}', {'name': displayName}),
      child: InkWell(
        key: avatarKey,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: circle,
      ),
    );
  }
}

Future<void> showGroupMemberProfileModal(
  BuildContext context, {
  required StudyGroup group,
  StudyGroupMember? member,
  String? userId,
  String? fallbackName,
  String? fallbackUsername,
  String? fallbackAvatarUrl,
  bool fallbackIsVip = false,
}) async {
  final resolvedMember = member ?? (userId != null ? group.memberFor(userId) : null);
  final uid = resolvedMember?.userId ?? userId ?? '';
  final displayName = resolvedMember?.displayName ?? fallbackName ?? NoesisL10n.tr('Estudante');
  final handle = resolvedMember?.username ?? fallbackUsername ?? NoesisL10n.tr('estudante');
  final avatarUrl = resolvedMember?.avatarUrl ?? fallbackAvatarUrl;
  final isVip = resolvedMember?.isVip ?? fallbackIsVip;
  final isLeader = resolvedMember?.isLeader ?? (uid == group.leaderId);
  final bio = (resolvedMember?.bio ?? '').trim();
  final groupInsights = resolvedMember?.insightsScore ?? 0;
  final groupMinutes = resolvedMember?.weeklyMinutes ?? 0;
  final canInvite = resolvedMember != null ? group.canUserInvite(resolvedMember.userId) : false;
  final canEdit = resolvedMember != null ? group.canUserEdit(resolvedMember.userId) : false;
  final joinedAt = resolvedMember?.joinedAt;

  final chatCount = group.chatMessages.where((m) => m.userId == uid).length;
  final sharedCount = group.sharedNotebooks.where((e) => e.sharedByUserId == uid).length +
      group.sharedDecks.where((e) => e.sharedByUserId == uid).length +
      group.sharedExams.where((e) => e.sharedByUserId == uid).length +
      group.sharedRoadmaps.where((e) => e.sharedByUserId == uid).length;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final primaryCol = AsterTheme.primary(dialogCtx);
      final mutedCol = AsterTheme.textMuted(dialogCtx);

      Widget statBox(String label, Widget valueWidget) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AsterTheme.surfaceAlt(dialogCtx),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AsterTheme.surfaceInset(dialogCtx)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: mutedCol,
                ),
              ),
              const SizedBox(height: 5),
              valueWidget,
            ],
          ),
        );
      }

      Widget permPill(IconData icon, String label, bool active) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? primaryCol.withValues(alpha: 0.12) : AsterTheme.surfaceAlt(dialogCtx),
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            border: Border.all(
              color: active ? primaryCol.withValues(alpha: 0.38) : AsterTheme.surfaceInset(dialogCtx),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: active ? primaryCol : mutedCol),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? primaryCol : mutedCol,
                ),
              ),
            ],
          ),
        );
      }

      final joinedLabel = joinedAt != null
          ? '${joinedAt.day.toString().padLeft(2, '0')}/${joinedAt.month.toString().padLeft(2, '0')}/${joinedAt.year}'
          : null;

      return NoesisGroupModalShell(
        modalKey: const Key('group_member_profile_modal'),
        icon: Icons.badge_rounded,
        title: dialogCtx.tr('Perfil do Membro'),
        subtitle: '@$handle · ${group.name}',
        maxWidth: 480,
        maxHeight: 600,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do membro com avatar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(dialogCtx),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AsterTheme.surfaceInset(dialogCtx)),
              ),
              child: Row(
                children: [
                  GroupMemberAvatar(
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    isVip: isVip,
                    showVipBadge: isVip,
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.manrope(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.text(dialogCtx),
                              ),
                            ),
                            if (isVip) const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$handle',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: primaryCol,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isLeader
                                    ? AsterVipColors.gold.withValues(alpha: 0.16)
                                    : AsterTheme.card(dialogCtx),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Text(
                                isLeader
                                    ? dialogCtx.tr('Criador / Líder')
                                    : dialogCtx.tr('Membro'),
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isLeader ? AsterVipColors.goldDark : mutedCol,
                                ),
                              ),
                            ),
                            if (joinedLabel != null)
                              Text(
                                dialogCtx.tr('No grupo desde {date}', {'date': joinedLabel}),
                                style: GoogleFonts.manrope(fontSize: 10.5, color: mutedCol),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bio
            _fieldLabel(dialogCtx, dialogCtx.tr('Sobre')),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(dialogCtx),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AsterTheme.surfaceInset(dialogCtx)),
              ),
              child: Text(
                bio.isNotEmpty ? bio : dialogCtx.tr('Nenhuma bio informada pelo estudante.'),
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  height: 1.45,
                  fontStyle: bio.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  color: bio.isNotEmpty ? AsterTheme.text(dialogCtx) : mutedCol,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estatísticas dentro deste grupo
            _fieldLabel(dialogCtx, dialogCtx.tr('Atividade neste grupo')),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: w,
                      child: statBox(
                        dialogCtx.tr('Insights no grupo'),
                        Row(
                          children: [
                            const InsightCoinIcon(size: 14),
                            const SizedBox(width: 5),
                            Text(
                              '$groupInsights',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.text(dialogCtx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: statBox(
                        dialogCtx.tr('Tempo no diário'),
                        Text(
                          DashboardAnalytics.formatReadableDuration(groupMinutes),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(dialogCtx),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: statBox(
                        dialogCtx.tr('Mensagens no chat'),
                        Text(
                          '$chatCount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(dialogCtx),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: statBox(
                        dialogCtx.tr('Itens anexados'),
                        Text(
                          '$sharedCount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.text(dialogCtx),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Permissões
            _fieldLabel(dialogCtx, dialogCtx.tr('Permissões no grupo')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                permPill(
                  Icons.person_add_alt_1_rounded,
                  canInvite ? dialogCtx.tr('Pode convidar') : dialogCtx.tr('Não convida'),
                  canInvite,
                ),
                permPill(
                  Icons.edit_note_rounded,
                  canEdit ? dialogCtx.tr('Pode editar e anexar') : dialogCtx.tr('Apenas estuda'),
                  canEdit,
                ),
              ],
            ),
          ],
        ),
        footer: ValueListenableBuilder<SocialGraphState>(
          valueListenable: SocialConnectionsService.instance.stateNotifier,
          builder: (footerCtx, _, _) {
            final targetUid = (userId ?? '').trim().isNotEmpty ? userId! : 'handle_$handle';
            final isSelf = targetUid == StudyGroupsService.currentUserId;
            final social = SocialConnectionsService.instance;
            final isFollowing = !isSelf && social.isFollowing(targetUid, username: handle);
            final targetProfile = social.findByUserOrHandle(userId: targetUid, username: handle) ??
                PublicUserProfile(
                  userId: targetUid,
                  username: handle,
                  displayName: displayName,
                  avatarUrl: avatarUrl,
                  bio: bio,
                  isVip: isVip,
                );

            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isSelf) ...[
                  SoftClayPillButton(
                    key: const Key('member_profile_follow_button'),
                    text: isFollowing ? footerCtx.tr('Seguindo') : footerCtx.tr('Seguir'),
                    icon: isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                    isSecondary: isFollowing,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    fontSize: 12,
                    onPressed: () => social.toggleFollow(targetProfile),
                  ),
                  const SizedBox(width: 10),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                  ),
                  child: Text(footerCtx.tr('Fechar')),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
