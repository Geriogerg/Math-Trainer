import 'package:material_ui/material_ui.dart';

/// Phase 5 commit 6 (`doc/plan.md`): the timer bar intensifies at 5, 10
/// and 20 in a row — a colour step, never a delay, never a size or position
/// change. (The streak line it once shared this with left the game screen
/// in the Redesign phase.)
const streakThresholds = [5, 10, 20];

/// 0 below 5 in a row, then 1, 2, 3.
int streakTier(int streak) =>
    streakThresholds.where((threshold) => streak >= threshold).length;

/// The timer bar: the accent, drawn toward the primary text colour at each
/// tier (brighter at night, deeper by day).
Color timerBarColor(ThemeData theme, int tier) => Color.lerp(
  theme.colorScheme.primary,
  theme.colorScheme.onSurface,
  const [0.0, 0.25, 0.45, 0.65][tier],
)!;
