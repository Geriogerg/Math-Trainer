import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';

/// Logique pure de rejeu et de mesure de `tool/recalibrate.dart`, séparée du
/// script pour rester testable (le script lui-même ne l'est pas facilement :
/// son point d'entrée lit une vraie base SQLite). Public — contrairement au
/// reste du script — précisément pour ça.

/// Une trajectoire = les lots de réponses d'une opération pour un joueur,
/// triés chronologiquement par session, sessions sous `n_min` déjà exclues.
typedef Trajectory = List<List<AnswerOutcome>>;

class Metrics {
  const Metrics({this.convergence, this.oscillation, this.bias});
  final double? convergence;
  final double? oscillation;
  final double? bias;
}

/// Cible d'amplitude à l'équilibre (doc/decisions.md : oscillation ≤ 2).
const oscillationTarget = 2;

/// Fenêtre glissante utilisée pour détecter la convergence : n'exige pas que
/// *tout* le reste de la trajectoire respecte la cible (un seul écart tardif
/// invaliderait alors une convergence par ailleurs réelle), seulement que
/// les [convergenceWindow] sessions suivantes la respectent. L'oscillation
/// et le biais, une fois la convergence détectée, restent eux mesurés sur
/// tout le reste de la trajectoire — c'est la détection qui doit être
/// tolérante à un accident isolé, pas la caractérisation de l'équilibre.
const convergenceWindow = 5;

/// Rejoue une trajectoire avec [rules], niveau de départ 1. `sessionsPlayed`
/// et l'absence pour `confidenceFor` sont reconstruits depuis le rejeu
/// lui-même — pas depuis `player_levels`, qui ne reflète que l'état courant,
/// pas l'historique complet.
List<int> replay(Trajectory trajectory, LevelingRules rules, DateTime baseTime) {
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

/// Premier indice à partir duquel une fenêtre de [convergenceWindow]
/// sessions (ou moins, en fin de trajectoire) a une amplitude (max−min)
/// sous [oscillationTarget] — `null` si jamais atteint. Une fenêtre de
/// longueur 1 ne permet rien de conclure (amplitude nulle par construction)
/// et est ignorée.
int? convergenceIndex(List<int> levels) {
  for (var i = 0; i < levels.length; i++) {
    final windowEnd = (i + convergenceWindow < levels.length)
        ? i + convergenceWindow
        : levels.length;
    final window = levels.sublist(i, windowEnd);
    if (window.length < 2) continue;
    final amplitude = window.reduce((a, b) => a > b ? a : b) - window.reduce((a, b) => a < b ? a : b);
    if (amplitude <= oscillationTarget) return i;
  }
  return null;
}

double? mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

/// Rejoue toutes les [trajectories] avec [rules] et moyenne les métriques.
/// Oscillation et biais sont mesurés sur tout le reste de la trajectoire à
/// partir du point de convergence (voir [convergenceWindow] pour pourquoi
/// la détection elle-même est plus tolérante).
Metrics averageMetrics(List<Trajectory> trajectories, LevelingRules rules, DateTime baseTime) {
  final convergences = <double>[];
  final oscillations = <double>[];
  final biases = <double>[];

  for (final trajectory in trajectories) {
    final levels = replay(trajectory, rules, baseTime);
    final convergedAt = convergenceIndex(levels);
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

  return Metrics(
    convergence: mean(convergences),
    oscillation: mean(oscillations),
    bias: mean(biases),
  );
}
