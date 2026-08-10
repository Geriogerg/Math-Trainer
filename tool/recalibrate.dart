// ignore_for_file: avoid_print
//
// Script CLI, pas du code app : la sortie console est le produit livré,
// pas un artefact de debug à remplacer par un logger.

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';

/// Rejoue l'historique SQLite pour évaluer, un paramètre de [LevelingRules]
/// à la fois, l'effet sur la convergence, l'oscillation et le biais de la
/// trajectoire de niveau. Script hors app, pas un écran — voir
/// `doc/decisions.md` pour le périmètre (les bornes de difficulté et
/// `difficultyBonusMax` ne sont pas concernés, `n_min` reste fixe).
///
/// Lit la base en SQL brut via `sqflite_common_ffi` plutôt que de passer par
/// `SqfliteSessionRepository` : ce dernier importe `package:sqflite/sqflite.dart`
/// (le plugin Flutter), qui tire `dart:ui` — indisponible pour un script
/// lancé en `dart run` pur, hors du SDK Flutter. `sqflite_common_ffi` seul
/// n'a pas ce problème.
///
/// Usage : `dart run tool/recalibrate.dart --db <chemin vers math_trainer.db>`
Future<void> main(List<String> args) async {
  final dbPath = _argValue(args, '--db');
  if (dbPath == null) {
    stderr.writeln('Usage: dart run tool/recalibrate.dart --db <chemin vers math_trainer.db>');
    exit(64);
  }

  sqfliteFfiInit();
  final database = await databaseFactoryFfi.openDatabase(dbPath);

  final defaultRules = LevelingRules();
  final trajectories = await _loadTrajectories(database, nMin: defaultRules.nMin);
  await database.close();

  if (trajectories.isEmpty) {
    print(
      'Aucune paire (joueur, opération) avec au moins 2 sessions de '
      '${defaultRules.nMin}+ réponses — pas assez de données pour une mesure fiable.',
    );
    return;
  }

  print('${trajectories.length} trajectoire(s) (joueur, opération) chargée(s).\n');

  for (final sweep in _sweeps) {
    print('== ${sweep.name} (défaut : ${sweep.defaultValue}) ==');
    print('valeur\tconvergence (sessions)\toscillation (±niveaux)\tbiais (niveaux/session)');
    for (final candidate in sweep.candidates) {
      final rules = sweep.apply(defaultRules, candidate);
      final metrics = _averageMetrics(trajectories, rules);
      print(
        '$candidate\t${_fmt(metrics.convergence, 1)}\t\t\t'
        '${_fmt(metrics.oscillation, 2)}\t\t\t${_fmt(metrics.bias, 3)}',
      );
    }
    print('');
  }

  print(
    'Cibles (doc/decisions.md) : convergence 10–20 sessions, oscillation ≤ 2, '
    'biais légèrement positif.',
  );
}

String _fmt(double? value, int decimals) => value == null ? '—' : value.toStringAsFixed(decimals);

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

/// Une trajectoire = les lots de réponses d'une opération pour un joueur,
/// triés chronologiquement par session, sessions sous `n_min` déjà exclues
/// (ce filtre ne varie pas d'un balayage à l'autre, contrairement au reste
/// de `LevelingRules`).
typedef _Trajectory = List<List<AnswerOutcome>>;

Future<List<_Trajectory>> _loadTrajectories(Database database, {required int nMin}) async {
  final sessionRows = await database.query(
    'sessions',
    columns: ['id', 'player_id'],
    orderBy: 'created_at ASC', // chronologique, pas récent→ancien
  );

  final byPlayerAndType = <String, _Trajectory>{};
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
      // `exercise_type` vaut 'arithmetic' pour les 4 opérations arithmétiques
      // (voir exercise_codec.dart) : l'opération précise est dans
      // `operation_type` dans ce cas-là seulement. Pour les 3 autres types,
      // `exercise_type` porte déjà le nom exact.
      final storedType = row['exercise_type'] as String;
      final type = ExerciseType.values.byName(
        storedType == 'arithmetic' ? row['operation_type'] as String : storedType,
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

  // Une seule session ne donne aucune trajectoire à observer (rien à
  // converger) : exclue plutôt que de fausser la moyenne avec du bruit.
  return byPlayerAndType.values.where((t) => t.length >= 2).toList();
}

class _Metrics {
  const _Metrics({this.convergence, this.oscillation, this.bias});
  final double? convergence;
  final double? oscillation;
  final double? bias;
}

const _oscillationTarget = 2;

/// Rejoue une trajectoire avec [rules], niveau de départ 1. `sessionsPlayed`
/// et l'absence pour `confidenceFor` sont reconstruits depuis le rejeu
/// lui-même — pas depuis `player_levels`, qui ne reflète que l'état courant,
/// pas l'historique complet.
List<int> _replay(_Trajectory trajectory, LevelingRules rules, DateTime baseTime) {
  final updater = LevelUpdater(rules: rules);
  var level = 1;
  LevelCacheEntry? prior;
  final levels = <int>[];

  for (var i = 0; i < trajectory.length; i++) {
    final now = baseTime.add(Duration(days: i)); // pas de vrais timestamps rejoués ici
    final confidence = confidenceFor(entry: prior, now: now, rules: rules);
    level = updater.update(currentLevel: level, answers: trajectory[i], confidence: confidence);
    levels.add(level);
    prior = LevelCacheEntry(
      level: level,
      sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
      updatedAt: now,
    );
  }
  return levels;
}

/// Premier indice à partir duquel l'amplitude (max−min) du reste de la
/// trajectoire descend sous [_oscillationTarget] — `null` si jamais atteint.
int? _convergenceIndex(List<int> levels) {
  for (var i = 0; i < levels.length; i++) {
    final tail = levels.sublist(i);
    final amplitude = tail.reduce((a, b) => a > b ? a : b) - tail.reduce((a, b) => a < b ? a : b);
    if (amplitude <= _oscillationTarget) return i;
  }
  return null;
}

_Metrics _averageMetrics(List<_Trajectory> trajectories, LevelingRules rules) {
  final baseTime = DateTime.utc(2026, 1, 1);
  final convergences = <double>[];
  final oscillations = <double>[];
  final biases = <double>[];

  for (final trajectory in trajectories) {
    final levels = _replay(trajectory, rules, baseTime);
    final convergedAt = _convergenceIndex(levels);
    if (convergedAt == null) continue;

    convergences.add(convergedAt.toDouble());
    final tail = levels.sublist(convergedAt);
    oscillations.add(
      (tail.reduce((a, b) => a > b ? a : b) - tail.reduce((a, b) => a < b ? a : b)).toDouble(),
    );
    if (tail.length >= 2) {
      final diffs = [for (var i = 1; i < tail.length; i++) tail[i] - tail[i - 1]];
      biases.add(diffs.reduce((a, b) => a + b) / diffs.length);
    }
  }

  return _Metrics(
    convergence: _mean(convergences),
    oscillation: _mean(oscillations),
    bias: _mean(biases),
  );
}

double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

/// Un paramètre de [LevelingRules] à la fois, les autres restant au défaut
/// — pas de recherche combinatoire sur les 10 ensemble (illisible et hors
/// de portée avec le volume de données actuel).
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
