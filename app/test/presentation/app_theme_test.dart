import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_trainer/app.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

void main() {
  // `PlayTab` reads the remembered selection and placement skip before it
  // draws (no flash of the selection before the placement offer).
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final testEnvironment = AppEnvironment(
    repository: InMemorySessionRepository(),
    playerId: 'test-player',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
  );

  test('both themes expose AppPalette and AppMotion', () {
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      expect(theme.extension<AppPalette>(), isNotNull);
      expect(theme.extension<AppMotion>(), isNotNull);
    }
  });

  testWidgets('the app builds without throwing in forced light mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Math Trainer'), findsOneWidget);
  });

  testWidgets('the app builds without throwing in forced dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Math Trainer'), findsOneWidget);
  });
}
