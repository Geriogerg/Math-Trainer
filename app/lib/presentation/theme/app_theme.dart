import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// "Nuit électrique" theme (`doc/design.md`): palette, typography and
/// animation durations centralised here, never hard-coded in a widget.
/// `ColorScheme` covers the usual Material 3 roles; `AppPalette`, `AppMotion`
/// and `AppMetrics` cover what has no standard equivalent (muted text,
/// animation durations, shared sizes/paddings). Both modes must stay
/// strictly symmetric in structure: only add a field to both functions at
/// once.

const _fontFamily = 'Inter';

ThemeData buildLightTheme() => _buildTheme(
  colorScheme: const ColorScheme.light(
    surface: Color(0xFFF4F6FB),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    outline: Color(0xFFD6DEEC),
    primary: Color(0xFF0F6E56),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF101528),
    onSurfaceVariant: Color(0xFF3E5170),
    error: Color(0xFFE24B4A),
    onError: Color(0xFFFFFFFF),
  ),
  palette: const AppPalette(textMuted: Color(0xFF7A8AA6)),
);

ThemeData buildDarkTheme() => _buildTheme(
  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF101528),
    surfaceContainerHigh: Color(0xFF1B2340),
    outline: Color(0xFF2A3352),
    primary: Color(0xFF5DCAA5),
    // Light accent: dark text rather than white for contrast (`design.md`
    // does not settle this point, checked by eye on Android).
    onPrimary: Color(0xFF101528),
    onSurface: Color(0xFFE6F1FB),
    onSurfaceVariant: Color(0xFF85B7EB),
    error: Color(0xFFE24B4A),
    onError: Color(0xFFFFFFFF),
  ),
  palette: const AppPalette(textMuted: Color(0xFF5A6B8C)),
);

const _motion = AppMotion(
  feedback: AnimationSpec(Duration(milliseconds: 120), Curves.easeOut),
  keyPress: AnimationSpec(Duration(milliseconds: 60), Curves.easeOut),
  questionTransition: AnimationSpec(
    Duration(milliseconds: 150),
    Curves.easeOut,
  ),
  tabChange: AnimationSpec(Duration(milliseconds: 200), Curves.easeInOut),
  levelUp: AnimationSpec(Duration(milliseconds: 600), Curves.easeOutCubic),
);

/// `rootPadding`: the only value shared by the three root padding variants
/// that coexisted before step 5, commit B (`all(24)`, `fromLTRB(24,16,24,8)`,
/// none). `keypadHeight`: `doc/design.md` requires a fixed value (never a
/// ratio of the screen) but does not set the number — 300 stays close to the
/// earlier rendering (`0.38 × ~800 dp` on a common phone).
const _metrics = AppMetrics(rootPadding: EdgeInsets.all(24), keypadHeight: 300);

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required AppPalette palette,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: colorScheme.surface,
  );

  return base.copyWith(
    textTheme: _textThemeFor(base.textTheme),
    extensions: [palette, _motion, _metrics],
  );
}

/// The 5 sizes of `doc/design.md` sit on 5 of the 15 named styles of the
/// Material 3 `TextTheme` (an arbitrary mapping, no standard role matches
/// natively). The other 10 keep Material 3's default size but still inherit
/// the weight cap and tabular figures: "never 600/700" and "tabular figures
/// everywhere" apply to the whole `TextTheme`, not just the 5 named sizes.
TextTheme _textThemeFor(TextTheme base) {
  TextStyle? finalize(
    TextStyle? style, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    if (style == null) return null;
    final cappedWeight = fontWeight ?? _capWeight(style.fontWeight);
    return style.copyWith(
      fontSize: fontSize,
      fontWeight: cappedWeight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  return base.copyWith(
    displayLarge: finalize(base.displayLarge),
    displayMedium: finalize(
      base.displayMedium,
      fontSize: 48,
      fontWeight: FontWeight.w500,
    ),
    displaySmall: finalize(base.displaySmall),
    headlineLarge: finalize(base.headlineLarge),
    headlineMedium: finalize(
      base.headlineMedium,
      fontSize: 32,
      fontWeight: FontWeight.w500,
    ),
    headlineSmall: finalize(base.headlineSmall),
    titleLarge: finalize(base.titleLarge),
    titleMedium: finalize(
      base.titleMedium,
      fontSize: 17,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: finalize(base.titleSmall),
    bodyLarge: finalize(base.bodyLarge),
    bodyMedium: finalize(
      base.bodyMedium,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: finalize(base.bodySmall),
    labelLarge: finalize(base.labelLarge),
    labelMedium: finalize(base.labelMedium),
    labelSmall: finalize(
      base.labelSmall,
      fontSize: 11,
      fontWeight: FontWeight.w400,
    ),
  );
}

/// `doc/design.md`: "Two weights only: 400 [...] 500. Never 600 or 700."
/// Material 3's default styles stay below this cap in almost every case;
/// this guard covers a future Flutter version introducing one that does
/// not.
FontWeight _capWeight(FontWeight? weight) {
  if (weight == null) return FontWeight.w400;
  return weight.value >= FontWeight.w600.value ? FontWeight.w500 : weight;
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.textMuted});

  /// Inactive tabs, hints — the only role in `doc/design.md` without an
  /// equivalent in `ColorScheme`.
  final Color textMuted;

  @override
  AppPalette copyWith({Color? textMuted}) =>
      AppPalette(textMuted: textMuted ?? this.textMuted);

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
    );
  }
}

@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics({required this.rootPadding, required this.keypadHeight});

  /// Uniform padding of each screen's root content.
  final EdgeInsets rootPadding;

  /// Fixed height of the keypad (`doc/design.md`: never a ratio of the
  /// screen — the layout must not move from one device to another).
  final double keypadHeight;

  @override
  AppMetrics copyWith({EdgeInsets? rootPadding, double? keypadHeight}) =>
      AppMetrics(
        rootPadding: rootPadding ?? this.rootPadding,
        keypadHeight: keypadHeight ?? this.keypadHeight,
      );

  @override
  AppMetrics lerp(ThemeExtension<AppMetrics>? other, double t) {
    if (other is! AppMetrics) return this;
    return AppMetrics(
      rootPadding:
          EdgeInsets.lerp(rootPadding, other.rootPadding, t) ?? rootPadding,
      keypadHeight:
          lerpDouble(keypadHeight, other.keypadHeight, t) ?? keypadHeight,
    );
  }
}

@immutable
class AnimationSpec {
  const AnimationSpec(this.duration, this.curve);

  final Duration duration;
  final Curve curve;
}

@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    required this.feedback,
    required this.keyPress,
    required this.questionTransition,
    required this.tabChange,
    required this.levelUp,
  });

  /// Flash + shake/pulse of the right/wrong answer.
  final AnimationSpec feedback;

  /// Keypad key press.
  final AnimationSpec keyPress;

  /// Move to the next question.
  final AnimationSpec questionTransition;

  /// Navigation tab change.
  final AnimationSpec tabChange;

  /// Level-up on the result screen — the only deliberately slow animation
  /// (`doc/design.md`).
  final AnimationSpec levelUp;

  @override
  AppMotion copyWith({
    AnimationSpec? feedback,
    AnimationSpec? keyPress,
    AnimationSpec? questionTransition,
    AnimationSpec? tabChange,
    AnimationSpec? levelUp,
  }) => AppMotion(
    feedback: feedback ?? this.feedback,
    keyPress: keyPress ?? this.keyPress,
    questionTransition: questionTransition ?? this.questionTransition,
    tabChange: tabChange ?? this.tabChange,
    levelUp: levelUp ?? this.levelUp,
  );

  @override
  AppMotion lerp(ThemeExtension<AppMotion>? other, double t) {
    // No continuous interpolation between two sets of durations/curves — it
    // makes no sense here (unlike colours). Switch at the midpoint.
    if (other is! AppMotion) return this;
    return t < 0.5 ? this : other;
  }
}
