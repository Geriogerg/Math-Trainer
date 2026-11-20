import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// An operation (or a board) the player can pick (Phase 5 commit 2): the
/// type selection on Play, the boards of the Leaderboard.
///
/// Selected: accent outline, tinted surface **and** a check mark before the
/// label — never colour alone (rule 14). `leading` (the operator's icon,
/// `OperatorIcon`) stays visible either way.
/// Built on Material's `FilterChip` for focus, keyboard and semantics
/// (`selected` is announced).
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.leading,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  /// Before the label, selected or not: the operator's icon.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Icon(Icons.check, size: 16, color: scheme.primary),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      avatar: leading,
      showCheckmark: false,
      labelStyle: theme.textTheme.bodyLarge?.copyWith(
        color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outline,
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.radius / 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }
}
