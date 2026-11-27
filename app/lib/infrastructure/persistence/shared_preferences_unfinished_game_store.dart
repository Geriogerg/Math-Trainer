import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/sync/session_upload.dart';

import '../../core/state/unfinished_game.dart';

/// The game in progress as one JSON string (its upload shape, a few KB at
/// most). On the web `shared_preferences` writes `localStorage` at once,
/// before the next answer: a tab closed right after an answer still has
/// it — what an asynchronous IndexedDB write could not promise.
class SharedPreferencesUnfinishedGameStore implements UnfinishedGameStore {
  const SharedPreferencesUnfinishedGameStore();

  static const _key = 'unfinished_game';

  @override
  Future<void> save(SessionUpload game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(game.toJson()));
  }

  @override
  Future<SessionUpload?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key);
    if (text == null) return null;
    return SessionUpload.fromJson(jsonDecode(text));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
