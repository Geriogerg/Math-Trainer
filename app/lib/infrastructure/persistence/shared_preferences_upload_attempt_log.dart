import 'dart:convert';

import 'package:math_core/sync/upload_attempt_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One JSON object `{sessionId: [count, ISO time of the first failure]}`
/// under a single key (Phase 6a). Only sessions the server is failing on
/// are in it, and each leaves once decided: it stays small.
class SharedPreferencesUploadAttemptLog implements UploadAttemptLog {
  const SharedPreferencesUploadAttemptLog();

  static const _key = 'upload_failures';

  Future<Map<String, List<Object?>>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, List<Object?>>();
    } on Object catch (_) {
      return {}; // corrupted: start over, a few more retries at worst
    }
  }

  @override
  Future<({int count, DateTime first})?> failures(String sessionId) async {
    final entry = (await _read(
      await SharedPreferences.getInstance(),
    ))[sessionId];
    if (entry == null || entry.length != 2) return null;
    final count = entry[0];
    final first = DateTime.tryParse('${entry[1]}');
    if (count is! int || first == null) return null;
    return (count: count, first: first.toUtc());
  }

  @override
  Future<void> recordFailure(String sessionId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _read(prefs);
    final held = map[sessionId];
    map[sessionId] = held != null && held.length == 2 && held[0] is int
        ? [(held[0] as int) + 1, held[1]]
        : [1, at.toUtc().toIso8601String()];
    await prefs.setString(_key, jsonEncode(map));
  }

  @override
  Future<void> clear(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _read(prefs);
    if (map.remove(sessionId) != null) {
      await prefs.setString(_key, jsonEncode(map));
    }
  }
}
