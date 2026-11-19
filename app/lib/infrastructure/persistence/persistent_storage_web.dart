import 'dart:js_interop';

/// `navigator.storage.persist()`. Already persistent: no new request.
/// Chrome and Edge answer from engagement heuristics without a prompt;
/// Firefox may ask the player; Safari grants it mostly to home-screen apps.
Future<bool?> requestPersistentStorage() async {
  try {
    final storage = _navigator.storage;
    if (storage == null) return null; // insecure context or no Storage API
    if ((await storage.persisted().toDart).toDart) return true;
    return (await storage.persist().toDart).toDart;
  } catch (_) {
    // A refusal or an unexpected browser must never stop the app.
    return null;
  }
}

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external _StorageManager? get storage;
}

extension type _StorageManager._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persisted();
  external JSPromise<JSBoolean> persist();
}
