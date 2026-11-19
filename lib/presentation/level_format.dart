/// A level change in hundredths as the player reads it: `+0.42`, `−1.05`,
/// `±0.00`. The level itself is shown as a whole number (`Level.whole`);
/// this is the only place its hundredths reach the screen, so a session
/// that moves the level by less than one whole step still shows that it
/// counted (plan, pillar 2: visible progress).
String formatLevelChange(int hundredthsDelta) {
  final magnitude = hundredthsDelta.abs();
  final text =
      '${magnitude ~/ 100}.${(magnitude % 100).toString().padLeft(2, '0')}';
  if (hundredthsDelta > 0) return '+$text';
  if (hundredthsDelta < 0) return '−$text';
  return '±$text';
}
