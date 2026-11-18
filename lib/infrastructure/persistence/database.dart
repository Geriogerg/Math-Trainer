import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

/// Current schema version. Every change increments this value and adds a
/// branch in [_onUpgrade] — never destructive, never retroactive.
const schemaVersion = 3;

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
          levels_json TEXT NOT NULL DEFAULT '{}',
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
}
