import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_type_selection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesTypeSelectionStore', () {
    test('load() renvoie null tant que rien n\'a été enregistré', () async {
      final store = SharedPreferencesTypeSelectionStore();

      expect(await store.load(), isNull);
    });

    test('save() puis load() retrouve exactement les types enregistrés', () async {
      final store = SharedPreferencesTypeSelectionStore();

      await store.save({ExerciseType.multiplication, ExerciseType.division});
      final result = await store.load();

      expect(result, {ExerciseType.multiplication, ExerciseType.division});
    });

    test('une sélection vide enregistrée explicitement est distincte de "jamais enregistré"', () async {
      final store = SharedPreferencesTypeSelectionStore();

      await store.save(const {});
      final result = await store.load();

      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('persiste au-delà de l\'instance du store', () async {
      await SharedPreferencesTypeSelectionStore().save({ExerciseType.percentage});

      final result = await SharedPreferencesTypeSelectionStore().load();

      expect(result, {ExerciseType.percentage});
    });
  });
}
