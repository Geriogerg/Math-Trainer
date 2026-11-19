import 'package:math_core/feedback/feedback.dart';
import 'package:test/test.dart';

void main() {
  test('empty after trimming, or longer than the server keeps', () {
    expect(feedbackProblem(''), FeedbackProblem.empty);
    expect(feedbackProblem(' \n\t '), FeedbackProblem.empty);
    expect(
      feedbackProblem('x' * (maxFeedbackLength + 1)),
      FeedbackProblem.tooLong,
    );
    // Surrounding spaces do not count (the server trims too).
    expect(feedbackProblem('  ${'x' * maxFeedbackLength}  '), isNull);
    expect(feedbackProblem('Roots feel slow.'), isNull);
  });
}
