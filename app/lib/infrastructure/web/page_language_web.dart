import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('document.documentElement')
external JSObject get _root;

/// Sets `<html lang>` to [code] ("en", "fr").
void setPageLanguage(String code) => _root.setProperty('lang'.toJS, code.toJS);
