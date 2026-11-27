/// `setPageLanguage(code)`: the page's `<html lang>` (Phase 6d) — what a
/// screen reader pronounces with. Nothing off the web. Chosen by
/// conditional import (rule 15).
library;

export 'page_language_stub.dart'
    if (dart.library.js_interop) 'page_language_web.dart';
