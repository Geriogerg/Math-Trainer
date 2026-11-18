import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

/// Version courante du schéma. Toute évolution incrémente cette valeur et
/// ajoute une branche dans [_onUpgrade] — jamais destructive, jamais
/// rétroactive.
const schemaVersion = 3;

/// Base de l'app, à l'emplacement attendu par chaque plateforme. Sur web :
/// même schéma et même code SQL qu'ailleurs, SQLite compilé en WebAssembly
/// (`sqflite_common_ffi_web`, fichiers `web/sqlite3.wasm` et
/// `web/sqflite_sw.js`), stocké dans l'IndexedDB du navigateur — un chemin
/// n'y est qu'un nom.
///
/// Délai sur web : un `sqflite_sw.js` introuvable ne remonte pas toujours
/// d'erreur (constaté sous Edge — 404 sur le worker, puis l'ouverture
/// n'aboutit jamais) ; sans borne, l'app resterait sur une page blanche.
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

/// Ouvre (et crée/migre si besoin) la base SQLite du stockage local.
/// [path] est fourni par l'appelant : un chemin réel en production
/// (`join(await getDatabasesPath(), 'math_trainer.db')`), ou
/// `inMemoryDatabasePath` dans les tests.
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
      await db.execute('CREATE INDEX idx_answers_session_id ON answers(session_id)');
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
    await db.execute("ALTER TABLE sessions ADD COLUMN levels_json TEXT NOT NULL DEFAULT '{}'");
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
    // Nullable, pas de valeur reconstituée : le niveau global d'après une
    // ancienne session dépend de tout le cache à cet instant, que
    // l'historique ne permet pas de retrouver fidèlement.
    await db.execute('ALTER TABLE sessions ADD COLUMN overall_level_after REAL');
  }
}
