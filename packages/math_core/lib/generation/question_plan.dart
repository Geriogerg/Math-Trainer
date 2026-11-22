import 'dart:math';

import '../models/exercise_type.dart';

/// What the player may choose as questions per operation (plan v2.9):
/// every choice is at least `n_min` (4), so each selected operation's level
/// moves in a Levelling game.
const questionsPerOperationChoices = [4, 5, 10, 20];

/// The setup page's default.
const defaultQuestionsPerOperation = 10;

/// A game's type order (Redesign phase commit 2): each of [types] exactly
/// [perOperation] times, shuffled by [seed]. Decided once when the game is
/// built and stored with the session (its type sequence), so a replay never
/// calls this again — the server replays the stored order.
///
/// Its own `Random(seed)`, apart from the one drawing the values
/// (`LocalExerciseSource`): the values stream starts exactly as it would
/// without the shuffle. Fisher–Yates over the types sorted by `.index`
/// (never iterated from a `Set`, rule 2).
List<ExerciseType> shuffledTypeSequence({
  required Set<ExerciseType> types,
  required int perOperation,
  required int seed,
}) {
  if (types.isEmpty) {
    throw ArgumentError.value(types, 'types', 'must not be empty.');
  }
  if (perOperation < 1) {
    throw ArgumentError.value(
      perOperation,
      'perOperation',
      'must be positive.',
    );
  }
  final sorted = types.toList()..sort((a, b) => a.index - b.index);
  final sequence = [
    for (final type in sorted)
      for (var i = 0; i < perOperation; i++) type,
  ];
  final random = Random(seed);
  for (var i = sequence.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = sequence[i];
    sequence[i] = sequence[j];
    sequence[j] = swap;
  }
  return sequence;
}
