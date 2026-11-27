import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/insights_economy_config.dart';
import '../../core/shop_service.dart';
import '../../core/supabase_service.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../widgets/insight_icon.dart';
import '../../widgets/vip_privileges.dart';
import '../../widgets/vip_rgb_theme_editor.dart';
import '../profile/models/profile_cosmetics.dart';
import '../ranking/models/ranking_league_model.dart';

enum _ShopSection { all, themes, arsenal, identity }

enum _ShopFilter { all, available, owned, light, dark }

enum _TransactionFilter { all, earned, spent }

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  _ShopSection _section = _ShopSection.all;
  _ShopFilter _filter = _ShopFilter.all;
  _TransactionFilter _txFilter = _TransactionFilter.all;
  ProfileCosmeticCategory _identityCategory = ProfileCosmeticCategory.banner;
  bool _identityVipOnlyFilter = false;
  bool _showAllTransactions = false;

  @override
  void initState() {
    super.initState();
    ShopService.instance.init();
  }

  Future<void> _handleProfileCosmeticAction(ProfileCosmeticItem item) async {
    if (item.isVipOnly && !SupabaseService.isCurrentUserVip) {
      showVipPrivilegesModal(context);
      return;
    }
    final res = await ShopService.instance.purchaseAndEquipProfileItem(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 3),
          backgroundColor: res.ok ? AsterConstants.menta : AsterConstants.coral,
          content: Text(
            res.ok ? (res.message ?? '${item.name} equipado!') : (res.error ?? 'Saldo insuficiente.'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
  }

  Future<void> _handleStreakProtectorPurchase() async {
    final res = await ShopService.instance.purchaseStreakProtector();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 3),
          backgroundColor: res.ok ? AsterConstants.menta : null,
          content: Text(
            res.ok
                ? (res.message ?? 'Selo de Consistência guardado!')
                : (res.error ?? 'Não foi possível guardar.'),
            style: res.ok ? const TextStyle(color: Colors.white) : null,
          ),
        ),
      );
  }

  Future<void> _handlePurchase(NoesisThemeOption option) async {
    final res = await ShopService.instance.purchaseTheme(option.id);
    if (!mounted) return;

    if (res.ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 3),
            backgroundColor: AsterTheme.primary(context),
            content: Text(
              res.message ?? 'Tema ${option.name} desbloqueado!',
              style: TextStyle(color: AsterTheme.onPrimary(context)),
            ),
            action: SnackBarAction(
              label: 'Equipar',
              textColor: AsterTheme.onPrimary(context),
              onPressed: () => AsterTheme.selectThemeOption(option.id),
            ),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            persist: false,
            duration: const Duration(seconds: 3),
            content: Text(res.error ?? 'Saldo insuficiente.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final shop = ShopService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([
        shop.balanceNotifier,
        shop.unlockedThemesNotifier,
        shop.transactionsNotifier,
        shop.streakProtectorsNotifier,
        shop.unlockedProfileItemsNotifier,
        shop.equippedBannerIdNotifier,
        shop.equippedFrameIdNotifier,
        shop.equippedTitleIdNotifier,
        shop.currentEloIndexNotifier,
        AsterTheme.activeThemeIdNotifier,
        SupabaseService.isVipNotifier,
      ]),
      builder: (context, _) {
        final balance = shop.balance;
        final activeThemeId = AsterTheme.activeThemeIdNotifier.value;
        final isVip = SupabaseService.isCurrentUserVip;
        final transactions = shop.transactionsNotifier.value
            .where((tx) => tx.source != 'welcome' && tx.id != 'welcome_bonus')
            .toList();
        final primaryCol = AsterTheme.primary(context);

        final filteredThemes = AsterTheme.availableThemes.where((opt) {
          final unlocked = shop.isThemeUnlocked(opt.id);
          switch (_filter) {
            case _ShopFilter.all:
              return true;
            case _ShopFilter.available:
              return !unlocked;
            case _ShopFilter.owned:
              return unlocked;
            case _ShopFilter.light:
              return opt.mode == ThemeMode.light;
            case _ShopFilter.dark:
              return opt.mode == ThemeMode.dark;
          }
        }).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 36.0 : 16.0,
            vertical: 18.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho da Loja
                  Builder(
                    builder: (context) {
                      final screenW = MediaQuery.sizeOf(context).width;
                      final isCompactHeader = screenW < 600;
                      final contentLeft =
                          ((screenW - 1040).clamp(0.0, double.infinity) / 2) +
                              (isDesktop ? 36.0 : 16.0);
                      final neededGap = (108.0 - contentLeft).clamp(0.0, 82.0);
                      final balanceBadge = Container(
                        key: const Key('shop_balance_badge'),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompactHeader ? 12 : 16,
                          vertical: isCompactHeader ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: AsterTheme.card(context),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                          border: Border.all(
                            color: AsterConstants.ambar.withValues(alpha: 0.45),
                            width: 1.4,
                          ),
                          boxShadow: Theme.of(context).brightness == Brightness.dark
                              ? AsterConstants.claySubtleDarkShadow
                              : AsterConstants.claySubtleShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InsightCoinIcon(size: isCompactHeader ? 18 : 20),
                            const SizedBox(width: 7),
                            Text(
                              '$balance ${ShopService.currencyName}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: isCompactHeader ? 12.5 : 13.5,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.text(context),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isCompactHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Loja do Noesis',
                                    style: GoogleFonts.manrope(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AsterTheme.text(context),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                balanceBadge,
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Desbloqueie temas, protetores de ofensiva e novidades com ${ShopService.currencyName}',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          NoesisCollapsedMenuSpacer(width: neededGap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Loja do Noesis',
                                  style: GoogleFonts.manrope(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AsterTheme.text(context),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Desbloqueie temas, protetores de ofensiva e novidades com ${ShopService.currencyName}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          balanceBadge,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Card Explicativo: Como ganhar moedas
                  SoftClayCard(
                    key: const Key('shop_how_to_earn_card'),
                    padding: EdgeInsets.all(isDesktop ? 20 : 16),
                    child: Builder(
                      builder: (context) {
                        final todayEarned = shop.todayEarnedInsights;
                        final eloIndex = shop.currentEloIndex;
                        final eloTier = RankingEloCatalog.tierAt(eloIndex);
                        final eloPct = InsightsEconomyConfig.eloBonusPercent(eloIndex);
                        final dailyCap = InsightsEconomyConfig.dailySoftCapForElo(eloIndex);
                        final capProgress = (todayEarned / dailyCap).clamp(0.0, 1.0);
                        final secondaryCol = AsterTheme.secondary(context);
                        String fmt(int base) => InsightsEconomyConfig.formatScaledReward(
                              base,
                              eloIndex: eloIndex,
                              isVip: isVip,
                            );

                        final dailyCounterPill = isVip
                            ? Container(
                                key: const Key('shop_vip_unlimited_pill'),
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AsterVipColors.gold.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AsterVipColors.gold.withValues(alpha: 0.55),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const VipCrownIcon(size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Hoje: $todayEarned · Ilimitado',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AsterTheme.text(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      eloPct > 0
                                          ? '2× VIP · +$eloPct% ${eloTier.name} (${InsightsEconomyConfig.totalGainMultiplier(eloIndex: eloIndex, isVip: true).toStringAsFixed(1)}×)'
                                          : 'Bônus VIP ativo · 2× Insights',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AsterVipColors.goldDark,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                key: const Key('shop_elo_cap_pill'),
                                width: isDesktop ? null : double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: AsterTheme.surfaceAlt(context),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AsterConstants.ambar.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const InsightCoinIcon(size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Hoje: $todayEarned/$dailyCap',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AsterTheme.text(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      eloPct > 0
                                          ? 'Elo ${eloTier.name}: +$eloPct% ganho · +${eloIndex * InsightsEconomyConfig.dailySoftCapBonusPerElo} limite'
                                          : 'Elo ${eloTier.name}: suba de elo p/ +10% e +20 limite',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: eloPct > 0
                                            ? eloTier.accentColor
                                            : AsterTheme.textMuted(context),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: isDesktop ? 168 : double.infinity,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: capProgress,
                                          minHeight: 4,
                                          backgroundColor: AsterTheme.surfaceInset(context),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            capProgress >= 1.0
                                                ? AsterConstants.ambar
                                                : primaryCol,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isDesktop ? 560 : MediaQuery.sizeOf(context).width - 64,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AsterConstants.ambar.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AsterConstants.ambar.withValues(alpha: 0.32),
                                          ),
                                        ),
                                        child: const Center(
                                          child: InsightCoinIcon(size: 24),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Como ganhar ${ShopService.currencyName}',
                                              style: GoogleFonts.manrope(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AsterTheme.text(context),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Estude com consistência para desbloquear novos temas na Loja',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                color: AsterTheme.textMuted(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                dailyCounterPill,
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 720;
                                final simCard = _buildEarnMethodTile(
                                  context,
                                  icon: Icons.assignment_rounded,
                                  accent: primaryCol,
                                  title: 'Simulados',
                                  actionLabel: 'Ir para Simulados',
                                  onAction: () => RootScreen.switchTab(1),
                                  pushActionToBottom: wide,
                                  rules: [
                                    (
                                      label: 'Questão (≥ 3s)',
                                      value: '+${fmt(InsightsEconomyConfig.quizQuestionAnswered)} · +${fmt(InsightsEconomyConfig.quizQuestionAnswered + InsightsEconomyConfig.quizQuestionCorrectBonus)} acerto',
                                    ),
                                    (
                                      label: 'Concluir prova',
                                      value: '+${fmt(InsightsEconomyConfig.examCompleted)} · +${fmt(InsightsEconomyConfig.examHighScoreBonus)} ≥80%',
                                    ),
                                  ],
                                );
                                final flashCard = _buildEarnMethodTile(
                                  context,
                                  icon: Icons.style_rounded,
                                  accent: secondaryCol,
                                  title: 'Flashcards',
                                  actionLabel: 'Revisar Flashcards',
                                  onAction: () => RootScreen.switchTab(2),
                                  pushActionToBottom: wide,
                                  rules: [
                                    (
                                      label: 'Revisão no prazo',
                                      value: '+${fmt(InsightsEconomyConfig.flashcardDueReview)} por card',
                                    ),
                                    (
                                      label: 'Difícil superado',
                                      value: '+${fmt(InsightsEconomyConfig.flashcardHardRedeemedBonus)} bônus',
                                    ),
                                  ],
                                );
                                final goalCard = _buildEarnMethodTile(
                                  context,
                                  icon: Icons.local_fire_department_rounded,
                                  accent: AsterConstants.ambar,
                                  title: 'Metas & Streaks',
                                  pushActionToBottom: wide,
                                  rules: [
                                    (
                                      label: 'Meta diária / semana',
                                      value: '+${fmt(InsightsEconomyConfig.dailyGoalHit)} / +${fmt(InsightsEconomyConfig.weeklyGoalHit)}',
                                    ),
                                    (
                                      label: 'Marcos de streak',
                                      value: '+${fmt(20)} a +${fmt(300)}',
                                    ),
                                  ],
                                );
                                if (wide) {
                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: simCard),
                                        const SizedBox(width: 12),
                                        Expanded(child: flashCard),
                                        const SizedBox(width: 12),
                                        Expanded(child: goalCard),
                                      ],
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    simCard,
                                    const SizedBox(height: 10),
                                    flashCard,
                                    const SizedBox(height: 10),
                                    goalCard,
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Barra de Seções da Loja (Grid 2x2 limpo no mobile, Wrap horizontal no desktop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final tabs = [
                        _buildSectionTab(
                          context,
                          section: _ShopSection.all,
                          key: const Key('shop_section_all'),
                          icon: Icons.grid_view_rounded,
                          label: 'Tudo',
                          expand: w < 640,
                        ),
                        _buildSectionTab(
                          context,
                          section: _ShopSection.themes,
                          key: const Key('shop_section_themes'),
                          icon: Icons.palette_rounded,
                          label: 'Temas & Visual',
                          expand: w < 640,
                        ),
                        _buildSectionTab(
                          context,
                          section: _ShopSection.arsenal,
                          key: const Key('shop_section_arsenal'),
                          icon: Icons.shield_rounded,
                          label: 'Arsenal de Estudo',
                          expand: w < 640,
                        ),
                        _buildSectionTab(
                          context,
                          section: _ShopSection.identity,
                          key: const Key('shop_section_identity'),
                          icon: Icons.workspace_premium_rounded,
                          label: 'Identidade & Status',
                          expand: w < 640,
                        ),
                      ];

                      if (w < 640) {
                        final cols = w >= 290 ? 2 : 1;
                        const gap = 8.0;
                        final tabW = (w - (cols - 1) * gap) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final tab in tabs) SizedBox(width: tabW, child: tab),
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: tabs,
                      );
                    },
                  ),
                  const SizedBox(height: 22),

                  if (_section == _ShopSection.all || _section == _ShopSection.themes) ...[
                    _buildSectionHeader(
                      context,
                      icon: Icons.palette_rounded,
                      accent: primaryCol,
                      title: 'Temas & Personalização Visual',
                      subtitle: 'Paletas permanentes para transformar todo o visual do Noesis',
                      badge: '${AsterTheme.availableThemes.length} temas + VIP',
                    ),
                    const SizedBox(height: 12),

                    // Filtros da seção de temas
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(context, _ShopFilter.all, 'Todos (${AsterTheme.availableThemes.length})'),
                        _buildFilterChip(context, _ShopFilter.available, 'Disponíveis'),
                        _buildFilterChip(context, _ShopFilter.owned, 'Desbloqueados'),
                        _buildFilterChip(context, _ShopFilter.light, 'Claros'),
                        _buildFilterChip(context, _ShopFilter.dark, 'Escuros'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grade de Temas da Loja
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
                        const gap = 14.0;
                        final cardW = (w - (cols - 1) * gap) / cols;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            ...filteredThemes.map(
                              (option) => SizedBox(
                                width: cardW,
                                child: _buildShopThemeCard(
                                  context,
                                  option: option,
                                  price: shop.priceForTheme(option.id),
                                  unlocked: shop.isThemeUnlocked(option.id),
                                  equipped: activeThemeId == option.id,
                                  balance: balance,
                                ),
                              ),
                            ),
                            if (_filter == _ShopFilter.all) ...[
                              SizedBox(
                                width: cardW,
                                child: _buildVipCustomThemeCard(
                                  context,
                                  isVip: isVip,
                                  equipped: activeThemeId == AsterTheme.customThemeId,
                                ),
                              ),
                              SizedBox(
                                width: cardW,
                                child: _buildLegendaryConquestCard(context),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'PERSONALIZAÇÃO VISUAL PERMANENTE · EM BREVE',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRoadmapGrid(
                      context,
                      items: const [
                        (
                          icon: Icons.colorize_rounded,
                          accent: Color(0xFF7C6CF0),
                          title: 'Cor de destaque personalizada',
                          description: 'Troque o roxo/destaque principal dentro de qualquer tema.',
                          priceLabel: '250',
                        ),
                        (
                          icon: Icons.timer_rounded,
                          accent: Color(0xFF0284C7),
                          title: 'Estilos do timer',
                          description: 'Visual em anel, digital grande, minimalista ou retrô.',
                          priceLabel: '150–300',
                        ),
                        (
                          icon: Icons.wallpaper_rounded,
                          accent: Color(0xFF10B981),
                          title: 'Fundos do dashboard',
                          description: 'Gradientes, padrões e texturas suaves de fundo.',
                          priceLabel: '300',
                        ),
                        (
                          icon: Icons.text_fields_rounded,
                          accent: Color(0xFFEC4899),
                          title: 'Fontes da interface',
                          description: 'Serifada para leitura longa nos cadernos ou monospace.',
                          priceLabel: '200',
                        ),
                        (
                          icon: Icons.flip_rounded,
                          accent: Color(0xFF8B5CF6),
                          title: 'Estilo dos flashcards',
                          description: 'Animação de virada, bordas e cores personalizadas do verso.',
                          priceLabel: '200',
                        ),
                        (
                          icon: Icons.interests_rounded,
                          accent: Color(0xFFF97316),
                          title: 'Ícones da barra lateral',
                          description: 'Traço fino, preenchido ou duotone para toda a navegação.',
                          priceLabel: '300',
                        ),
                      ],
                    ),
                  ],

                  if (_section == _ShopSection.all || _section == _ShopSection.arsenal) ...[
                    if (_section == _ShopSection.all) const SizedBox(height: 28),
                    Builder(
                      builder: (context) {
                        final shields = shop.streakProtectors;
                        final maxShields = shop.maxStreakProtectors;
                        final badgeText = shields == 0
                            ? 'Nenhum selo guardado'
                            : '$shields/$maxShields ${shields == 1 ? 'selo guardado' : 'selos guardados'}';
                        return _buildSectionHeader(
                          context,
                          icon: Icons.donut_large_rounded,
                          customIcon: const ConsistencySealIcon(size: 24),
                          accent: AsterConstants.menta,
                          title: 'Arsenal de Estudo',
                          subtitle:
                              'Utilitários para preservar sua consistência, manter o foco e acelerar revisões',
                          badge: badgeText,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildStreakProtectorCard(context, balance: balance),
                    const SizedBox(height: 18),
                    Text(
                      'PRÓXIMOS UTILITÁRIOS · EM BREVE',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRoadmapGrid(
                      context,
                      items: const [
                        (
                          icon: Icons.inventory_2_rounded,
                          accent: Color(0xFF7C6CF0),
                          title: 'Pacotes de decks prontos',
                          description: 'Baralhos temáticos curados (ex.: Security+). Conteúdo extra por enquanto em breve.',
                          priceLabel: '300',
                        ),
                        (
                          icon: Icons.schedule_send_rounded,
                          accent: Color(0xFF3DD598),
                          title: 'Adiar revisão (consumível)',
                          description: 'Máx. 1x por semana: empurra os flashcards do dia para amanhã sem quebrar a sequência.',
                          priceLabel: '60',
                        ),
                        (
                          icon: Icons.psychology_alt_rounded,
                          accent: Color(0xFFEC4899),
                          title: 'Personas do Noesis AI',
                          description: 'Professor Socrático, Revisor Rigoroso e Explique como se eu tivesse 12 anos.',
                          priceLabel: '400',
                        ),
                        (
                          icon: Icons.headphones_rounded,
                          accent: Color(0xFF06B6D4),
                          title: 'Sons de foco no timer',
                          description: 'Pacotes de chuva, lo-fi, ruído branco e biblioteca durante a sessão.',
                          priceLabel: '250',
                        ),
                        (
                          icon: Icons.widgets_rounded,
                          accent: Color(0xFFF59E0B),
                          title: 'Widgets extras do dashboard',
                          description: 'Contagem regressiva para a prova e cartões avançados de ritmo.',
                          priceLabel: '200',
                        ),
                        (
                          icon: Icons.event_available_rounded,
                          accent: Color(0xFF10B981),
                          title: 'Dia de folga semanal',
                          description: 'Escolha 1 dia fixo de descanso na semana sem gastar selo de consistência.',
                          priceLabel: '120',
                        ),
                      ],
                    ),
                  ],

                  if (_section == _ShopSection.all || _section == _ShopSection.identity) ...[
                    if (_section == _ShopSection.all) const SizedBox(height: 28),
                    _buildSectionHeader(
                      context,
                      icon: Icons.workspace_premium_rounded,
                      accent: AsterVipColors.goldDark,
                      title: 'Identidade & Status',
                      subtitle:
                          'Capas, molduras e títulos compráveis com Insights ou exclusivos para assinantes VIP',
                      badge: '${ProfileCosmeticsCatalog.all.length} itens + VIP',
                    ),
                    const SizedBox(height: 12),
                    _buildIdentityStoreSection(
                      context,
                      shop: shop,
                      isVip: isVip,
                      primaryCol: primaryCol,
                    ),
                  ],

                  if (transactions.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _buildTransactionsLedgerCard(
                      context,
                      transactions: transactions,
                      currentBalance: balance,
                    ),
                  ],
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsLedgerCard(
    BuildContext context, {
    required List<ShopTransaction> transactions,
    required int currentBalance,
  }) {
    bool isFreeSealTx(ShopTransaction tx) =>
        tx.amount == 0 && tx.reference == 'streak_protector';
    final earnedList =
        transactions.where((tx) => tx.amount > 0 || isFreeSealTx(tx)).toList();
    final spentList = transactions.where((tx) => tx.amount < 0).toList();
    final totalEarned = earnedList.fold<int>(0, (sum, tx) => sum + tx.amount);
    final totalSpent = spentList.fold<int>(0, (sum, tx) => sum + tx.amount.abs());

    final filtered = switch (_txFilter) {
      _TransactionFilter.all => transactions,
      _TransactionFilter.earned => earnedList,
      _TransactionFilter.spent => spentList,
    };

    const initialLimit = 8;
    final visible = _showAllTransactions ? filtered : filtered.take(initialLimit).toList();
    final primaryCol = AsterTheme.primary(context);

    return SoftClayCard(
      key: const Key('shop_transactions_ledger_card'),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 900 ? 22 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho + abas de separação (Todos / Conquistados / Investidos)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width >= 900
                      ? 520
                      : MediaQuery.sizeOf(context).width - 64,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryCol.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long_rounded, size: 19, color: primaryCol),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Livro de transações (${ShopService.currencyName})',
                            style: GoogleFonts.manrope(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AsterTheme.text(context),
                            ),
                          ),
                          Text(
                            'Acompanhe separadamente suas conquistas nos estudos e investimentos na Loja',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              color: AsterTheme.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AsterTheme.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(color: AsterTheme.surfaceInset(context)),
                ),
                child: Wrap(
                  spacing: 4,
                  children: [
                    _buildTxFilterPill(
                      context,
                      key: const Key('transactions_filter_all'),
                      filter: _TransactionFilter.all,
                      label: 'Todos (${transactions.length})',
                      activeColor: primaryCol,
                    ),
                    _buildTxFilterPill(
                      context,
                      key: const Key('transactions_filter_earned'),
                      filter: _TransactionFilter.earned,
                      label: 'Conquistados (${earnedList.length})',
                      icon: Icons.south_west_rounded,
                      activeColor: AsterConstants.menta,
                    ),
                    _buildTxFilterPill(
                      context,
                      key: const Key('transactions_filter_spent'),
                      filter: _TransactionFilter.spent,
                      label: 'Investidos (${spentList.length})',
                      icon: Icons.north_east_rounded,
                      activeColor: AsterConstants.coral,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Painel de resumo financeiro (Conquistas vs Investimentos vs Saldo)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final tiles = [
                _buildLedgerSummaryTile(
                  context,
                  key: const Key('ledger_summary_earned'),
                  label: 'CONQUISTADOS NOS ESTUDOS',
                  amountText: '+$totalEarned',
                  subtitle:
                      '${earnedList.length} ${earnedList.length == 1 ? 'recompensa' : 'recompensas'} recebidas',
                  accent: AsterConstants.menta,
                  icon: Icons.trending_up_rounded,
                ),
                _buildLedgerSummaryTile(
                  context,
                  key: const Key('ledger_summary_spent'),
                  label: 'INVESTIDOS NA LOJA',
                  amountText: totalSpent > 0 ? '-$totalSpent' : '0',
                  subtitle:
                      '${spentList.length} ${spentList.length == 1 ? 'resgate realizado' : 'resgates realizados'}',
                  accent: AsterConstants.coral,
                  icon: Icons.shopping_bag_outlined,
                ),
                _buildLedgerSummaryTile(
                  context,
                  key: const Key('ledger_summary_balance'),
                  label: 'SALDO DISPONÍVEL',
                  amountText: '$currentBalance',
                  subtitle: 'Pronto para usar na Loja',
                  accent: primaryCol,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ];

              if (isCompact) {
                return Column(
                  children: [
                    for (int i = 0; i < tiles.length; i++) ...[
                      tiles[i],
                      if (i < tiles.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    Expanded(child: tiles[i]),
                    if (i < tiles.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Lista de movimentações filtradas
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    _txFilter == _TransactionFilter.spent
                        ? Icons.shopping_bag_outlined
                        : Icons.auto_awesome_outlined,
                    size: 18,
                    color: AsterTheme.textMuted(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _txFilter == _TransactionFilter.spent
                          ? 'Nenhum investimento realizado ainda — explore os temas e o Selo de Consistência acima.'
                          : 'Nenhuma conquista registrada neste filtro ainda.',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                border: Border.all(color: AsterTheme.surfaceInset(context)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 58,
                        endIndent: 14,
                        color: AsterTheme.surfaceInset(context),
                      ),
                    _buildTransactionRow(context, visible[i]),
                  ],
                ],
              ),
            ),

          if (filtered.length > initialLimit) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                key: const Key('transactions_toggle_expand'),
                onPressed: () =>
                    setState(() => _showAllTransactions = !_showAllTransactions),
                icon: Icon(
                  _showAllTransactions
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(
                  _showAllTransactions
                      ? 'Mostrar menos'
                      : 'Ver todas as movimentações (${filtered.length})',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTxFilterPill(
    BuildContext context, {
    required Key key,
    required _TransactionFilter filter,
    required String label,
    required Color activeColor,
    IconData? icon,
  }) {
    final selected = _txFilter == filter;
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      onTap: () => setState(() {
        _txFilter = filter;
        _showAllTransactions = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: selected ? activeColor : AsterTheme.textMuted(context),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? activeColor : AsterTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSummaryTile(
    BuildContext context, {
    required Key key,
    required String label,
    required String amountText,
    required String subtitle,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                amountText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(width: 6),
              const InsightCoinIcon(size: 15),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AsterTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  ({String category, IconData icon}) _resolveTransactionMeta(ShopTransaction tx) {
    final descLower = tx.description.toLowerCase();
    if (descLower.contains('no grupo')) {
      return (category: 'Grupo', icon: Icons.groups_rounded);
    }
    if (tx.reference == 'streak_protector') {
      return (category: 'Selo de Consistência', icon: Icons.verified_outlined);
    }
    if (tx.reference.startsWith('theme:')) {
      return (category: 'Tema', icon: Icons.palette_outlined);
    }
    switch (tx.source) {
      case 'quiz_answer':
      case 'quiz_question':
      case 'quiz_complete':
      case 'exam_complete':
        return (category: 'Simulado', icon: Icons.quiz_outlined);
      case 'flashcard_review':
      case 'flashcard_hard_redeemed':
      case 'flashcard_redeem':
        return (category: 'Flashcard', icon: Icons.style_outlined);
      case 'notebook_review':
        return (category: 'Caderno', icon: Icons.menu_book_outlined);
      case 'daily_goal':
      case 'weekly_goal':
      case 'streak_milestone':
      case 'streak':
        return (category: 'Meta & Consistência', icon: Icons.track_changes_rounded);
      case 'ranking_reward':
        return (category: 'Ranking', icon: Icons.emoji_events_outlined);
      case 'achievement':
        return (category: 'Conquista', icon: Icons.military_tech_rounded);
      case 'theme_purchase':
        return (category: 'Tema', icon: Icons.palette_outlined);
      case 'streak_protector_purchase':
      case 'streak_protector':
        return (category: 'Selo de Consistência', icon: Icons.verified_outlined);
      default:
        return tx.amount >= 0
            ? (category: 'Conquista', icon: Icons.auto_awesome_outlined)
            : (category: 'Resgate', icon: Icons.shopping_bag_outlined);
    }
  }

  String _formatTransactionTime(DateTime dt) {
    final now = ShopService.currentNow();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(dt.year, dt.month, dt.day);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (txDay == today) return 'Hoje · $hh:$mm';
    if (txDay == today.subtract(const Duration(days: 1))) return 'Ontem · $hh:$mm';
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$dd/$mo · $hh:$mm';
  }

  Widget _buildTransactionRow(BuildContext context, ShopTransaction tx) {
    final isFreeSeal = tx.amount == 0 && tx.reference == 'streak_protector';
    final isEarned = tx.amount >= 0;
    final color = isEarned ? AsterConstants.menta : AsterConstants.coral;
    final meta = _resolveTransactionMeta(tx);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(meta.icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AsterTheme.text(context),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        meta.category,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                    Text(
                      '${isFreeSeal ? 'Recompensa gratuita' : (isEarned ? 'Conquista' : 'Investimento')} · ${_formatTransactionTime(tx.createdAt)}',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            ),
            child: isFreeSeal
                ? Text(
                    '+1 Selo',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isEarned ? '+' : ''}${tx.amount}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const InsightCoinIcon(size: 13),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, _ShopFilter filter, String label) {
    final selected = _filter == filter;
    return SoftClayChoiceChip(
      label: label,
      selected: selected,
      showCheckmark: true,
      onTap: () => setState(() => _filter = filter),
    );
  }

  Widget _buildEarnMethodTile(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required List<({String label, String value})> rules,
    String? actionLabel,
    VoidCallback? onAction,
    bool pushActionToBottom = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
        border: Border.all(color: AsterTheme.surfaceInset(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: pushActionToBottom ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < rules.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rules[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: AsterTheme.textMuted(context),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AsterTheme.card(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(color: AsterTheme.surfaceInset(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const InsightCoinIcon(size: 11),
                      const SizedBox(width: 4),
                      Text(
                        rules[i].value,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AsterTheme.text(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            if (pushActionToBottom) const Spacer(),
            const SizedBox(height: 10),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 13, color: accent),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showThemePreviewModal(
    BuildContext context, {
    required NoesisThemeOption option,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ThemePreviewModal(
        option: option,
        onPurchase: () => _handlePurchase(option),
      ),
    );
  }

  Widget _buildSectionTab(
    BuildContext context, {
    required _ShopSection section,
    required Key key,
    required IconData icon,
    required String label,
    bool expand = false,
  }) {
    final selected = _section == section;
    final primaryCol = AsterTheme.primary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: () => setState(() => _section = section),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: expand ? 12 : 15,
            vertical: expand ? 10 : 9,
          ),
          decoration: BoxDecoration(
            color: selected ? primaryCol : AsterTheme.card(context),
            borderRadius: BorderRadius.circular(
              expand ? AsterConstants.radiusMedium : AsterConstants.radiusPill,
            ),
            border: Border.all(
              color: selected ? primaryCol : AsterTheme.surfaceInset(context),
            ),
            boxShadow: selected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AsterConstants.claySubtleDarkShadow
                    : AsterConstants.claySubtleShadow)
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: expand ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AsterTheme.onPrimary(context) : AsterTheme.textMuted(context),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: expand ? 12 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? AsterTheme.onPrimary(context) : AsterTheme.text(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    Widget? customIcon,
    required Color accent,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final iconBox = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: customIcon ?? Icon(icon, size: 19, color: accent),
      ),
    );
    final badgePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
      ),
      child: Text(
        badge,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconBox,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AsterTheme.text(context),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              badgePill,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AsterTheme.textMuted(context),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconBox,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: AsterTheme.text(context),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AsterTheme.textMuted(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        badgePill,
      ],
    );
  }

  Widget _buildStreakProtectorCard(BuildContext context, {required int balance}) {
    final shop = ShopService.instance;
    final shields = shop.streakProtectors;
    final protectedDaysCount = shop.protectedStreakDates.length;
    final isVip = SupabaseService.isCurrentUserVip;
    const price = InsightsEconomyConfig.streakProtectorPrice;
    final maxShields = shop.maxStreakProtectors;
    final monthlyFreeCount = shop.monthlyFreeVipProtectorsReceivedThisMonth;
    final isFull = shields >= maxShields;
    final canAfford = balance >= price;
    final secondaryCol = AsterTheme.secondary(context);
    final mutedCol = AsterTheme.textMuted(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final balanceProgress = (balance / price).clamp(0.0, 1.0);

    final ctaButton = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const Key('shop_buy_streak_protector'),
        onPressed: isFull ? null : _handleStreakProtectorPurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFull
              ? AsterTheme.surfaceAlt(context)
              : (canAfford ? secondaryCol : AsterTheme.surfaceAlt(context)),
          foregroundColor: isFull
              ? mutedCol
              : (canAfford ? AsterTheme.onPrimary(context) : mutedCol),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          ),
        ),
        child: isFull
            ? Text(
                'Estoque cheio ($maxShields/$maxShields)',
                style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!canAfford) ...[
                    const InsightCoinIcon(size: 15),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    canAfford ? 'Guardar selo' : 'Precisa de $price',
                    style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
      ),
    );

    final slotsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELO DE CONSISTÊNCIA',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: mutedCol,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          key: const Key('shop_streak_protector_inventory'),
          text: TextSpan(
            children: [
              TextSpan(
                text: '$shields',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AsterTheme.text(context),
                ),
              ),
              TextSpan(
                text: '/$maxShields',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: mutedCol.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Text(
          'guardados',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: mutedCol,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (int i = 0; i < maxShields; i++)
              ConsistencySlotRing(
                filled: i < shields,
                size: maxShields > 5 ? 20 : 25,
                strokeWidth: 2.1,
                activeColor: secondaryCol,
                emptyColor: mutedCol,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Cada vaga guarda 1 selo.',
          style: GoogleFonts.manrope(fontSize: 11, color: mutedCol),
        ),
        if (protectedDaysCount > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: secondaryCol.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            ),
            child: Text(
              '$protectedDaysCount ${protectedDaysCount == 1 ? 'dia protegido' : 'dias protegidos'}',
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: secondaryCol,
              ),
            ),
          ),
        ],
      ],
    );

    final previewColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMO APARECE NA SUA CONSISTÊNCIA',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: mutedCol,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          width: double.infinity,
          child: CustomPaint(
            painter: _ConsistencySealPreviewPainter(
              activeColor: secondaryCol,
              emptyColor: insetCol,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: insetCol,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text('sem estudo', style: GoogleFonts.manrope(fontSize: 10.5, color: mutedCol)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: secondaryCol,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text('estudou', style: GoogleFonts.manrope(fontSize: 10.5, color: mutedCol)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConsistencySlotRing(
                  filled: true,
                  size: 10,
                  strokeWidth: 1.8,
                  activeColor: secondaryCol,
                ),
                const SizedBox(width: 5),
                Text('dia protegido', style: GoogleFonts.manrope(fontSize: 10.5, color: mutedCol)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Passou um dia sem estudar? O selo entra sozinho e preenche a lacuna, então sua sequência continua.',
          style: GoogleFonts.manrope(
            fontSize: 11.5,
            height: 1.4,
            color: mutedCol,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          key: const Key('shop_free_seals_info_box'),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: secondaryCol.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
            border: Border.all(color: secondaryCol.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 13, color: secondaryCol),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'COMO GANHAR SELOS GRÁTIS (MÁX. $maxShields GUARDADOS)',
                      style: GoogleFonts.manrope(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: secondaryCol,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.quiz_outlined, size: 13, color: AsterTheme.text(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '+1 selo grátis a cada 100 questões respondidas',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AsterTheme.text(context),
                      ),
                    ),
                  ),
                  Text(
                    '${shop.questionsTowardNextFreeProtector}/100',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: secondaryCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 13, color: AsterTheme.text(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '+1 selo grátis a cada 10h estudadas na semana',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AsterTheme.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final priceColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREÇO',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: mutedCol,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$price',
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: AsterTheme.text(context),
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: InsightCoinIcon(size: 16),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'Insights',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: mutedCol,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Seu saldo', style: GoogleFonts.manrope(fontSize: 11, color: mutedCol)),
            Text(
              '$balance / $price',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: canAfford ? secondaryCol : mutedCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: balanceProgress,
            minHeight: 4,
            backgroundColor: insetCol,
            valueColor: AlwaysStoppedAnimation<Color>(secondaryCol),
          ),
        ),
        const SizedBox(height: 12),
        ctaButton,
        const SizedBox(height: 8),
        Text(
          'Ganhe Insights estudando em Simulados e Flashcards.',
          style: GoogleFonts.manrope(fontSize: 10.5, height: 1.35, color: mutedCol),
        ),
      ],
    );

    return SoftClayCard(
      key: const Key('shop_streak_protector_card'),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 900 ? 22 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    slotsColumn,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: insetCol),
                    ),
                    previewColumn,
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: insetCol),
                    ),
                    priceColumn,
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 210, child: slotsColumn),
                    VerticalDivider(width: 36, thickness: 1, color: insetCol),
                    Expanded(flex: 5, child: previewColumn),
                    VerticalDivider(width: 36, thickness: 1, color: insetCol),
                    SizedBox(width: 210, child: priceColumn),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: insetCol),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _protectorTag(context, Icons.bolt_rounded, 'Ativação automática'),
              _protectorTag(context, Icons.donut_large_rounded, 'Preserva sua consistência'),
              InkWell(
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                onTap: isVip ? null : () => showVipPrivilegesModal(context),
                child: Container(
                  key: const Key('shop_streak_protector_vip_perk_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVip
                        ? AsterVipColors.gold.withValues(alpha: 0.16)
                        : AsterTheme.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    border: Border.all(
                      color: AsterVipColors.gold.withValues(alpha: isVip ? 0.55 : 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const VipCrownIcon(size: 11),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isVip
                              ? 'VIP ativo: até 10 guardados · $monthlyFreeCount/2 grátis no mês'
                              : 'VIP: até 10 guardados (2×) + 2 grátis/mês',
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isVip ? AsterVipColors.goldDark : mutedCol,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _protectorTag(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AsterTheme.surfaceAlt(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AsterTheme.surfaceInset(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AsterTheme.textMuted(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AsterTheme.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapGrid(
    BuildContext context, {
    required List<({IconData icon, Color accent, String title, String description, String priceLabel})> items,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
        const gap = 12.0;
        final cardW = (w - (cols - 1) * gap) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            return SizedBox(
              width: cardW,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AsterTheme.card(context),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  border: Border.all(color: AsterTheme.surfaceInset(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: item.accent.withValues(alpha: 0.25)),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: item.accent,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.text(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AsterTheme.surfaceAlt(context),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: Text(
                                  'Em breve',
                                  style: GoogleFonts.manrope(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.textMuted(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              height: 1.38,
                              color: AsterTheme.textMuted(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (RegExp(r'\d').hasMatch(item.priceLabel)) ...[
                                const InsightCoinIcon(size: 12),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                item.priceLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildShopThemeCard(
    BuildContext context, {
    required NoesisThemeOption option,
    required int price,
    required bool unlocked,
    required bool equipped,
    required int balance,
  }) {
    final canAfford = balance >= price;
    final swatches = <Color>[
      option.bg,
      option.surface,
      option.primary,
      ...option.accents.take(3),
    ];
    final tierName = InsightsEconomyConfig.tierLabel(
      InsightsEconomyConfig.tierForTheme(option.id),
    );

    return SoftClayCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('shop_card_${option.id}'),
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          onTap: () => _showThemePreviewModal(context, option: option),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini preview com as cores reais do tema + faixa de tier
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: option.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: equipped
                          ? option.primary
                          : option.primary.withValues(alpha: 0.35),
                      width: equipped ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: option.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(option.icon, size: 18, color: option.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.name,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: option.textColor,
                              ),
                            ),
                            Text(
                              option.tag,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: option.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: option.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          tierName,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: option.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Pré-visualizar tema',
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: option.mutedColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  option.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: swatches
                          .map(
                            (c) => Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black.withValues(alpha: 0.14)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    if (equipped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AsterTheme.primary(context).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Em uso',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AsterTheme.primary(context),
                          ),
                        ),
                      )
                    else if (unlocked)
                      ElevatedButton(
                        key: Key('shop_equip_${option.id}'),
                        onPressed: () => AsterTheme.selectThemeOption(option.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AsterTheme.primary(context),
                          foregroundColor: AsterTheme.onPrimary(context),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Equipar',
                          style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      ElevatedButton(
                        key: Key('shop_buy_${option.id}'),
                        onPressed: () => _handlePurchase(option),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford
                              ? AsterConstants.ambar
                              : AsterTheme.surfaceAlt(context),
                          foregroundColor: canAfford
                              ? const Color(0xFF141218)
                              : AsterTheme.textMuted(context),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const InsightCoinIcon(size: 13),
                            const SizedBox(width: 5),
                            Text(
                              canAfford ? 'Comprar · $price' : '$price',
                              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVipCustomThemeCard(
    BuildContext context, {
    required bool isVip,
    required bool equipped,
  }) {
    final customOpt = AsterTheme.customThemeColorsNotifier.value.toNoesisThemeOption();
    return SoftClayCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('shop_card_${customOpt.id}'),
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          onTap: () => _showThemePreviewModal(context, option: customOpt),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: customOpt.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: customOpt.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(customOpt.icon, size: 18, color: customOpt.primary),
                      ),
                      const SizedBox(width: 10),
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
                                  customOpt.name,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: customOpt.textColor,
                                  ),
                                ),
                                const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                              ],
                            ),
                            Text(
                              'VIP · Escolha as 6 cores RGB',
                              style: GoogleFonts.manrope(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: customOpt.mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Pré-visualizar tema',
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: customOpt.mutedColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tema exclusivo para apoiadores VIP com editor RGB completo em Configurações.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () {
                      if (isVip) {
                        RootScreen.switchTab(6);
                      } else {
                        showVipPrivilegesModal(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AsterVipColors.goldDark,
                      side: BorderSide(color: AsterVipColors.gold.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isVip ? (equipped ? 'Editar em Config' : 'Abrir Editor RGB') : 'Exclusivo VIP',
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
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

  Widget _buildLegendaryConquestCard(BuildContext context) {
    return SoftClayCard(
      key: const Key('shop_legendary_card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF151424),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AsterConstants.lavanda.withValues(alpha: 0.55)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AsterVipColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AsterVipColors.gold.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, size: 18, color: AsterVipColors.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temas Especiais',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Especiais · só por conquista',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFA7AAD0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Temas especiais desbloqueados por grandes marcos (ex.: 30 dias de streak) na Fase 2.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              height: 1.4,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Só por conquista',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AsterTheme.textMuted(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityStoreSection(
    BuildContext context, {
    required ShopService shop,
    required bool isVip,
    required Color primaryCol,
  }) {
    final allInCat = ProfileCosmeticsCatalog.byCategory(_identityCategory);
    final items = _identityVipOnlyFilter
        ? allInCat.where((i) => i.isVipOnly).toList()
        : allInCat;

    return Column(
      key: const Key('shop_identity_store_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SoftClayChoiceChip(
              key: const Key('shop_identity_tab_banner'),
              label: 'Capas (${ProfileCosmeticsCatalog.banners.length})',
              icon: Icons.gradient_rounded,
              selected: _identityCategory == ProfileCosmeticCategory.banner,
              compact: true,
              onTap: () => setState(() => _identityCategory = ProfileCosmeticCategory.banner),
            ),
            SoftClayChoiceChip(
              key: const Key('shop_identity_tab_frame'),
              label: 'Molduras (${ProfileCosmeticsCatalog.frames.length})',
              icon: Icons.blur_circular_rounded,
              selected: _identityCategory == ProfileCosmeticCategory.frame,
              compact: true,
              onTap: () => setState(() => _identityCategory = ProfileCosmeticCategory.frame),
            ),
            SoftClayChoiceChip(
              key: const Key('shop_identity_tab_title'),
              label: 'Títulos (${ProfileCosmeticsCatalog.titles.length})',
              icon: Icons.workspace_premium_rounded,
              selected: _identityCategory == ProfileCosmeticCategory.title,
              compact: true,
              onTap: () => setState(() => _identityCategory = ProfileCosmeticCategory.title),
            ),
            SoftClayChoiceChip(
              key: const Key('shop_identity_filter_vip'),
              label: 'Exclusivos VIP',
              icon: Icons.workspace_premium_rounded,
              selected: _identityVipOnlyFilter,
              accentColor: AsterVipColors.goldDark,
              compact: true,
              onTap: () => setState(() => _identityVipOnlyFilter = !_identityVipOnlyFilter),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
            const gap = 14.0;
            final cardW = (w - (cols - 1) * gap) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: items.map((item) {
                final unlocked = shop.isProfileItemUnlocked(item.id);
                final equipped = shop.isProfileItemEquipped(item);
                return SizedBox(
                  width: cardW,
                  child: _buildIdentityCosmeticCard(
                    context,
                    item: item,
                    unlocked: unlocked,
                    equipped: equipped,
                    isVip: isVip,
                    primaryCol: primaryCol,
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        SoftClayCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.military_tech_rounded, size: 18, color: primaryCol),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Depois de desbloquear Capas, Molduras ou Títulos aqui, troque quando quiser em Perfil -> Editar.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityCosmeticCard(
    BuildContext context, {
    required ProfileCosmeticItem item,
    required bool unlocked,
    required bool equipped,
    required bool isVip,
    required Color primaryCol,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vipAccent = AsterVipColors.goldDark;
    final cardBorder = equipped
        ? AsterConstants.menta.withValues(alpha: 0.68)
        : item.isVipOnly
            ? AsterVipColors.gold.withValues(alpha: 0.55)
            : (isDark ? Colors.white : item.accentColor).withValues(alpha: isDark ? 0.08 : 0.16);

    return SoftClayCard(
      key: Key('shop_identity_card_${item.id}'),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
          border: Border.all(color: cardBorder, width: equipped ? 1.6 : 1.1),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _identityCosmeticPreview(context, item: item),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AsterTheme.text(context),
                  ),
                ),
              ),
              if (item.isVipOnly) ...[
                const SizedBox(width: 6),
                const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: equipped
                ? Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AsterConstants.menta.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Text(
                      'Equipado',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AsterConstants.menta,
                      ),
                    ),
                  )
                : OutlinedButton(
                    key: Key('shop_identity_btn_${item.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      side: BorderSide(
                        color: (item.isVipOnly && !isVip
                                ? AsterVipColors.gold
                                : unlocked
                                    ? primaryCol
                                    : item.accentColor)
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    onPressed: () => _handleProfileCosmeticAction(item),
                    child: item.isVipOnly && !isVip
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const VipCrownIcon(size: 13),
                              const SizedBox(width: 5),
                              Text(
                                'Exclusivo VIP',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: vipAccent,
                                ),
                              ),
                            ],
                          )
                        : unlocked || item.isFree
                            ? Text(
                                item.isVipOnly ? 'Equipar VIP' : 'Equipar',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: item.isVipOnly ? vipAccent : primaryCol,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const InsightCoinIcon(size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${item.price} Insights',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: item.accentColor,
                                    ),
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

  Widget _identityCosmeticPreview(BuildContext context, {required ProfileCosmeticItem item}) {
    if (item.category == ProfileCosmeticCategory.banner) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: item.gradientColors.isEmpty
              ? LinearGradient(
                  colors: [
                    AsterTheme.primary(context).withValues(alpha: 0.18),
                    AsterConstants.menta.withValues(alpha: 0.18),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.gradientColors,
                ),
        ),
      );
    }
    if (item.category == ProfileCosmeticCategory.frame) {
      return SizedBox(
        height: 44,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: item.gradientColors.isEmpty
                  ? null
                  : LinearGradient(colors: item.gradientColors),
              border: item.gradientColors.isEmpty
                  ? Border.all(color: item.accentColor.withValues(alpha: 0.5), width: 2)
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AsterTheme.card(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded, size: 17, color: item.accentColor),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: item.accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            border: Border.all(color: item.accentColor.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 13.5, color: item.accentColor),
              const SizedBox(width: 5),
              Text(
                item.name,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: item.accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewModal extends StatefulWidget {
  final NoesisThemeOption option;
  final Future<void> Function() onPurchase;

  const _ThemePreviewModal({
    required this.option,
    required this.onPurchase,
  });

  @override
  State<_ThemePreviewModal> createState() => _ThemePreviewModalState();
}

class _ThemePreviewModalState extends State<_ThemePreviewModal> {
  late NoesisCustomThemeColors _previewCustomColors;
  bool _showRgbEditor = false;
  int _selectedRgbSlot = 2; // Começa selecionando Primária

  @override
  void initState() {
    super.initState();
    _previewCustomColors = AsterTheme.customThemeColorsNotifier.value;
  }

  static String _hex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final shop = ShopService.instance;
    final compact = MediaQuery.sizeOf(context).width < 640;
    final isCustom = widget.option.id == AsterTheme.customThemeId;

    return ListenableBuilder(
      listenable: Listenable.merge([
        shop.balanceNotifier,
        shop.unlockedThemesNotifier,
        AsterTheme.activeThemeIdNotifier,
        SupabaseService.isVipNotifier,
      ]),
      builder: (context, _) {
        final option = isCustom
            ? _previewCustomColors.toNoesisThemeOption()
            : widget.option;
        final isVip = SupabaseService.isCurrentUserVip;
        final unlocked = shop.isThemeUnlocked(option.id);
        final equipped = AsterTheme.activeThemeIdNotifier.value == option.id;
        final price = shop.priceForTheme(option.id);
        final balance = shop.balance;
        final canAfford = balance >= price;

        final accent1 = option.accents.isNotEmpty ? option.accents[0] : option.primary;
        final accent2 = option.accents.length > 1 ? option.accents[1] : option.primary;
        final accent3 = option.accents.length > 2 ? option.accents[2] : AsterConstants.coral;

        final swatchEntries = [
          (label: 'Fundo', color: option.bg),
          (label: 'Cartões', color: option.surface),
          (label: 'Primária', color: option.primary),
          (label: 'Acento 1', color: accent1),
          (label: 'Acento 2', color: accent2),
          (label: 'Acento 3', color: accent3),
        ];

        return Dialog(
          key: const Key('shop_theme_preview_modal'),
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 28,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740, maxHeight: 780),
            child: Container(
              decoration: BoxDecoration(
                color: AsterTheme.card(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
                border: Border.all(color: AsterTheme.surfaceInset(context)),
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? AsterConstants.clayDarkShadow
                    : AsterConstants.clayShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabeçalho da modal
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AsterConstants.radiusLarge),
                      ),
                      border: Border(
                        bottom: BorderSide(color: AsterTheme.surfaceInset(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: option.bg,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: option.primary.withValues(alpha: 0.45)),
                          ),
                          child: Icon(option.icon, size: 19, color: option.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Pré-visualização · ${option.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                  ),
                                  if (isCustom) ...[
                                    const SizedBox(width: 8),
                                    const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                                  ],
                                ],
                              ),
                              Text(
                                '${option.tag} · ${option.description}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: AsterTheme.textMuted(context)),
                        ),
                      ],
                    ),
                  ),

                  // Conteúdo rolável: Mockup ao vivo do Noesis com o template + paleta
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mini interface do Noesis renderizada exatamente nas cores do tema
                          Container(
                            key: const Key('preview_mockup_canvas'),
                            decoration: BoxDecoration(
                              color: option.bg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: option.primary.withValues(alpha: 0.35),
                                width: 1.4,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!compact)
                                  Container(
                                    width: 164,
                                    padding: const EdgeInsets.all(14),
                                    color: option.surface,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: option.primary,
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                              child: Icon(
                                                Icons.visibility_rounded,
                                                size: 14,
                                                color: option.onPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Noesis',
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: option.textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: option.primary,
                                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.home_rounded, size: 13, color: option.onPrimary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Dashboard',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: option.onPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _mockSidebarItem(option, Icons.assignment_rounded, 'Simulados'),
                                        const SizedBox(height: 4),
                                        _mockSidebarItem(option, Icons.style_rounded, 'Flashcards'),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            color: option.surface2,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'META SEMANAL',
                                                style: GoogleFonts.manrope(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: option.mutedColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: 0.68,
                                                  minHeight: 5,
                                                  backgroundColor: option.bg,
                                                  valueColor: AlwaysStoppedAnimation(accent1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Bom dia, Estudante.',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: option.textColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    '7 dias de streak · Foco ativo',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 10.5,
                                                      color: option.mutedColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: option.surface,
                                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                border: Border.all(color: accent2.withValues(alpha: 0.5)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const InsightCoinIcon(size: 12),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '240',
                                                    style: GoogleFonts.jetBrainsMono(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: accent2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Cards simulados no mockup
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: option.surface,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Revisões Hoje',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: option.mutedColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '18 cards',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800,
                                                        color: option.textColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: accent1.withValues(alpha: 0.16),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '84% retenção',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: accent1,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: option.surface,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Simulado Ativo',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: option.mutedColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '30 questões',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800,
                                                        color: option.textColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: accent3.withValues(alpha: 0.16),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'Prazo: Amanhã',
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: accent3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Barra inferior de ação/busca no mockup
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: option.surface,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: option.surface2,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Pesquisar baralho ou caderno...',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 10.5,
                                                      color: option.mutedColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                decoration: BoxDecoration(
                                                  color: option.primary,
                                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                                ),
                                                child: Text(
                                                  'Iniciar Sessão',
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: option.onPrimary,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Paleta das 6 cores do template
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isCustom
                                    ? 'PALETA DO TEMPLATE · TOQUE PARA EDITAR'
                                    : 'PALETA DO TEMPLATE',
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                              if (isCustom)
                                TextButton.icon(
                                  key: const Key('preview_toggle_rgb_button'),
                                  onPressed: () {
                                    setState(() => _showRgbEditor = !_showRgbEditor);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AsterVipColors.goldDark,
                                    backgroundColor: AsterVipColors.gold.withValues(alpha: 0.14),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: AsterVipColors.gold.withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    _showRgbEditor ? Icons.expand_less_rounded : Icons.tune_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    _showRgbEditor ? 'Ocultar RGB' : 'Editar RGB ao vivo',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(swatchEntries.length, (idx) {
                              final entry = swatchEntries[idx];
                              final isActiveSwatch = isCustom && _showRgbEditor && _selectedRgbSlot == idx;
                              final chip = AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isActiveSwatch
                                      ? AsterVipColors.gold.withValues(alpha: 0.14)
                                      : AsterTheme.surfaceAlt(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isActiveSwatch
                                        ? AsterVipColors.gold
                                        : AsterTheme.surfaceInset(context),
                                    width: isActiveSwatch ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: entry.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black.withValues(alpha: 0.16)),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      '${entry.label} ',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AsterTheme.text(context),
                                      ),
                                    ),
                                    Text(
                                      _hex(entry.color),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (!isCustom) return chip;
                              return InkWell(
                                key: Key('preview_swatch_$idx'),
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _selectedRgbSlot = idx;
                                    _showRgbEditor = true;
                                  });
                                },
                                child: chip,
                              );
                            }),
                          ),
                          if (isCustom && _showRgbEditor)
                            VipRgbThemeEditor(
                              colors: _previewCustomColors,
                              selectedSlot: _selectedRgbSlot,
                              onSlotSelected: (slot) {
                                setState(() => _selectedRgbSlot = slot);
                              },
                              margin: const EdgeInsets.only(top: 14),
                              title: 'Prévia RGB em Tempo Real (6 Cores)',
                              onChanged: (nextColors) {
                                setState(() => _previewCustomColors = nextColors);
                              },
                              onReset: () {
                                setState(() {
                                  _previewCustomColors = NoesisCustomThemeColors.defaults;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Rodapé com ação direta de comprar / equipar / VIP
                  Container(
                    padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 12, compact ? 14 : 20, 14),
                    decoration: BoxDecoration(
                      color: AsterTheme.surfaceAlt(context),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AsterConstants.radiusLarge),
                      ),
                      border: Border(
                        top: BorderSide(color: AsterTheme.surfaceInset(context)),
                      ),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!isCustom)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const InsightCoinIcon(size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Seu saldo: $balance ${ShopService.currencyName}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ],
                          )
                        else if (!compact)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              isVip
                                  ? 'Edite as cores acima e salve no tema VIP.'
                                  : 'Teste sua paleta RGB ao vivo na prévia acima.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AsterTheme.textMuted(context),
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Fechar',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AsterTheme.textMuted(context),
                                ),
                              ),
                            ),
                            if (isCustom) ...[
                              if (!_showRgbEditor && !compact)
                                OutlinedButton.icon(
                                  key: const Key('preview_footer_rgb_button'),
                                  onPressed: () {
                                    setState(() => _showRgbEditor = true);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AsterVipColors.goldDark,
                                    side: BorderSide(color: AsterVipColors.gold.withValues(alpha: 0.55)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.tune_rounded, size: 15),
                                  label: Text(
                                    'Abrir RGB',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ElevatedButton(
                                key: isVip ? const Key('preview_apply_custom_button') : null,
                                onPressed: () async {
                                  if (isVip) {
                                    await AsterTheme.updateCustomThemeColors(
                                      _previewCustomColors,
                                      activateIfVip: true,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                  } else {
                                    Navigator.of(context).pop();
                                    showVipPrivilegesModal(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsterVipColors.gold,
                                  foregroundColor: AsterVipColors.inkBase,
                                ),
                                child: Text(
                                  isVip ? 'Salvar e Equipar' : 'Desbloquear VIP',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ] else if (equipped)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: AsterTheme.primary(context).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Em uso',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AsterTheme.primary(context),
                                  ),
                                ),
                              )
                            else if (unlocked)
                              ElevatedButton(
                                key: Key('preview_equip_${option.id}'),
                                onPressed: () {
                                  AsterTheme.selectThemeOption(option.id);
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AsterTheme.primary(context),
                                  foregroundColor: AsterTheme.onPrimary(context),
                                ),
                                child: Text(
                                  'Equipar ${option.name}',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                key: Key('preview_buy_${option.id}'),
                                onPressed: () async {
                                  await widget.onPurchase();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford
                                      ? AsterConstants.ambar
                                      : AsterTheme.card(context),
                                  foregroundColor: canAfford
                                      ? const Color(0xFF141218)
                                      : AsterTheme.textMuted(context),
                                ),
                                icon: Icon(
                                  canAfford
                                      ? Icons.shopping_cart_checkout_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  canAfford
                                      ? 'Comprar por $price ${ShopService.currencySymbol}'
                                      : 'Faltam ${price - balance} ${ShopService.currencySymbol}',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
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
    );
  }

  Widget _mockSidebarItem(NoesisThemeOption opt, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: opt.mutedColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: opt.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsistencySealPreviewPainter extends CustomPainter {
  const _ConsistencySealPreviewPainter({
    required this.activeColor,
    required this.emptyColor,
  });

  final Color activeColor;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    const int cols = 18;
    const int rows = 7;
    final double baseGap = (size.width * 0.01).clamp(3.0, 5.0);
    final double maxWCell = (size.width - baseGap * (cols - 1)) / cols;
    final double maxHCell = (size.height - baseGap * (rows - 1)) / rows;
    final double cellSize = math.min(maxWCell, maxHCell).clamp(6.0, 16.0);
    final double gapX = cols > 1
        ? ((size.width - cols * cellSize) / (cols - 1)).clamp(baseGap, 7.5)
        : baseGap;
    final double gapY = baseGap;

    final double totalW = cols * cellSize + (cols - 1) * gapX;
    final double totalH = rows * cellSize + (rows - 1) * gapY;
    final double offsetX = math.max(0.0, (size.width - totalW) / 2);
    final double offsetY = math.max(0.0, (size.height - totalH) / 2);

    final double stepX = cellSize + gapX;
    final double stepY = cellSize + gapY;
    final double cornerRadius = (cellSize * 0.28).clamp(2.5, 5.0);
    final double ringStroke = (cellSize * 0.14).clamp(1.5, 2.2);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..color = activeColor;

    // Blocos estudados estilizados na direita do mini heatmap (alinhados ao último dia)
    const int lastCol = cols - 1;
    const activeCoords = <(int, int, double)>[
      (lastCol - 4, 2, 0.45),
      (lastCol - 3, 1, 0.7),
      (lastCol - 3, 4, 0.35),
      (lastCol - 2, 2, 0.55),
      (lastCol - 1, 3, 0.7),
      (lastCol - 1, 5, 0.45),
      (lastCol, 0, 0.9),
      (lastCol, 1, 0.75),
      (lastCol, 2, 1.0),
      (lastCol, 4, 0.9),
      (lastCol, 5, 0.75),
      (lastCol, 6, 0.5),
    ];

    for (int col = 0; col < cols; col++) {
      final x = offsetX + col * stepX;
      for (int row = 0; row < rows; row++) {
        final y = offsetY + row * stepY;
        final rect = Rect.fromLTWH(x, y, cellSize, cellSize);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));

        if (col == lastCol && row == 3) {
          fillPaint.color = activeColor.withValues(alpha: 0.14);
          canvas.drawRRect(rrect, fillPaint);
          canvas.drawRRect(rrect.deflate(ringStroke / 2), ringPaint);
          continue;
        }
        double? intensity;
        for (final entry in activeCoords) {
          if (entry.$1 == col && entry.$2 == row) {
            intensity = entry.$3;
            break;
          }
        }
        fillPaint.color = intensity != null
            ? activeColor.withValues(alpha: intensity)
            : emptyColor.withValues(alpha: 0.85);
        canvas.drawRRect(rrect, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConsistencySealPreviewPainter oldDelegate) =>
      oldDelegate.activeColor != activeColor || oldDelegate.emptyColor != emptyColor;
}
