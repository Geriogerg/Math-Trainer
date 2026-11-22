import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/game_setup_store.dart';
import 'package:math_core/persistence/type_selection_store.dart';

/// In-memory stores: widget tests never wait on `SharedPreferences`.
class FakeTypeSelectionStore implements TypeSelectionStore {
  FakeTypeSelectionStore([this.stored]);

  Set<ExerciseType>? stored;

  @override
  Future<Set<ExerciseType>?> load() async => stored;

  @override
  Future<void> save(Set<ExerciseType> types) async => stored = types;
}

class FakeGameSetupStore implements GameSetupStore {
  FakeGameSetupStore([this.stored]);

  GameSetup? stored;

  @override
  Future<GameSetup?> load() async => stored;

  @override
  Future<void> save(GameSetup setup) async => stored = setup;
}

class FakeChallengeStatsStore implements ChallengeStatsStore {
  FakeChallengeStatsStore([Map<Challenge, ChallengeStats>? stats])
    : stats = {...?stats};

  final Map<Challenge, ChallengeStats> stats;

  @override
  Future<ChallengeStats> load(Challenge challenge) async =>
      stats[challenge] ?? ChallengeStats.none;

  @override
  Future<void> save(Challenge challenge, ChallengeStats stats) async =>
      this.stats[challenge] = stats;
}
