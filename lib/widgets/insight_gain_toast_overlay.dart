import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/localization/noesis_l10n.dart';
import '../core/shop_service.dart';
import '../core/theme.dart';
import 'insight_icon.dart';

/// Overlay global que exibe um aviso flutuante instantâneo sempre que o usuário
/// conquista Insights em qualquer área do Noesis (Simulados, Flashcards, Grupos,
/// Metas, Streaks ou Ranking), informando a quantidade ganha e o motivo exato.
class InsightGainToastOverlay extends StatefulWidget {
  const InsightGainToastOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<InsightGainToastOverlay> createState() => _InsightGainToastOverlayState();
}

class _ActiveToastEntry {
  _ActiveToastEntry({required this.event});

  final InsightGainEvent event;
  bool dismissing = false;
  Timer? autoDismissTimer;
  Timer? removeAfterExitTimer;

  void cancelTimers() {
    autoDismissTimer?.cancel();
    autoDismissTimer = null;
    removeAfterExitTimer?.cancel();
    removeAfterExitTimer = null;
  }
}

class _InsightGainToastOverlayState extends State<InsightGainToastOverlay> {
  static const int _maxVisibleToasts = 2;
  static const Duration _visibleDuration = Duration(milliseconds: 3000);
  static const Duration _exitAnimationDuration = Duration(milliseconds: 220);

  final List<_ActiveToastEntry> _entries = [];
  String? _lastHandledId;

  @override
  void initState() {
    super.initState();
    _lastHandledId = ShopService.instance.latestGainNotifier.value?.id;
    ShopService.instance.latestGainNotifier.addListener(_onGainEvent);
  }

  @override
  void dispose() {
    ShopService.instance.latestGainNotifier.removeListener(_onGainEvent);
    for (final entry in _entries) {
      entry.cancelTimers();
    }
    _entries.clear();
    super.dispose();
  }

  void _onGainEvent() {
    if (!mounted) return;
    final event = ShopService.instance.latestGainNotifier.value;
    if (event == null || event.amount <= 0) return;
    if (event.id == _lastHandledId) return;
    _lastHandledId = event.id;

    final entry = _ActiveToastEntry(event: event);
    entry.autoDismissTimer = Timer(_visibleDuration, () {
      _dismissEntry(entry.event.id);
    });

    setState(() {
      _entries.add(entry);
      while (_entries.length > _maxVisibleToasts) {
        final oldest = _entries.removeAt(0);
        oldest.cancelTimers();
      }
    });
  }

  void _dismissEntry(String id) {
    if (!mounted) return;
    final idx = _entries.indexWhere((e) => e.event.id == id);
    if (idx == -1) return;
    final entry = _entries[idx];
    if (entry.dismissing) return;

    entry.autoDismissTimer?.cancel();
    setState(() {
      entry.dismissing = true;
    });
    entry.removeAfterExitTimer = Timer(_exitAnimationDuration, () {
      if (!mounted) return;
      setState(() {
        _entries.removeWhere((e) {
          if (e.event.id == id) {
            e.cancelTimers();
            return true;
          }
          return false;
        });
      });
    });
  }

  String _sourceCategoryLabel(BuildContext context, String source) {
    switch (source) {
      case 'quiz_question':
      case 'exam_complete':
      case 'group_quiz':
        return context.tr('Simulado');
      case 'flashcard_review':
      case 'flashcard_redeem':
      case 'group_flashcard':
        return context.tr('Flashcard');
      case 'group_diary':
        return context.tr('Diário do Grupo');
      case 'daily_goal':
      case 'weekly_goal':
        return context.tr('Meta');
      case 'streak_milestone':
        return context.tr('Sequência');
      case 'ranking_reward':
        return context.tr('Ranking');
      case 'achievement':
        return context.tr('Conquista');
      default:
        return context.tr('Estudo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDesktop = screenWidth >= 700;

    return Stack(
      children: [
        widget.child,
        if (_entries.isNotEmpty)
          PositionedDirectional(
            key: const Key('insight_gain_toast_container'),
            top: topPadding + 14,
            end: isDesktop ? 20 : 14,
            start: isDesktop ? null : 14,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 360 : screenWidth - 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
                children: _entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _InsightGainToastCard(
                          key: Key('insight_gain_toast_${entry.event.id}'),
                          event: entry.event,
                          categoryLabel: _sourceCategoryLabel(context, entry.event.source),
                          dismissing: entry.dismissing,
                          onDismiss: () => _dismissEntry(entry.event.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _InsightGainToastCard extends StatefulWidget {
  const _InsightGainToastCard({
    super.key,
    required this.event,
    required this.categoryLabel,
    required this.dismissing,
    required this.onDismiss,
  });

  final InsightGainEvent event;
  final String categoryLabel;
  final bool dismissing;
  final VoidCallback onDismiss;

  @override
  State<_InsightGainToastCard> createState() => _InsightGainToastCardState();
}

class _InsightGainToastCardState extends State<_InsightGainToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _InsightGainToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.dismissing && widget.dismissing) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardCol = isDark ? AsterConstants.surfaceCardDark : AsterConstants.surfaceCard;
    final event = widget.event;
    final unit = event.amount == 1 ? 'Insight' : 'Insights';

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cardCol.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(AsterConstants.radiusMedium),
              border: Border.all(
                color: AsterConstants.menta.withValues(alpha: isDark ? 0.45 : 0.36),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AsterConstants.menta.withValues(alpha: isDark ? 0.18 : 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AsterConstants.menta.withValues(alpha: isDark ? 0.20 : 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: InsightCoinIcon(size: 20),
                  ),
                ),
                const SizedBox(width: 11),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '+${event.amount} $unit',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AsterConstants.menta,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AsterTheme.primary(context).withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                            ),
                            child: Text(
                              widget.categoryLabel,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AsterTheme.primary(context),
                              ),
                            ),
                          ),
                          if (event.isVipBoosted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(AsterConstants.radiusPill),
                              ),
                              child: Text(
                                '2× VIP',
                                style: GoogleFonts.manrope(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AsterTheme.textMuted(context),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: widget.onDismiss,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AsterTheme.textMuted(context),
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
