import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import '../kit/kit.dart';
import 'package:math_core/feedback/feedback.dart';

import '../../core/state/feedback_controller.dart';
import '../theme/app_theme.dart';

/// The beta's feedback field (Phase 3a commit 5), opened from Profile. One
/// free text; the app version goes with it, the player never types it.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.controller});

  final FeedbackController controller;

  static String? messageFor(FeedbackController controller) =>
      switch (controller.status) {
        FeedbackStatus.failed => strings.profile.feedbackOffline,
        FeedbackStatus.tooMany => strings.profile.feedbackTooMany,
        FeedbackStatus.editing => switch (controller.problem) {
          FeedbackProblem.empty => strings.profile.feedbackEmpty,
          FeedbackProblem.tooLong => strings.profile.feedbackTooLong(
            maxFeedbackLength,
          ),
          null => null,
        },
        FeedbackStatus.sending || FeedbackStatus.sent => null,
      };

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: Text(strings.profile.feedbackTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.status == FeedbackStatus.sent) {
              return Center(
                child: Padding(
                  padding: theme.extension<AppMetrics>()!.rootPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.profile.feedbackSent,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AppButton.primary(
                        onPressed: () => Navigator.of(context).pop(),
                        label: strings.common.back,
                      ),
                    ],
                  ),
                ),
              );
            }
            final sending = controller.status == FeedbackStatus.sending;
            return ListView(
              padding: theme.extension<AppMetrics>()!.rootPadding,
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  enabled: !sending,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: maxFeedbackLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.profile.yourMessage,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    errorText: FeedbackScreen.messageFor(controller),
                  ),
                ),
                const SizedBox(height: 16),
                AppButton.primary(
                  onPressed: sending
                      ? null
                      : () => controller.send(_text.text).ignore(),
                  label: sending
                      ? strings.profile.sending
                      : strings.profile.send,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
