import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/desktop_window_service.dart';
import '../../core/theme.dart';
import '../../widgets/desktop_top_bar.dart';
import '../../widgets/noesis_logo.dart';
import '../../widgets/vip_privileges.dart';
import '../auth/auth_screen.dart' show DiscordLogoWidget;
import 'widgets/landing_bento_section.dart';
import 'widgets/landing_community_section.dart';
import 'widgets/landing_hero_stage.dart';
import 'widgets/landing_motion.dart';
import 'widgets/landing_showcase_section.dart';

/// Página principal (Landing Page) do Noesis em Flutter — recriada sobre o
/// layout do redesign web e corrigida com todos os dados reais do software
/// (14 módulos, 20 ferramentas, 7 provedores de IA, 39 bancas RAG, 8 Elos reais,
/// Calendário em 4 visões Dia/Semana/Mês/Timeline, 11 temas + VIP RGB).
class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.onOpenLogin,
  });

  final VoidCallback onOpenLogin;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _resourcesKey = GlobalKey();
  final GlobalKey _modulesKey = GlobalKey();
  final GlobalKey _communityKey = GlobalKey();
  final GlobalKey _platformsKey = GlobalKey();

  static const String _githubUrl = 'https://github.com/zAstergun/Noesis';
  static const String _windowsSetupUrl =
      'https://github.com/zAstergun/Noesis/releases/download/v1.0.0/noesis-v1.0.0-windows-x64-setup.exe';
  static const String _androidApkUrl =
      'https://github.com/zAstergun/Noesis/releases/download/v1.0.0/noesis-v1.0.0-android.apk';

  late final ValueNotifier<String> _demoThemeIdNotifier =
      ValueNotifier<String>(AsterTheme.activeThemeIdNotifier.value);
  final ValueNotifier<bool> _specsRevealed = ValueNotifier<bool>(false);

  NoesisThemeOption _resolveDemoTheme(String themeId) {
    return AsterTheme.availableThemesWithCustom.firstWhere(
      (t) => t.id == themeId,
      orElse: () => AsterTheme.availableThemes.first,
    );
  }

  @override
  void dispose() {
    _demoThemeIdNotifier.dispose();
    _specsRevealed.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openThemePickerDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<String>(
          valueListenable: _demoThemeIdNotifier,
          builder: (_, activeId, _) {
            final demoOption = _resolveDemoTheme(activeId);
            return NoesisLogoThemeScope(
              themeOption: demoOption,
              child: Theme(
                data: AsterTheme.themeDataFor(demoOption),
                child: Builder(
                  builder: (themedContext) {
                    final isDark = Theme.of(themedContext).brightness == Brightness.dark;
                    final textCol = AsterTheme.text(themedContext);
                    final mutedCol = AsterTheme.textMuted(themedContext);
                    final primary = AsterTheme.primary(themedContext);
                    final cardCol = AsterTheme.card(themedContext);
                    final altCol = AsterTheme.surfaceAlt(themedContext);
                    final insetCol = AsterTheme.surfaceInset(themedContext);
                    final themes = AsterTheme.availableThemesWithCustom;

                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardCol,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: insetCol.withValues(alpha: 0.9),
                            ),
                            boxShadow: isDark
                                ? AsterConstants.clayDarkShadow
                                : AsterConstants.clayShadow,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(Icons.palette_rounded, size: 19, color: primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Temas do Noesis (Prévia)',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: textCol,
                                          ),
                                        ),
                                        Text(
                                          'Demonstração nesta página · 11 paletas + VIP RGB',
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: mutedCol,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    icon: Icon(Icons.close_rounded, color: mutedCol),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final cols = constraints.maxWidth >= 380 ? 3 : 2;
                                      const spacing = 10.0;
                                      final itemW =
                                          (constraints.maxWidth - spacing * (cols - 1)) / cols;
                                      return Wrap(
                                        spacing: spacing,
                                        runSpacing: spacing,
                                        children: themes.map((opt) {
                                          final selected = opt.id == activeId;
                                          final isCustomVip =
                                              opt.id == AsterTheme.customThemeId;
                                          final borderCol = selected
                                              ? (isCustomVip ? AsterVipColors.gold : primary)
                                              : (isCustomVip
                                                  ? AsterVipColors.gold.withValues(alpha: 0.55)
                                                  : insetCol);

                                          return SizedBox(
                                            width: itemW,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                key: Key('landing_theme_option_${opt.id}'),
                                                onTap: () => _demoThemeIdNotifier.value = opt.id,
                                                borderRadius: BorderRadius.circular(18),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 180),
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? (isCustomVip
                                                            ? AsterVipColors.gold
                                                                .withValues(alpha: 0.12)
                                                            : primary.withValues(alpha: 0.10))
                                                        : altCol,
                                                    borderRadius: BorderRadius.circular(18),
                                                    border: Border.all(
                                                      color: borderCol,
                                                      width: selected ? 2 : 1.1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(
                                                            color: Colors.black.withValues(
                                                              alpha: isDark ? 0.35 : 0.08,
                                                            ),
                                                          ),
                                                        ),
                                                        clipBehavior: Clip.antiAlias,
                                                        child: isCustomVip
                                                            ? Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment.stretch,
                                                                children: AsterTheme
                                                                    .customThemeColorsNotifier
                                                                    .value
                                                                    .asList
                                                                    .map(
                                                                      (c) => Expanded(
                                                                        child:
                                                                            ColoredBox(color: c),
                                                                      ),
                                                                    )
                                                                    .toList(),
                                                              )
                                                            : Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment.stretch,
                                                                children: [
                                                                  Expanded(
                                                                    flex: 3,
                                                                    child:
                                                                        ColoredBox(color: opt.bg),
                                                                  ),
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: ColoredBox(
                                                                        color: opt.surface),
                                                                  ),
                                                                  Expanded(
                                                                    flex: 2,
                                                                    child: ColoredBox(
                                                                        color: opt.primary),
                                                                  ),
                                                                  Expanded(
                                                                    child: ColoredBox(
                                                                      color: opt.accents.isNotEmpty
                                                                          ? opt.accents.first
                                                                          : opt.primary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              opt.name,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.manrope(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.w800,
                                                                color: textCol,
                                                              ),
                                                            ),
                                                          ),
                                                          if (selected)
                                                            Icon(
                                                              Icons.check_circle_rounded,
                                                              size: 15,
                                                              color: isCustomVip
                                                                  ? AsterVipColors.gold
                                                                  : primary,
                                                            )
                                                          else if (isCustomVip)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 5,
                                                                vertical: 1.5,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: AsterVipColors.gold
                                                                    .withValues(alpha: 0.2),
                                                                borderRadius:
                                                                    BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                'VIP',
                                                                style: GoogleFonts.jetBrainsMono(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: AsterVipColors.goldDark,
                                                                ),
                                                              ),
                                                            )
                                                          else
                                                            Icon(
                                                              opt.mode == ThemeMode.dark
                                                                  ? Icons.dark_mode_rounded
                                                                  : Icons.light_mode_rounded,
                                                              size: 13,
                                                              color: mutedCol,
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        isCustomVip
                                                            ? 'VIP · 6 cores RGB'
                                                            : (opt.mode == ThemeMode.dark
                                                                ? 'Escuro'
                                                                : 'Claro'),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: isCustomVip
                                                              ? AsterVipColors.goldDark
                                                              : mutedCol,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
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
            );
          },
        );
      },
    );
  }

  void _openMobileNavSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final demoOption = _resolveDemoTheme(_demoThemeIdNotifier.value);
        return Theme(
          data: AsterTheme.themeDataFor(demoOption),
          child: Builder(
            builder: (themedSheetContext) {
              final textCol = AsterTheme.text(themedSheetContext);
              final primary = AsterTheme.primary(themedSheetContext);
              return Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AsterTheme.card(themedSheetContext),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AsterTheme.surfaceInset(themedSheetContext)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MobileMenuTile(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Recursos',
                      textCol: textCol,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _scrollTo(_resourcesKey);
                      },
                    ),
                    _MobileMenuTile(
                      icon: Icons.layers_rounded,
                      label: 'Módulos',
                      textCol: textCol,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _scrollTo(_modulesKey);
                      },
                    ),
                    _MobileMenuTile(
                      icon: Icons.groups_rounded,
                      label: 'Comunidade',
                      textCol: textCol,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _scrollTo(_communityKey);
                      },
                    ),
                    _MobileMenuTile(
                      icon: Icons.download_rounded,
                      label: 'Download',
                      textCol: textCol,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _scrollTo(_platformsKey);
                      },
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onOpenLogin();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        'Acessar ferramenta',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: AsterTheme.onPrimary(themedSheetContext),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _demoThemeIdNotifier,
      builder: (_, demoThemeId, _) {
        final demoOption = _resolveDemoTheme(demoThemeId);
        return NoesisLogoThemeScope(
          themeOption: demoOption,
          child: Theme(
            data: AsterTheme.themeDataFor(demoOption),
            child: Builder(
              builder: (themedContext) {
                final body = _buildLandingBody(themedContext);

                if (!DesktopWindowService.isCustomFrameSupported) {
                  return Scaffold(
                    backgroundColor: Theme.of(themedContext).scaffoldBackgroundColor,
                    body: body,
                  );
                }

                final isDark = Theme.of(themedContext).brightness == Brightness.dark;
                final shellColor = noesisDesktopShellColor(themedContext);
                return Scaffold(
                  backgroundColor: shellColor,
                  body: Container(
                    color: shellColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DesktopTopBar(showWorkspaceControls: false),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AsterTheme.surfaceInset(themedContext).withValues(
                                    alpha: isDark ? 0.72 : 0.9,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: body,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandingBody(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final isCompactMobile = width < 480;
    final horizontalPadding = isWide ? 40.0 : (isCompactMobile ? 16.0 : 24.0);

    return LandingAmbientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 24 : 12,
                10,
                isWide ? 24 : 12,
                4,
              ),
              child: _buildFloatingPillHeader(context, width: width),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('landing_scroll_view'),
                controller: _scrollController,
                padding: EdgeInsets.only(bottom: isWide ? 48 : 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isWide ? 44 : 24),
                          KeyedSubtree(
                            key: _heroKey,
                            child: LandingHeroSection(
                              width: width,
                              onOpenLogin: widget.onOpenLogin,
                              onExploreResources: () => _scrollTo(_resourcesKey),
                            ),
                          ),
                          SizedBox(height: isWide ? 56 : 36),
                          LandingScrollReveal(
                            scrollController: _scrollController,
                            onRevealed: () => _specsRevealed.value = true,
                            child: _SpecsStrip(
                              width: width,
                              revealedListenable: _specsRevealed,
                            ),
                          ),
                          SizedBox(height: isWide ? 88 : 56),
                          KeyedSubtree(
                            key: _resourcesKey,
                            child: LandingScrollReveal(
                              scrollController: _scrollController,
                              child: LandingShowcaseSection(width: width),
                            ),
                          ),
                          SizedBox(height: isWide ? 88 : 56),
                          KeyedSubtree(
                            key: _modulesKey,
                            child: LandingScrollReveal(
                              scrollController: _scrollController,
                              child: LandingBentoSection(width: width),
                            ),
                          ),
                          SizedBox(height: isWide ? 88 : 56),
                          KeyedSubtree(
                            key: _communityKey,
                            child: LandingScrollReveal(
                              scrollController: _scrollController,
                              child: LandingCommunitySection(width: width),
                            ),
                          ),
                          SizedBox(height: isWide ? 88 : 56),
                          KeyedSubtree(
                            key: _platformsKey,
                            child: LandingScrollReveal(
                              scrollController: _scrollController,
                              child: _buildFinalCtaAndPlatforms(context, width: width),
                            ),
                          ),
                          SizedBox(height: isWide ? 48 : 32),
                          _buildFooter(context, width: width),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra superior flutuante em formato pílula inspirada em `.hdr-in`.
  Widget _buildFloatingPillHeader(BuildContext context, {required double width}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = width >= 940;
    final isCompact = width < 480;
    final cardCol = AsterTheme.card(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final primary = AsterTheme.primary(context);
    final onPrimary = AsterTheme.onPrimary(context);
    final textCol = AsterTheme.text(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Container(
          height: 62,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: cardCol.withValues(alpha: isDark ? 0.88 : 0.90),
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            border: Border.all(
              color: insetCol.withValues(alpha: isDark ? 0.85 : 0.95),
            ),
            boxShadow: isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.clayShadow,
          ),
          child: Row(
            children: [
              NoesisInteractiveBrand(
                onTap: () => _scrollTo(_heroKey),
                logoSize: isCompact ? 28 : 32,
                fontSize: isCompact ? 17 : 20,
                spacing: isCompact ? 7 : 10,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                trailing: isCompact
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          'ASTER',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: primary,
                          ),
                        ),
                      ),
              ),
              if (isWide) ...[
                const Spacer(),
                _NavPillLink(
                  label: 'Recursos',
                  onTap: () => _scrollTo(_resourcesKey),
                ),
                _NavPillLink(
                  label: 'Módulos',
                  onTap: () => _scrollTo(_modulesKey),
                ),
                _NavPillLink(
                  label: 'Comunidade',
                  onTap: () => _scrollTo(_communityKey),
                ),
                _NavPillLink(
                  key: const Key('landing_nav_download_button'),
                  label: 'Download',
                  onTap: () => _scrollTo(_platformsKey),
                ),
              ],
              const Spacer(),
              // Botão único de tema (11 temas reais do Noesis)
              Tooltip(
                message: 'Explorar 11 temas do Noesis',
                child: InkWell(
                  key: const Key('landing_theme_button'),
                  onTap: _openThemePickerDialog,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: altCol,
                      shape: BoxShape.circle,
                      border: Border.all(color: insetCol),
                    ),
                    child: Icon(Icons.palette_rounded, size: 17, color: primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // CTA principal do header (mantém Key('landing_nav_login_button'))
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(primary, Colors.white, 0.14)!,
                      primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  boxShadow: AsterTheme.primaryShadow(context, primary),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('landing_nav_login_button'),
                    onTap: widget.onOpenLogin,
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : 18,
                        vertical: 9,
                      ),
                      child: Text(
                        isCompact ? 'Acessar' : 'Acessar ferramenta',
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.manrope(
                          fontSize: isCompact ? 12.5 : 13.5,
                          fontWeight: FontWeight.w800,
                          color: onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!isWide) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: _openMobileNavSheet,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: altCol,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.menu_rounded, size: 19, color: textCol),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinalCtaAndPlatforms(BuildContext context, {required double width}) {
    final isCompact = width < 600;
    final isWide = width >= 900;
    final primary = AsterTheme.primary(context);

    final radius = isCompact ? 32.0 : 44.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(primary, const Color(0xFF14112E), 0.36)!,
            Color.lerp(primary, const Color(0xFF231F48), 0.24)!,
            Color.lerp(primary, AsterConstants.menta, 0.44)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 48,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: _FinalBannerOrbs()),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 22 : 44,
                  vertical: isCompact ? 42 : 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            ),
            child: Text(
              'PLATAFORMAS & DOWNLOADS · v1.0.0',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Text(
              'Seu próximo nível de estudo começa agora.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: isWide ? 52 : (isCompact ? 30 : 40),
                fontWeight: FontWeight.w700,
                height: 1.06,
                letterSpacing: -1.4,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'Acesse pela Web ou baixe os pacotes oficiais para Windows e Android com sincronização automática pela sua Aster Account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: isCompact ? 14.5 : 16.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 12,
            children: [
              LandingHoverLift(
                liftY: -2.0,
                child: ElevatedButton.icon(
                  onPressed: widget.onOpenLogin,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'Acessar ferramenta',
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AsterConstants.textDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              LandingHoverLift(
                liftY: -2.0,
                child: OutlinedButton.icon(
                  onPressed: () => _openExternalUrl(AsterConstants.asterDiscordUrl),
                  icon: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: DiscordLogoWidget(size: 13)),
                  ),
                  label: Text(
                    'Entrar no Discord Aster',
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              LandingHoverLift(
                liftY: -2.0,
                child: OutlinedButton.icon(
                  key: const Key('landing_github_button'),
                  onPressed: () => _openExternalUrl(_githubUrl),
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: Text(
                    'GitHub (zAstergun/Noesis)',
                    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCols = constraints.maxWidth >= 560;
                final windowsCard = LandingHoverLift(
                  liftY: -4.0,
                  child: _DownloadOptionCard(
                    icon: Icons.desktop_windows_rounded,
                    badge: 'x64 · ~13,0 MB',
                    title: 'Windows Desktop',
                    subtitle: 'Instalador oficial (.exe) com atalho automático e desinstalador.',
                    ctaLabel: 'Baixar Instalador Windows (.exe)',
                    onTap: () => _openExternalUrl(_windowsSetupUrl),
                  ),
                );
                final androidCard = LandingHoverLift(
                  liftY: -4.0,
                  child: _DownloadOptionCard(
                    icon: Icons.android_rounded,
                    badge: 'v1.0.0 · ~70,6 MB',
                    title: 'Android APK',
                    subtitle: 'Instalador direto oficial para estudar no celular ou tablet.',
                    ctaLabel: 'Baixar APK Android',
                    onTap: () => _openExternalUrl(_androidApkUrl),
                  ),
                );

                if (isTwoCols) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: windowsCard),
                        const SizedBox(width: 18),
                        Expanded(child: androidCard),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    windowsCard,
                    const SizedBox(height: 14),
                    androidCard,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_iphone_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'iOS · disponível via Web App no Safari',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, {required double width}) {
    final mutedCol = AsterTheme.textMuted(context);
    final primary = AsterTheme.primary(context);
    final insetCol = AsterTheme.surfaceInset(context);

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: insetCol.withValues(alpha: 0.85))),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          NoesisInteractiveBrand(
            onTap: () => _scrollTo(_heroKey),
            logoSize: 28,
            fontSize: 17,
            spacing: 8,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Text(
                'ASTER',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
          ),
          Text(
            'Cognitive OS & AI Study Engine · Ecossistema Aster',
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: mutedCol,
            ),
          ),
          Wrap(
            spacing: 14,
            children: [
              _FooterTextLink(label: 'Recursos', onTap: () => _scrollTo(_resourcesKey)),
              _FooterTextLink(label: 'Módulos', onTap: () => _scrollTo(_modulesKey)),
              _FooterTextLink(label: 'Comunidade', onTap: () => _scrollTo(_communityKey)),
              _FooterTextLink(label: 'Download', onTap: () => _scrollTo(_platformsKey)),
              _FooterTextLink(label: 'Entrar', onTap: widget.onOpenLogin),
            ],
          ),
        ],
      ),
    );
  }
}

/// Faixa de 5 especificações reais do Noesis com count-up animado ao entrar na tela.
class _SpecsStrip extends StatelessWidget {
  const _SpecsStrip({
    required this.width,
    required this.revealedListenable,
  });

  final double width;
  final ValueListenable<bool> revealedListenable;

  static const List<({int count, String label})> _specs = [
    (count: 14, label: 'Módulos integrados'),
    (count: 20, label: 'Ferramentas no Agente'),
    (count: 7, label: 'Provedores de IA'),
    (count: 39, label: 'Modelos de simulados'),
    (count: 8, label: 'Elos na Liga'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardCol = AsterTheme.card(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final isWide = width >= 860;

    return ValueListenableBuilder<bool>(
      valueListenable: revealedListenable,
      builder: (context, revealed, _) {
        final active = revealed || isLandingTestEnvironment();
        return Container(
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: insetCol.withValues(alpha: isDark ? 0.75 : 0.9)),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          child: isWide
              ? IntrinsicHeight(
                  child: Row(
                    children: List.generate(_specs.length, (i) {
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: i == 0
                                ? null
                                : Border(
                                    left: BorderSide(
                                      color: insetCol.withValues(alpha: 0.75),
                                    ),
                                  ),
                          ),
                          child: _SpecItem(
                            count: _specs[i].count,
                            label: _specs[i].label,
                            delayMs: i * 90,
                            active: active,
                          ),
                        ),
                      );
                    }),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_specs.length, (i) {
                      return SizedBox(
                        width: width < 480 ? (width - 64) / 2 : 165,
                        child: _SpecItem(
                          count: _specs[i].count,
                          label: _specs[i].label,
                          delayMs: i * 90,
                          compact: true,
                          active: active,
                        ),
                      );
                    }),
                  ),
                ),
        );
      },
    );
  }
}

class _SpecItem extends StatelessWidget {
  const _SpecItem({
    required this.count,
    required this.label,
    required this.delayMs,
    required this.active,
    this.compact = false,
  });

  final int count;
  final String label;
  final int delayMs;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final primary = AsterTheme.primary(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 14 : 26,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: active ? count.toDouble() : 0),
            duration: isLandingTestEnvironment()
                ? Duration.zero
                : Duration(milliseconds: 900 + delayMs),
            curve: kLandingFluidCurve,
            builder: (context, value, _) {
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [textCol, Color.lerp(textCol, primary, 0.5)!],
                ).createShader(bounds),
                child: Text(
                  '${value.round()}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: compact ? 36 : 48,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1.5,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mutedCol,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavPillLink extends StatelessWidget {
  const _NavPillLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AsterTheme.textMuted(context),
          ),
        ),
      ),
    );
  }
}

class _MobileMenuTile extends StatelessWidget {
  const _MobileMenuTile({
    required this.icon,
    required this.label,
    required this.textCol,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textCol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AsterTheme.primary(context)),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textCol,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: onTap,
    );
  }
}

class _DownloadOptionCard extends StatelessWidget {
  const _DownloadOptionCard({
    required this.icon,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 24, color: Colors.white),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded, size: 17, color: AsterConstants.textDark),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ctaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AsterConstants.textDark,
                        ),
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
  }
}

class _FooterTextLink extends StatelessWidget {
  const _FooterTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AsterTheme.primary(context),
          ),
        ),
      ),
    );
  }
}

class _FinalBannerOrbs extends StatefulWidget {
  const _FinalBannerOrbs();

  @override
  State<_FinalBannerOrbs> createState() => _FinalBannerOrbsState();
}

class _FinalBannerOrbsState extends State<_FinalBannerOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (!isLandingTestEnvironment()) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final s = math.sin(t * math.pi);
          return Stack(
            children: [
              Positioned(
                left: -210 + (t * 56),
                top: -210 + (s * 32),
                width: 560,
                height: 560,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        stops: const [0.0, 0.72],
                        colors: [
                          Colors.white.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -190 + ((1 - t) * 52),
                bottom: -210 - (s * 28),
                width: 540,
                height: 540,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        stops: const [0.0, 0.72],
                        colors: [
                          Colors.white.withValues(alpha: 0.11),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
