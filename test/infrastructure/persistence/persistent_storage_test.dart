import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/infrastructure/persistence/persistent_storage.dart';

void main() {
  test('outside the web the request is a no-op answering null', () async {
    // `flutter test` runs on the Dart VM: the conditional import picks the
    // stub. The web implementation is checked in a browser (doc/progress.md,
    // Phase 0 commit 8).
    expect(await requestPersistentStorage(), isNull);
  });
}
