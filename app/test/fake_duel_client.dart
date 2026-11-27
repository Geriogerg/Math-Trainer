import 'dart:async';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/duel/duel_validation.dart';

/// The server's duel endpoints, in memory: offers handed out in order,
/// runs judged with the core against the offer's lane, as the server does.
class FakeDuelClient implements DuelClient {
  FakeDuelClient({List<DuelOffer> offers = const []}) : offers = [...offers];

  final List<DuelOffer> offers;
  final submitted = <(String, DuelRun)>[];
  final progressed = <(String, DuelRun)>[];

  @override
  Future<void> progress(String duelId, DuelRun run) async =>
      progressed.add((duelId, run));
  final finds = <({DuelMode mode, String? rematchOf, String? challenge})>[];

  /// Thrown by the next calls (offline, a refusal…) while set.
  Object? failure;

  final _byId = <String, DuelOffer>{};

  /// While set, `/health` waits for it: a server still asleep.
  Completer<void>? asleep;

  var supportCalls = 0;

  @override
  Future<DuelServerSupport> support() async {
    supportCalls++;
    if (asleep case final waking?) await waking.future;
    // `/health` fails only offline; a refusal is the endpoint's.
    if (failure case final DuelUnavailable f) throw f;
    return (modes: {...DuelMode.values}, rules: {1});
  }

  @override
  Future<DuelOffer> find(
    DuelMode mode, {
    String? rematchOf,
    String? challenge,
  }) async {
    finds.add((mode: mode, rematchOf: rematchOf, challenge: challenge));
    if (failure case final f?) throw f;
    final offer = offers.removeAt(0);
    _byId[offer.duelId] = offer;
    return offer;
  }

  @override
  Future<DuelOffer> open(String duelId) async {
    if (failure case final f?) throw f;
    final offer = offers.firstWhere((o) => o.duelId == duelId);
    _byId[duelId] = offer;
    return offer;
  }

  @override
  Future<DuelVerdict> submit(String duelId, DuelMode mode, DuelRun run) async {
    if (failure case final f?) throw f;
    submitted.add((duelId, run));
    final offer = _byId[duelId];
    if (offer == null) throw const DuelRefused('unknownDuel');
    final verdict = validateDuelRun(offer.config, run);
    if (verdict is DuelRunInvalid) throw DuelRefused(verdict.problem.name);
    final mine = (verdict as DuelRunValid).score;
    final theirs = offer.lane?.score;
    return DuelVerdict(
      duelId: duelId,
      you: mine,
      waiting: theirs == null,
      result: theirs == null ? null : duelResult(mine, theirs),
      them: theirs,
      rated: offer.kind == DuelKind.pool,
      ratingBefore: offer.kind == DuelKind.pool ? 1542 : null,
      ratingAfter: offer.kind == DuelKind.pool ? 1560.4 : null,
      ratingNow: 1500,
      provisional: false,
    );
  }

  /// Registers an offer handed out by another path (a test building the
  /// controller directly).
  void know(DuelOffer offer) => _byId[offer.duelId] = offer;
}

/// Pending runs in memory, through JSON as the device stores them.
class MemoryDuelRunStore implements DuelRunStore {
  final saved = <String, List<Map<String, Object?>>>{};

  @override
  Future<List<PendingDuelRun>> load(String playerId) async => [
    for (final json in saved[playerId] ?? const [])
      PendingDuelRun.fromJson(json),
  ];

  @override
  Future<void> save(String playerId, List<PendingDuelRun> runs) async {
    saved[playerId] = [for (final r in runs) r.toJson()];
  }
}
