import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';
import 'package:math_core/leaderboard/leaderboard.dart';

import '../duel/duel_texts.dart';
import '../number_format.dart';

import '../../composition_root.dart';
import '../../core/state/account_form_controller.dart';
import '../../core/state/leaderboard_controller.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'save_progress_screen.dart';

/// The Leaderboard tab (plan 6.4, Phase 2 commit 8): a board per operation
/// and the main board; by default the player's standing — "Top N %" and the five
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
        Ranked() => _RankedView(standing: standing, onReport: _report),
        NotRanked() => _NotRankedView(
          standing: standing,
          board: controller.board,
          onSaveProgress: _saveProgress,
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
            : _EntryList(entries: top, onReport: _report),
    };
  }

  /// A guest is not on the boards (only linked players are, plan 6.3):
  /// the same "Save your progress" as Profile, then the board again —
  /// same account id, so their place shows at once.
  Future<void> _saveProgress() async {
    final environment = widget.environment;
    final outcome = await Navigator.of(context).push<SaveProgressOutcome>(
      MaterialPageRoute(
        builder: (_) => SaveProgressScreen(
          accountRepository: environment.accountRepository,
          profileRepository: environment.profileRepository,
          initialDisplayName: '',
          guestHasProgress: true,
        ),
      ),
    );
    if (!mounted || outcome == null) return;
    _controller?.load().ignore();
    if (outcome == SaveProgressOutcome.saved ||
        outcome == SaveProgressOutcome.savedWithoutName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress saved to your account.')),
      );
    }
  }

  /// Confirm, report, say so. Names are public content (plan 6.4). Only a
  /// saved account reports (plan v3.9): a guest is told how.
  Future<void> _report(LeaderboardEntry entry) async {
    final controller = _controller!;
    final account = await widget.environment.accountRepository.authState.first;
    if (!mounted) return;
    if (account == null || account.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save your progress to report a name.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Report "${entry.name}"?'),
        content: const Text(
          'Report a name that is offensive or impersonates someone. A '
          'reported name is hidden until it is reviewed.',
        ),
        actions: [
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: 'Cancel',
          ),
          AppButton.primary(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: 'Report',
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final sent = await controller.report(entry);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent ? 'Reported — thank you.' : 'Could not send the report.',
        ),
      ),
    );
  }
}

String boardLabel(LeaderboardBoard board) => switch ((board.type, board.duel)) {
  (final type?, _) => exerciseTypeLabel(type),
  (_, final mode?) => duelModeLabel(mode),
  _ => 'Main',
};

/// A duel board's chip mark: the Online tab's icon, so "Basics" the duel
/// board never reads as the main board (rule 14: an icon and a word).
const duelBoardIcon = Icons.bolt;

class _BoardChips extends StatelessWidget {
  const _BoardChips({required this.selected, required this.onSelected});

  final LeaderboardBoard selected;
  final ValueChanged<LeaderboardBoard> onSelected;

  /// One line that scrolls sideways (owner, Phase 2 report): wrapped, the
  /// eight boards took three lines on a phone and pushed the board itself
  /// down. The chip cut off at the edge shows there is more.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, board) in LeaderboardBoard.all.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            TypeChip(
              leading: switch ((board.type, board.duel)) {
                (final type?, _) => OperatorIcon(type),
                (_, _?) => const Icon(duelBoardIcon, size: 18),
                _ => null,
              },
              label: boardLabel(board),
              selected: board == selected,
              onSelected: (_) => onSelected(board),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankedView extends StatelessWidget {
  const _RankedView({required this.standing, required this.onReport});

  final Ranked standing;
  final ValueChanged<LeaderboardEntry> onReport;

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
          '${switch ((standing.level, standing.rating)) {
            (final level?, _) => 'level ${level.whole}',
            (_, final rating?) => 'rating ${groupedNumber(rating)}',
            _ => '',
          }}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _EntryList(entries: standing.neighbours, onReport: onReport),
        ),
      ],
    );
  }
}

class _NotRankedView extends StatelessWidget {
  const _NotRankedView({
    required this.standing,
    required this.board,
    required this.onSaveProgress,
  });

  final NotRanked standing;
  final LeaderboardBoard board;
  final VoidCallback onSaveProgress;

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
            ? 'Finish $games to join the main board.'
            : '$games with ${boardLabel(board).toLowerCase()} to join this '
                  'board.',
      NotRankedReason.inactive when board.isDuel =>
        'Play a rated duel to appear again: the board shows players active '
            'in the last 30 days.',
      NotRankedReason.inactive =>
        'Play a game to appear again: the board shows players active in the '
            'last 30 days. Your level never drops while you are away.',
      NotRankedReason.noDuels => 'Play a duel in this mode to join its board.',
      NotRankedReason.provisional =>
        n == 1
            ? '1 more rated duel to join this board.'
            : '$n more rated duels to join this board.',
      NotRankedReason.notLinked =>
        'The leaderboard shows players who saved their progress. Save '
            'yours — an email and a player name — to take your place.',
      NotRankedReason.signedOut ||
      NotRankedReason.other => 'You are not on this board yet.',
    };
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: theme.textTheme.bodyLarge),
          if (standing.reason == NotRankedReason.notLinked) ...[
            const SizedBox(height: 16),
            AppButton.primary(
              onPressed: onSaveProgress,
              label: 'Save your progress',
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.onReport});

  final List<LeaderboardEntry> entries;
  final ValueChanged<LeaderboardEntry> onReport;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: entries.length,
    itemBuilder: (context, i) =>
        _EntryRow(entry: entries[i], onReport: onReport),
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onReport});

  final LeaderboardEntry entry;
  final ValueChanged<LeaderboardEntry> onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The player's own row: weight 500 (the design's two weights: 400 and
    // 500, never 700) and labelled "You" — never by colour alone (rule 14).
    final style = entry.isMe
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)
        : theme.textTheme.bodyLarge;
    // A fixed height: rows with and without a report button line up.
    return SizedBox(
      height: 44,
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
          switch ((entry.level, entry.rating)) {
            (final level?, _) => LevelBadge(level: level.whole),
            (_, final rating?) => Text(
              groupedNumber(rating),
              style: style?.digits,
            ),
            _ => const SizedBox.shrink(),
          },
          // Another player's chosen name can be reported; a nameless row
          // ("Player") or one's own cannot.
          SizedBox(
            width: 40,
            child: entry.isMe || entry.name == null || entry.playerId == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    tooltip: 'Report name',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onReport(entry),
                  ),
          ),
        ],
      ),
    );
  }
}
