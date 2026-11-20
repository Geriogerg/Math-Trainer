/// `createGameSound()`: Web Audio in a browser, silence elsewhere. Chosen
/// by conditional import — `dart:js_interop` exists only in web builds
/// (rule 15).
library;

export 'game_sound_stub.dart'
    if (dart.library.js_interop) 'web_audio_game_sound.dart';
