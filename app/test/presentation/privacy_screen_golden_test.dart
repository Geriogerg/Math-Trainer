import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_trainer/presentation/screens/privacy_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('privacy notice — $name', (tester) async {
      await setGoldenSurfaceSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const PrivacyScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/privacy_$name.png'),
      );
    });
  }
}
