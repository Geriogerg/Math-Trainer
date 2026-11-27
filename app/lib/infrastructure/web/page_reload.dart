/// `reloadPage()`: reloads the web page (Phase 6b commit 5, the start's
/// catch-all); `null` where there is no page to reload. Chosen by
/// conditional import — `dart:js_interop` exists only in web builds (rule
/// 15).
library;

export 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
