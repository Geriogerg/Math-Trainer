import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import '../fake_stores.dart';
import 'golden_test_utils.dart';

/// The Redesign phase's accessibility rules (plan v2.9): touch targets of
/// 48 dp, text contrast of 4.5:1 in both themes, layouts that hold at large
/// system text sizes — checked with Flutter's own guidelines on Home, the
/// setup page and the game screen.
class _Source extends ExerciseSource {
  @override
  Exercise next() => const ArithmeticExercise(
    operandA: 47,
    operandB: 8,
    operationType: OperationType.multiplication,
  );
}

class _InertTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

AppEnvironment _environment() => AppEnvironment(
  repository: InMemorySessionRepository(),
  playerId: 'p',
  accountRepository: FakeAccountRepository(),
  profileRepository: FakeProfileRepository(),
  typeSelectionStore: FakeTypeSelectionStore({ExerciseType.addition}),
  gameSetupStore: FakeGameSetupStore(GameSetup(mode: GameMode.training)),
);

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  ThemeData theme, {
  double textScale = 1,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _game() {
  final controller = SessionController(
    config: SessionConfig(
      seed: 1,
      enabledTypes: const {ExerciseType.multiplication},
      exerciseCount: 10,
      levels: {ExerciseType.multiplication: Level.whole(12)},
    ),
    exerciseSource: _Source(),
    repository: InMemorySessionRepository(),
    playerId: 'p',
    createTimer: (duration, callback) => _InertTimer(),
  )..start();
  return Scaffold(
    body: SafeArea(
      child: SessionScreen(controller: controller, onQuit: () {}),
    ),
  );
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    Future<void> openSetup(WidgetTester tester) async {
      await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
      await tester.pumpAndSettle();
    }

    testWidgets('Home and setup page: 48 dp targets — $name', (tester) async {
      await _pump(tester, AppShell(environment: _environment()), theme);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await openSetup(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('game screen: 48 dp targets — $name', (tester) async {
      await _pump(tester, _game(), theme);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    // Flutter's textContrastGuideline samples rendered pixels and
    // underestimates small anti-aliased text; the theme's own pairs are
    // checked exactly instead (WCAG 2 relative luminance).
    test(
      'every text colour reaches 4.5:1 on background and surface — $name',
      () {
        final scheme = theme.colorScheme;
        final texts = {
          'primary text': scheme.onSurface,
          'secondary text': scheme.onSurfaceVariant,
          'muted text': theme.extension<AppPalette>()!.textMuted,
          'accent': scheme.primary,
          'error': scheme.error,
        };
        for (final (bgName, bg) in [
          ('background', scheme.surface),
          ('surface', scheme.surfaceContainerHigh),
        ]) {
          for (final MapEntry(key: textName, value: fg) in texts.entries) {
            expect(
              _contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$textName on $bgName',
            );
          }
        }
        expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
      },
    );
  }

  testWidgets('large system text (200 %) holds on a small phone', (
    tester,
  ) async {
    const small = Size(360, 640);
    final theme = buildDarkTheme();
    await _pump(
      tester,
      AppShell(environment: _environment()),
      theme,
      textScale: 2,
      size: small,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _pump(tester, _game(), theme, textScale: 2, size: small);
    expect(tester.takeException(), isNull);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
