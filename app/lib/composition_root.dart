import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_core/friends/friends.dart';
import 'package:math_core/tiers/tip_band.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/weak_spots/history.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/levelling.dart';
import 'package:math_core/weak_spots/practice.dart';
import 'package:math_core/weak_spots/scheduler.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/beta_access.dart';
import 'package:math_core/feedback/feedback.dart';
import 'package:math_core/account/profile_repository.dart';
import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/list_exercise_source.dart';
import 'package:math_core/generation/local_exercise_source.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/tables.dart';
import 'package:math_core/persistence/chain_setup_store.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/game_setup_store.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/local_player_id_provider.dart';
import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:math_core/persistence/abandoned_guest_cleanup.dart';
import 'package:math_core/sync/server_levels.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_core/sync/session_upload_queue.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/persistence/theme_mode_store.dart';
import 'package:math_core/persistence/type_selection_store.dart';
import 'core/sharing/link_sharer.dart';
import 'core/state/duel_controller.dart';
import 'core/state/session_controller.dart';
import 'infrastructure/backend/http_duel_client.dart';
import 'infrastructure/backend/supabase_friends_repository.dart';
import 'infrastructure/backend/supabase_online_repository.dart';
import 'infrastructure/persistence/shared_preferences_pending_invite_store.dart';
import 'infrastructure/sharing/link_sharer_factory.dart';
import 'infrastructure/persistence/shared_preferences_duel_run_store.dart';
import 'infrastructure/backend/http_session_upload_client.dart';
import 'infrastructure/backend/supabase_beta_code_repository.dart';
import 'infrastructure/backend/supabase_feedback_repository.dart';
import 'infrastructure/backend/supabase_leaderboard_repository.dart';
import 'infrastructure/backend/supabase_account_repository.dart';
import 'infrastructure/backend/supabase_profile_repository.dart';
import 'infrastructure/backend/supabase_server_levels_source.dart';
import 'core/effects/app_session_effects.dart';
import 'core/effects/effect_settings.dart';
import 'core/effects/session_effects.dart';
import 'infrastructure/effects/game_haptics_factory.dart';
import 'infrastructure/effects/game_sound_factory.dart';
import 'infrastructure/persistence/database.dart';
import 'infrastructure/persistence/persistent_storage.dart';
import 'infrastructure/persistence/shared_preferences_abandoned_guest_store.dart';
import 'infrastructure/persistence/shared_preferences_beta_code_store.dart';
import 'infrastructure/web/boot_sign_in.dart';
import 'infrastructure/persistence/shared_preferences_effect_settings_store.dart';
import 'infrastructure/persistence/shared_preferences_challenge_stats_store.dart';
import 'infrastructure/persistence/shared_preferences_chain_setup_store.dart';
import 'infrastructure/persistence/shared_preferences_game_setup_store.dart';
import 'infrastructure/persistence/shared_preferences_tables_store.dart';
import 'infrastructure/persistence/shared_preferences_player_id_provider.dart';
import 'infrastructure/persistence/shared_preferences_theme_mode_store.dart';
import 'infrastructure/persistence/shared_preferences_type_selection_store.dart';
import 'infrastructure/persistence/sqflite_session_repository.dart';

/// Concrete dependencies resolved once at app start (see `main.dart`),
/// before `runApp()` — never in a UI widget. This is the only file choosing
/// *which* concrete implementations to use (generation, persistence);
/// screens only observe the resulting `SessionController`.
class AppEnvironment {
  const AppEnvironment({
    required this.repository,
    required this.playerId,
    required this.accountRepository,
    required this.profileRepository,
    this.typeSelectionStore = const SharedPreferencesTypeSelectionStore(),
    this.gameSetupStore = const SharedPreferencesGameSetupStore(),
    this.chainSetupStore = const SharedPreferencesChainSetupStore(),
    this.tablesStore = const SharedPreferencesTablesStore(),
    this.challengeStatsStore = const SharedPreferencesChallengeStatsStore(),
    this.themeModeStore = const SharedPreferencesThemeModeStore(),
    this.abandonedGuestStore = const SharedPreferencesAbandonedGuestStore(),
    this.uploadClient,
    this.uploadQueue,
    this.serverLevelsAhead,
    this.leaderboardRepository,
    this.serverLevelsSource,
    this.betaCodes,
    this.betaCodeStore = const SharedPreferencesBetaCodeStore(),
    this.feedbackRepository,
    this.sessionEffects = const NoSessionEffects(),
    this.effectSettings,
    this.duelClient,
    this.duelRunStore = const SharedPreferencesDuelRunStore(),
    this.duelQueue,
    this.onlineRepository,
    this.friendsRepository,
    this.pendingInviteStore = const SharedPreferencesPendingInviteStore(),
    this.siteUrl,
    this.linkSharer,
  });

  final SessionRepository repository;

  /// Player whose data is read and written. At start: the device's local id
  /// (`LocalPlayerIdProvider`), now only used to find games played before
  /// accounts. On sign-in, `AuthGate` replaces it with the account id
  /// ([environmentForAccount]): screens only ever see that one.
  final String playerId;

  /// Required, no concrete default: unlike `typeSelectionStore`/
  /// `themeModeStore` (auxiliary local read, silent failure acceptable), the
  /// account is the very feature of the sign-in gate — a default would hide
  /// a wiring mistake rather than simplify tests. Tests that do not care
  /// about the account pass `FakeAccountRepository`
  /// (`test/fake_account_repository.dart`).
  final AccountRepository accountRepository;

  /// Same reasoning as `accountRepository`: required, no silent default —
  /// it is the core feature of the Profile tab.
  final ProfileRepository profileRepository;

  /// Optional, concrete default rather than required: a required field would
  /// break construction in tests that never care about `PlayTab`
  /// (`ProfileScreen`, `ResultScreen`...), same reasoning as
  /// `SessionResult.scorer` (step 5, commit D).
  final TypeSelectionStore typeSelectionStore;

  /// The setup page's choices; same reasoning as `typeSelectionStore`.
  final GameSetupStore gameSetupStore;

  /// Chain operations' setup; same reasoning as `typeSelectionStore`.
  final ChainSetupStore chainSetupStore;

  /// Tables mode's setup and stats, on the device (`doc/levels.md`
  /// section 7); same reasoning as `typeSelectionStore`.
  final TablesStore tablesStore;

  /// The challenges' personal records, on the device only (plan v2.9).
  final ChallengeStatsStore challengeStatsStore;

  /// Same reasoning as `typeSelectionStore`: optional so as not to break
  /// construction in tests that do not care about the theme toggle.
  final ThemeModeStore themeModeStore;

  /// Guests this device left for another account (`AuthGate`), whose
  /// hidden games go after 30 days.
  final AbandonedGuestStore abandonedGuestStore;

  /// `null` when the build has no `SERVER_URL` (server not deployed yet):
  /// sessions stay local, pending, until a build has one.
  final SessionUploadClient? uploadClient;

  /// This player's upload queue (`forPlayer`); `null` for the device-id
  /// environment and without [uploadClient]. Flushed at sign-in and after
  /// every session flow; disposed by `AuthGate` when the player changes.
  final SessionUploadQueue? uploadQueue;

  /// This player's server levels, read ahead of the first game
  /// (`forPlayer`, Phase 5.1 commit 1): `AuthGate` starts the read once the
  /// sign-in's uploads are settled, and Start uses its answer instead of a
  /// round trip. `null` where [serverLevelsSource] is.
  final PrefetchedServerLevels? serverLevelsAhead;

  /// The boards (Supabase); `null` in tests that do not care — the tab
  /// then says it is unavailable.
  final LeaderboardRepository? leaderboardRepository;

  /// The player's server levels, read before each game
  /// (`syncLevelsBeforeGame`, Phase 3a commit 2). `null` without
  /// [uploadClient]: with no uploads the server knows nothing, and its empty
  /// levels must never replace local progress.
  final ServerLevelsSource? serverLevelsSource;

  /// The beta gate (Phase 3a commit 3): `null` when the build has it off
  /// (`BETA_GATE`), and then no code is ever asked nor redeemed.
  final BetaCodeRepository? betaCodes;

  /// Same reasoning as `typeSelectionStore`.
  final BetaCodeStore betaCodeStore;

  /// The beta's feedback field (Phase 3a commit 5); `null` in tests that
  /// do not care — Profile then shows no "Send feedback".
  final FeedbackRepository? feedbackRepository;

  /// Sound and haptics during a game (Phase 5).
  final SessionEffects sessionEffects;

  /// The Profile's effect switches; `null` in tests that do not care —
  /// Profile then shows none.
  final EffectSettings? effectSettings;

  /// The server's duel endpoints (Phase 7); `null` without `SERVER_URL` —
  /// the Online tab then says duels are not available.
  final DuelClient? duelClient;

  /// Where runs wait for the server, per player.
  final DuelRunStore duelRunStore;

  /// This player's duel runs on their way (`forPlayer`); `null` without
  /// [duelClient].
  final DuelRunQueue? duelQueue;

  /// The Online tab's reads (Supabase); `null` in tests that do not care.
  final OnlineRepository? onlineRepository;

  /// Friends (Supabase); `null` in tests that do not care — the Online tab
  /// then has no Friends button.
  final FriendsRepository? friendsRepository;

  /// An invite link's code waiting for the player to be linked.
  final PendingInviteStore pendingInviteStore;

  /// The site's own address, for invite links; `null` off the web.
  final Uri? siteUrl;

  /// The share sheet for invite links (plan v3.8); `null`: the link is
  /// copied.
  final LinkSharer? linkSharer;

  AppEnvironment forPlayer(String playerId) => AppEnvironment(
    repository: repository,
    playerId: playerId,
    accountRepository: accountRepository,
    profileRepository: profileRepository,
    typeSelectionStore: typeSelectionStore,
    gameSetupStore: gameSetupStore,
    chainSetupStore: chainSetupStore,
    tablesStore: tablesStore,
    challengeStatsStore: challengeStatsStore,
    themeModeStore: themeModeStore,
    abandonedGuestStore: abandonedGuestStore,
    uploadClient: uploadClient,
    leaderboardRepository: leaderboardRepository,
    serverLevelsSource: serverLevelsSource,
    betaCodes: betaCodes,
    betaCodeStore: betaCodeStore,
    feedbackRepository: feedbackRepository,
    sessionEffects: sessionEffects,
    effectSettings: effectSettings,
    duelClient: duelClient,
    duelRunStore: duelRunStore,
    onlineRepository: onlineRepository,
    friendsRepository: friendsRepository,
    pendingInviteStore: pendingInviteStore,
    siteUrl: siteUrl,
    linkSharer: linkSharer,
    duelQueue: switch (duelClient) {
      final client? => DuelRunQueue(
        store: duelRunStore,
        client: client,
        playerId: playerId,
      ),
      null => null,
    },
    serverLevelsAhead: switch (serverLevelsSource) {
      final source? => PrefetchedServerLevels(
        source: source,
        repository: repository,
        playerId: playerId,
      ),
      null => null,
    },
    uploadQueue: switch (uploadClient) {
      final client? => SessionUploadQueue(
        repository: repository,
        client: client,
        playerId: playerId,
      ),
      null => null,
    },
  );
}

/// Environment of the signed-in player: levels and history bound to the
/// account, not the device — two accounts on the same browser share
/// nothing. First adopts the games played under the device's local id
/// (`SessionRepository.transferPlayerData`: only if the account has nothing
/// here yet, so in practice the first account to sign in). A failed
/// adoption does not prevent playing: the old games stay under the device
/// id, and adoption is retried at the next sign-in.
Future<AppEnvironment> environmentForAccount(
  AppEnvironment environment,
  Account account,
) async {
  try {
    await environment.repository.transferPlayerData(
      fromPlayerId: environment.playerId,
      toPlayerId: account.id,
    );
  } on Exception catch (_) {
    // See above: no consequence for the game being played.
  }
  return environment.forPlayer(account.id);
}

/// URL and publishable key read at compile time (`--dart-define`), never
/// hard-coded in the source (`doc/online.md`) — the publishable key is meant
/// to ship in the client (RLS protects the data, not this key's secrecy),
/// but the URL/key remain specific to each Supabase project.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// The upload server (`server/`); empty until the owner deploys it — the
/// app then keeps every session local and pending (plan: offline first).
const _serverUrl = String.fromEnvironment('SERVER_URL');

/// The invite-only beta's gate (Phase 3a commit 3), on when the build says
/// `BETA_GATE=true` (CI: the repository variable of the same name, set by
/// the owner when the invitations go out; removed at the public launch).
const _betaGate = bool.fromEnvironment('BETA_GATE');

/// The build's commit (CI: the first 7 characters of the SHA), stored with
/// every feedback message; `dev` for a local build.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// `true` in the CI's preview builds (the beta's site): tools for the owner
/// such as the typeface specimen. A public release (Phase 6) leaves it
/// unset.
const previewBuild = bool.fromEnvironment('PREVIEW_BUILD');

/// The digit-typeface specimen opens with `?specimen` (Phase 5 commit 1).
const specimenAvailable = kDebugMode || previewBuild;

/// Build started without `--dart-define-from-file=dart_defines.json` (see
/// `dart_defines.example.json`). Without this check the app still started
/// on the sign-in gate with an address-less Supabase client: every attempt
/// failed on an incomprehensible URI error, and with sign-in mandatory the
/// whole app became unusable without explanation.
class MissingBackendConfigException implements Exception {
  const MissingBackendConfigException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() =>
      'MissingBackendConfigException: ${missingKeys.join(', ')} absent(s)';
}

/// On web, the SQLite database runs as WebAssembly in a worker
/// (`sqflite_common_ffi_web`) loaded from `web/sqlite3.wasm` and
/// `web/sqflite_sw.js`. If they are missing (setup never run), opening
/// fails: without this check the app would crash at start with no
/// explanation — and falling back to in-memory storage would lose games
/// silently.
class WebStorageUnavailableException implements Exception {
  const WebStorageUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'WebStorageUnavailableException: $cause';
}

Future<AppEnvironment> buildAppEnvironment() async {
  final missingKeys = [
    if (_supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (_supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
  if (missingKeys.isNotEmpty) {
    throw MissingBackendConfigException(missingKeys);
  }

  final LocalPlayerIdProvider playerIdProvider =
      SharedPreferencesPlayerIdProvider();
  final playerId = await playerIdProvider.currentPlayerId();

  final SessionRepository repository;
  try {
    repository = SqfliteSessionRepository(await openAppDatabase());
  } catch (e) {
    if (kIsWeb) throw WebStorageUnavailableException(e);
    rethrow;
  }
  // Not awaited: the answer (or a Firefox prompt) must not delay the first
  // frame, and a refusal changes nothing in how the app runs.
  unawaited(requestPersistentStorage());

  // The page may have signed in while the files downloaded (Phase 5.1
  // commit 1): its session must be in storage before the client reads it.
  await waitForBootSignIn();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  final accountRepository = SupabaseAccountRepository(Supabase.instance.client);
  // An invite link (`?friend=MATH-7K2P`, Phase 7): its code waits on the
  // device until the player is linked, then becomes a friend request.
  const invites = SharedPreferencesPendingInviteStore();
  if (kIsWeb) {
    final invited = Uri.base.queryParameters[inviteLinkParameter];
    final code = invited == null ? null : normalizeFriendCode(invited);
    if (code != null) {
      try {
        await invites.save(code);
      } on Exception catch (_) {
        // The link is lost; the code can still be typed.
      }
    }
  }
  final haptics = createGameHaptics();
  final effectSettings = await EffectSettings.load(
    const SharedPreferencesEffectSettingsStore(),
    hapticsSupported: haptics.supported,
  );
  return AppEnvironment(
    effectSettings: effectSettings,
    sessionEffects: AppSessionEffects(
      sound: createGameSound(),
      haptics: haptics,
      settings: effectSettings,
    ),
    repository: repository,
    playerId: playerId,
    accountRepository: accountRepository,
    profileRepository: SupabaseProfileRepository(Supabase.instance.client),
    leaderboardRepository: SupabaseLeaderboardRepository(
      Supabase.instance.client,
    ),
    uploadClient: _serverUrl.isEmpty
        ? null
        : HttpSessionUploadClient(
            serverUrl: Uri.parse(_serverUrl),
            accessToken: accountRepository.accessToken,
          ),
    serverLevelsSource: _serverUrl.isEmpty
        ? null
        : SupabaseServerLevelsSource(Supabase.instance.client),
    betaCodes: _betaGate
        ? SupabaseBetaCodeRepository(Supabase.instance.client)
        : null,
    onlineRepository: SupabaseOnlineRepository(Supabase.instance.client),
    friendsRepository: SupabaseFriendsRepository(Supabase.instance.client),
    pendingInviteStore: invites,
    siteUrl: kIsWeb ? Uri.base : null,
    linkSharer: createLinkSharer(),
    duelClient: _serverUrl.isEmpty
        ? null
        : HttpDuelClient(
            serverUrl: Uri.parse(_serverUrl),
            accessToken: accountRepository.accessToken,
          ),
    feedbackRepository: SupabaseFeedbackRepository(Supabase.instance.client),
  );
}

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
      ? chooseWeakSpots(due: due, sequence: typeSequence, levels: levels)
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
