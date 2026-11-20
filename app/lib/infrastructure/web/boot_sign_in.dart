/// `waitForBootSignIn()`: in a browser, waits for the sign-in that
/// `web/index.html` starts during the download (Phase 5.1 commit 1); a
/// no-op elsewhere. Chosen by conditional import — `dart:js_interop` exists
/// only in web builds (rule 15).
library;

export 'boot_sign_in_stub.dart'
    if (dart.library.js_interop) 'boot_sign_in_web.dart';
