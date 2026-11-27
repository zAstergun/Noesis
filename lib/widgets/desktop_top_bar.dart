import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/desktop_window_service.dart';
import '../core/localization/noesis_l10n.dart';
import '../core/notifications_service.dart';
import '../core/shop_service.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';
import 'noesis_logo.dart';
import 'vip_privileges.dart';

/// Cor da moldura externa (barra superior + barra lateral + enquadramento da página).
Color noesisDesktopShellColor(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return Color.lerp(
    theme.scaffoldBackgroundColor,
    theme.cardColor,
    isDark ? 0.16 : 0.48,
  )!;
}

/// Barra superior nativa integrada do Noesis (identidade Aster Soft Clay):
/// alternador de barra lateral à esquerda, área arrastável ao centro,
/// seletor de tema com prévia ao vivo, notificações e controles de janela à direita.
class DesktopTopBar extends StatefulWidget {
  const DesktopTopBar({
    super.key,
    this.showWorkspaceControls = true,
    this.isSidebarCollapsed = false,
    this.isSettingsActive = false,
    this.onToggleSidebar,
    this.onOpenShop,
    this.onOpenNotifications,
    this.onOpenSettings,
    this.leadingTitle,
  });

  final bool showWorkspaceControls;
  final bool isSidebarCollapsed;
  final bool isSettingsActive;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onOpenShop;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenSettings;
  final Widget? leadingTitle;

  static const double height = 46.0;

  @override
  State<DesktopTopBar> createState() => _DesktopTopBarState();
}

class _DesktopTopBarState extends State<DesktopTopBar> {
  @override
  void initState() {
    super.initState();
    DesktopWindowService.ensureInitialized();
  }

  void _showThemePickerPopover(BuildContext context) {
    final parentContext = context;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned(
              top: DesktopTopBar.height + 6,
              right: DesktopWindowService.isCustomFrameSupported ? 188 : 88,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 336,
                    maxHeight: 470,
                  ),
                  child: _ThemePickerPopover(
                    onClose: () => Navigator.of(dialogContext).pop(),
                    onOpenShop: widget.onOpenShop,
                    parentContext: parentContext,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AsterTheme.primary(context);
    final iconColor = AsterTheme.text(context).withValues(alpha: 0.84);
    final showWindowButtons = DesktopWindowService.isCustomFrameSupported;
    final pillSurface = AsterTheme.card(context).withValues(
      alpha: isDark ? 0.72 : 0.86,
    );
    final pillBorder = AsterTheme.surfaceInset(context).withValues(
      alpha: isDark ? 0.65 : 0.9,
    );

    return Container(
      height: DesktopTopBar.height,
      padding: EdgeInsetsDirectional.only(
        start: 12,
        end: showWindowButtons ? 8 : 12,
      ),
      child: Row(
        children: [
          if (widget.showWorkspaceControls) ...[
            ValueListenableBuilder<bool>(
              valueListenable: SupabaseService.isVipNotifier,
              builder: (context, isVip, _) {
                return Tooltip(
                  message: widget.isSidebarCollapsed
                      ? context.tr('Expandir barra lateral')
                      : context.tr('Minimizar barra lateral'),
                  waitDuration: const Duration(milliseconds: 450),
                  child: NoesisInteractiveBrand(
                    key: const Key('top_bar_sidebar_toggle'),
                    logoSize: 26,
                    fontSize: 16.5,
                    spacing: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    onTap: widget.onToggleSidebar,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isVip) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AsterVipColors.gold.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'VIP',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AsterVipColors.gold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        AnimatedRotation(
                          turns: widget.isSidebarCollapsed ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 16,
                            color: AsterTheme.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else if (widget.leadingTitle != null) ...[
            widget.leadingTitle!,
          ],

          // Área arrastável da barra de título (suporta duplo clique para maximizar)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => DesktopWindowService.startDrag(),
              onDoubleTap: () => DesktopWindowService.toggleMaximize(),
              child: const SizedBox.expand(),
            ),
          ),

          if (widget.showWorkspaceControls) ...[
            _NoesisTopPillButton(
              key: const Key('top_bar_theme_toggle'),
              tooltip: context.tr('Selecionar tema'),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              onTap: () => _showThemePickerPopover(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primary,
                          AsterTheme.secondary(context),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.palette_rounded,
                    size: 15.5,
                    color: iconColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<List<NoesisNotification>>(
              valueListenable: NotificationsService.instance.notificationsNotifier,
              builder: (context, notifications, _) {
                final unread = notifications.where((n) => !n.isRead).length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _NoesisTopPillButton(
                      key: const Key('notifications_bell_button'),
                      tooltip: context.tr('Notificações'),
                      width: 34,
                      onTap: widget.onOpenNotifications,
                      child: Icon(
                        unread > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_rounded,
                        size: 16.5,
                        color: unread > 0 ? primary : iconColor,
                      ),
                    ),
                    if (unread > 0)
                      PositionedDirectional(
                        key: const Key('notifications_unread_dot'),
                        top: -1,
                        end: -1,
                        child: IgnorePointer(
                          child: Container(
                            width: 8.5,
                            height: 8.5,
                            decoration: BoxDecoration(
                              color: AsterConstants.coral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: noesisDesktopShellColor(context),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 6),
            _NoesisTopPillButton(
              key: const Key('top_bar_settings_button'),
              tooltip: context.tr('Configurações'),
              width: 34,
              isActive: widget.isSettingsActive,
              onTap: widget.onOpenSettings,
              child: Icon(
                Icons.settings_rounded,
                size: 16.5,
                color: widget.isSettingsActive ? primary : iconColor,
              ),
            ),
          ],

          if (showWindowButtons) ...[
            if (widget.showWorkspaceControls) const SizedBox(width: 8),
            Container(
              height: 30,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: pillSurface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: pillBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WindowControlButton(
                    key: const Key('window_minimize_button'),
                    tooltip: context.tr('Minimizar'),
                    onTap: DesktopWindowService.minimize,
                    glyphType: _WindowGlyphType.minimize,
                  ),
                  const SizedBox(width: 2),
                  ValueListenableBuilder<bool>(
                    valueListenable: DesktopWindowService.isMaximizedNotifier,
                    builder: (context, isMaximized, _) {
                      return _WindowControlButton(
                        key: const Key('window_maximize_button'),
                        tooltip: isMaximized
                            ? context.tr('Restaurar')
                            : context.tr('Maximizar'),
                        onTap: DesktopWindowService.toggleMaximize,
                        glyphType: isMaximized
                            ? _WindowGlyphType.restore
                            : _WindowGlyphType.maximize,
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  _WindowControlButton(
                    key: const Key('window_close_button'),
                    tooltip: context.tr('Fechar'),
                    isClose: true,
                    onTap: DesktopWindowService.close,
                    glyphType: _WindowGlyphType.close,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemePickerPopover extends StatelessWidget {
  const _ThemePickerPopover({
    required this.onClose,
    required this.parentContext,
    this.onOpenShop,
  });

  final VoidCallback onClose;
  final BuildContext parentContext;
  final VoidCallback? onOpenShop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AsterTheme.card(context);
    final borderCol = AsterTheme.surfaceInset(context).withValues(
      alpha: isDark ? 0.78 : 0.9,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          AsterTheme.activeThemeIdNotifier,
          AsterTheme.customThemeColorsNotifier,
          SupabaseService.isVipNotifier,
          ShopService.instance.unlockedThemesNotifier,
        ]),
        builder: (context, _) {
          final activeId = AsterTheme.activeThemeIdNotifier.value;
          final isVip = SupabaseService.isCurrentUserVip;
          final allThemes = AsterTheme.availableThemesWithCustom;
          final themes = [
            ...allThemes.where((t) => ShopService.instance.isThemeUnlocked(t.id)),
            ...allThemes.where((t) => !ShopService.instance.isThemeUnlocked(t.id)),
          ];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_rounded,
                      size: 17,
                      color: AsterTheme.primary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('Selecionar tema'),
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.text(context),
                        ),
                      ),
                    ),
                    Text(
                      '${themes.where((t) => ShopService.instance.isThemeUnlocked(t.id)).length}/${themes.length}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: borderCol),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: themes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final option = themes[index];
                    final isSelected = activeId == option.id;
                    final isCustom = option.id == AsterTheme.customThemeId;
                    final isUnlocked = ShopService.instance.isThemeUnlocked(option.id);
                    final isLockedVip = isCustom && !isVip;
                    final isLockedShop = !isCustom && !isUnlocked;
                    final price = isLockedShop
                        ? ShopService.instance.priceForTheme(option.id)
                        : 0;

                    return InkWell(
                      key: Key('theme_picker_item_${option.id}'),
                      borderRadius: BorderRadius.circular(11),
                      onTap: () {
                        if (isLockedVip) {
                          onClose();
                          showVipPrivilegesModal(parentContext);
                          return;
                        }
                        if (isLockedShop) {
                          onClose();
                          ScaffoldMessenger.of(parentContext)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                persist: false,
                                duration: const Duration(seconds: 3),
                                content: Text(
                                  context.tr(
                                    'Desbloqueie o tema {name} na Loja por {price} {symbol} {currency}.',
                                    {
                                      'name': option.localizedName,
                                      'price': '$price',
                                      'symbol': ShopService.currencySymbol,
                                      'currency': ShopService.currencyName,
                                    },
                                  ),
                                ),
                                action: onOpenShop != null
                                    ? SnackBarAction(
                                        label: context.tr('Abrir Loja'),
                                        onPressed: onOpenShop!,
                                      )
                                    : null,
                              ),
                            );
                          return;
                        }
                        if (isCustom) {
                          AsterTheme.updateCustomThemeColors(
                            AsterTheme.customThemeColorsNotifier.value,
                            activateIfVip: true,
                          );
                        } else {
                          AsterTheme.selectThemeOption(option.id);
                        }
                        onClose();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? option.primary.withValues(alpha: isDark ? 0.18 : 0.11)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isSelected
                                ? option.primary.withValues(alpha: 0.85)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Opacity(
                          opacity: isUnlocked ? 1.0 : 0.65,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: option.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: option.primary.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Icon(
                                  option.icon,
                                  size: 14.5,
                                  color: option.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                          Flexible(
                                            child: Text(
                                              option.localizedName,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.manrope(
                                                fontSize: 12.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w700,
                                                color: AsterTheme.text(context),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            option.mode == ThemeMode.dark
                                                ? context.tr('Escuro')
                                                : context.tr('Claro'),
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AsterTheme.textMuted(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          for (final swatch in [
                                            option.bg,
                                            option.surface,
                                            option.primary,
                                            if (option.accents.isNotEmpty)
                                              option.accents.first,
                                          ])
                                            Container(
                                              width: 10,
                                              height: 10,
                                              margin: const EdgeInsetsDirectional.only(end: 4),
                                            decoration: BoxDecoration(
                                              color: swatch,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AsterTheme.text(context)
                                                    .withValues(alpha: 0.16),
                                                width: 0.7,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: option.primary,
                                )
                              else if (isLockedVip)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AsterVipColors.gold
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lock_rounded,
                                        size: 11,
                                        color: AsterVipColors.gold,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'VIP',
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AsterVipColors.gold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isLockedShop)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AsterTheme.surfaceAlt(context),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        size: 11,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$price',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AsterTheme.textMuted(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (onOpenShop != null) ...[
                Divider(height: 1, thickness: 1, color: borderCol),
                InkWell(
                  onTap: () {
                    onClose();
                    onOpenShop!();
                  },
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 15,
                          color: AsterTheme.primary(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('Desbloquear mais temas na Loja'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AsterTheme.primary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Cápsula Soft Clay para ações da barra superior do Noesis.
class _NoesisTopPillButton extends StatefulWidget {
  const _NoesisTopPillButton({
    super.key,
    required this.tooltip,
    required this.child,
    this.onTap,
    this.width,
    this.padding,
    this.isActive = false,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final bool isActive;

  @override
  State<_NoesisTopPillButton> createState() => _NoesisTopPillButtonState();
}

class _NoesisTopPillButtonState extends State<_NoesisTopPillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AsterTheme.primary(context);
    final baseBg = AsterTheme.card(context).withValues(alpha: isDark ? 0.72 : 0.86);
    final activeBg = Color.lerp(baseBg, primary, isDark ? 0.22 : 0.14)!;
    final hoverBg = Color.lerp(baseBg, primary, isDark ? 0.16 : 0.10)!;
    final borderCol = widget.isActive
        ? primary.withValues(alpha: 0.72)
        : (_hovered
            ? primary.withValues(alpha: 0.45)
            : AsterTheme.surfaceInset(context).withValues(alpha: isDark ? 0.65 : 0.9));

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: widget.width,
            height: 29,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.isActive ? activeBg : (_hovered ? hoverBg : baseBg),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol, width: 1),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

enum _WindowGlyphType { minimize, maximize, restore, close }

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.glyphType,
    this.isClose = false,
  });

  final String tooltip;
  final VoidCallback onTap;
  final _WindowGlyphType glyphType;
  final bool isClose;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AsterTheme.primary(context);
    final normalColor = AsterTheme.text(context).withValues(alpha: 0.78);
    final hoverBg = widget.isClose
        ? AsterConstants.coral
        : primary.withValues(alpha: isDark ? 0.22 : 0.14);
    final fgColor = widget.isClose && _hovered
        ? Colors.white
        : (_hovered && !widget.isClose ? primary : normalColor);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 24,
            decoration: BoxDecoration(
              color: _hovered ? hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(11, 11),
                painter: _NoesisWindowGlyphPainter(
                  type: widget.glyphType,
                  color: fgColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoesisWindowGlyphPainter extends CustomPainter {
  const _NoesisWindowGlyphPainter({
    required this.type,
    required this.color,
  });

  final _WindowGlyphType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case _WindowGlyphType.minimize:
        final y = size.height * 0.62;
        canvas.drawLine(Offset(1.5, y), Offset(size.width - 1.5, y), paint);
        break;
      case _WindowGlyphType.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1.5, 1.5, size.width - 3.0, size.height - 3.0),
            const Radius.circular(2.6),
          ),
          paint,
        );
        break;
      case _WindowGlyphType.restore:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1.2, 3.2, size.width - 4.4, size.height - 4.4),
            const Radius.circular(2.2),
          ),
          paint,
        );
        final back = Path()
          ..moveTo(3.6, 3.2)
          ..lineTo(3.6, 1.4)
          ..arcToPoint(
            const Offset(5.0, 1.0),
            radius: const Radius.circular(1.4),
          )
          ..lineTo(size.width - 2.4, 1.0)
          ..arcToPoint(
            Offset(size.width - 1.0, 2.4),
            radius: const Radius.circular(1.4),
          )
          ..lineTo(size.width - 1.0, size.height - 3.6);
        canvas.drawPath(back, paint);
        break;
      case _WindowGlyphType.close:
        canvas.drawLine(
          const Offset(2.0, 2.0),
          Offset(size.width - 2.0, size.height - 2.0),
          paint,
        );
        canvas.drawLine(
          Offset(size.width - 2.0, 2.0),
          Offset(2.0, size.height - 2.0),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NoesisWindowGlyphPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
