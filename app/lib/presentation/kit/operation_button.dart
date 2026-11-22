import 'package:material_ui/material_ui.dart';

import 'package:math_core/models/exercise_type.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import 'operator_icon.dart';

/// One operation of a Home row (Redesign phase, mockup 1): its operator and
/// the player's level under it; tapping toggles it in the row's selection.
/// Selected: the accent outline, **thicker**, over a tinted surface — the
/// width tells it too, never the colour alone (rule 14); screen readers
/// hear "Addition, level 41, selected".
class OperationButton extends StatelessWidget {
  const OperationButton({
    super.key,
    required this.type,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final ExerciseType type;

  /// The whole level shown; 1 for an operation never played (the level it
  /// counts as).
  final int level;
  final bool selected;
  final VoidCallback? onTap;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final radius = BorderRadius.circular(metrics.radius * 0.75);
    return Semantics(
      button: true,
      selected: selected,
      label: '${exerciseTypeLabel(type)}, level $level',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OperatorIcon(
                  type,
                  size: 22,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
                const SizedBox(height: 4),
                Text(
                  '$level',
                  style: theme.textTheme.labelSmall?.digits.copyWith(
                    color: scheme.onSurfaceVariant,
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
