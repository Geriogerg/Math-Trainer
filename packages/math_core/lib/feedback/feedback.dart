// In-app feedback (plan v2.3, Phase 3a commit 5): a free text sent to the
// server with the app version, read by the owner.

/// Longest message the server stores (`feedback.message`, SQL).
const maxFeedbackLength = 2000;

enum FeedbackProblem { empty, tooLong }

/// Why [message] cannot be sent as is, or `null`. Same rule as the table's
/// check, after trimming.
FeedbackProblem? feedbackProblem(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return FeedbackProblem.empty;
  if (trimmed.length > maxFeedbackLength) return FeedbackProblem.tooLong;
  return null;
}

/// What the server did with a message. Names match `send_feedback()`.
enum FeedbackOutcome { sent, tooMany }

abstract interface class FeedbackRepository {
  /// Throws on network or server failure (nothing stored).
  Future<FeedbackOutcome> send({
    required String message,
    required String appVersion,
  });
}
