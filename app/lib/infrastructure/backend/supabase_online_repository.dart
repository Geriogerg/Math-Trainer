import 'package:math_core/duel/online_overview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Online tab's data, read straight from Supabase (`duel_overview()`,
/// `supabase/migrations/…_online_reads.sql`): never through the server,
/// which may be asleep.
class SupabaseOnlineRepository implements OnlineRepository {
  SupabaseOnlineRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OnlineOverview> overview() async {
    try {
      return OnlineOverview.fromJson(await _client.rpc('duel_overview'));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
