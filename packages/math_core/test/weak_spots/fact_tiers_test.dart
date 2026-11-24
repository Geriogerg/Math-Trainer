@TestOn('vm')
library;

import 'dart:math';

import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:test/test.dart';

/// `factsAt` against the generator, both ways (plan v3.5: "tests that every
/// tier's facts are covered"): every fact a tier's standard questions draw
/// is listed for that tier, and every listed fact is drawn. VM only: a
/// sampling test, heavy under JavaScript; `factsAt` is pure integer
/// enumeration, identical there.
void main() {
  // Enough for the rarest listed fact (1 in ~22 000 at percentages T9) to
  // be drawn dozens of times; the seed is fixed, so the test is not flaky.
  const draws = 600000;
  for (final type in ExerciseType.values) {
    test('${type.name}: each tier\'s facts are exactly the ones it draws', () {
      for (final tier in Tier.values) {
        final listed = factsAt(type, tier).toSet();
        final drawn = <Exercise>{};
        final random = Random(type.index * 100 + tier.index);
        for (var i = 0; i < draws; i++) {
          final question = standardQuestionV4(type, tier, random);
          if (factOf(question) != null) drawn.add(question);
        }
        expect(
          drawn.difference(listed),
          isEmpty,
          reason: '${tier.label}: drawn but not listed',
        );
        expect(
          listed.difference(drawn),
          isEmpty,
          reason: '${tier.label}: listed but never drawn',
        );
      }
    });
  }
}
