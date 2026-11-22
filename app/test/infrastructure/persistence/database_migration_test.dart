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
            // Every real database has had `answers` since v1 (the v6
            // migration reads it).
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
            // Every real v2 database has it (created by the v1 → v2 step);
            // the v4 migration updates it.
            await db.execute('''
            CREATE TABLE player_levels (
              player_id TEXT NOT NULL,
              exercise_type TEXT NOT NULL,
              level INTEGER NOT NULL,
              sessions_played INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (player_id, exercise_type)
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

      // Through v4 as well: the frozen level is now in hundredths.
      expect(rows.single['levels_json'], '{"addition":1200}');
      expect(rows.single.containsKey('overall_level_after'), isTrue);
      expect(rows.single['overall_level_after'], isNull);

      await v3db.close();
      await databaseFactory.deleteDatabase(path);
    },
  );

  test('an existing v3 database migrates to v4 and v5: every level ×100, '
      'every session a game, nothing else touched', () async {
    const path = 'migration_v3_test.db';
    await databaseFactory.deleteDatabase(path);

    // A v3 database as the app created it (same schema as today, whole
    // levels).
    final v3db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
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
              overall_level_after REAL,
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
          // Every real database has had `answers` since v1.
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
          await db.execute('''
            CREATE TABLE player_levels (
              player_id TEXT NOT NULL,
              exercise_type TEXT NOT NULL,
              level INTEGER NOT NULL,
              sessions_played INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (player_id, exercise_type)
            )
          ''');
        },
      ),
    );
    Map<String, Object?> session(String id, String levelsJson) => {
      'id': id,
      'player_id': 'player',
      'seed': 7,
      'operation_types': '["addition","division"]',
      'exercise_count': 8,
      'total_score': 120,
      'levels_json': levelsJson,
      'overall_level_after': 9.857142857142858,
      'created_at': DateTime.utc(2026, 11, 1).toIso8601String(),
    };
    await v3db.insert(
      'sessions',
      session('s1', '{"addition":42,"division":1}'),
    );
    await v3db.insert('sessions', session('s2', '{}'));
    for (final (type, level) in [('addition', 43), ('division', 100)]) {
      await v3db.insert('player_levels', {
        'player_id': 'player',
        'exercise_type': type,
        'level': level,
        'sessions_played': 5,
        'updated_at': DateTime.utc(2026, 11, 1).toIso8601String(),
      });
    }
    await v3db.close();

    final v4db = await openMathTrainerDatabase(path);
    final sessions = {
      for (final row in await v4db.query('sessions')) row['id']: row,
    };
    final levels = {
      for (final row in await v4db.query('player_levels'))
        row['exercise_type']: row['level'],
    };

    expect(sessions['s1']!['levels_json'], '{"addition":4200,"division":100}');
    expect(sessions['s2']!['levels_json'], '{}');
    // v9: recomputed as the main level from the cache (no completed
    // session to walk back): (43 + 1 + 1 + 100) / 4.
    expect(sessions['s1']!['overall_level_after'], 36.25);
    expect(sessions['s1']!['seed'], 7);
    // Through v5 as well: every older session is a game.
    expect(sessions['s1']!['kind'], 'game');
    expect(levels, {'addition': 4300, 'division': 10000});
    expect(await v4db.getVersion(), schemaVersion);

    await v4db.close();
    await databaseFactory.deleteDatabase(path);
  });

  test('an existing v5 database migrates to v6: a complete session gets its '
      'answer types as its sequence, an interrupted one keeps null', () async {
    const path = 'migration_v5_test.db';
    await databaseFactory.deleteDatabase(path);
    final v5db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
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
              overall_level_after REAL,
              created_at TEXT NOT NULL,
              synced_at TEXT,
              kind TEXT NOT NULL DEFAULT 'game'
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
    for (final (id, count) in [('complete', 3), ('interrupted', 4)]) {
      await v5db.insert('sessions', {
        'id': id,
        'player_id': 'player',
        'seed': 7,
        'operation_types': '["addition","power"]',
        'exercise_count': count,
        'total_score': 0,
        'levels_json': '{"addition":100,"power":100}',
        'created_at': DateTime.utc(2026, 11, 1).toIso8601String(),
      });
      // Inserted in answer order; ids deliberately not in that order.
      for (final (i, type) in [(2, 'power'), (0, 'addition'), (1, 'power')]) {
        await v5db.insert('answers', {
          'id': '$id-$i',
          'session_id': id,
          'exercise_type': type == 'power' ? 'power' : 'arithmetic',
          'operation_type': type,
          'operands_json': '{}',
          'submitted_value': 1,
          'is_correct': 1,
          'elapsed_ms': 900,
          'created_at': DateTime.utc(2026, 11, 1).toIso8601String(),
        });
      }
    }
    await v5db.close();

    final db = await openMathTrainerDatabase(path);
    final sequences = {
      for (final row in await db.query('sessions'))
        row['id']: row['type_sequence'],
    };
    expect(sequences['complete'], '["power","addition","power"]');
    expect(sequences['interrupted'], isNull);
    // Through v7 as well: every existing session is still to upload.
    expect(
      [for (final row in await db.query('sessions')) row['upload_refused']],
      [null, null],
    );
    // And v8: nothing played before says which build or which keys.
    expect(
      [for (final row in await db.query('sessions')) row['app_version']],
      [null, null],
    );
    expect(
      {for (final row in await db.query('answers')) row['input_device']},
      {null},
    );
    expect(await db.getVersion(), schemaVersion);

    await db.close();
    await databaseFactory.deleteDatabase(path);
  });

  test('v9 recomputes each stored point as the main level after it', () async {
    const path = 'migration_v9_test.db';
    await databaseFactory.deleteDatabase(path);
    final db = await openMathTrainerDatabase(path);
    Future<void> session(String id, int day, String levels, int answers) async {
      await db.insert('sessions', {
        'id': id,
        'player_id': 'player',
        'seed': 1,
        'operation_types': '["addition","power"]',
        'exercise_count': 2,
        'total_score': 0,
        'levels_json': levels,
        'overall_level_after': 99.0,
        'created_at': DateTime.utc(2026, 11, day).toIso8601String(),
        'kind': 'game',
      });
      for (var i = 0; i < answers; i++) {
        await db.insert('answers', {
          'id': '$id-$i',
          'session_id': id,
          'exercise_type': 'arithmetic',
          'operation_type': 'addition',
          'operands_json': '{}',
          'submitted_value': 1,
          'is_correct': 1,
          'elapsed_ms': 1000,
          'created_at': DateTime.utc(2026, 11, day).toIso8601String(),
        });
      }
    }

    await session('old', 1, '{"addition":1000,"power":5000}', 2);
    await session('new', 2, '{"addition":1400,"power":6000}', 2);
    await session('cut', 3, '{"addition":1800,"power":6000}', 1);
    for (final (type, level) in [('addition', 1800), ('power', 7000)]) {
      await db.insert('player_levels', {
        'player_id': 'player',
        'exercise_type': type,
        'level': level,
        'sessions_played': 2,
        'updated_at': DateTime.utc(2026, 11, 2).toIso8601String(),
      });
    }

    await recomputeMainLevels(db);
    final after = {
      for (final row in await db.query('sessions'))
        row['id']: row['overall_level_after'],
    };
    // Powers never count; an interrupted session moved nothing; walking
    // back restores each completed game's frozen addition level.
    expect(after['cut'], (18 + 3) / 4);
    expect(after['new'], (18 + 3) / 4);
    expect(after['old'], (14 + 3) / 4);

    await db.close();
    await databaseFactory.deleteDatabase(path);
  });
}
