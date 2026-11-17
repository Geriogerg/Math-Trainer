import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/app.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

void main() {
  final testEnvironment = AppEnvironment(
    repository: InMemorySessionRepository(),
    playerId: 'test-player',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
  );

  test('les deux thèmes exposent AppPalette et AppMotion', () {
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      expect(theme.extension<AppPalette>(), isNotNull);
      expect(theme.extension<AppMotion>(), isNotNull);
    }
  });

  testWidgets('l\'app construit sans lever en mode clair forcé', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Math Trainer'), findsOneWidget);
  });

  testWidgets('l\'app construit sans lever en mode sombre forcé', (
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
