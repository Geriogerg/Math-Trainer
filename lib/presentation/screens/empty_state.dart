import 'package:flutter/material.dart';

/// Replaces a `SizedBox.shrink()` as a screen state (`doc/design.md`): an
/// empty screen is a dead end, a message and an exit action are required.
/// Shared by `SessionScreen` and `SessionFlowScreen` — both branches it
/// covers are dead in practice (`SessionState` guarantees a non-null
/// `currentExercise` while `status == inProgress`), but what shows if they
/// were reached anyway must stay usable.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
