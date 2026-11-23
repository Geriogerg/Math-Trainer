import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/main_level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'session_rows.dart';

/// Current schema version. Every change increments this value and adds a
/// branch in [_onUpgrade] — never destructive, never retroactive.
const schemaVersion = 12;

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
          synced_at TEXT,
          -- `SessionKind.name`: 'game', 'placementV1', ... (schema v5).
          kind TEXT NOT NULL DEFAULT 'game',
          -- Type of every planned question, JSON list of names (schema v6).
          type_sequence TEXT,
          -- Why the server refused this session for good (schema v7);
          -- NULL: accepted (`synced_at` set) or still to upload.
          upload_refused TEXT,
          -- The build that played it (schema v8): commit or 'dev'.
          app_version TEXT,
          -- `RulesVersion.number` (schema v10); NULL: before, i.e. 1.
          rules_version INTEGER
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
          synced_at TEXT,
          -- `InputDevice.name` (schema v8); NULL: no key pressed.
          input_device TEXT
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
  if (oldVersion < 5) {
    // Placement test (Phase 1 commit 6): every session so far is a game.
    await db.execute(
      "ALTER TABLE sessions ADD COLUMN kind TEXT NOT NULL DEFAULT 'game'",
    );
  }
  if (oldVersion < 6) {
    await db.execute('ALTER TABLE sessions ADD COLUMN type_sequence TEXT');
    await backfillTypeSequences(db);
  }
  if (oldVersion < 7) {
    // Uploads (Phase 2 commit 5): every existing session is still to send.
    await db.execute('ALTER TABLE sessions ADD COLUMN upload_refused TEXT');
  }
  if (oldVersion < 8) {
    // After Phase 3a (owner decision): unknown for what was played before.
    await db.execute('ALTER TABLE sessions ADD COLUMN app_version TEXT');
    await db.execute('ALTER TABLE answers ADD COLUMN input_device TEXT');
  }
  if (oldVersion < 9) {
    // Redesign phase commit 1: the main level (four basics) replaces the
    // seven-type overall level in every stored point of the Profile curve.
    await recomputeMainLevels(db);
  }
  if (oldVersion < 10) {
    // Levels phase commit 0 (`doc/levels.md`, section 4): the rules each
    // session was played under. NULL for everything before: rules v1.
    await db.execute('ALTER TABLE sessions ADD COLUMN rules_version INTEGER');
  }
  if (oldVersion < 11) {
    // Levels phase commit 4 (`doc/levels.md`, section 4, approved by the
    // owner): every level back to 0 for every player, history kept. The
    // level cache empties — an absent level is 0 — and the sessions stay.
    // The server's levels reset in the same release.
    final cache = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'player_levels'",
    );
    if (cache.isNotEmpty) await db.delete('player_levels');
  }
  if (oldVersion < 12) {
    // Levels phase commit 4.1: the production server was still the one
    // before rules v2 when the transition went live, and refused every
    // rules-v2 game (it cannot read level 0, nor replay the tiers). No
    // server knew rules v2 then, so every such refusal is the old server's:
    // those games are pending again, and wait until a server replays them
    // (`HttpSessionUploadClient` checks its `/health`).
    await db.rawUpdate(
      'UPDATE sessions SET upload_refused = NULL '
      'WHERE rules_version = 2 AND upload_refused IS NOT NULL',
    );
  }
}

/// Schema v9: each session's `overall_level_after` becomes the main level
/// after it (`mainLevelsAfter`, walked back from the player's level cache).
/// Only rows that had a value: `null` still means "never known". No column
/// changes. A player whose rows do not parse keeps their old values — a
/// display-only number must never stop the database from opening.
Future<void> recomputeMainLevels(DatabaseExecutor db) async {
  final players = await db.rawQuery(
    'SELECT DISTINCT player_id FROM sessions '
    'WHERE overall_level_after IS NOT NULL',
  );
  for (final row in players) {
    final playerId = row['player_id'] as String;
    try {
      final levelRows = await db.query(
        'player_levels',
        columns: ['exercise_type', 'level'],
        where: 'player_id = ?',
        whereArgs: [playerId],
      );
      final sessionRows = await db.rawQuery(
        'SELECT s.*, (SELECT COUNT(*) FROM answers a WHERE a.session_id = s.id)'
        ' AS answer_count FROM sessions s WHERE s.player_id = ?',
        [playerId],
      );
      final after = mainLevelsAfter(
        sessions: [
          for (final s in sessionRows)
            (
              session: sessionFromRow(s),
              completed: s['answer_count'] == s['exercise_count'],
            ),
        ],
        current: {
          for (final l in levelRows)
            ExerciseType.values.byName(l['exercise_type'] as String):
                Level.fromHundredths(l['level'] as int),
        },
      );
      for (final s in sessionRows) {
        if (s['overall_level_after'] == null) continue;
        await db.update(
          'sessions',
          {'overall_level_after': after[s['id']]},
          where: 'id = ?',
          whereArgs: [s['id']],
        );
      }
    } on FormatException catch (_) {
      // See above: this player's curve keeps its old scale.
    } on ArgumentError catch (_) {
      // Same: an unknown type name or a level out of range.
    }
  }
}

/// Schema v6 (plan, Phase 2 commit 1): a session stores its type order. For
/// a session played to its last question, that order is exactly the types
/// of its answers in the order given (`rowid`: inserted in order, in one
/// transaction). An interrupted session only shows a prefix of its plan:
/// it keeps `null` and cannot be replayed — readable as before.
Future<void> backfillTypeSequences(DatabaseExecutor db) async {
  final sessions = await db.query(
    'sessions',
    columns: ['id', 'exercise_count'],
  );
  for (final session in sessions) {
    final answers = await db.query(
      'answers',
      columns: ['operation_type'],
      where: 'session_id = ?',
      whereArgs: [session['id']],
      orderBy: 'rowid',
    );
    if (answers.isEmpty || answers.length != session['exercise_count']) {
      continue;
    }
    await db.update(
      'sessions',
      {
        'type_sequence': jsonEncode([
          for (final a in answers) a['operation_type'],
        ]),
      },
      where: 'id = ?',
      whereArgs: [session['id']],
    );
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
