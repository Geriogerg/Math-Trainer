import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/feedback/feedback.dart';
import 'package:math_trainer/core/state/feedback_controller.dart';

class _Repository implements FeedbackRepository {
  _Repository(this.answer);
  Future<FeedbackOutcome> Function() answer;
  final sent = <(String, String)>[];

  @override
  Future<FeedbackOutcome> send({
    required String message,
    required String appVersion,
  }) {
    sent.add((message, appVersion));
    return answer();
  }
}

void main() {
  FeedbackController make(_Repository repository) {
    final controller = FeedbackController(
      repository: repository,
      appVersion: 'a1b2c3d',
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('sends the trimmed text with the app version', () async {
    final repository = _Repository(() async => FeedbackOutcome.sent);
    final controller = make(repository);
    await controller.send('  Roots feel slow.\n');
    expect(repository.sent, [('Roots feel slow.', 'a1b2c3d')]);
    expect(controller.status, FeedbackStatus.sent);
  });

  test('blank: a problem, nothing sent', () async {
    final repository = _Repository(() async => FeedbackOutcome.sent);
    final controller = make(repository);
    await controller.send('   ');
    expect(controller.problem, FeedbackProblem.empty);
    expect(controller.status, FeedbackStatus.editing);
    expect(repository.sent, isEmpty);
  });

  test('offline, then sent on the next try', () async {
    final repository = _Repository(() async => throw Exception('offline'));
    final controller = make(repository);
    await controller.send('Hello');
    expect(controller.status, FeedbackStatus.failed);
    repository.answer = () async => FeedbackOutcome.sent;
    await controller.send('Hello');
    expect(controller.status, FeedbackStatus.sent);
  });

  test('the daily cap is its own status', () async {
    final controller = make(_Repository(() async => FeedbackOutcome.tooMany));
    await controller.send('Again');
    expect(controller.status, FeedbackStatus.tooMany);
  });
}
