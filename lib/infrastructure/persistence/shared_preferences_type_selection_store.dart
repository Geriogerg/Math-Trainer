import 'package:shared_preferences/shared_preferences.dart';

import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/type_selection_store.dart';

/// `getStringList`/`setStringList` distinguent déjà nativement une clé
/// absente (`null`, jamais enregistré) d'une liste vide enregistrée — pas
/// besoin d'une sentinelle séparée pour porter cette différence.
class SharedPreferencesTypeSelectionStore implements TypeSelectionStore {
  const SharedPreferencesTypeSelectionStore();

  static const _key = 'type_selection';

  @override
  Future<Set<ExerciseType>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored == null) return null;
    return stored.map(ExerciseType.values.byName).toSet();
  }

  @override
  Future<void> save(Set<ExerciseType> types) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [for (final type in types) type.name]);
  }
}
