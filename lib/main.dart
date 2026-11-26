import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/constants.dart';
import 'core/notifications_service.dart';
import 'core/shop_service.dart';
import 'core/theme.dart';
import 'core/supabase_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/tracker/tracker_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/ai_agent/ai_assistant_screen.dart';
import 'features/quizzes/quiz_screen.dart';
import 'features/flashcards/flashcards_screen.dart';
import 'features/notebooks/notebooks_screen.dart';
import 'features/performance/performance_screen.dart';
import 'features/profile/data/social_connections_service.dart';
import 'features/profile/profile_screen.dart';
import 'features/ranking/data/ranking_service.dart';
import 'features/ranking/ranking_screen.dart';
import 'features/roadmaps/roadmaps_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/study_groups/study_groups_screen.dart';
import 'features/study_log/study_log_screen.dart';
import 'features/settings/settings_screen.dart';
import 'widgets/insight_gain_toast_overlay.dart';
import 'widgets/insight_icon.dart';
import 'widgets/noesis_logo.dart';
import 'widgets/profile_settings_dialog.dart';
import 'widgets/vip_privileges.dart';
import 'widgets/weekly_goal_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar suporte a formatação de datas em português
  await initializeDateFormatting('pt_BR', null);

  // Inicializar Supabase com a instância oficial do Aster
  await Supabase.initialize(
    url: AsterConstants.supabaseUrl,
    anonKey: AsterConstants.supabaseAnonKey,
  );

  // Desativar download de fontes em runtime (utilizar fontes locais em assets/fonts/)
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const NoesisApp());
}

class AsterScrollBehavior extends MaterialScrollBehavior {
  const AsterScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());
  }
}

class NoesisApp extends StatelessWidget {
  const NoesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AsterTheme.themeModeNotifier,
        AsterTheme.activeThemeIdNotifier,
        AsterTheme.customThemeColorsNotifier,
      ]),
      builder: (context, _) {
        final themeMode = AsterTheme.themeModeNotifier.value;
        return MaterialApp(
          title: AsterConstants.appName,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AsterScrollBehavior(),
          theme: AsterTheme.activeLightThemeData(),
          darkTheme: AsterTheme.activeDarkThemeData(),
          themeMode: themeMode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Troca o ThemeData em 1 frame sem lerp pesado de TextTheme; a fluidez visual
          // é feita pelo NoesisThemeTransitionOverlay diretamente na GPU.
          themeAnimationDuration: Duration.zero,
          builder: (context, child) {
            return NoesisThemeTransitionOverlay(
              child: InsightGainToastOverlay(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const RootScreen(),
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @visibleForTesting
  static bool bypassAuthForTesting = false;

  static late ValueNotifier<int> activeTabNotifier;
  static ValueNotifier<int>? activeTabListenable;
  static void switchTab(int index) {
    final notifier = activeTabListenable;
    if (notifier != null) {
      notifier.value = index;
    }
  }

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with SingleTickerProviderStateMixin {
  late final ValueNotifier<int> _activeTabNotifier;
  Map<String, dynamic>? _userProfile;
  bool _isSidebarCollapsed = false;
  late final AnimationController _sidebarController;
  late final Animation<Offset> _sidebarOffset;
  late final Animation<double> _sidebarOpacity;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _studySessionsSubscription;
  Session? _session;
  int _weeklyStudiedMinutes = 0;
  int _dailyStudiedMinutes = 0;
  int _currentStreakDays = 0;

  final Set<int> _loadedTabs = {0};

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const TrackerScreen();
      case 1:
        return const QuizScreen();
      case 2:
        return const FlashcardsScreen();
      case 3:
        return const NotebooksScreen();
      case 4:
        return const AiAssistantScreen();
      case 5:
        return const CalendarScreen();
      case 6:
        return const SettingsScreen();
      case 7:
        return const StudyLogScreen();
      case 8:
        return const RoadmapsScreen();
      case 9:
        return const ShopScreen();
      case 10:
        return const StudyGroupsScreen();
      case 11:
        return const RankingScreen();
      case 12:
        return const ProfileScreen();
      case 13:
        return const PerformanceScreen();
      default:
        return const TrackerScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    final sidebarCurve = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _sidebarOffset = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(sidebarCurve);
    _sidebarOpacity = sidebarCurve;
    AsterTheme.sidebarCollapsedNotifier.value = _isSidebarCollapsed;
    _activeTabNotifier = ValueNotifier<int>(0);
    RootScreen.activeTabNotifier = _activeTabNotifier;
    RootScreen.activeTabListenable = _activeTabNotifier;
    _activeTabNotifier.addListener(() {
      if (mounted) {
        setState(() {
          _loadedTabs.add(_activeTabNotifier.value);
        });
        NotificationsService.instance.refresh();
      }
    });
    _session = SupabaseService.client.auth.currentSession;
    SupabaseService.userProfileNotifier.addListener(_onUserProfileChanged);
    SupabaseService.isVipNotifier.addListener(_onUserProfileChanged);
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        final newSession = data.session;
        if (_session?.user.id != newSession?.user.id) {
          setState(() {
            _session = newSession;
          });
          _loadProfile();
          _loadWeeklyGoalAndSessions();
          ShopService.instance.init(force: true).then((_) {
            if (mounted) NotificationsService.instance.refresh();
          });
        }
      }
    });
    _loadProfile();
    _loadWeeklyGoalAndSessions();
    ShopService.instance.init().then((_) {
      if (mounted) NotificationsService.instance.refresh();
    });
    NotificationsService.instance.start();
  }

  void _onUserProfileChanged() {
    if (!mounted) return;
    setState(() {
      _userProfile = SupabaseService.userProfileNotifier.value;
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    AsterTheme.sidebarCollapsedNotifier.value = _isSidebarCollapsed;
    if (_isSidebarCollapsed) {
      _sidebarController.reverse();
    } else {
      _sidebarController.forward();
    }
  }

  @override
  void dispose() {
    SupabaseService.userProfileNotifier.removeListener(_onUserProfileChanged);
    SupabaseService.isVipNotifier.removeListener(_onUserProfileChanged);
    NotificationsService.instance.stop();
    AsterTheme.sidebarCollapsedNotifier.value = false;
    _sidebarController.dispose();
    _authSubscription?.cancel();
    _studySessionsSubscription?.cancel();
    if (identical(RootScreen.activeTabListenable, _activeTabNotifier)) {
      RootScreen.activeTabListenable = null;
    }
    _activeTabNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyGoalAndSessions() async {
    await Future.wait([
      SupabaseService.loadWeeklyGoalMinutes(),
      SupabaseService.loadDailyGoalMinutes(),
    ]);
    await ShopService.instance.init();
    await RankingService.instance.init();
    _studySessionsSubscription?.cancel();
    _studySessionsSubscription = SupabaseService.studySessionsStream().listen((sessions) {
      if (!mounted) return;
      unawaited(_syncSessionsAndRewards(sessions));
    });
    final initialSessions = await SupabaseService.getStudySessions(limit: 200);
    await _syncSessionsAndRewards(initialSessions);
  }

  Future<void> _syncSessionsAndRewards(List<Map<String, dynamic>> sessions) async {
    await ShopService.instance.reconcileStreakProtectors(sessions);
    ShopService.instance.evaluateStudyProgressRewards(
      sessions: sessions,
      weeklyGoalMinutes: SupabaseService.weeklyGoalMinutesNotifier.value,
      dailyGoalMinutes: SupabaseService.dailyGoalMinutesNotifier.value,
    );
    unawaited(RankingService.instance.syncCurrentUserProgress());
    final mins = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
    final dailyMins = SupabaseService.computeTodayStudiedMinutes(sessions);
    final streak = SupabaseService.computeCurrentStreakDays(
      sessions,
      protectedDates: ShopService.instance.protectedStreakDates,
    );
    if (mounted &&
        (mins != _weeklyStudiedMinutes ||
            dailyMins != _dailyStudiedMinutes ||
            streak != _currentStreakDays)) {
      setState(() {
        _weeklyStudiedMinutes = mins;
        _dailyStudiedMinutes = dailyMins;
        _currentStreakDays = streak;
      });
    }
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.loadFullProfile();
    await AsterTheme.loadCustomTheme(isVip: SupabaseService.isCurrentUserVip);
    unawaited(SocialConnectionsService.instance.init());
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
  }

  void _openProfileSettings() {
    showProfileSettingsDialog(
      context,
      streakDays: _currentStreakDays,
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    final formatter = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
    try {
      final text = formatter.format(now);
      return text[0].toUpperCase() + text.substring(1);
    } catch (_) {
      return 'Hoje · Foco Ativo';
    }
  }

  void _showNotificationsPanel(BuildContext context, bool isWideScreen) {
    NotificationsService.instance.refresh();
    if (isWideScreen) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.12),
        builder: (dialogContext) {
          return Stack(
            children: [
              Positioned(
                top: 68,
                right: 28,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 390,
                      maxHeight: 520,
                    ),
                    child: _buildNotificationsContent(
                      dialogContext: dialogContext,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (bottomSheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: _buildNotificationsContent(
                  dialogContext: bottomSheetContext,
                  isBottomSheet: true,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildNotificationsContent({
    required BuildContext dialogContext,
    bool isBottomSheet = false,
  }) {
    return ValueListenableBuilder<List<NoesisNotification>>(
      valueListenable: NotificationsService.instance.notificationsNotifier,
      builder: (context, items, _) {
        final unread = items.where((n) => !n.isRead).length;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryCol = AsterTheme.primary(context);
        final cardCol = AsterTheme.card(context);
        final surfaceAltCol = AsterTheme.surfaceAlt(context);
        final insetCol = AsterTheme.surfaceInset(context);
        final textCol = AsterTheme.text(context);
        final mutedCol = AsterTheme.textMuted(context);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: cardCol,
            borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
            border: Border.all(
              color: isDark ? insetCol : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isBottomSheet)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: insetCol,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryCol.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        size: 16,
                        color: primaryCol,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Notificações',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AsterConstants.coral.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                        ),
                        child: Text(
                          '$unread ${unread == 1 ? 'nova' : 'novas'}',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AsterConstants.coral,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (unread > 0)
                      TextButton(
                        onPressed: NotificationsService.instance.markAllAsRead,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Marcar lidas',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryCol,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: mutedCol),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: insetCol),
              Flexible(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: surfaceAltCol,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.done_all_rounded,
                                size: 24,
                                color: AsterConstants.menta,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tudo em dia!',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textCol,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Você não tem novas notificações no momento.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: mutedCol,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: NotificationsService.instance.restoreAndRefresh,
                              icon: Icon(Icons.refresh_rounded, size: 15, color: primaryCol),
                              label: Text(
                                'Verificar notificações',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryCol,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 64,
                          endIndent: 20,
                          color: insetCol.withValues(alpha: 0.6),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final itemColor = item.resolveColor(context);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                NotificationsService.instance.markAsRead(item.id);
                                _activeTabNotifier.value = item.targetTab;
                                _loadedTabs.add(item.targetTab);
                                Navigator.of(dialogContext).pop();
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: itemColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: item.id == 'welcome_insights_bonus'
                                          ? const Center(child: InsightCoinIcon(size: 20))
                                          : Icon(item.icon, size: 18, color: itemColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13,
                                                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                    color: textCol,
                                                  ),
                                                ),
                                              ),
                                              if (!item.isRead) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: itemColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.message,
                                            style: GoogleFonts.manrope(
                                              fontSize: 11.5,
                                              height: 1.35,
                                              color: item.isRead
                                                  ? mutedCol.withValues(alpha: 0.72)
                                                  : mutedCol,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.timeLabel,
                                            style: GoogleFonts.manrope(
                                              fontSize: 10,
                                              color: mutedCol.withValues(alpha: 0.75),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Dispensar',
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: mutedCol.withValues(alpha: 0.7),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 14,
                                      onPressed: () =>
                                          NotificationsService.instance.dismiss(item.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (items.isNotEmpty) ...[
                Divider(height: 1, color: insetCol),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toque para abrir no app',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: mutedCol.withValues(alpha: 0.75),
                        ),
                      ),
                      TextButton(
                        onPressed: NotificationsService.instance.dismissAll,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Limpar todas',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: mutedCol,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session ?? SupabaseService.client.auth.currentSession;

    if (session == null && !RootScreen.bypassAuthForTesting) {
      return AuthScreen(
        onAuthenticated: () {
          setState(() {
            _session = SupabaseService.client.auth.currentSession;
          });
          _loadProfile();
          _loadWeeklyGoalAndSessions();
          ShopService.instance.init(force: true).then((_) {
            if (mounted) NotificationsService.instance.refresh();
          });
        },
      );
    }

        final isWideScreen = MediaQuery.of(context).size.width >= 900;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final rawFullName = (_userProfile?['full_name'] ?? '').toString().trim();
        final rawChannel = SupabaseService.sanitizeUsername((_userProfile?['channel'] ?? '').toString());
        final userName = rawFullName.isNotEmpty
            ? rawFullName
            : (rawChannel.isNotEmpty
                ? '@$rawChannel'
                : (session?.user.email?.split('@').first ?? 'Estudante'));
        final initials = userName.isNotEmpty ? userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase() : 'ES';
        final avatarImage = buildAvatarImageProvider(_userProfile?['avatar_url']?.toString());
        final isVip = SupabaseService.isCurrentUserVip;

        return Scaffold(
          body: SoftClayBackground(
            child: Stack(
              children: [
                // ─── Área Principal de Conteúdo (layout único sem reflow por frame) ───
                Positioned.fill(
                  left: isWideScreen ? (_isSidebarCollapsed ? 0.0 : 240.0) : 0.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Top Bar (somente na tela inicial / Dashboard; nas demais telas o botão fica ao lado no topo)
                      ValueListenableBuilder<int>(
                        valueListenable: _activeTabNotifier,
                        builder: (context, activeIndex, _) {
                          if (activeIndex != 0) {
                            return const SizedBox.shrink();
                          }
                          return RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                              child: Row(
                                children: [
                                  if (!isWideScreen) ...[
                                    const NoesisLogo(size: 32, withShadow: true),
                                    const SizedBox(width: 10),
                                    const NoesisWordmark(fontSize: 19),
                                  ] else ...[
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 160),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, anim) => FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                                          child: child,
                                        ),
                                      ),
                                      child: _isSidebarCollapsed
                                          ? Padding(
                                              key: const ValueKey('dashboard_collapsed_pill'),
                                              padding: const EdgeInsets.only(right: 16),
                                              child: _buildCollapsedLogoPill(),
                                            )
                                          : const SizedBox.shrink(key: ValueKey('dashboard_expanded_empty')),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$_greeting, $userName.',
                                          style: GoogleFonts.manrope(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AsterTheme.text(context),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              '${_formatTodayDate()} · $_currentStreakDays ${_currentStreakDays == 1 ? 'dia' : 'dias'} de streak ',
                                              style: GoogleFonts.manrope(
                                                fontSize: 13,
                                                color: AsterTheme.textMuted(context),
                                              ),
                                            ),
                                            const Text('🔥', style: TextStyle(fontSize: 13)),
                                            ValueListenableBuilder<int>(
                                              valueListenable:
                                                  ShopService.instance.streakProtectorsNotifier,
                                              builder: (context, shields, _) {
                                                if (shields <= 0) return const SizedBox.shrink();
                                                return Padding(
                                                  padding: const EdgeInsets.only(left: 6),
                                                  child: Tooltip(
                                                    message:
                                                        '$shields ${shields == 1 ? 'Protetor de Ofensiva ativo' : 'Protetores de Ofensiva ativos'}',
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF38BDF8)
                                                            .withValues(alpha: 0.14),
                                                        borderRadius: BorderRadius.circular(
                                                          AsterConstants.radiusPill,
                                                        ),
                                                        border: Border.all(
                                                          color: const Color(0xFF38BDF8)
                                                              .withValues(alpha: 0.4),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const StreakShieldIcon(size: 13),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '$shields',
                                                            style: GoogleFonts.jetBrainsMono(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w800,
                                                              color: const Color(0xFF0284C7),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],

                                  const Spacer(),

                                  // Carteira rápida de Lúmens (clique abre a Loja)
                                  ValueListenableBuilder<int>(
                                    valueListenable: ShopService.instance.balanceNotifier,
                                    builder: (context, balance, _) {
                                      return Tooltip(
                                        message: 'Saldo na Loja (${ShopService.currencyName})',
                                        child: InkWell(
                                          key: const Key('header_wallet_pill'),
                                          onTap: () => RootScreen.switchTab(9),
                                          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: AsterTheme.card(context),
                                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                              border: Border.all(
                                                color: AsterConstants.ambar.withValues(alpha: 0.4),
                                              ),
                                              boxShadow: isDark
                                                  ? AsterConstants.claySubtleDarkShadow
                                                  : AsterConstants.claySubtleShadow,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const InsightCoinIcon(size: 18),
                                                const SizedBox(width: 7),
                                                Text(
                                                  '$balance ${ShopService.currencyName}',
                                                  style: GoogleFonts.jetBrainsMono(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: AsterTheme.text(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 10),

                                  // Botão Interativo de Notificações (reativo com dados reais)
                                  ValueListenableBuilder<List<NoesisNotification>>(
                                    valueListenable: NotificationsService.instance.notificationsNotifier,
                                    builder: (context, notifications, _) {
                                      final unread = notifications.where((n) => !n.isRead).length;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 280),
                                            curve: Curves.easeInOutCubic,
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AsterTheme.card(context),
                                              shape: BoxShape.circle,
                                              boxShadow: isDark
                                                  ? AsterConstants.claySubtleDarkShadow
                                                  : AsterConstants.claySubtleShadow,
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                key: const Key('notifications_bell_button'),
                                                onTap: () => _showNotificationsPanel(context, isWideScreen),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Center(
                                                  child: Icon(
                                                    unread > 0
                                                        ? Icons.notifications_active_outlined
                                                        : Icons.notifications_none_rounded,
                                                    size: 20,
                                                    color: AsterTheme.text(context),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (unread > 0)
                                            Positioned(
                                              key: const Key('notifications_unread_dot'),
                                              top: 2,
                                              right: 2,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: AsterConstants.coral,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AsterTheme.card(context),
                                                    width: 2,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color.fromRGBO(255, 122, 144, 0.4),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (!isWideScreen) ...[
                                    const SizedBox(width: 10),
                                    Tooltip(
                                      message: 'Configurações do Perfil',
                                      child: InkWell(
                                        key: const Key('mobile_profile_button'),
                                        customBorder: const CircleBorder(),
                                        onTap: _openProfileSettings,
                                        child: VipAvatarCircle(
                                          isVip: isVip,
                                          badgeSize: VipBadgeSize.xs,
                                          borderWidth: 2,
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.16),
                                            backgroundImage: avatarImage,
                                            onBackgroundImageError: avatarImage != null ? (_, _) {} : null,
                                            child: avatarImage == null
                                                ? Text(
                                                    initials,
                                                    style: GoogleFonts.manrope(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 12,
                                                      color: AsterTheme.primary(context),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Telas do App com Offstage (apenas a aba ativa executa layout/paint)
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _activeTabNotifier,
                          builder: (context, activeIndex, _) {
                            _loadedTabs.add(activeIndex);
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                for (int index = 0; index < 14; index++)
                                  if (_loadedTabs.contains(index))
                                    Positioned.fill(
                                      child: Offstage(
                                        offstage: index != activeIndex,
                                        child: TickerMode(
                                          enabled: index == activeIndex,
                                          child: RepaintBoundary(child: _buildScreen(index)),
                                        ),
                                      ),
                                    ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Botão Flutuante de Reabrir Menu (alinhado ao lado do botão voltar e topo) ───
                if (isWideScreen)
                  ValueListenableBuilder<int>(
                    valueListenable: _activeTabNotifier,
                    builder: (context, activeIndex, _) {
                      if (activeIndex == 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        top: 8,
                        left: 20,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          child: _isSidebarCollapsed
                              ? _buildCollapsedLogoPill()
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),

                // ─── Sidebar Oficial Soft Clay (GPU SlideTransition + FadeTransition sem lag) ───
                if (isWideScreen)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: 240,
                    child: AnimatedBuilder(
                      animation: _sidebarController,
                      builder: (context, child) {
                        if (_sidebarController.value == 0.0) {
                          return const SizedBox.shrink();
                        }
                        return IgnorePointer(
                          ignoring: _isSidebarCollapsed,
                          child: SlideTransition(
                            position: _sidebarOffset,
                            child: FadeTransition(
                              opacity: _sidebarOpacity,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: RepaintBoundary(
                        child: Container(
                          width: 240,
                          decoration: BoxDecoration(
                            color: AsterTheme.card(context),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color.fromRGBO(60, 60, 120, 0.05),
                                blurRadius: 20,
                                offset: const Offset(4, 0),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo Noesis Oficial (clique para ocultar o menu lateral)
                              Tooltip(
                                message: 'Ocultar menu lateral',
                                child: InkWell(
                                  key: const Key('sidebar_logo_toggle'),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                  onTap: _toggleSidebar,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                    child: Row(
                                      children: [
                                        const NoesisLogo(size: 34, withShadow: true),
                                        const SizedBox(width: 11),
                                        const NoesisWordmark(fontSize: 19.5),
                                        const Spacer(),
                                        Icon(
                                          Icons.menu_open_rounded,
                                          size: 18,
                                          color: AsterTheme.textMuted(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Itens de Menu organizados por seção (rolável em telas menores para manter rodapé sempre visível)
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildNavItem(
                                        index: 0,
                                        title: 'Dashboard',
                                        icon: Icons.home_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 13,
                                        title: 'Desempenho',
                                        icon: Icons.analytics_rounded,
                                      ),
                                      _buildNavSectionHeader('ESTUDO'),
                                      _buildNavItem(
                                        index: 1,
                                        title: 'Simulados',
                                        icon: Icons.assignment_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 2,
                                        title: 'Flashcards',
                                        icon: Icons.style_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 3,
                                        title: 'Cadernos',
                                        icon: Icons.menu_book_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 8,
                                        title: 'Trilhas',
                                        icon: Icons.route_rounded,
                                      ),
                                      _buildNavSectionHeader('ROTINA & IA'),
                                      _buildNavItem(
                                        index: 7,
                                        title: 'Diário de Estudos',
                                        icon: Icons.auto_stories_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 5,
                                        title: 'Calendário',
                                        icon: Icons.calendar_today_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 4,
                                        title: 'Noesis AI',
                                        icon: Icons.smart_toy_rounded,
                                      ),
                                      _buildNavSectionHeader('COMUNIDADE'),
                                      _buildNavItem(
                                        index: 10,
                                        title: 'Grupos',
                                        icon: Icons.groups_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 11,
                                        title: 'Ranking',
                                        icon: Icons.emoji_events_rounded,
                                      ),
                                      _buildNavSectionHeader('CONTA'),
                                      _buildNavItem(
                                        index: 12,
                                        title: 'Perfil',
                                        icon: Icons.person_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 9,
                                        title: 'Loja',
                                        icon: Icons.storefront_rounded,
                                      ),
                                      const SizedBox(height: 1),
                                      _buildNavItem(
                                        index: 6,
                                        title: 'Configurações',
                                        icon: Icons.settings_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Widget: Meta Diária & Meta Semanal (interativos e editáveis)
                              ValueListenableBuilder<int>(
                                valueListenable: SupabaseService.dailyGoalMinutesNotifier,
                                builder: (context, dailyGoalMinutes, _) {
                                  final hasDailyGoal = dailyGoalMinutes > 0;
                                  final safeDaily = hasDailyGoal ? dailyGoalMinutes : 1;
                                  final dailyProgress =
                                      (_dailyStudiedMinutes / safeDaily).clamp(0.0, 1.0);
                                  final dailyPct = ((_dailyStudiedMinutes / safeDaily) * 100)
                                      .round()
                                      .clamp(0, 999);
                                  final dailyReached =
                                      hasDailyGoal && _dailyStudiedMinutes >= safeDaily;

                                  return Tooltip(
                                    message: 'Clique para editar a meta diária',
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeInOutCubic,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AsterConstants.surfaceAltDark
                                            : AsterConstants.surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(AsterConstants.radiusMedium),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          key: const Key('sidebar_daily_goal_card'),
                                          borderRadius:
                                              BorderRadius.circular(AsterConstants.radiusMedium),
                                          onTap: () => showDailyGoalEditorDialog(
                                            context,
                                            currentWeekStudiedMinutes: _weeklyStudiedMinutes,
                                            currentDayStudiedMinutes: _dailyStudiedMinutes,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 9,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'META DIÁRIA',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.8,
                                                        color: isDark
                                                            ? AsterConstants.textMutedDark
                                                            : AsterConstants.textMuted,
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.edit_rounded,
                                                      size: 11,
                                                      color: AsterTheme.primary(context),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        hasDailyGoal
                                                            ? '${SupabaseService.formatGoalDuration(_dailyStudiedMinutes)} / ${SupabaseService.formatGoalDuration(dailyGoalMinutes)}'
                                                            : '${SupabaseService.formatGoalDuration(_dailyStudiedMinutes)} hoje',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w800,
                                                          color: isDark
                                                              ? AsterConstants.textLight
                                                              : AsterConstants.textDark,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      hasDailyGoal ? '$dailyPct%' : 'Sem meta',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: hasDailyGoal ? 11.5 : 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: !hasDailyGoal
                                                            ? (isDark
                                                                ? AsterConstants.textMutedDark
                                                                : AsterConstants.textMuted)
                                                            : (dailyReached
                                                                ? AsterTheme.secondary(context)
                                                                : AsterTheme.primary(context)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (hasDailyGoal) ...[
                                                  const SizedBox(height: 6),
                                                  LinearProgressIndicator(
                                                    value: dailyProgress,
                                                    minHeight: 5,
                                                    borderRadius: BorderRadius.circular(
                                                      AsterConstants.radiusPill,
                                                    ),
                                                    backgroundColor:
                                                        AsterTheme.surfaceInset(context),
                                                    valueColor: AlwaysStoppedAnimation(
                                                      AsterTheme.primary(context),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              ValueListenableBuilder<int>(
                                valueListenable: SupabaseService.weeklyGoalMinutesNotifier,
                                builder: (context, goalMinutes, _) {
                                  final hasWeeklyGoal = goalMinutes > 0;
                                  final safeGoal = hasWeeklyGoal ? goalMinutes : 1;
                                  final progress = (_weeklyStudiedMinutes / safeGoal).clamp(0.0, 1.0);
                                  final pct = ((_weeklyStudiedMinutes / safeGoal) * 100)
                                      .round()
                                      .clamp(0, 999);
                                  final goalReached =
                                      hasWeeklyGoal && _weeklyStudiedMinutes >= safeGoal;

                                  return Tooltip(
                                    message: 'Clique para editar a meta semanal',
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeInOutCubic,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AsterConstants.surfaceAltDark
                                            : AsterConstants.surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(AsterConstants.radiusMedium),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          key: const Key('sidebar_weekly_goal_card'),
                                          borderRadius:
                                              BorderRadius.circular(AsterConstants.radiusMedium),
                                          onTap: () => showWeeklyGoalEditorDialog(
                                            context,
                                            currentWeekStudiedMinutes: _weeklyStudiedMinutes,
                                            currentDayStudiedMinutes: _dailyStudiedMinutes,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 9,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'META SEMANAL',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.8,
                                                        color: isDark
                                                            ? AsterConstants.textMutedDark
                                                            : AsterConstants.textMuted,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: AsterTheme.primary(context)
                                                            .withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(
                                                            AsterConstants.radiusPill),
                                                      ),
                                                      child: Icon(
                                                        Icons.edit_rounded,
                                                        size: 11,
                                                        color: AsterTheme.primary(context),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        hasWeeklyGoal
                                                            ? '${SupabaseService.formatGoalDuration(_weeklyStudiedMinutes)} / ${SupabaseService.formatGoalDuration(goalMinutes)}'
                                                            : '${SupabaseService.formatGoalDuration(_weeklyStudiedMinutes)} na sem.',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 13.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: isDark
                                                              ? AsterConstants.textLight
                                                              : AsterConstants.textDark,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      hasWeeklyGoal ? '$pct%' : 'Sem meta',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: hasWeeklyGoal ? 12 : 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: !hasWeeklyGoal
                                                            ? (isDark
                                                                ? AsterConstants.textMutedDark
                                                                : AsterConstants.textMuted)
                                                            : (goalReached
                                                                ? AsterTheme.secondary(context)
                                                                : AsterTheme.primary(context)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (hasWeeklyGoal) ...[
                                                  const SizedBox(height: 6),
                                                  LinearProgressIndicator(
                                                    value: progress,
                                                    minHeight: 5,
                                                    borderRadius: BorderRadius.circular(
                                                        AsterConstants.radiusPill),
                                                    backgroundColor:
                                                        AsterTheme.surfaceInset(context),
                                                    valueColor: AlwaysStoppedAnimation(
                                                      AsterTheme.secondary(context),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),

                              // Botão oficial da comunidade Discord do Aster (acima do perfil do usuário)
                              Tooltip(
                                message: 'Entrar na comunidade Discord do Aster (${AsterConstants.asterDiscordInviteCode})',
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF5865F2),
                                        Color(0xFF4752C4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.24),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF5865F2).withValues(alpha: isDark ? 0.28 : 0.26),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                    child: InkWell(
                                      key: const Key('sidebar_discord_button'),
                                      borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                      hoverColor: Colors.white.withValues(alpha: 0.08),
                                      splashColor: Colors.white.withValues(alpha: 0.14),
                                      onTap: () async {
                                        final uri = Uri.parse(AsterConstants.asterDiscordUrl);
                                        try {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } catch (_) {}
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(9),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.12),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Center(
                                                child: DiscordLogoWidget(size: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Entrar no Discord',
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      height: 1.15,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    'Comunidade Aster',
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      height: 1.15,
                                                      color: Colors.white.withValues(alpha: 0.80),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.18),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Perfil do Usuário (clicável -> abre Configurações do Perfil estilo StudioOS)
                              Row(
                                children: [
                                  Expanded(
                                    child: Tooltip(
                                      message: 'Configurações do Perfil',
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          key: const Key('sidebar_profile_button'),
                                          borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                                          onTap: _openProfileSettings,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            child: Row(
                                              children: [
                                                VipAvatarCircle(
                                                  isVip: isVip,
                                                  badgeSize: VipBadgeSize.xs,
                                                  borderWidth: 2,
                                                  child: CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.15),
                                                    backgroundImage: avatarImage,
                                                    onBackgroundImageError: avatarImage != null ? (_, _) {} : null,
                                                    child: avatarImage == null
                                                        ? Text(
                                                            initials,
                                                            style: GoogleFonts.manrope(
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 12,
                                                              color: AsterTheme.primary(context),
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        userName,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                                        ),
                                                      ),
                                                      Text(
                                                        rawChannel.isNotEmpty
                                                            ? '@$rawChannel · ${isVip ? 'VIP · ' : ''}${_currentStreakDays}d'
                                                            : '${isVip ? 'VIP' : 'Pro'} · Streak ${_currentStreakDays}d',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 11,
                                                          color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.tune_rounded,
                                                  size: 15,
                                                  color: isDark
                                                      ? AsterConstants.textMutedDark.withValues(alpha: 0.8)
                                                      : AsterConstants.textMuted.withValues(alpha: 0.8),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.logout_rounded,
                                      size: 18,
                                      color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                    ),
                                    tooltip: 'Sair',
                                    onPressed: () {
                                      SupabaseService.signOut();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Bottom Navigation Bar Soft Clay para Mobile ───
          bottomNavigationBar: !isWideScreen
              ? RepaintBoundary(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : const Color.fromRGBO(60, 60, 120, 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMobileNavItem(0, Icons.home_rounded, 'Dashboard'),
                          _buildMobileNavItem(13, Icons.analytics_rounded, 'Desempenho'),
                          _buildMobileNavDivider(context),
                          _buildMobileNavItem(1, Icons.assignment_rounded, 'Simulados'),
                          _buildMobileNavItem(2, Icons.style_rounded, 'Flashcards'),
                          _buildMobileNavItem(3, Icons.menu_book_rounded, 'Cadernos'),
                          _buildMobileNavItem(8, Icons.route_rounded, 'Trilhas'),
                          _buildMobileNavDivider(context),
                          _buildMobileNavItem(7, Icons.auto_stories_rounded, 'Diário'),
                          _buildMobileNavItem(5, Icons.calendar_today_rounded, 'Calendário'),
                          _buildMobileNavItem(4, Icons.smart_toy_rounded, 'Noesis AI'),
                          _buildMobileNavDivider(context),
                          _buildMobileNavItem(10, Icons.groups_rounded, 'Grupos'),
                          _buildMobileNavItem(11, Icons.emoji_events_rounded, 'Ranking'),
                          _buildMobileNavDivider(context),
                          _buildMobileNavItem(12, Icons.person_rounded, 'Perfil'),
                          _buildMobileNavItem(9, Icons.storefront_rounded, 'Loja'),
                          _buildMobileNavItem(6, Icons.settings_rounded, 'Config'),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        );
  }

  Widget _buildCollapsedLogoPill() {
    return Tooltip(
      message: 'Mostrar menu lateral',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collapsed_logo_toggle'),
          onTap: _toggleSidebar,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AsterTheme.card(context),
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              boxShadow: AsterTheme.isDarkMode
                  ? AsterConstants.claySubtleDarkShadow
                  : AsterConstants.claySubtleShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NoesisLogo(size: 28, withShadow: true),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AsterTheme.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavSectionHeader(String title) {
    final muted = AsterTheme.textMuted(context);
    final lineCol = AsterTheme.surfaceInset(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 8, 2),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: muted.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: lineCol.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AsterTheme.surfaceInset(context),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: _activeTabNotifier,
      builder: (context, activeIndex, _) {
        final cs = Theme.of(context).colorScheme;
        final isSelected = activeIndex == index;

        return Container(
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            boxShadow: isSelected ? AsterTheme.primaryShadow(context) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _activeTabNotifier.value = index;
                _loadedTabs.add(index);
              },
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.2),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileNavItem(int index, IconData icon, String label) {
    return ValueListenableBuilder<int>(
      valueListenable: _activeTabNotifier,
      builder: (context, activeIndex, _) {
        final cs = Theme.of(context).colorScheme;
        final isSelected = activeIndex == index;

        return GestureDetector(
          onTap: () {
            _activeTabNotifier.value = index;
            _loadedTabs.add(index);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
