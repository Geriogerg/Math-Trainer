/// `createGameHaptics()`: the vibration API in a browser, Flutter's
/// `HapticFeedback` elsewhere. Chosen by conditional import (rule 15).
library;

export 'platform_haptics.dart'
    if (dart.library.js_interop) 'web_vibration_haptics.dart';
