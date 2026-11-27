// The builders of every game's controller (a game, Training, Tables, weak
// spots, drills, duels) and the weak-spot schedule: split out of
// composition_root.dart at Phase 6b's close (review m12). Still the
// composition root: the only place choosing implementations (rule 15).
part of 'composition_root.dart';

/// Builds a `SessionController` ready to play [enabledTypes] (chosen on
/// `PlayTab`) under the current rules (`doc/levels.md`): a fresh seed, the
/// type order of [setup] (every operation `questionsPerOperation` times,
/// shuffled by the seed and stored with the session), and the levels it is
/// generated at, frozen.
///
/// Levelling (the default): the player's levels, 0 for an operation never
/// played — read after the server's when every local session is settled.
/// Training: [setup]'s fixed difficulty for every operation, no level
/// update.
Future<SessionController> buildSessionController(
  AppEnvironment environment,
  Set<ExerciseType> enabledTypes, {
  GameSetup? setup,
}) async {
  final plan = setup ?? GameSetup();
  if (plan.mode == GameMode.training) {
    return _controllerFor(
      environment,
      enabledTypes,
      plan,
      levels: {for (final t in enabledTypes) t: plan.difficulty.level},
      kind: SessionKind.training,
      levelUpdates: const NoLevelUpdates(),
    );
  }
  // A game starts from the server's levels when every local session is
  // settled: after a game on another device, the local ones are behind and
  // this game would be refused (plan v2.3, Phase 3a commit 2). At most 2 s;
  // offline or pending uploads → the local levels, as before.
  if ((
        environment.serverLevelsAhead ?? environment.serverLevelsSource,
        environment.uploadQueue,
      )
      case (final source?, _?)) {
    await syncLevelsBeforeGame(
      repository: environment.repository,
      source: source,
      playerId: environment.playerId,
    );
  }
  final priorLevels = await environment.repository.currentLevels(
    environment.playerId,
  );
  // Rules v7 (Phase 4): the due weak spots of the current tiers. Optional:
  // a history that cannot be read just means a game without them.
  var due = const <Item>[];
  try {
    due = (await loadWeakSpotSchedule(environment)).due;
  } on Exception catch (_) {}
  return _controllerFor(
    due: due,
    environment,
    enabledTypes,
    plan,
    levels: {
      for (final type in enabledTypes)
        type: priorLevels[type]?.level ?? Level.zero,
    },
    kind: SessionKind.game,
    levelUpdates: const LevelCacheOrchestrator(),
  );
}

SessionController _controllerFor(
  AppEnvironment environment,
  Set<ExerciseType> enabledTypes,
  GameSetup setup, {
  required Map<ExerciseType, Level> levels,
  required SessionKind kind,
  required SessionLevelUpdates levelUpdates,
  List<Item> due = const [],
}) {
  final seed = DateTime.now().millisecondsSinceEpoch;
  // Decided once here and stored with the session, so the session replays
  // from what it stores alone (plan, Phase 2 commit 1).
  final typeSequence = shuffledTypeSequence(
    types: enabledTypes,
    perOperation: setup.questionsPerOperation,
    seed: seed,
  );
  const rulesVersion = RulesVersion.current;
  // Only a Levelling game re-asks weak spots, only from each operation's
  // current tier (`chooseWeakSpots`).
  final weakSpots = kind == SessionKind.game
      ? chooseWeakSpots(
          due: due,
          sequence: typeSequence,
          levels: levels,
          rules: rulesVersion,
        )
      : const <Item>[];
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: typeSequence.length,
      levels: levels,
      kind: kind,
      typeSequence: typeSequence,
      rulesVersion: rulesVersion,
      weakSpots: weakSpots,
    ),
    exerciseSource: LocalExerciseSource(
      generator: gameExerciseGenerator(
        rulesVersion: rulesVersion,
        enabledTypes: enabledTypes,
        levels: levels,
        typeSequence: typeSequence,
        weakSpots: weakSpots,
      ),
      seed: seed,
    ),
    levelCacheOrchestrator: levelUpdates,
    repository: environment.repository,
    playerId: environment.playerId,
    correctionDelay: SessionController.defaultCorrectionDelay,
    appVersion: appVersion,
    questionTimeout: questionTimeoutFor(
      isDebugBuild: kDebugMode,
      noTimeoutRequested: _debugNoTimeout,
    ),
    // A Levelling game is kept as it goes: closing the tab still counts.
    unfinishedGames: kind == SessionKind.game
        ? environment.unfinishedGameStore
        : null,
  );
}

/// A Tables mode round (`doc/levels.md`, section 7): [setup]'s facts,
/// shuffled by a fresh seed, on the game screen with its timer and keypad.
/// Practice only: no level update, and a throwaway repository — the round
/// never enters the history, the level cache or the upload queue. Played as
/// Training (no level change on the result screen).
SessionController buildTablesController(
  AppEnvironment environment,
  TablesSetup setup,
) {
  final seed = DateTime.now().millisecondsSinceEpoch;
  final questions = tablesQuestions(seed: seed, setup: setup);
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: const {ExerciseType.multiplication},
      exerciseCount: questions.length,
      levels: {ExerciseType.multiplication: Level.zero},
      kind: SessionKind.training,
    ),
    exerciseSource: ListExerciseSource(questions),
    levelCacheOrchestrator: const NoLevelUpdates(),
    repository: InMemorySessionRepository(),
    playerId: environment.playerId,
    correctionDelay: SessionController.defaultCorrectionDelay,
    appVersion: appVersion,
    questionTimeout: questionTimeoutFor(
      isDebugBuild: kDebugMode,
      noTimeoutRequested: _debugNoTimeout,
    ),
  );
}

/// A duel's controller (Phase 7): Basics and Advanced on the game's own
/// [SessionController] with the duel's questions — practice-like, a
/// throwaway repository and no level update (a duel never touches levels or
/// history; its run goes to the server through [AppEnvironment.duelQueue]).
DuelController buildDuelController(
  AppEnvironment environment,
  DuelOffer offer, {
  DateTime Function() clock = DateTime.now,
}) => DuelController(
  offer: offer,
  queue: environment.duelQueue!,
  clock: clock,
  quizController: (config) {
    final questions = config.questions();
    final types = {for (final q in questions) q.type};
    return SessionController(
      config: SessionConfig(
        seed: config.seed,
        enabledTypes: types,
        exerciseCount: questions.length,
        levels: {for (final t in types) t: Level.whole(10 * config.difficulty)},
        kind: SessionKind.training,
      ),
      exerciseSource: ListExerciseSource(questions),
      levelCacheOrchestrator: const NoLevelUpdates(),
      repository: InMemorySessionRepository(),
      playerId: environment.playerId,
      clock: clock,
      correctionDelay: SessionController.defaultCorrectionDelay,
      appVersion: appVersion,
      questionTimeout: questionTimeoutFor(
        isDebugBuild: kDebugMode,
        noTimeoutRequested: _debugNoTimeout,
      ),
    );
  },
);

/// A Weak spots game (Phase 4): [items] in order, one question each, at the
/// player's current levels (frozen), stored and uploaded like Training,
/// never moving a level. Throws if the items break `weakSpotsGameProblem`.
Future<SessionController> buildWeakSpotsController(
  AppEnvironment environment,
  List<Item> items,
) async {
  final current = await environment.repository.currentLevels(
    environment.playerId,
  );
  final types = {for (final item in items) item.type};
  final levels = {
    for (final type in types) type: current[type]?.level ?? Level.zero,
  };
  final sequence = [for (final item in items) item.type];
  if (weakSpotsGameProblem(items, sequence, levels) case final problem?) {
    throw ArgumentError.value(items, 'items', problem);
  }
  return _practiceController(
    environment,
    kind: SessionKind.weakSpots,
    items: items,
    levels: levels,
    sequence: sequence,
  );
}

/// A Drill (Phase 4): [drillGameLength] questions of one tip's strategy —
/// its [families], at the player's tier or the families' first; without
/// families, the operation's standard questions at the player's tier
/// brought into the tip's [band] (`drillTier`). Practice, stored and
/// uploaded, never moving a level.
Future<SessionController> buildDrillController(
  AppEnvironment environment, {
  required ExerciseType type,
  required List<PatternFamily> families,
  required TipBand band,
}) async {
  final current = await environment.repository.currentLevels(
    environment.playerId,
  );
  final tier = drillTier(
    families: families,
    playerTier: Tier.of(current[type]?.level ?? Level.zero),
    bandLow: band.low,
    bandHigh: band.high,
  );
  return _practiceController(
    environment,
    kind: SessionKind.drill,
    items: [for (final f in families) SkillItem(f)],
    levels: {type: Level.whole(10 * tier.index)},
    sequence: List.filled(drillGameLength, type),
  );
}

/// The Profile block's Practice (Phase 4): [facts] each twice, those the
/// player can practise at their current levels, as a Weak spots game.
/// `null` when none can be.
Future<SessionController?> buildFactsPracticeController(
  AppEnvironment environment,
  List<FactItem> facts,
) async {
  final current = await environment.repository.currentLevels(
    environment.playerId,
  );
  final practisableFacts = [
    for (final fact in facts)
      if (practisable(fact, current[fact.type]?.level ?? Level.zero)) fact,
  ];
  if (practisableFacts.isEmpty) return null;
  final items = [
    ...practisableFacts,
    ...practisableFacts,
  ].take(weakSpotsGameLength).toList();
  return buildWeakSpotsController(environment, items);
}

/// The Weak spots game Home offers now: the due items the player can
/// practise, most urgent first (`chooseWeakSpotsGame`).
Future<List<Item>> weakSpotsGameItems(AppEnvironment environment) async {
  final schedule = await loadWeakSpotSchedule(environment);
  final current = await environment.repository.currentLevels(
    environment.playerId,
  );
  return chooseWeakSpotsGame(
    due: schedule.due,
    levels: {
      for (final MapEntry(:key, :value) in current.entries) key: value.level,
    },
  );
}

SessionController _practiceController(
  AppEnvironment environment, {
  required SessionKind kind,
  required List<Item> items,
  required Map<ExerciseType, Level> levels,
  required List<ExerciseType> sequence,
}) {
  final seed = DateTime.now().millisecondsSinceEpoch;
  const rulesVersion = RulesVersion.current;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: sequence.toSet(),
      exerciseCount: sequence.length,
      levels: levels,
      kind: kind,
      typeSequence: sequence,
      rulesVersion: rulesVersion,
      weakSpots: items,
    ),
    exerciseSource: LocalExerciseSource(
      generator: practiceGenerator(
        kind: kind,
        items: items,
        levels: levels,
        typeSequence: sequence,
      ),
      seed: seed,
    ),
    levelCacheOrchestrator: const NoLevelUpdates(),
    repository: environment.repository,
    playerId: environment.playerId,
    correctionDelay: SessionController.defaultCorrectionDelay,
    appVersion: appVersion,
    questionTimeout: questionTimeoutFor(
      isDebugBuild: kDebugMode,
      noTimeoutRequested: _debugNoTimeout,
    ),
  );
}

/// The player's weak-spot schedule, rebuilt from every stored game
/// (Phase 4: nothing about it is stored) — except the ones the server
/// refused: it rebuilds the same schedule from the ones it accepted, to
/// check a game's weak spots were due (Phase 4 close-out).
Future<WeakSpotSchedule> loadWeakSpotSchedule(
  AppEnvironment environment,
) async => scheduleFromHistory([
  for (final game in await environment.repository.storedGames(
    environment.playerId,
  ))
    if (game.session.uploadRefused == null) game,
]);

/// Debug switch: `flutter run --dart-define=DEBUG_NO_TIMEOUT=true` turns the
/// per-question timeout off, for slow manual checks and screenshots.
const _debugNoTimeout = bool.fromEnvironment('DEBUG_NO_TIMEOUT');

/// The timeout a session gets. The switch only works in a debug build:
/// `kDebugMode` is a compile-time `false` in profile and release builds, so
/// there the switch is ignored whatever the build was given — the preview
/// and every player always have the timeout.
Duration? questionTimeoutFor({
  required bool isDebugBuild,
  required bool noTimeoutRequested,
}) => isDebugBuild && noTimeoutRequested
    ? null
    : SessionController.defaultQuestionTimeout;
