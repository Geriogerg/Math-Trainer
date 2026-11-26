/// How often the server failed on one stored session (Phase 6a, review
/// m2): the upload queue stops at the first session it cannot send, so a
/// session that always makes the server fail would block every later game
/// for ever. Counted only when the server answered (an error status), never
/// when the device was offline. Concrete storage in `infrastructure/`.
abstract interface class UploadAttemptLog {
  /// The failures recorded for [sessionId]: how many, and when the first
  /// was; `null` for none.
  Future<({int count, DateTime first})?> failures(String sessionId);

  /// One more failure of [sessionId] at [at] (UTC).
  Future<void> recordFailure(String sessionId, DateTime at);

  /// [sessionId] was decided (accepted, refused or set aside).
  Future<void> clear(String sessionId);
}

/// In memory: tests, and a device without storage.
class InMemoryUploadAttemptLog implements UploadAttemptLog {
  final _entries = <String, ({int count, DateTime first})>{};

  @override
  Future<({int count, DateTime first})?> failures(String sessionId) async =>
      _entries[sessionId];

  @override
  Future<void> recordFailure(String sessionId, DateTime at) async {
    final held = _entries[sessionId];
    _entries[sessionId] = held == null
        ? (count: 1, first: at)
        : (count: held.count + 1, first: held.first);
  }

  @override
  Future<void> clear(String sessionId) async => _entries.remove(sessionId);
}

/// When a session is set aside: the server failed on it at least
/// [setAsideAfterFailures] times over at least [setAsideAfter] — days of
/// retries, while the server answered. It is then marked refused on the
/// device (reason [setAsideReason]) and the queue moves on.
const setAsideAfterFailures = 20;
const setAsideAfter = Duration(days: 3);

/// The local refusal reason of a session set aside (not a server
/// `RejectionReason`: the app shows its generic sentence).
const setAsideReason = 'setAside';
