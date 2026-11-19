// ignore_for_file: avoid_print
//
// A CLI script, not app code: console output is the deliverable, not a
// debug artefact to replace with a logger.

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/leveling_rules.dart';
import 'package:math_core/models/exercise_type.dart';

import 'src/replay_metrics.dart';

/// Replays the SQLite history to assess, one [LevelingRules] parameter at a
/// time, the effect on convergence, oscillation and bias of the level
/// trajectory. A script outside the app, not a screen — see
/// `doc/decisions.md` for the scope (difficulty bounds and
/// `difficultyBonusMax` are not covered, `n_min` stays fixed).
///
/// Reads the database in raw SQL through `sqflite_common_ffi` rather than
/// `SqfliteSessionRepository`: the latter imports `package:sqflite/sqflite.dart`
/// (the Flutter plugin), which pulls in `dart:ui` — unavailable to a script
/// run with plain `dart run`, outside the Flutter SDK. `sqflite_common_ffi`
/// alone does not have this problem.
///
/// Usage: `dart run tool/recalibrate.dart --db <path to math_trainer.db>`
Future<void> main(List<String> args) async {
  final dbPath = _argValue(args, '--db');
  if (dbPath == null) {
    stderr.writeln(
      'Usage: dart run tool/recalibrate.dart --db <path to math_trainer.db>',
    );
    exit(64);
  }

  sqfliteFfiInit();
  final database = await databaseFactoryFfi.openDatabase(dbPath);

  final defaultRules = LevelingRules();
  final trajectories = await _loadTrajectories(
    database,
    nMin: defaultRules.nMin,
  );
  await database.close();

  if (trajectories.isEmpty) {
    print(
      'No (player, operation) pair with at least 2 sessions of '
      '${defaultRules.nMin}+ answers — not enough data for a reliable measure.',
    );
    return;
  }

  print('${trajectories.length} (player, operation) trajectory(ies) loaded.\n');

  final baseTime = DateTime.utc(2026, 1, 1);
  for (final sweep in _sweeps) {
    print('== ${sweep.name} (default: ${sweep.defaultValue}) ==');
    print(
      'value\tconvergence (sessions)\toscillation (±levels)\tbias (levels/session)',
    );
    for (final candidate in sweep.candidates) {
      final rules = sweep.apply(defaultRules, candidate);
      final metrics = averageMetrics(trajectories, rules, baseTime);
      print(
        '$candidate\t${_fmt(metrics.convergence, 1)}\t\t\t'
        '${_fmt(metrics.oscillation, 2)}\t\t\t${_fmt(metrics.bias, 3)}',
      );
    }
    print('');
  }

  print(
    'Targets (doc/decisions.md): convergence in 10–20 sessions, oscillation ≤ 2, '
    'slightly positive bias.',
  );
}

String _fmt(double? value, int decimals) =>
    value == null ? '—' : value.toStringAsFixed(decimals);

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

/// Sessions under `n_min` are already excluded here (this filter does not
/// vary from one sweep to the next, unlike the rest of `LevelingRules`).
Future<List<Trajectory>> _loadTrajectories(
  Database database, {
  required int nMin,
}) async {
  final sessionRows = await database.query(
    'sessions',
    columns: ['id', 'player_id'],
    orderBy: 'created_at ASC', // chronological, not recent→old
  );

  final byPlayerAndType = <String, Trajectory>{};
  for (final sessionRow in sessionRows) {
    final sessionId = sessionRow['id'] as String;
    final playerId = sessionRow['player_id'] as String;

    final answerRows = await database.query(
      'answers',
      columns: ['exercise_type', 'operation_type', 'is_correct', 'elapsed_ms'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    final byType = <ExerciseType, List<AnswerOutcome>>{};
    for (final row in answerRows) {
      // `exercise_type` is 'arithmetic' for the 4 arithmetic operations (see
      // exercise_codec.dart): the exact operation is in `operation_type` in
      // that case only. For the 3 other types, `exercise_type` already
      // carries the exact name.
      final storedType = row['exercise_type'] as String;
      final type = ExerciseType.values.byName(
        storedType == 'arithmetic'
            ? row['operation_type'] as String
            : storedType,
      );
      byType
          .putIfAbsent(type, () => [])
          .add(
            AnswerOutcome(
              isCorrect: (row['is_correct'] as int) == 1,
              elapsedMs: row['elapsed_ms'] as int,
            ),
          );
    }
    for (final entry in byType.entries) {
      if (entry.value.length < nMin) continue; // bruit, comme en production
      final key = '$playerId|${entry.key.name}';
      byPlayerAndType.putIfAbsent(key, () => []).add(entry.value);
    }
  }

  // A single session gives no trajectory to observe (nothing to converge):
  // excluded rather than skewing the mean with noise.
  return byPlayerAndType.values.where((t) => t.length >= 2).toList();
}

/// One [LevelingRules] parameter at a time, the others at their default —
/// no combinatorial search over all 10 together (unreadable and out of
/// reach with the current data volume).
class _Sweep {
  const _Sweep(this.name, this.defaultValue, this.candidates, this.apply);
  final String name;
  final num defaultValue;
  final List<num> candidates;
  final LevelingRules Function(LevelingRules base, num candidate) apply;
}

final _sweeps = <_Sweep>[
  _Sweep(
    'pCible',
    LevelingRules().pCible,
    [0.60, 0.70, 0.80],
    (b, c) => LevelingRules(
      pCible: c.toDouble(),
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'f',
    LevelingRules().f,
    [0.15, 0.30, 0.45, 0.60],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: c.toDouble(),
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'kHaut',
    LevelingRules().kHaut,
    [2.0, 3.0, 4.0, 5.0],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: c.toDouble(),
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'kBas',
    LevelingRules().kBas,
    [1.0, 1.5, 2.0, 2.5],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: c.toDouble(),
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'delta',
    LevelingRules().delta,
    [0.0, 0.05, 0.10],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: c.toDouble(),
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'deltaMax',
    LevelingRules().deltaMax,
    [2, 3, 5, 8],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: c.toInt(),
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'kCalib',
    LevelingRules().kCalib,
    [2.0, 4.0, 6.0],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: c.toDouble(),
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'boostRetour',
    LevelingRules().boostRetour,
    [1.0, 2.0, 3.0],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: c.toDouble(),
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'tRapideMs',
    LevelingRules().tRapideMs,
    [1000, 2000, 3000],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: c.toInt(),
      tLentMs: b.tLentMs,
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'tLentMs',
    LevelingRules().tLentMs,
    [6000, 8000, 10000],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: c.toInt(),
      absenceDaysThreshold: b.absenceDaysThreshold,
    ),
  ),
  _Sweep(
    'absenceDaysThreshold',
    LevelingRules().absenceDaysThreshold,
    [14, 30, 60],
    (b, c) => LevelingRules(
      pCible: b.pCible,
      f: b.f,
      kHaut: b.kHaut,
      kBas: b.kBas,
      delta: b.delta,
      deltaMax: b.deltaMax,
      nMin: b.nMin,
      kCalib: b.kCalib,
      boostRetour: b.boostRetour,
      tRapideMs: b.tRapideMs,
      tLentMs: b.tLentMs,
      absenceDaysThreshold: c.toInt(),
    ),
  ),
];
