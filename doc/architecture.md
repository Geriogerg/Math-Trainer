# Architecture — Math Trainer

Reference document, **not loaded automatically**. The non-negotiable rules are in `CLAUDE.md`;
this file describes the current state and may lag behind the code. Where they differ, the code is
right — report the gap.

## Tree

```
lib/
  main.dart                # runApp() — async, resolves the environment first; ConfigErrorApp if
                           # the build lacks the Supabase configuration or web storage fails
  app.dart                 # MaterialApp, theme (light/dark/persisted toggle), AuthGate at the root
  composition_root.dart    # the only file choosing concrete implementations (AppEnvironment)
  core/
    domain/                # pure Dart — no Flutter import (rule 1)
      account/             # Account, AccountRepository, PlayerProfile, ProfileRepository (interfaces)
      models/              # Exercise (sealed) and 4 variants, ExerciseType, OperationType,
                           # AnswerResult, SessionConfig, SessionResult
      generation/          # ExerciseGenerator, CompositeExerciseGenerator, per-type generators,
                           # OperandRange, ExerciseSource, LocalExerciseSource,
                           # DebtAwareTypeSelectionStrategy, session_length.dart
      difficulty/          # level → operand bounds per type (arithmetic/power/square_root/percentage)
      leveling/            # LevelUpdater, LevelCacheOrchestrator, LevelingRules, Confidence,
                           # AnswerOutcome — recompute levels from history; overall_level.dart
                           # (overall level, also stored per session)
      scoring/             # Scorer, ScoringRules
      persistence/         # SessionRepository, LocalPlayerIdProvider, TypeSelectionStore,
                           # ThemeModeStore (interfaces), PersistedSession/PersistedAnswer,
                           # LevelCacheEntry, InMemorySessionRepository, uuid.dart, exercise_codec.dart
    state/                 # SessionController (ChangeNotifier), SessionState — the only part of
                           # the core importing Flutter (foundation.dart only)
  infrastructure/
    persistence/           # SqfliteSessionRepository, database.dart (schema, migrations, web
                           # engine), SharedPreferences{PlayerIdProvider,TypeSelectionStore,
                           # ThemeModeStore} — the only place importing sqflite / shared_preferences;
                           # persistent_storage*.dart (navigator.storage.persist, conditional import)
    backend/               # Supabase{Account,Profile}Repository — the only place importing
                           # supabase_flutter (besides composition_root.dart)
  presentation/
    theme/                 # app_theme.dart — light/dark ColorScheme, AppPalette/AppMotion/AppMetrics
    screens/               # AuthGate (mandatory sign-in) + AuthForm, AppShell (tabbed shell,
                           # IndexedStack), PlayTab (type selection + day/night toggle),
                           # SessionFlowScreen/SessionScreen (full-screen session), ResultScreen,
                           # ProfileScreen (identity + statistics, reloads when the tab is shown),
                           # ComingSoonScreen, EmptyState, ConfigErrorApp
    exercise_prompt.dart   # builds the displayed operation from the exercise's fields
    exercise_type_labels.dart
supabase/
  profiles.sql             # `profiles` table + RLS, run by hand in the project's SQL editor
tool/
  recalibrate.dart         # replays stored answers to tune the leveling constants (Phase 3)
  delta_check.dart         # simulated players against LevelUpdater, compares δ / n_min settings
  hooks/                   # Claude Code hooks (.claude/settings.json): edit_rules.dart (rules,
                           # tested), guard_edit.dart, format_edit.dart, run.sh (launcher)
.claude/
  settings.json            # the hooks above
  agents/reviewer.md       # reviewer subagent: diff against the CLAUDE.md rules
test/
  domain/                  # mirrors core/domain — `dart test test/domain`
  state/                   # SessionController — `flutter test` (ChangeNotifier pulls dart:ui)
  infrastructure/          # sqflite via sqflite_common_ffi, shared_preferences mocked;
                           # backend/: real SupabaseClient, simulated HTTP transport (MockClient)
  presentation/            # screens + golden tests (light/dark)
  widget_test.dart         # smoke test + startup → session flow, theme toggle
```

From Phase 2 commit 1 the repo becomes a monorepo (`app/`, `packages/math_core/`, `server/`, see
`doc/online.md`).

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

The expected answer comes from the domain, never recomputed by the UI or the `Scorer`.

Storage goes through `operands_json`, which absorbs the variants without schema migration. The
stored discriminant is the `ExerciseType` value name.

## Local schema (version 4)

| Table | Content |
|---|---|
| `sessions` | id, player_id, seed, operation_types, exercise_count, total_score, levels_json (levels frozen at start, in hundredths), overall_level_after (nullable, in level units: 37.42), created_at, synced_at |
| `answers` | id, session_id, exercise_type, operation_type, operands_json, submitted_value, is_correct, elapsed_ms, created_at, synced_at |
| `player_levels` | (player_id, exercise_type), level (in hundredths), sessions_played, updated_at — the level cache |

**Levels are integer hundredths** (`core/domain/leveling/level.dart`, an extension type over
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
