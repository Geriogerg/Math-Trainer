import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/domain/account/account.dart';
import 'core/domain/account/account_repository.dart';
import 'core/domain/account/profile_repository.dart';
import 'core/domain/generation/composite_exercise_generator.dart';
import 'core/domain/generation/debt_aware_type_selection_strategy.dart';
import 'core/domain/generation/local_exercise_source.dart';
import 'core/domain/generation/session_length.dart';
import 'core/domain/leveling/leveling_rules.dart';
import 'core/domain/models/exercise_type.dart';
import 'core/domain/models/session_config.dart';
import 'core/domain/persistence/local_player_id_provider.dart';
import 'core/domain/persistence/session_repository.dart';
import 'core/domain/persistence/theme_mode_store.dart';
import 'core/domain/persistence/type_selection_store.dart';
import 'core/state/session_controller.dart';
import 'infrastructure/backend/supabase_account_repository.dart';
import 'infrastructure/backend/supabase_profile_repository.dart';
import 'infrastructure/persistence/database.dart';
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

  AppEnvironment forPlayer(String playerId) => AppEnvironment(
    repository: repository,
    playerId: playerId,
    accountRepository: accountRepository,
    profileRepository: profileRepository,
    typeSelectionStore: typeSelectionStore,
    themeModeStore: themeModeStore,
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

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  return AppEnvironment(
    repository: repository,
    playerId: playerId,
    accountRepository: SupabaseAccountRepository(Supabase.instance.client),
    profileRepository: SupabaseProfileRepository(Supabase.instance.client),
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
    for (final type in enabledTypes) type: priorLevels[type]?.level ?? 1,
  };

  final exerciseCount = sessionLengthFor(
    activeTypeCount: enabledTypes.length,
    nMin: _levelingRules.nMin,
    cap: _sessionLengthCap,
  );
  final strategy = DebtAwareTypeSelectionStrategy(
    exerciseCount: exerciseCount,
    nMin: _levelingRules.nMin,
    sessionsPlayedByType: {
      for (final entry in priorLevels.entries)
        entry.key: entry.value.sessionsPlayed,
    },
  );

  final seed = DateTime.now().millisecondsSinceEpoch;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: exerciseCount,
      levels: levels,
    ),
    exerciseSource: LocalExerciseSource(
      generator: CompositeExerciseGenerator(
        enabledTypes: enabledTypes,
        levels: levels,
        strategy: strategy,
      ),
      seed: seed,
    ),
    repository: environment.repository,
    playerId: environment.playerId,
  );
}
