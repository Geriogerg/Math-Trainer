import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// A full-width tappable card with a label only (Redesign phase, mockup 1:
/// the Challenges). The label carries the meaning; nothing else on it.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.label, required this.onTap});

  final String label;

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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
