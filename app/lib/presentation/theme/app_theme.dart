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

/// The display face for digits (`doc/plan.md` section 6.2; Phase 5 commit
/// 1, provisional pick — `doc/decisions.md`): operations, typed answers,
/// keypad digits, and the numbers of the kit (scores, levels). Only digits
/// and operators are bundled; anything else (the "of" of a percentage,
/// "Level") falls back to Inter.
const digitFontFamily = 'Space Grotesk Digits';

extension DigitFace on TextStyle {
  /// This style, drawn in the digit face.
  TextStyle get digits => copyWith(
    fontFamily: digitFontFamily,
    fontFamilyFallback: const [_fontFamily],
  );
}

ThemeData buildLightTheme() => _buildTheme(
  colorScheme: const ColorScheme.light(
    surface: Color(0xFFF4F6FB),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    // Edges of what can be tapped — cards, keys, tiles, chips — at 3:1
    // against the page and a card (WCAG 1.4.11; Phase 6b commit 6, review
    // M17: they were 1.08–1.46:1). The design's light line stays for what
    // only decorates: tracks and separators.
    outline: Color(0xFF7C8AA4),
    outlineVariant: Color(0xFFD6DEEC),
    primary: Color(0xFF0F6E56),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF101528),
    onSurfaceVariant: Color(0xFF3E5170),
    // Text contrast >= 4.5:1 on background and surface (Redesign phase):
    // the design's #E24B4A reached 3.6:1 here.
    error: Color(0xFFBF3433),
    onError: Color(0xFFFFFFFF),
  ),
  palette: const AppPalette(textMuted: Color(0xFF5E6E8C)),
);

ThemeData buildDarkTheme() => _buildTheme(
  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF101528),
    surfaceContainerHigh: Color(0xFF1B2340),
    outline: Color(0xFF616F90),
    outlineVariant: Color(0xFF2A3352),
    primary: Color(0xFF5DCAA5),
    // Light accent: dark text rather than white for contrast (`design.md`
    // does not settle this point, checked by eye on Android).
    onPrimary: Color(0xFF101528),
    onSurface: Color(0xFFE6F1FB),
    onSurfaceVariant: Color(0xFF85B7EB),
    // >= 4.5:1 on a surface too (#E24B4A: 3.9:1); dark text on it.
    error: Color(0xFFF06968),
    onError: Color(0xFF101528),
  ),
  palette: const AppPalette(textMuted: Color(0xFF7F90B2)),
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
  pulse: AnimationSpec(Duration(milliseconds: 240), Curves.easeOut),
);

/// `rootPadding`: the only value shared by the three root padding variants
/// that coexisted before step 5, commit B (`all(24)`, `fromLTRB(24,16,24,8)`,
/// none). `keypadHeight`: `doc/design.md` requires a fixed value (never a
/// ratio of the screen) but does not set the number — 300 stays close to the
/// earlier rendering (`0.38 × ~800 dp` on a common phone). `radius` and
/// `keyGap`: the keypad's corner and spacing as the beta started (pinned by
/// `session_layout_pin_test.dart`), shared by the whole kit (Phase 5
/// commit 2). `controlHeight`: the kit's buttons, a thumb's height.
const _metrics = AppMetrics(
  rootPadding: EdgeInsets.all(24),
  keypadHeight: 300,
  radius: 16,
  keyGap: 4,
  controlHeight: 52,
);

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required AppPalette palette,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: colorScheme.surface,
    // A field's error is a sentence ("Ce code n’est pas valide. Vérifie-le
    // sur ton invitation."): Material shows one line and cuts the rest,
    // which French reached at 360 px (Phase 6d commit 5).
    inputDecorationTheme: const InputDecorationTheme(errorMaxLines: 3),
  );

  return base.copyWith(
    textTheme: _textThemeFor(base.textTheme),
    extensions: [palette, _motion, _metrics],
  );
}

/// The 5 sizes of `doc/design.md` sit on 5 of the 15 named styles of the
/// Material 3 `TextTheme` (an arbitrary mapping, no standard role matches
/// natively). The three digit roles — the operation (`displayMedium`), the
/// typed answer (`headlineMedium`), the keypad (`displaySmall`) — use the
/// digit face; their line heights stay Material 3's, so no position on the
/// session screen moves (`session_layout_pin_test.dart`). The other 10 keep Material 3's default size but still inherit
/// the weight cap and tabular figures: "never 600/700" and "tabular figures
/// everywhere" apply to the whole `TextTheme`, not just the 5 named sizes.
TextTheme _textThemeFor(TextTheme base) {
  TextStyle? finalize(
    TextStyle? style, {
    double? fontSize,
    FontWeight? fontWeight,
    bool digits = false,
  }) {
    if (style == null) return null;
    final cappedWeight = fontWeight ?? _capWeight(style.fontWeight);
    final finalized = style.copyWith(
      fontSize: fontSize,
      fontWeight: cappedWeight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return digits ? finalized.digits : finalized;
  }

  return base.copyWith(
    displayLarge: finalize(base.displayLarge),
    displayMedium: finalize(
      base.displayMedium,
      fontSize: 48,
      fontWeight: FontWeight.w500,
      digits: true,
    ),
    displaySmall: finalize(base.displaySmall, digits: true),
    headlineLarge: finalize(base.headlineLarge),
    headlineMedium: finalize(
      base.headlineMedium,
      fontSize: 32,
      fontWeight: FontWeight.w500,
      digits: true,
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
    // Body text 15 px, captions 13 px (Phase 6b commit 6, review M17: body
    // text was 13 px, the level on Home's tiles 11 px).
    bodyMedium: finalize(
      base.bodyMedium,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: finalize(
      base.bodySmall,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: finalize(base.labelLarge),
    labelMedium: finalize(base.labelMedium),
    labelSmall: finalize(
      base.labelSmall,
      fontSize: 13,
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
  const AppMetrics({
    required this.rootPadding,
    required this.keypadHeight,
    required this.radius,
    required this.keyGap,
    required this.controlHeight,
  });

  /// Uniform padding of each screen's root content.
  final EdgeInsets rootPadding;

  /// Fixed height of the keypad (`doc/design.md`: never a ratio of the
  /// screen — the layout must not move from one device to another).
  final double keypadHeight;

  /// Corner radius of keys, buttons, tiles and badges.
  final double radius;

  /// Space around each keypad key (half the gap between two keys).
  final double keyGap;

  /// Minimum height of the kit's buttons.
  final double controlHeight;

  @override
  AppMetrics copyWith({
    EdgeInsets? rootPadding,
    double? keypadHeight,
    double? radius,
    double? keyGap,
    double? controlHeight,
  }) => AppMetrics(
    rootPadding: rootPadding ?? this.rootPadding,
    keypadHeight: keypadHeight ?? this.keypadHeight,
    radius: radius ?? this.radius,
    keyGap: keyGap ?? this.keyGap,
    controlHeight: controlHeight ?? this.controlHeight,
  );

  @override
  AppMetrics lerp(ThemeExtension<AppMetrics>? other, double t) {
    if (other is! AppMetrics) return this;
    return AppMetrics(
      rootPadding:
          EdgeInsets.lerp(rootPadding, other.rootPadding, t) ?? rootPadding,
      keypadHeight:
          lerpDouble(keypadHeight, other.keypadHeight, t) ?? keypadHeight,
      radius: lerpDouble(radius, other.radius, t) ?? radius,
      keyGap: lerpDouble(keyGap, other.keyGap, t) ?? keyGap,
      controlHeight:
          lerpDouble(controlHeight, other.controlHeight, t) ?? controlHeight,
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
    required this.pulse,
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

  /// A short scale pulse (Phase 5): the streak reaching 5, 10, 20; the
  /// "Level up" mark appearing. Never under reduced motion.
  final AnimationSpec pulse;

  @override
  AppMotion copyWith({
    AnimationSpec? feedback,
    AnimationSpec? keyPress,
    AnimationSpec? questionTransition,
    AnimationSpec? tabChange,
    AnimationSpec? levelUp,
    AnimationSpec? pulse,
  }) => AppMotion(
    feedback: feedback ?? this.feedback,
    keyPress: keyPress ?? this.keyPress,
    questionTransition: questionTransition ?? this.questionTransition,
    tabChange: tabChange ?? this.tabChange,
    levelUp: levelUp ?? this.levelUp,
    pulse: pulse ?? this.pulse,
  );

  @override
  AppMotion lerp(ThemeExtension<AppMotion>? other, double t) {
    // No continuous interpolation between two sets of durations/curves — it
    // makes no sense here (unlike colours). Switch at the midpoint.
    if (other is! AppMotion) return this;
    return t < 0.5 ? this : other;
  }
}
