# Architecture — Math Trainer

Reference document, **not loaded automatically**. The non-negotiable rules are in `CLAUDE.md`;
this file describes the current state and may lag behind the code. Where they differ, the code is
right — report the gap.

## Tree

```
packages/math_core/        # pure Dart, no dependency — imported by path by app/ and server/ (rule 1)
  lib/
    account/               # Account, AccountRepository, PlayerProfile, ProfileRepository (interfaces)
    models/                # Exercise (sealed) and 5 variants, ExerciseType, OperationType,
                           # AnswerResult, SessionConfig, SessionResult, SessionKind, GameSetup
    generation/            # ExerciseGenerator, CompositeExerciseGenerator, per-type generators,
                           # OperandRange, ExerciseSource, LocalExerciseSource,
                           # FixedTypeSequence, question_plan.dart (questions per
                           # operation, shuffledTypeSequence — the pre-Redesign debt rotation
                           # lives in test/support/ for the pinned determinism cases)
    difficulty/            # level → operand bounds per type (arithmetic/power/square_root/percentage)
    placement/             # placement test: staircases, placementLevels (pure), its exercise
                           # source (adaptive, deterministic), PlacementLevelOrchestrator
    leveling/              # Level, LevelUpdater, LevelCacheOrchestrator, LevelingRules, Confidence,
                           # AnswerOutcome — recompute levels from history; main_level.dart
                           # (main level = mean of the four basics, also stored per session;
                           # mainLevelsAfter rebuilt the stored values at schema v9)
    replay/                # replaySessionQuestions: a stored session's questions from what it
                           # stores alone (seed, kind, frozen levels, type sequence)
    leaderboard/           # LeaderboardBoard, LeaderboardEntry, Standing (Ranked/NotRanked),
                           # LeaderboardRepository (interface), JSON parsing
    sync/                  # SessionUpload (JSON codec shared with the server),
                           # SessionUploadClient (interface), SessionUploadQueue (offline, ordered)
    validation/            # validateSessionUpload: the server's replay and checks (pure);
                           # ServerPlayerState, RejectionReason, ValidationFlag
    scoring/               # Scorer, ScoringRules
    persistence/           # SessionRepository, LocalPlayerIdProvider, TypeSelectionStore,
                           # ThemeModeStore, PlacementSkipStore, GameSetupStore (interfaces), PersistedSession/
                           # PersistedAnswer, LevelCacheEntry, InMemorySessionRepository, uuid.dart,
                           # exercise_codec.dart
  test/                    # mirrors lib/ — `dart test` (VM) and `dart test -p node` (JavaScript);
                           # determinism/ (pinned references), tool/ (replay metrics)
  tool/
    recalibrate.dart       # replays stored answers to tune the leveling constants (Phase 3)
    delta_check.dart       # simulated players against LevelUpdater, compares δ / n_min settings
    placement_check.dart   # simulated players through the placement, then games
    determinism_references.dart  # regenerates test/determinism/determinism_references.dart
    src/                   # player_model.dart, replay_metrics.dart
app/                       # the Flutter app (package `math_trainer`), web first
  lib/
    main.dart              # runApp() — async, resolves the environment first; ConfigErrorApp if
                           # the build lacks the Supabase configuration or web storage fails
    app.dart               # MaterialApp, theme (light/dark/persisted toggle), AuthGate at the root
    composition_root.dart  # the only file choosing concrete implementations (AppEnvironment)
    core/state/            # SessionController (ChangeNotifier), SessionState, account form and
                           # deletion controllers, LeaderboardController — foundation.dart only
    infrastructure/
      persistence/         # SqfliteSessionRepository, database.dart (schema, migrations, web
                           # engine), SharedPreferences{PlayerIdProvider,TypeSelectionStore,
                           # ThemeModeStore,PlacementSkipStore} — the only place importing
                           # sqflite / shared_preferences; persistent_storage*.dart
      backend/             # Supabase{Account,Profile}Repository — the only place importing
                           # supabase_flutter (besides composition_root.dart);
                           # HttpSessionUploadClient (package http),
                           # SupabaseLeaderboardRepository (the two board functions)
    presentation/
      theme/               # app_theme.dart — light/dark ColorScheme, AppPalette/AppMotion/AppMetrics
      screens/             # AuthGate (anonymous-first), AppShell (tabbed shell, IndexedStack),
                           # PlayTab (placement offer, Home, setup page), SessionFlowScreen/
                           # SessionScreen (full-screen session), ResultScreen, ProfileScreen,
                           # SaveProgressScreen, SignInScreen, LeaderboardScreen,
                           # ComingSoonScreen (Online tab), EmptyState, ConfigErrorApp
      exercise_prompt.dart # builds the displayed operation from the exercise's fields
      exercise_type_labels.dart
  test/
    state/                 # controllers — `flutter test` (ChangeNotifier pulls dart:ui)
    infrastructure/        # sqflite via sqflite_common_ffi, shared_preferences mocked;
                           # backend/: real SupabaseClient, simulated HTTP transport (MockClient)
    presentation/          # screens + golden tests (light/dark)
    widget_test.dart       # startup → session flow, theme toggle
  web/                     # index.html, flutter_bootstrap.js, sqlite3.wasm, sqflite_sw.js, fonts
supabase/
  config.toml              # Supabase CLI config (CI only: `supabase db push`)
  migrations/              # versioned SQL, applied to the live project by CI on main (never by hand)
  tests/                   # 00_supabase_stub.sql (auth schema + roles stand-in), *_test.sql
tool/                      # repo tooling, its own small package (tests: `dart test` in tool/)
  hooks/                   # Claude Code hooks (.claude/settings.json): edit_rules.dart (rules),
                           # guard_edit.dart, format_edit.dart, run.sh (launcher)
  smoke/preview_smoke.mjs  # CI smoke test of the deployed preview (Node + Chrome, CDP)
  sql/test_sql.sh          # migrations (twice) + SQL tests on a scratch Postgres, locally and in CI
  test/                    # edit_rules_test.dart — also scans app/, the core and server/
.claude/
  settings.json            # the hooks above
  agents/reviewer.md       # reviewer subagent: diff against the CLAUDE.md rules
server/                    # Dart server (shelf + http, math_core by path) — doc/online.md
  bin/server.dart          # entry point: config from the environment, serve
  lib/src/                 # config.dart (env, secret never printed), http_app.dart (routes, CORS,
                           # JSON errors), supabase_gateway.dart (auth check, database functions),
                           # session_endpoint.dart (POST /v1/sessions: status, state, validate,
                           # apply or reject)
  test/                    # `dart test`
  Dockerfile               # AOT binary in a scratch image; build from the repo root
render.yaml                # Render Blueprint for the server — prepared, inert until the owner acts
```

Monorepo since Phase 2 commit 3 (`doc/decisions.md`).

## Online

Accounts (step 6, slices 1–2): Supabase client in `infrastructure/backend/`, behind
`AccountRepository`/`ProfileRepository`. `AuthGate` requires a signed-in account and swaps the
device `playerId` for the account id (`environmentForAccount`). The session is persisted locally by
Supabase, so no network is needed at launch for a player already signed in. On `ProfileScreen`,
only the player name goes through the network, loaded separately from the local statistics.

## State management

Native `ChangeNotifier` (`flutter/foundation.dart`), no third-party package. `SessionController`
holds an immutable `SessionState` and notifies the UI through `ListenableBuilder`. At the end of a
session it writes the session, its answers and the level updates in one atomic `recordSession`,
asynchronously, without blocking the UI. A failed write is reported on the result screen, which
offers to retry it (`retryPersistence`, same ids — safe because the write is atomic).

`SessionController.abandon()` delegates to `_interruptSession()`, also used for the automatic
interruption after three silent timeouts: one `interrupted` status, two triggers.
`SessionFlowScreen` calls it from a `PopScope` that intercepts leaving while
`status == inProgress` and asks for confirmation.

## Composition root

`lib/composition_root.dart` is the only file choosing concrete implementations (generator,
repository, backend). The local database opens through `openAppDatabase()`
(`infrastructure/persistence/database.dart`), which picks the location and, on web, the SQLite
WebAssembly engine. Screens build no domain object: they observe the resulting controller.

`buildSessionController(environment, enabledTypes)` reads the player's levels from the repository
itself; if a third parameter ever appears, prefer a small configuration object.

## Exercise model

Two enums, two distinct roles:

- **`ExerciseType`** — the selection axis of a session, covers every type of the game. An enhanced
  enum carrying an `OperationType?`: the four arithmetic values reference their operation, the
  others carry `null`.
- **`OperationType`** — strictly internal to `ArithmeticExercise`, a binary operation (+ − × ÷).
  Never extended for a new exercise type (rule 12).

`Exercise` is a `sealed class` exposing `correctAnswer` (typed **`int`**),
`isCorrectAnswer(int)` and `ExerciseType get type`. Each variant names its operands rather than
holding a generic list, and implements `==` / `hashCode`. The domain exposes **no display string**:
`presentation/exercise_prompt.dart` composes the prompt from the fields.

| Variant | Operands | Displayed form |
|---|---|---|
| `ArithmeticExercise` | `operandA`, `operandB`, `OperationType` | `a + b`, `a − b`, `a × b`, `a ÷ b` |
| `PowerExercise` | `base`, `exponent` | base with a raised exponent |
| `SquareRootExercise` | `radicand` (perfect square) | `√a` with a bar over the radicand |
| `PercentageExercise` | `percent`, `base` | `p% of a` |
| `IntegralExercise` | `lower`, `upper`, `c0`…`c3` (p's coefficients; `ck` a multiple of k+1) | `∫` with bounds, the polynomial, `dx` |

The expected answer comes from the domain, never recomputed by the UI or the `Scorer`.

Storage goes through `operands_json`, which absorbs the variants without schema migration. The
stored discriminant is the `ExerciseType` value name.

## Local schema (version 7)

| Table | Content |
|---|---|
| `sessions` | id, player_id, seed, operation_types, exercise_count, total_score, levels_json (levels frozen at start, in hundredths), overall_level_after (nullable, in level units: 37.42; the **main level** — four basics — since schema v9, which recomputed every stored value), created_at, synced_at, kind (`SessionKind.name`: `game`, `placementV1` or `placementV2`, schema v5), type_sequence (JSON list of `ExerciseType` names, one per planned question, schema v6; `null` for an interrupted session from before v6), upload_refused (why the server refused it for good, schema v7; `null` while pending or once synced) |
| `answers` | id, session_id, exercise_type, operation_type, operands_json, submitted_value, is_correct, elapsed_ms, created_at, synced_at |
| `player_levels` | (player_id, exercise_type), level (in hundredths), sessions_played, updated_at — the level cache |

**Levels are integer hundredths** (`math_core/lib/leveling/level.dart`, an extension type over
`int`: 3742 = 37.42) since schema v4 (Phase 1 commit 2), which multiplied every stored level by
100 — the cache and each session's frozen levels. Generation, the score multiplier and the
screens read the whole part (`Level.whole`, truncated); the level update and, later, the
leaderboard use the hundredths. A migrated frozen level's whole part is the old level, so old
sessions regenerate the same questions (checked: the pinned determinism sequences did not
change). Pitfall: `Level` is an `int` at runtime — interpolating one in a string prints the
hundredths; always go through `.whole` or `formatLevelChange`.

`answers.created_at` is the moment of that answer (`AnswerResult.answeredAt`; for a timeout, when
the time ran out) since Phase 0 commit 4; `sessions.created_at` is the end of the session. Answers
stored before that commit carry their session's end time instead — not rebuilt, the true times
are unknown.

Known gap: `submitted_value` is declared `REAL` although every answer is an `int` (stored as a
float, read back with `toInt()`). Harmless; changing a column type in SQLite means rebuilding the
table, so it waits for a migration that is needed for another reason.

## Web first load (measured Phase 0, commit 8)

Release build (`flutter build web`, JS + CanvasKit), cold cache, headless Edge, served locally
with gzip on text types only (a conservative stand-in for GitHub Pages), time to Flutter's
`flutter-first-frame` event:

| Network | First frame | Transferred by the page |
|---|---|---|
| none (localhost) | 1.4 s | 3.25 MiB |
| Fast 4G (9 Mbit/s, 60 ms) | 5.1–5.6 s | 3.25 MiB |
| Slow 4G (1.6 Mbit/s, 150 ms) | 19.4 s | 3.25 MiB |

What loads before the first frame: CanvasKit `canvaskit.wasm` 1.5 MiB (fetched from Google's
CDN `gstatic.com`, Flutter's default), `Inter.ttf` 856 KiB (not compressed by the local server;
450 KiB gzipped), `main.dart.js` 2.8 MiB raw / 840 KiB gzipped, a Roboto font from
`fonts.gstatic.com` (62 KiB), and in the SQLite shared worker — not counted above —
`sqlite3.wasm` 731 KiB (351 KiB gzipped) and `sqflite_sw.js` 256 KiB (77 KiB gzipped). Whole
`build/web`: 43 MB, of which 37 MB are CanvasKit variants the browser picks one of.

**Re-measured on the preview** (Phase 1 commit 0, `https://geriogerg.github.io/Math-Trainer/`,
same method, the browser's real network to GitHub Pages plus the emulated profile; 2–3 runs
each): 2.6–3.3 s unthrottled, 3.4–3.7 s on Fast 4G, 16.0–16.1 s on Slow 4G, 2.86 MiB before the
first frame. GitHub Pages gzips `Inter.ttf` (451 KiB on the wire), the main gain over the local
numbers. Still fetched from Google at runtime: `canvaskit.wasm` 1.5 MiB and `canvaskit.js`
(`www.gstatic.com`), Roboto (`fonts.gstatic.com`) — Phase 1 commit 3. The measured first frame
was the "Missing configuration" screen (CI secrets absent at the time); the bundle is the same.

**Phase 1 commit 3** (self-hosted CanvasKit and fonts, loading screen; preview, same method):

| Network | First frame | Transferred | vs commit 0 |
|---|---|---|---|
| none | 4.1–6.6 s (2 of 3 runs ~4.5 s) | 3.41 MiB | 2.7 s, 2.86 MiB |
| Fast 4G | 4.6 s | 3.41 MiB | 3.6 s |
| Slow 4G | 20.0 s | 3.41 MiB | 16.0 s |

Every request now goes to the site: `canvaskit/chromium/canvaskit.wasm` 2046 KiB (gzip; Google
served it brotli at 1531 KiB), `main.dart.js` 859 KiB, `Inter.ttf` 451 KiB,
`assets/fonts/fallback/Roboto-Regular.ttf` 89 KiB, `canvaskit.js` 27 KiB. Trade-off and levers:
`doc/decisions.md` ("First load"). The loading screen paints within ~150 ms of navigation.

Leads, none applied: subset Inter to Latin (most of its 856 KiB); bundle the Roboto fallback or
stop it being requested (the fonts are meant to be bundled); serve CanvasKit from the site
(`--no-web-resources-cdn`) if the third-party CDN becomes a concern; a loading screen with
progress (plan, section 5).

`navigator.storage.persist()` is requested at startup
(`infrastructure/persistence/persistent_storage*.dart`); headless Edge on a fresh profile
declines it, as Chrome's engagement heuristics predict.

## Dependencies

| Dependency | Reason |
|---|---|
| `flutter` (SDK) | required |
| `material_ui ^1.11.1` | Material widgets, moved out of the SDK in Flutter 3.47 (`package:flutter/material.dart` is deprecated); official Flutter package, every platform — see `doc/decisions.md` |
| `cupertino_icons ^1.0.8` | added by `flutter create` — **unused**, removable |
| `flutter_test` (SDK, dev) | widget tests |
| `flutter_lints ^6.0.0` (dev) | project lints |
| `test ^1.25.0` (dev) | `dart test` on the pure core |
| `sqflite` | local SQLite (rule 3), hand-written schema |
| `path` | cross-platform path joining for the `.db` |
| `shared_preferences` | scalars: device id (adopting pre-account games), theme, type selection |
| `sqflite_common_ffi_web` | the same SQLite on web (WebAssembly + IndexedDB); on mobile `sqflite` replaces it — see `doc/decisions.md` |
| `sqflite_common_ffi` (dev) | repository tests on the Dart VM |
| `supabase_flutter` | Auth + Postgres (`doc/online.md`) |
