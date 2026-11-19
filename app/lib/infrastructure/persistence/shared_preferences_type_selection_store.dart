import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/type_selection_store.dart';

/// `getStringList`/`setStringList` already tell a missing key (`null`,
/// never stored) from a stored empty list — no separate sentinel needed to
/// carry that difference.
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
