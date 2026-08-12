import 'dart:ui' show Size;

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Charge Inter et les icônes Material dans le binding de test. Sans ça,
/// `flutter test` rend avec des polices de repli (glyphes génériques pour le
/// texte, carrés vides pour les icônes — `Icons.check`/`backspace_outlined`
/// du pavé, constaté en générant les premiers golden) : les golden ne
/// représenteraient pas le rendu réel.
Future<void> loadInterFontForGoldens() async {
  await _loadFont('Inter', 'assets/fonts/Inter.ttf');
  // Clé sans « packages/flutter/ » : `uses-material-design: true` l'injecte
  // sous cette forme précise dans le manifest d'assets (flutter_tools,
  // asset.dart, kMaterialFonts), pas comme un asset de package classique.
  await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
}

Future<void> _loadFont(String family, String assetKey) async {
  final data = await rootBundle.load(assetKey);
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}

/// Taille d'écran fixe pour des golden reproductibles — sans ça, la taille
/// par défaut du banc de test (souvent liée à la machine) ferait varier la
/// mise en page capturée.
Future<void> setGoldenSurfaceSize(WidgetTester tester) async {
  const size = Size(412, 915);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
