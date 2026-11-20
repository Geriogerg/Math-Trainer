import '../../core/effects/game_sound.dart';

/// Outside the browser: silence until Phase 8 brings an audio package
/// behind the same `GameSound` (`doc/decisions.md`).
GameSound createGameSound() => const NoGameSound();
