import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/session_controller.dart';

void main() {
  group('questionTimeoutFor (debug switch DEBUG_NO_TIMEOUT)', () {
    test(
      'a release or profile build keeps the timeout even when the switch is set',
      () {
        expect(
          questionTimeoutFor(isDebugBuild: false, noTimeoutRequested: true),
          SessionController.defaultQuestionTimeout,
        );
      },
    );

    test('a debug build without the switch keeps the timeout', () {
      expect(
        questionTimeoutFor(isDebugBuild: true, noTimeoutRequested: false),
        SessionController.defaultQuestionTimeout,
      );
    });

    test('only a debug build with the switch has no timeout', () {
      expect(
        questionTimeoutFor(isDebugBuild: true, noTimeoutRequested: true),
        isNull,
      );
    });

    test('the switch is off when the build was not given it', () {
      // `flutter test` passes no --dart-define: the app built by the tests,
      // like any build without the define, keeps the timeout.
      expect(const bool.fromEnvironment('DEBUG_NO_TIMEOUT'), isFalse);
    });
  });
}
