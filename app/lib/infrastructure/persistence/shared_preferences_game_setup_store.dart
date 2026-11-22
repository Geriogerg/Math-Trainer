import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/game_setup_store.dart';

class SharedPreferencesGameSetupStore implements GameSetupStore {
  const SharedPreferencesGameSetupStore();

  static const _questionsKey = 'game_setup_questions_per_operation';
  static const _modeKey = 'game_setup_mode';
  static const _difficultyKey = 'game_setup_difficulty';

  @override
  Future<GameSetup?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final questions = prefs.getInt(_questionsKey);
    if (questions == null) return null;
    try {
      return GameSetup(questionsPerOperation: questions).copyWith(
        mode: _byName(GameMode.values, prefs.getString(_modeKey)),
        difficulty: _byName(
          TrainingDifficulty.values,
          prefs.getString(_difficultyKey),
        ),
      );
    } on ArgumentError catch (_) {
      // A value this build does not offer: the default instead.
      return null;
    }
  }

  @override
  Future<void> save(GameSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_questionsKey, setup.questionsPerOperation);
    await prefs.setString(_modeKey, setup.mode.name);
    await prefs.setString(_difficultyKey, setup.difficulty.name);
  }

  /// `null` when nothing is stored (a build before the mode existed); throws
  /// [ArgumentError] for an unknown name, like `byName`.
  static T? _byName<T extends Enum>(List<T> values, String? name) =>
      name == null ? null : values.byName(name);
}
