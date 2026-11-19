import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/profile_repository.dart';
import 'package:math_core/generation/composite_exercise_generator.dart';
import 'package:math_core/generation/debt_aware_type_selection_strategy.dart';
import 'package:math_core/generation/fixed_type_sequence.dart';
import 'package:math_core/generation/local_exercise_source.dart';
import 'package:math_core/generation/session_length.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/leveling_rules.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/local_player_id_provider.dart';
import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:math_core/persistence/placement_skip_store.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_core/sync/session_upload_queue.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/persistence/theme_mode_store.dart';
import 'package:math_core/persistence/type_selection_store.dart';
import 'package:math_core/placement/placement.dart';
import 'package:math_core/placement/placement_exercise_source.dart';
import 'package:math_core/placement/placement_level_orchestrator.dart';
import 'core/state/session_controller.dart';
import 'infrastructure/backend/http_session_upload_client.dart';
import 'infrastructure/backend/supabase_leaderboard_repository.dart';
import 'infrastructure/backend/supabase_account_repository.dart';
import 'infrastructure/backend/supabase_profile_repository.dart';
import 'infrastructure/persistence/database.dart';
import 'infrastructure/persistence/persistent_storage.dart';
import 'infrastructure/persistence/shared_preferences_placement_skip_store.dart';
import 'infrastructure/persistence/shared_preferences_player_id_provider.dart';
import 'infrastructure/persistence/shared_preferences_theme_mode_store.dart';
import 'infrastructure/persistence/shared_preferences_type_selection_store.dart';
import 'infrastructure/persistence/sqflite_session_repository.dart';

/// Duration target (~90 s at ~4 s/question, rough — see `doc/decisions.md`)
/// disguised as a question cap: `sessionLengthFor` never exceeds this value,
/// whatever the number of active types.
const _sessionLengthCap = 24;

final _levelingRules = LevelingRules();

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
    this.themeModeStore = const SharedPreferencesThemeModeStore(),
    this.placementSkipStore = const SharedPreferencesPlacementSkipStore(),
    this.uploadClient,
    this.uploadQueue,
    this.leaderboardRepository,
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

  /// Same reasoning as `typeSelectionStore`: optional so as not to break
  /// construction in tests that do not care about the theme toggle.
  final ThemeModeStore themeModeStore;

  /// Same reasoning as `typeSelectionStore`.
  final PlacementSkipStore placementSkipStore;

  /// `null` when the build has no `SERVER_URL` (server not deployed yet):
  /// sessions stay local, pending, until a build has one.
  final SessionUploadClient? uploadClient;

  /// This player's upload queue (`forPlayer`); `null` for the device-id
  /// environment and without [uploadClient]. Flushed at sign-in and after
  /// every session flow; disposed by `AuthGate` when the player changes.
  final SessionUploadQueue? uploadQueue;

  /// The boards (Supabase); `null` in tests that do not care — the tab
  /// then says it is unavailable.
  final LeaderboardRepository? leaderboardRepository;

  AppEnvironment forPlayer(String playerId) => AppEnvironment(
    repository: repository,
    playerId: playerId,
    accountRepository: accountRepository,
    profileRepository: profileRepository,
    typeSelectionStore: typeSelectionStore,
    themeModeStore: themeModeStore,
    placementSkipStore: placementSkipStore,
    uploadClient: uploadClient,
    leaderboardRepository: leaderboardRepository,
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

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  final accountRepository = SupabaseAccountRepository(Supabase.instance.client);
  return AppEnvironment(
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
  );
}

/// Builds a `SessionController` ready to play: local exercise source (a mix
/// of [enabledTypes], chosen by the player on `PlayTab`) + a fresh seed +
/// the dependencies of [environment]. Asynchronous: reads the player's level
/// cache (rule 4, repositories always async) to freeze this session's levels
/// — level 1 for any operation never played (no estimated skill = start at
/// the bottom).
///
/// The number of questions is not fixed: `sessionLengthFor` aims for enough
/// questions for every active type to reach `n_min` (so its level cache can
/// move), capped at `_sessionLengthCap`. Beyond the cap,
/// `DebtAwareTypeSelectionStrategy` favours the least-played types
/// (`sessionsPlayed`, already read above for the levels) — no extra
/// repository call (see `doc/decisions.md`).
Future<SessionController> buildSessionController(
  AppEnvironment environment,
  Set<ExerciseType> enabledTypes,
) async {
  final priorLevels = await environment.repository.currentLevels(
    environment.playerId,
  );
  final levels = {
    for (final type in enabledTypes)
      type: priorLevels[type]?.level ?? Level.floor,
  };

  final exerciseCount = sessionLengthFor(
    activeTypeCount: enabledTypes.length,
    nMin: _levelingRules.nMin,
    cap: _sessionLengthCap,
  );
  // The order depends on the player's history (least-played types first):
  // decided once here and stored with the session, so the session replays
  // from what it stores alone (plan, Phase 2 commit 1).
  final typeSequence = DebtAwareTypeSelectionStrategy(
    exerciseCount: exerciseCount,
    nMin: _levelingRules.nMin,
    sessionsPlayedByType: {
      for (final entry in priorLevels.entries)
        entry.key: entry.value.sessionsPlayed,
    },
  ).sequenceFor(enabledTypes.toList()..sort((a, b) => a.index - b.index));

  final seed = DateTime.now().millisecondsSinceEpoch;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: exerciseCount,
      levels: levels,
      typeSequence: typeSequence,
    ),
    exerciseSource: LocalExerciseSource(
      generator: CompositeExerciseGenerator(
        enabledTypes: enabledTypes,
        levels: levels,
        strategy: FixedTypeSequence(typeSequence),
      ),
      seed: seed,
    ),
    repository: environment.repository,
    playerId: environment.playerId,
    correctionDelay: SessionController.defaultCorrectionDelay,
    questionTimeout: questionTimeoutFor(
      isDebugBuild: kDebugMode,
      noTimeoutRequested: _debugNoTimeout,
    ),
  );
}

/// The placement test (plan, Phase 1 commit 6): the four basic operations
/// in turn, each on its own adaptive staircase, then starting levels from
/// `placementLevels`. Offered by `PlayTab` to a player with no history.
SessionController buildPlacementController(AppEnvironment environment) {
  const rules = currentPlacementRules;
  final seed = DateTime.now().millisecondsSinceEpoch;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: placementTypes.toSet(),
      exerciseCount: rules.questionCount,
      // The staircases' common start, recorded with the session; the level
      // of each question follows the answers (`PlacementExerciseSource`).
      levels: {
        for (final t in placementTypes) t: Level.whole(rules.startLevel),
      },
      kind: placementKindFor(rules),
      typeSequence: placementTypeSequence(rules),
    ),
    exerciseSource: PlacementExerciseSource(seed: seed, rules: rules),
    levelCacheOrchestrator: const PlacementLevelOrchestrator(rules: rules),
    repository: environment.repository,
    playerId: environment.playerId,
    correctionDelay: SessionController.defaultCorrectionDelay,
    questionTimeout: questionTimeoutFor(
      isDebugBuild: kDebugMode,
      noTimeoutRequested: _debugNoTimeout,
    ),
  );
}

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
