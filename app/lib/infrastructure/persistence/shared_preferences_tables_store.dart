import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/challenges/tables.dart';

/// Tables mode's setup (four integers) and stats (one JSON string), on the
/// device only (`doc/levels.md`, section 7).
class SharedPreferencesTablesStore implements TablesStore {
  const SharedPreferencesTablesStore();

  static const _first = 'tables_first';
  static const _last = 'tables_last';
  static const _multiplier = 'tables_max_multiplier';
  static const _questions = 'tables_questions';
  static const _stats = 'tables_stats';

  @override
  Future<TablesSetup?> loadSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getInt(_first);
    final last = prefs.getInt(_last);
    final multiplier = prefs.getInt(_multiplier);
    final questions = prefs.getInt(_questions);
    if (first == null ||
        last == null ||
        multiplier == null ||
        questions == null) {
      return null;
    }
    try {
      return TablesSetup(
        firstTable: first,
        lastTable: last,
        maxMultiplier: multiplier,
        questions: questions,
      );
    } on ArgumentError catch (_) {
      return null; // A choice this build does not offer: the default.
    }
  }

  @override
  Future<void> saveSetup(TablesSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_first, setup.firstTable);
    await prefs.setInt(_last, setup.lastTable);
    await prefs.setInt(_multiplier, setup.maxMultiplier);
    await prefs.setInt(_questions, setup.questions);
  }

  @override
  Future<TablesStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stats);
    if (raw == null) return TablesStats.none;
    try {
      return TablesStats.fromJson(jsonDecode(raw));
    } on FormatException catch (_) {
      return TablesStats.none; // Unreadable: start again rather than fail.
    }
  }

  @override
  Future<void> saveStats(TablesStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stats, jsonEncode(stats.toJson()));
  }
}
