/// Rules the Claude Code hooks enforce on every file Claude writes or edits
/// (`.claude/settings.json`, `tool/hooks/guard_edit.dart`). Pure, so that
/// `tool/test/edit_rules_test.dart` covers it.
library;

final _assertCall = RegExp(r'\bassert\s*\(');
final _unseededRandom = RegExp(r'\bRandom\s*\(\s*\)');

/// The violations [text] would bring into the file at [path] (a path with
/// `/` or `\` separators, absolute or relative to the repo). Lines that are
/// comments are ignored: explaining why `assert(` is banned stays possible.
List<String> violationsFor(String path, String text) {
  final normalised = '/${path.replaceAll(r'\', '/')}';
  if (!normalised.endsWith('.dart')) return const [];
  // The core package, and the app's `lib/core/` (its state layer).
  final inCore =
      normalised.contains('/packages/math_core/lib/') ||
      normalised.contains('/lib/core/');
  final inAppOrTests =
      normalised.contains('/lib/') || normalised.contains('/test/');

  final violations = <String>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final code = _withoutComment(lines[i]);
    if (inCore && _assertCall.hasMatch(code)) {
      violations.add(
        'line ${i + 1}: `assert(` in the core — rule 13: invariants by '
        '`throw` (ArgumentError/StateError), with a test of the invalid case; '
        'asserts vanish from release builds.',
      );
    }
    if (inAppOrTests && _unseededRandom.hasMatch(code)) {
      violations.add(
        'line ${i + 1}: unseeded `Random()` — rule 2: pass an explicit seed '
        '(`Random(seed)`), or `Random.secure()` for ids.',
      );
    }
  }
  return violations;
}

/// The line without a `//` comment. Approximate (a `//` inside a string
/// literal cuts the line too), which can only hide code, never flag a
/// comment.
String _withoutComment(String line) {
  final start = line.indexOf('//');
  return start < 0 ? line : line.substring(0, start);
}
