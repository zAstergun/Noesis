import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';

/// Retorna `true` quando rodando em ambiente de `flutter_test`, evitando que
/// animações contínuas (`repeat()`) travem `pumpAndSettle()`.
bool isLandingTestEnvironment() =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// Curva fluida principal inspirada no redesign (`cubic-bezier(0.2, 0.8, 0.2, 1)`).
const Curve kLandingFluidCurve = Cubic(0.2, 0.8, 0.2, 1.0);

/// Curva com leve overshoot elástico para o indicador deslizante de abas (`cubic-bezier(0.3, 1.15, 0.4, 1)`).
const Curve kLandingSpringCurve = Cubic(0.3, 1.15, 0.4, 1.0);

/// Fundo Soft Clay vivo com 3 esferas radiais que flutuam lentamente em segundo plano.
class LandingAmbientBackground extends StatefulWidget {
  const LandingAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<LandingAmbientBackground> createState() => _LandingAmbientBackgroundState();
}

class _LandingAmbientBackgroundState extends State<LandingAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftCtrl;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (!isLandingTestEnvironment()) {
      _driftCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final primary = theme.colorScheme.primary;
    final menta = AsterConstants.menta;
    final coral = AsterConstants.coral;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ColoredBox(
              color: bg,
              child: AnimatedBuilder(
                animation: _driftCtrl,
                builder: (context, _) {
                  final t = _driftCtrl.value;
                  final s1 = math.sin(t * math.pi);
                  final c1 = math.cos(t * math.pi);
                  return Stack(
                    children: [
                      // Orbe 1 (Lavanda/Primary topo-esquerda)
                      Positioned(
                        left: -160 + (t * 60),
                        top: -140 + (s1 * 42),
                        width: 580,
                        height: 580,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  primary.withValues(alpha: isDark ? 0.24 : 0.22),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Orbe 2 (Menta direita)
                      Positioned(
                        right: -150 + ((1 - t) * 55),
                        top: 120 + (c1 * 48),
                        width: 520,
                        height: 520,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  menta.withValues(alpha: isDark ? 0.16 : 0.17),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Orbe 3 (Coral inferior)
                      Positioned(
                        left: 180 + (s1 * 64),
                        bottom: -220 + (t * 45),
                        width: 500,
                        height: 500,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  coral.withValues(alpha: isDark ? 0.14 : 0.15),
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
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Entrada em cascata (fade + slide vertical suave) para o Hero ou itens de lista.
class LandingEntrance extends StatefulWidget {
  const LandingEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 780),
    this.offsetY = 24,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<LandingEntrance> createState() => _LandingEntranceState();
}

class _LandingEntranceState extends State<LandingEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: kLandingFluidCurve);

    if (isLandingTestEnvironment()) {
      _ctrl.value = 1.0;
    } else if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final v = _anim.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - v) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Revela o filho com fade + slide quando entra na viewport do [scrollController].
class LandingScrollReveal extends StatefulWidget {
  const LandingScrollReveal({
    super.key,
    required this.scrollController,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 28,
    this.onRevealed,
  });

  final ScrollController scrollController;
  final Widget child;
  final Duration delay;
  final double offsetY;
  final VoidCallback? onRevealed;

  @override
  State<LandingScrollReveal> createState() => _LandingScrollRevealState();
}

class _LandingScrollRevealState extends State<LandingScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _revealed = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: kLandingFluidCurve);

    if (isLandingTestEnvironment()) {
      _revealed = true;
      _ctrl.value = 1.0;
    } else {
      widget.scrollController.addListener(_checkVisibility);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
    }
  }

  void _checkVisibility() {
    if (_revealed || !mounted) return;
    final renderObj = context.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.hasSize) return;
    final top = renderObj.localToGlobal(Offset.zero).dy;
    final viewportH = MediaQuery.sizeOf(context).height;
    if (top <= viewportH * 0.94) {
      _revealed = true;
      widget.scrollController.removeListener(_checkVisibility);
      if (widget.delay == Duration.zero) {
        _ctrl.forward();
        widget.onRevealed?.call();
      } else {
        _delayTimer = Timer(widget.delay, () {
          if (!mounted) return;
          _ctrl.forward();
          widget.onRevealed?.call();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    widget.scrollController.removeListener(_checkVisibility);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final v = _anim.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - v) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Flutuação vertical contínua e suave (para os chips ao redor da janela Hero).
class LandingFloatingBob extends StatefulWidget {
  const LandingFloatingBob({
    super.key,
    required this.child,
    this.amplitude = 9.0,
    this.phaseShift = 0.0,
  });

  final Widget child;
  final double amplitude;
  final double phaseShift;

  @override
  State<LandingFloatingBob> createState() => _LandingFloatingBobState();
}

class _LandingFloatingBobState extends State<LandingFloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    if (!isLandingTestEnvironment()) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLandingTestEnvironment()) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final dy = math.sin((_ctrl.value * 2 * math.pi) + widget.phaseShift) *
            widget.amplitude;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Barra de abas com indicador em pílula deslizante e curva elástica suave.
class LandingSlidingPillTabs extends StatefulWidget {
  const LandingSlidingPillTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.activeFillColor,
    this.activeTextColor,
    this.backgroundColor,
    this.compact = false,
  });

  final List<({IconData icon, String label})> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Color? activeFillColor;
  final Color? activeTextColor;
  final Color? backgroundColor;
  final bool compact;

  @override
  State<LandingSlidingPillTabs> createState() => _LandingSlidingPillTabsState();
}

class _LandingSlidingPillTabsState extends State<LandingSlidingPillTabs> {
  late List<GlobalKey> _tabKeys;
  double _indLeft = 0;
  double _indWidth = 0;
  bool _hasLayout = false;

  @override
  void initState() {
    super.initState();
    _tabKeys = List.generate(widget.items.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureIndicator());
  }

  @override
  void didUpdateWidget(covariant LandingSlidingPillTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _tabKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureIndicator());
  }

  void _measureIndicator() {
    if (!mounted) return;
    final idx = widget.selectedIndex.clamp(0, _tabKeys.length - 1);
    final tabCtx = _tabKeys[idx].currentContext;
    final rowBox = context.findRenderObject() as RenderBox?;
    if (tabCtx == null || rowBox == null || !rowBox.hasSize) return;
    final tabBox = tabCtx.findRenderObject() as RenderBox?;
    if (tabBox == null || !tabBox.hasSize) return;

    final offset = tabBox.localToGlobal(Offset.zero, ancestor: rowBox);
    if ((_indLeft - offset.dx).abs() > 0.5 || (_indWidth - tabBox.size.width).abs() > 0.5 || !_hasLayout) {
      setState(() {
        _indLeft = offset.dx;
        _indWidth = tabBox.size.width;
        _hasLayout = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AsterTheme.primary(context);
    final cardCol = AsterTheme.card(context);
    final altCol = AsterTheme.surfaceAlt(context);
    final insetCol = AsterTheme.surfaceInset(context);
    final textCol = AsterTheme.text(context);
    final mutedCol = AsterTheme.textMuted(context);

    final fillCol = widget.activeFillColor ?? cardCol;
    final activeTextCol = widget.activeTextColor ?? textCol;
    final bgCol = widget.backgroundColor ?? altCol;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
        border: Border.all(color: insetCol.withValues(alpha: 0.85)),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_hasLayout && _indWidth > 0)
            AnimatedPositioned(
              duration: isLandingTestEnvironment()
                  ? Duration.zero
                  : const Duration(milliseconds: 440),
              curve: kLandingSpringCurve,
              left: _indLeft - 5,
              top: 0,
              bottom: 0,
              width: _indWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fillCol,
                  borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                  boxShadow: widget.activeFillColor != null
                      ? AsterTheme.primaryShadow(context, fillCol)
                      : AsterConstants.claySubtleShadow,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.items.length, (i) {
              final item = widget.items[i];
              final sel = i == widget.selectedIndex;
              return InkWell(
                key: _tabKeys[i],
                onTap: () => widget.onSelect(i),
                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 13 : 17,
                    vertical: widget.compact ? 8 : 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: sel
                            ? (widget.activeTextColor ?? primary)
                            : mutedCol,
                      ),
                      const SizedBox(width: 7),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: widget.compact ? 13 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: sel ? activeTextCol : mutedCol,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Card interativo do Bento com elevação no hover e brilho radial que segue o cursor.
class LandingSpotlightHoverScope extends InheritedWidget {
  const LandingSpotlightHoverScope({
    super.key,
    required this.hovered,
    required super.child,
  });

  final bool hovered;

  static bool isHoveredOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LandingSpotlightHoverScope>()?.hovered ?? false;

  @override
  bool updateShouldNotify(covariant LandingSpotlightHoverScope oldWidget) =>
      hovered != oldWidget.hovered;
}

class LandingSpotlightCard extends StatefulWidget {
  const LandingSpotlightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(26),
    this.borderRadius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  State<LandingSpotlightCard> createState() => _LandingSpotlightCardState();
}

class _LandingSpotlightCardState extends State<LandingSpotlightCard> {
  bool _hovered = false;
  Offset _cursor = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AsterTheme.primary(context);
    final cardCol = AsterTheme.card(context);
    final insetCol = AsterTheme.surfaceInset(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onHover: (e) => setState(() => _cursor = e.localPosition),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: kLandingFluidCurve,
        transform: Matrix4.translationValues(0, _hovered ? -5.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovered
                ? primary.withValues(alpha: isDark ? 0.55 : 0.35)
                : insetCol.withValues(alpha: isDark ? 0.75 : 0.9),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: isDark ? 0.22 : 0.14),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                    spreadRadius: -6,
                  ),
                  ...(isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow),
                ]
              : (isDark ? AsterConstants.clayDarkShadow : AsterConstants.clayShadow),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (_hovered)
              Positioned(
                left: _cursor.dx - 160,
                top: _cursor.dy - 160,
                width: 320,
                height: 320,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: isDark ? 0.13 : 0.09),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: widget.padding,
              child: LandingSpotlightHoverScope(
                hovered: _hovered,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper simples de micro-elevação para botões e cards clicáveis ao passar o mouse.
class LandingHoverLift extends StatefulWidget {
  const LandingHoverLift({
    super.key,
    required this.child,
    this.liftY = -3.0,
    this.scale = 1.0,
  });

  final Widget child;
  final double liftY;
  final double scale;

  @override
  State<LandingHoverLift> createState() => _LandingHoverLiftState();
}

class _LandingHoverLiftState extends State<LandingHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final matrix = Matrix4.identity()
      ..translateByDouble(0.0, _hovered ? widget.liftY : 0.0, 0.0, 1.0);
    if (_hovered && widget.scale != 1.0) {
      matrix.scaleByDouble(widget.scale, widget.scale, 1.0, 1.0);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: kLandingFluidCurve,
        transform: matrix,
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

/// Transição em 2 fases (sai primeiro -> entra depois) sem sobrepor dois conteúdos.
class LandingSequentialSwitcher extends StatefulWidget {
  const LandingSequentialSwitcher({
    super.key,
    required this.child,
    this.outDuration = const Duration(milliseconds: 140),
    this.inDuration = const Duration(milliseconds: 340),
    this.inOffset = const Offset(0, 12),
    this.outOffset = const Offset(0, 10),
  });

  final Widget child;
  final Duration outDuration;
  final Duration inDuration;
  final Offset inOffset;
  final Offset outOffset;

  @override
  State<LandingSequentialSwitcher> createState() =>
      _LandingSequentialSwitcherState();
}

class _LandingSequentialSwitcherState extends State<LandingSequentialSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Widget _shownChild;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _shownChild = widget.child;
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.inDuration,
      value: 1.0,
    );
    _ctrl.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    if (_exiting && status == AnimationStatus.dismissed) {
      setState(() {
        _exiting = false;
        _shownChild = widget.child;
      });
      _ctrl.duration = widget.inDuration;
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant LandingSequentialSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.key != _shownChild.key) {
      if (isLandingTestEnvironment()) {
        _exiting = false;
        _shownChild = widget.child;
        _ctrl.value = 1.0;
      } else {
        _exiting = true;
        _ctrl.duration = widget.outDuration;
        _ctrl.reverse();
      }
    } else {
      _shownChild = widget.child;
      if (_exiting) {
        _exiting = false;
        _ctrl.duration = widget.inDuration;
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final raw = _ctrl.value;
        final curved = kLandingFluidCurve.transform(raw);
        final offset = _exiting
            ? widget.outOffset * (1.0 - raw)
            : widget.inOffset * (1.0 - curved);
        return Opacity(
          opacity: (_exiting ? raw : curved).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: offset,
            child: _shownChild,
          ),
        );
      },
    );
  }
}
