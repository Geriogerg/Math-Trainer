import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/tip_band.dart';
import 'package:math_trainer/presentation/screens/tips_view.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';
import 'package:math_trainer/presentation/tips/tips.dart';

import 'golden_test_utils.dart';

void main() {
  group('content (doc/levels.md section 8)', () {
    test('every operation has tips in every band', () {
      for (final type in ExerciseType.values) {
        for (final band in TipBand.values) {
          expect(
            tips.where((t) => t.type == type && t.band == band),
            isNotEmpty,
            reason: '${type.name} ${band.name}',
          );
        }
      }
    });

    test("every strategy of the detector is one tip's", () {
      for (final strategy in Strategy.values) {
        expect(
          tips.where((t) => t.strategy == strategy),
          hasLength(1),
          reason: strategy.name,
        );
      }
    });

    test("every pattern family is one tip's, of its operation; every "
        'Method but a fallback finds its tip', () {
      for (final family in PatternFamily.values) {
        final linked = tips.where((t) => t.families.contains(family));
        expect(linked, hasLength(1), reason: family.name);
        expect(linked.single.type, family.type, reason: family.name);
        expect(
          tipFor(Method(lines: const [], family: family)),
          same(linked.single),
        );
      }
      for (final strategy in Strategy.values) {
        expect(tipFor(Method(lines: const [], strategy: strategy)), isNotNull);
      }
      expect(tipFor(const Method(lines: [])), isNull);
    });

    test('one sentence and one worked example each', () {
      for (final tip in tips) {
        expect(tip.text.trim(), endsWith('.'), reason: tip.text);
        expect(
          '.'.allMatches(tip.text.replaceAll(RegExp(r'\d\.\d'), '')),
          hasLength(1),
          reason: tip.text,
        );
        expect(tip.example, isNotEmpty);
      }
    });
  });

  Future<void> pumpTips(
    WidgetTester tester,
    Map<ExerciseType, Level> levels, {
    ThemeData? theme,
  }) async {
    await setGoldenSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: Scaffold(
          body: TipsView(
            levelOf: (type) => levels[type] ?? Level.zero,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the player's band is marked, on each operation", (tester) async {
    await pumpTips(tester, {ExerciseType.addition: Level.whole(37)});
    Finder marker(ExerciseType type, TipBand band) => find.descendant(
      of: find.byKey(tipBandKey(type, band)),
      matching: find.byIcon(Icons.my_location),
    );
    expect(marker(ExerciseType.addition, TipBand.intermediate), findsOneWidget);
    expect(marker(ExerciseType.addition, TipBand.beginner), findsNothing);
    // Never played: 0, the beginner band.
    expect(marker(ExerciseType.subtraction, TipBand.beginner), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(tipBandKey(ExerciseType.addition, TipBand.intermediate)),
      ),
      isSemantics(isSelected: true),
    );
  });

  setUpAll(loadInterFontForGoldens);
  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('tips — $name', (tester) async {
      await pumpTips(tester, {
        ExerciseType.addition: Level.whole(37),
      }, theme: theme);
      await expectLater(
        find.byType(TipsView),
        matchesGoldenFile('goldens/tips_$name.png'),
      );
    });
  }
}
