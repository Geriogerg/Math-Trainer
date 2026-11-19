import 'package:material_ui/material_ui.dart';
import 'package:math_core/leaderboard/leaderboard.dart';

import '../../composition_root.dart';
import '../../core/state/leaderboard_controller.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// The Leaderboard tab (plan 6.4, Phase 2 commit 8): a board per operation
/// and overall; by default the player's standing — "Top N %" and the five
/// players above and below — and the top 100 in a second view. Ranked on
/// the level; the score never ranks anyone.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.environment,
    this.isActive = true,
  });

  final AppEnvironment environment;

  /// Reloads when the tab is shown again (`IndexedStack` keeps it alive):
  /// a game played meanwhile may have moved the player.
  final bool isActive;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardController? _controller;

  @override
  void initState() {
    super.initState();
    final repository = widget.environment.leaderboardRepository;
    if (repository != null) {
      _controller = LeaderboardController(repository)..load().ignore();
    }
  }

  @override
  void didUpdateWidget(covariant LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _controller?.load().ignore();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);
    if (controller == null) {
      return Center(
        child: Text(
          'The leaderboard is not available in this build.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: theme.extension<AppMetrics>()!.rootPadding.copyWith(bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Leaderboard', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _BoardChips(
              selected: controller.board,
              onSelected: controller.selectBoard,
            ),
            const SizedBox(height: 12),
            SegmentedButton<LeaderboardView>(
              segments: const [
                ButtonSegment(
                  value: LeaderboardView.aroundMe,
                  label: Text('Around me'),
                ),
                ButtonSegment(
                  value: LeaderboardView.top,
                  label: Text('Top 100'),
                ),
              ],
              selected: {controller.view},
              onSelectionChanged: (s) => controller.selectView(s.single),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            Expanded(child: _content(controller, theme)),
          ],
        ),
      ),
    );
  }

  Widget _content(LeaderboardController controller, ThemeData theme) {
    if (controller.failed) {
      return EmptyState(
        message: 'Could not load the leaderboard.',
        actionLabel: 'Retry',
        onAction: () => controller.load().ignore(),
      );
    }
    final standing = controller.standing;
    final top = controller.top;
    if (standing == null || top == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (controller.view) {
      LeaderboardView.aroundMe => switch (standing) {
        Ranked() => _RankedView(standing: standing),
        NotRanked() => _NotRankedView(
          standing: standing,
          board: controller.board,
        ),
      },
      LeaderboardView.top =>
        top.isEmpty
            ? Center(
                child: Text(
                  'Nobody on this board yet.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            : _EntryList(entries: top),
    };
  }
}

String boardLabel(LeaderboardBoard board) =>
    board.type == null ? 'Overall' : exerciseTypeLabel(board.type!);

class _BoardChips extends StatelessWidget {
  const _BoardChips({required this.selected, required this.onSelected});

  final LeaderboardBoard selected;
  final ValueChanged<LeaderboardBoard> onSelected;

  /// Wrapped, like the Play tab's chips: on a phone a sideways-scrolling
  /// row would hide half the boards.
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final board in LeaderboardBoard.all)
          ChoiceChip(
            label: Text(boardLabel(board)),
            selected: board == selected,
            onSelected: (_) => onSelected(board),
          ),
      ],
    );
  }
}

class _RankedView extends StatelessWidget {
  const _RankedView({required this.standing});

  final Ranked standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Top ${standing.topPercent} %', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Rank ${standing.rank} of ${standing.total} · '
          'level ${standing.level.whole}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(child: _EntryList(entries: standing.neighbours)),
      ],
    );
  }
}

class _NotRankedView extends StatelessWidget {
  const _NotRankedView({required this.standing, required this.board});

  final NotRanked standing;
  final LeaderboardBoard board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = standing.sessionsNeeded;
    final games = n == 1 ? '1 more game' : '$n more games';
    final message = switch (standing.reason) {
      NotRankedReason.noSessions =>
        'Play a game to join the leaderboard. Your games count once they '
            'reach the server.',
      NotRankedReason.notEnoughSessions =>
        board.type == null
            ? 'Finish $games to join the overall board.'
            : '$games with ${boardLabel(board).toLowerCase()} to join this '
                  'board.',
      NotRankedReason.inactive =>
        'Play a game to appear again: the board shows players active in the '
            'last 30 days. Your level never drops while you are away.',
      NotRankedReason.notLinked =>
        'Save your progress to appear on the leaderboard.',
      NotRankedReason.signedOut ||
      NotRankedReason.other => 'You are not on this board yet.',
    };
    return Align(
      alignment: Alignment.topLeft,
      child: Text(message, style: theme.textTheme.bodyLarge),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: entries.length,
    itemBuilder: (context, i) => _EntryRow(entry: entries[i]),
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The player's own row: bold and labelled "You" — never by colour
    // alone (rule 14).
    final style = entry.isMe
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text('${entry.rank}', style: style)),
          Expanded(
            child: Text(
              entry.isMe
                  ? '${entry.name ?? 'Player'} (You)'
                  : entry.name ?? 'Player',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('Level ${entry.level.whole}', style: style),
        ],
      ),
    );
  }
}
