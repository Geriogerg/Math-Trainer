import 'package:math_trainer_server/server.dart';

/// An in-memory model of the duel SQL functions
/// (`supabase/migrations/…_duels.sql`, tested on Postgres by
/// `supabase/tests/a1_duels_test.sql`): what the server's duel endpoints
/// read and write, so their logic is tested without a database.
class FakeDuelGateway implements SupabaseGateway {
  /// Token → user.
  final users = <String, AuthenticatedUser>{};
  final names = <String, String>{};

  /// Server levels (hundredths by type name) per player.
  final levels = <String, Map<String, int>>{};

  final duels = <String, Map<String, Object?>>{};
  final runs = <Map<String, Object?>>[];
  final ratings = <(String, String), Map<String, Object?>>{};
  final rejections = <(String, String), String>{};
  final calls = <String>[];
  bool down = false;

  /// Bumps these players' rating versions once, right before the next
  /// apply: another duel landed in between.
  final concurrentDuelFor = <String>{};

  /// Whether a challenge between the pair was rated today (the SQL derives
  /// it from `duels.finished_at`).
  bool Function(Map<String, Object?> duel) pairRatedToday = _ratedToday;

  int _clock = 0;
  var _runIds = 0;

  static bool _ratedToday(Map<String, Object?> duel) => false;

  void addUser(
    String token,
    String id, {
    bool anonymous = false,
    String? name,
  }) {
    users[token] = (id: id, isAnonymous: anonymous);
    if (name != null) names[id] = name;
  }

  @override
  Future<AuthenticatedUser?> userForToken(String accessToken) async {
    if (down) throw const GatewayUnavailable('down');
    return users[accessToken];
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> p) async {
    if (down) throw const GatewayUnavailable('down');
    calls.add(name);
    switch (name) {
      case 'duel_insert':
        duels[p['p_duel_id'] as String] = {
          'id': p['p_duel_id'],
          'mode': p['p_mode'],
          'kind': p['p_kind'],
          'config': p['p_config'],
          'firstPlayer': p['p_first_player'],
          'secondPlayer': p['p_second_player'],
          'firstLane': p['p_first_lane'],
          'state': p['p_kind'] == 'challenge'
              ? 'awaitingFirst'
              : 'awaitingSecond',
          'expiresAt': p['p_expires_at'],
          'rated': false,
          'createdAt': _clock++,
        };
        return null;
      case 'duel_context':
        return _context(p['p_duel_id'] as String, p['p_player_id'] as String);
      case 'record_duel_run_refused':
        final key = (p['p_duel_id'] as String, p['p_player_id'] as String);
        rejections.putIfAbsent(key, () => p['p_reason'] as String);
        final duel = duels[key.$1];
        if (duel != null &&
            (duel['state'] == 'awaitingFirst' ||
                duel['state'] == 'awaitingSecond')) {
          duel['state'] = 'void';
        }
        return null;
      case 'apply_duel_run':
        return [_apply(p)];
      case 'duel_take_run':
        return _take(p);
      case 'duel_player':
        final id = p['p_player_id'] as String;
        final user = users.values.where((u) => u.id == id).firstOrNull;
        if (user == null) return null;
        final row = ratings[(id, p['p_mode'])];
        return {
          'id': id,
          'linked': !user.isAnonymous,
          'name': names[id],
          'rating': row == null ? null : {...row},
          'levels': levels[id] ?? const {},
        };
      case 'duel_open_offer':
        final open = duels.values
            .where(
              (d) =>
                  d['secondPlayer'] == p['p_player_id'] &&
                  d['mode'] == p['p_mode'] &&
                  (d['kind'] == 'pool' || d['kind'] == 'practice') &&
                  d['state'] == 'awaitingSecond' &&
                  d['stale'] != true,
            )
            .lastOrNull;
        if (open == null) return null;
        final first = open['firstPlayer'];
        return {
          'duelId': open['id'],
          'kind': open['kind'],
          'config': open['config'],
          'lane': open['firstLane'],
          'opponent': first == null
              ? null
              : {'id': first, 'name': names[first]},
        };
      case 'duel_create_challenge':
        final me = p['p_challenger'] as String;
        final target = p['p_target'] as String;
        if (me == target) return 'self';
        if (!users.values.any((u) => u.id == target && !u.isAnonymous)) {
          return 'notLinked';
        }
        final pair = {me, target};
        if (duels.values.any(
          (d) =>
              d['kind'] == 'challenge' &&
              d['mode'] == p['p_mode'] &&
              (d['state'] == 'awaitingFirst' ||
                  d['state'] == 'awaitingSecond') &&
              d['expired'] != true &&
              pair.containsAll([d['firstPlayer'], d['secondPlayer']]),
        )) {
          return 'exists';
        }
        await rpc('duel_insert', {
          'p_duel_id': p['p_duel_id'],
          'p_mode': p['p_mode'],
          'p_kind': 'challenge',
          'p_config': p['p_config'],
          'p_first_player': me,
          'p_second_player': target,
          'p_first_lane': null,
          'p_expires_at': '2099-01-01T00:00:00Z',
        });
        return 'created';
    }
    throw StateError('unexpected rpc $name');
  }

  Map<String, Object?>? _context(String duelId, String player) {
    final duel = duels[duelId];
    if (duel == null) return null;
    final run = runs
        .where((r) => r['duelId'] == duelId && r['player'] == player)
        .firstOrNull;
    final reason = rejections[(duelId, player)];
    final other = duel['firstPlayer'] == player
        ? duel['secondPlayer']
        : duel['firstPlayer'];
    return {
      'duel': {...duel, 'opponentName': names[other]},
      'run': run == null
          ? null
          : {'lane': run['lane'], 'score': run['score'], 'flags': run['flags']},
      'rejection': reason == null ? null : {'reason': reason},
      'ratings': {
        for (final who in [duel['firstPlayer'], duel['secondPlayer']])
          if (ratings[(who, duel['mode'])] case final r?) who: {...r},
      },
      'levels': levels[player] ?? const {},
      'pairRatedToday': duel['kind'] == 'challenge' && pairRatedToday(duel),
    };
  }

  Map<String, Object?> _apply(Map<String, Object?> p) {
    final duelId = p['p_duel_id'] as String;
    final player = p['p_player_id'] as String;
    final existing = runs
        .where((r) => r['duelId'] == duelId && r['player'] == player)
        .firstOrNull;
    if (existing != null) {
      return {'outcome': 'duplicate', 'run_id': existing['id']};
    }
    final duel = duels[duelId];
    if (duel == null) return {'outcome': 'notOpen'};
    final String turn;
    if (duel['state'] == 'awaitingFirst' && duel['firstPlayer'] == player) {
      turn = 'first';
    } else if (duel['state'] == 'awaitingSecond' &&
        duel['secondPlayer'] == player) {
      turn = 'second';
    } else {
      return {'outcome': 'notOpen'};
    }
    if (duel['expired'] == true) return {'outcome': 'expired'};
    final mode = duel['mode'] as String;
    final start = p['p_start_rating'] as Map;
    ratings.putIfAbsent(
      (player, mode),
      () => {
        'rating': start['rating'],
        'deviation': start['deviation'],
        'volatility': start['volatility'],
        'ratedDuels': 0,
        'version': 0,
      },
    );
    for (final who in concurrentDuelFor) {
      final r = ratings[(who, mode)];
      if (r != null) r['version'] = (r['version'] as int) + 1;
    }
    concurrentDuelFor.clear();
    final rated = p['p_rated'] == true;
    final before = <String, Object?>{};
    final after = <String, Object?>{};
    if (turn == 'second' && rated) {
      if (duel['kind'] == 'challenge' && pairRatedToday(duel)) {
        return {'outcome': 'stale'};
      }
      final updates = (p['p_ratings'] as Map).cast<String, Map>();
      for (final MapEntry(key: who, value: u) in updates.entries) {
        final r = ratings[(who, mode)];
        if (r == null || r['version'] != u['expectedVersion']) {
          return {'outcome': 'stale'};
        }
      }
      for (final MapEntry(key: who, value: u) in updates.entries) {
        final r = ratings[(who, mode)]!;
        before[who] = r['rating'];
        after[who] = u['rating'];
        r
          ..['rating'] = u['rating']
          ..['deviation'] = u['deviation']
          ..['volatility'] = u['volatility']
          ..['ratedDuels'] = (r['ratedDuels'] as int) + 1
          ..['version'] = (r['version'] as int) + 1;
      }
    }
    final id = 'run-${++_runIds}';
    runs.add({
      'id': id,
      'duelId': duelId,
      'player': player,
      'mode': mode,
      'config': duel['config'],
      'payload': p['p_payload'],
      'lane': p['p_lane'],
      'score': p['p_score'],
      'flags': p['p_flags'],
      'review': null,
      'serves': 0,
      'createdAt': _clock++,
    });
    if (turn == 'first') {
      duel
        ..['firstRun'] = id
        ..['firstLane'] = p['p_lane']
        ..['state'] = 'awaitingSecond';
    } else {
      duel
        ..['secondRun'] = id
        ..['state'] = 'done'
        ..['result'] = p['p_result']
        ..['rated'] = rated
        ..['firstRatingBefore'] = before[duel['firstPlayer']]
        ..['firstRatingAfter'] = after[duel['firstPlayer']]
        ..['secondRatingBefore'] = before[player]
        ..['secondRatingAfter'] = after[player];
    }
    return {'outcome': 'applied', 'run_id': id};
  }

  /// `duel_take_run`: the pool's rules, as the SQL applies them.
  Map<String, Object?>? _take(Map<String, Object?> p) {
    final player = p['p_player_id'] as String;
    final mode = p['p_mode'] as String;
    final rating = (p['p_rating'] as num).toDouble();
    final opponent = p['p_opponent'] as String?;
    final difficulty = p['p_difficulty'] as int?;
    bool linked(Object? who) =>
        users.values.any((u) => u.id == who && !u.isAnonymous);
    final played = {
      for (final d in duels.values)
        if (d['firstPlayer'] == player || d['secondPlayer'] == player)
          _key(d['config']),
    };
    final latest = <Object?, List<Map<String, Object?>>>{};
    for (final r in runs.where((r) => r['mode'] == mode)) {
      (latest[r['player']] ??= []).add(r);
    }
    final pool = <Map<String, Object?>>{
      for (final owned in latest.values)
        ...([...owned]..sort(
              (a, b) =>
                  (b['createdAt'] as int).compareTo(a['createdAt'] as int),
            ))
            .take(10),
    };
    final candidates = [
      for (final r in pool)
        if (r['player'] != player &&
            linked(r['player']) &&
            (opponent == null || r['player'] == opponent) &&
            (r['serves'] as int) < 5 &&
            (((r['flags'] as List).isEmpty && r['review'] != 'rejected') ||
                r['review'] == 'ok') &&
            !played.contains(_key(r['config'])) &&
            ratings[(r['player'], mode)] != null)
          r,
    ];
    if (candidates.isEmpty) return null;
    double distance(Map<String, Object?> r) => opponent == null
        ? ((ratings[(r['player'], mode)]!['rating'] as num) - rating).abs()
        : (((r['config'] as Map)['difficulty'] as int) - (difficulty ?? 0))
              .abs()
              .toDouble();
    candidates.sort((a, b) {
      final byDistance = distance(a).compareTo(distance(b));
      return byDistance != 0
          ? byDistance
          : (b['createdAt'] as int).compareTo(a['createdAt'] as int);
    });
    final picked = candidates.first;
    picked['serves'] = (picked['serves'] as int) + 1;
    final duelId = p['p_duel_id'] as String;
    duels[duelId] = {
      'id': duelId,
      'mode': mode,
      'kind': 'pool',
      'config': picked['config'],
      'firstPlayer': picked['player'],
      'secondPlayer': player,
      'firstRun': picked['id'],
      'firstLane': picked['lane'],
      'state': 'awaitingSecond',
      'rated': false,
      'createdAt': _clock++,
    };
    final owner = ratings[(picked['player'], mode)]!;
    return {
      'duelId': duelId,
      'kind': 'pool',
      'config': picked['config'],
      'lane': picked['lane'],
      'opponent': {
        'id': picked['player'],
        'name': names[picked['player']],
        'rating': owner['rating'],
        'ratedDuels': owner['ratedDuels'],
      },
    };
  }

  static String _key(Object? config) {
    final c = config as Map;
    return [
      for (final k in ['mode', 'seed', 'difficulty', 'rules', 'duelRules'])
        c[k],
    ].join('/');
  }
}
