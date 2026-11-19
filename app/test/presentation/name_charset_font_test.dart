import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/account/display_name.dart';

/// Plan, Phase 2 commit 9: a player name may only use characters the
/// bundled fonts draw (no font is fetched at runtime: a missing glyph shows
/// as a box on everyone's leaderboard). This reads Inter's character map
/// and checks it holds every character `displayNameCharClass` allows — a
/// font swap that drops a script fails here, not on a player's screen.
void main() {
  test('Inter draws every character a name may use', () {
    final covered = _cmapCodePoints(
      File('assets/fonts/Inter.ttf').readAsBytesSync(),
    );
    final missing = [
      for (final c in _allowedCodePoints(displayNameCharClass))
        if (!covered.contains(c)) 'U+${c.toRadixString(16).toUpperCase()}',
    ];
    expect(missing, isEmpty);
  });
}

/// The code points of a `[...]` class made of `\uXXXX` escapes, ranges
/// and literal ASCII characters.
Set<int> _allowedCodePoints(String charClass) {
  final body = charClass.substring(1, charClass.length - 1);
  final chars = <int>[];
  for (var i = 0; i < body.length; i++) {
    if (body[i] == r'\' && body[i + 1] == 'u') {
      chars.add(int.parse(body.substring(i + 2, i + 6), radix: 16));
      i += 5;
    } else {
      chars.add(body.codeUnitAt(i));
    }
  }
  final result = <int>{};
  for (var i = 0; i < chars.length; i++) {
    // `a-b` is a range unless `-` ends the class.
    if (i + 2 < chars.length && chars[i + 1] == 0x2D) {
      for (var c = chars[i]; c <= chars[i + 2]; c++) {
        result.add(c);
      }
      i += 2;
    } else {
      result.add(chars[i]);
    }
  }
  return result;
}

/// Every code point mapped by the font's `cmap` (formats 4 and 12).
Set<int> _cmapCodePoints(Uint8List font) {
  final data = ByteData.sublistView(font);
  final tableCount = data.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(font.sublist(record, record + 4));
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  if (cmap < 0) throw StateError('no cmap table');
  final result = <int>{};
  final subtables = data.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final start = cmap + data.getUint32(cmap + 4 + 8 * i + 4);
    switch (data.getUint16(start)) {
      case 4:
        final segments = data.getUint16(start + 6) ~/ 2;
        for (var s = 0; s < segments; s++) {
          final end = data.getUint16(start + 14 + 2 * s);
          final first = data.getUint16(start + 16 + 2 * segments + 2 * s);
          if (first == 0xFFFF) continue;
          for (var c = first; c <= end; c++) {
            result.add(c);
          }
        }
      case 12:
        final groups = data.getUint32(start + 12);
        for (var g = 0; g < groups; g++) {
          final first = data.getUint32(start + 16 + 12 * g);
          final last = data.getUint32(start + 20 + 12 * g);
          for (var c = first; c <= last; c++) {
            result.add(c);
          }
        }
    }
  }
  return result;
}
