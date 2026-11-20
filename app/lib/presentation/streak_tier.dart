import 'package:material_ui/material_ui.dart';

import 'theme/app_theme.dart';

/// Phase 5 commit 6 (`doc/plan.md`): the streak counter and the timer bar
/// intensify at 5, 10 and 20 in a row — a colour step and a short pulse,
/// never a delay, never a size or position change (beta-safety rule).
const streakThresholds = [5, 10, 20];

/// 0 below 5 in a row, then 1, 2, 3.
int streakTier(int streak) =>
    streakThresholds.where((threshold) => streak >= threshold).length;

/// The streak's words: muted, then secondary text, then the accent.
Color streakTextColor(ThemeData theme, int tier) => switch (tier) {
  0 => theme.extension<AppPalette>()!.textMuted,
  1 => theme.colorScheme.onSurfaceVariant,
  _ => theme.colorScheme.primary,
};

/// The timer bar: the accent, drawn toward the primary text colour at each
/// tier (brighter at night, deeper by day).
Color timerBarColor(ThemeData theme, int tier) => Color.lerp(
  theme.colorScheme.primary,
  theme.colorScheme.onSurface,
  const [0.0, 0.25, 0.45, 0.65][tier],
)!;
