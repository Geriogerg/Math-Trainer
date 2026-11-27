import 'dart:io';

/// Reading Dart sources for their words: the guard that keeps every word in
/// `lib/presentation/strings/` (Phase 6b commit 7) and the check that no
/// French string is an English one left untranslated (Phase 6d commit 5).

/// The word-holding string literals of the Dart file at [path], line by
/// line, without comments and directives: `(line number, text)`.
List<(int, String)> wordLiteralsOf(String path) => [
  for (final (line, _, text) in literalsOf(path))
    if (holdsWords(text)) (line, text),
];

/// Every single-line string literal of the Dart file at [path]:
/// `(line number, column, text)`, comments and directives left out.
List<(int, int, String)> literalsOf(String path) {
  final found = <(int, int, String)>[];
  final lines = File(path).readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('//') ||
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ') ||
        trimmed.startsWith('part ')) {
      continue;
    }
    for (final (column, text) in lineLiterals(lines[i])) {
      found.add((i + 1, column, text));
    }
  }
  return found;
}

/// Words, once interpolations are taken out: two letters in a row, and not
/// a lone lower-case identifier.
bool holdsWords(String text) {
  final bare = withoutInterpolations(text);
  if (!RegExp('[A-Za-z]{2,}').hasMatch(bare)) return false;
  return !RegExp(r'^[a-z][A-Za-z0-9_\-]*$').hasMatch(bare.trim());
}

/// [text] without `$name` and `${…}` (braces nested).
String withoutInterpolations(String text) {
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
List<(int, String)> lineLiterals(String line) {
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
        j = _escape(line, j, buffer);
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

/// Writes the character the escape at [at] (a backslash) stands for —
/// `\u202f` its character, `\n` a space — and returns its last index.
int _escape(String line, int at, StringBuffer buffer) {
  final next = line[at + 1];
  if (next == 'u') {
    final braced = RegExp(r'\{([0-9a-fA-F]+)\}').matchAsPrefix(line, at + 2);
    final plain = RegExp('[0-9a-fA-F]{4}').matchAsPrefix(line, at + 2);
    final match = braced ?? plain;
    if (match != null) {
      final hex = braced != null ? braced.group(1)! : plain!.group(0)!;
      buffer.writeCharCode(int.parse(hex, radix: 16));
      return match.end - 1;
    }
  }
  buffer.write(switch (next) {
    'n' || 't' || 'r' => ' ',
    _ => next,
  });
  return at + 1;
}
