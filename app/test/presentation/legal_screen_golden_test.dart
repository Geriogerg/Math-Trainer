import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_trainer/presentation/screens/legal_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// The legal pages as a player sees them before the owner's details are
/// given: the Draft banner and the highlighted placeholders (Phase 6c
/// commit 2).
void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (name, theme, page, language) in [
    ('privacy_en_light', buildLightTheme(), LegalPage.privacy, 'en'),
    ('notice_fr_dark', buildDarkTheme(), LegalPage.notice, 'fr'),
  ]) {
    testWidgets('legal page — $name', (tester) async {
      await setGoldenSurfaceSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          locale: testLocale,
          supportedLocales: testLocales,
          localizationsDelegates: testLocalizations,
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: LegalScreen(
            page: page,
            details: const {},
            languageCode: language,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/legal_$name.png'),
      );
    });
  }

  for (final page in LegalPage.values) {
    testWidgets('legal page ${page.name} — French, 360 px', (tester) async {
      useFrench();
      await tester.pumpWidget(
        MaterialApp(
          locale: testLocale,
          supportedLocales: testLocales,
          localizationsDelegates: testLocalizations,
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          home: LegalScreen(page: page, details: const {}, languageCode: 'fr'),
        ),
      );
      await expectFrenchAt360(tester, 'legal_${page.name}');
    });
  }
}
