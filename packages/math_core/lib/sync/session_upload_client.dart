import '../leveling/level.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import 'session_upload.dart';

/// Sends one session to the server (plan, Phase 2 commit 5). The app's
/// implementation speaks HTTP (`app/lib/infrastructure/backend/`); tests
/// use fakes.
abstract interface class SessionUploadClient {
  /// Accepted or refused — both final for this session. Throws
  /// [UploadUnavailable] when it could not be decided now (offline, server
  /// asleep or down, expired sign-in): the queue retries later.
  Future<UploadOutcome> upload(SessionUpload upload);
}

sealed class UploadOutcome {
  const UploadOutcome();
}

/// Stored by the server — or already stored before ([duplicate]: the
/// endpoint is idempotent on the session id).
final class UploadAccepted extends UploadOutcome {
  const UploadAccepted({required this.syncedAt, this.duplicate = false});

  /// When the server recorded it (UTC): the session's `syncedAt`.
  final DateTime syncedAt;
  final bool duplicate;
}

/// Refused for good: never sent again.
final class UploadRefused extends UploadOutcome {
  const UploadRefused({required this.reason, this.serverLevels});

  /// A `RejectionReason` name (`validation/session_validation.dart`), or a
  /// client-side reason (`notReplayable` for a session from before
  /// schema v6).
  final String reason;

  /// The server's level cache, sent with a `levelsMismatch`: the app adopts
  /// it so its next games chain again.
  final Map<ExerciseType, LevelCacheEntry>? serverLevels;
}

/// The upload could not be decided now; nothing changed on either side.
class UploadUnavailable implements Exception {
  const UploadUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'UploadUnavailable: $reason';
}

/// The level cache as JSON (`{type: {level, sessionsPlayed, updatedAt}}`),
/// for a refusal's server levels.
Map<String, Object?> levelCacheToJson(
  Map<ExerciseType, LevelCacheEntry> levels,
) => {
  for (final MapEntry(key: type, value: entry) in levels.entries)
    type.name: {
      'level': entry.level.hundredths,
      'sessionsPlayed': entry.sessionsPlayed,
      'updatedAt': entry.updatedAt.toIso8601String(),
    },
};

/// Inverse of [levelCacheToJson]; throws [FormatException] on bad input.
Map<ExerciseType, LevelCacheEntry> levelCacheFromJson(Object? json) {
  if (json is! Map) throw const FormatException('levels is not an object');
  final result = <ExerciseType, LevelCacheEntry>{};
  for (final MapEntry(:key, :value) in json.entries) {
    final type = ExerciseType.values.where((t) => t.name == key).firstOrNull;
    if (type == null || value is! Map) {
      throw FormatException('bad level entry $key');
    }
    final level = value['level'];
    final played = value['sessionsPlayed'];
    final updatedAt = DateTime.tryParse('${value['updatedAt']}');
    if (level is! int ||
        played is! int ||
        updatedAt == null ||
        !updatedAt.isUtc) {
      throw FormatException('bad level entry $key');
    }
    try {
      result[type] = LevelCacheEntry(
        level: Level.fromHundredths(level),
        sessionsPlayed: played,
        updatedAt: updatedAt,
      );
    } on ArgumentError catch (e) {
      throw FormatException('bad level entry $key: ${e.message}');
    }
  }
  return result;
}
