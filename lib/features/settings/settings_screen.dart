import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/localization/noesis_l10n.dart';
import '../../core/localization/noesis_locale_service.dart';
import '../../core/theme.dart';
import '../../core/gemini_service.dart';
import '../../core/shop_service.dart';
import '../../core/supabase_service.dart';
import '../../main.dart';
import '../../widgets/country_flag_icon.dart';
import '../../widgets/vip_privileges.dart';
import '../../widgets/vip_rgb_theme_editor.dart';
import '../../widgets/weekly_goal_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedProviderId = 'google';
  String _selectedModel = 'gemini-flash-lite-latest';
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _obscureApiKey = true;
  bool _isTestingKey = false;
  String? _testResult;
  bool? _testSuccess;
  bool _isManualModelMode = false;
  List<String> _dynamicGoogleModels = List<String>.from(GeminiService.operationalGoogleModels);
  bool _isCheckingOperationalModels = false;
  Timer? _debounceTimer;

  List<NoesisLanguageOption> get _languages =>
      NoesisLocaleService.supportedLanguages;

  @override
  void initState() {
    super.initState();
    _selectedProviderId = GeminiService.provider;
    _selectedModel = GeminiService.model;
    _modelController.text = _selectedModel;
    _baseUrlController.text = GeminiService.baseUrl;
    if (GeminiService.apiKey != null && GeminiService.apiKey!.isNotEmpty) {
      _apiKeyController.text = GeminiService.apiKey!;
    }
    SupabaseService.loadWeeklyGoalMinutes();
    SupabaseService.loadDailyGoalMinutes();
    final prov = GeminiService.providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () => GeminiService.providers.first,
    );
    if (prov.models.isEmpty || (!prov.models.contains(_selectedModel) && _selectedModel.isNotEmpty)) {
      _isManualModelMode = true;
    }
    _apiKeyController.addListener(_onApiKeyChanged);
    if (_selectedProviderId == 'google' && _apiKeyController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndSyncOperationalModels(_apiKeyController.text.trim());
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _apiKeyController.removeListener(_onApiKeyChanged);
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _onApiKeyChanged() {
    final key = _apiKeyController.text.trim();
    if (_selectedProviderId == 'google' && key.length >= 30) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted && _apiKeyController.text.trim() == key) {
          _checkAndSyncOperationalModels(key);
        }
      });
    }
  }

  int _getModelCountForProvider(AIProvider p) {
    if (p.id == 'google' && _dynamicGoogleModels.isNotEmpty) {
      return _dynamicGoogleModels.length;
    }
    return p.models.length;
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              persist: false,
              duration: const Duration(seconds: 3),
              backgroundColor: AsterConstants.coral,
              content: Text(
                context.tr('Não foi possível abrir o link: {url}', {'url': url}),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
      }
    }
  }

  void _onSelectProvider(String providerId) {
    final prov = GeminiService.providers.firstWhere(
      (p) => p.id == providerId,
      orElse: () => GeminiService.providers.first,
    );
    setState(() {
      _selectedProviderId = providerId;
      _selectedModel = prov.defaultModel;
      _modelController.text = prov.defaultModel;
      _isManualModelMode = prov.models.isEmpty;
      if (providerId == 'custom' && _baseUrlController.text.isEmpty) {
        _baseUrlController.text = prov.defaultBaseUrl ?? '';
      }
      _testResult = null;
      _testSuccess = null;
    });
  }

  void _onSelectModel(String modelName) {
    setState(() {
      _selectedModel = modelName;
      _modelController.text = modelName;
      _isManualModelMode = false;
      _testResult = null;
      _testSuccess = null;
    });
    GeminiService.configure(
      providerId: _selectedProviderId,
      modelName: modelName,
      key: _apiKeyController.text.trim(),
      customBaseUrl: _baseUrlController.text.trim(),
    );
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingKey = true;
      _testResult = null;
      _testSuccess = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final msg = await GeminiService.testConnection(
        providerId: _selectedProviderId,
        modelName: _modelController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
      );
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isTestingKey = false;
          _testSuccess = true;
          _testResult = '$msg (${stopwatch.elapsedMilliseconds}ms)';
        });
        GeminiService.configure(
          providerId: _selectedProviderId,
          modelName: _modelController.text.trim(),
          key: _apiKeyController.text.trim(),
          customBaseUrl: _baseUrlController.text.trim(),
        );
        if (_selectedProviderId == 'google') {
          _checkAndSyncOperationalModels(_apiKeyController.text.trim());
        }
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isTestingKey = false;
          _testSuccess = false;
          _testResult = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _checkAndSyncOperationalModels(String key, {bool showSuccessSnackbar = false}) async {
    if (_isCheckingOperationalModels || !mounted || key.isEmpty) return;

    setState(() {
      _isCheckingOperationalModels = true;
      _testResult = null;
    });

    try {
      final result = await GeminiService.fetchOperationalGoogleModels(key);
      if (!mounted) return;

      if (result.models.isNotEmpty) {
        setState(() {
          _dynamicGoogleModels = result.models;
          _isCheckingOperationalModels = false;
          _testSuccess = true;
          _testResult = context.tr('{count} modelo(s) validado(s) e 100% operacional(is) para sua conta agora!', {'count': result.models.length});
          if (!result.models.contains(_modelController.text.trim())) {
            _selectedModel = result.models.first;
            _modelController.text = _selectedModel;
          }
          _isManualModelMode = false;
        });

        GeminiService.configure(
          providerId: 'google',
          modelName: _modelController.text.trim(),
          key: key,
        );

        if (showSuccessSnackbar) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                persist: false,
                duration: const Duration(seconds: 3),
                content: Text(
                  context.tr('{count} modelo(s) operacionais prontos: {models}', {
                    'count': result.models.length,
                    'models': result.models.join(', '),
                  }),
                  style: TextStyle(color: AsterTheme.onPrimary(context)),
                ),
                backgroundColor: AsterTheme.primary(context),
              ),
            );
        }
      } else {
        setState(() {
          _isCheckingOperationalModels = false;
          _testSuccess = false;
          _testResult = result.error ?? context.tr('Nenhum modelo Gemini respondeu com sucesso para esta chave.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingOperationalModels = false;
          _testSuccess = false;
          _testResult = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _saveAiSettings() {
    final key = _apiKeyController.text.trim();
    final mod = _modelController.text.trim();
    final url = _baseUrlController.text.trim();

    GeminiService.configure(
      providerId: _selectedProviderId,
      modelName: mod,
      key: key,
      customBaseUrl: url,
    );
    setState(() {});
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 2),
          backgroundColor: AsterTheme.primary(context),
          content: Text(
            context.tr('Configurações de IA salvas com sucesso!'),
            style: TextStyle(color: AsterTheme.onPrimary(context)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 36.0 : 16.0,
        vertical: 18.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Título da Página ───
              Builder(
                builder: (context) {
                  final screenW = MediaQuery.sizeOf(context).width;
                  final contentLeft =
                      ((screenW - 960).clamp(0.0, double.infinity) / 2) + (isDesktop ? 36.0 : 16.0);
                  final neededGap = (108.0 - contentLeft).clamp(0.0, 82.0);
                  return Row(
                    children: [
                      NoesisCollapsedMenuSpacer(width: neededGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Configurações'),
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('Preferências de tema, chave de IA, idiomas do ecossistema e perfil'),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ─── Card 1: Aparência e Tema (Light vs Dark) ───
              _buildThemeSection(isDark),
              const SizedBox(height: 20),

              // ─── Card 2: Meta Semanal de Estudos ───
              _buildWeeklyGoalSection(isDark),
              const SizedBox(height: 20),

              // ─── Card 3: Chave de IA (Google Gemini API Key) ───
              _buildAiKeySection(isDark),
              const SizedBox(height: 20),

              // ─── Card 4: Seleção de Idiomas do Portfólio ───
              _buildLanguageSection(isDark),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. Seção de Aparência e Tema ───
  Widget _buildWeeklyGoalSection(bool isDark) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SupabaseService.weeklyGoalMinutesNotifier,
        SupabaseService.dailyGoalMinutesNotifier,
      ]),
      builder: (context, _) {
        final goalMinutes = SupabaseService.weeklyGoalMinutesNotifier.value;
        final dailyGoalMinutes = SupabaseService.dailyGoalMinutesNotifier.value;
        final hasWeeklyGoal = goalMinutes > 0;
        final hasDailyGoal = dailyGoalMinutes > 0;
        final dailyAvg = (goalMinutes / 7).round();
        return SoftClayCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AsterTheme.secondary(context).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.track_changes_rounded,
                      size: 20,
                      color: AsterTheme.secondary(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Meta Semanal de Estudos'),
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasWeeklyGoal
                              ? context.tr('Meta atual: {goal}/semana · média ~{avg}/dia', {
                                  'goal': SupabaseService.formatGoalDuration(goalMinutes),
                                  'avg': SupabaseService.formatGoalDuration(dailyAvg),
                                })
                              : context.tr('Sem meta semanal definida · modo livre ativo'),
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SoftClayPillButton(
                    key: const Key('settings_edit_weekly_goal_button'),
                    text: hasWeeklyGoal ? context.tr('Editar Meta') : context.tr('Definir Meta'),
                    onPressed: () async {
                      final sessions = await SupabaseService.getStudySessions(limit: 200);
                      final studied = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
                      final studiedToday = SupabaseService.computeTodayStudiedMinutes(sessions);
                      if (!context.mounted) return;
                      await showWeeklyGoalEditorDialog(
                        context,
                        currentWeekStudiedMinutes: studied,
                        currentDayStudiedMinutes: studiedToday,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: AsterTheme.surfaceInset(context)),
              const SizedBox(height: 16),
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
                      Icons.today_rounded,
                      size: 20,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Meta Diária de Estudos'),
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDailyGoal
                              ? context.tr('Meta atual: {goal}/dia · equivalente a ~{weekly}/semana', {
                                  'goal': SupabaseService.formatGoalDuration(dailyGoalMinutes),
                                  'weekly': SupabaseService.formatGoalDuration(dailyGoalMinutes * 7),
                                })
                              : context.tr('Sem meta diária definida · modo livre ativo'),
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SoftClayPillButton(
                    key: const Key('settings_edit_daily_goal_button'),
                    text: hasDailyGoal ? context.tr('Editar Diária') : context.tr('Definir Diária'),
                    onPressed: () async {
                      final sessions = await SupabaseService.getStudySessions(limit: 200);
                      final studied = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
                      final studiedToday = SupabaseService.computeTodayStudiedMinutes(sessions);
                      if (!context.mounted) return;
                      await showDailyGoalEditorDialog(
                        context,
                        currentWeekStudiedMinutes: studied,
                        currentDayStudiedMinutes: studiedToday,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeSection(bool isDark) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AsterTheme.activeThemeIdNotifier,
        AsterTheme.customThemeColorsNotifier,
        SupabaseService.isVipNotifier,
        ShopService.instance.unlockedThemesNotifier,
      ]),
      builder: (context, _) {
        final activeThemeId = AsterTheme.activeThemeIdNotifier.value;
        final isVip = SupabaseService.isCurrentUserVip;
        final customColors = AsterTheme.customThemeColorsNotifier.value;
        final themes = AsterTheme.availableThemesWithCustom;

        final isDesktop = MediaQuery.sizeOf(context).width >= 900;
        return SoftClayCard(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.palette_rounded, size: 20, color: AsterTheme.primary(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Aparência e Tema'),
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        Text(
                          context.tr('Escolha o tema visual para o seu ambiente de estudos'),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final crossAxisCount = availableWidth >= 880
                      ? 4
                      : (availableWidth >= 640
                          ? 3
                          : (availableWidth >= 290 ? 2 : 1));
                  const double spacing = 10;
                  final double itemWidth =
                      (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: themes.map((themeOption) {
                      return SizedBox(
                        width: itemWidth,
                        child: _buildThemeOptionCard(
                          option: themeOption,
                          isSelected: activeThemeId == themeOption.id,
                          isVip: isVip,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              if (isVip && activeThemeId == AsterTheme.customThemeId)
                VipRgbThemeEditor(
                  colors: customColors,
                  onChanged: (next) => AsterTheme.updateCustomThemeColors(
                    next,
                    activateIfVip: true,
                  ),
                  onReset: () => AsterTheme.updateCustomThemeColors(
                    NoesisCustomThemeColors.defaults,
                    activateIfVip: true,
                  ),
                )
              else if (!isVip) ...[
                const SizedBox(height: 14),
                InkWell(
                  key: const Key('custom_theme_vip_lock_banner'),
                  onTap: () => showVipPrivilegesModal(context),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AsterVipColors.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      border: Border.all(
                        color: AsterVipColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const VipCrownIcon(size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('Tema "Personalizado" com escolha livre das 6 cores em RGB liberado somente para VIP.'),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AsterTheme.text(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const VipBadgePill(size: VipBadgeSize.sm, interactive: false),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionCard({
    required NoesisThemeOption option,
    required bool isSelected,
    required bool isVip,
  }) {
    final isCustom = option.id == AsterTheme.customThemeId;
    final isLockedVip = isCustom && !isVip;
    final isLockedShop = !isCustom && !ShopService.instance.isThemeUnlocked(option.id);
    final isLocked = isLockedVip || isLockedShop;
    final price = isLockedShop ? ShopService.instance.priceForTheme(option.id) : 0;
    final accent = option.primary;
    final paletteSwatches = <Color>[
      option.bg,
      option.surface,
      option.primary,
      ...option.accents.take(3),
    ];

    return InkWell(
      key: Key('theme_option_${option.id}'),
      onTap: () {
        if (isLockedVip) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                persist: false,
                duration: const Duration(seconds: 3),
                content: Text(
                  context.tr('O tema Personalizado (6 cores RGB) é exclusivo para membros VIP.'),
                ),
                action: SnackBarAction(
                  label: context.tr('Ver VIP'),
                  onPressed: () {
                    if (mounted) showVipPrivilegesModal(context);
                  },
                ),
              ),
            );
          showVipPrivilegesModal(context);
          return;
        }
        if (isLockedShop) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                persist: false,
                duration: const Duration(seconds: 3),
                content: Text(
                  context.tr(
                    'Compre o tema {name} na Loja por {price} {symbol} {currency}.',
                    {
                      'name': option.localizedName,
                      'price': price,
                      'symbol': ShopService.currencySymbol,
                      'currency': ShopService.currencyName,
                    },
                  ),
                ),
                action: SnackBarAction(
                  label: context.tr('Abrir Loja'),
                  onPressed: () => RootScreen.switchTab(9),
                ),
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
      },
      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : AsterTheme.surfaceAlt(context),
          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
          border: Border.all(
            color: isSelected
                ? accent
                : (isCustom ? AsterVipColors.gold.withValues(alpha: 0.45) : Colors.transparent),
            width: isSelected ? 2 : (isCustom ? 1.2 : 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: option.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: option.primary.withValues(alpha: 0.45)),
                  ),
                  child: Icon(option.icon, size: 15, color: option.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              option.localizedName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                color: isSelected ? accent : AsterTheme.text(context),
                              ),
                            ),
                          ),
                          if (isCustom) ...[
                            const SizedBox(width: 4),
                            const VipBadgePill(size: VipBadgeSize.xs, interactive: false),
                          ] else if (isLockedShop) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AsterConstants.ambar.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Text(
                                '$price ${ShopService.currencySymbol}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AsterConstants.ambar,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        option.localizedTag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AsterTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: isLockedVip ? AsterVipColors.gold : AsterConstants.ambar,
                  )
                else if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 16, color: option.primary),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: paletteSwatches
                  .map(
                    (c) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsetsDirectional.only(end: 5),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Seção de Provedor de IA & Modelos (Studio OS Style) ───
  Widget _buildAiKeySection(bool isDark) {
    final currentProv = GeminiService.providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () => GeminiService.providers.first,
    );
    final hasKey = (_selectedProviderId == 'custom' && _baseUrlController.text.trim().isNotEmpty) ||
        _apiKeyController.text.trim().isNotEmpty;

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return SoftClayCard(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 560 : MediaQuery.sizeOf(context).width - 68,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AsterTheme.primary(context).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.psychology_rounded, size: 20, color: AsterTheme.primary(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Inteligência Artificial & Provedores'),
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                            ),
                          ),
                          Text(
                            context.tr('Escolha o provedor de IA, personalize a URL e selecione modelos recomendados'),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasKey ? AsterConstants.menta : AsterConstants.ambar).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasKey ? AsterConstants.menta : AsterConstants.ambar,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasKey
                          ? context.tr('Configurado · {provider}', {'provider': currentProv.label})
                          : context.tr('Não configurada'),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasKey ? AsterConstants.menta : AsterConstants.ambar,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Provedores de IA
          Text(
            context.tr('PROVEDOR DE IA'),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final crossAxisCount = availableWidth > 880
                  ? 4
                  : (availableWidth > 640 ? 3 : (availableWidth >= 290 ? 2 : 1));
              const double spacing = 10;
              final double itemWidth =
                  (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: GeminiService.providers.map((p) {
                  final isSelected = _selectedProviderId == p.id;
                  final primaryCol = AsterTheme.primary(context);

                  return InkWell(
                    onTap: () => _onSelectProvider(p.id),
                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: itemWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryCol.withValues(alpha: 0.12)
                            : AsterTheme.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        border: Border.all(
                          color: isSelected
                              ? primaryCol
                              : AsterTheme.surfaceInset(context),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                    color: isSelected
                                        ? primaryCol
                                        : AsterTheme.text(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.models.isNotEmpty
                                      ? (p.id == 'google' && _isCheckingOperationalModels
                                          ? context.tr('Verificando...')
                                          : context.tr('{count} disponíveis', {'count': _getModelCountForProvider(p)}))
                                      : context.tr('URL e modelo próprios'),
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: (p.id == 'google' && _dynamicGoogleModels.isNotEmpty)
                                        ? AsterTheme.secondary(context)
                                        : AsterTheme.textMuted(context),
                                    fontWeight: (p.id == 'google' && _dynamicGoogleModels.isNotEmpty)
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, size: 16, color: primaryCol),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 18),

          // 2. Campo de URL Base (apenas para Provedor Personalizado)
          if (_selectedProviderId == 'custom') ...[
            Text(
              context.tr('URL BASE DA API (OPENAI-COMPATIBLE)'),
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _baseUrlController,
              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AsterTheme.text(context)),
              decoration: InputDecoration(
                hintText: 'https://api.exemplo.com/v1',
                prefixIcon: Icon(Icons.link_rounded, size: 18, color: AsterTheme.primary(context)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('💡 A URL deve aceitar o formato de chat completions. O Noesis acrescenta /chat/completions se necessário.'),
              style: GoogleFonts.manrope(fontSize: 11, color: AsterTheme.textMuted(context)),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Campo de Chave de API
          Text(
            context.tr('CHAVE DE API ({provider})', {'provider': currentProv.label.toUpperCase()}),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AsterTheme.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            onSubmitted: (val) {
              if (_selectedProviderId == 'google' && val.trim().isNotEmpty) {
                _checkAndSyncOperationalModels(val.trim(), showSuccessSnackbar: true);
              }
            },
            style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AsterTheme.text(context)),
            decoration: InputDecoration(
              hintText: _selectedProviderId == 'custom'
                  ? context.tr('Opcional para provedores locais (ex: Ollama/LM Studio)')
                  : context.tr('sk-... ou AIzaSy...'),
              prefixIcon: Icon(Icons.vpn_key_rounded, size: 18, color: AsterTheme.primary(context)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 20,
                  color: AsterTheme.textMuted(context),
                ),
                onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              ),
            ),
          ),
          if (currentProv.keyUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: () => _openUrl(currentProv.keyUrl),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AsterTheme.primary(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      border: Border.all(
                        color: AsterTheme.primary(context).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.key_rounded, size: 15, color: AsterTheme.primary(context)),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('Obter Chave da API ({provider})', {'provider': currentProv.label}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AsterTheme.primary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.open_in_new_rounded, size: 14, color: AsterTheme.primary(context)),
                      ],
                    ),
                  ),
                ),
                Text(
                  context.tr('Abre o console de credenciais oficial em nova aba'),
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: AsterTheme.textMuted(context),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),

          // 4. Seletor de Modelo com Dropdown Menu (Studio OS Style)
          Row(
            children: [
              Text(
                context.tr('MODELO'),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AsterTheme.textMuted(context),
                ),
              ),
              if (_selectedProviderId == 'google' && _isCheckingOperationalModels) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: AsterTheme.primary(context)),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('Validando modelos em tempo real...'),
                  style: GoogleFonts.manrope(fontSize: 10.5, color: AsterTheme.primary(context), fontWeight: FontWeight.w700),
                ),
              ],
              const Spacer(),
              if (_selectedProviderId == 'google' && _apiKeyController.text.trim().isNotEmpty) ...[
                InkWell(
                  onTap: _isCheckingOperationalModels
                      ? null
                      : () => _checkAndSyncOperationalModels(_apiKeyController.text.trim(), showSuccessSnackbar: true),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, size: 14, color: AsterTheme.primary(context)),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('Sincronizar da Conta'),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
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
          ),
          const SizedBox(height: 6),
          if (currentProv.models.isNotEmpty && !_isManualModelMode) ...[
            Container(
              decoration: BoxDecoration(
                color: AsterTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                border: Border.all(
                  color: AsterTheme.surfaceInset(context),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: Builder(
                  builder: (context) {
                    final allModels = <String>{
                      ...(_selectedProviderId == 'google' && _dynamicGoogleModels.isNotEmpty
                          ? _dynamicGoogleModels
                          : currentProv.models),
                      if (_modelController.text.trim().isNotEmpty) _modelController.text.trim(),
                    }.toList();

                    final selectedVal = allModels.contains(_modelController.text.trim())
                        ? _modelController.text.trim()
                        : (allModels.isNotEmpty ? allModels.first : currentProv.defaultModel);

                    return DropdownButton<String>(
                      value: selectedVal,
                      isExpanded: true,
                      dropdownColor: AsterTheme.card(context),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AsterTheme.primary(context)),
                      items: [
                        ...allModels.map((mod) {
                          final isDefault = mod == currentProv.defaultModel;
                          return DropdownMenuItem<String>(
                            value: mod,
                            child: Row(
                              children: [
                                Icon(Icons.smart_toy_outlined, size: 18, color: AsterTheme.primary(context)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    mod,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AsterTheme.text(context),
                                    ),
                                  ),
                                ),
                                if (isDefault) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AsterTheme.secondary(context).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                    ),
                                    child: Text(
                                      context.tr('Padrão'),
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AsterTheme.secondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        DropdownMenuItem<String>(
                          value: '__custom__',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18, color: AsterTheme.textMuted(context)),
                              const SizedBox(width: 10),
                              Text(
                                context.tr('Personalizado (digitar outro modelo...)'),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AsterTheme.primary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        if (val == '__custom__') {
                          setState(() {
                            _isManualModelMode = true;
                          });
                        } else {
                          _onSelectModel(val);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('Modelo ativo: '),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AsterTheme.textMuted(context),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _modelController.text.isNotEmpty ? _modelController.text : currentProv.defaultModel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AsterTheme.primary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isManualModelMode = true;
                    });
                  },
                  icon: Icon(Icons.edit_rounded, size: 13, color: AsterTheme.primary(context)),
                  label: Text(
                    context.tr('Digitar ID manualmente'),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AsterTheme.primary(context),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ] else ...[
            TextField(
              controller: _modelController,
              style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AsterTheme.text(context)),
              decoration: InputDecoration(
                hintText: currentProv.models.isNotEmpty
                    ? context.tr('Digite o ID do modelo (ex: {model})', {'model': currentProv.defaultModel})
                    : context.tr('ID exato do modelo (ex: llama3:8b, mistral, qwen2.5)'),
                prefixIcon: Icon(Icons.memory_rounded, size: 18, color: AsterTheme.primary(context)),
                suffixIcon: currentProv.models.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.arrow_drop_down_circle_outlined, size: 18, color: AsterTheme.primary(context)),
                        tooltip: context.tr('Voltar ao menu dropdown'),
                        onPressed: () {
                          setState(() {
                            _isManualModelMode = false;
                            if (_modelController.text.trim().isEmpty) {
                              _modelController.text = currentProv.defaultModel;
                            }
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (text) => setState(() {}),
            ),
            if (currentProv.models.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isManualModelMode = false;
                      if (_modelController.text.trim().isEmpty) {
                        _modelController.text = currentProv.defaultModel;
                      }
                    });
                  },
                  icon: Icon(Icons.list_rounded, size: 14, color: AsterTheme.primary(context)),
                  label: Text(
                    context.tr('Selecionar da lista dropdown'),
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: AsterTheme.primary(context)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),

          // 5. Feedback de Teste
          if (_testResult != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_testSuccess == true ? AsterConstants.menta : AsterConstants.coral).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                border: Border.all(
                  color: (_testSuccess == true ? AsterConstants.menta : AsterConstants.coral).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    size: 18,
                    color: _testSuccess == true ? AsterConstants.menta : AsterConstants.coral,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _testSuccess == true ? AsterConstants.menta : AsterConstants.coral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 6. Botões de Ação
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SoftClayPillButton(
                text: context.tr('Salvar Configuração'),
                onPressed: _saveAiSettings,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AsterTheme.primary(context),
                  side: BorderSide(color: AsterTheme.primary(context), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AsterConstants.radiusPill)),
                ),
                icon: _isTestingKey
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AsterTheme.primary(context)))
                    : const Icon(Icons.flash_on_rounded, size: 16),
                label: Text(
                  _isTestingKey ? context.tr('Testando...') : context.tr('Testar Conexão'),
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: _isTestingKey ? null : _testAiConnection,
              ),
              if (hasKey)
                TextButton(
                  onPressed: () {
                    _apiKeyController.clear();
                    _modelController.text = currentProv.defaultModel;
                    _baseUrlController.clear();
                    GeminiService.configure(
                      providerId: _selectedProviderId,
                      modelName: currentProv.defaultModel,
                      key: '',
                      customBaseUrl: '',
                    );
                    setState(() {
                      _testResult = null;
                      _testSuccess = null;
                    });
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          persist: false,
                          duration: const Duration(seconds: 2),
                          content: Text(context.tr('Configurações de IA redefinidas.')),
                        ),
                      );
                  },
                  child: Text(context.tr('Limpar'), style: GoogleFonts.manrope(color: AsterConstants.coral, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 3. Seção de Idiomas do Ecossistema Aster (15 Idiomas) ───
  Widget _buildLanguageSection(bool isDark) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return SoftClayCard(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AsterTheme.primary(context).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language_rounded, size: 20, color: AsterTheme.primary(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Idioma e Região'),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                      ),
                    ),
                    Text(
                      context.tr('Todos os 15 idiomas suportados no ecossistema Aster Portfolio'),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Grade com os 15 Idiomas do Portfólio (Responsiva e Preenchendo a Largura Total)
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final crossAxisCount = availableWidth > 880
                  ? 4
                  : (availableWidth > 640 ? 3 : (availableWidth >= 290 ? 2 : 1));
              const double spacing = 12;
              final double itemWidth =
                  (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

              return ValueListenableBuilder<String>(
                valueListenable: NoesisLocaleService.currentCodeNotifier,
                builder: (context, activeCode, _) {
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: _languages.map((lang) {
                      final isSelected = activeCode == lang.code;
                      final primaryCol = AsterTheme.primary(context);
                      final regionLabel = context.tr(lang.regionKey);

                      return InkWell(
                        key: Key('settings_lang_option_${lang.code}'),
                        onTap: () async {
                          await NoesisLocaleService.setLanguage(lang.code);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                persist: false,
                                duration: const Duration(seconds: 2),
                                backgroundColor: primaryCol,
                                content: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CountryFlagIcon(code: lang.code, width: 20, height: 14),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        context.tr(
                                          'Idioma selecionado: {name} ({region})',
                                          {
                                            'name': lang.nativeName,
                                            'region': regionLabel,
                                          },
                                        ),
                                        style: TextStyle(color: AsterTheme.onPrimary(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                        },
                        borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: itemWidth,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryCol.withValues(alpha: 0.12)
                                : AsterTheme.surfaceAlt(context),
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                            border: Border.all(
                              color: isSelected ? primaryCol : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              CountryFlagIcon(code: lang.code, width: 30, height: 21),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.nativeName,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? primaryCol
                                            : AsterTheme.text(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      regionLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        color: AsterTheme.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded,
                                    size: 16, color: primaryCol),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
