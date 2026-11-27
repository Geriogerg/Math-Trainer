import 'package:math_core/challenges/chain.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/tables.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/chain_setup_store.dart';
import 'package:math_core/persistence/game_setup_store.dart';
import 'package:math_core/persistence/type_selection_store.dart';
import 'package:math_trainer/core/state/hints.dart';

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

class FakeChainSetupStore implements ChainSetupStore {
  FakeChainSetupStore([this.stored]);

  ChainSetup? stored;

  @override
  Future<ChainSetup?> load() async => stored;

  @override
  Future<void> save(ChainSetup setup) async => stored = setup;
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

/// Hints seen, in memory (Phase 6b commit 4).
class FakeHintsStore implements HintsStore {
  FakeHintsStore([Set<Hint>? seen]) : seenHints = {...?seen};

  final Set<Hint> seenHints;

  @override
  Future<bool> seen(Hint hint) async => seenHints.contains(hint);

  @override
  Future<void> markSeen(Hint hint) async => seenHints.add(hint);
}

class FakeTablesStore implements TablesStore {
  FakeTablesStore({this.setup, this.stats = TablesStats.none});

  TablesSetup? setup;
  TablesStats stats;

  @override
  Future<TablesSetup?> loadSetup() async => setup;

  @override
  Future<void> saveSetup(TablesSetup setup) async => this.setup = setup;

  @override
  Future<TablesStats> loadStats() async => stats;

  @override
  Future<void> saveStats(TablesStats stats) async => this.stats = stats;
}
