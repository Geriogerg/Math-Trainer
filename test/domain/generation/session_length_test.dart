import 'package:math_trainer/core/domain/generation/session_length.dart';
import 'package:test/test.dart';

void main() {
  group('sessionLengthFor', () {
    test('sous le plafond, vise n_min * types actifs', () {
      expect(sessionLengthFor(activeTypeCount: 1, nMin: 8, cap: 24), 8);
      expect(sessionLengthFor(activeTypeCount: 2, nMin: 8, cap: 24), 16);
      expect(sessionLengthFor(activeTypeCount: 3, nMin: 8, cap: 24), 24);
    });

    test('plafonne au-delà', () {
      expect(sessionLengthFor(activeTypeCount: 4, nMin: 8, cap: 24), 24);
      expect(sessionLengthFor(activeTypeCount: 7, nMin: 8, cap: 24), 24);
    });

    test('refuse un nombre de types actifs non positif', () {
      expect(() => sessionLengthFor(activeTypeCount: 0, nMin: 8, cap: 24), throwsArgumentError);
      expect(() => sessionLengthFor(activeTypeCount: -1, nMin: 8, cap: 24), throwsArgumentError);
    });
  });
}
