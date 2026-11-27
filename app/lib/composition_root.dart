import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
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
import 'package:math_core/sync/upload_attempt_log.dart';
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
import 'infrastructure/backend/time_limited_client.dart';
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
import 'infrastructure/persistence/shared_preferences_upload_attempt_log.dart';
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
import 'infrastructure/persistence/shared_preferences_unfinished_game_store.dart';
import 'core/state/hints.dart';
import 'core/state/levels_refresh.dart';
import 'core/state/unfinished_game.dart';
import 'infrastructure/persistence/shared_preferences_hints_store.dart';
import 'infrastructure/web/page_reload.dart' as web;

part 'session_builders.dart';

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
    this.uploadAttemptLog = const SharedPreferencesUploadAttemptLog(),
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
    this.unfinishedGameStore,
    this.hints,
    this.levelsRefresh,
    this.reloadPage,
  });

  final SessionRepository repository;

  /// Where a Levelling game is kept after every answer, for a start after a
  /// closed tab (Phase 6b commit 2, `recoverUnfinishedGame`). `null` in
  /// tests that do not look at it.

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

  /// Server failures per stored session (Phase 6a): a session the server
  /// keeps failing on is set aside instead of blocking the queue.
  final UploadAttemptLog uploadAttemptLog;

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

  final UnfinishedGameStore? unfinishedGameStore;

  /// The one-time explanations seen (Phase 6b commit 4). `null`: none is
  /// shown (tests that do not look at them).
  final HintsStore? hints;

  /// Fired when the server's levels replaced the local ones at sign-in
  /// ([adoptServerLevelsAtSignIn]); Home and Profile read them again. One
  /// per player (`forPlayer`); `null` in tests that do not look at it.
  final LevelsRefresh? levelsRefresh;

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

  /// Reloads the page (the web build); `null` elsewhere and in tests. A
  /// duel asked for by a build older than the server's rules offers it
  /// (plan v4.1).
  final void Function()? reloadPage;

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
    unfinishedGameStore: unfinishedGameStore,
    hints: hints,
    reloadPage: reloadPage,
    levelsRefresh: LevelsRefresh(),
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
        attempts: uploadAttemptLog,
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

/// Right after sign-in (Phase 6b commit 5, review M14): once the sign-in's
/// uploads are settled, the server's levels replace the local ones when
/// they differ — a linked player on a new device sees their levels on Home
/// at once, not after a first game started from 0. The same rule as before
/// a game (`syncLevelsBeforeGame`: never while uploads are pending), with
/// the Supabase call's own limit instead of a game's 2 s. Never throws.
Future<LevelSyncOutcome> adoptServerLevelsAtSignIn(
  AppEnvironment environment,
) async {
  final source = environment.serverLevelsSource;
  if (source == null || environment.uploadQueue == null) {
    return LevelSyncOutcome.unavailable;
  }
  try {
    final outcome = await syncLevelsBeforeGame(
      repository: environment.repository,
      source: source,
      playerId: environment.playerId,
      timeout: supabaseCallLimit,
    );
    if (outcome == LevelSyncOutcome.adopted) {
      environment.levelsRefresh?.changed();
    }
    return outcome;
  } on Exception catch (_) {
    return LevelSyncOutcome.unavailable;
  }
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

  // A Levelling game left by closing the tab (Phase 6b commit 2): stored
  // now, before any new game starts from the levels — under rules v9 its
  // unanswered questions count as timeouts. Never blocks the start.
  const unfinishedGames = SharedPreferencesUnfinishedGameStore();
  try {
    await recoverUnfinishedGame(store: unfinishedGames, repository: repository);
  } on Exception catch (_) {
    // Kept for the next start.
  }

  // The page may have signed in while the files downloaded (Phase 5.1
  // commit 1): its session must be in storage before the client reads it.
  await waitForBootSignIn();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
    // Every Supabase call, auth and database, gives up after 15 s (Phase 6b
    // commit 5, review M18): a stalled request fails as offline does.
    httpClient: TimeLimitedClient(http.Client()),
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
    unfinishedGameStore: unfinishedGames,
    hints: const SharedPreferencesHintsStore(),
    reloadPage: web.reloadPage,
  );
}
