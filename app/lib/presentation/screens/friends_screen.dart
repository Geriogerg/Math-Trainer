import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/friends/friends.dart';

import '../../composition_root.dart';
import '../../core/state/friends_controller.dart';
import '../duel/duel_flow_screen.dart';
import '../duel/duel_rules.dart';
import '../duel/duel_texts.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';

/// What a request by code did, in words.
String friendRequestText(FriendRequestOutcome outcome) => switch (outcome) {
  FriendRequestOutcome.sent => 'Request sent.',
  FriendRequestOutcome.friends => 'You are now friends.',
  FriendRequestOutcome.already => 'Already friends.',
  FriendRequestOutcome.pending => 'Request already sent.',
  FriendRequestOutcome.unknown => 'No player has this code.',
  FriendRequestOutcome.self => 'That is your own code.',
  FriendRequestOutcome.tooMany => 'Too many requests today.',
  FriendRequestOutcome.other => 'Could not send the request.',
};

/// An accept, a decline or a removal that did not go through.
const friendActionFailedText = 'Could not reach the server — try again.';

/// The Friends page (`doc/mockups/online.html`, screen 4): the player's
/// code, Share link and Add code, the requests waiting, the friends with
/// the head-to-head and a Challenge button. A friend's row opens the
/// history of duels between them.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendsController _controller = FriendsController(
    widget.environment.friendsRepository!,
  )..load().ignore();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Accept or Decline, and a line when it did not go through (Phase 6b
  /// commit 5, review M18).
  Future<void> _respond(FriendRequest request, {required bool accept}) async {
    if (!await _controller.respond(request, accept: accept) && mounted) {
      _say(friendActionFailedText);
    }
  }

  /// The phone's share sheet where the browser has one (plan v3.8), the
  /// clipboard otherwise.
  Future<void> _share(String code) async {
    final site = widget.environment.siteUrl;
    final sharer = widget.environment.linkSharer;
    if (site != null && sharer != null) {
      final link = inviteLink(site, code);
      if (await sharer.share(title: 'Math Trainer', link: link)) return;
    }
    final text = site == null ? code : '${inviteLink(site, code)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _say('Link copied');
  }

  /// A new code: the old one and its links stop working — asked first.
  Future<void> _newCode() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Get a new code?'),
        content: const Text(
          'Your current code and the links you shared stop working. Your '
          'friends stay.',
        ),
        actions: [
          AppButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: 'New code',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    if (!await _controller.newCode() && mounted) {
      _say('Could not get a new code — try again.');
    }
  }

  Future<void> _addCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCodeDialog(),
    );
    if (code == null || !mounted) return;
    final normalized = normalizeFriendCode(code);
    if (normalized == null) {
      _say(friendRequestText(FriendRequestOutcome.unknown));
      return;
    }
    _say(friendRequestText(await _controller.add(normalized)));
  }

  Future<void> _challenge(Friend friend) async {
    final client = widget.environment.duelClient;
    if (client == null) return;
    final mode = await pickDuelMode(context);
    if (mode == null || !mounted) return;
    // The rules first, as from Online (Phase 6b commit 5: commit 4 left
    // this path out).
    if (!await confirmDuel(context, mode) || !mounted) return;
    await playDuel(
      context,
      widget.environment,
      () => client.find(mode, challenge: friend.id),
    );
    _controller.load().ignore();
  }

  Future<void> _history(Friend friend) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => FriendHistoryScreen(
        friend: friend,
        repository: widget.environment.friendsRepository!,
        onRemove: () => _controller.remove(friend),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final section = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Friends'), centerTitle: true),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final code = _controller.code;
            final friends = _controller.friends;
            if (friends == null || code == null) {
              return Center(
                child: _controller.failed
                    ? AppButton.secondary(
                        label: 'Retry',
                        onPressed: _controller.load,
                      )
                    : const CircularProgressIndicator(),
              );
            }
            return ListView(
              padding: metrics.rootPadding,
              children: [
                _CodeCard(code: code),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Share link',
                        onPressed: () => _share(code),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Add code',
                        onPressed: _addCode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppButton.secondary(label: 'New code', onPressed: _newCode),
                if (_controller.incoming.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Requests', style: section),
                  for (final request in _controller.incoming)
                    _Line(
                      key: ValueKey('request-${request.fromId}'),
                      label: Text(request.name ?? 'Player'),
                      actions: [
                        AppButton.secondary(
                          label: 'Decline',
                          onPressed: () => _respond(request, accept: false),
                        ),
                        const SizedBox(width: 6),
                        AppButton.primary(
                          label: 'Accept',
                          compact: true,
                          onPressed: () => _respond(request, accept: true),
                        ),
                      ],
                    ),
                ],
                const SizedBox(height: 12),
                Text('Friends', style: section),
                if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Share your link or add a friend\'s code.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                for (final friend in friends)
                  _Line(
                    key: ValueKey('friend-${friend.id}'),
                    onTap: () => _history(friend),
                    label: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${friend.name ?? 'Player'} '),
                          TextSpan(
                            text: '${friend.wins}–${friend.losses}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ).digits,
                          ),
                        ],
                      ),
                      semanticsLabel:
                          '${friend.name ?? 'Player'}, '
                          '${friend.wins} wins, ${friend.losses} losses',
                    ),
                    actions: [
                      AppButton.secondary(
                        label: 'Challenge',
                        onPressed: () => _challenge(friend),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Owns its text field's controller: disposed with the dialog, after its
/// closing animation (disposing it on pop broke that animation).
class _AddCodeDialog extends StatefulWidget {
  const _AddCodeDialog();

  @override
  State<_AddCodeDialog> createState() => _AddCodeDialogState();
}

class _AddCodeDialogState extends State<_AddCodeDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add code'),
    content: TextField(
      controller: _field,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(hintText: 'MATH-7K2P-QX4M'),
      onSubmitted: (text) => Navigator.of(context).pop(text),
    ),
    actions: [
      AppButton.secondary(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      AppButton.secondary(
        label: 'Add',
        onPressed: () => Navigator.of(context).pop(_field.text),
      ),
    ],
  );
}

/// The mode of a challenge: the three, as on the Online tab.
Future<DuelMode?> pickDuelMode(BuildContext context) =>
    showModalBottomSheet<DuelMode>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in DuelMode.values) ...[
                AppCard(
                  label: duelModeLabel(mode),
                  onTap: () => Navigator.of(sheetContext).pop(mode),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: Column(
        children: [
          Text(
            'Your code',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(
            code,
            key: const ValueKey('friend-code'),
            style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.label,
    required this.actions,
    this.onTap,
  });

  final Widget label;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
                child: label,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// The duels between the player and one friend (plan v3.7): date, mode,
/// both scores, the result; and Remove friend.
class FriendHistoryScreen extends StatefulWidget {
  const FriendHistoryScreen({
    super.key,
    required this.friend,
    required this.repository,
    required this.onRemove,
  });

  final Friend friend;
  final FriendsRepository repository;

  /// `false` when the removal did not go through: the page stays, and says
  /// so.
  final Future<bool> Function() onRemove;

  @override
  State<FriendHistoryScreen> createState() => _FriendHistoryScreenState();
}

class _FriendHistoryScreenState extends State<FriendHistoryScreen> {
  late Future<List<FriendDuel>> _history = widget.repository.history(
    widget.friend.id,
  );

  Future<void> _remove() async {
    final name = widget.friend.name ?? 'this player';
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        actions: [
          AppButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.secondary(
            label: 'Remove',
            destructive: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final removed = await widget.onRemove();
    if (!mounted) return;
    if (removed) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(friendActionFailedText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final friend = widget.friend;
    return Scaffold(
      appBar: AppBar(title: Text(friend.name ?? 'Player'), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder<List<FriendDuel>>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: AppButton.secondary(
                  label: 'Retry',
                  onPressed: () => setState(() {
                    _history = widget.repository.history(friend.id);
                  }),
                ),
              );
            }
            final duels = snapshot.data;
            if (duels == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: metrics.rootPadding,
              children: [
                Text(
                  '${friend.wins}–${friend.losses}'
                  '${friend.draws > 0 ? ' · ${friend.draws} drawn' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.digits,
                ),
                const SizedBox(height: 12),
                if (duels.isEmpty)
                  Text(
                    'No duel yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                for (final duel in duels)
                  _Line(
                    key: ValueKey('history-${duel.duelId}'),
                    label: Text(
                      '${_date(duel.at)} · ${duelModeLabel(duel.mode)} · '
                      '${_score(duel)}',
                    ),
                    actions: [
                      Text(
                        resultWord(duel.result).toLowerCase(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: duel.result == 1
                              ? theme.colorScheme.primary
                              : theme.extension<AppPalette>()!.textMuted,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Center(
                  child: AppButton.secondary(
                    label: 'Remove friend',
                    destructive: true,
                    onPressed: _remove,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    return '${local.day}/${local.month}';
  }

  /// "7–6" (questions) or "3–5" (distance): the player's first.
  static String _score(FriendDuel duel) {
    final you = duel.you?.points;
    final them = duel.them?.points;
    return '${you ?? '–'}–${them ?? '–'}';
  }
}
