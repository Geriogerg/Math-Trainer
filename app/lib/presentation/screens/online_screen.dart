import 'package:material_ui/material_ui.dart';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/online_overview.dart';

import '../../composition_root.dart';
import '../../core/state/account_form_controller.dart';
import '../../core/state/online_controller.dart';
import '../duel/duel_flow_screen.dart';
import '../duel/duel_texts.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';
import 'save_progress_screen.dart';

/// The Online tab (`doc/mockups/online.html`, screen 1; plan v3.7): the
/// three duel modes with the player's rating in each, the challenges
/// "Waiting for you", and "Recent" duels. Online play needs a linked
/// account: a guest is invited to save their progress.
class OnlineScreen extends StatelessWidget {
  const OnlineScreen({
    super.key,
    required this.environment,
    required this.controller,
    this.friendsButton,
  });

  final AppEnvironment environment;

  /// `null` when the build has no server or no online reads: the tab says
  /// online play is not available.
  final OnlineController? controller;

  /// Top right: the Friends pill (commit 7).
  final Widget? friendsButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final controller = this.controller;
    return Padding(
      padding: metrics.rootPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Online', style: theme.textTheme.titleMedium),
              const Spacer(),
              ?friendsButton,
            ],
          ),
          Expanded(
            child: controller == null || environment.duelClient == null
                ? const _Message('Online play is not available in this build.')
                : ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => _content(context, controller),
                  ),
          ),
        ],
      ),
    );
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
          Text('Duels', style: section),
          const SizedBox(height: 6),
          for (final mode in DuelMode.values) ...[
            AppCard(
              key: ValueKey('duel-mode-${mode.name}'),
              label: duelModeLabel(mode),
              detail: () {
                final r = controller.rating(mode);
                return ratingText(r.rating, provisional: r.provisional);
              }(),
              onTap: () =>
                  _play(context, controller, (client) => client.find(mode)),
            ),
            const SizedBox(height: 6),
          ],
          if (overview.waiting.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Waiting for you', style: section),
            for (final challenge in overview.waiting)
              _Row(
                key: ValueKey('waiting-${challenge.duelId}'),
                label:
                    '${challenge.from ?? 'Player'} · '
                    '${duelModeLabel(challenge.mode)}',
                trailing: AppButton.primary(
                  label: 'Play',
                  compact: true,
                  onPressed: () => _play(
                    context,
                    controller,
                    (client) => client.open(challenge.duelId),
                  ),
                ),
              ),
          ],
          if (overview.recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Recent', style: section),
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
    final name = duel.opponent ?? 'Player';
    if (duel.kind == DuelKind.practice) {
      return 'Practice · ${duelModeLabel(duel.mode)}';
    }
    if (duel.raced && !duel.waiting) return '$name raced your run';
    return '$name · ${duelModeLabel(duel.mode)}';
  }
}

/// Won / lost / draw in words (rule 14), the win in the accent; "waiting"
/// for a challenge sent, "not counted" for a void duel.
class _RecentOutcome extends StatelessWidget {
  const _RecentOutcome({required this.duel});

  final RecentDuel duel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = duel.result;
    final word = duel.voided
        ? 'not counted'
        : duel.waiting
        ? 'waiting'
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
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
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
            'Duels need a saved account: save your progress — an email and '
            'a player name — to race other players.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          AppButton.primary(onPressed: onSave, label: 'Save your progress'),
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
        const Text('Could not load your duels.'),
        const SizedBox(height: 12),
        AppButton.secondary(label: 'Retry', onPressed: onRetry),
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
