// Claude Code PreToolUse hook (Write|Edit|MultiEdit), see
// `.claude/settings.json`. Reads the tool call as JSON on stdin; exit code
// 2 refuses it and stderr tells Claude why.
import 'dart:convert';
import 'dart:io';

import 'edit_rules.dart';

Future<void> main() async {
  final input = jsonDecode(await stdin.transform(utf8.decoder).join());
  final toolInput = (input as Map<String, dynamic>)['tool_input'];
  if (toolInput is! Map<String, dynamic>) return;
  final path = toolInput['file_path'];
  if (path is! String) return;

  // Write: the whole new file. Edit: the replacement text. MultiEdit: every
  // replacement. Only what Claude adds is checked.
  final texts = <String>[
    if (toolInput['content'] case final String content) content,
    if (toolInput['new_string'] case final String replacement) replacement,
    if (toolInput['edits'] case final List<dynamic> edits)
      for (final edit in edits)
        if (edit case {'new_string': final String replacement}) replacement,
  ];

  final violations = [for (final text in texts) ...violationsFor(path, text)];
  if (violations.isEmpty) return;
  stderr.writeln('Refused by tool/hooks/guard_edit.dart ($path):');
  for (final violation in violations) {
    stderr.writeln('- $violation');
  }
  exitCode = 2;
}
