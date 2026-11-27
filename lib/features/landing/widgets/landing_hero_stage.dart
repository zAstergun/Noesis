import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants.dart';
import '../../../core/localization/noesis_l10n.dart';
import '../../../core/theme.dart';
import '../../../widgets/insight_icon.dart';
import '../../../widgets/noesis_logo.dart';
import 'landing_motion.dart';

/// Hero completo da Landing Page do Noesis, inspirado no redesign web
/// com janela interativa ao vivo (Timer Stopwatch/Pomodoro + Heatmap,
/// Noesis AI com Tool Calling animado e Simulado RAG interativo).
class LandingHeroSection extends StatefulWidget {
  const LandingHeroSection({
    super.key,
    required this.width,
    required this.onOpenLogin,
    required this.onExploreResources,
  });

  final double width;
  final VoidCallback onOpenLogin;
  final VoidCallback onExploreResources;

  @override
  State<LandingHeroSection> createState() => _LandingHeroSectionState();
}

class _LandingHeroSectionState extends State<LandingHeroSection>
    with TickerProviderStateMixin {
  int _activeTab = 0; // 0 = Timer, 1 = Noesis AI, 2 = Simulados RAG

  // Tilt 3D / Parallax 60fps suave no desktop (equivalente ao #stage -> #bezel da referência)
  final GlobalKey _stageKey = GlobalKey();
  final ValueNotifier<Offset> _tiltNotifier = ValueNotifier<Offset>(Offset.zero);
  Offset _tiltTarget = Offset.zero;
  Offset _tiltCurrent = Offset.zero;
  late final Ticker _tiltTicker;

  // Estado da aba Timer
  int _timerSeconds = 28 * 60 + 39;
  bool _timerRunning = true;
  bool _isPomodoroMode = false;
  int _selectedHeatIndex = 101;
  Timer? _tickTimer;

  // Estado interativo do Heatmap (permite clicar para alternar intensidade como na referência)
  late final List<int> _heatLevels = _generateInitialHeatLevels();

  static List<int> _generateInitialHeatLevels() {
    return List<int>.generate(15 * 7, (i) {
      final r = (math.sin(i * 12.9898) * 43758.5453).abs() % 1.0;
      return math.min(4, (r * r * 5.2).floor());
    });
  }

  // Estado da aba Noesis AI (animação sequencial de digitação + tool calls)
  late final AnimationController _pulseController;
  final List<Timer> _aiTimers = [];
  String _typedPrompt = '';
  bool _aiSendPulse = false;
  bool _aiSent = false;
  int _aiToolsStage = 0; // 0..3: quantas tools iniciaram
  int _aiToolsDone = 0; // 0..3: quantas tools concluíram
  bool _aiCardVisible = false;

  // Estado da aba Simulado RAG
  int _quizIndex = 0;
  int? _selectedOption;
  int _quizAnswerEpoch = 0;

  static String get _aiDemoPrompt => NoesisL10n.tr(
      'Crie um simulado de Estruturas de Dados, gere flashcards e agende revisão para sexta.');

  static List<({String src, String question, List<String> options, int answer, String explanation})>
      get _ragQuestions => [
    (
      src: 'estruturas-de-dados.pdf · p.14',
      question: NoesisL10n.tr(
          'Qual é a complexidade média de busca em uma tabela hash bem dimensionada?'),
      options: ['O(n)', 'O(log n)', 'O(1)', 'O(n log n)'],
      answer: 2,
      explanation: NoesisL10n.tr(
          'Conforme o trecho citado, com boa função de espalhamento e fator de carga controlado, o acesso médio é constante: O(1).'),
    ),
    (
      src: 'estruturas-de-dados.pdf · p.22',
      question: NoesisL10n.tr('Qual estrutura de dados segue estritamente a política LIFO?'),
      options: [
        NoesisL10n.tr('Fila'),
        NoesisL10n.tr('Pilha'),
        NoesisL10n.tr('Lista circular'),
        NoesisL10n.tr('Heap binário'),
      ],
      answer: 1,
      explanation: NoesisL10n.tr(
          'A pilha remove primeiro o último elemento inserido (Last In, First Out).'),
    ),
    (
      src: 'estruturas-de-dados.pdf · p.31',
      question: NoesisL10n.tr(
          'Em uma árvore binária de busca balanceada (AVL), a busca custa no pior caso…'),
      options: ['O(log n)', 'O(n²)', 'O(1)', 'O(n)'],
      answer: 0,
      explanation: NoesisL10n.tr(
          'O balanceamento garante altura proporcional a log n, descartando metade da subárvore a cada comparação.'),
    ),
  ];

  static const List<int> _heatMinutes = [0, 45, 90, 150, 240];
  static List<String> get _heatLabels => [
    NoesisL10n.tr('sem estudo'),
    NoesisL10n.tr('foco leve'),
    NoesisL10n.tr('foco moderado'),
    NoesisL10n.tr('foco forte'),
    NoesisL10n.tr('foco máximo'),
  ];

  @override
  void initState() {
    super.initState();
    _tiltTicker = createTicker(_onTiltTick);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!isLandingTestEnvironment()) {
      _pulseController.repeat();
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_timerRunning || _activeTab != 0) return;
        setState(() {
          if (_isPomodoroMode) {
            _timerSeconds = _timerSeconds > 0 ? _timerSeconds - 1 : 25 * 60;
          } else {
            _timerSeconds++;
          }
        });
      });
    }
  }

  void _setTiltTarget(Offset target) {
    _tiltTarget = target;
    if (isLandingTestEnvironment()) {
      _tiltCurrent = target;
      _tiltNotifier.value = target;
      return;
    }
    if (!_tiltTicker.isActive) {
      _tiltTicker.start();
    }
  }

  void _onTiltTick(Duration _) {
    _tiltCurrent = Offset.lerp(_tiltCurrent, _tiltTarget, 0.16)!;
    if ((_tiltCurrent - _tiltTarget).distance < 0.002) {
      _tiltCurrent = _tiltTarget;
      _tiltTicker.stop();
    }
    _tiltNotifier.value = _tiltCurrent;
  }

  @override
  void dispose() {
    _tiltTicker.dispose();
    _tiltNotifier.dispose();
    _tickTimer?.cancel();
    _stopAiSimulation();
    _pulseController.dispose();
    super.dispose();
  }

  void _stopAiSimulation() {
    for (final t in _aiTimers) {
      t.cancel();
    }
    _aiTimers.clear();
  }

  void _runAiSimulation() {
    final prompt = context.tr(_aiDemoPrompt);
    _stopAiSimulation();
    setState(() {
      _typedPrompt = '';
      _aiSendPulse = false;
      _aiSent = false;
      _aiToolsStage = 0;
      _aiToolsDone = 0;
      _aiCardVisible = false;
    });

    const step = 3;
    var cursor = 0;
    void typeNext() {
      if (!mounted) return;
      if (cursor < prompt.length) {
        cursor = math.min(prompt.length, cursor + step);
        setState(() => _typedPrompt = prompt.substring(0, cursor));
        _aiTimers.add(Timer(const Duration(milliseconds: 28), typeNext));
      } else {
        _aiTimers.add(Timer(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _aiSendPulse = true);
        }));
        _aiTimers.add(Timer(const Duration(milliseconds: 420), () {
          if (!mounted) return;
          setState(() {
            _aiSendPulse = false;
            _typedPrompt = '';
            _aiSent = true;
          });
          for (var i = 1; i <= 3; i++) {
            _aiTimers.add(Timer(Duration(milliseconds: 280 + (i - 1) * 520), () {
              if (!mounted) return;
              setState(() => _aiToolsStage = i);
            }));
            _aiTimers.add(Timer(Duration(milliseconds: 680 + (i - 1) * 520), () {
              if (!mounted) return;
              setState(() => _aiToolsDone = i);
            }));
          }
          _aiTimers.add(Timer(const Duration(milliseconds: 2050), () {
            if (!mounted) return;
            setState(() => _aiCardVisible = true);
          }));
        }));
      }
    }

    _aiTimers.add(Timer(const Duration(milliseconds: 220), typeNext));
  }

  void _selectTab(int index) {
    if (_activeTab == index) return;
    _stopAiSimulation();
    setState(() => _activeTab = index);
    if (index == 1) {
      _runAiSimulation();
    }
  }

  String _formatHms(int totalSeconds) {
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.width < 600;
    final isWide = widget.width >= 960;
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final cardCol = AsterTheme.card(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Eyebrow Pill com ponto pulsante
        LandingEntrance(
          delay: const Duration(milliseconds: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardCol,
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              border: Border.all(color: insetCol.withValues(alpha: isDark ? 0.8 : 0.95)),
              boxShadow: isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(controller: _pulseController, color: AsterConstants.menta),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    context.tr('Cognitive OS & AI Study Engine · Ecossistema Aster'),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: isCompact ? 11.5 : 13,
                      fontWeight: FontWeight.w700,
                      color: mutedCol,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isWide ? 24 : 18),

        // Headline central de impacto (Space Grotesk)
        LandingEntrance(
          delay: const Duration(milliseconds: 130),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.spaceGrotesk(
                  fontSize: isWide ? 66 : (isCompact ? 34 : 48),
                  fontWeight: FontWeight.w700,
                  height: 1.04,
                  letterSpacing: isWide ? -2.2 : -1.2,
                  color: textCol,
                ),
                children: [
                  TextSpan(text: context.tr('O sistema operacional cognitivo que ')),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          primary,
                          Color.lerp(primary, AsterConstants.coral, 0.55)!,
                          AsterConstants.menta,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        context.tr('estuda com você.'),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: isWide ? 66 : (isCompact ? 34 : 48),
                          fontWeight: FontWeight.w700,
                          height: 1.04,
                          letterSpacing: isWide ? -2.2 : -1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Lead copy
        LandingEntrance(
          delay: const Duration(milliseconds: 220),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              context.tr('Foco Stopwatch & Pomodoro, simulados com RAG sobre 39 bancas, flashcards 3D, cadernos, trilhas, agenda em 4 visões e um agente autônomo com 20 ferramentas.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: isCompact ? 15 : 18,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: mutedCol,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // CTAs
        LandingEntrance(
          delay: const Duration(milliseconds: 300),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 12,
            children: [
              _HeroPrimaryButton(
                key: const Key('landing_open_login_button'),
                label: context.tr('Acessar ferramenta'),
                icon: Icons.arrow_forward_rounded,
                onTap: widget.onOpenLogin,
              ),
              _HeroSoftButton(
                label: context.tr('Explorar recursos'),
                icon: Icons.play_circle_outline_rounded,
                onTap: widget.onExploreResources,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Fatos rápidos reais do Noesis
        LandingEntrance(
          delay: const Duration(milliseconds: 370),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              _HeroFact(label: context.tr('Aster Account SSO (OAuth + Email)')),
              _HeroFact(label: context.tr('14 módulos integrados')),
              _HeroFact(label: context.tr('7 provedores de IA')),
              _HeroFact(label: context.tr('Windows · Web · Android · iOS')),
            ],
          ),
        ),
        SizedBox(height: isWide ? 48 : 32),

        // Janela interativa com bezel + tilt 3D + chips flutuantes
        LandingEntrance(
          delay: const Duration(milliseconds: 450),
          offsetY: 32,
          child: _buildStageWindow(context, isCompact: isCompact, isWide: isWide),
        ),
      ],
    );
  }

  Widget _buildStageWindow(
    BuildContext context, {
    required bool isCompact,
    required bool isWide,
  }) {
    final cardCol = AsterTheme.card(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final primary = AsterTheme.primary(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980),
      child: MouseRegion(
        key: _stageKey,
        onHover: isCompact
            ? null
            : (event) {
                final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                final local = box.globalToLocal(event.position);
                final nx = ((local.dx / box.size.width) - 0.5) * 2;
                final ny = ((local.dy / box.size.height) - 0.5) * 2;
                _setTiltTarget(
                  Offset(
                    nx.clamp(-1.0, 1.0),
                    ny.clamp(-1.0, 1.0),
                  ),
                );
              },
        onExit: (_) => _setTiltTarget(Offset.zero),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ValueListenableBuilder<Offset>(
              valueListenable: _tiltNotifier,
              builder: (context, tilt, child) {
                final tiltMatrix = isCompact
                    ? Matrix4.identity()
                    : (Matrix4.identity()
                      ..setEntry(3, 2, -0.0012)
                      ..rotateX(-tilt.dy * 0.095)
                      ..rotateY(tilt.dx * 0.115));
                return Transform(
                  alignment: Alignment.center,
                  transform: tiltMatrix,
                  child: child,
                );
              },
              child: Container(
                padding: EdgeInsets.all(isCompact ? 6 : 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isCompact ? 26 : 38),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(cardCol, primary, 0.12)!,
                      Color.lerp(altCol, primary, 0.08)!,
                    ],
                  ),
                  border: Border.all(
                    color: insetCol.withValues(alpha: isDark ? 0.85 : 1.0),
                  ),
                  boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: BorderRadius.circular(isCompact ? 20 : 28),
                    border: Border.all(
                      color: insetCol.withValues(alpha: isDark ? 0.65 : 0.75),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Top bar da janela mockup com dots + abas centralizadas (fiel à referência .win-bar)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : 18,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: altCol.withValues(alpha: 0.72),
                        border: Border(
                          bottom: BorderSide(
                            color: insetCol.withValues(alpha: isDark ? 0.7 : 0.9),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (!isCompact) ...[
                            const _Dot(color: AsterConstants.coral),
                            const SizedBox(width: 7),
                            const _Dot(color: AsterConstants.ambar),
                            const SizedBox(width: 7),
                            const _Dot(color: AsterConstants.menta),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: LandingSlidingPillTabs(
                                  compact: true,
                                  selectedIndex: _activeTab,
                                  onSelect: _selectTab,
                                  items: [
                                    (icon: Icons.timer_rounded, label: context.tr('Timer')),
                                    (icon: Icons.auto_awesome_rounded, label: context.tr('Noesis AI')),
                                    (icon: Icons.assignment_rounded, label: context.tr('Simulados')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isWide) ...[
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PulsingDot(
                                  controller: _pulseController,
                                  color: AsterConstants.menta,
                                  size: 6.5,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.tr('noesis://prévia'),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    color: mutedCol,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Conteúdo da aba ativa padronizado em altura ampla para exibir o dashboard real
                    Padding(
                      padding: EdgeInsets.all(isCompact ? 14 : 22),
                      child: SizedBox(
                        height: isCompact ? null : 536.0,
                        child: LandingSequentialSwitcher(
                          outDuration: const Duration(milliseconds: 140),
                          inDuration: const Duration(milliseconds: 340),
                          outOffset: const Offset(0, 8),
                          inOffset: const Offset(0, 12),
                          child: switch (_activeTab) {
                            0 => _buildTimerPane(context, isCompact: isCompact, textCol: textCol, mutedCol: mutedCol, primary: primary, altCol: altCol, cardCol: cardCol, insetCol: insetCol),
                            1 => _buildAiPane(context, isCompact: isCompact, textCol: textCol, mutedCol: mutedCol, primary: primary, altCol: altCol, cardCol: cardCol, insetCol: insetCol),
                            _ => _buildQuizPane(context, isCompact: isCompact, textCol: textCol, mutedCol: mutedCol, primary: primary, altCol: altCol, cardCol: cardCol, insetCol: insetCol),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),

            // Chips flutuantes posicionados nas bordas externas sem cobrir métricas
            if (isWide) ...[
              PositionedDirectional(
                top: 60,
                start: -28,
                child: LandingFloatingBob(
                  phaseShift: 0.0,
                  amplitude: 8.0,
                  child: _FloatingStageChip(
                    tiltListenable: _tiltNotifier,
                    depth: const Offset(-20, -14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const InsightCoinIcon(size: 16),
                        const SizedBox(width: 7),
                        Text(
                          context.tr('+24 Insights'),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -20,
                end: 56,
                child: LandingFloatingBob(
                  phaseShift: 2.1,
                  amplitude: 7.0,
                  child: _FloatingStageChip(
                    tiltListenable: _tiltNotifier,
                    depth: const Offset(-24, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 15, color: primary),
                        const SizedBox(width: 7),
                        Text(
                          context.tr('20 ações no agente'),
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerPane(
    BuildContext context, {
    required bool isCompact,
    required Color textCol,
    required Color mutedCol,
    required Color primary,
    required Color altCol,
    required Color cardCol,
    required Color insetCol,
  }) {
    final selLevel = _heatLevels[_selectedHeatIndex];
    final selMins = _heatMinutes[selLevel];
    final selName = context.tr(_heatLabels[selLevel]);
    const dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final dayName = context.tr(dayNames[_selectedHeatIndex % 7]);
    final onPrimary = AsterTheme.onPrimary(context);

    final sessionGoalSecs = _isPomodoroMode ? 25 * 60 : 90 * 60;
    final sessionProgress = (_timerSeconds / sessionGoalSecs).clamp(0.08, 1.0);

    final timerCard = Container(
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: altCol,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: insetCol.withValues(alpha: 0.72)),
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
                  Expanded(
                    child: Text(
                      context.tr('SESSÃO DE FOCO'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: mutedCol,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isPomodoroMode = !_isPomodoroMode;
                        _timerSeconds = _isPomodoroMode ? 25 * 60 : 28 * 60 + 39;
                      });
                    },
                    borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        _isPomodoroMode ? context.tr('Pomodoro 25m') : context.tr('Stopwatch'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AsterConstants.ambar.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const InsightCoinIcon(size: 13),
                        const SizedBox(width: 5),
                        Text(
                          context.tr('+24 INSIGHTS'),
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color.lerp(AsterConstants.ambar, textCol, 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 16 : 20),
              Text(
                _formatHms(_timerSeconds),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: isCompact ? 40 : 54,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2.0,
                  height: 1.0,
                  color: textCol,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      border: Border.all(color: insetCol.withValues(alpha: 0.85)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulsingDot(
                          controller: _pulseController,
                          color: _timerRunning ? AsterConstants.menta : AsterConstants.ambar,
                          size: 7,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.tr('Estruturas de Dados · bloco 3'),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      border: Border.all(color: insetCol.withValues(alpha: 0.85)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_outlined, size: 13.5, color: primary),
                        const SizedBox(width: 5),
                        Text(
                          context.tr('Meta {goal}', {'goal': _isPomodoroMode ? '25m' : '90m'}),
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: mutedCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Barra de progresso da sessão ativa + checkpoint (fiel ao TrackerScreen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: insetCol.withValues(alpha: 0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('Progresso da sessão'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: mutedCol,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            context.tr('Checkpoint #1 · 00:14:20'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: insetCol.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: sessionProgress,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            gradient: LinearGradient(
                              colors: [primary, AsterConstants.menta],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 16 : 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LandingHoverLift(
                liftY: -2.0,
                child: DecoratedBox(
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
                      onTap: () => setState(() => _timerRunning = !_timerRunning),
                      borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _timerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: onPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _timerRunning ? context.tr('Pausar') : context.tr('Retomar'),
                              style: GoogleFonts.manrope(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              LandingHoverLift(
                liftY: -2.0,
                child: Material(
                  color: cardCol,
                  shape: StadiumBorder(side: BorderSide(color: insetCol)),
                  child: InkWell(
                    onTap: () => setState(() {
                      _timerSeconds = _isPomodoroMode ? 25 * 60 : 0;
                    }),
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Text(
                        context.tr('Reiniciar'),
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textCol,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final ecosystemKpis = [
      (
        icon: Icons.assignment_turned_in_rounded,
        color: primary,
        title: context.tr('Simulados'),
        value: context.tr('12 feitos'),
        sub: context.tr('Média 84% acerto'),
      ),
      (
        icon: Icons.style_rounded,
        color: AsterConstants.ambar,
        title: context.tr('Flashcards'),
        value: context.tr('18 p/ revisar'),
        sub: context.tr('4 cadernos ativos'),
      ),
      (
        icon: Icons.route_rounded,
        color: AsterConstants.coral,
        title: context.tr('Trilhas'),
        value: context.tr('68% concl.'),
        sub: context.tr('3 eventos na semana'),
      ),
    ];

    Widget buildKpiTile(({IconData icon, Color color, String title, String value, String sub}) item) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: altCol,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: insetCol.withValues(alpha: 0.72)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 16, color: item.color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(item.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: mutedCol,
                    ),
                  ),
                  Text(
                    context.tr(item.value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: textCol,
                    ),
                  ),
                  Text(
                    context.tr(item.sub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: mutedCol,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final overviewStrip = isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < ecosystemKpis.length; i++) ...[
                buildKpiTile(ecosystemKpis[i]),
                if (i < ecosystemKpis.length - 1) const SizedBox(height: 8),
              ],
            ],
          )
        : Row(
            children: [
              for (int i = 0; i < ecosystemKpis.length; i++) ...[
                Expanded(child: buildKpiTile(ecosystemKpis[i])),
                if (i < ecosystemKpis.length - 1) const SizedBox(width: 10),
              ],
            ],
          );

    const weekDayBars = [
      (label: 'S', factor: 0.56),
      (label: 'T', factor: 0.80),
      (label: 'Q', factor: 0.44),
      (label: 'Q', factor: 0.96),
      (label: 'S', factor: 0.72),
      (label: 'S', factor: 0.36),
      (label: 'D', factor: 0.88),
    ];

    final goalAndHeatCard = Container(
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        color: altCol,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: insetCol.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    context.tr('META SEMANAL'),
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: mutedCol,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '12h30 / 20h · 62%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                ),
                clipBehavior: Clip.antiAlias,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 0.625),
                  duration: isLandingTestEnvironment()
                      ? Duration.zero
                      : const Duration(milliseconds: 1100),
                  curve: kLandingFluidCurve,
                  builder: (context, progress, _) {
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        heightFactor: 1.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            gradient: LinearGradient(
                              colors: [primary, AsterConstants.menta],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini gráfico semanal real (últimos 7 dias do TrackerScreen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardCol,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: insetCol.withValues(alpha: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('ÚLTIMOS 7 DIAS'),
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: mutedCol,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AsterConstants.menta.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                      ),
                      child: Text(
                        context.tr('+18% vs sem. ant.'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AsterConstants.menta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < weekDayBars.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(end: i == 6 ? 0 : 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: 32 * weekDayBars[i].factor,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        primary,
                                        primary.withValues(alpha: 0.35),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  weekDayBars[i].label,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: mutedCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    context.tr('HEATMAP DE FOCO'),
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: mutedCol,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.tr('15 semanas'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: mutedCol,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Grade 15x7 responsiva preenchendo 100% da largura
              Row(
                children: List.generate(15, (col) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: col == 14 ? 0 : (isCompact ? 3 : 4)),
                      child: Column(
                        children: List.generate(7, (row) {
                          final idx = col * 7 + row;
                          final lvl = _heatLevels[idx];
                          final isSel = idx == _selectedHeatIndex;
                          final alpha = switch (lvl) {
                            0 => 0.07,
                            1 => 0.22,
                            2 => 0.42,
                            3 => 0.66,
                            _ => 0.90,
                          };
                          return Padding(
                            padding: EdgeInsets.only(bottom: row == 6 ? 0 : (isCompact ? 3 : 4)),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => setState(() => _selectedHeatIndex = idx),
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _heatLevels[idx] = (_heatLevels[idx] + 1) % 5;
                                    _selectedHeatIndex = idx;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: kLandingFluidCurve,
                                    transform: isSel
                                        ? (Matrix4.identity()..scaleByDouble(1.24, 1.24, 1.0, 1.0))
                                        : Matrix4.identity(),
                                    transformAlignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: alpha),
                                      borderRadius: BorderRadius.circular(5),
                                      border: isSel
                                          ? Border.all(
                                              color: Color.lerp(primary, textCol, 0.25)!,
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                '$dayName · ${selMins > 0 ? "${selMins ~/ 60}h${(selMins % 60).toString().padLeft(2, '0')} · " : ""}$selName',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: mutedCol,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return KeyedSubtree(
      key: const ValueKey('hero_pane_timer'),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                timerCard,
                const SizedBox(height: 12),
                overviewStrip,
                const SizedBox(height: 12),
                goalAndHeatCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: timerCard),
                      const SizedBox(height: 12),
                      overviewStrip,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 10, child: goalAndHeatCard),
              ],
            ),
    );
  }

  Widget _buildAiPane(
    BuildContext context, {
    required bool isCompact,
    required Color textCol,
    required Color mutedCol,
    required Color primary,
    required Color altCol,
    required Color cardCol,
    required Color insetCol,
  }) {
    final actions = [
      context.tr('Gerar simulado'),
      context.tr('Criar flashcards'),
      context.tr('Agendar revisão'),
    ];

    final feedContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header contextual do roteador multi-provedor
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Text(
                context.tr('7 provedores · 20 ferramentas ativas'),
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _runAiSimulation,
              icon: const Icon(Icons.replay_rounded, size: 15),
              label: Text(
                context.tr('Reproduzir'),
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_aiSent) ...[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(20),
                  topEnd: Radius.circular(20),
                  bottomStart: Radius.circular(20),
                  bottomEnd: Radius.circular(6),
                ),
              ),
              child: Text(
                context.tr(_aiDemoPrompt),
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AsterTheme.onPrimary(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(actions.length, (i) {
              if (_aiToolsStage <= i) return const SizedBox.shrink();
              final done = _aiToolsDone > i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: done
                      ? AsterConstants.menta.withValues(alpha: 0.15)
                      : altCol,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  border: Border.all(
                    color: done
                        ? AsterConstants.menta.withValues(alpha: 0.45)
                        : insetCol,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (done)
                      const Icon(Icons.check_rounded, size: 14, color: AsterConstants.menta)
                    else
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      ),
                    const SizedBox(width: 7),
                    Text(
                      context.tr(actions[i]),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textCol,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
        ],

        if (_aiCardVisible)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: altCol,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: insetCol.withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const NoesisLogo(
                      size: 24,
                      withShadow: true,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      context.tr('Noesis AI · Agente Cognitivo'),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('Pronto! Organizei tudo diretamente nos seus módulos:'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textCol,
                  ),
                ),
                const SizedBox(height: 8),
                _AiActionResultRow(
                  icon: Icons.assignment_rounded,
                  title: context.tr('Simulado · Estruturas de Dados'),
                  tool: context.tr('Simulado pronto'),
                  cardCol: cardCol,
                  insetCol: insetCol,
                  primary: primary,
                  textCol: textCol,
                  mutedCol: mutedCol,
                ),
                const SizedBox(height: 6),
                _AiActionResultRow(
                  icon: Icons.style_rounded,
                  title: context.tr('Baralho 3D com revisão espaçada'),
                  tool: context.tr('Baralho salvo'),
                  cardCol: cardCol,
                  insetCol: insetCol,
                  primary: primary,
                  textCol: textCol,
                  mutedCol: mutedCol,
                ),
                const SizedBox(height: 6),
                _AiActionResultRow(
                  icon: Icons.calendar_today_rounded,
                  title: context.tr('Revisão agendada para sexta às 19h'),
                  tool: context.tr('No Calendário'),
                  cardCol: cardCol,
                  insetCol: insetCol,
                  primary: primary,
                  textCol: textCol,
                  mutedCol: mutedCol,
                ),
              ],
            ),
          )
        else if (!_aiSent && _typedPrompt.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: isCompact ? 42 : 160),
            child: Center(
              child: Text(
                context.tr('Iniciando demonstração do agente cognitivo…'),
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: mutedCol,
                ),
              ),
            ),
          ),
      ],
    );

    return Container(
      key: const ValueKey('hero_pane_ai'),
      constraints: isCompact ? const BoxConstraints(minHeight: 310) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isCompact)
            feedContent
          else
            Expanded(
              child: SingleChildScrollView(
                child: feedContent,
              ),
            ),
          const SizedBox(height: 12),
          // Barra de entrada do chat
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: altCol,
              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              border: Border.all(color: insetCol),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _typedPrompt.isNotEmpty
                        ? '$_typedPrompt|'
                        : context.tr('Pergunte algo ou anexe um PDF à Noesis…'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: _typedPrompt.isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                      color: _typedPrompt.isNotEmpty ? textCol : mutedCol,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _runAiSimulation,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  child: AnimatedScale(
                    scale: _aiSendPulse ? 0.86 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: kLandingSpringCurve,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send_rounded, size: 17, color: AsterTheme.onPrimary(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizPane(
    BuildContext context, {
    required bool isCompact,
    required Color textCol,
    required Color mutedCol,
    required Color primary,
    required Color altCol,
    required Color cardCol,
    required Color insetCol,
  }) {
    final q = _ragQuestions[_quizIndex];
    const letters = ['A', 'B', 'C', 'D'];
    final answered = _selectedOption != null;
    final isCorrect = answered && _selectedOption == q.answer;

    final quizBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Text(
                context.tr('Simulado RAG · 39 Bancas'),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: altCol,
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                border: Border.all(color: insetCol),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_rounded, size: 13.5, color: mutedCol),
                  const SizedBox(width: 5),
                  Text(
                    context.tr(q.src),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: mutedCol,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: AsterConstants.ambar.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
              ),
              child: Text(
                '${_quizIndex + 1} / ${_ragQuestions.length}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textCol,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(q.question),
          style: GoogleFonts.spaceGrotesk(
            fontSize: isCompact ? 18 : 22,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.4,
            color: textCol,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 560;
            final itemW = twoCols ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(q.options.length, (i) {
                var bg = altCol;
                var borderCol = insetCol;
                var badgeBg = cardCol;
                var badgeText = textCol;
                if (answered) {
                  if (i == q.answer) {
                    bg = AsterConstants.menta.withValues(alpha: 0.18);
                    borderCol = AsterConstants.menta;
                    badgeBg = AsterConstants.menta;
                    badgeText = Colors.white;
                  } else if (i == _selectedOption) {
                    bg = AsterConstants.coral.withValues(alpha: 0.18);
                    borderCol = AsterConstants.coral;
                    badgeBg = AsterConstants.coral;
                    badgeText = Colors.white;
                  }
                }
                return SizedBox(
                  width: itemW,
                  child: _QuizOptionFeedbackTile(
                    key: ValueKey('quiz_opt_${_quizIndex}_$i'),
                    letter: letters[i],
                    text: context.tr(q.options[i]),
                    answered: answered,
                    isSelected: i == _selectedOption,
                    isRightOption: i == q.answer,
                    epoch: _quizAnswerEpoch,
                    bg: bg,
                    borderCol: borderCol,
                    badgeBg: badgeBg,
                    badgeText: badgeText,
                    insetCol: insetCol,
                    textCol: textCol,
                    onTap: answered
                        ? null
                        : () => setState(() {
                              _selectedOption = i;
                              _quizAnswerEpoch++;
                            }),
                  ),
                );
              }),
            );
          },
        ),
        if (answered) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isCorrect ? AsterConstants.menta : AsterConstants.coral)
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCorrect) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: InsightCoinIcon(size: 16),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    '${isCorrect ? context.tr('Acertou! (+3 Insights) ') : context.tr('Quase! ')}${context.tr(q.explanation)}',
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textCol,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return KeyedSubtree(
      key: const ValueKey('hero_pane_quiz'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isCompact)
            quizBody
          else
            Expanded(
              child: SingleChildScrollView(
                child: quizBody,
              ),
            ),
          const SizedBox(height: 14),
          Row(
          children: [
            Row(
              children: List.generate(_ragQuestions.length, (i) {
                final on = i <= _quizIndex;
                return Container(
                  width: 28,
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  decoration: BoxDecoration(
                    color: on ? primary : insetCol,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
            const Spacer(),
            if (answered)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _quizIndex = (_quizIndex + 1) % _ragQuestions.length;
                    _selectedOption = null;
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  'Próxima',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: AsterTheme.onPrimary(context),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({
    required this.controller,
    required this.color,
    this.size = 9,
  });

  final AnimationController controller;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        return SizedBox(
          width: size * 2,
          height: size * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.7 + (v * 1.1),
                child: Container(
                  width: size * 1.6,
                  height: size * 1.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: (1 - v).clamp(0.0, 1.0) * 0.7),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroPrimaryButton extends StatefulWidget {
  const _HeroPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_HeroPrimaryButton> createState() => _HeroPrimaryButtonState();
}

class _HeroPrimaryButtonState extends State<_HeroPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AsterTheme.primary(context);
    final onPrimary = AsterTheme.onPrimary(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: kLandingFluidCurve,
        transform: Matrix4.translationValues(0, _hovered ? -2.5 : 0.0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(primary, Colors.white, _hovered ? 0.2 : 0.14)!,
              primary,
            ],
          ),
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          boxShadow: AsterTheme.primaryShadow(context, primary),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.manrope(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: kLandingFluidCurve,
                    transform: Matrix4.translationValues(_hovered ? 3.5 : 0.0, 0, 0),
                    child: Icon(widget.icon, size: 18, color: onPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSoftButton extends StatelessWidget {
  const _HeroSoftButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardCol = AsterTheme.card(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final textCol = AsterTheme.text(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LandingHoverLift(
      liftY: -2.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
          border: Border.all(color: insetCol),
          boxShadow: isDark ? AsterConstants.claySubtleDarkShadow : AsterConstants.claySubtleShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AsterTheme.primary(context)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: textCol,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_rounded, size: 16, color: AsterConstants.menta),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AsterTheme.textMuted(context),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FloatingStageChip extends StatelessWidget {
  const _FloatingStageChip({
    required this.tiltListenable,
    required this.depth,
    required this.child,
  });

  final ValueListenable<Offset> tiltListenable;
  final Offset depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: AsterTheme.card(context),
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(
          color: AsterTheme.surfaceInset(context).withValues(alpha: 0.9),
        ),
        boxShadow: isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow,
      ),
      child: child,
    );

    return ValueListenableBuilder<Offset>(
      valueListenable: tiltListenable,
      builder: (context, tilt, child) {
        return Transform.translate(
          offset: Offset(tilt.dx * depth.dx, tilt.dy * depth.dy),
          child: child,
        );
      },
      child: box,
    );
  }
}

class _AiActionResultRow extends StatelessWidget {
  const _AiActionResultRow({
    required this.icon,
    required this.title,
    required this.tool,
    required this.cardCol,
    required this.insetCol,
    required this.primary,
    required this.textCol,
    required this.mutedCol,
  });

  final IconData icon;
  final String title;
  final String tool;
  final Color cardCol;
  final Color insetCol;
  final Color primary;
  final Color textCol;
  final Color mutedCol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: insetCol.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
          ),
          Text(
            tool,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: mutedCol,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizOptionFeedbackTile extends StatefulWidget {
  const _QuizOptionFeedbackTile({
    super.key,
    required this.letter,
    required this.text,
    required this.answered,
    required this.isSelected,
    required this.isRightOption,
    required this.epoch,
    required this.bg,
    required this.borderCol,
    required this.badgeBg,
    required this.badgeText,
    required this.insetCol,
    required this.textCol,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool answered;
  final bool isSelected;
  final bool isRightOption;
  final int epoch;
  final Color bg;
  final Color borderCol;
  final Color badgeBg;
  final Color badgeText;
  final Color insetCol;
  final Color textCol;
  final VoidCallback? onTap;

  @override
  State<_QuizOptionFeedbackTile> createState() => _QuizOptionFeedbackTileState();
}

class _QuizOptionFeedbackTileState extends State<_QuizOptionFeedbackTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant _QuizOptionFeedbackTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isLandingTestEnvironment() &&
        widget.answered &&
        !oldWidget.answered &&
        widget.epoch != oldWidget.epoch) {
      if ((widget.isSelected && !widget.isRightOption) || widget.isRightOption) {
        _ctrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWrongPicked = widget.answered && widget.isSelected && !widget.isRightOption;
    final isRight = widget.answered && widget.isRightOption;
    final hoverLift = !widget.answered && _hovered ? -2.0 : 0.0;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final v = _ctrl.value;
          double dx = 0;
          double scale = 1;
          if (isWrongPicked && _ctrl.isAnimating) {
            dx = math.sin(v * math.pi * 4) * 6.0 * (1.0 - v);
          } else if (isRight && _ctrl.isAnimating) {
            scale = 1.0 + (math.sin(v * math.pi) * 0.035);
          }
          return Transform.translate(
            offset: Offset(dx, hoverLift),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: kLandingFluidCurve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: widget.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.borderCol, width: 1.4),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.badgeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.insetCol),
                  ),
                  child: Center(
                    child: Text(
                      widget.letter,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.badgeText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.text,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.textCol,
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
}
