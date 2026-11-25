import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:test/test.dart';

class MemoryStore implements DuelRunStore {
  final saved = <String, List<Map<String, Object?>>>{};

  @override
  Future<List<PendingDuelRun>> load(String playerId) async => [
    for (final json in saved[playerId] ?? const [])
      PendingDuelRun.fromJson(json),
  ];

  @override
  Future<void> save(String playerId, List<PendingDuelRun> runs) async {
    // Through JSON, as the app stores them.
    saved[playerId] = [for (final r in runs) r.toJson()];
  }
}

class FakeClient implements DuelClient {
  DuelServerSupport supported = (modes: {...DuelMode.values}, rules: {1});
  Object? failure;
  final sent = <(String, DuelRun)>[];
  final progressed = <(String, DuelRun)>[];

  @override
  Future<void> progress(String duelId, DuelRun run) async =>
      progressed.add((duelId, run));

  @override
  Future<DuelServerSupport> support() async => supported;

  @override
  Future<DuelVerdict> submit(String duelId, DuelMode mode, DuelRun run) async {
    if (failure case final f?) throw f;
    sent.add((duelId, run));
    return DuelVerdict(
      duelId: duelId,
      you: const DuelScore(mode: DuelMode.basics, points: 1, totalMs: 1),
    );
  }

  @override
  Future<DuelOffer> find(
    DuelMode mode, {
    String? rematchOf,
    String? challenge,
  }) => throw UnimplementedError();

  @override
  Future<DuelOffer> open(String duelId) => throw UnimplementedError();
}

DuelOffer _offer(String id, {DuelMode mode = DuelMode.basics}) => DuelOffer(
  duelId: id,
  kind: DuelKind.practice,
  config: DuelConfig(
    mode: mode,
    seed: 1,
    difficulty: 1,
    rulesVersion: RulesVersion.v8,
  ),
);

QuizRun _answers(int n) => QuizRun([
  for (var i = 0; i < n; i++) DuelAnswer(value: i, elapsedMs: 1000),
]);

void main() {
  late MemoryStore store;
  late FakeClient client;
  late DuelRunQueue queue;

  setUp(() {
    store = MemoryStore();
    client = FakeClient();
    queue = DuelRunQueue(store: store, client: client, playerId: 'p');
  });

  test('a finished run is sent at once and leaves the queue', () async {
    final verdict = await queue.finish(_offer('d1'), _answers(8));
    expect(verdict?.duelId, 'd1');
    expect(client.sent.single.$1, 'd1');
    expect(await store.load('p'), isEmpty);
  });

  test('offline: kept, sent by the next flush', () async {
    client.failure = const DuelUnavailable('offline');
    expect(await queue.finish(_offer('d1'), _answers(8)), isNull);
    expect((await store.load('p')).single.complete, isTrue);
    client.failure = null;
    await queue.flush();
    expect(client.sent.single.$1, 'd1');
    expect(await store.load('p'), isEmpty);
  });

  test('a server that does not list the mode or rules: kept', () async {
    client.supported = (modes: {DuelMode.basics}, rules: {1});
    expect(
      await queue.finish(_offer('c', mode: DuelMode.count), CountRun(const [])),
      isNull,
    );
    client.supported = (modes: {...DuelMode.values}, rules: {});
    expect(await queue.finish(_offer('b'), _answers(8)), isNull);
    expect(client.sent, isEmpty);
    expect((await store.load('p')).length, 2);
  });

  test('refused: removed, never resent', () async {
    client.failure = const DuelRefused('badDerivation');
    await expectLater(
      queue.finish(_offer('d1'), _answers(8)),
      throwsA(isA<DuelRefused>()),
    );
    expect(await store.load('p'), isEmpty);
  });

  test('a run left half-played is sent with the rest as timeouts', () async {
    client.failure = const DuelUnavailable('offline');
    await queue.saveProgress(_offer('d1'), _answers(3));
    expect((await store.load('p')).single.complete, isFalse);
    client.failure = null;
    await queue.flush();
    final sent = client.sent.single.$2 as QuizRun;
    expect(sent.answers.length, 8);
    expect(sent.answers.last, DuelAnswer.none);
  });

  test('progress saved again replaces the earlier save', () async {
    client.failure = const DuelUnavailable('offline');
    await queue.saveProgress(_offer('d1'), _answers(1));
    await queue.saveProgress(_offer('d1'), _answers(2));
    final kept = (await store.load('p')).single.run as QuizRun;
    expect(kept.answers.length, 2);
    // Each step also told the server (plan v3.8: abandoned duels).
    expect(
      [for (final (_, r) in client.progressed) (r as QuizRun).answers.length],
      [1, 2],
    );
  });

  test('offers and verdicts read the server\'s shapes', () {
    final offer = DuelOffer.fromJson({
      'duelId': 'd',
      'kind': 'pool',
      'config': {
        'mode': 'count',
        'seed': 1,
        'difficulty': 0,
        'rules': 8,
        'duelRules': 1,
      },
      'lane': {
        'rounds': [
          {'base': 3, 'improvements': []},
        ],
      },
      'opponent': {
        'id': 'x',
        'name': 'Léa',
        'rating': 1542.4,
        'ratedDuels': 12,
      },
    });
    expect(offer.mode, DuelMode.count);
    expect(offer.opponent!.name, 'Léa');
    expect(offer.opponent!.provisional, isFalse);
    expect(offer.lane!.score.points, 3);
    final verdict = DuelVerdict.fromJson({
      'status': 'accepted',
      'duelId': 'd',
      'you': {'points': 7, 'ms': 38000},
      'them': {'points': 6, 'ms': 31000},
      'result': 1,
      'rated': true,
      'rating': {'before': 1542.0, 'after': 1560.2, 'provisional': false},
    }, DuelMode.basics);
    expect(verdict.result, 1);
    expect(verdict.them!.points, 6);
    expect(verdict.ratingAfter, 1560.2);
    expect(verdict.provisional, isFalse);
    expect(
      () => DuelOffer.fromJson({'duelId': 'd', 'kind': 'live'}),
      throwsFormatException,
    );
  });
}
