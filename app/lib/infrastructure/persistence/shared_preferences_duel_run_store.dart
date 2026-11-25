import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/duel/duel_run_queue.dart';

/// A player's pending duel runs, as one JSON list under a key named after
/// the player (a few KB at most: a run leaves once the server decided it).
class SharedPreferencesDuelRunStore implements DuelRunStore {
  const SharedPreferencesDuelRunStore();

  static String _key(String playerId) => 'duel_runs_$playerId';

  @override
  Future<List<PendingDuelRun>> load(String playerId) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key(playerId));
    if (text == null) return const [];
    final json = jsonDecode(text);
    if (json is! List) throw const FormatException('pending duel runs');
    return [for (final run in json) PendingDuelRun.fromJson(run)];
  }

  @override
  Future<void> save(String playerId, List<PendingDuelRun> runs) async {
    final prefs = await SharedPreferences.getInstance();
    if (runs.isEmpty) {
      await prefs.remove(_key(playerId));
    } else {
      await prefs.setString(
        _key(playerId),
        jsonEncode([for (final r in runs) r.toJson()]),
      );
    }
  }
}
