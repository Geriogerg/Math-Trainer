/// `createHumanCheck(siteKey)`: Cloudflare Turnstile in a browser
/// (`window.mtHumanCheck`, web/index.html), none elsewhere until Phase 8 —
/// Turnstile has no native SDK; a mobile build needs its own (doc/decisions.md,
/// "Phase 6c build", commit 3). Chosen by conditional import (rule 15).
library;

export 'human_check_stub.dart'
    if (dart.library.js_interop) 'human_check_web.dart';
