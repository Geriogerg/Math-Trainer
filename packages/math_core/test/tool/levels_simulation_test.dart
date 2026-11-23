import 'dart:math';

import 'package:test/test.dart';

import '../../tool/src/levels_simulation.dart';

void main() {
  test("a perfect player matches the spec's grind estimate: T2 (level 20) "
      'in 5 games, level 50 in 13', () {
    final reached = gamesToTiers(simulatedPlayers.first, random: Random(1));
    expect(reached[1], 5);
    expect(reached[4], 13);
  });

  test('a correct-but-slow player still climbs, slower', () {
    final perfect = gamesToTiers(simulatedPlayers[0], random: Random(1));
    final slow = gamesToTiers(simulatedPlayers[1], random: Random(1));
    expect(slow[0], isNotNull);
    expect(slow[0]!, greaterThan(perfect[0]!));
  });

  test('an 80 % player climbs; a 60 % player creeps up, about five times '
      'slower (median, 101 runs) — not the stall the spec expects, reported '
      'for Phase 3b', () {
    final eighty = medianGamesToTiers(simulatedPlayers[2], runs: 101);
    final sixty = medianGamesToTiers(simulatedPlayers[3], runs: 101);
    expect(eighty[4], isNotNull);
    expect(sixty[4]!, greaterThan(4 * eighty[4]!));
  });
}
