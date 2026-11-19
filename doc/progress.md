# Progress — Math Trainer

Commit log by phase. One line per commit, appended after each commit (`CLAUDE.md`, "How a phase
runs"). Commits before the plan of 18 Nov 2026 are grouped by the old step numbering; their
messages are in French.

## Before the plan (steps 1–6)

### Step 0–1 — MVP and core tests (8 Aug 2026)
- `4eb9634` Flutter scaffold and MVP.
- `219ef83` Core tests consolidated, two fixes.
- `dac997d` CLAUDE.md: state management, tree, dependencies, roadmap.

### Step 2 — Local persistence (8 Aug)
- `f28e2b6` SQLite via `sqflite` + `shared_preferences`.
- `4d7b301` Docs.

### Step 3 — Seven exercise types (8 Aug)
- `2e9d921` A: answer contract `num` → `int`.
- `e379b53` B: powers, square roots, percentages in the domain.
- `e59da25` C: config and UI, exercise type selection.
- `ba5606f` Docs.

### Step 4 — Level system (10 Aug)
- `8941d28` A: last `assert` → `throw` (rule 13).
- `30c1c1e` B: level update in the pure domain.
- `7ab7bc7` C: difficulty derived from the level.
- `a7abe3a` D: levels persisted (schema v2).
- `da32156` E: difficulty-weighted score, progress screen.

### Step 4.1 — Fixes (10–11 Aug)
- `1a316ee` A: guaranteed sampling. `e2f685c` B: endless spinners. `4f4c494` C: decoupled
  session persistence. `2444c8c` D: `LevelCacheEntry`, `LevelCacheOrchestrator`. `fccf7e8` E:
  recalibration script. `d64f9c2` Post-review fixes.

### Step 5 — Visual direction "nuit électrique" (11–13 Aug)
- `ea1d4cb` Docs (design, architecture, decisions).
- `a726597` Central theme. `6018353` `Exercise.prompt` removed. `997a906` Maths rendering.
  `30f8bb3` Built-in keypad. `99399fd` Navigation, progress screen, golden tests. `2bda9e2` Darker
  dark palette. `88e5066` Docs.
- `7373a26` Audit defects (PopScope, empty states). `6b3de21` Theme consistency. `1ebd42b`
  Aggregated reads. `f72ea15` Result screen. `6968afc` Progress screen. `05eed02` Streak,
  transitions, result golden.
- `976df5c`, `98db14d`, `30d2fe9`, `93524c5` UX fixes: result clarity, persisted selection, dark
  palette, day/night toggle, overall level over 7 types.

### Step 4.2 — Session loop (12 Aug)
- `1f8b891` A: volume-weighted step, `n_min` 8 → 4, `δ` 0.05 → 0.07 (not approved by the owner).
- `010abe6` B: per-question timeout, interruption on abandonment.
- `4791321` C: immediate replay. `d00c47a` Docs.

### Step 6 — Accounts (13 Aug – 18 Nov)
- `0d884c1` Slice 1: sign-up and sign-in (Supabase).
- `7400f9b` Slice 2: mandatory sign-in, player name, Profile tab; app working again on web.
- `7de0d4a` Sign-in errors translated, failed name save reported.
- `49f634b` Product review: physical keyboard, game lost on close, web feedback.
- `94e785f` Levels and history bound to the account.
- `b1ff31c` Profile curve on the overall level after each game; retry a failed save.
- `18fb220` Web persistence: SQLite in WebAssembly (IndexedDB).

State at the plan: 49 commits, 176 core tests / 328 in total.

## Phase 0 — Stabilise and build the web pipeline

- **Commit 0** *(C)* — Docs aligned with `doc/plan.md` and moved to English: `CLAUDE.md`,
  `doc/online.md`, `doc/decisions.md`, `doc/architecture.md`, `doc/design.md`; this file created;
  `doc/plan.md` committed. Owner decisions recorded: English everywhere, Android not a concern until
  Phase 8. Checkpoint: the owner reads the docs.
- *Owner request, outside the plan* — Interface text in English: every screen, the web page
  title and description, tests and golden images.
- *Owner request, outside the plan* — Code comments, error messages, test names, tool,
  `supabase/profiles.sql` (policies renamed, old names dropped) and config comments in English.

- *Owner request* — `doc/plan.md` v1.1, edited at the owner's request: English-speaking audience,
  Android out of CI until Phase 8, `δ` = 0.07 recorded as unapproved, commit 0 read rather than
  played, no GitHub remote yet.

- **Commit 1** *(A)* — CI on GitHub Actions (`.github/workflows/ci.yml`): core tests, all tests,
  analyzer (`--no-fatal-infos` until commit 3) on Windows, where the golden images are recorded;
  web build on Linux with the Supabase settings from repository secrets. No Android build (plan
  v1.1).
- **Commit 2** *(A)* — Preview on GitHub Pages, `https://geriogerg.github.io/Math-Trainer/`: the
  web job builds with `--base-href /<repo>/` and uploads the site on pushes to `main`; a `deploy`
  job publishes it once tests and build are green. Host chosen because it needs only GitHub (repo
  public, free plan). Sub-path build checked locally in a real browser: database opens, sign-in
  shows.
- **Commit 3** — *parked*: needs the owner's yes on the new `material_ui` dependency. Done in
  Phase 1 commit 0.
- **Commit 4** *(A)* — One timestamp per answer, **no schema migration**: `answers.created_at`
  already existed and was filled with the session's end time. `AnswerResult` gains `answeredAt`
  (UTC, refused otherwise), set when the answer is submitted or the time runs out, stored as the
  answer's `created_at`. Older rows keep their session time. `submitted_value REAL` left as is.
- **Commit 5** *(A)* — `δ` checked against `n_min` = 4 with `tool/delta_check.dart` (simulated
  players, real `LevelUpdater`). `δ` was widened (0.07); no new value proposed — keeping 0.07 is
  recommended, the owner confirms. Findings in `doc/decisions.md`: `n_min` = 4 oscillates ±2.4
  levels against ±1.5 designed; integer rounding, not `δ`, dominates the dead band; `δ` ≥ 0.133
  would freeze progress; convergence takes 45–90 sessions against a 10–20 target. Also: the last
  French column headers of `tool/recalibrate.dart` translated.
- **Commit 6** *(A)* — Debug-only switch `--dart-define=DEBUG_NO_TIMEOUT=true`:
  `SessionController.questionTimeout` becomes nullable (no timer, no abandonment interruption,
  timer bar stays full). `questionTimeoutFor` in `composition_root.dart` honours the switch only
  when `kDebugMode`, a compile-time `false` in profile and release builds; tests cover the four
  cases, the controller without a timer and the full bar.
- **Commit 7** *(A)*, in two parts. `de338fa`: the whole repo formatted with `dart format` (77 of
  133 files were not; listed in `.git-blame-ignore-revs`). Then: Claude Code hooks in
  `.claude/settings.json` — PreToolUse refuses `assert(` in `lib/core/` and unseeded `Random()` in
  `lib/` and `test/` (`tool/hooks/edit_rules.dart`, tested, including a scan of the current code);
  PostToolUse formats each Dart file written; `tool/hooks/run.sh` uses the SDK's Dart VM (about
  1.4 s per Dart edit, against 3 s through the `dart` wrapper) and skips non-Dart files. Reviewer
  subagent `.claude/agents/reviewer.md` (read-only, CLAUDE.md rules as checklist). CI checks
  formatting. The hooks load only when Claude Code starts in `math_trainer/`; not yet seen
  running live (they load at session start).
- **Commit 8** *(A)* — Persistent storage requested at startup, not awaited
  (`requestPersistentStorage`, `dart:js_interop` behind a conditional import, a stub elsewhere;
  no new dependency). First load measured locally (`doc/architecture.md`, "Web first load"):
  3.25 MiB before the first frame plus ~1 MiB for the SQLite worker; first frame 1.4 s on
  localhost, ~5.3 s on Fast 4G, 19.4 s on Slow 4G. Found: CanvasKit and a Roboto font come from
  Google's servers at runtime; `Inter.ttf` is 856 KiB. To re-measure on the preview once it is
  deployed.
- **Commit 9** *(C)* — Correction pause: after a wrong answer or a timeout (not on the last
  question), `SessionState.correction` keeps the question on screen with its correct answer and
  "Your answer: X" / "Time's up" for 1 s (`correctionDelay`, set by the composition root); no
  timer, input ignored, the next question's clock starts after it. Mistakes review on the result
  screen; its actions pinned at the bottom so a long list never hides "Play again". Golden images:
  session and result updated, correction and mistakes added (both themes). **Checkpoint: the
  owner plays 5 games on a phone** — not deployable until GitHub Pages is enabled.

Phase 0 closed in Phase 1 commit 0 (`material_ui`, `δ` recorded, preview, load).

## Phase 1 — First run and accounts

- **Commit 0** *(C)* — Close Phase 0. `material_ui` migration (owner's yes): `material_ui ^1.11.1`
  added, 28 imports moved by `dart fix --apply --code=migrate_design_widgets`, no widget or
  golden image changed, analyzer at zero notices, CI's analyzer back to fatal infos. `δ` = 0.07
  recorded as the owner's decision. Plan v2.1 and the owner's `CLAUDE.md` rewrite committed.
  Preview: live, but **built without the Supabase settings** — the `SUPABASE_URL` and
  `SUPABASE_PUBLISHABLE_KEY` repository secrets are missing, so it shows "Missing
  configuration". Same check on a local release build at `/Math-Trainer/` against the real
  Supabase project, with one anonymous user created through the auth API
  (`e188e86d-…`, to delete once commit 7's function exists): app shell, a full 8-question game
  with correction pauses and mistakes review, reload, Profile still showing the answers. Load
  re-measured on the preview: 2.7 s / 3.6 s Fast 4G / 16.0 s Slow 4G (`doc/architecture.md`).
  **Waiting: the owner adds the two secrets, then plays 5 games on a phone.** Also found: the
  owner's GitHub-template `.github/workflows/dart.yml` fails on every push (plain `dart pub get`
  cannot resolve a Flutter project) and duplicates `ci.yml`.

- *Owner decisions* (`890cee9`) — one pass with stops only where necessary; new screens in
  English; `.github/workflows/dart.yml` removed. Secrets added by the owner.
- **Commit 7 (1/2)** (`891822e`) — `supabase/delete_account.sql` written first, for the owner to
  run during the phase.
- **Commit 1** *(A)* — Cross-platform determinism: `test/domain/determinism/` pins 144 session
  sequences, 12 endless sequences and a 5,040-update `LevelUpdater` grid, generated on the VM by
  `tool/determinism_references.dart`; **identical on Node (dart2js), 158/158**. CI runs the core
  on the VM and `-p node`. UUID test excluded from Node (dart2js `Random.secure()` bug under
  Node 24; passes in Edge). Found: sequences depend on `sessionsPlayedByType`, not stored with
  the session — for Phase 2.

- **Commit 2** *(A)* — Continuous levels: `Level` (integer hundredths, extension type), update
  rounded once to hundredths, generation and display on the whole part; schema v4 migrates
  `player_levels.level` and `sessions.levels_json` ×100. Pinned sequences unchanged; level grid
  regenerated. Simulation rerun: oscillation ±1.95 (was ±2.4), convergence from level 1 64
  sessions (was 45) — placement (commit 6) or Phase 3 constants. Result screen shows the change
  in hundredths (provisional). Bug caught by goldens: `levels[type] ?? 1` printed "level 1200".

- **Commit 3** *(A)* — First load: CanvasKit from the site (`--no-web-resources-cdn`), fonts
  from the site (Flutter's bundled Roboto; `fontFallbackBaseUrl` → `fonts/`, so Noto never
  reaches Google), HTML/CSS loading screen with resource-driven progress, OFL licences shipped.
  Preview: zero requests off-origin; first frame Fast 4G 4.6 s (was 3.6), Slow 4G 20.0 s (was
  16.0): Pages gzips CanvasKit where Google served brotli (+0.55 MiB). Levers recorded, none
  applied. Non-Latin player names would render as boxes (Phase 2 decision).

- **Commit 4** *(A)* — Anonymous-first: `Account.isAnonymous` (email optional),
  `AccountRepository.signInAnonymously()`; `AuthGate` creates a guest when no session exists
  (once, after the local session resolves), retry screen on failure; sign-out hidden for guests.
  Checked in a release build against the real project: fresh browser → guest created (one
  `signup`), straight to Play, a game, reload → same guest, no new account, history kept.
  Guest `8bec648d-…` created by that check (to delete with commit 7). `AuthForm` unused until
  commit 5.

- **Commit 5** *(C)* — Linking and account screens: Profile offers a guest "Save your
  progress" (email, password, player name → `linkEmail`, one atomic `updateUser`, same id) and
  "I already have an account" (`SignInScreen`, warning when the guest has played); taken email
  → "Sign in to that account instead". `AccountFormController` holds the flow; `signUp` and
  `AuthForm` removed. Server behaviour probed on the real project with two throwaway guests
  (`fb154e14-…` now linked to `mt-link-check-…@example.com`, `7969cb24-…`), to delete with
  commit 7. **Played by the owner at phase end.**

- **Commit 6** *(C)* — Placement test: `core/domain/placement/` (staircases in integer
  hundredths, `placementLevels`, `PlacementExerciseSource` adaptive and deterministic,
  `replayPlacementQuestions` for the server, `PlacementLevelOrchestrator`); schema v5
  `sessions.kind`; offered on Play to a player with no session ("Find my level" / "Skip");
  "finding your level" during it; starting levels on the result. Parameters chosen by
  `tool/placement_check.dart`, provisional: start 35, first step 25, pass ≤ 3 s, calibration
  kept. Placed player at level in 5.5 games (w 6) / 18.9 (w 10) against 65.5 / 73.5 without.
  48 placement sequences pinned VM = JavaScript. `ExerciseSource.onAnswered`,
  `SessionLevelUpdates` interface, `exerciseGeneratorFor` made public (no sequence changed).
  Walked in a release build (guest `7ea74633-…` created). **Played by the owner at phase end.**

- **Commit 7 (2/2)** *(A)* — Account deletion, app side: `deleteAccount` (RPC),
  `deletePlayerData` (SQLite and in-memory, atomic), `AccountDeletionController` (server →
  device → sign-out; nothing touched if the server refuses), Profile "Delete my data" /
  "Delete my account" with confirmation. Unit- and widget-tested. **Parked: live check** —
  `delete_my_account()` not installed in the project yet (PGRST202 on 19 Nov 2026); once the
  owner has run `supabase/delete_account.sql`: delete one of the throwaway guests through the
  app, and the probe accounts `8bec648d-…`, `e188e86d-…`, `fb154e14-…` (linked),
  `7969cb24-…`, `7ea74633-…`.

- **Commit 8** *(A)* — Smoke test on the preview, `smoke` job after `deploy`
  (`tool/smoke/preview_smoke.mjs`: Node 22 + the runner's Chrome over CDP, no dependency):
  fresh browser → guest → skip placement → full 8-question game → reload → history in
  Profile → "Delete my data". Finds widgets through Flutter's accessibility tree. Reports
  the app's own failure message and any guest left behind; screenshot as CI artifact.
  `SMOKE_NETWORK=slow4g` measures the exit test: **first question 21.1 s** from navigation on
  emulated slow 4G, local gzip build (preview pending the key secret). Local runs left guests
  `58c28fa0-…`, `c655e665-…`, `4d09177b-…` (deletion function not installed). **The job fails
  until the owner adds `SUPABASE_PUBLISHABLE_KEY` and runs `supabase/delete_account.sql`.**

## Phase 2 — Server and leaderboard

- **Commit 0** *(A)* — Close Phase 1 with the owner's decisions. Placement **version 2**
  (`placementRulesV2`, `SessionKind.placementV2`; v1 kept and still replayable): 5 questions
  per operation, pass time per operation at 1.5 × `t_rapide` (equal for the four today: one
  `t_rapide` in `LevelingRules`). Simulation rerun: median ~81 s, games to ±3 5.6 / 20.0.
  Offer on Play only without a **completed** session and without a remembered skip
  (`PlacementSkipStore`); "Find my level" in Profile until a session is completed; no type
  selection flash (Play draws nothing until its local read resolves). Result screen: whole
  level and a bar inside it, no more "(+2.76)" (`level_format.dart` removed). 48 placement v2
  sequences pinned (v1 references unchanged). `SessionRepository.hasCompletedSession`.
  **Parked: test accounts** — deleted once `delete_my_account()` is applied by CI (commit 2).
- **Commit 1** *(A)* — Self-contained sessions: every session stores its type sequence
  (schema v6 `sessions.type_sequence`; complete old sessions backfilled from their answers,
  interrupted old ones stay `null`). Games are generated through `FixedTypeSequence` (same
  questions as the debt strategy). `replaySessionQuestions` regenerates a stored session from
  what it stores alone; a test plays real sessions into SQLite and replays each in isolation.
  `answersForSession` ordered by `rowid`. No pinned sequence changed.
- **Commit 2** *(A)* — SQL migrations from CI. `supabase/profiles.sql` and
  `supabase/delete_account.sql` became `supabase/migrations/2026111{7,9}…`; a third migration
  deletes the eight Phase 1 test accounts by id. CI `sql` job: every migration applied twice
  to a scratch Postgres 17 with a Supabase stand-in (`supabase/tests/00_supabase_stub.sql`),
  then SQL tests (profiles RLS, `delete_my_account()`). CI `migrations` job on `main`:
  `supabase link` + `supabase db push` with the `SUPABASE_ACCESS_TOKEN` / `SUPABASE_DB_PASSWORD`
  secrets; `deploy` waits for it. Also seen: the smoke test is **green on the preview** since
  commit 0 — the owner fixed the key secret and installed `delete_my_account()`, so Phase 1's
  parked live deletion check passed (the smoke guest deletes itself).

### Remaining contradictions after commit 0

The five plan/reality contradictions found at commit 0 (language, `δ`, branch and remote, commit 0
as a checkpoint, Android in CI) are resolved by plan v1.1. Still open: the repo has no GitHub
remote (owner action), which blocks commits 1 and 2.

Code that does not yet follow the plan, already scheduled: mandatory sign-in versus "offline first"
(Phase 1); one timestamp shared by all answers of a game (commit 4); correct answer not shown after
an error (commit 9).
