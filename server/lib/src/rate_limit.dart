import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';

import 'http_app.dart';

/// Token buckets by key (plan v3.9, Phase 6a commit 2; review B4): each key
/// holds up to [capacity] tokens, refilled at [refillPerSecond]; a request
/// takes one. In memory: one server instance, and a restart only forgives.
///
/// Bounded: past [maxKeys] the buckets that have refilled (idle long
/// enough to be the same as absent) are dropped, then the oldest half — a
/// flood of keys cannot grow the map without limit.
class TokenBuckets {
  TokenBuckets({
    required this.capacity,
    required this.refillPerSecond,
    DateTime Function()? clock,
    this.maxKeys = 20000,
  }) : _clock = clock ?? DateTime.now {
    if (capacity < 1 || refillPerSecond <= 0 || maxKeys < 2) {
      throw ArgumentError('capacity, refillPerSecond and maxKeys: positive');
    }
  }

  final int capacity;
  final double refillPerSecond;
  final int maxKeys;
  final DateTime Function() _clock;

  /// Key → (tokens, when they were counted). Insertion order is use order:
  /// a key is re-inserted each time it is used.
  final _buckets = <String, (double, DateTime)>{};

  int get keys => _buckets.length;

  /// Takes one token for [key]: `null` when there was one, else how long
  /// until the next.
  Duration? take(String key) {
    final now = _clock();
    final held = _buckets.remove(key);
    var tokens = capacity.toDouble();
    if (held != null) {
      final seconds = now.difference(held.$2).inMicroseconds / 1e6;
      tokens = min(
        capacity.toDouble(),
        held.$1 + max(0, seconds) * refillPerSecond,
      );
    }
    final allowed = tokens >= 1;
    _buckets[key] = (allowed ? tokens - 1 : tokens, now);
    if (_buckets.length > maxKeys) _evict(now);
    if (allowed) return null;
    return Duration(
      milliseconds: max(1, ((1 - tokens) / refillPerSecond * 1000).ceil()),
    );
  }

  void _evict(DateTime now) {
    _buckets.removeWhere((_, held) {
      final seconds = now.difference(held.$2).inMicroseconds / 1e6;
      return held.$1 + seconds * refillPerSecond >= capacity;
    });
    if (_buckets.length <= maxKeys) return;
    final oldest = _buckets.keys.take(_buckets.length ~/ 2).toList();
    oldest.forEach(_buckets.remove);
  }
}

/// The server's two floors under abuse: every request counts against its
/// address before anything else is done (authentication is a call to
/// Supabase), and every authenticated request against its player.
///
/// The numbers leave an honest player far from the limit — a duel is about
/// ten requests in a minute or more, a backlog of games uploads one at a
/// time — and several players behind one address (a school, a phone
/// network) well inside the address's.
class RateLimits {
  RateLimits({TokenBuckets? perAddress, TokenBuckets? perPlayer})
    : perAddress =
          perAddress ?? TokenBuckets(capacity: 120, refillPerSecond: 2),
      perPlayer = perPlayer ?? TokenBuckets(capacity: 40, refillPerSecond: 0.5);

  final TokenBuckets perAddress;
  final TokenBuckets perPlayer;

  /// 429 when [request]'s address has no token left, else `null`.
  Response? checkAddress(Request request) =>
      _answer(perAddress.take(clientAddress(request)));

  /// 429 when [playerId] has no token left, else `null`.
  Response? checkPlayer(String playerId) => _answer(perPlayer.take(playerId));

  static Response? _answer(Duration? wait) =>
      wait == null ? null : tooManyRequests('rate_limited', retryAfter: wait);
}

/// 429: not a refusal — the app keeps what it was sending and tries again
/// later (`retry-after`, in seconds).
Response tooManyRequests(String error, {required Duration retryAfter}) =>
    jsonResponse(429, {
      'error': error,
    }).change(headers: {'retry-after': '${max(1, retryAfter.inSeconds)}'});

/// The address a request counts against: what the host's proxy reports
/// (`cf-connecting-ip`, else the first `x-forwarded-for` entry), else the
/// socket's. Best effort — where the proxy does not overwrite these
/// headers a client can pick its own key, which weakens this limit and
/// never turns it against other players; the per-player limit does not
/// depend on it.
String clientAddress(Request request) {
  String? clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : (v.length > 64 ? v.substring(0, 64) : v);
  }

  final direct = clean(request.headers['cf-connecting-ip']);
  if (direct != null) return direct;
  final forwarded = clean(request.headers['x-forwarded-for']?.split(',').first);
  if (forwarded != null) return forwarded;
  final info = request.context['shelf.io.connection_info'];
  return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
}
