@TestOn('vm')
library;

import 'dart:io';

import 'package:math_core/account/display_name.dart';
import 'package:test/test.dart';

/// The database enforces the same rule as the app: this checks the latest
/// migration that defines `public.display_name_problem` holds this
/// package's character class and word lists, character for character —
/// change one, change both. Reads the files: VM only.
void main() {
  final migrations =
      Directory('../../supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final sql = migrations.reversed
      .map((f) => f.readAsStringSync())
      .firstWhere(
        (text) => text.contains(
          'create or replace function public.display_name_problem',
        ),
      );

  /// A Dart string as it appears in a SQL literal (quotes doubled).
  String inSql(String s) => s.replaceAll("'", "''");

  test('the same character class', () {
    expect(sql, contains("'${inSql(displayNameCharClass)}'"));
  });

  test('the same maximum length', () {
    expect(sql, contains('char_length(p_name) > $maxDisplayNameLength'));
  });

  test('the same blocked words and word starts', () {
    for (final word in [...blockedWords, ...blockedWordStarts]) {
      expect(sql, contains("'$word'"), reason: word);
    }
    // Only the two word arrays (`foreach w in array array[ … ] loop`).
    final arrays = RegExp(
      r'foreach w in array array\[(.*?)\] loop',
      dotAll: true,
    ).allMatches(sql).map((m) => m[1]!).join(',');
    final quoted = RegExp(r"'([^']+)'").allMatches(arrays).map((m) => m[1]);
    expect(quoted.toSet(), {
      ...blockedWords,
      ...blockedWordStarts,
    }, reason: 'a word in the SQL that the app does not know');
  });
}
