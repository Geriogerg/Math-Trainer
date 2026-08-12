import 'package:flutter/material.dart';

/// Thème « nuit électrique » (`doc/design.md`) : palette, typographie et
/// durées d'animation centralisées ici, jamais en dur dans un widget.
/// `ColorScheme` couvre les rôles Material 3 usuels ; `AppPalette` et
/// `AppMotion` couvrent ce qui n'a pas d'équivalent standard (texte discret,
/// durées d'animation). Les deux modes doivent rester strictement
/// symétriques dans leur structure : n'ajouter un champ que dans les deux
/// fonctions à la fois.

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
    surface: Color(0xFF0A0E1C),
    surfaceContainerHigh: Color(0xFF151A30),
    outline: Color(0xFF232A47),
    primary: Color(0xFF2ED9A0),
    // Accent clair : texte sombre plutôt que blanc pour le contraste
    // (`design.md` ne tranche pas ce point, confirmé à l'œil sur Android).
    onPrimary: Color(0xFF0A0E1C),
    onSurface: Color(0xFFEAF2FF),
    onSurfaceVariant: Color(0xFF7FB0E8),
    error: Color(0xFFE24B4A),
    onError: Color(0xFFFFFFFF),
  ),
  palette: const AppPalette(textMuted: Color(0xFF4C5B7D)),
);

const _motion = AppMotion(
  feedback: AnimationSpec(Duration(milliseconds: 120), Curves.easeOut),
  keyPress: AnimationSpec(Duration(milliseconds: 60), Curves.easeOut),
  questionTransition: AnimationSpec(Duration(milliseconds: 150), Curves.easeOut),
  tabChange: AnimationSpec(Duration(milliseconds: 200), Curves.easeInOut),
  levelUp: AnimationSpec(Duration(milliseconds: 600), Curves.easeOutCubic),
);

ThemeData _buildTheme({required ColorScheme colorScheme, required AppPalette palette}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: colorScheme.surface,
  );

  return base.copyWith(
    textTheme: _textThemeFor(base.textTheme),
    extensions: [palette, _motion],
  );
}

/// Les 5 tailles de `doc/design.md` se posent sur 5 des 15 styles nommés du
/// `TextTheme` Material 3 (mapping arbitraire, aucun rôle standard n'y
/// correspond nativement). Les 10 restants gardent la taille par défaut de
/// Material 3 mais héritent quand même du plafond de graisse et des chiffres
/// tabulaires : la règle « jamais 600/700 » et « chiffres tabulaires partout »
/// s'appliquent à tout le `TextTheme`, pas qu'aux 5 tailles nommées.
TextTheme _textThemeFor(TextTheme base) {
  TextStyle? finalize(TextStyle? style, {double? fontSize, FontWeight? fontWeight}) {
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
    displayMedium: finalize(base.displayMedium, fontSize: 48, fontWeight: FontWeight.w500),
    displaySmall: finalize(base.displaySmall),
    headlineLarge: finalize(base.headlineLarge),
    headlineMedium: finalize(base.headlineMedium, fontSize: 32, fontWeight: FontWeight.w500),
    headlineSmall: finalize(base.headlineSmall),
    titleLarge: finalize(base.titleLarge),
    titleMedium: finalize(base.titleMedium, fontSize: 17, fontWeight: FontWeight.w500),
    titleSmall: finalize(base.titleSmall),
    bodyLarge: finalize(base.bodyLarge),
    bodyMedium: finalize(base.bodyMedium, fontSize: 13, fontWeight: FontWeight.w400),
    bodySmall: finalize(base.bodySmall),
    labelLarge: finalize(base.labelLarge),
    labelMedium: finalize(base.labelMedium),
    labelSmall: finalize(base.labelSmall, fontSize: 11, fontWeight: FontWeight.w400),
  );
}

/// `doc/design.md` : « Deux graisses seulement : 400 [...] 500. Jamais 600
/// ou 700. » Les styles Material 3 par défaut restent en dessous de ce
/// plafond dans la quasi-totalité des cas ; ce garde-fou couvre le cas où un
/// futur changement de version Flutter en introduirait un.
FontWeight _capWeight(FontWeight? weight) {
  if (weight == null) return FontWeight.w400;
  return weight.value >= FontWeight.w600.value ? FontWeight.w500 : weight;
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.textMuted});

  /// Onglets inactifs, indications — seul rôle de `doc/design.md` sans
  /// équivalent dans `ColorScheme`.
  final Color textMuted;

  @override
  AppPalette copyWith({Color? textMuted}) => AppPalette(textMuted: textMuted ?? this.textMuted);

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted);
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

  /// Flash + secousse/pulse de la réponse juste/fausse.
  final AnimationSpec feedback;

  /// Enfoncement d'une touche du pavé.
  final AnimationSpec keyPress;

  /// Passage à la question suivante.
  final AnimationSpec questionTransition;

  /// Changement d'onglet de navigation.
  final AnimationSpec tabChange;

  /// Montée de niveau sur l'écran de progression — seule animation lente
  /// assumée (`doc/design.md`).
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
    // Pas d'interpolation continue entre deux jeux de durées/courbes — ça
    // n'a pas de sens ici (contrairement aux couleurs). Bascule au milieu.
    if (other is! AppMotion) return this;
    return t < 0.5 ? this : other;
  }
}
