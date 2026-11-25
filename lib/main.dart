import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/supabase_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/tracker/tracker_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/ai_agent/ai_assistant_screen.dart';
import 'features/quizzes/quiz_screen.dart';
import 'features/flashcards/flashcards_screen.dart';
import 'features/notebooks/notebooks_screen.dart';
import 'features/roadmaps/roadmaps_screen.dart';
import 'features/study_log/study_log_screen.dart';
import 'features/settings/settings_screen.dart';
import 'widgets/noesis_logo.dart';
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
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const RootScreen(),
        );
      },
    );
  }
}

class _NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final int? targetTab;
  bool isRead;

  _NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    this.targetTab,
    this.isRead = false,
  });
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

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
  bool _isGuestMode = false;
  bool _isSidebarCollapsed = false;
  late final AnimationController _sidebarController;
  late final Animation<Offset> _sidebarOffset;
  late final Animation<double> _sidebarOpacity;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _studySessionsSubscription;
  Session? _session;
  int _weeklyStudiedMinutes = 0;
  int _currentStreakDays = 0;

  final List<_NotificationItem> _notifications = [
    _NotificationItem(
      id: '1',
      title: 'Meta de Streak Mantida 🔥',
      message: 'Parabéns! Você completou sua sessão diária e atingiu 42 dias de consistência.',
      time: 'Há 12 min',
      icon: Icons.local_fire_department_rounded,
      color: AsterConstants.menta,
      targetTab: 0,
    ),
    _NotificationItem(
      id: '2',
      title: 'Novo Simulado RAG Gerado',
      message: 'O Agente Noesis preparou 5 questões inéditas de Criptografia & Redes para você testar.',
      time: 'Há 45 min',
      icon: Icons.quiz_rounded,
      color: AsterConstants.ambar,
      targetTab: 1,
    ),
    _NotificationItem(
      id: '3',
      title: 'Alerta de Cronograma',
      message: 'Simulado Oficial OWASP agendado para os próximos 2 dias. Revise seus pontos fracos.',
      time: 'Hoje às 09:15',
      icon: Icons.event_available_rounded,
      color: AsterConstants.coral,
      targetTab: 4,
    ),
    _NotificationItem(
      id: '4',
      title: 'Insight do Agente Cognitivo',
      message: 'Sua retenção em Sistemas Distribuídos aumentou 14% após a revisão espaçada.',
      time: 'Ontem',
      icon: Icons.auto_awesome_rounded,
      color: AsterConstants.lavanda,
      targetTab: 4,
      isRead: true,
    ),
  ];

  int get _unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

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
      }
    });
    _session = SupabaseService.client.auth.currentSession;
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        final newSession = data.session;
        if (_session?.user.id != newSession?.user.id) {
          setState(() {
            _session = newSession;
          });
          _loadProfile();
          _loadWeeklyGoalAndSessions();
        }
      }
    });
    _loadProfile();
    _loadWeeklyGoalAndSessions();
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
    await SupabaseService.loadWeeklyGoalMinutes();
    _studySessionsSubscription?.cancel();
    _studySessionsSubscription = SupabaseService.studySessionsStream().listen((sessions) {
      if (!mounted) return;
      final mins = SupabaseService.computeCurrentWeekStudiedMinutes(sessions);
      final streak = SupabaseService.computeCurrentStreakDays(sessions);
      if (mins != _weeklyStudiedMinutes || streak != _currentStreakDays) {
        setState(() {
          _weeklyStudiedMinutes = mins;
          _currentStreakDays = streak;
        });
      }
    });
    final initialSessions = await SupabaseService.getStudySessions(limit: 200);
    if (mounted) {
      setState(() {
        _weeklyStudiedMinutes =
            SupabaseService.computeCurrentWeekStudiedMinutes(initialSessions);
        _currentStreakDays =
            SupabaseService.computeCurrentStreakDays(initialSessions);
      });
    }
  }

  Future<void> _loadProfile() async {
    if (SupabaseService.currentUser != null) {
      final profile = await SupabaseService.getProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    }
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
    if (isWideScreen) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.12),
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (ctx, setPanelState) {
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
                          setPanelState: setPanelState,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (bottomSheetContext) {
          return StatefulBuilder(
            builder: (ctx, setPanelState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                    ),
                    child: _buildNotificationsContent(
                      dialogContext: bottomSheetContext,
                      setPanelState: setPanelState,
                      isBottomSheet: true,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildNotificationsContent({
    required BuildContext dialogContext,
    required void Function(void Function()) setPanelState,
    bool isBottomSheet = false,
  }) {
    final unread = _unreadNotificationCount;
    final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AsterConstants.surfaceInsetDark : Colors.white.withValues(alpha: 0.8),
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
                  color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset,
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
                    color: AsterTheme.primary(context).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: AsterTheme.primary(context),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Notificações',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
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
                      '$unread novas',
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
                    onPressed: () {
                      setState(() {
                        for (var n in _notifications) {
                          n.isRead = true;
                        }
                      });
                      setPanelState(() {});
                    },
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
                        color: AsterTheme.primary(context),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AsterConstants.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AsterConstants.surfaceInset),
          Flexible(
            child: _notifications.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? AsterConstants.surfaceAltDark : AsterConstants.surfaceAlt,
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
                            color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Você não tem novas notificações no momento.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 64,
                      endIndent: 20,
                      color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceAlt,
                    ),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final itemColor = item.id == '4' ? AsterTheme.primary(context) : item.color;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              item.isRead = true;
                              if (item.targetTab != null) {
                                _activeTabNotifier.value = item.targetTab!;
                                _loadedTabs.add(item.targetTab!);
                              }
                            });
                            Navigator.of(dialogContext).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  child: Icon(item.icon, size: 18, color: itemColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: GoogleFonts.manrope(
                                                fontSize: 13,
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: item.color,
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
                                              ? (isDark ? AsterConstants.textFaintDark : AsterConstants.textFaint)
                                              : (isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.time,
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          color: isDark ? AsterConstants.textFaintDark : AsterConstants.textFaint,
                                          fontWeight: FontWeight.w500,
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
          if (_notifications.isNotEmpty) ...[
            Divider(height: 1, color: isDark ? AsterConstants.surfaceInsetDark : AsterConstants.surfaceInset),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Toque para abrir no app',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: isDark ? AsterConstants.textFaintDark : AsterConstants.textFaint,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _notifications.clear();
                      });
                      setPanelState(() {});
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Limpar todas',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AsterConstants.textMuted,
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
  }

  @override
  Widget build(BuildContext context) {
    final session = _session ?? SupabaseService.client.auth.currentSession;

    if (session == null && !_isGuestMode) {
      return AuthScreen(
        onAuthenticated: () {
          setState(() {
            _session = SupabaseService.client.auth.currentSession;
          });
          _loadProfile();
          _loadWeeklyGoalAndSessions();
        },
        onContinueAsGuest: () {
          setState(() {
            _isGuestMode = true;
          });
        },
      );
    }

        final isWideScreen = MediaQuery.of(context).size.width >= 900;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final userName = _userProfile?['full_name'] ??
            _userProfile?['channel'] ??
            session?.user.email?.split('@').first ??
            (_isGuestMode ? 'Visitante (Teste)' : 'Estudante');
        final initials = userName.isNotEmpty ? userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase() : 'VT';

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
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],

                                  const Spacer(),

                                  // Botão Interativo de Notificações
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 280),
                                        curve: Curves.easeInOutCubic,
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard,
                                          shape: BoxShape.circle,
                                          boxShadow: isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow,
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showNotificationsPanel(context, isWideScreen),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Center(
                                              child: Icon(
                                                Icons.notifications_none_rounded,
                                                size: 20,
                                                color: isDark ? AsterConstants.textLight : AsterConstants.textDark,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_unreadNotificationCount > 0)
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: AsterConstants.coral,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDark ? AsterConstants.surfaceCardDark : Colors.white,
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
                                  ),
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
                                for (int index = 0; index < 9; index++)
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    child: Row(
                                      children: [
                                        const NoesisLogo(size: 38, withShadow: true),
                                        const SizedBox(width: 12),
                                        const NoesisWordmark(fontSize: 21),
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
                              const SizedBox(height: 36),

                              // Itens de Menu Soft Clay
                              _buildNavItem(
                                index: 0,
                                title: 'Dashboard',
                                icon: Icons.home_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 1,
                                title: 'Simulados',
                                icon: Icons.assignment_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 2,
                                title: 'Flashcards',
                                icon: Icons.style_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 3,
                                title: 'Cadernos',
                                icon: Icons.menu_book_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 7,
                                title: 'Diário de Estudos',
                                icon: Icons.auto_stories_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 8,
                                title: 'Trilhas',
                                icon: Icons.route_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 4,
                                title: 'Noesis AI',
                                icon: Icons.smart_toy_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 5,
                                title: 'Calendário',
                                icon: Icons.calendar_today_rounded,
                              ),
                              const SizedBox(height: 8),
                              _buildNavItem(
                                index: 6,
                                title: 'Configurações',
                                icon: Icons.settings_rounded,
                              ),

                              const Spacer(),

                              // Widget: Meta Semanal (interativo e editável)
                              ValueListenableBuilder<int>(
                                valueListenable: SupabaseService.weeklyGoalMinutesNotifier,
                                builder: (context, goalMinutes, _) {
                                  final safeGoal = goalMinutes > 0 ? goalMinutes : 1;
                                  final progress = (_weeklyStudiedMinutes / safeGoal).clamp(0.0, 1.0);
                                  final pct = ((_weeklyStudiedMinutes / safeGoal) * 100)
                                      .round()
                                      .clamp(0, 999);
                                  final goalReached = _weeklyStudiedMinutes >= safeGoal;

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
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'META SEMANAL',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 10,
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
                                                        size: 12,
                                                        color: AsterTheme.primary(context),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        '${SupabaseService.formatGoalDuration(_weeklyStudiedMinutes)} / ${SupabaseService.formatGoalDuration(goalMinutes)}',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: isDark
                                                              ? AsterConstants.textLight
                                                              : AsterConstants.textDark,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '$pct%',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: goalReached
                                                            ? AsterTheme.secondary(context)
                                                            : AsterTheme.primary(context),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                LinearProgressIndicator(
                                                  value: progress,
                                                  minHeight: 6,
                                                  borderRadius: BorderRadius.circular(
                                                      AsterConstants.radiusPill),
                                                  backgroundColor: AsterTheme.surfaceInset(context),
                                                  valueColor: AlwaysStoppedAnimation(
                                                    AsterTheme.secondary(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Perfil do Usuário
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AsterTheme.primary(context).withValues(alpha: 0.15),
                                      backgroundImage: _userProfile?['avatar_url'] != null
                                          ? ResizeImage(
                                              NetworkImage(_userProfile!['avatar_url']),
                                              width: 72,
                                              height: 72,
                                            )
                                          : null,
                                      child: _userProfile?['avatar_url'] == null
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
                                            _isGuestMode
                                                ? 'Modo de Teste · ${_currentStreakDays}d'
                                                : 'Pro · Streak ${_currentStreakDays}d',
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.logout_rounded, size: 18, color: isDark ? AsterConstants.textMutedDark : AsterConstants.textMuted),
                                      tooltip: _isGuestMode ? 'Voltar para o Login' : 'Sair',
                                      onPressed: () {
                                        if (_isGuestMode) {
                                          setState(() {
                                            _isGuestMode = false;
                                          });
                                        } else {
                                          SupabaseService.signOut();
                                        }
                                      },
                                    ),
                                  ],
                                ),
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
                          _buildMobileNavItem(1, Icons.assignment_rounded, 'Simulados'),
                          _buildMobileNavItem(2, Icons.style_rounded, 'Flashcards'),
                          _buildMobileNavItem(3, Icons.menu_book_rounded, 'Cadernos'),
                          _buildMobileNavItem(7, Icons.auto_stories_rounded, 'Diário'),
                          _buildMobileNavItem(8, Icons.route_rounded, 'Trilhas'),
                          _buildMobileNavItem(4, Icons.smart_toy_rounded, 'Noesis AI'),
                          _buildMobileNavItem(5, Icons.calendar_today_rounded, 'Calendário'),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? cs.onPrimary : cs.onSurface,
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
