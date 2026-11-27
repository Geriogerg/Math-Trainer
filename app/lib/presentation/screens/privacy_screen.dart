import 'package:material_ui/material_ui.dart';

import '../strings/privacy_strings.dart';
import '../theme/app_theme.dart';

/// The short privacy notice (plan v2.3, Phase 3a commit 4): what is stored,
/// why, and how to delete it — real people give data even in a beta. The
/// full legal pages come with the public launch (Phase 6). Plain text, no
/// link out: it must read the same offline.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  /// The notice's sections (`strings/privacy_strings.dart`).
  static const sections = privacySections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: theme.extension<AppMetrics>()!.rootPadding,
          children: [
            for (final (title, points) in sections) ...[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(point, style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
