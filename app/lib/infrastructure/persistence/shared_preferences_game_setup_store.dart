import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/game_setup_store.dart';

class SharedPreferencesGameSetupStore implements GameSetupStore {
  const SharedPreferencesGameSetupStore();

  static const _questionsKey = 'game_setup_questions_per_operation';

  @override
  Future<GameSetup?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final questions = prefs.getInt(_questionsKey);
    if (questions == null) return null;
    try {
      return GameSetup(questionsPerOperation: questions);
    } on ArgumentError catch (_) {
      // A value this build does not offer: the default instead.
      return null;
    }
  }

  @override
  Future<void> save(GameSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_questionsKey, setup.questionsPerOperation);
  }
}
