import 'package:math_core/duel/duel_client.dart';

/// A duel request's [body] as this build's app sends it: `find` and `open`
/// declare the rules versions they know (plan v4.1). A body that already
/// says (`rules`), or is not a map, is left as it is.
Object? withKnownRules(String path, Object? body) =>
    (path == '/v1/duels' || path == '/v1/duels/open') &&
        body is Map<String, Object?> &&
        !body.containsKey('rules')
    ? {...body, ...knownDuelRules()}
    : body;
