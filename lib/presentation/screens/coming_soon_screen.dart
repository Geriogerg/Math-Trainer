import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Generic screen for a tab whose navigation entry already exists but
/// whose feature is outside the current phase ("chrome in place, content
/// pending").
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: theme.extension<AppMetrics>()!.rootPadding,
      child: Center(
        child: Text(
          '$label — coming soon',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.extension<AppPalette>()?.textMuted,
          ),
        ),
      ),
    );
  }
}
