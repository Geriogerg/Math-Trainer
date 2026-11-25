import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The boards, read straight from Supabase through the two public SQL
/// functions (`supabase/migrations/…_leaderboard.sql`): rank, name and
/// level only. Works signed out too (the functions allow `anon`).
class SupabaseLeaderboardRepository implements LeaderboardRepository {
  SupabaseLeaderboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LeaderboardEntry>> top(LeaderboardBoard board) async =>
      leaderboardEntriesFromJson(
        board.isDuel
            ? await _call('duel_board_top', board, param: 'p_mode')
            : await _call('leaderboard_top', board),
      );

  @override
  Future<Standing> aroundMe(LeaderboardBoard board) async => standingFromJson(
    board.isDuel
        ? await _call('duel_board_around_me', board, param: 'p_mode')
        : await _call('leaderboard_around_me', board),
  );

  @override
  Future<void> reportName(String playerId) async {
    try {
      await _client.rpc(
        'report_player_name',
        params: {'p_player_id': playerId},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Duel boards (Phase 7) are read by `duel_board_top(p_mode)` and
  /// `duel_board_around_me(p_mode)`, in the same shapes with a rating.
  Future<Object?> _call(
    String function,
    LeaderboardBoard board, {
    String param = 'p_board',
  }) async {
    try {
      return await _client.rpc(function, params: {param: board.key});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
