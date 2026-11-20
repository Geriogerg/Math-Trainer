import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// One key of the session keypad (`doc/design.md`, "Built-in keypad"):
/// digit or icon, on `Surface`, the submit key on `Accent`.
///
/// **Its geometry is pinned for the beta** (`session_layout_pin_test.dart`):
/// it fills its cell, the visible key sits `AppMetrics.keyGap` inside it
/// with `AppMetrics.radius` corners, and it registers on tap (finger up) —
/// the same input path as before Phase 5. Restyle colours and type, never
/// size, spacing or the gesture.
class KeypadKey extends StatefulWidget {
  /// A digit key.
  const KeypadKey.digit(String this.label, {super.key, required this.onTap})
    : icon = null,
      semanticLabel = null,
      isPrimary = false;

  /// Backspace or submit: an icon, named for screen readers.
  const KeypadKey.icon(
    IconData this.icon, {
    super.key,
    required String this.semanticLabel,
    required this.onTap,
    this.isPrimary = false,
  }) : label = null;

  final String? label;
  final IconData? icon;

  /// Read by screen readers for keys without text (icons).
  final String? semanticLabel;
  final VoidCallback onTap;

  /// The submit key: the most frequent gesture, on the accent.
  final bool isPrimary;

  @override
  State<KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<KeypadKey> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final motion = theme.extension<AppMotion>()!.keyPress;
    final background = widget.isPrimary
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final foreground = widget.isPrimary
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: motion.duration,
        curve: motion.curve,
        child: Container(
          margin: EdgeInsets.all(metrics.keyGap),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(metrics.radius),
          ),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: foreground,
                  semanticLabel: widget.semanticLabel,
                )
              : Text(
                  widget.label!,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: foreground,
                  ),
                ),
        ),
      ),
    );
  }
}
