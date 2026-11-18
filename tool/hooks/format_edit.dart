// Claude Code PostToolUse hook (Write|Edit|MultiEdit), see
// `.claude/settings.json`: formats the Dart file Claude just wrote, so the
// repo stays `dart format` clean (checked by CI). Never blocks: a file that
// does not parse yet is left as is and the analyzer reports it.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final input = jsonDecode(await stdin.transform(utf8.decoder).join());
  final toolInput = (input as Map<String, dynamic>)['tool_input'];
  if (toolInput is! Map<String, dynamic>) return;
  final path = toolInput['file_path'];
  if (path is! String || !path.endsWith('.dart') || !File(path).existsSync()) {
    return;
  }
  // The Dart VM running this script: no reliance on `dart` being on PATH
  // (on Windows it is a .bat file that Process.run cannot start directly).
  await Process.run(Platform.resolvedExecutable, ['format', path]);
}
