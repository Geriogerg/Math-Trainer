import 'dart:ui' show Size;

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Loads Inter and the Material icons into the test binding. Without it,
/// `flutter test` renders with fallback fonts (generic glyphs for text,
/// empty squares for icons — the keypad's `Icons.check`/`backspace_outlined`,
/// seen when generating the first goldens): the goldens would not show the
/// real rendering.
Future<void> loadInterFontForGoldens() async {
  await _loadFont('Inter', 'assets/fonts/Inter.ttf');
  // Key without "packages/flutter/": `uses-material-design: true` injects it
  // in this exact form into the asset manifest (flutter_tools, asset.dart,
  // kMaterialFonts), not as a regular package asset.
  await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
}

Future<void> _loadFont(String family, String assetKey) async {
  final data = await rootBundle.load(assetKey);
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}

/// Fixed screen size for reproducible goldens — without it, the test
/// harness's default size (often tied to the machine) would vary the
/// captured layout.
Future<void> setGoldenSurfaceSize(WidgetTester tester) async {
  const size = Size(412, 915);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
