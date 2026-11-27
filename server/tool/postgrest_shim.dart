// A stand-in for the two Supabase endpoints the server calls (Phase 6a
// commit 7, review finding M12): `GET /auth/v1/user` and
// `POST /rest/v1/rpc/<function>`, answered from a real Postgres with every
// migration applied. The server runs unchanged against it — its HTTP
// gateway, the real SQL functions, the real grants (each call runs as
// `service_role`, as PostgREST does with the secret key).
//
//   dart run tool/postgrest_shim.dart <port> <postgres url>
//
// For CI's integration job and local runs only: no authentication beyond
// what the tests need (a token is a JWT whose `sub` is an `auth.users` id).
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/postgrest_shim.dart <port> <postgres url>',
    );
    exitCode = 64;
    return;
  }
  final port = int.parse(args[0]);
  final db = Uri.parse(args[1]);
  final userInfo = db.userInfo.split(':');
  final pool = Pool.withEndpoints(
    [
      Endpoint(
        host: db.host,
        port: db.hasPort ? db.port : 5432,
        database: db.pathSegments.isEmpty ? 'postgres' : db.pathSegments.first,
        username: Uri.decodeComponent(userInfo.first),
        password: userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null,
      ),
    ],
    settings: const PoolSettings(
      maxConnectionCount: 4,
      sslMode: SslMode.disable,
    ),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('postgrest shim on :$port');
  await for (final request in server) {
    try {
      await _handle(request, pool);
    } on Object catch (e) {
      _send(request, 500, {'message': '$e'});
    }
  }
}

Future<void> _handle(HttpRequest request, Pool pool) async {
  final path = request.uri.path;
  if (request.method == 'GET' && path == '/auth/v1/user') {
    final user = await _user(request, pool);
    if (user == null) return _send(request, 401, {'message': 'invalid token'});
    return _send(request, 200, user);
  }
  final rpc = RegExp(r'^/rest/v1/rpc/([a-z_0-9]+)$').firstMatch(path);
  if (request.method == 'POST' && rpc != null) {
    final params = (jsonDecode(await utf8.decodeStream(request)) as Map)
        .cast<String, Object?>();
    return _rpc(request, pool, rpc[1]!, params);
  }
  _send(request, 404, {'message': 'not found'});
}

/// The `sub` of a JWT-shaped bearer token, if it names a user.
Future<Map<String, Object?>?> _user(HttpRequest request, Pool pool) async {
  final header = request.headers.value('authorization') ?? '';
  final parts = header.replaceFirst('Bearer ', '').split('.');
  if (parts.length != 3) return null;
  final Object? payload;
  try {
    payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
  } on FormatException {
    return null;
  }
  if (payload is! Map || payload['sub'] is! String) return null;
  final rows = await pool.execute(
    Sql.named(
      'select id::text, is_anonymous, email_confirmed_at::text '
      'from auth.users where id::text = @id',
    ),
    parameters: {'id': payload['sub']},
  );
  if (rows.isEmpty) return null;
  return {
    'id': rows.first[0],
    'is_anonymous': rows.first[1],
    'email_confirmed_at': rows.first[2],
  };
}

/// `public.<name>(<param> => value, …)` as `service_role`: a set or table
/// result as a JSON array of objects, anything else as its JSON value — as
/// PostgREST answers. A SQL error is a 4xx with its code, as PostgREST maps
/// them (42501 → 403, 42883 → 404, else 400).
Future<void> _rpc(
  HttpRequest request,
  Pool pool,
  String name,
  Map<String, Object?> params,
) async {
  final signature = await pool.execute(
    Sql.named('''
      select p.proretset or p.prorettype = 'record'::regtype,
        p.prorettype = 'void'::regtype,
        coalesce(p.proargnames, '{}'),
        array(select format_type(t, null) from unnest(p.proargtypes) t)
      from pg_proc p
      where p.pronamespace = 'public'::regnamespace and p.proname = @name
    '''),
    parameters: {'name': name},
  );
  if (signature.isEmpty) {
    return _send(request, 404, {
      'code': '42883',
      'message': 'no function $name',
    });
  }
  final returnsRows = signature.first[0]! as bool;
  final returnsVoid = signature.first[1]! as bool;
  final names = (signature.first[2]! as List).cast<String>();
  final types = (signature.first[3]! as List).cast<String>();
  final args = <String>[];
  final values = <String, Object?>{};
  for (final MapEntry(key: param, value: value) in params.entries) {
    final i = names.indexOf(param);
    if (i < 0) {
      return _send(request, 404, {
        'code': '42883',
        'message': 'no parameter $param',
      });
    }
    final type = types[i];
    final key = 'p$i';
    values[key] = value == null ? null : jsonEncode(value);
    // cast(… as …), not ::, right after a placeholder: `@name:type` is the
    // package's own syntax.
    final json = 'cast(@$key as jsonb)';
    final expr = switch (type) {
      'jsonb' => json,
      'json' => '$json::json',
      'text[]' => 'array(select jsonb_array_elements_text($json))',
      _ => '($json #>> \'{}\')::$type',
    };
    args.add('$param => $expr');
  }
  final call = 'public.$name(${args.join(', ')})';
  final sql = returnsRows
      ? 'select coalesce(json_agg(t), \'[]\'::json)::text from $call t'
      : returnsVoid
      ? 'select $call'
      : 'select to_json($call)::text';
  try {
    final result = await pool.runTx((tx) async {
      await tx.execute('set local role service_role');
      return tx.execute(Sql.named(sql), parameters: values);
    });
    if (returnsVoid) return _sendText(request, 200, '');
    return _sendText(request, 200, result.first[0] as String? ?? 'null');
  } on ServerException catch (e) {
    final status = switch (e.code) {
      '42501' => 403,
      '42883' => 404,
      _ => 400,
    };
    _send(request, status, {'code': e.code, 'message': e.message});
  }
}

void _send(HttpRequest request, int status, Object body) =>
    _sendText(request, status, jsonEncode(body));

void _sendText(HttpRequest request, int status, String body) {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  request.response.close();
}
