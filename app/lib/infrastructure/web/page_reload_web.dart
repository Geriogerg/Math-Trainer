import 'dart:js_interop';

@JS('location.reload')
external void _reload();

// A plain Dart function: JS interop members cannot be torn off.
void _reloadPage() => _reload();

/// Reloads the page — what a player would do by hand, offered as a button.
const void Function() reloadPage = _reloadPage;
