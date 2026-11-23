// The level system's tuning, simulated (Levels phase commit 8, Levels
// close-out): for rules v2 and v3, the plan's targets checked exactly
// (`doc/plan.md` v3.2), the stall accuracy by questions per operation, and
// the median games of 10 questions to reach each tier from level 0.
//
//   dart run tool/levels_simulation.dart          # v2 against v3
//   dart run tool/levels_simulation.dart --grid   # + every candidate meeting the targets

import 'package:math_core/leveling/level_rules.dart';

import 'src/levels_simulation.dart';

void main(List<String> args) {
  for (final (name, rules) in [('v2', LevelRules.v2), ('v3', LevelRules.v3)]) {
    print('== rules $name: $rules');
    for (final t in targetsFor(rules)) {
      print('  [${t.met ? 'met' : 'MISSED'}] ${t.target}: ${t.measured}');
    }
    for (final (label, fluent) in [('half fluent', 0.5), ('all slow', 0.0)]) {
      final stalls = [
        for (final n in questionCounts)
          stallAccuracyPercent(rules, questions: n, fluent: fluent),
      ];
      print(
        '  stall, $label: '
        '${stalls.map((s) => s == null ? 'none' : '$s %').join(' / ')}',
      );
    }
    print(
      '  median games of 10 questions to each tier '
      '(1001 players; — = never within 500 games)',
    );
    print(
      '  player          '
      '${[for (var t = 1; t <= 9; t++) 'T$t'.padLeft(5)].join()}',
    );
    for (final player in simulatedPlayers) {
      final medians = medianGamesToTiers(player, rules: rules);
      print(
        '  ${player.name.padRight(16)}'
        '${[for (final m in medians) (m == null ? '—' : '$m').padLeft(5)].join()}',
      );
    }
  }
  if (!args.contains('--grid')) return;
  print('== candidates meeting every target (stall at n = 4/5/10/20)');
  for (final rules in candidateRules()) {
    final targets = targetsFor(rules);
    if (targets.every((t) => t.met)) {
      print('  $rules: ${targets.first.measured}');
    }
  }
}
