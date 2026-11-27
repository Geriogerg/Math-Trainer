import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../strings/strings.dart';

/// A level, always as a whole number (`doc/design.md`): the digit face in
/// the accent, inside an accent outline (Phase 5 commit 2). Profile rows,
/// the leaderboard, the overall level on Play. Screen readers hear
/// "Level 12".
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.large = false});

  /// The whole level (`Level.whole`); `null`: not played yet — a dash.
  final int? level;

  /// The overall level (Play, Profile): the answer's size.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final played = level != null;
    final color = played
        ? scheme.primary
        : theme.extension<AppPalette>()!.textMuted;
    final style =
        (large ? theme.textTheme.headlineMedium : theme.textTheme.titleMedium)
            ?.digits
            .copyWith(color: color, fontWeight: FontWeight.w500);
    return Semantics(
      label: switch (level) {
        final level? => strings.game.levelBadge(level),
        null => strings.game.notPlayed,
      },
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: large ? 64 : 40),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 8,
          vertical: large ? 4 : 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radius / 2),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          played ? '$level' : '—',
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}
