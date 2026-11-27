import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every word a player reads lives in `lib/presentation/strings/` (Phase 6b
/// commit 7, review m18; plan v4.0: strings in one place, French right
/// after). This scans the rest of `lib/presentation/` for string literals
/// that hold words and fails on any — a new screen's text goes in a
/// strings class, never inline.
///
/// What is not a word: keys and identifiers (`'play-basics'`), numbers and
/// punctuation around interpolations (`'$a – $b'`), and the few entries of
/// [_allowed], each with its reason.
const _allowed = {
  // Notation, not language: the integral's "dx", a placeholder friend code.
  ('exercise_prompt.dart', ' dx'),
  ('friends_screen.dart', 'MATH-7K2P-QX4M'),
  // Font families' names.
  ('app_theme.dart', 'Space Grotesk Digits'),
  ('app_theme.dart', 'Inter'),
  // An internal error, caught by the game flow, which shows its own words.
  ('play_tab.dart', 'Nothing due.'),
};

/// Developer-only screens: the typeface specimen (preview builds only).
const _exemptFiles = {'specimen_screen.dart'};

void main() {
  test('no player-facing text outside lib/presentation/strings/', () {
    final offenders = <String>[];
    final root = Directory('lib/presentation');
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/strings/')) continue;
      final name = path.split('/').last;
      if (_exemptFiles.contains(name)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('import ') ||
            trimmed.startsWith('export ') ||
            trimmed.startsWith('part ')) {
          continue;
        }
        for (final (start, text) in _literals(line)) {
          final before = line.substring(0, start);
          if (RegExp(r'Key\(\s*$').hasMatch(before)) continue;
          if (_allowed.contains((name, text))) continue;
          if (_holdsWords(text)) offenders.add('$path:${i + 1}: $text');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the scan finds what it should (its own check)', () {
    expect(_holdsWords('Could not start'), isTrue);
    expect(_holdsWords('Your answer \$value'), isTrue);
    expect(_holdsWords('\${a.b}–\${c ?? 0}'), isFalse);
    expect(_holdsWords('play-basics'), isFalse);
    expect(_holdsWords('\$n / \$total'), isFalse);
    expect(_literals("x('Hello', \"Bye\")").map((l) => l.$2), ['Hello', 'Bye']);
  });
}

/// Words, once interpolations are taken out: two letters in a row, and not
/// a lone lower-case identifier.
bool _holdsWords(String text) {
  final bare = _withoutInterpolations(text);
  if (!RegExp('[A-Za-z]{2,}').hasMatch(bare)) return false;
  return !RegExp(r'^[a-z][A-Za-z0-9_\-]*$').hasMatch(bare.trim());
}

/// [text] without `$name` and `${…}` (braces nested).
String _withoutInterpolations(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (text[i] == r'$' && i + 1 < text.length) {
      if (text[i + 1] == '{') {
        var depth = 0;
        var j = i + 1;
        for (; j < text.length; j++) {
          if (text[j] == '{') depth++;
          if (text[j] == '}' && --depth == 0) break;
        }
        i = j + 1;
        continue;
      }
      var j = i + 1;
      while (j < text.length && RegExp(r'\w').hasMatch(text[j])) {
        j++;
      }
      i = j;
      continue;
    }
    out.write(text[i]);
    i++;
  }
  return out.toString();
}

/// The single-line string literals of [line], with where each starts.
/// Quotes inside an interpolation (`'${a ?? 'x'}'`) belong to it.
List<(int, String)> _literals(String line) {
  final found = <(int, String)>[];
  var i = 0;
  while (i < line.length) {
    final quote = line[i];
    if (quote != "'" && quote != '"') {
      // A comment ends the code.
      if (line.startsWith('//', i)) break;
      i++;
      continue;
    }
    final start = i;
    final buffer = StringBuffer();
    var j = i + 1;
    var depth = 0;
    for (; j < line.length; j++) {
      final c = line[j];
      if (depth == 0 && c == r'\' && j + 1 < line.length) {
        buffer.write(line[j + 1]);
        j++;
        continue;
      }
      if (c == r'$' && j + 1 < line.length && line[j + 1] == '{') {
        depth++;
        buffer.write(r'${');
        j++;
        continue;
      }
      if (depth > 0) {
        if (c == '{') depth++;
        if (c == '}') depth--;
        buffer.write(c);
        continue;
      }
      if (c == quote) break;
      buffer.write(c);
    }
    found.add((start, buffer.toString()));
    i = j + 1;
  }
  return found;
}
