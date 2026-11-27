import 'package:http/http.dart' as http;

/// How long any Supabase call may wait for an answer (Phase 6b commit 5,
/// review M18: no Supabase call had a limit, so a stalled request left a
/// spinner for ever — account deletion's could not even be dismissed).
const supabaseCallLimit = Duration(seconds: 15);

/// Every Supabase request, auth and database alike (the client is given to
/// `Supabase.initialize`, which builds both on it), fails after [limit]
/// without an answer — as an `http.ClientException`, exactly what an
/// offline request throws: gotrue turns it into its retryable error
/// (`AccountFailure.network`), and every repository's caller already shows
/// its offline state for it.
class TimeLimitedClient extends http.BaseClient {
  TimeLimitedClient(this._inner, {this.limit = supabaseCallLimit});

  final http.Client _inner;
  final Duration limit;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _inner
      .send(request)
      .timeout(
        limit,
        onTimeout: () => throw http.ClientException(
          'No answer within ${limit.inSeconds} s',
          request.url,
        ),
      );

  @override
  void close() => _inner.close();
}
