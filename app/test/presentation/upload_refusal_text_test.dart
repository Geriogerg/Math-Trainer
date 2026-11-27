import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:math_trainer/presentation/strings/upload_refusal_text.dart';

void main() {
  test('every rejection reason has a sentence; unknown ones too', () {
    for (final reason in RejectionReason.values) {
      expect(uploadRefusalText(reason.name), startsWith('Not ranked: '));
    }
    expect(
      uploadRefusalText('somethingNewer'),
      'Not ranked: the server could not check this game.',
    );
  });

  test('the reasons a player can act on are told apart', () {
    final specific = {
      for (final reason in [
        RejectionReason.levelsMismatch,
        RejectionReason.placementAfterGames,
        RejectionReason.notReplayable,
        RejectionReason.outOfOrder,
        RejectionReason.typeAlreadyPlayed,
      ])
        uploadRefusalText(reason.name),
    };
    expect(specific, hasLength(5));
    expect(
      specific,
      isNot(contains(uploadRefusalText(RejectionReason.badElapsed.name))),
    );
  });
}
