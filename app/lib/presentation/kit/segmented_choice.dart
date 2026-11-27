import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// One choice among a few, equal widths (Redesign phase, mockup 2: the
/// setup page's Questions, Mode and difficulty rows). The chosen segment is
/// filled with the accent **and** its label is set in the heavier weight —
/// never the colour alone (rule 14); screen readers hear it as selected.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final radius = BorderRadius.circular(metrics.radius / 2);
    return Row(
      children: [
        for (final (i, value) in values.indexed) ...[
          if (i > 0) SizedBox(width: metrics.keyGap * 1.5),
          Expanded(
            child: Semantics(
              button: true,
              inMutuallyExclusiveGroup: true,
              selected: value == selected,
              child: Material(
                color: value == selected
                    ? scheme.primary
                    : scheme.surfaceContainerHigh,
                // Its edge at 3:1 (Phase 6b commit 6, review M17).
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: value == selected ? scheme.primary : scheme.outline,
                  ),
                ),
                child: InkWell(
                  borderRadius: radius,
                  onTap: () => onChanged(value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: height),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          label(value),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: value == selected
                                ? scheme.onPrimary
                                : scheme.onSurface,
                            fontWeight: value == selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
