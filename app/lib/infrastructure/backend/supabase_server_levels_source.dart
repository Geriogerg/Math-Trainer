import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/sync/server_levels.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The player's server levels, read straight from Supabase
/// (`my_server_levels()`, Phase 3a commit 2) — not through the Dart server,
/// which may be asleep: a game never waits for it.
class SupabaseServerLevelsSource implements ServerLevelsSource {
  SupabaseServerLevelsSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> fetch() async {
    final Object? json;
    try {
      json = await _client.rpc('my_server_levels');
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
    // Same shape as a refusal's server levels; a bad answer throws
    // FormatException, and the game keeps the local levels.
    return levelCacheFromJson(json);
  }
}
