import '../challenges/chain.dart';

/// Remembers Chain operations' setup between launches (Redesign close-out,
/// plan v3.0), like `GameSetupStore` for the operations' games.
abstract class ChainSetupStore {
  /// `null`: never stored, or stored by a build that offered other
  /// choices — the caller uses the default.
  Future<ChainSetup?> load();

  Future<void> save(ChainSetup setup);
}
