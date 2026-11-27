import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/online_overview.dart';

import '../../composition_root.dart';
import '../../core/state/account_form_controller.dart';
import '../../core/state/online_controller.dart';
import '../duel/duel_flow_screen.dart';
import '../duel/duel_rules.dart';
import 'package:math_trainer/presentation/strings/duel_texts.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';
import 'friends_screen.dart';
import 'save_progress_screen.dart';

/// The Online tab (`doc/mockups/online.html`, screen 1; plan v3.7): the
/// three duel modes with the player's rating in each, the challenges
/// "Waiting for you", and "Recent" duels; Friends top right. Online play
/// needs a linked account: a guest is invited to save their progress.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({
    super.key,
    required this.environment,
    required this.controller,
  });

  final AppEnvironment environment;

  /// `null` when the build has no server or no online reads: the tab says
  /// online play is not available.
  final OnlineController? controller;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant OnlineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onChanged);
      widget.controller?.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onChanged);
    super.dispose();
  }

  /// The invite link is handled by the shell (Phase 6a: asked on any
  /// tab); this screen only rebuilds.
  void _onChanged() {}

  AppEnvironment get environment => widget.environment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final controller = widget.controller;
    if (controller == null || environment.duelClient == null) {
      return Padding(
        padding: metrics.rootPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.online.online, style: theme.textTheme.titleMedium),
            Expanded(child: _Message(strings.online.notAvailable)),
          ],
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final overview = controller.overview;
        return Padding(
          padding: metrics.rootPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    strings.online.online,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (environment.friendsRepository != null &&
                      (overview?.linked ?? false))
                    _FriendsPill(
                      requests: overview!.friendRequests,
                      onTap: () => _openFriends(context, controller),
                    ),
                ],
              ),
              Expanded(child: _content(context, controller)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFriends(
    BuildContext context,
    OnlineController controller,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FriendsScreen(environment: environment),
      ),
    );
    controller.load().ignore();
  }

  Widget _content(BuildContext context, OnlineController controller) {
    final overview = controller.overview;
    if (overview == null) {
      if (controller.failed) {
        return _Retry(onRetry: controller.load);
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (!overview.linked) {
      return _GuestInvite(onSave: () => _saveProgress(context, controller));
    }
    final theme = Theme.of(context);
    final section = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        children: [
          const SizedBox(height: 12),
          Text(strings.online.duels, style: section),
          // After each mode's first rated duel, no sheet: this line, and
          // the full rules one tap away (plan v4.1).
          const DuelReminder(),
          const SizedBox(height: 6),
          for (final mode in DuelMode.values) ...[
            AppCard(
              key: ValueKey('duel-mode-${mode.name}'),
              label: duelModeLabel(mode),
              detail: () {
                final r = controller.rating(mode);
                return ratingText(r.rating, provisional: r.provisional);
              }(),
              caption: duelModeRule(mode),
              onTap: () async {
                // The rules before the first rated duel of the mode
                // (review M15; plan v4.1: once per mode).
                if (!await confirmDuel(
                  context,
                  mode,
                  hints: environment.hints,
                )) {
                  return;
                }
                if (!context.mounted) return;
                await _play(context, controller, (client) => client.find(mode));
              },
            ),
            const SizedBox(height: 6),
          ],
          if (overview.waiting.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(strings.online.waitingForYou, style: section),
            for (final challenge in overview.waiting)
              _Row(
                key: ValueKey('waiting-${challenge.duelId}'),
                label: strings.online.challengeFrom(
                  challenge.from ?? strings.common.player,
                  duelModeLabel(challenge.mode),
                ),
                trailing: AppButton.primary(
                  label: strings.online.play,
                  compact: true,
                  onPressed: () async {
                    if (!await confirmDuel(
                      context,
                      challenge.mode,
                      hints: environment.hints,
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                    await _play(
                      context,
                      controller,
                      (client) => client.open(challenge.duelId),
                    );
                  },
                ),
              ),
          ],
          if (overview.recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(strings.online.recent, style: section),
            for (final duel in overview.recent)
              _Row(
                key: ValueKey('recent-${duel.duelId}'),
                label: _recentLabel(duel),
                trailing: _RecentOutcome(duel: duel),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _play(
    BuildContext context,
    OnlineController controller,
    Future<DuelOffer> Function(DuelClient client) load,
  ) async {
    final client = environment.duelClient;
    if (client == null) return;
    await playDuel(context, environment, () => load(client));
    controller.load().ignore();
  }

  Future<void> _saveProgress(
    BuildContext context,
    OnlineController controller,
  ) async {
    await Navigator.of(context).push<SaveProgressOutcome>(
      MaterialPageRoute(
        builder: (_) => SaveProgressScreen(
          accountRepository: environment.accountRepository,
          profileRepository: environment.profileRepository,
          initialDisplayName: '',
          guestHasProgress: true,
        ),
      ),
    );
    controller.load().ignore();
  }

  /// The mockup's words: "Tom raced your run", "Practice · Advanced",
  /// "Léa · Basics".
  static String _recentLabel(RecentDuel duel) {
    final name = duel.opponent ?? strings.common.player;
    if (duel.kind == DuelKind.practice) {
      return strings.online.practiceDuel(duelModeLabel(duel.mode));
    }
    if (duel.raced && !duel.waiting) return strings.online.racedYourRun(name);
    return strings.online.duelWith(name, duelModeLabel(duel.mode));
  }
}

/// Won / lost / draw in words (rule 14), the win in the accent; "waiting"
/// for a challenge sent, "not counted" for a void duel.
/// The mockup's Friends pill, with a dot when requests wait — and the
/// count in its words for screen readers (rule 14).
class _FriendsPill extends StatelessWidget {
  const _FriendsPill({required this.requests, required this.onTap});

  final int requests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: strings.online.friendsPill(requests),
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('friends-pill'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.online.friends,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (requests > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOutcome extends StatelessWidget {
  const _RecentOutcome({required this.duel});

  final RecentDuel duel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = duel.result;
    final word = duel.voided
        ? strings.online.notCountedLower
        : duel.waiting
        ? strings.online.waitingLower
        : result == null
        ? ''
        : resultWord(result).toLowerCase();
    return Text(
      word,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: result == 1
            ? theme.colorScheme.primary
            : theme.extension<AppPalette>()!.textMuted,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _GuestInvite extends StatelessWidget {
  const _GuestInvite({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.online.needsAccount,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          AppButton.primary(
            onPressed: onSave,
            label: strings.online.saveYourProgress,
          ),
        ],
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(strings.online.couldNotLoad),
        const SizedBox(height: 12),
        AppButton.secondary(label: strings.common.retry, onPressed: onRetry),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: Theme.of(context).textTheme.bodyLarge));
}
