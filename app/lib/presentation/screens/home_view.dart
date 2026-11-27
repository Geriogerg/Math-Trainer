// Home itself (mockup 1) and its first-run card: split out of play_tab.dart
// at Phase 6b's close (review m12: files that carry too much).
part of 'play_tab.dart';

/// Mockup 1. Labels only.
class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.mainLevel,
    required this.levelOf,
    required this.selectionOf,
    required this.onToggle,
    required this.onPlay,
    required this.onGetTheCount,
    required this.onChainOperations,
    required this.onTables,
    required this.onTips,
    this.weakSpotsDue,
    this.onWeakSpots,
    this.firstRun = false,
    this.onDismissFirstRun,
    this.onSignIn,
  });

  final int mainLevel;

  /// A level-0 guest's sign-in hint; `null`: none.
  final VoidCallback? onSignIn;

  /// The first-run card, until dismissed (Phase 6b commit 4).
  final bool firstRun;
  final VoidCallback? onDismissFirstRun;
  final int Function(ExerciseType type) levelOf;
  final Set<ExerciseType> Function(ExerciseFamily family) selectionOf;
  final ValueChanged<ExerciseType> onToggle;
  final ValueChanged<ExerciseFamily> onPlay;
  final VoidCallback? onGetTheCount;
  final VoidCallback? onChainOperations;
  final VoidCallback? onTables;
  final VoidCallback? onTips;

  /// Weak spots the player can practise now (Phase 4); `null`: unknown.
  final int? weakSpotsDue;
  final VoidCallback? onWeakSpots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return SingleChildScrollView(
      padding: metrics.rootPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.home.play,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              LevelBadge(level: mainLevel),
            ],
          ),
          Caption(strings.home.mainLevelCaption, textAlign: TextAlign.end),
          if (onSignIn case final signIn?) ...[
            const SizedBox(height: 8),
            Row(
              key: signInHintKey,
              children: [
                Expanded(child: Caption(strings.home.signInHint)),
                const SizedBox(width: 8),
                AppButton.secondary(
                  label: strings.common.signIn,
                  onPressed: signIn,
                ),
              ],
            ),
          ],
          if (firstRun) ...[
            const SizedBox(height: 12),
            _FirstRunCard(onDismiss: onDismissFirstRun),
          ],
          for (final family in ExerciseFamily.values) ...[
            _SectionLabel(strings.home.family(family)),
            Row(
              children: [
                for (final (i, type) in family.types.indexed) ...[
                  if (i > 0) SizedBox(width: metrics.keyGap * 1.5),
                  Expanded(
                    child: OperationButton(
                      type: type,
                      level: levelOf(type),
                      selected: selectionOf(family).contains(type),
                      onTap: () => onToggle(type),
                    ),
                  ),
                ],
              ],
            ),
            Caption(strings.home.familyCaption(family)),
            const SizedBox(height: 8),
            AppButton.primary(
              key: playButtonKey(family),
              label: strings.home.play,
              semanticLabel: strings.home.playFamily(family),
              compact: true,
              // Dimmed and inert until the row has a selection.
              onPressed: selectionOf(family).isEmpty
                  ? null
                  : () => onPlay(family),
            ),
          ],
          // Phase 4: the player's own weak spots, practice only.
          _SectionLabel(strings.home.practice),
          AppCard(
            key: weakSpotsCardKey,
            label: strings.home.weakSpots,
            caption: strings.home.weakSpotsCaption,
            detail: switch (weakSpotsDue) {
              null => null,
              final n => strings.home.weakSpotsDue(n),
            },
            onTap: (weakSpotsDue ?? 0) > 0 ? onWeakSpots : null,
          ),
          _SectionLabel(strings.home.challenges),
          AppCard(
            label: strings.home.getTheCount,
            caption: strings.home.getTheCountCaption,
            onTap: onGetTheCount,
          ),
          const SizedBox(height: 8),
          AppCard(
            label: strings.home.chainOperations,
            caption: strings.home.chainCaption,
            onTap: onChainOperations,
          ),
          const SizedBox(height: 8),
          // Its own card, under Challenges (`doc/levels.md`, section 7).
          AppCard(
            label: strings.home.tables,
            caption: strings.home.tablesCaption,
            onTap: onTables,
          ),
          const SizedBox(height: 8),
          // Reached from its own card (`doc/levels.md`, section 8).
          AppCard(
            label: strings.home.tips,
            caption: strings.home.tipsCaption,
            onTap: onTips,
          ),
        ],
      ),
    );
  }
}

/// What a newcomer needs before the first game (Phase 6b commit 4, review
/// M16): how a level moves, in three lines; gone once dismissed.
class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard({required this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return Container(
      key: firstRunCardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(metrics.radius * 0.75),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.home.firstRunTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(strings.home.firstRunLevels, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            strings.home.firstRunPractice,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(
              label: strings.common.gotIt,
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

/// The first-run card (tests find it by this key).
const firstRunCardKey = ValueKey('first-run-card');

/// A level-0 guest's sign-in hint (tests find it by this key).
const signInHintKey = ValueKey('sign-in-hint');

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // 20, not 24, since body text grew to 15 px (Phase 6b commit 6): the
      // setup pages keep Start in view on a 640 px phone.
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
