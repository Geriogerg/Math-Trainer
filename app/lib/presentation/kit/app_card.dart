import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'caption.dart';

/// A full-width tappable card (Redesign phase, mockup 1: the Challenges):
/// its label, and from Phase 6b one line saying what it opens ([caption]:
/// review M16, "minimal text" relaxed for strangers).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.label,
    required this.onTap,
    this.detail,
    this.caption,
  });

  final String label;

  /// One line under the label: what the card opens.
  final String? caption;

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
      // Its edge at 3:1 (Phase 6b commit 6): the card alone was 1.08:1.
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outline),
      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (caption case final caption?) Caption(caption),
                    ],
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
