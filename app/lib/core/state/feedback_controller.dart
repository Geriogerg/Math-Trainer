import 'package:flutter/foundation.dart';
import 'package:math_core/feedback/feedback.dart';

enum FeedbackStatus { editing, sending, sent, failed, tooMany }

/// The feedback screen's state (Phase 3a commit 5). A failed send keeps the
/// text on screen: nothing is queued, the player simply sends again.
class FeedbackController extends ChangeNotifier {
  FeedbackController({required this.repository, required this.appVersion});

  final FeedbackRepository repository;

  /// The build's commit (`APP_VERSION`), stored with every message.
  final String appVersion;

  FeedbackStatus _status = FeedbackStatus.editing;
  FeedbackProblem? _problem;
  bool _disposed = false;

  FeedbackStatus get status => _status;
  FeedbackProblem? get problem => _problem;

  Future<void> send(String message) async {
    if (_status == FeedbackStatus.sending) return;
    final problem = feedbackProblem(message);
    if (problem != null) {
      _set(FeedbackStatus.editing, problem);
      return;
    }
    _set(FeedbackStatus.sending);
    try {
      final outcome = await repository.send(
        message: message.trim(),
        appVersion: appVersion,
      );
      _set(switch (outcome) {
        FeedbackOutcome.sent => FeedbackStatus.sent,
        FeedbackOutcome.tooMany => FeedbackStatus.tooMany,
      });
    } on Exception catch (_) {
      _set(FeedbackStatus.failed);
    }
  }

  void _set(FeedbackStatus status, [FeedbackProblem? problem]) {
    if (_disposed) return;
    _status = status;
    _problem = problem;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
