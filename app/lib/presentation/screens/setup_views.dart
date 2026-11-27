// The setup pages — a game's, Chain operations', Tables mode's: split out of
// play_tab.dart at Phase 6b's close (review m12).
part of 'play_tab.dart';

/// Mockup 2: back, the selected operators as the title, Questions, Mode,
/// the difficulty in Training only, Start at the bottom.
class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.types,
    required this.setup,
    required this.onChanged,
    required this.onBack,
    required this.onStart,
    required this.isStarting,
    required this.startError,
  });

  final Set<ExerciseType> types;
  final GameSetup setup;
  final ValueChanged<GameSetup Function(GameSetup)> onChanged;
  final VoidCallback onBack;
  final VoidCallback? onStart;
  final bool isStarting;
  final String? startError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final title = [
      for (final type in types.toList()..sort((a, b) => a.index - b.index))
        operatorSymbol(type),
    ].join(' ');
    // Scrolls only when large text needs it; Start otherwise sits at the
    // bottom.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: strings.common.back,
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    // Balances the back button: the title stays centred.
                    const SizedBox(width: 48),
                  ],
                ),
                _SectionLabel(strings.home.questions),
                SegmentedChoice<int>(
                  values: questionsPerOperationChoices,
                  selected: setup.questionsPerOperation,
                  label: (n) => '$n',
                  onChanged: (n) =>
                      onChanged((s) => s.copyWith(questionsPerOperation: n)),
                ),
                Caption(
                  strings.home.questionsCaption(
                    setup.questionsPerOperation,
                    types.length,
                  ),
                ),
                _SectionLabel(strings.home.mode),
                SegmentedChoice<GameMode>(
                  values: GameMode.values,
                  selected: setup.mode,
                  label: strings.home.modeLabel,
                  onChanged: (mode) => onChanged((s) => s.copyWith(mode: mode)),
                ),
                Caption(strings.home.modeCaption(setup.mode)),
                if (setup.mode == GameMode.training) ...[
                  const SizedBox(height: 8),
                  SegmentedChoice<TrainingDifficulty>(
                    values: TrainingDifficulty.values,
                    selected: setup.difficulty,
                    label: strings.home.difficulty,
                    onChanged: (difficulty) =>
                        onChanged((s) => s.copyWith(difficulty: difficulty)),
                  ),
                  Caption(strings.home.difficultyCaption),
                ],
                const Spacer(),
                const SizedBox(height: 24),
                if (startError case final error?) ...[
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                AppButton.primary(
                  label: strings.common.start,
                  onPressed: onStart,
                  busy: isStarting,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The chain's setup page (mockup 2's layout): seconds per screen and the
/// number of operations, then Start.
class _ChainSetupView extends StatelessWidget {
  const _ChainSetupView({
    required this.seconds,
    required this.operations,
    required this.onSeconds,
    required this.onOperations,
    required this.onBack,
    required this.onStart,
  });

  final int seconds;
  final int operations;
  final ValueChanged<int> onSeconds;
  final ValueChanged<int> onOperations;
  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: strings.common.back,
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        strings.home.chainOperations,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                _SectionLabel(strings.home.seconds),
                SegmentedChoice<int>(
                  values: chainSecondsChoices,
                  selected: seconds,
                  label: (s) => '$s',
                  onChanged: onSeconds,
                ),
                _SectionLabel(strings.home.operations),
                SegmentedChoice<int>(
                  values: chainOperationChoices,
                  selected: operations,
                  label: (n) => '$n',
                  onChanged: onOperations,
                ),
                const Spacer(),
                const SizedBox(height: 24),
                AppButton.primary(
                  label: strings.common.start,
                  onPressed: onStart,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tables mode's setup page (`doc/levels.md`, section 7): which tables (a
/// range within 1–50), multipliers 1–10 or 1–20, how many questions, then
/// Start. Labels only.
class _TablesSetupView extends StatelessWidget {
  const _TablesSetupView({
    required this.setup,
    required this.onChanged,
    required this.onBack,
    required this.onStart,
  });

  final TablesSetup setup;
  final void Function(TablesSetup Function(TablesSetup)) onChanged;
  final VoidCallback onBack;
  final VoidCallback onStart;

  /// The first table moves the last along when it passes it, and back.
  static TablesSetup _first(TablesSetup s, int first) => s.copyWith(
    firstTable: first,
    lastTable: s.lastTable < first ? first : s.lastTable,
  );

  static TablesSetup _last(TablesSetup s, int last) => s.copyWith(
    lastTable: last,
    firstTable: s.firstTable > last ? last : s.firstTable,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: strings.common.back,
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        strings.home.tables,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                _SectionLabel(strings.home.from),
                _TableStepper(
                  key: const ValueKey('tables-from'),
                  value: setup.firstTable,
                  label: strings.home.from,
                  onChanged: (v) => onChanged((s) => _first(s, v)),
                ),
                _SectionLabel(strings.home.to),
                _TableStepper(
                  key: const ValueKey('tables-to'),
                  value: setup.lastTable,
                  label: strings.home.to,
                  onChanged: (v) => onChanged((s) => _last(s, v)),
                ),
                _SectionLabel(strings.home.multipliers),
                SegmentedChoice<int>(
                  values: tablesMultiplierChoices,
                  selected: setup.maxMultiplier,
                  label: (m) => '1–$m',
                  onChanged: (m) =>
                      onChanged((s) => s.copyWith(maxMultiplier: m)),
                ),
                _SectionLabel(strings.home.questions),
                SegmentedChoice<int>(
                  values: tablesQuestionChoices,
                  selected: setup.questions,
                  label: (n) => '$n',
                  onChanged: (n) => onChanged((s) => s.copyWith(questions: n)),
                ),
                const Spacer(),
                const SizedBox(height: 24),
                AppButton.primary(
                  label: strings.common.start,
                  onPressed: onStart,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A table number in [tablesMin, tablesMax]: − and + (48 dp each), the value
/// between them in the digit face. Screen readers hear "From 12".
class _TableStepper extends StatelessWidget {
  const _TableStepper({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: strings.home.stepDown(label),
          onPressed: value > tablesMin ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 88,
          child: Text(
            '$value',
            semanticsLabel: strings.home.stepValue(label, value),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.digits,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: strings.home.stepUp(label),
          onPressed: value < tablesMax ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
