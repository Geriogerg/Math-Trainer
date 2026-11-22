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
