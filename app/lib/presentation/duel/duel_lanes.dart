import 'package:material_ui/material_ui.dart';

import '../../core/state/duel_controller.dart';
import '../theme/app_theme.dart';

/// The two lanes of a duel (`doc/mockups/online.html`, screen 2): "You"
/// and the opponent's name, each a track and a number — correct answers,
/// or the distance to the target. The opponent's lane is their recorded
/// run at its own pace. Never colour alone (rule 14): each lane is named.
class DuelLanes extends StatelessWidget {
  const DuelLanes({
    super.key,
    required this.mine,
    required this.theirs,
    required this.opponentName,
  });

  final LaneProgress mine;

  /// `null`: nobody to race yet (a challenger plays first).
  final LaneProgress? theirs;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theirs = this.theirs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Lane(
          key: const ValueKey('lane-you'),
          label: 'You',
          progress: mine,
          color: scheme.primary,
        ),
        if (theirs != null)
          _Lane(
            key: const ValueKey('lane-them'),
            label: opponentName,
            progress: theirs,
            color: scheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    super.key,
    required this.label,
    required this.progress,
    required this.color,
  });

  final String label;
  final LaneProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 7,
                backgroundColor: theme.colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              '${progress.value}',
              textAlign: TextAlign.right,
              style: style?.digits,
            ),
          ),
        ],
      ),
    );
  }
}
