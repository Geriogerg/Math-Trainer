@TestOn('vm')
library;

import 'dart:io';

import 'package:math_core/account/display_name.dart';
import 'package:test/test.dart';

/// The database enforces the same rule as the app
/// (`supabase/migrations/…_display_names.sql`): this checks the migration
/// holds this package's character class and word lists, character for
/// character — change one, change both. Reads the file: VM only.
void main() {
  final sql = File(
    '../../supabase/migrations/20261120030000_display_names.sql',
  ).readAsStringSync();

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
