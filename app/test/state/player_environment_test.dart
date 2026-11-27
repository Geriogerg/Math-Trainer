import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/unfinished_game.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import '../fake_stores.dart';

class _Games implements UnfinishedGameStore {
  @override
  Future<void> save(SessionUpload game) async {}

  @override
  Future<SessionUpload?> load() async => null;

  @override
  Future<void> clear() async {}
}

void main() {
  // Phase 6b commit 5: `forPlayer` dropped both, so the signed-in player's
  // games were never kept (commit 2) and no hint ever showed (commit 4).
  test(
    'the player\'s environment keeps the kept-game store, the hints and the reload, '
    'and gets its own levels refresh',
    () {
      final games = _Games();
      final hints = FakeHintsStore();
      void reload() {}
      final device = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'device',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
        unfinishedGameStore: games,
        hints: hints,
        reloadPage: reload,
      );
      final player = device.forPlayer('me');
      expect(player.playerId, 'me');
      expect(player.unfinishedGameStore, same(games));
      expect(player.hints, same(hints));
      expect(player.reloadPage, same(reload));
      expect(player.levelsRefresh, isNotNull);
      expect(
        device.forPlayer('other').levelsRefresh,
        isNot(same(player.levelsRefresh)),
      );
    },
  );
}
