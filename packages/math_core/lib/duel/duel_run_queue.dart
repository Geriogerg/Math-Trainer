import 'duel_client.dart';
import 'duel_mode.dart';
import 'duel_run.dart';

/// A run kept on the device until the server has decided it: saved after
/// every answer or round ([complete] false), so a run left by a closed tab
/// is still sent (plan v3.7: quitting counts).
final class PendingDuelRun {
  const PendingDuelRun({
    required this.duelId,
    required this.mode,
    required this.duelRules,
    required this.run,
    required this.complete,
  });

  final String duelId;
  final DuelMode mode;

  /// The duel's rules version: the run waits until the server lists it.
  final int duelRules;
  final DuelRun run;
  final bool complete;

  /// What is sent: a run left unfinished gets its remaining questions as
  /// timeouts, its remaining rounds as never improved.
  DuelRun get toSend => switch (run) {
    final QuizRun quiz => quiz.completedWithTimeouts(),
    final CountRun count => count.completedWithEmptyRounds(),
  };

  Map<String, Object?> toJson() => {
    'duelId': duelId,
    'mode': mode.name,
    'duelRules': duelRules,
    'run': run.toJson(),
    'complete': complete,
  };

  factory PendingDuelRun.fromJson(Object? json) {
    if (json is! Map || json['duelId'] is! String) {
      throw const FormatException('pending duel run');
    }
    final mode = DuelMode.parse(json['mode']);
    final rules = json['duelRules'];
    if (rules is! int) throw const FormatException('pending duel rules');
    return PendingDuelRun(
      duelId: json['duelId'] as String,
      mode: mode,
      duelRules: rules,
      run: DuelRun.fromJson(json['run'], mode),
      complete: json['complete'] == true,
    );
  }
}

/// Where pending runs live, per player (the app: `shared_preferences`).
abstract interface class DuelRunStore {
  Future<List<PendingDuelRun>> load(String playerId);
  Future<void> save(String playerId, List<PendingDuelRun> runs);
}

/// A player's duel runs on their way to the server, one at a time. A run
/// leaves the queue once the server has decided it — accepted or refused;
/// offline, a sleeping server, or a server that does not list the run's
/// mode and duel rules yet: it stays, and the next [flush] tries again.
class DuelRunQueue {
  DuelRunQueue({
    required this.store,
    required this.client,
    required this.playerId,
  });

  final DuelRunStore store;
  final DuelClient client;
  final String playerId;

  Future<void>? _flushing;

  /// Saves [run] of [offer] as it stands (after each answer or round), and
  /// tells the server — never awaited, never failing: what the server has
  /// is what an abandoned duel is recorded from (plan v3.8).
  ///
  /// Stored on the device first: the server only accepts a run that
  /// continues the progress it holds (Phase 6a), so the device must never
  /// know less than the server.
  Future<void> saveProgress(DuelOffer offer, DuelRun run) async {
    await _put(_pending(offer, run, complete: false));
    client.progress(offer.duelId, run).ignore();
  }

  PendingDuelRun _pending(
    DuelOffer offer,
    DuelRun run, {
    required bool complete,
  }) => PendingDuelRun(
    duelId: offer.duelId,
    mode: offer.mode,
    duelRules: offer.config.duelRules.number,
    run: run,
    complete: complete,
  );

  /// Saves the finished (or quit) [run], then sends it now. Its verdict, or
  /// `null` when it stays pending (the app shows its own result meanwhile).
  /// Throws [DuelRefused] when the server refuses it (it leaves the queue).
  Future<DuelVerdict?> finish(DuelOffer offer, DuelRun run) async {
    final pending = _pending(offer, run, complete: true);
    await _put(pending);
    return _send(pending);
  }

  /// Sends every pending run, oldest first; stops at the first that cannot
  /// be sent now. A flush during a flush waits for it.
  Future<void> flush() => _flushing ??= _flushAll().whenComplete(() {
    _flushing = null;
  });

  Future<void> _flushAll() async {
    for (final pending in await _load()) {
      try {
        if (await _send(pending) == null) return;
      } on DuelRefused {
        // Removed by _send; the next one.
      }
    }
  }

  Future<DuelVerdict?> _send(PendingDuelRun pending) async {
    try {
      final support = await client.support();
      if (!support.modes.contains(pending.mode) ||
          !support.rules.contains(pending.duelRules)) {
        return null;
      }
      final verdict = await client.submit(
        pending.duelId,
        pending.mode,
        pending.toSend,
      );
      await _remove(pending.duelId);
      return verdict;
    } on DuelUnavailable {
      return null;
    } on DuelAccountRequired {
      // Signed out of the linked account meanwhile: kept for its return.
      return null;
    } on DuelRefused {
      await _remove(pending.duelId);
      rethrow;
    }
  }

  Future<List<PendingDuelRun>> _load() async {
    try {
      return await store.load(playerId);
    } on FormatException {
      // A stored run from an older format: dropped rather than blocking.
      await store.save(playerId, const []);
      return const [];
    }
  }

  Future<void> _put(PendingDuelRun run) async {
    final runs = [
      for (final r in await _load())
        if (r.duelId != run.duelId) r,
      run,
    ];
    await store.save(playerId, runs);
  }

  Future<void> _remove(String duelId) async {
    await store.save(playerId, [
      for (final r in await _load())
        if (r.duelId != duelId) r,
    ]);
  }
}
