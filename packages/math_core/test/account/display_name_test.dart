import 'package:math_core/account/display_name.dart';
import 'package:test/test.dart';

/// The same samples as `supabase/tests/40_display_names_test.sql`: the
/// app's check and the database's must agree.
const samples = <String, DisplayNameProblem?>{
  'Ada': null,
  'Zoé Martin': null,
  'Nguyễn Văn An': null,
  'Ελένη': null,
  'Пётр': null,
  "O'Brien-2": null,
  'Marc_Antoine.9': null,
  'Mitsuko': null,
  '': DisplayNameProblem.empty,
  'abcdefghijklmnopqrstuvwxyz12345': DisplayNameProblem.tooLong,
  ' Ada': DisplayNameProblem.spaces,
  'Ada  Lovelace': DisplayNameProblem.spaces,
  '李雷': DisplayNameProblem.charset,
  'Ada 🙂': DisplayNameProblem.charset,
  'مريم': DisplayNameProblem.charset,
  '-._': DisplayNameProblem.noLetter,
  'Big Fucker': DisplayNameProblem.blocked,
  's.a.l.o.p.e': DisplayNameProblem.blocked,
  'Shitake': DisplayNameProblem.blocked,
  'Enculé': DisplayNameProblem.blocked,
};

void main() {
  for (final MapEntry(key: name, value: expected) in samples.entries) {
    test('"$name" → ${expected?.name ?? 'allowed'}', () {
      expect(displayNameProblem(name), expected);
    });
  }

  test('the character class covers every letter of the samples it allows', () {
    // Catches a range typo: a real name refused for a missing letter.
    for (final name in ['Àéîõü Ÿ', 'Łódź Śćń', 'Ωμέγα', 'Жюль Ёж', 'Đặng']) {
      expect(displayNameProblem(name), isNull, reason: name);
    }
  });
}
