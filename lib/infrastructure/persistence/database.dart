import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

/// Current schema version. Every change increments this value and adds a
/// branch in [_onUpgrade] — never destructive, never retroactive.
const schemaVersion = 4;

/// The app's database, where each platform expects it. On web: same schema
/// and same SQL as elsewhere, SQLite compiled to WebAssembly
/// (`sqflite_common_ffi_web`, files `web/sqlite3.wasm` and
/// `web/sqflite_sw.js`), stored in the browser's IndexedDB — a path there
/// is just a name.
///
/// Timeout on web: a missing `sqflite_sw.js` does not always surface an
/// error (seen in Edge — 404 on the worker, then opening never completes);
/// without a bound, the app would stay on a blank page.
Future<Database> openAppDatabase() async {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    return openMathTrainerDatabase(
      'math_trainer.db',
    ).timeout(const Duration(seconds: 20));
  }
  return openMathTrainerDatabase(
    p.join(await getDatabasesPath(), 'math_trainer.db'),
  );
}

/// Opens (and creates/migrates if needed) the local SQLite database.
/// [path] comes from the caller: a real path in production
/// (`join(await getDatabasesPath(), 'math_trainer.db')`), or
/// `inMemoryDatabasePath` in tests.
Future<Database> openMathTrainerDatabase(String path) {
  return openDatabase(
    path,
    version: schemaVersion,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE sessions (
          id TEXT PRIMARY KEY,
          player_id TEXT NOT NULL,
          seed INTEGER NOT NULL,
          operation_types TEXT NOT NULL,
          exercise_count INTEGER NOT NULL,
          total_score INTEGER NOT NULL,
          -- Frozen levels, {type name: level in hundredths} (schema v4).
          levels_json TEXT NOT NULL DEFAULT '{}',
          -- Overall level in level units (37.42), not hundredths.
          overall_level_after REAL,
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
      await db.execute(
        'CREATE INDEX idx_answers_session_id ON answers(session_id)',
      );
      await db.execute('''
        CREATE TABLE player_levels (
          player_id TEXT NOT NULL,
          exercise_type TEXT NOT NULL,
          -- In hundredths (3742 = level 37.42) since schema v4.
          level INTEGER NOT NULL,
          sessions_played INTEGER NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (player_id, exercise_type)
        )
      ''');
    },
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      "ALTER TABLE sessions ADD COLUMN levels_json TEXT NOT NULL DEFAULT '{}'",
    );
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
  }
  if (oldVersion < 3) {
    // Nullable, no rebuilt value: the overall level after an old session
    // depends on the whole cache at that time, which history cannot
    // faithfully recover.
    await db.execute(
      'ALTER TABLE sessions ADD COLUMN overall_level_after REAL',
    );
  }
  if (oldVersion < 4) {
    await migrateLevelsToHundredths(db);
  }
}

/// Schema v4 (plan, Phase 1 commit 2 — approved by the owner): levels move
/// from whole numbers to integer hundredths, ×100, in the level cache and
/// in each session's frozen levels. The column keeps its name; only its
/// unit changes. Nothing else moves: `overall_level_after` stays in level
/// units, and a migrated frozen level's whole part is the old level, so
/// every old session still regenerates the same questions.
///
/// `levels_json` is rewritten in Dart rather than with SQLite's JSON
/// functions, which older Android SQLite builds lack. Runs inside the
/// upgrade transaction `sqflite` opens: all or nothing.
Future<void> migrateLevelsToHundredths(DatabaseExecutor db) async {
  await db.rawUpdate('UPDATE player_levels SET level = level * 100');
  final rows = await db.query('sessions', columns: ['id', 'levels_json']);
  for (final row in rows) {
    final levels = (jsonDecode(row['levels_json'] as String) as Map)
        .cast<String, Object?>();
    if (levels.isEmpty) continue;
    final migrated = levels.map(
      (type, level) => MapEntry(type, (level as int) * 100),
    );
    await db.update(
      'sessions',
      {'levels_json': jsonEncode(migrated)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
}
