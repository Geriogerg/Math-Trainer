import 'dart:math';

import 'package:math_core/method/method.dart';
import 'package:math_core/method/method_for.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_spaces_v9.dart';
import 'package:math_core/tiers/standard_v9.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tip_band.dart';

import '../tiers/tier_cases.dart' show describe;

/// The pinned Methods (`doc/levels.md` v1.6 section 9: "every family and
/// fallback has a pinned example per tier band whose lines are compared
/// word for word"), as `tool/method_pins.dart` writes them and
/// `method_pins_test.dart` checks them: per family and band, the first
/// question its v9 space draws at the band's first tier where it is
/// drawn; per fallback and band, the first standard question of that band
/// (operations in order, tiers in order) whose Method is that fallback.
Map<String, String> methodPinCases() {
  String pin(Object question, Method m) =>
      '${describe(question as dynamic)}\n${methodDebugText(m)}';
  final pins = <String, String>{};
  for (final family in PatternFamily.values) {
    for (final band in TipBand.values) {
      for (var t = band.low.index; t <= band.high.index; t++) {
        final tier = Tier.values[t];
        if (t < family.from.index ||
            !familiesAtV9(family.type, tier).contains(family)) {
          continue;
        }
        final q = familySpaceV9(family, tier).draw(Random(7), const {});
        pins['${family.name} | ${band.name}'] = pin(
          q,
          methodFor(q, family: family),
        );
        break;
      }
    }
  }
  for (final band in TipBand.values) {
    for (final type in ExerciseType.values) {
      for (var t = band.low.index; t <= band.high.index; t++) {
        final random = Random(7);
        final space = standardSpaceV9(type, Tier.values[t]);
        for (var i = 0; i < 400; i++) {
          final q = space.draw(random, const {});
          final m = methodFor(q);
          final kind = m.fallback;
          if (kind == null) continue;
          pins.putIfAbsent('${kind.name} | ${band.name}', () => pin(q, m));
        }
      }
    }
  }
  return pins;
}
