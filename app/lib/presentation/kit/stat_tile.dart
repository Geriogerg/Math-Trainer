import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// One number with its label (Phase 5 commit 2): the result screen's score,
/// counts and times, the Profile's figures. The number in the digit face,
/// the label under it in muted text.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.emphasis = false,
  });

  /// Already formatted ("1 830 ms", "12").
  final String value;
  final String label;

  /// The screen's headline number (the score): larger, on the accent's
  /// outline.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final valueStyle =
        (emphasis ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)
            ?.digits
            .copyWith(fontWeight: FontWeight.w500, color: scheme.onSurface);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(metrics.radius),
          border: Border.all(color: emphasis ? scheme.primary : scheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: valueStyle, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.extension<AppPalette>()!.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiles side by side, sharing the width equally.
class StatTileRow extends StatelessWidget {
  const StatTileRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, tile) in tiles.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tile),
        ],
      ],
    );
  }
}
