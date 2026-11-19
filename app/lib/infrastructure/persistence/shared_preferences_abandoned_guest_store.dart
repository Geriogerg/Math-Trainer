import 'dart:convert';

import 'package:math_core/persistence/abandoned_guest_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One JSON object `{guestId: ISO time left}` under a single key.
class SharedPreferencesAbandonedGuestStore implements AbandonedGuestStore {
  const SharedPreferencesAbandonedGuestStore();

  static const _key = 'abandoned_guests';

  Future<Map<String, String>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } on Object catch (_) {
      return {}; // corrupted: start over, nothing is lost but a delay
    }
  }

  @override
  Future<Map<String, DateTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final MapEntry(:key, :value) in (await _read(prefs)).entries)
        if (DateTime.tryParse(value) case final at?) key: at.toUtc(),
    };
  }

  @override
  Future<void> record(String guestId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _read(prefs);
    map.putIfAbsent(guestId, () => at.toUtc().toIso8601String());
    await prefs.setString(_key, jsonEncode(map));
  }

  @override
  Future<void> forget(String guestId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _read(prefs)
      ..remove(guestId);
    await prefs.setString(_key, jsonEncode(map));
  }
}
