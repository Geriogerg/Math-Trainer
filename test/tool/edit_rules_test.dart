import 'dart:io';

import 'package:test/test.dart';

import '../../tool/hooks/edit_rules.dart';

// Split literal: this file must not itself contain the unseeded call the
// hook refuses, or the hook would block edits of its own test.
const unseeded =
    'Random'
    '()';

void main() {
  group('violationsFor', () {
    test('assert( in lib/core/ is refused', () {
      final violations = violationsFor(
        'lib/core/domain/models/x.dart',
        'void f(int a) {\n  assert(a > 0);\n}\n',
      );
      expect(violations, hasLength(1));
      expect(violations.single, startsWith('line 2: `assert(`'));
    });

    test('Windows absolute paths are recognised', () {
      expect(
        violationsFor(
          r'd:\mathtrainer\math_trainer\lib\core\state\x.dart',
          'assert (true);',
        ),
        hasLength(1),
      );
    });

    test('assert( outside lib/core/ is not this hook’s business', () {
      expect(
        violationsFor('lib/presentation/x.dart', 'assert(true);'),
        isEmpty,
      );
    });

    test('a comment may mention assert( and an unseeded Random', () {
      expect(
        violationsFor(
          'lib/core/domain/x.dart',
          '/// never `assert(`, never `$unseeded`\nint x = 1; // not assert()\n',
        ),
        isEmpty,
      );
    });

    test('an unseeded Random is refused in lib/ and test/', () {
      expect(
        violationsFor('lib/presentation/x.dart', 'final r = $unseeded;'),
        hasLength(1),
      );
      expect(
        violationsFor(
          'test/domain/x_test.dart',
          'final r = Random'
              '( );',
        ),
        hasLength(1),
      );
    });

    test('seeded and secure Random are allowed', () {
      expect(
        violationsFor(
          'lib/core/domain/x.dart',
          'final a = Random(seed);\nfinal b = Random.secure();\n'
              'final c = math.Random(42);\n',
        ),
        isEmpty,
      );
    });

    test('non-Dart files and files outside lib/ and test/ are ignored', () {
      expect(violationsFor('doc/decisions.md', 'assert( $unseeded'), isEmpty);
      expect(violationsFor('tool/x.dart', unseeded), isEmpty);
    });

    test('a name merely containing assert is not a call', () {
      expect(violationsFor('lib/core/domain/x.dart', 'assertX(1);'), isEmpty);
    });

    test('the current code base has no violation', () {
      // Also guards the hook: a rule that flags existing code would block
      // every rewrite of that file.
      final files = [
        for (final dir in ['lib', 'test'])
          ...Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')),
      ];
      expect(files, isNotEmpty);
      final violations = [
        for (final file in files)
          for (final v in violationsFor(file.path, file.readAsStringSync()))
            '${file.path}: $v',
      ];
      expect(violations, isEmpty);
    });
  });
}
