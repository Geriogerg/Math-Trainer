/// `createLinkSharer()`: the Web Share API in a browser, none elsewhere
/// (until Phase 8). Chosen by conditional import (rule 15).
library;

export 'no_link_sharer.dart'
    if (dart.library.js_interop) 'web_link_sharer.dart';
