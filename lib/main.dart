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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar suporte a formatação de datas em português
  await initializeDateFormatting('pt_BR', null);

  // Inicializar Supabase com a instância oficial do Aster
  await Supabase.initialize(
    url: AsterConstants.supabaseUrl,
    anonKey: AsterConstants.supabaseAnonKey,
  );

  runApp(const NoesisApp());
}

class NoesisApp extends StatelessWidget {
  const NoesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AsterConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AsterTheme.softClayTheme,
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userProfile;

  final List<Widget> _screens = const [
    TrackerScreen(),
    QuizScreen(),
    AiAssistantScreen(),
    CalendarScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? SupabaseService.client.auth.currentSession;

        if (session == null) {
          return AuthScreen(onAuthenticated: _loadProfile);
        }

        final isWideScreen = MediaQuery.of(context).size.width >= 900;
        final userName = _userProfile?['full_name'] ?? _userProfile?['channel'] ?? session.user.email?.split('@').first ?? 'Estudante';
        final initials = userName.isNotEmpty ? userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase() : 'AR';

        return Scaffold(
          body: SoftClayBackground(
            child: Row(
              children: [
                // ─── Sidebar Oficial Soft Clay (Desktop / Tablet) ───
                if (isWideScreen)
                  Container(
                    width: 240,
                    decoration: const BoxDecoration(
                      color: AsterConstants.surfaceCard,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(60, 60, 120, 0.05),
                          blurRadius: 20,
                          offset: Offset(4, 0),
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                child: LinearProgressIndicator(
                                  value: 0.72,
                                  minHeight: 6,
                                  backgroundColor: AsterConstants.surfaceInset,
                                  valueColor: const AlwaysStoppedAnimation(AsterConstants.menta),
                                ),
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
                                    ? NetworkImage(_userProfile!['avatar_url'])
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
                                      'Pro · Streak 42d',
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
                                tooltip: 'Sair',
                                onPressed: () => SupabaseService.signOut(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Área Principal de Conteúdo ───
                Expanded(
                  child: Column(
                    children: [
                      // Header Top Bar
                      Padding(
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bom dia, $userName.',
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
                              ),
                            ],

                            const Spacer(),

                            // Campo de Busca Suave Soft Clay
                            if (isWideScreen)
                              Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: AsterConstants.surfaceCard,
                                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                                  boxShadow: AsterConstants.claySubtleShadow,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search_rounded, size: 18, color: AsterConstants.textMuted),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Buscar',
                                      style: GoogleFonts.manrope(fontSize: 13, color: AsterConstants.textMuted),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AsterConstants.surfaceAlt,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '⌘K',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AsterConstants.textMuted, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 12),

                            // Ícone de Notificações
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AsterConstants.surfaceCard,
                                shape: BoxShape.circle,
                                boxShadow: AsterConstants.claySubtleShadow,
                              ),
                              child: const Icon(Icons.notifications_none_rounded, size: 20, color: AsterConstants.textDark),
                            ),
                            const SizedBox(width: 12),

                            // Avatar no Topo
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AsterConstants.lavanda,
                              child: Text(
                                initials,
                                style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Telas do App
                      Expanded(
                        child: _screens[_selectedIndex],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Bottom Navigation Bar Soft Clay para Mobile ───
          bottomNavigationBar: !isWideScreen
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AsterConstants.surfaceCard,
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(60, 60, 120, 0.08),
                        blurRadius: 20,
                        offset: Offset(0, -4),
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
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AsterConstants.lavanda : Colors.transparent,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        boxShadow: isSelected ? AsterConstants.primaryButtonShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
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
                    color: isSelected ? Colors.white : AsterConstants.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
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
  }
}
