# Architecture — Math Trainer

Reference document, **not loaded automatically**. The non-negotiable rules are in `CLAUDE.md`;
the decisions and their reasons in `doc/decisions.md`. Regenerated from the code at Phase 6b
commit 8 (27 Nov 2026, review M19); where it and the code differ, the code is right — report
the gap.

## The repository

A monorepo (Phase 2 commit 3): the app and the server import one pure-Dart core by path.

```
app/                       # the Flutter app (web first; Android and iOS in Phase 8)
packages/math_core/        # pure Dart, no dependency at all (rule 1): rules, generation, levels
server/                    # the Dart server on Render: validates uploads, runs duels
supabase/                  # migrations (applied by CI, twice) and SQL tests on plain Postgres
tool/                      # CI scripts, SQL test runner, smoke test, web build steps, dashboard
.github/workflows/         # ci.yml (tests with pinned counts, deploys), android.yml (weekly)
doc/                       # plan.md and levels.md (the owner's), this file, decisions, progress
```

## The core — `packages/math_core/lib/`

```
models/        Exercise (sealed: Arithmetic, Power, SquareRoot, Percentage, Integral),
               ExerciseType (the selection axis), OperationType (inside ArithmeticExercise
               only, rule 12), SessionConfig, SessionKind, GameSetup, AnswerResult, InputDevice
tiers/         Tier (T0–T9), fluent times, each version's tier tables (arithmetic, long
               arithmetic, power, percentage, integral), QuestionSpace (v9: distinct questions,
               listed or drawn, OperationDraws), standard_v9.dart, GameDraws (ContentDraws for
               v2–v8, DrawsV9), TieredGameGenerator, tip bands
patterns/      PatternFamily (49), pattern questions v4 and sized (v5+), pattern_spaces_v9.dart
generation/    gameExerciseGenerator (one per game: v9 remembers what it asked), question_plan
               (questions per operation, the shuffled type sequence), exercise sources
leveling/      Level (integer hundredths), LevelRules.of(rules), RulesVersion (v1 retired,
               v2–v9 replayed, v9 current), gameLevelUpdates and gameQualities (the one
               implementation, app and server), main level, level changes
method/        methodFor (spec section 9): blocks, families, fallbacks (part files), Method,
               MethodFallback, offersMethod
strategies/    Strategy: the detector weak spots key on
weak_spots/    facts and skills, the five-box scheduler rebuilt from history
               (scheduleFromHistory), belongsTo / weakSpotOperationCap per rules, practice
               (Weak spots, Drill), worst facts
replay/        replaySessionQuestions and replaySessionPatterns: a stored session's questions
               from what it stores alone
validation/    validateSessionUpload: the server's checks (replay, timing, chaining, flags)
scoring/       Scorer
sync/          SessionUpload, SessionUploadQueue (one at a time, oldest first), server levels
               (syncLevelsBeforeGame, PrefetchedServerLevels), UploadAttemptLog
persistence/   SessionRepository (async, rule 4) and its in-memory version, PersistedSession,
               PersistedAnswer, level cache, stores' interfaces (setups, selection, player id)
duel/          DuelMode, DuelConfig (content from rating, seed and rules), DuelRun, duel
               validation, Glicko inputs (duel_rating), DuelRunQueue, OnlineOverview,
               the practice lane
friends/       friend codes, requests, history
leaderboard/   boards, standings, NotRankedReason
challenges/    Get the count, Chain operations, Tables mode, their stats
account/       Account, AccountRepository, profiles, the name rule (display_name.dart, twin of
               SQL display_name_problem), beta access
difficulty/    structural features (twin of SQL owner_dashboard.structural_features)
feedback/      the beta's feedback
```

## The app — `app/lib/`

Strict layers (rule 7): `core/` holds state and interfaces, `infrastructure/` their
implementations (storage, network, web), `presentation/` the screens. `composition_root.dart`
alone picks implementations (rule 15).

```
main.dart                   ensureSemantics, buildAppEnvironment, the start's catch-all
app.dart                    MaterialApp, themes, AuthGate
composition_root.dart       AppEnvironment (forPlayer: everything a player's screens use),
                            buildAppEnvironment, builders of every controller, level sync
core/state/                 ChangeNotifier controllers: SessionController (a game), duel, count,
                            chain, online, friends, leaderboard, account forms, beta gate,
                            feedback; UnfinishedGameStore, HintsStore, LevelsRefresh
core/effects/               SessionEffects (sound, haptics: fire and forget), settings
core/sharing/               LinkSharer
infrastructure/backend/     Supabase repositories (accounts, profiles, boards, online reads,
                            friends, beta codes, feedback, server levels) over one
                            TimeLimitedClient (15 s); HTTP clients of the Dart server (uploads,
                            duels)
infrastructure/persistence/ SQLite (database.dart, schema 13; web: WebAssembly + IndexedDB),
                            shared_preferences stores, persistent storage request
infrastructure/effects/     Web Audio synthesis, vibration
infrastructure/web/         the page's boot sign-in, page reload (conditional imports)
presentation/screens/       AuthGate, AppShell (Play, Online, Profile, Ranks), Home and setups
                            (play_tab), the game, its result, Get the count, Chain, Tips,
                            Profile, Ranks, Online, Friends, sign in, save progress, legal pages
presentation/duel/          a duel's flow, lanes, result, rules sheet
presentation/kit/           the only buttons, cards, chips, keys, badges, captions screens use
presentation/strings/       every word a player reads (Phase 6b commit 7; a guard test)
presentation/theme/         themes, metrics, motion, the digit face
```

## The server — `server/`

`bin/server.dart` starts `lib/server.dart` (`buildServerHandler`): CORS, the rate limits
(`rate_limit.dart`), and the endpoints — `session_endpoint.dart` (`/v1/sessions`: replay and
validate an upload, then `apply_validated_session`), `error_endpoint.dart` (`/v1/errors`: the
app's error reports, masked, no account — Phase 6c), `duel_endpoint.dart` (the HTTP surface of
`/v1/duels…`; the work in `duels/`: matchmaking, runs, abandonment sweeps, ratings, JSON) and
`/health` (commit, rules versions, session kinds, duel modes and rules). `rating/` is Glicko-2.
It talks to Supabase as `service_role` through `supabase_gateway.dart` (RPC only). `tool/`
holds `postgrest_shim.dart` (the integration job's stand-in for PostgREST) and the gate probe.

## Supabase

46 migrations (`supabase/migrations/`), each idempotent; the tables are closed to the API, which
reaches data through `security definer` functions (`public`) and the owner's views
(`owner_dashboard`, read by `tool/dashboard/dashboard.sh`, locally only). 29 SQL test files
(`supabase/tests/`, run by `tool/sql/test_sql.sh`; `99m_catalogue_test.sql` lists every
callable function). Boards are cached a minute (`board_rows`). A saved account is not
anonymous **and** has its email confirmed (Phase 6c). `supabase/templates/` holds the emails,
generated from `Brand`.

## How a game flows

1. **Home → Start**: `buildSessionController` syncs levels with the server when nothing waits
   to be sent (`syncLevelsBeforeGame`), adds due weak spots, freezes the levels and draws the
   type sequence; `gameExerciseGenerator(rules)` makes the questions (v9: no repeat while the
   tier has unused ones).
2. **Playing**: `SessionController` times answers on a monotonic clock, keeps a Levelling game
   after every answer (`UnfinishedGameStore`), and at the end writes session, answers and level
   updates in one `recordSession`.
3. **Sending**: `SessionUploadQueue` uploads one session at a time to `/v1/sessions` once
   `/health` lists its rules and kind; the server replays it, checks it and applies it.
4. **Boards** read `leaderboard_*` functions straight from Supabase; levels come back through
   `my_server_levels` (at sign-in and before a game).

A duel: Online → rules sheet → `DuelFlowScreen` wakes the server (`/health`), then `find` /
`open` → `DuelController` saves its progress before telling the server (`DuelRunQueue`) →
`/v1/duels/run` replays the run, rates both sides.

## Rules versions and generation

`RulesVersion` is stored with each session; the server replays a session under its own rules.
v2–v8 draw each question on its own (`ContentDraws`), v9 (current, `doc/levels.md` v1.6) through
a per-game memory (`DrawsV9`, `OperationDraws`) over `QuestionSpace`s. Every version's questions
are frozen by reference files (`test/tiers/tier_references*.dart`) and the spec test reads the
live `doc/levels.md`. The next change to generation is v10.

## State management

Native `ChangeNotifier`, no third-party package; screens observe through `ListenableBuilder`.
`SessionController` holds an immutable `SessionState`; a failed final write is offered again on
the result screen (`retryPersistence`, same ids). One `interrupted` status for ✕, three silent
timeouts and a closed tab (the kept game, stored at the next start).

## The exercise model

| Variant | Operands | Displayed (spoken) |
|---|---|---|
| `ArithmeticExercise` | `operandA`, `operandB`, optional `operandC` (a third addend), `OperationType` | `a + b`, two lines when too wide; ÷ always one line ("47 times 8") |
| `PowerExercise` | `base`, `exponent` | base with a raised exponent ("12 squared") |
| `SquareRootExercise` | `radicand`, `index` (2 or 3) | `√` with a bar; a small 3 for a cube root ("the cube root of 27") |
| `PercentageExercise` | `percent`, `tenths`, `base` | `37.5% of 64` ("37.5 percent of 64") |
| `IntegralExercise` | `lower`, `upper`, `c0`…`c4` (`ck` a multiple of k+1) | `∫` with bounds, the polynomial, `dx` |

The expected answer is an `int` from the domain (rule 9); the display and its spoken words come
from `presentation/` (`exercise_prompt.dart`, `strings/spoken_prompt.dart`). Answers store
their operands as `operands_json`, discriminated by the `ExerciseType` name.

## Local schema (version 14)

| Table | Content |
|---|---|
| `sessions` | id, player_id, seed, operation_types, exercise_count, total_score, levels_json (frozen levels, hundredths), overall_level_after (the main level after, level units), created_at (the session's **end**), synced_at, kind (`SessionKind.name`), type_sequence (planned types, v6), upload_refused (v7), app_version (v8), rules_version (v10; NULL = v1), weak_spots (item keys, v13) |
| `answers` | id, session_id, exercise_type, operation_type, operands_json, submitted_value (INTEGER since v14; REAL before), is_correct, elapsed_ms, created_at (that answer's moment), synced_at, input_device (v8) |
| `player_levels` | (player_id, exercise_type), level (hundredths), sessions_played, updated_at — the level cache, recomputable from history |

## Web delivery

Cloudflare Pages, deployed by CI after the tests: the build's large files are content-hashed
(`main.<hash>.dart.js`, `canvaskit/<hash>/`) and served from brotli copies; security headers
come from `tool/web/security_headers.mjs`. `index.html` paints a loader at once (progress from
resource timing, Reload after 40 s or on a failure) and signs the player in while the files
download (`window.mtBootAuth`). Slow 4G reaches the gate screen in about 15–17 s and a first
question in about 20–23 s (Phase 5.1 measurements, `doc/progress.md`).

## Dependencies (app)

| Dependency | Why |
|---|---|
| `flutter`, `material_ui` | the framework; Material widgets (moved out of the SDK in Flutter 3.47) |
| `sqflite`, `sqflite_common_ffi_web`, `path` | local SQLite (rule 3); on the web through WebAssembly |
| `shared_preferences` | small stores (setups, hints, the kept game, pending duel runs) |
| `supabase_flutter` | accounts and reads |
| `http` | the Dart server's endpoints, and the Supabase client's time limit |
| `math_core` (path) | the core |
| dev: `flutter_test`, `flutter_lints`, `test`, `sqflite_common_ffi` | tests, lints, repository tests on the VM |

The server depends on `math_core`, `shelf` and `http`; the core on nothing.
