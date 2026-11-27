import 'package:material_ui/material_ui.dart';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tip_band.dart';

import 'package:math_trainer/presentation/strings/exercise_type_labels.dart';
import '../kit/kit.dart';
import '../strings/strings.dart';
import '../theme/app_theme.dart';
import 'package:math_trainer/presentation/strings/tips.dart';

/// Key of a band's block, for tests: `tips-addition-intermediate`.
ValueKey<String> tipBandKey(ExerciseType type, TipBand band) =>
    ValueKey('tips-${type.name}-${band.name}');

/// The Tips page (`doc/levels.md`, section 8): one section per operation,
/// split into beginner (T0–T2), intermediate (T3–T5) and advanced (T6–T9);
/// each tip a sentence and a worked example. The band of the player's own
/// tier on each operation is marked — an outline, a marker icon and the
/// heavier weight, never the colour alone (rule 14) — and screen readers
/// hear it as selected.
/// The Drill button of [tip] (tests, the smoke test).
ValueKey<String> tipDrillKey(Tip tip) => ValueKey('drill-${tips.indexOf(tip)}');

class TipsView extends StatefulWidget {
  const TipsView({
    super.key,
    required this.levelOf,
    required this.onBack,
    this.focus,
    this.focusTip,
    this.onDrill,
  });

  /// The player's level on an operation (0 never played).
  final Level Function(ExerciseType type) levelOf;
  final VoidCallback onBack;

  /// Opened at this operation's section: "More tips" under a Method
  /// (`doc/levels.md` section 9).
  final ExerciseType? focus;

  /// Scrolled to and marked: the tip a Method followed.
  final Tip? focusTip;

  /// A Drill of a tip (Phase 4): every tip gets the button when given.
  final ValueChanged<Tip>? onDrill;

  @override
  State<TipsView> createState() => _TipsViewState();
}

class _TipsViewState extends State<TipsView> {
  final _sections = {for (final t in ExerciseType.values) t: GlobalKey()};
  final _tipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final focus = widget.focus;
    if (focus != null || widget.focusTip != null) {
      // After the first layout: the tip (or section) exists to scroll to.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = widget.focusTip != null
            ? _tipKey.currentContext
            : _sections[focus]!.currentContext;
        if (target != null && mounted) {
          Scrollable.ensureVisible(target, alignment: 0.05);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final levelOf = widget.levelOf;
    // A Column in a scroll view, not a ListView: every section is built, so
    // the one asked for can be scrolled to.
    return SingleChildScrollView(
      padding: metrics.rootPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: strings.common.back,
                onPressed: widget.onBack,
              ),
              Expanded(
                child: Text(
                  strings.home.tips,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          for (final type in ExerciseType.values) ...[
            const SizedBox(height: 24),
            Row(
              key: _sections[type],
              children: [
                OperatorIcon(type, size: 20),
                const SizedBox(width: 8),
                Text(
                  exerciseTypeLabel(type),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            for (final band in TipBand.values)
              if (tips.any((t) => t.type == type && t.band == band))
                _BandBlock(
                  key: tipBandKey(type, band),
                  band: band,
                  tips: [
                    for (final t in tips)
                      if (t.type == type && t.band == band) t,
                  ],
                  mine: TipBand.of(Tier.of(levelOf(type))) == band,
                  focusTip: widget.focusTip,
                  focusKey: _tipKey,
                  onDrill: widget.onDrill,
                ),
          ],
        ],
      ),
    );
  }
}

class _BandBlock extends StatelessWidget {
  const _BandBlock({
    super.key,
    required this.band,
    required this.tips,
    required this.mine,
    this.focusTip,
    this.focusKey,
    this.onDrill,
  });

  final ValueChanged<Tip>? onDrill;
  final TipBand band;
  final List<Tip> tips;
  final bool mine;
  final Tip? focusTip;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final muted = theme.extension<AppPalette>()!.textMuted;
    return Semantics(
      selected: mine,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radius / 2),
          border: Border.all(
            color: mine ? scheme.primary : Colors.transparent,
            width: 2,
          ),
          color: mine ? scheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  switch (band) {
                    final band => strings.game.tipBand(band),
                  },
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: mine ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.my_location,
                    size: 18,
                    color: scheme.primary,
                    semanticLabel: strings.game.yourLevel,
                  ),
                ],
              ],
            ),
            for (final tip in tips) ...[
              const SizedBox(height: 8),
              _TipText(
                key: identical(tip, focusTip) ? focusKey : null,
                tip: tip,
                focused: identical(tip, focusTip),
                muted: muted,
              ),
              if (onDrill case final drill?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton.secondary(
                    key: tipDrillKey(tip),
                    label: strings.game.drill,
                    semanticLabel: strings.game.drillLabel(tip.text),
                    onPressed: () => drill(tip),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tip: its sentence and its example. The one a Method led to is marked
/// by a bar and an arrow at its side (never the colour alone, rule 14) and
/// heard as selected.
class _TipText extends StatelessWidget {
  const _TipText({
    super.key,
    required this.tip,
    required this.focused,
    required this.muted,
  });

  final Tip tip;
  final bool focused;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tip.text, style: theme.textTheme.bodyMedium),
        Text(
          tip.example,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
    if (!focused) return body;
    final accent = theme.colorScheme.primary;
    return Semantics(
      selected: true,
      child: Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: body),
            Icon(Icons.arrow_back, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}
