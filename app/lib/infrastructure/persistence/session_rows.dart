import 'dart:convert';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/weak_spots/item.dart';

/// A `sessions` row as the model — shared by the repository and the
/// schema migrations that need whole sessions (v9).
PersistedSession sessionFromRow(Map<String, Object?> row) {
  final typeNames = (jsonDecode(row['operation_types'] as String) as List)
      .cast<String>();
  final levelsJson = (jsonDecode(row['levels_json'] as String) as Map)
      .cast<String, Object?>();
  final syncedAt = row['synced_at'] as String?;
  final typeSequence = row['type_sequence'] as String?;
  return PersistedSession(
    id: row['id'] as String,
    playerId: row['player_id'] as String,
    seed: row['seed'] as int,
    enabledTypes: typeNames.map(ExerciseType.values.byName).toSet(),
    exerciseCount: row['exercise_count'] as int,
    totalScore: row['total_score'] as int,
    levels: levelsJson.map(
      (name, level) => MapEntry(
        ExerciseType.values.byName(name),
        Level.fromHundredths(level as int),
      ),
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
    overallLevelAfter: (row['overall_level_after'] as num?)?.toDouble(),
    kind: SessionKind.values.byName(row['kind'] as String),
    syncedAt: syncedAt == null ? null : DateTime.parse(syncedAt),
    typeSequence: typeSequence == null
        ? null
        : [
            for (final name in (jsonDecode(typeSequence) as List))
              ExerciseType.values.byName(name as String),
          ],
    uploadRefused: row['upload_refused'] as String?,
    appVersion: row['app_version'] as String?,
    rulesVersion: switch (row['rules_version']) {
      final int number => RulesVersion.of(number),
      _ => RulesVersion.v1,
    },
    weakSpots: switch (row['weak_spots']) {
      final String json => [
        for (final key in jsonDecode(json) as List) Item.parse(key as String),
      ],
      _ => const [],
    },
  );
}
