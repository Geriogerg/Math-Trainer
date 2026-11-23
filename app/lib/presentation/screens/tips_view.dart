import 'package:material_ui/material_ui.dart';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tip_band.dart';

import '../exercise_type_labels.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';
import '../tips/tips.dart';

/// Key of a band's block, for tests: `tips-addition-intermediate`.
ValueKey<String> tipBandKey(ExerciseType type, TipBand band) =>
    ValueKey('tips-${type.name}-${band.name}');

/// The Tips page (`doc/levels.md`, section 8): one section per operation,
/// split into beginner (T0–T2), intermediate (T3–T5) and advanced (T6–T9);
/// each tip a sentence and a worked example. The band of the player's own
/// tier on each operation is marked — an outline, a marker icon and the
/// heavier weight, never the colour alone (rule 14) — and screen readers
/// hear it as selected.
class TipsView extends StatelessWidget {
  const TipsView({super.key, required this.levelOf, required this.onBack});

  /// The player's level on an operation (0 never played).
  final Level Function(ExerciseType type) levelOf;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return ListView(
      padding: metrics.rootPadding,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                'Tips',
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
            children: [
              OperatorIcon(type, size: 20),
              const SizedBox(width: 8),
              Text(exerciseTypeLabel(type), style: theme.textTheme.titleMedium),
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
              ),
        ],
      ],
    );
  }
}

class _BandBlock extends StatelessWidget {
  const _BandBlock({
    super.key,
    required this.band,
    required this.tips,
    required this.mine,
  });

  final TipBand band;
  final List<Tip> tips;
  final bool mine;

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
                    TipBand.beginner => 'Beginner',
                    TipBand.intermediate => 'Intermediate',
                    TipBand.advanced => 'Advanced',
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
                    semanticLabel: 'Your level',
                  ),
                ],
              ],
            ),
            for (final tip in tips) ...[
              const SizedBox(height: 8),
              Text(tip.text, style: theme.textTheme.bodyMedium),
              Text(
                tip.example,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
