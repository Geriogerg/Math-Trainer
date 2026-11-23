// The level system's grind, simulated (Levels phase commit 8,
// `doc/levels.md`): median games of 10 questions to reach each tier from
// level 0, for a perfect, a perfect-but-slow, an 80 % and a 60 % player.
//
//   dart run tool/levels_simulation.dart [questions per game]

import 'src/levels_simulation.dart';

void main(List<String> args) {
  final questions = args.isEmpty ? 10 : int.parse(args.first);
  print(
    'Median games of $questions questions to reach each tier '
    '(1001 players each; — = never within 500 games)',
  );
  print(
    'player          ${[for (var t = 1; t <= 9; t++) 'T$t'.padLeft(5)].join()}',
  );
  for (final player in simulatedPlayers) {
    final medians = medianGamesToTiers(player, questions: questions);
    print(
      '${player.name.padRight(16)}'
      '${[for (final m in medians) (m == null ? '—' : '$m').padLeft(5)].join()}',
    );
  }
}
