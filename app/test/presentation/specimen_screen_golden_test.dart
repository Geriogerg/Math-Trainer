import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_trainer/presentation/screens/specimen_screen.dart';

import 'golden_test_utils.dart';

/// The typeface specimen (Phase 5 commit 1) in both themes: the record of
/// what the provisional pick was chosen from (`doc/decisions.md`).
void main() {
  setUpAll(() async {
    await loadInterFontForGoldens();
    await loadSpecimenFonts();
  });

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('specimen, $mode', (tester) async {
      tester.view.physicalSize = const Size(412, 3400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(SpecimenApp(fontsLoaded: Future.value()));
      if (!dark) await tester.tap(find.byTooltip('Day theme'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SpecimenScreen),
        matchesGoldenFile('goldens/specimen_$mode.png'),
      );
    });
  }
}
