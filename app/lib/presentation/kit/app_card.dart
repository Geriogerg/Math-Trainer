import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// A full-width tappable card with a label only (Redesign phase, mockup 1:
/// the Challenges). The label carries the meaning; nothing else on it.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final String label;

  /// A short status at the end of the row ("3 due"); in words, never a
  /// colour alone (rule 14).
  final String? detail;

  /// `null`: shown, not tappable.
  final VoidCallback? onTap;

  static const minHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final radius = BorderRadius.circular(metrics.radius * 0.75);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (detail case final detail?)
                  Text(
                    detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
