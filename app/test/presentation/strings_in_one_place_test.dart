import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_literals.dart';

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
      for (final (line, start, text) in literalsOf(entity.path)) {
        final before = lines[line - 1].substring(0, start);
        if (RegExp(r'Key\(\s*$').hasMatch(before)) continue;
        if (_allowed.contains((name, text))) continue;
        if (holdsWords(text)) offenders.add('$path:$line: $text');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the scan finds what it should (its own check)', () {
    expect(holdsWords('Could not start'), isTrue);
    expect(holdsWords('Your answer \$value'), isTrue);
    expect(holdsWords('\${a.b}–\${c ?? 0}'), isFalse);
    expect(holdsWords('play-basics'), isFalse);
    expect(holdsWords('\$n / \$total'), isFalse);
    expect(lineLiterals("x('Hello', \"Bye\")").map((l) => l.$2), [
      'Hello',
      'Bye',
    ]);
  });
}
