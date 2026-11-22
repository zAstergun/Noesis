import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
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
import 'features/settings/settings_screen.dart';

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
    PointerDeviceKind.stylus,
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AsterTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: AsterConstants.appName,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AsterScrollBehavior(),
          theme: AsterTheme.softClayTheme,
          darkTheme: AsterTheme.darkTheme,
          themeMode: themeMode,
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

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  late final ValueNotifier<int> _activeTabNotifier;
  Map<String, dynamic>? _userProfile;
  bool _isGuestMode = false;
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;

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
      targetTab: 3,
    ),
    _NotificationItem(
      id: '4',
      title: 'Insight do Agente Cognitivo',
      message: 'Sua retenção em Sistemas Distribuídos aumentou 14% após a revisão espaçada.',
      time: 'Ontem',
      icon: Icons.auto_awesome_rounded,
      color: AsterConstants.lavanda,
      targetTab: 2,
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
        return const AiAssistantScreen();
      case 3:
        return const CalendarScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const TrackerScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _activeTabNotifier = ValueNotifier<int>(0);
    _session = SupabaseService.client.auth.currentSession;
    _authSubscription = SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        final newSession = data.session;
        if (_session?.user.id != newSession?.user.id) {
          setState(() {
            _session = newSession;
          });
          _loadProfile();
        }
      }
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _activeTabNotifier.dispose();
    super.dispose();
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

    return Container(
      decoration: BoxDecoration(
        color: AsterConstants.surfaceCard,
        borderRadius: BorderRadius.circular(AsterConstants.radiusLarge),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: AsterConstants.clayShadow,
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
                  color: AsterConstants.surfaceInset,
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
                    color: AsterConstants.lavanda.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: AsterConstants.lavanda,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Notificações',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AsterConstants.textDark,
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
                        color: AsterConstants.lavanda,
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
                          decoration: const BoxDecoration(
                            color: AsterConstants.surfaceAlt,
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
                            color: AsterConstants.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Você não tem novas notificações no momento.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AsterConstants.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 64,
                      endIndent: 20,
                      color: AsterConstants.surfaceAlt,
                    ),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
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
                                    color: item.color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(item.icon, size: 18, color: item.color),
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
                                                color: AsterConstants.textDark,
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
                                          color: item.isRead ? AsterConstants.textFaint : AsterConstants.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.time,
                                        style: GoogleFonts.manrope(
                                          fontSize: 10,
                                          color: AsterConstants.textFaint,
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
            const Divider(height: 1, color: AsterConstants.surfaceInset),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Toque para abrir no app',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: AsterConstants.textFaint,
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
            child: Row(
              children: [
                // ─── Sidebar Oficial Soft Clay (Desktop / Tablet) ───
                if (isWideScreen)
                  RepaintBoundary(
                    child: Container(
                      width: 240,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF191A26) : AsterConstants.surfaceCard,
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
                        // Logo Noesis Soft Clay
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AsterConstants.lavanda,
                                shape: BoxShape.circle,
                                boxShadow: AsterConstants.primaryButtonShadow,
                              ),
                              child: const Center(
                                child: Text(
                                  'N',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Noesis',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AsterConstants.textDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
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
                          title: 'Noesis AI',
                          icon: Icons.smart_toy_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem(
                          index: 3,
                          title: 'Calendário',
                          icon: Icons.calendar_today_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem(
                          index: 4,
                          title: 'Configurações',
                          icon: Icons.settings_rounded,
                        ),

                        const Spacer(),

                        // Widget: Meta Semanal
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AsterConstants.surfaceAlt,
                            borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'META SEMANAL',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AsterConstants.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '18h / 25h',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AsterConstants.textDark,
                                    ),
                                  ),
                                  Text(
                                    '72%',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AsterConstants.menta,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: 0.72,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                backgroundColor: AsterConstants.surfaceInset,
                                valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Perfil do Usuário
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AsterConstants.lavanda.withValues(alpha: 0.15),
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
                                          color: AsterConstants.lavanda,
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
                                        color: AsterConstants.textDark,
                                      ),
                                    ),
                                    Text(
                                      _isGuestMode ? 'Modo de Teste' : 'Pro · Streak 42d',
                                      style: GoogleFonts.manrope(
                                        fontSize: 11,
                                        color: AsterConstants.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout_rounded, size: 18, color: AsterConstants.textMuted),
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

                // ─── Área Principal de Conteúdo ───
                Expanded(
                  child: Column(
                    children: [
                      // Header Top Bar (Isolado para repaint eficiente)
                      RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                          child: Row(
                          children: [
                            if (!isWideScreen) ...[
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AsterConstants.lavanda,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Noesis',
                                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AsterConstants.textDark),
                              ),
                            ] else ...[
                              ValueListenableBuilder<int>(
                                valueListenable: _activeTabNotifier,
                                builder: (context, activeIndex, _) {
                                  if (activeIndex != 0) return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_greeting, $userName.',
                                        style: GoogleFonts.manrope(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AsterConstants.textDark,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${_formatTodayDate()} · 42 dias de streak ',
                                            style: GoogleFonts.manrope(
                                              fontSize: 13,
                                              color: AsterConstants.textMuted,
                                            ),
                                          ),
                                          const Text('🔥', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],

                            const Spacer(),

                            if (_isGuestMode) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AsterConstants.ambar.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isGuestMode = false;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.logout_rounded, size: 14, color: AsterConstants.ambar),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Sair do Teste',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AsterConstants.ambar,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],

                            // Botão Interativo de Notificações
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: AsterConstants.surfaceCard,
                                    shape: BoxShape.circle,
                                    boxShadow: AsterConstants.claySubtleShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showNotificationsPanel(context, isWideScreen),
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Center(
                                        child: Icon(
                                          Icons.notifications_none_rounded,
                                          size: 20,
                                          color: AsterConstants.textDark,
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
                                        border: Border.all(color: Colors.white, width: 2),
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
                      ),

                      // Telas do App com Carregamento Sob Demanda (Lazy Cache)
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _activeTabNotifier,
                          builder: (context, activeIndex, _) {
                            _loadedTabs.add(activeIndex);
                            return IndexedStack(
                              index: activeIndex,
                              children: List.generate(5, (index) {
                                if (_loadedTabs.contains(index)) {
                                  return RepaintBoundary(child: _buildScreen(index));
                                }
                                return const SizedBox.shrink();
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Bottom Navigation Bar Soft Clay para Mobile ───
          bottomNavigationBar: !isWideScreen
              ? RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF191A26) : AsterConstants.surfaceCard,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.3)
                              : const Color.fromRGBO(60, 60, 120, 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMobileNavItem(0, Icons.home_rounded, 'Dashboard'),
                        _buildMobileNavItem(1, Icons.assignment_rounded, 'Simulados'),
                        _buildMobileNavItem(2, Icons.smart_toy_rounded, 'Noesis AI'),
                        _buildMobileNavItem(3, Icons.calendar_today_rounded, 'Calendário'),
                        _buildMobileNavItem(4, Icons.settings_rounded, 'Config'),
                      ],
                    ),
                  ),
                )
              : null,
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
        final isSelected = activeIndex == index;

        return Container(
          decoration: BoxDecoration(
            color: isSelected ? AsterConstants.lavanda : Colors.transparent,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            boxShadow: isSelected ? AsterConstants.primaryButtonShadow : null,
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
                      color: isSelected ? Colors.white : AsterConstants.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : AsterConstants.textDark),
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
              color: isSelected ? AsterConstants.lavanda.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AsterConstants.lavanda : AsterConstants.textMuted,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AsterConstants.lavanda : AsterConstants.textMuted,
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
