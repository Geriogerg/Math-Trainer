import 'package:math_trainer/core/domain/persistence/placement_skip_store.dart';

/// In-memory [PlacementSkipStore]: widget tests never wait on
/// `SharedPreferences`.
class FakePlacementSkipStore implements PlacementSkipStore {
  final skipped = <String>{};

  @override
  Future<bool> hasSkipped(String playerId) async => skipped.contains(playerId);

  @override
  Future<void> markSkipped(String playerId) async => skipped.add(playerId);
}
