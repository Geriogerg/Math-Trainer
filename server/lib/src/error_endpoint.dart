import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'http_app.dart';
import 'rate_limit.dart';
import 'supabase_gateway.dart';

/// Largest accepted report: a message and a stack, cut below anyway.
const maxErrorBytes = 16 * 1024;

/// `POST /v1/errors` (Phase 6c commit 5, plan v4.1): what went wrong in a
/// player's app — an uncaught error, a start that failed, the loading page
/// giving up — kept for the owner 30 days (`record_client_error`,
/// `dashboard.sh errors`).
///
/// No account needed (an error can come before any sign-in) and nothing
/// about the player kept: the kind, the message and the stack — cut, with
/// anything shaped like a token, a key or an email address masked, never
/// trusting the app to have done it — the app's version and the browser.
/// Any content type is read (the loading page sends with `sendBeacon`, as
/// text). Answers 202 whether stored or over the day's cap: the app never
/// retries a report.
class ErrorEndpoint {
  ErrorEndpoint(this.gateway, {TokenBuckets? perAddress})
    : perAddress =
          perAddress ?? TokenBuckets(capacity: 10, refillPerSecond: 1 / 360);

  final SupabaseGateway gateway;

  /// Reports per address, on top of the general limit: 10, then one every
  /// six minutes — a broken page reports, it does not flood.
  final TokenBuckets perAddress;

  Route get route => (method: 'POST', path: '/v1/errors', handler: handle);

  static const kinds = {'flutter', 'zone', 'start', 'loader'};

  Future<Response> handle(Request request) async {
    final wait = perAddress.take(clientAddress(request));
    if (wait != null) return tooManyRequests('rate_limited', retryAfter: wait);
    final text = await readBodyWithin(request, maxErrorBytes);
    if (text == null) return jsonResponse(413, {'error': 'too_large'});
    final Object? body;
    try {
      body = jsonDecode(text);
    } on FormatException {
      return jsonResponse(400, {'error': 'bad_request'});
    }
    if (body is! Map) return jsonResponse(400, {'error': 'bad_request'});
    final message = cleanReport(body['message'], 1000);
    if (message.isEmpty) return jsonResponse(400, {'error': 'bad_request'});
    final kind = body['kind'];
    try {
      await gateway.rpc('record_client_error', {
        'p_kind': kinds.contains(kind) ? kind : 'other',
        'p_message': message,
        'p_stack': _orNull(cleanReport(body['stack'], 4000)),
        'p_app_version': _orNull(cleanReport(body['appVersion'], 40)),
        'p_user_agent': _orNull(
          cleanReport(request.headers['user-agent'], 300),
        ),
      });
    } on GatewayUnavailable catch (e) {
      // ignore: avoid_print
      print('503 on POST /v1/errors: ${e.detail}');
      return jsonResponse(503, {'error': 'unavailable'});
    } on GatewayRejected catch (e) {
      // ignore: avoid_print
      print('400 on POST /v1/errors: ${e.detail}');
      return jsonResponse(400, {'error': 'bad_request'});
    }
    return jsonResponse(202, {'status': 'received'});
  }

  static String? _orNull(String value) => value.isEmpty ? null : value;
}

final _jwt = RegExp(r'eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*');
final _key = RegExp(r'\bsb_(?:secret|publishable)_[A-Za-z0-9_-]+');
final _bearer = RegExp(r'(?<=[Bb]earer )[A-Za-z0-9._-]{8,}');
final _email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
final _secretParameter = RegExp(
  r'((?:access|refresh)_token|apikey|code|password)=[^&\s"]+',
  caseSensitive: false,
);

/// [value] as stored: text only, secrets and email addresses masked, cut to
/// [max] characters; `''` for anything else.
String cleanReport(Object? value, int max) {
  if (value is! String) return '';
  final masked = value
      .replaceAll(_jwt, '<token>')
      .replaceAll(_key, '<key>')
      .replaceAll(_bearer, '<token>')
      .replaceAll(_email, '<email>')
      .replaceAllMapped(_secretParameter, (m) => '${m[1]}=<hidden>')
      .trim();
  return masked.length > max ? masked.substring(0, max) : masked;
}
