import 'session_repository.dart';

/// Guests this device stopped using, and when (plan v2.2, Phase 2 commit
/// 11): a guest who signs in to another account on this device can never
/// come back (an anonymous account has no credentials), yet its games stay
/// hidden in local storage. Concrete store in `infrastructure/` (rule 3).
abstract class AbandonedGuestStore {
  Future<Map<String, DateTime>> load();

  /// Remembers [guestId] as left at [at] (UTC); the first time is kept.
  Future<void> record(String guestId, DateTime at);

  Future<void> forget(String guestId);
}

/// How long a left guest's games stay on the device: as long as the
/// server keeps an idle guest account (`cleanup_stale_guests`, 30 days).
const abandonedGuestRetention = Duration(days: 30);

/// Deletes from this device the games of every guest left more than
/// [retention] ago, then forgets them; returns their ids. A failure on one
/// guest leaves it for the next run.
Future<List<String>> deleteAbandonedGuests({
  required AbandonedGuestStore store,
  required SessionRepository repository,
  required DateTime now,
  Duration retention = abandonedGuestRetention,
}) async {
  final deleted = <String>[];
  for (final MapEntry(key: guestId, value: leftAt)
      in (await store.load()).entries) {
    if (now.difference(leftAt) < retention) continue;
    try {
      await repository.deletePlayerData(guestId);
      await store.forget(guestId);
      deleted.add(guestId);
    } on Exception catch (_) {
      // Next launch.
    }
  }
  return deleted;
}
