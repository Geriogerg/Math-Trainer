import 'package:math_trainer/infrastructure/persistence/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('an existing v1 database migrates to v2 without losing data', () async {
    const path = 'migration_test.db';
    await databaseFactory.deleteDatabase(path);

    // Replicates the v1 schema as it existed before this commit, to
    // reproduce a real existing player's database.
    final v1db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE sessions (
              id TEXT PRIMARY KEY,
              player_id TEXT NOT NULL,
              seed INTEGER NOT NULL,
              operation_types TEXT NOT NULL,
              exercise_count INTEGER NOT NULL,
              total_score INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE answers (
              id TEXT PRIMARY KEY,
              session_id TEXT NOT NULL REFERENCES sessions(id),
              exercise_type TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              operands_json TEXT NOT NULL,
              submitted_value REAL NOT NULL,
              is_correct INTEGER NOT NULL,
              elapsed_ms INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
        },
      ),
    );
    await v1db.insert('sessions', {
      'id': 'legacy-session',
      'player_id': 'legacy-player',
      'seed': 1,
      'operation_types': '["addition"]',
      'exercise_count': 10,
      'total_score': 100,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'synced_at': null,
    });
    await v1db.close();

    final v2db = await openMathTrainerDatabase(path);

    final sessionRows = await v2db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: ['legacy-session'],
    );
    expect(sessionRows.single['levels_json'], '{}');

    // player_levels exists and is usable after migration.
    await v2db.insert('player_levels', {
      'player_id': 'legacy-player',
      'exercise_type': 'addition',
      'level': 5,
      'sessions_played': 1,
      'updated_at': DateTime.utc(2026, 1, 2).toIso8601String(),
    });
    final levelRows = await v2db.query('player_levels');
    expect(levelRows, hasLength(1));

    await v2db.close();
    await databaseFactory.deleteDatabase(path);
  });

  test(
    'an existing v2 database migrates to v3: sessions kept, without an overall level after',
    () async {
      const path = 'migration_v2_test.db';
      await databaseFactory.deleteDatabase(path);

      // v2 schema as it existed before `overall_level_after`.
      final v2db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE sessions (
              id TEXT PRIMARY KEY,
              player_id TEXT NOT NULL,
              seed INTEGER NOT NULL,
              operation_types TEXT NOT NULL,
              exercise_count INTEGER NOT NULL,
              total_score INTEGER NOT NULL,
              levels_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
          },
        ),
      );
      await v2db.insert('sessions', {
        'id': 'v2-session',
        'player_id': 'player',
        'seed': 1,
        'operation_types': '["addition"]',
        'exercise_count': 4,
        'total_score': 40,
        'levels_json': '{"addition":12}',
        'created_at': DateTime.utc(2026, 10, 1).toIso8601String(),
      });
      await v2db.close();

      final v3db = await openMathTrainerDatabase(path);
      final rows = await v3db.query('sessions');

      expect(rows.single['levels_json'], '{"addition":12}');
      expect(rows.single.containsKey('overall_level_after'), isTrue);
      expect(rows.single['overall_level_after'], isNull);

      await v3db.close();
      await databaseFactory.deleteDatabase(path);
    },
  );
}
