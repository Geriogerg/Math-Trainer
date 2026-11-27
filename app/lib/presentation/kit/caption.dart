import 'package:material_ui/material_ui.dart';

import 'app_button.dart';

/// One line saying what a control does (Phase 6b commit 4, review M16:
/// "minimal text" relaxed for strangers — one line under each Home and
/// setup control, no more). Quiet: the control stays the thing to read.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        textAlign: textAlign,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A short sheet of rules with Cancel and [confirm] (Phase 6b commit 4):
/// `true` when the player goes on. [confirm] `null`: a single OK.
Future<bool> showRules(
  BuildContext context, {
  required String title,
  required List<String> lines,
  String? confirm = 'Start',
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line),
            ),
        ],
      ),
      actions: [
        if (confirm != null)
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: 'Cancel',
          ),
        AppButton.secondary(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          label: confirm ?? 'OK',
        ),
      ],
    ),
  );
  return go ?? false;
}
