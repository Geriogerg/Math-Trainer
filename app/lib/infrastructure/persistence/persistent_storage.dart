/// Asks the browser not to evict this site's storage (IndexedDB holds the
/// SQLite history, `localStorage` the session and settings) under storage
/// pressure — Safari in particular evicts otherwise. Until the server keeps
/// a copy (Phase 2), local history is the only copy.
///
/// Returns `true` if storage is (now) persistent, `false` if the browser
/// declined, `null` where the question does not exist (mobile, tests, or a
/// browser without the Storage API). Never throws.
///
/// The web implementation is chosen by conditional import: `dart:js_interop`
/// exists only in web builds (rule 15).
library;

export 'persistent_storage_stub.dart'
    if (dart.library.js_interop) 'persistent_storage_web.dart';
