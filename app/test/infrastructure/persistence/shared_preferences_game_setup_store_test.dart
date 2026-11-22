import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_game_setup_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = SharedPreferencesGameSetupStore();

  test('null until something is saved', () async {
    expect(await store.load(), isNull);
  });

  test('save() then load() finds the same setup', () async {
    final setup = GameSetup(
      questionsPerOperation: 20,
      mode: GameMode.training,
      difficulty: TrainingDifficulty.easy,
    );
    await store.save(setup);
    expect(await store.load(), setup);
  });

  test('a count this build does not offer: the default (null)', () async {
    SharedPreferences.setMockInitialValues({
      'game_setup_questions_per_operation': 7,
    });
    expect(await store.load(), isNull);
  });

  test('stored before the mode existed: Levelling, Medium', () async {
    SharedPreferences.setMockInitialValues({
      'game_setup_questions_per_operation': 5,
    });
    expect(await store.load(), GameSetup(questionsPerOperation: 5));
  });
}
