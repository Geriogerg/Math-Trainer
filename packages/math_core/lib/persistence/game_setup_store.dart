import '../models/game_setup.dart';

/// Remembers the setup page's choices between launches (rule 3: the
/// concrete store lives in the app's `infrastructure/`).
abstract class GameSetupStore {
  /// `null`: never stored, or stored by a build that knew other choices —
  /// the caller uses the default.
  Future<GameSetup?> load();

  Future<void> save(GameSetup setup);
}
