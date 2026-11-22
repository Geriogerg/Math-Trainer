import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/challenges/challenge_stats.dart';

/// Three integers per challenge, under keys named after it.
class SharedPreferencesChallengeStatsStore implements ChallengeStatsStore {
  const SharedPreferencesChallengeStatsStore();

  static String _key(Challenge c, String field) => 'challenge_${c.name}_$field';

  @override
  Future<ChallengeStats> load(Challenge challenge) async {
    final prefs = await SharedPreferences.getInstance();
    return ChallengeStats(
      games: prefs.getInt(_key(challenge, 'games')) ?? 0,
      solved: prefs.getInt(_key(challenge, 'solved')) ?? 0,
      bestTimeMs: prefs.getInt(_key(challenge, 'best_ms')),
    );
  }

  @override
  Future<void> save(Challenge challenge, ChallengeStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(challenge, 'games'), stats.games);
    await prefs.setInt(_key(challenge, 'solved'), stats.solved);
    final best = stats.bestTimeMs;
    if (best == null) {
      await prefs.remove(_key(challenge, 'best_ms'));
    } else {
      await prefs.setInt(_key(challenge, 'best_ms'), best);
    }
  }
}
