import 'package:math_trainer/core/domain/persistence/uuid.dart';
import 'package:test/test.dart';

void main() {
  final uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  group('generateUuidV4', () {
    test('produces an id in UUID v4 format (RFC 4122)', () {
      for (var i = 0; i < 100; i++) {
        expect(generateUuidV4(), matches(uuidV4Pattern));
      }
    });

    test('produces no collision over a sample', () {
      final ids = List.generate(1000, (_) => generateUuidV4());

      expect(ids.toSet(), hasLength(1000));
    });
  });
}
