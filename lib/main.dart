import 'package:flutter/material.dart';
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

  // Inicializar Supabase com a instância oficial do Aster
  await Supabase.initialize(
    url: AsterConstants.supabaseUrl,
    anonKey: AsterConstants.supabaseAnonKey,
  );

  runApp(const AsterStudyApp());
}

class AsterStudyApp extends StatelessWidget {
  const AsterStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AsterConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AsterTheme.darkTheme,
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
    CalendarScreen(),
    AiAssistantScreen(),
    QuizScreen(),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? SupabaseService.client.auth.currentSession;

        if (session == null) {
          return AuthScreen(onAuthenticated: _loadProfile);
        }

        final isWideScreen = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          body: Row(
            children: [
              // Navigation Rail para Telas Desktop e Tablet
              if (isWideScreen)
                NavigationRail(
                  backgroundColor: AsterConstants.surfaceDark,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AsterConstants.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: AsterConstants.primary, width: 2),
                          ),
                          child: const Icon(Icons.auto_stories_rounded, color: AsterConstants.secondary, size: 22),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'NOESIS',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: AsterConstants.secondary),
                        ),
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: AsterConstants.textDim),
                          tooltip: 'Sair da Aster Account',
                          onPressed: () => SupabaseService.signOut(),
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.timer_outlined),
                      selectedIcon: Icon(Icons.timer, color: AsterConstants.secondary),
                      label: Text('Tracker'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month, color: AsterConstants.secondary),
                      label: Text('Calendário'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome, color: AsterConstants.secondary),
                      label: Text('Aster AI'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.psychology_outlined),
                      selectedIcon: Icon(Icons.psychology, color: AsterConstants.secondary),
                      label: Text('Simulados'),
                    ),
                  ],
                ),

              // Conteúdo da Tela Selecionada
              Expanded(
                child: Column(
                  children: [
                    // Top Bar de Identidade Aster
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(
                        color: AsterConstants.surfaceDark,
                        border: Border(bottom: BorderSide(color: AsterConstants.borderDark)),
                      ),
                      child: Row(
                        children: [
                          if (!isWideScreen) ...[
                            const Icon(Icons.auto_stories_rounded, color: AsterConstants.secondary, size: 22),
                            const SizedBox(width: 8),
                            const Text('Noesis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                          const Spacer(),
                          // Badge de Perfil do Aster
                          if (_userProfile != null) ...[
                            if (_userProfile!['is_vip'] == true)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AsterConstants.accentAmber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AsterConstants.accentAmber),
                                ),
                                child: const Text('VIP', style: TextStyle(color: AsterConstants.accentAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            Text(
                              _userProfile!['full_name'] ?? _userProfile!['channel'] ?? session.user.email ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AsterConstants.textLight),
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AsterConstants.cardDark,
                              backgroundImage: _userProfile!['avatar_url'] != null
                                  ? NetworkImage(_userProfile!['avatar_url'])
                                  : null,
                              child: _userProfile!['avatar_url'] == null
                                  ? const Icon(Icons.person, size: 18, color: AsterConstants.secondary)
                                  : null,
                            ),
                          ] else ...[
                            Text(session.user.email ?? '', style: const TextStyle(fontSize: 13, color: AsterConstants.textMuted)),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.logout, size: 18, color: AsterConstants.textDim),
                              onPressed: () => SupabaseService.signOut(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(child: _screens[_selectedIndex]),
                  ],
                ),
              ),
            ],
          ),
          // Bottom Navigation Bar para Telas Mobile / Pequenas
          bottomNavigationBar: !isWideScreen
              ? BottomNavigationBar(
                  backgroundColor: AsterConstants.surfaceDark,
                  currentIndex: _selectedIndex,
                  selectedItemColor: AsterConstants.secondary,
                  unselectedItemColor: AsterConstants.textDim,
                  type: BottomNavigationBarType.fixed,
                  onTap: (idx) => setState(() => _selectedIndex = idx),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.timer_outlined), label: 'Tracker'),
                    BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Calendário'),
                    BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), label: 'Aster AI'),
                    BottomNavigationBarItem(icon: Icon(Icons.psychology_outlined), label: 'Simulados'),
                  ],
                )
              : null,
        );
      },
    );
  }
}
