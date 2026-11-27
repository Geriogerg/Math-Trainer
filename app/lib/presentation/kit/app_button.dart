import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The app's buttons (Phase 5 commit 2, `doc/plan.md` section 6.2), in
/// two roles:
/// - **primary** — the screen's main action (Start, Play again, Save):
///   filled with the accent; one per screen;
/// - **secondary** — every other action and the in-text links (Skip, New
///   selection, Privacy, a dialog's Cancel): the accent as text only.
///
/// Built on Material's buttons for focus, keyboard, semantics and the
/// disabled state; the look comes only from the theme tokens (accent,
/// `AppMetrics.radius` and `controlHeight`, the title style). Screens use
/// this, never `FilledButton`/`TextButton` directly.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
    this.semanticLabel,
  }) : _primary = true,
       destructive = false;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.destructive = false,
    this.semanticLabel,
  }) : _primary = false,
       compact = false;

  final String label;

  /// `null`: disabled — the screen says why next to it (`doc/design.md`,
  /// "A disabled state explains why").
  final VoidCallback? onPressed;

  /// Work started by this button is running: a small progress ring
  /// replaces the label, and the button cannot be pressed again.
  final bool busy;

  /// A secondary action that destroys something (Delete): the error colour,
  /// still quiet — irreversible actions are never the filled button.
  final bool destructive;

  /// A shorter primary button (Home's Play under each row, Redesign
  /// phase): [compactHeight], still a full touch target.
  final bool compact;

  static const compactHeight = 48.0;

  /// What screen readers say instead of [label], when the label alone is
  /// ambiguous on its screen (Home's two "Play": "Play Basics").
  final String? semanticLabel;

  final bool _primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(metrics.radius),
    );
    final minimumSize = Size(
      0,
      // 48: the smallest touch target (Redesign phase accessibility).
      compact ? compactHeight : (_primary ? metrics.controlHeight : 48),
    );
    final padding = EdgeInsets.symmetric(horizontal: _primary ? 24 : 12);
    final textStyle = _primary
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);
    final child = busy
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          )
        // A label that wraps (a long one, at 360 px) stays centred.
        : Text(
            label,
            semanticsLabel: semanticLabel,
            textAlign: TextAlign.center,
          );
    final action = busy ? null : onPressed;
    if (_primary) {
      return FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          // Busy keeps the accent (the player's own action is running);
          // only a truly disabled button greys out.
          disabledBackgroundColor: busy
              ? theme.colorScheme.primary.withValues(alpha: 0.7)
              : null,
          minimumSize: minimumSize,
          padding: padding,
          shape: shape,
          textStyle: textStyle,
        ),
        child: child,
      );
    }
    return TextButton(
      onPressed: action,
      style: TextButton.styleFrom(
        foregroundColor: destructive
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
        minimumSize: minimumSize,
        padding: padding,
        shape: shape,
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}
