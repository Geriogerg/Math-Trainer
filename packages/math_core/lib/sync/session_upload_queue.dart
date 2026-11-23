import 'dart:async';

import '../leveling/rules_version.dart';
import '../persistence/session_repository.dart';
import 'session_upload.dart';
import 'session_upload_client.dart';

/// What one [SessionUploadQueue.flush] did.
typedef UploadRun = ({int accepted, int refused, bool stoppedOffline});

/// The offline upload queue (plan, Phase 2 commit 5): every stored session
/// of the player not yet accepted nor refused is sent, **oldest first and
/// one at a time** — the server checks that each session's levels chain
/// from the previous one. The queue is the database itself
/// (`pendingUploads`): nothing to lose when the app closes.
///
/// A network or server failure stops the run and schedules a retry, with a
/// growing delay; any later [flush] (after a game, at sign-in) also retries.
class SessionUploadQueue {
  SessionUploadQueue({
    required this.repository,
    required this.client,
    required this.playerId,
    Timer Function(Duration, void Function())? createTimer,
    this.retryDelays = const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 10),
    ],
  }) : _createTimer = createTimer ?? Timer.new {
    if (retryDelays.isEmpty) {
      throw ArgumentError.value(retryDelays, 'retryDelays', 'is empty.');
    }
  }

  final SessionRepository repository;
  final SessionUploadClient client;
  final String playerId;

  /// Delay before the n-th retry in a row; the last one repeats.
  final List<Duration> retryDelays;
  final Timer Function(Duration, void Function()) _createTimer;

  Future<UploadRun>? _running;
  bool _again = false;
  int _failuresInARow = 0;
  Timer? _retry;
  bool _disposed = false;

  /// Sends what is pending. Concurrent calls share the running pass; a call
  /// arriving during it makes it run once more at the end, so a session
  /// stored meanwhile is not left behind.
  Future<UploadRun> flush() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<UploadRun> _loop() async {
    var accepted = 0;
    var refused = 0;
    while (true) {
      _again = false;
      final run = await _pass();
      accepted += run.accepted;
      refused += run.refused;
      if (run.stoppedOffline || !_again || _disposed) {
        return (
          accepted: accepted,
          refused: refused,
          stoppedOffline: run.stoppedOffline,
        );
      }
    }
  }

  Future<UploadRun> _pass() async {
    var accepted = 0;
    var refused = 0;
    final pending = await repository.pendingUploads(playerId);
    for (final session in pending) {
      if (_disposed) break;
      // Played under retired rules (before the Levels phase's transition):
      // the server would refuse it (`rulesRetired`) and it can move
      // nothing, so it is never sent. That covers every session without a
      // type order (before schema v6) too.
      if (session.rulesVersion == RulesVersion.v1) {
        await repository.markUploadRefused(session.id, 'rulesRetired');
        refused++;
        continue;
      }
      final answers = await repository.answersForSession(session.id);
      final UploadOutcome outcome;
      try {
        outcome = await client.upload(
          SessionUpload(session: session, answers: answers),
        );
      } on UploadUnavailable {
        _scheduleRetry();
        return (accepted: accepted, refused: refused, stoppedOffline: true);
      }
      switch (outcome) {
        case UploadAccepted(:final syncedAt):
          await repository.markSynced(session.id, syncedAt);
          accepted++;
        case UploadRefused(:final reason, :final serverLevels):
          await repository.markUploadRefused(session.id, reason);
          if (serverLevels != null) {
            await repository.replaceLevelCache(playerId, serverLevels);
          }
          refused++;
      }
    }
    _failuresInARow = 0;
    _retry?.cancel();
    _retry = null;
    return (accepted: accepted, refused: refused, stoppedOffline: false);
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final delay =
        retryDelays[_failuresInARow < retryDelays.length
            ? _failuresInARow
            : retryDelays.length - 1];
    _failuresInARow++;
    _retry?.cancel();
    _retry = _createTimer(delay, () {
      _retry = null;
      flush().ignore();
    });
  }

  /// Stops retrying (the player signed out or changed).
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _retry = null;
  }
}
