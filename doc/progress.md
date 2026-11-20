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

### Remaining contradictions after commit 0

The five plan/reality contradictions found at commit 0 (language, `δ`, branch and remote, commit 0
as a checkpoint, Android in CI) are resolved by plan v1.1. Still open: the repo has no GitHub
remote (owner action), which blocks commits 1 and 2.

Code that does not yet follow the plan, already scheduled: mandatory sign-in versus "offline first"
(Phase 1); one timestamp shared by all answers of a game (commit 4); correct answer not shown after
an error (commit 9).

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
  Fix (`76586ae`): CI's first `sql` run failed on a connection (psql exit 2) — the Postgres
  service container passes its health check before its first-run restart; the runner now
  waits for a real connection and reports failures as annotations.
- **Commit 3** *(A)* — Monorepo, no behaviour change: `lib/core/domain/` → `packages/math_core/lib/`
  (pure Dart, zero dependencies), Flutter app → `app/`, core tests and simulation tools →
  `packages/math_core/{test,tool}/`, root `tool/` a small package (hook-rule tests). Imports
  rewritten to `package:math_core/…`; determinism references regenerated byte-identical. CI:
  `core` job (format, core analyze + VM + Node, tooling tests) on Linux, app tests on Windows,
  web build from `app/`. Tests unchanged in number: core 483 (incl. 13 replay-metric tests
  that were app tests), app 219, tooling 10.
  Fix (`bdc881d`): the SQL runner had CRLF endings (Write tool on Windows): bash on Linux exits
  2 at once. `.gitattributes` now forces LF for `.sh`, `.yml`, `.mjs`, `.js`, `.toml`, `.html`
  and `Dockerfile`. CI then green; the `migrations` job **skipped its apply step**: the
  `SUPABASE_ACCESS_TOKEN` / `SUPABASE_DB_PASSWORD` secrets are not set yet (owner).
- **Commit 4** *(A)*, committed with 3 (same files) — Dart server skeleton: `server/` (`shelf`,
  `http`, `math_core` by path), config from the environment only (secret key refused if
  publishable, never printed), `GET /health`, CORS for the preview's origin, JSON errors without
  details; AOT container (`server/Dockerfile`, scratch image); CI `server` job builds the image
  and checks `/health`. Host **prepared, not deployed**: `render.yaml` (Render free),
  recommendation and steps in `doc/decisions.md` / `doc/online.md` — owner decision.
- **Commit 5** *(A)* — Session upload. Core: `SessionUpload` (JSON codec, strict),
  `SessionUploadClient`, `SessionUploadQueue` (the local database is the queue: pending =
  never synced nor refused, oldest first, one at a time, backoff 30 s → 10 min). Schema v7
  `sessions.upload_refused`; `pendingUploads`, `markSynced` (session and answers),
  `markUploadRefused`, `replaceLevelCache`; `AccountRepository.accessToken`. App:
  `HttpSessionUploadClient`, queue per player in `AppEnvironment.forPlayer`, flushed at
  sign-in and after each session flow; `SERVER_URL` dart-define (repo variable in CI), empty →
  no upload. Server: `POST /v1/sessions` (Supabase Auth check, caller = player, 256 KB cap),
  migration `uploaded_sessions` + `record_session_upload` (idempotent; service role only), SQL
  tests. No server deployed yet: nothing is uploaded by the preview until the owner's host
  decision.
- **Commit 6** *(A)* — Server replay and validation. Core: `validateSessionUpload` (player,
  timestamps, answer count and times, every question regenerated, correctness recomputed, the
  chain of levels, placement rules; level updates replayed; timing flags), level updates
  extracted to `gameLevelUpdates` / `placementLevelUpdates` (the app's orchestrators use them —
  one implementation). Server endpoint: known id → same verdict; state → validate → apply
  (optimistic version, 3 tries) or record the rejection; `levelsMismatch` returns the
  server's levels, which the app adopts. Migration: `server_players`, `server_levels`,
  `upload_rejections`, `upload_flags` (RLS on, no API access), `upload_status`,
  `player_server_state`, `apply_validated_session`, `record_rejected_upload` (service role);
  commit 5's `record_session_upload` dropped. **Forged uploads rejected by tests** (core,
  server); **rows reproduced by replay**: the app-side test above.
- **Commit 7** *(A)* — Tables and access rules, rank and percentile. Migration: internal
  `leaderboard_rows` (eligible players of a board, level, `rank()`, total), and the two public
  readers `leaderboard_top` (≤ 100) and `leaderboard_around_me` (rank, total, top %, ±5
  neighbours, or why not eligible and how many sessions are missing), `security definer`,
  name/rank/level only. Server tables still closed to players; only the server writes. SQL
  tests: 13 players — order, ranks, top %, neighbour windows, every ineligibility reason,
  overall mean, access rules. Eligibility thresholds provisional.
- **Commit 8** *(C)* — Leaderboard screen: the tab's placeholder replaced by
  `LeaderboardScreen` (board chips, "Around me" with "Top N %", rank and ±5 neighbours, "Top
  100", the player's row bold and "(You)", reasons when not on a board, Retry offline, reload
  on every visit), `LeaderboardController`, core models and JSON parsing, Supabase repository.
  Widget tests, goldens (light/dark). **Played at phase end** — and only meaningful once the
  migrations are applied (owner's secrets) and the server deployed (owner's host decision):
  until then the preview's tab shows "Could not load the leaderboard.".
- **Commit 9** *(A)* — Name filter and report action. Rule in core (`displayNameProblem`:
  length, spaces, a character set inside Inter's coverage — Latin incl. Vietnamese, Greek,
  Cyrillic — at least one letter/digit, a short EN/FR blocklist) and in SQL
  (`display_name_problem`, a `NOT VALID` check on `profiles`); parity test (Dart reads the
  migration); font test (reads Inter's `cmap`). Save-progress form and Profile dialog check
  first and say why; a database refusal → "This name is not allowed." Reports: flag button on
  other players' named rows, confirmation, `report_player_name` (one per reporter/player);
  3 reports on the current name → shown as "Player". SQL tests (20 sample names, reports,
  hiding, access). Also: the SQL runner sets `PGCLIENTENCODING=UTF8`.
- **Commit 10** *(A)* — Linked players only: migration replaces `leaderboard_rows` (skips
  anonymous accounts) and `leaderboard_around_me` (`notLinked` first for a guest). The tab tells
  a guest why and offers "Save your progress" (the Profile screen), then reloads. SQL test: a
  guest with the best level is off the board and told `notLinked`; once linked (same id), first.
- **Commit 11** *(A)* — Stale guest cleanup. Server: `cleanup_stale_guests()` (anonymous, older
  than 30 days, no upload **and no renewed sign-in session** in 30 days — the plan's criterion
  plus a guard so guests who play before the server exists are not deleted), daily via
  `pg_cron` (warns if it cannot schedule); stub gains `auth.sessions`; SQL tests (one stale
  guest deleted out of five kinds). Device: `AuthGate` records a guest replaced by another
  account (`AbandonedGuestStore`, shared_preferences); `deleteAbandonedGuests` removes their
  hidden games 30 days later, run at every sign-in.
- **Commit 12** *(A)* — Android compile-only CI: `.github/workflows/android.yml`, a debug APK
  from `app/` with Java 17, every Monday 04:00 UTC, on demand (Actions → Android build → Run
  workflow) and when the workflow file changes. Separate from `ci.yml`: never slows a push,
  never blocks the preview. Its first local run caught real breakage: Flutter 3.50 refuses
  Gradle 9.1.0 and Android Gradle Plugin 9.0.1 (minimums 9.3.1 / 9.1.1). Moved to the versions
  Flutter recommends (Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20); the full build is left to CI
  (a local one takes over 12 minutes and did not finish here). First CI run: **APK built**.

### Phase 2 exit test (19 Nov 2026)

- Rows reproduced by replay: **by tests** — `app/test/state/server_replay_test.dart` (server
  levels after replaying six real sessions = the app's cache), the SQL write path, the
  endpoint. Not live: no server deployed, migrations not applied.
- Forged upload rejected: **by tests** (core: 18 validation cases; server: a forged question
  rejected, recorded, still rejected when resent).
- The owner sees their rank on a phone: **not yet** — needs the migration secrets and the
  server host (owner decisions).
- Also measured, Phase 1's open item: slow 4G on the **real preview**, fresh browser, first
  question **26.5 s** from navigation (target < 30 s; 21.1 s on the local build). The smoke
  script now waits up to 60 s for Flutter (it gave up at 20 s on slow 4G).

## Phase 3a — Build the beta

Plan v2.3 (19 Nov 2026). Entry: Phase 2 live. State at the start:

- The migration secrets are set: the first `supabase db push` ran (CI, `a83e5f2`) and **failed
  before applying any migration** — the live project still has only Phase 1's `profiles` and
  `delete_my_account`. The reason is in the job log only (needs a signed-in reader): CI now
  turns the CLI's last lines into an annotation, secrets redacted.
- The smoke test failed once on CI (`9f48d0c`, reason in the log only) and passes locally on
  the preview (first question 8.8 s): it now annotates its failure reason too.
- Server not deployed yet (`SERVER_URL` unset).

- **Commit 0** *(A)* — Close Phase 2. Leaderboard board chips on one line that scrolls sideways
  (a test pins one line at 360 px and the last board reachable; goldens updated). The owner's
  Phase 2 decisions recorded in `doc/decisions.md` (still provisional: rejection/flag names and
  timing thresholds, the 03:17 UTC cleanup schedule). A Phase 0 section stranded at the end of
  this file moved back; wrong "20 Nov" dates fixed. The migrations job's first live failure,
  read from its new annotation: the latest Supabase CLI pushes to a local stack unless given
  `--remote` (the link to the project worked) — now `db push --remote --yes`.
  First live push of the migrations: **green** (commit 0's CI) — leaderboard functions, name rule
  and server tables answer on the live project; the board is empty until the server runs.
- **Commit 1** *(A)* — Preview host, **prepared, not moved** (the plan: move only after the
  owner's yes). Measured on the live preview: 3,945 KB gzip → 3,024 KB brotli before the first
  question, ~4.6 s less on slow 4G; Cloudflare Pages recommended (`doc/decisions.md`). `ci.yml`
  deploys there, smoke-tests there and turns GitHub Pages into a redirect only when the
  repository variable `PREVIEW_HOST` is `cloudflare`; owner steps in `doc/online.md`.
  `render.yaml` allows the new origin. **Moved on 19 Nov** (owner's yes): the plain
  `math-trainer.pages.dev` belongs to another site, so the project is
  `https://math-trainer-kjc.pages.dev`; CI now reads the project's address and holds back the
  GitHub redirect until `PREVIEW_URL` matches it (`4093772`, `c25cdd9`), and a manual run on
  `main` deploys (`e7b9832`). Re-measured there on slow 4G: every large file brotli
  (`chromium/canvaskit.wasm` 2.06 MB, `main.dart.js` 0.90 MB, `sqlite3.wasm` 0.36 MB), but the
  first question at **24.4 s** (23.1 s on GitHub Pages, one run each): the guest exists only at
  23.2 s, so sign-in round trips at slow-4G latency dominate, not bytes. Online path proven
  there (server levels at 69 s, CORS allows the new origin).
- **Commit 2** *(A)* — Server levels before each game: `syncLevelsBeforeGame` (core; 8 tests:
  adopt, unchanged, pending uploads, failure, timeout…) called by `buildSessionController`, so
  "Play again" is covered too; `my_server_levels()` migration + SQL test (own rows only, anon
  refused); `SupabaseServerLevelsSource`. Refused games say why in Profile (reason stored since
  schema v7, now read into `PersistedSession.uploadRefused`). Numbers: core 556 VM / 551 JS,
  app 251, server 20, 6 SQL test files.
- **Commit 3** *(A)* — Beta gate: migration `beta_codes` (tables, `beta_code_status`,
  `redeem_beta_code`, `create_beta_code`; SQL test 70: normalization, use limit, already,
  disabled, nothing exposed, a deletion frees its use). Core `beta_access.dart`
  (`redeemDeviceBetaCode`, 5 tests); `BetaGateController` + `BetaGateScreen` (goldens);
  `AuthGate` asks before creating the guest, redeems after (4 widget tests). Off until the
  owner sets `BETA_GATE=true` (and `SMOKE_BETA_CODE`); the smoke test enters the code when the
  gate is on — **not verified against a gated build yet** (needs a live code).
- **Commit 4** *(A)* — Privacy notice: `PrivacyScreen` (what is stored, where, why, who sees
  what, deleting it), linked from the gate screen (before any data) and from Profile, above
  the deletion button. Every server table holding player data cascades from the account
  (checked: profiles, uploaded_sessions, server_players, server_levels, upload_rejections,
  upload_flags via sessions, name_reports, beta_code_uses). Tests: sections, the named buttons,
  the 30-day guest retention equal to `abandonedGuestRetention`; goldens.
- **Commit 5** *(A)* — Feedback: migration `feedback` + `send_feedback` (SQL test 80: trimmed,
  stored with the version, 20 a day, unreadable by players, deleted with the account); core
  `feedback.dart`; `FeedbackController` + `FeedbackScreen` from Profile; the build's commit as
  `APP_VERSION` (CI). Tests: controller, repository, the flow from Profile.
- **Commit 6** *(A)* — Owner dashboard: migration `owner_dashboard` (schema the API never
  serves; views for readiness, active testers, sessions per day, testers by code, answer times
  per operation and level band, interruptions, refusals, flags, names to review, feedback;
  `name_reviews` + `review_name`, and `public_display_name` never hides an approved name). SQL
  test 90 checks every count. `tool/dashboard/dashboard.sh` (report, new-code, codes,
  disable-code, approve-name, clear-name, feedback), run by `test_sql.sh` on the scratch
  database. **Not yet run on live data**: needs the owner's connection file.
- **Commit 7** *(C)* — Type placement: rules version 3 and kind `typePlacementV3` (core: the
  staircases follow a stored rotation; replay and shared validation, new reason
  `typeAlreadyPlayed`); `buildSessionController` places never-played operations first; Play
  hint; result screen lists the placed operations; Profile explains the new refusal. Tests: core
  (rotation, staircases, live = replay, the placement test unchanged; 6 validation cases), app
  (only never-played placed, then a game; interrupted comes back; hint), widget flow from Play.
  The smoke test reads the question count (a fresh guest's first Start now places).
  **To play at phase end** (checkpoint *C*).
- **Commit 8** *(A)* — Data check: `owner_dashboard.data_check` (six requirements per uploaded
  answer; SQL test 95 counts each kind of gap), `dashboard.sh data-check` with a verdict and the
  three things not stored at all (input device, app version per session, timeout in force —
  owner decisions, `doc/decisions.md`); a core format test for all seven operations. The smoke
  test now proves the live online path when the build has a server: first run, server levels
  27 s after opening the page (server on Render, found live: the owner deployed it).

### Phase 3a exit test (19 Nov 2026)

- A fresh invited tester goes from the link to a ranked game on a phone: **not yet**. Proven
  without the gate and without ranking: a fresh browser at phone size, on slow 4G, reaches its
  first question in **23.1 s** (26.5 s in Phase 2), plays the first-game type placement, and the
  live server validates it (server levels 65 s after opening, smoke test). Missing: the gate
  switched on (codes, `BETA_GATE`), and a linked account's three games for a rank — owner steps.
- The dashboard report runs on live data: **not yet** — needs the owner's connection file.
  Every command runs in CI on the scratch database. *(19 Nov, later: yes — the owner's
  `data-check` ran on the live project; no real answer uploaded yet.)*
- The owner sends the invitations: owner.

### After the report (19 Nov 2026)

Owner's answers: Cloudflare yes; every provisional decision confirmed (`doc/decisions.md`);
input device and app version to be recorded before the invitations.

- Preview moved (commit 1 above): `e7b9832` (a manual run deploys), `4093772` + `c25cdd9`
  (CI checks the Cloudflare address; `math-trainer.pages.dev` is a stranger's), `44f202a`.
- `e9bd019` Dashboard: the console switched to UTF-8 while psql prints (VS Code's terminal
  showed "—" as garbage).
- Input device per answer, app version per session: core `InputDevice`, `AnswerResult` /
  `PersistedAnswer.inputDevice`, `PersistedSession.appVersion`, optional upload fields (same
  `formatVersion`); app: `SessionScreen` reports each key's source, schema v8; SQL:
  `answer_times_by_input` (replaces `answer_times`), `app_versions`, data check 8 rows.
  Tests: core (combine, round-trip, old payloads, refusals, format test), app (controller,
  keypad/keyboard/mixed in the screen, v8 round-trip and migration), SQL 95.
  **Owner next**: codes, `SMOKE_BETA_CODE`, `BETA_GATE=true`, the phone checklist,
  invitations.

## Phase 5 — Identity

Plan v2.5 (20 Nov 2026), run in one pass **during the beta**. Beta-safety rule: nothing may
change how players answer (keypad geometry, input paths, question order and difficulty, the
15 s timeout, the correction pause, when the next question appears). Owner hand actions, all at
the end: confirm the typeface on the specimen, judge the feel on a phone (sound, haptics,
streak, level-up), add to the home screen on Android and iPhone.

- **Commit 0** *(A)* — Pins. `test/presentation/session_layout_pin_test.dart`, measured with
  Inter loaded, at 412×915 and 360×640, both themes: every keypad cell and its visible key (4 px
  margin), the question's centre (the same for all operations), the empty answer field's top
  and height per operation; a mutation (keypad 301 instead of 300) fails it. Effects moved
  behind `SessionEffects` (`core/effects/`; `HapticSessionEffects` keeps the earlier haptics,
  `AppEnvironment.sessionEffects`): called after the controller has moved on, never awaited,
  every call guarded — a test with effects that throw shows the next question in the same
  frame and the correction pause unchanged (1 s; timeout 15 s). App 293 tests.
- **Commit 1** *(A)* — Digit typeface. The four candidates cut to digits, operators and "of"
  (`tool/fonts/subset_digits.py`, fonttools): all tabular at play size, Sora lacks √; specimen
  screen (`?specimen` on debug and preview builds, `PREVIEW_BUILD` from CI; candidates loaded on
  demand from plain assets, never by a player), goldens in both themes. Provisional pick: **Space
  Grotesk** (`doc/decisions.md`), on the operation, typed answer and keypad. First load +2.7 KB.
  The pins caught two 0.5 px moves (power prompt, mixed-face percentage) — fixed in the code,
  pins unchanged. Goldens of the session and result screens regenerated. Found: the profile
  golden depends on the time of day (0.01 %, passes once regenerated; pre-existing) — debt.
- **Commit 2** *(A)* — Kit (`presentation/kit/`): `AppButton` (primary, secondary,
  destructive, busy), `TypeChip`, `KeypadKey` (moved out of the session screen, pins and session
  goldens unchanged — pixel-identical), `StatTile` (+ `StatTileRow`), `LevelBadge`; tokens
  `radius`, `keyGap`, `controlHeight` in `AppMetrics`. Every screen moved: no
  `FilledButton`/`TextButton`/`FilterChip`/`ChoiceChip` left in `screens/`. Result screen:
  score tile, Right / Wrong / Timed out, Average time / Best streak tiles; Profile, Play and
  Leaderboard levels as badges. Goldens: 10 kit (5 components × 2 themes) + the restyled
  screens. Tests now find levels with `findLevelBadge` (a semantics finder misses badges
  scrolled out of view). App 305 tests.
- *Fix after commit 2* — the smoke test clicked "Delete my data" by the centre of a node only
  half on screen (the Profile grew with the level badges): the click missed, the test account
  stayed (one locally, `41d3e85e…`, probably one from CI; the 30-day cleanup removes them). It
  now clicks only a node whose centre is on screen and on top there. Checked on a local
  release build of commit 2: passed, account deleted.
- **Commit 3** *(A)* — Operator icons: `OperatorIcon` / `OperatorIconPainter` (kit), the
  seven operators as one family; on type chips (check mark before the label when selected),
  Profile operation rows, leaderboard boards. Favicon, `Icon-192/512`, maskable 192/512 and a
  new `apple-touch-icon.png` (180) rendered from the painter by
  `app/tool/icons/render_web_icons_test.dart` (not in the suite). Kit goldens + the family;
  screen goldens regenerated; flow tests press the submit key by its handle (a selected chip's
  check mark is a second `Icons.check`). Also: the specimen's baseline now names Inter (the
  theme's digit styles carry the chosen face). App 307 tests.
- **Commit 4** *(C)* — Sound: `GameSound` (key tick, streak chime, low tone, level-up) in
  `core/effects/`; Web Audio synthesis in `infrastructure/effects/web_audio_game_sound.dart`
  (conditional import, silence elsewhere), unlocked by the first gesture, silent when hidden;
  `AppSessionEffects` plays sound then haptics, the tick for the keypad only
  (`SessionEffects.keyPressed` now takes the device); `EffectSettings` (on by default,
  `SharedPreferences`), Profile's "During a game" → Sound switch. Tests: effects and settings
  (10), the Profile switch (2). Smoke test: counts the tones of its game (11 on a local release
  build; fails at zero). **To play at phase end.**
- **Commit 5** *(C)* — Haptics: `GameHaptics` (`core/effects/`), web via `navigator.vibrate`
  (feature-detected), `HapticFeedback` elsewhere (conditional import);
  `HapticSessionEffects` removed, `AppSessionEffects` now drives both effects, each behind its
  switch; `EffectSettings.haptics` (on by default, stored) and Profile's "Vibration" switch,
  disabled with a reason where the browser cannot vibrate. Tests: effects and settings (11),
  Profile switches (4). Local release build + smoke passed (11 tones). Found locally: an
  incremental `flutter build web` on Windows dropped `web/` files (sqlite3.wasm…) from the output
  — a clean `build/web` fixes it; CI always builds clean. **To play at phase end** (Android).
- **Commit 6** *(C)* — Streak escalation and level-up: `streak_tier.dart` (tiers at 5, 10,
  20; colours from the theme); the streak line (`Text.rich`, its own colour) pulses on reaching
  a tier, the timer bar's colour steps; `AppMotion.pulse` (240 ms). Result: "▲ Level up" mark
  (pulses once), `SessionEffects.levelUp` (sound arpeggio + success vibration) once per result
  (`leveledUp`); reduced motion: no pulse, instant count-up. Result actions in a `Wrap` (they
  overflowed with wide text). Tests: 8 (tiers, colours, pulse and its absence, level-up once,
  none without a whole level, instant count-up); pins and session goldens unchanged.
  **To play at phase end.**
- **Commit 7** *(A)* — Web app manifest: `id`, `scope`, explicit icon purposes; Safari's
  180 px `apple-touch-icon` + `apple-mobile-web-app-capable`; `theme-color` per system theme.
  `test/web_manifest_test.dart` (4: fields, every icon at its declared size, iOS tags,
  favicon). Smoke test: Chrome's installability verdict (local release build: installable,
  11 tones, passed).

### Phase 5 exit test (20 Nov 2026)

- **The layout pins still pass**: yes — `session_layout_pin_test.dart` unchanged since commit 0,
  green at every commit (a keypad 1 px taller fails it; two half-pixel moves were caught and
  fixed in the code). Session goldens unchanged by commits 2–7.
- **Golden tests on every kit component in both themes**: yes — 12 (`AppButton`, `TypeChip`,
  `KeypadKey`, `StatTile`, `LevelBadge`, `OperatorIcon`; dark and light).
- **First load within +50 KB of Phase 3a**: yes — **+16.4 KB** brotli (3,025.2 → 3,041.7 KB:
  `main.dart.js` +12.3, the digit face +2.6, favicon and manifests +1.5), both builds made the
  same way (`0bdf9d9` in a worktree vs `3eaca42`).
- **The owner confirms the typeface and approves the feel on a phone**: owner — the typeface on
  `?specimen`, sound, vibration (Android), streak, level-up, home screen.
- Live: every commit's build reached the preview (its version found in `main.dart.js`), so CI
  passed through deploy each time; the smoke results themselves are not visible to Claude since
  the repository went private. Locally on release builds: smoke passed with 11 tones,
  installable.

## Phase 5.1 — Beta-period groundwork

Plan v2.6 (20 Nov 2026). Runs during the beta; the beta-safety rule of Phase 5 still applies
(`session_layout_pin_test.dart` green at every commit).

- **Commit 0** *(A)* — Close Phase 5. The player's own leaderboard row in weight 500 instead of
  700 (`doc/design.md`: two weights only), still labelled "(You)"; leaderboard goldens
  regenerated. `ProfileScreen.clock`: the profile golden runs at a fixed instant (20 Nov 2026,
  noon UTC) — with the real clock, the recent games' `dd/mm` dates changed every day.
  Plan alignment: the Phase 5 report's six points are all settled by plan v2.6 (timeout not
  stored, section 4, the Cloudflare timing, the typeface wording of section 10, the private
  repository). CLAUDE.md no longer calls the repository public. New, for the owner: section
  10 lists the app name twice and still asks to invite testers "at the end of Phase 3a.1"
  (done); section 4's weakness table says Phase 3 for the level constants (now 3b).
- **Commit 1** *(A)* — First load. (1/2, `9669a70`) Cloudflare serves the large files
  pre-compressed at brotli 11 through a Pages Function (`tool/cloudflare/`): live,
  `canvaskit.wasm` 2,011 → 1,551 KB, `main.dart.js` 901 → 705, `Inter.ttf` 437 → 365,
  `sqlite3.wasm` 355 → 314; right content types, revalidation 304, small files untouched.
  (2/2) The page signs in during the download (refresh or anonymous sign-up where no gate
  asks) and the app waits for it before starting Supabase; server levels read ahead of Start
  (`PrefetchedServerLevels`, 7 core tests + 1 app test); Inter cut to optical size 14 and
  weights 400–500 (174 KB brotli; 16 goldens moved sub-pixel, session goldens and pins not).
  Smoke test: request waterfall (`SMOKE_TRACE=1`); the reload step now expires the session
  and checks the page refreshed it. Local A/B (slow 4G, no gate): 19.0–19.8 s vs 19.8–20.6 s.
- **Commit 2** *(A)* — Strategy detector, core only (`strategies/strategy.dart`):
  `bestStrategy` → one of seven moves (sealed `StrategyMove`, `==`/`hashCode`, each
  recomputing the answer its own way) or `null`. 16 tests on VM and JavaScript: the table's
  seven examples one by one, each rule's edges, the priority when two fit, and every move's
  answer checked over ~100,000 exercises. Thresholds provisional (`doc/decisions.md`).
  Nothing in the app calls it.
- **Commit 3** *(A)* — Structural features, analysis only: `structuralFeatures` (core;
  7 tests VM and JavaScript, incl. carries and borrows against an independent count over
  ~16,000 pairs); the same rules in SQL with views `owner_dashboard.answer_features` and
  `feature_summary`, `dashboard.sh features`; the SQL test's 18 cases run against Dart
  (`structural_features_sql_parity_test.dart`, 19 tests). SQL tests passed locally
  (migrations twice, every dashboard command). Generation untouched.
- **Commit 4** *(A)* — Beta progress, first in `dashboard.sh report`: views
  `owner_dashboard.beta_progress` (completed games and testers against 300 / 10, games per
  tester, median, last 7 days, days to 300 at this pace, beta day) and `tester_activity`
  (every player who uploaded: code label, name, games, interrupted, placements, last game,
  days since). SQL test `97_beta_progress_test.sql` (incl. an empty beta: no division by
  zero). A tester is a player with a completed game, as in `calibration_readiness`.
- **Commit 5** *(A)* — Server-side gate. (1/2, `3288b0b`) `upload_allowed(player)`: a code
  redeemed or an accepted session already; SQL test `98_upload_gate_test.sql`. Pushed first,
  so the function exists before the server asks. (2/2) The server asks it for anonymous
  players before storing anything: 403 `beta_code_required` (retried by the app, never a
  refusal); linked accounts never asked; `BETA_GATE=false` turns it off (Phase 6); `/health`
  reports the switch and the deployed commit. Server tests 20 → 28. Probe
  `server/tool/gate_probe.dart`: a throwaway guest with no code calls the live API directly.

### Phase 5.1 exit test (20 Nov 2026)

- **Pinning tests still pass**: yes — `session_layout_pin_test.dart` unchanged, green at every
  commit; the session screen's goldens never moved (the Inter cut moved 16 other goldens by
  under 0.2 % of their pixels, sub-pixel edges).
- **Slow-4G first question measured (target < 20 s)**: partly. Live preview (gate on, fresh
  browser, slow 4G): the gate screen at **15.1, 15.2, 17.2 s** (three runs). The rest — code
  check, sign-up, Skip, Start — needs an invitation code the script does not have (owner step
  1, `D:\mathtrainer\smoke_code.txt`, not provided yet); from the local traces it takes
  2.5–3 s, so an **estimated 18–20 s**, not measured. Before the phase: 24.4 s to the first
  question (no gate then). Live bytes: `canvaskit.wasm` 2,011 → 1,551 KB, `main.dart.js`
  901 → 705, `Inter.ttf` 437 → 175 (pre-compression + the cut). Local A/B without a gate
  (both at brotli 5): 19.0–19.8 s vs 19.8–20.6 s.
- **Detector and features tested on VM and JavaScript**: yes — 16 + 7 tests on both, plus 19
  SQL-parity tests (VM) and the SQL tests.
- **The report shows beta progress**: yes, against the test database (`test_sql.sh` runs every
  dashboard command); on the live data, the owner's `dashboard.sh`.
- **Server gate**: the live server (`/health`: `cd4e2f4`, gate on, deployed by Render from the
  private repository) answers a code-less anonymous player's direct upload with 403
  `beta_code_required`; the probe's guest deleted. Testers with a code: covered by the CI smoke
  test's upload check on every push (results visible to the owner only).
- Totals: core 631 (VM) / 607 (JavaScript), app 333, server 28; SQL tests passed.

## Phase 5.2 — Staging and online groundwork

Plan v2.7 (20 Nov 2026). Runs during the beta; the beta-safety rule still applies.

- **Commit 0** *(A)* — Close Phase 5.1. (1/2) Plan alignment: v2.7 settled the Phase 5.1
  report's points (Phase 4 item 1, section 8, the risk table, section 10). Still open, for the
  owner: section 4 is "after Phase 5" (tests 582/577/332/20 and 24.4 s — now 631/607/333/28,
  gate at 15–17 s); Phase 7 still lists the duel configuration and Glicko-2, which Phase 5.2
  builds; Phase 6's entry says "Phases 3–5 done" (5.1 and 5.2 now exist); Phase 4 item 4
  (structural features) partly exists since 5.1. (2/2, parked) the live slow-4G measurement
  with the CI beta code: waits for `D:\mathtrainer\smoke_code.txt` (owner step 1).
- **Commit 1** *(A)* — Staging. CI: with `STAGING=on`, staging migrations → staging server
  (deploy hook, waits for `/health`) and site (`math-trainer-staging`, no gate) → full smoke
  on staging → production migrations → production server (hook; skipped when server and core
  are unchanged) → site → read-only smoke on production. Composite actions for migrations, web
  build, Cloudflare deploy; `tool/ci/render_deploy.sh`; `render.yaml` gains the staging service,
  both without automatic deploys; server CORS accepts one-label patterns (`originAllowed`,
  1 test). Smoke test: `SMOKE_READ_ONLY=1` (writes blocked, first screen, installability,
  `SMOKE_EXPECT_VERSION`) — run against production: gate shown, installable, nothing
  attempted; a wrong version fails. `render_deploy.sh` checked against production (unchanged
  server: no deploy). **Parked**: the owner's staging setup (doc/online.md, "Staging"); green
  on staging is verified at the end of the phase.
- **Commit 2** *(A)* — Duel configuration, core only (`duel/duel_config.dart`): fixed quotas
  per type, the level of a rating bracket (15 brackets of 100 points, levels 5–75), the quotas
  shuffled by the seed then drawn by the game's generators on one stream. 10 tests on VM and
  JavaScript: three pinned sequences, determinism, quotas, the bracket alone setting
  difficulty, invalid configurations throwing, strict JSON. No UI.
- **Commit 3** *(A)* — Glicko-2 on the server (`rating/glicko2.dart`), no endpoint: 7 tests —
  Glickman's worked example to the published precision, periods without games (deviation
  grows, capped at 350), symmetry, volatility on upsets, invalid input. Server tests 29 → 36.
- **Commit 4** *(A)* — Legal drafts in `doc/legal/`: privacy policy (what is stored, why and
  on what basis, where, who sees it, how long, rights, the in-app deletion), legal notice
  (publisher, hosts, IP), and a README with the placeholders and five questions for the
  professional review (language, minors, transfers, a private publisher, beta data).
  Written against the migrations and the server; found: the in-app notice does not mention
  the input device, the app version or timing flags — for Phase 6's pages.
