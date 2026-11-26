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

### Phase 5.2 exit test (20 Nov 2026)

- **Smoke green on staging and production**: production yes, staging not yet. The
  restructured CI deployed production twice with `STAGING` unset (`352f1d5`, `2d54fbb` live);
  the read-only visit on production at `2d54fbb`: gate shown, installable, this build served,
  no write attempted. Staging waits for the owner's setup (doc/online.md, "Staging"): no
  staging run has happened, so the staging half is unverified.
- **Production untouched by tests**: only once `STAGING=on`. Until then CI's production smoke
  still plays the full visit (an account created and deleted in production), as before.
- **Duel configuration and Glicko-2 tested**: yes — 10 tests VM and JavaScript (three pinned
  duels); 7 server tests incl. Glickman's worked example.
- **Legal drafts ready for review**: yes — `doc/legal/`.
- **Commit 0's measurement** (slow-4G first question with the CI beta code): not done — no
  code file yet.
- The production server stays at `352f1d5` (Render deployed it by itself before the Blueprint
  took `autoDeploy: false`); later server commits (Glicko-2, unused at runtime) wait for the
  production deploy hook.
- Totals: core 641 (VM) / 617 (JavaScript), app 333, server 36; SQL tests unchanged.

## Redesign phase — Game modes and new interface

Plan v2.9 (22 Nov 2026), reference screens `doc/mockups/redesign.html`. The beta-safety rule is
lifted for this phase.

- **Commit 0** *(A)* — Owner decisions recorded in `doc/decisions.md` ("Redesign phase — owner
  decisions"), with the entries they supersede marked; gaps filled provisionally (contrast
  tones, "Ranks", the theme toggle in Profile, level 1 for a never-played operation, the
  wordless correction pause). Beta-safety pins lifted: the pin test's header and the CLAUDE.md
  pitfall say they are re-measured once at commit 6. `doc/plan.md` v2.9 and the mockups
  committed; CLAUDE.md's "Current phase" is the Redesign phase.
- **Commit 1** *(A)* — Level structure. Core: `ExerciseType.family` and `ExerciseFamily`
  (basics, advanced); `overall_level.dart` → `main_level.dart`: `mainLevel` is the mean of the
  four basics (unplayed = 1), `mainLevelsAfter` rebuilds each session's main level by walking
  history back from the level cache (a completed game restores its frozen levels, a completed
  placement removes the levels it created, an interrupted session moved nothing);
  `LeaderboardBoard.main()` (server key still `overall`). App: schema v9 recomputes every
  stored `overall_level_after` with it (a player whose rows do not parse keeps old values);
  Home, Profile and the leaderboard say "Main level" / "Main"; `sessionFromRow` moved to
  `session_rows.dart` for the migration. SQL: `leaderboard_rows` ranks the main board on the
  four basics (`20261124000000_main_level.sql`); per-operation boards unchanged, and every row
  is computed at read time, so the new definition applies to everyone at once. The owner
  dashboard shows no aggregate level: nothing to change there. Tests: core +6, app +1 (v9
  walk-back on a real database), SQL (main board ignores a level-99 power).
- **Commit 2** *(A)* — Session flow. 30 s per question (`defaultQuestionTimeout`; the server's
  `maxElapsedMs` 30 000; the data check's time range in `20261124010000_thirty_second_questions.sql`,
  same view columns). Questions per operation: `question_plan.dart` (choices 4/5/10/20, default
  10; `shuffledTypeSequence`: each operation exactly N times, Fisher–Yates on its own
  `Random(seed)`, pinned on VM and JavaScript); `GameSetup` (core) remembered by
  `GameSetupStore` (shared_preferences); `buildSessionController(…, setup:)` and Play again
  carry it. The count is the type sequence's length, stored with the session as before. The
  derived count and the debt rotation left the core for `test/support/legacy_game_plan.dart`:
  the pinned determinism cases were drawn with them and stay byte-identical. Placement
  unchanged, on the new 30 s. The setup page comes with commit 5 (until then the stored or
  default setup applies). Pins: the timeout pin now says 30 s; the result golden's average
  time moved (a timeout counts 30 s).
- **Commit 3** *(A)* — Training mode. Core: `SessionKind.training` (`isPlacement` now an
  explicit switch); `GameMode` and `TrainingDifficulty` (levels 15 / 40 / 70) in `GameSetup`;
  `NoLevelUpdates`; replay draws a Training game like a game at its frozen levels; the
  server's validation accepts one difficulty for every operation, whatever the levels it
  holds, and never updates a level (`levelsMismatch` otherwise); `mainLevelsAfter` skips it.
  App: `buildTrainingController` (no server-level sync, no type placement, the setup's
  questions per operation, shuffled by the seed); the setup store keeps mode and difficulty;
  the result screen shows no level change after Training. Tests: validation (accepted with
  other server levels and the chain goes on; refused off-difficulty or mixed), the level walk,
  the store, and the app→server replay with a Training game in the middle (levels and counts
  untouched). Dashboard views count `kind = 'game'`: Training stays out of them until
  commit 9 decides what to show.
- **Commit 4** *(A)* — Integrals end to end. Core: `ExerciseType.integral` (last, so no
  existing order moves); `IntegralExercise` (p's coefficients `c0`…`c3`, bounds; invariants by
  `throw`: 0 ≤ a < b, non-negative coefficients, each `ck` a multiple of k+1 — so the answer
  F(b) − F(a) is whole and is an area); `IntegralExerciseGenerator` builds F first (integer
  coefficients, degree 2–4, no constant) and shows F′; `IntegralDifficulty`; codec (every
  coefficient, one shape); structural features (the bounds); the strategy detector (none);
  type placement rules v3 gain its pass time (no stored type placement replays differently).
  The pinned "all seven" determinism cases now list their seven types explicitly — unchanged
  references; integrals have their own pin, VM and JavaScript. App: the prompt (∫, bounds,
  raised exponents, `dx`, scaled down when too wide), the "Integrals" label, the ∫ icon in
  the operator family; its board and Profile row come from `ExerciseType.values`. SQL
  (`20261124020000_integrals.sql`): the level type, the board, the data check's operands, the
  structural features (two parity cases). The app→server replay test now plays integrals too
  (their type placement, then games). Tests: core +11, app +2, SQL (the integral board).
- **Commit 5** *(C)* — Home, setup page and navigation per mockups 1 and 2. Kit:
  `OperationButton` (operator and level; selected by a thicker accent outline over a tint —
  never colour alone), `SegmentedChoice`, `AppCard`, `AppButton.primary(compact:)` (48 high).
  `PlayTab`: Home (main level badge; Basics and Advanced rows, multi-select, remembered in one
  set; each row's Play dimmed and inert until it has a selection; Challenges cards, inert until
  commits 7–8), the setup page in the tab (back, operators as title, Questions, Mode, the
  difficulty in Training only, Start; system back closes it), the placement offer reduced to
  labels. Choices go through a function of the current setup (two taps between frames both
  count). After a game: back on Home. Shell: "Ranks"; the day/night toggle is a "Dark mode"
  switch in Profile's Settings (sound and vibration without their subtitles). The type
  placement hint sentence is gone. Goldens: Home and setup page, both themes. Tests rewritten
  for the new flow (`play_tab_test.dart`, `widget_test.dart`, the shell's fade test); shared
  `test/fake_stores.dart`.
- **Commit 6** *(C)* — Game screens per mockups 3 and 4. Session screen: ✕ (quit, confirmed —
  the dialog keeps its title and buttons only; the back gesture asks the same) and `n / N` on
  top, a 5 px timer bar, the operation, the answer in the accent on its underline, the keypad
  inside the root padding (backspace in the secondary colour); no type, level or streak line;
  the correction pause shows what was typed struck through, or an hourglass. Result screen:
  labels only ("Home", "Not saved"; the placement sentence and "Types played" gone; mistakes
  struck through). Feedback page: its helper sentence gone. Accessibility: muted text and the
  error colour retuned to ≥ 4.5:1 in both themes (exact check on the theme's pairs), secondary
  buttons 48 dp, Flutter's tap-target guideline on Home, the setup page and the game screen in
  both themes, 200 % text on a 360×640 phone without overflow (the game's middle block scales
  down), reduced motion everywhere (answer scale and shake, question fade, key press, tab
  fade). Pins re-measured on the new screen (keys inside the padding, the answer with its
  underline, an integral prompt added) and frozen again; goldens re-recorded, the integral
  screen added. `streakTextColor` and the streak-line tests removed with the line.
- **Commit 7** *(C)* — Chain operations. Core (`challenges/`): `Chain` (invariants by `throw`:
  every value in [1, 999], every division exact), `generateChain` (seeded; each step drawn
  among the operators that keep the value valid, then among their valid operands — no
  rejection; pinned on VM and JavaScript; 3 × 3000 seeds checked), `ChallengeStats` and its
  store interface. App: `ChainController` (screen, blank, …, keypad, answer; injectable timers;
  records games, solved and best time on the device), `SharedPreferencesChallengeStatsStore`,
  the chain's setup page in the Play tab (Seconds, Operations, Start), `ChainFlowScreen` /
  `ChainScreen` full screen (✕ with confirmation, `n / N`, progress bar, one operation per
  screen, the keypad, the correction line by line, Play again / Home). The keypad moved to
  the kit (`NumericKeypad`, `physicalDigitKeys`, `keypadKeyKey` re-exported by the game
  screen) — the pins are unchanged. Goldens: a chain screen and its correction, both themes.
- **Commit 8** *(C)* — Get the count. Core (`challenges/count.dart`): `CountPuzzle` (invariants
  by `throw`), `generateCountPuzzle` — the six numbers first, then the target drawn among the
  values in [101, 999] they can make, so a solution always exists (argument in
  `doc/decisions.md`) — `solveCount` (dynamic programme over the 63 subsets, the smallest one
  reaching the target is the shortest solution), `CountBoard` (combine under the rules, undo,
  reset, solved, closest value). Tests: 2000 seeds on the VM (target in range, the solution
  replayed under the rules), a 40-seed sample and a pin on VM and JavaScript, the rules, the
  board. App: `CountController` (45 s ticking, tile / operator / tile, a forbidden move drops
  the operator, undo, reset; stats on the device), `CountFlowScreen` / `CountScreen` per
  mockup 5 and its correction; the card plays a round at once. Profile: a "Challenges" block
  (games, solved, best, for both challenges). Goldens: the round and its correction, both
  themes; the chain's correction is now centred the same way.
- **Commit 9** *(A)* — Smoke test, dashboard, first-load budget. Smoke test
  (`tool/smoke/preview_smoke.mjs`): the placement offer is "Find your level"; after Skip it taps
  Home's "Play Basics" (each row's Play now carries an accessible label naming its row —
  `AppButton.semanticLabel`), then Start; a game is 10 questions per operation. Not run
  locally: it would create a guest in the production project (CI runs it). Dashboard
  (`20261124030000_redesign_dashboard.sql`): `calibration_window` (one row, set when the
  migration first reaches the project, i.e. at this release; the owner can move it),
  `calibration_progress` counts Phase 3b's games from it, `player_activity` gives Training its
  own column (it used to fall under "placements"); the old `beta_progress` and
  `tester_activity` are dropped, `report.sql` follows; SQL test extended (a Training session,
  a game before the window). First load: release builds of the phase's start (`dea0c42`) and
  of this commit, same flags — `main.dart.js` 3,004 → 3,064 KB raw, **687 → 700 KB brotli
  (+13 KB, ~0.07 s on slow 4G)**; the tree-shaken icon font stays 2 KB; no new asset.

### Redesign phase exit test (22 Nov 2026)

- **Every screen matches the mockups in both themes**: goldens of Home, the setup page, the
  game screen (an operation, an integral, the correction pause), Get the count and its
  correction, Chain operations and its correction, light and dark, compared by eye with
  `doc/mockups/redesign.html`. Differences, all within "colours, type and spacing from the
  theme": the nav icons are Material's (the mockups' are placeholders); Home's level badge is
  the kit's outlined `LevelBadge`; a selected operation also gets a thicker outline (rule 14).
- **A Levelling game on basics moves the main level and the leaderboard; Training moves
  nothing**: `server_replay_test.dart` (app-built games, placements, an integral type placement
  and a Training game replayed by the server's validation: the server ends on exactly the app's
  levels; the Training game leaves every level and count untouched); the main board ranks the
  four basics only (SQL test: a level-99 power changes nothing); `mainLevel` tests.
- **Integrals generated, answered, validated by the server and ranked**: generator tests over
  every level (5000 draws), the prompt, the codec, the replay above, the integral board (SQL).
- **Both challenges playable end to end with their correction**: widget tests play a chain and
  a Get-the-count round through to the correction; stats recorded.
- **Every Get-the-count target solvable**: 2000 seeds on the VM, 40 more on VM and JavaScript —
  target in [101, 999], the solver's solution replayed under the rules.
- **All chain values whole, non-negative, ≤ 999**: 3 × 3000 seeds (each operation count).
- Deployed: `bf8c8b8` served by the live preview at 18:02 (CI deploys only after its tests).
- Not verified here: a phone play of the preview (owner); the CI smoke result (private
  repository — the deploy is checked by its commit in the live `main.dart.js`); staging (still
  waiting on its setup).
- Totals: core 673 (VM) / 646 (JavaScript), app 372, server 36, tool 10; SQL tests passed.
  First load: `main.dart.js` 687 → 700 KB brotli over the phase.

## Redesign close-out

Plan v3.0 (22 Nov 2026), one commit, run at the start of the Levels phase (its entry).

- **Close-out** *(A)* — The owner's three changes. Training out of eligibility: already true on
  the server (the main board counts `kind = 'game'`, a board's own count is `sessions_played`,
  which Training never moves); now pinned by a SQL test (2 games + 5 Training games = one game
  short). Chain setup remembered: `ChainSetup` (core, invariants by `throw`), `ChainSetupStore`
  and its shared_preferences store, the Play tab loads and saves it (tests: core, store, Play
  tab). Every result screen offers Home and Play again — a placement's too (it offered "Play",
  to Home). `doc/design.md`: the error colours in the palette tables, the result screen's
  actions and mistakes as they are. `doc/decisions.md`: the owner's decisions on the Redesign.
  Plan alignment, for the owner (none blocks): section 3 and section 4 still describe the
  level system the Levels phase replaces (placement, ~20 constants); section 6.1 still lists a
  placement test and a timeout scaled to the level, which `doc/levels.md` drops; section 6.4
  says "one overall board" (the main board since v2.9); Phase 6's entry does not list the
  Levels phase.

## Levels phase — new level system, tables mode, tips

Plan v3.1 (23 Nov 2026), specification `doc/levels.md` v1 (binding). The beta-safety rule stays
lifted. The new rules are built as **rules v2** next to v1 through commits 1–3; commit 4 makes
new games use them, together with the reset (`doc/decisions.md`).

- **Commit 0** *(A)* — Decisions and the rules version. `doc/decisions.md`: the owner's level
  system recorded, the entries it supersedes marked, the gaps filled (rules version, v2 built
  alongside, late v1 uploads refused after the transition). Core: `RulesVersion` (v1, v2;
  stored numbers; `current` = v1 until commit 4) on `SessionConfig` and `PersistedSession`,
  the upload's optional `rulesVersion` (absent = v1, unknown refused). A v2 session does not
  replay yet (`SessionNotReplayable`) — so the server refuses one until commit 4. App: schema
  v10 `sessions.rules_version` (NULL = v1), written by the session controller. SQL
  (`20261125000000_rules_version.sql`): `uploaded_sessions.rules_version`, read from the stored
  payload (absent = 1), so no write path changes. Tests: enum, codec, replay gate, SQLite
  round-trip and v10 migration, SQL column.
- **Commit 1** *(A)* — The new level update (spec section 3), as rules v2. Core:
  `LevelRules` (dead band 55–65 %, spans 25 / 35, caps +3/+3/+4/+5 by questions and −2, slow
  credit 0.75 — integers, invariants by `throw`), `answerCreditQuarters`,
  `levelChangeHundredths` (integer arithmetic only, one rounding to the nearest hundredth) and
  `levelAfterGame`; `gameLevelUpdates` picks v1 or v2 by the game's rules version — one
  implementation for the app (`LevelCacheOrchestrator.rulesVersion`) and the server's
  validation (`session.rulesVersion`; under v2 an unplayed operation chains from 0). `Level`
  now spans [0, 100] (`Level.zero`); rules v1 keeps its own floor at 1.00 (`clampedV1`, used
  by the v1 update and the placement staircases), so the live game is unchanged. Fluent time:
  the shared 2 s until commit 3. The v1 constants stay for v1 games until commit 4 removes v1.
  Tests: the spec's example table to the hundredth and as printed (+3, +1.2, +1.2, 0, −0.3,
  −1.0, −2), its grind estimate (0 → 20 in 5 perfect 10-question games, → 50 in 13), a
  correct-but-slow game raises the level for every count, the caps, the closed dead band, the
  [0, 100] clamp, invalid input, the v2 branch of `gameLevelUpdates`.
- **Commit 2** *(A)* — Ten tiers per operation (spec section 5), as rules v2. Core
  `tiers/`: `Tier` (T0–T9, an enum so every switch is exhaustive; 100 is in T9), the content
  of every tier of the eight operations (`arithmeticAt`, `powerAt`, `rootAt`,
  `percentageAt`, `integralAt`, one entry `exerciseAt`) — built from their parts: digits
  drawn so carries and borrows land where the tier wants them, quotients before dividends,
  roots before radicands, bases among the multiples that make a percentage whole, integrals
  from whole antiderivatives; `TieredGameGenerator`: each operation at its frozen tier,
  exactly 30 % review from the tier below (1 of 4, 2 of 5, 3 of 10, 6 of 20; none at T0),
  which questions drawn on the game's stream. `gameExerciseGenerator` picks v1 or v2 for the
  app and the replay; a v2 game replays (a v2 placement, or a plan other than equal counts in
  4/5/10/20, does not), so the server validates v2 games — chained from 0, levels by
  commit 1's update. Models: cube roots (`SquareRootExercise.index`), eighths
  (`PercentageExercise.tenths`), x⁴ and one negative term covered by a higher one
  (`IntegralExercise.c4`; p ≥ 0 by an exact rule), all by `throw`; stored shapes of earlier
  questions unchanged (new keys only when used); the prompt draws them (a small raised 3
  before √ — no bundled face has ∛ —, "37.5%", " − "). Tests: every tier of every
  operation, 3,000 draws each, against its spec description, whole and exact; each spec
  example is of its tier's kind; the exact 70/30 split over 300 seeds × 4 counts; v2
  sequences pinned and identical on VM and JavaScript (`tool/tier_references.dart`); v2
  validation (accepted with the app's levels, forged question, wrong plan, level-1 chain).
  Not live: new games stay v1 until commit 4.
- **Commit 3** *(A)* — Fluent time per tier (spec section 5) replaces rules v2's shared 2 s:
  `fluentTimeMs(type, level)` in `tiers/`, the spec's eight tables (4 → 14 s for + and −, up
  to 20 s for integrals), read at the tier of the frozen level for every question of that
  operation, reviews included (provisional, `doc/decisions.md`, with commits 1–2's gaps).
  Tests: every table value, the tier boundaries (39.99 / 40 / 100), the fluent time itself
  counted as fluent, 0.1 s over it as slow. Rules v1 keep their `t_rapide` until commit 4.
- **Commit 4** *(A)* — The transition (spec section 4). `RulesVersion.current` = v2: every
  new game, Levelling and Training, draws from the tiers and moves levels by commit 1's update.
  **Rules v1 deleted**: the `p_cible` update and its constants, confidence boosts, the operand
  curves and v1 generators (`CompositeExerciseGenerator`, `FixedTypeSequence`, the debt
  strategy), placement and type placement (core, app builders, the Home offer, Profile's "Find
  my level", the skip store, the result screen's placement branch); the stored `SessionKind`
  names stay, never replayed. `replaySessionQuestions(session, count)` replays v2 only;
  validation refuses v1 (`rulesRetired`, new reason, "Not ranked: played before the new levels.")
  and the upload queue never sends a v1 session. **Levels to 0**: app schema v11 empties the
  level cache (history kept); SQL `20261125010000_levels_transition.sql` widens
  `server_levels` to 0–10000, empties it, ranks the main board with unplayed basics at 0 and
  counts only rules-v2 games toward its three, and restarts Phase 3b's calibration window.
  Everyone starts at 0: Home, Profile and the result show 0 for an operation never played;
  Profile's curve and 30-day change use v2 sessions only. Training stays 15 / 40 / 70 = T1 /
  T4 / T7 (tested). Duels draw from the tiers; their three pins re-recorded on purpose (no duel
  stored). Scores: the difficulty multiplier from level 0. Smoke test: Home is the first
  screen (no Skip). Tests: v1 suites and pins removed with their code (core 835 → 437 on the
  VM); replay, validation (v1 refused, placements refused, the v2 chain), queue, migration
  (v3 → v11), SQL (v1 games off the main board, level 0 stored, unplayed 0); goldens of Home,
  Profile and the result screen regenerated and checked by eye (levels at 0, no placement
  block, +3 on a perfect 4-question game). Not run locally: the smoke test (production).
- **Commit 4.1** *(A)* — Urgent fix after commit 4 went live. The production server was still
  `352f1d5` (its deploys wait for the owner's production deploy hook, part of the staging setup
  still open), so it refused every rules-v2 game for good — it cannot read level 0 nor replay
  the tiers — and with nothing pending, the next Start adopted its levels (empty since the
  reset): a tester's progress dropped back to 0 after each game. Now: the server's `/health`
  lists the rules it replays (`RulesVersion.replayed`); the app sends a session only to a
  server that replays its rules, otherwise it stays pending (which also stops the adoption).
  App schema v12: rules-v2 sessions the old server refused are pending again. SQL
  `20261125020000_old_server_v2_rejections.sql`: the old server's rejections of v2 games are
  deleted (a resend of a known id gets its stored verdict); repeated in commit 5 for those
  made meanwhile. Tests: client (old server: nothing sent), v12, SQL, `/health`.
  **Owner**: deploy the production server (doc/online.md) — until then games are held on the
  devices, unranked.
- **Commit 5** *(C)* — Display (spec section 6, plan commit 5). Numbers grouped by three with a
  space everywhere a question, an answer or a correction shows one (`groupedNumber`); + − ×
  on one line when it fits the game's width, otherwise stacked on two lines aligned on the
  units digit with a rule under them and the typed answer right-aligned on that column
  (`promptStacks`, measured with the screen's text scale); ÷ always one line (the spec);
  answers up to 10 digits (was 7); "Roots" for the family that now has cube roots. The plan
  and the spec differ on when to stack: the plan's rule built, provisional
  (`doc/decisions.md`). Pins: a stacked case added (4 789 × 3 657: one line at 412 px,
  stacked at 360 px, answer under the units column), every earlier pin unchanged. Goldens:
  the stacked game screen at 360 × 640 in both themes; Profile's "Roots". Also SQL
  `20261125030000_old_server_v2_rejections_again.sql`: commit 4.1's cleanup once more.
  **To play on the phone.**
- **Commit 6** *(C)* — Tables mode (spec section 7). Core `challenges/tables.dart`:
  `TablesSetup` (tables within 1–50, multipliers 10 / 20, 10 / 20 / 50 questions; invariants
  by `throw`), `tablesQuestions` (every fact of the chosen tables, shuffled by the seed, dealt
  again for a longer round; pinned on VM and JavaScript), `TablesStats` (games, answers, right,
  every fact's record, the slowest; JSON), `TablesStore`; `ListExerciseSource`. App: the
  shared_preferences store; Home's "Tables" card under Challenges; its setup page (From / To
  steppers, Multipliers, Questions, Start; remembered); `buildTablesController` plays a round
  on the game screen as Training with a throwaway repository (no history, no level, no
  upload); `playSessionFlow` gains `playAgain` and `onFinished` (each finished round goes into
  the stats); Profile's "Tables" block (games, right / answers, three slowest facts). Also:
  the Play tab loads each remembered setup on its own (one store that never answered left the
  others at their defaults). Tests: core (setup, ranges, one pass per fact, determinism, pin,
  stats, JSON), store, Play tab (card, setup, range, ends, remembered), a full round end to
  end (stats recorded, history and levels untouched, Play again), Profile block; goldens: the
  Tables setup page and Home with its card, both themes. **To play on the phone.**
- **Commit 7** *(C)* — Tips page (spec section 8). Core `TipBand` (beginner T0–T2,
  intermediate T3–T5, advanced T6–T9). App `presentation/tips/tips.dart`: 35 tips, one
  sentence and one worked example each, every operation in every band, each of the
  detector's seven strategies linked to exactly one (`Tip.strategy`, for a later phase's
  tip after a wrong answer); `TipsView` per operation and band, the player's band marked
  (outline, marker icon, weight; selected for screen readers); a "Tips" card on Home under
  Tables. Every character checked against Inter's coverage. Tests: band rule, content rules,
  the marked band (level 37 → intermediate; never played → beginner), Home → Tips → back;
  goldens: the Tips page in both themes, Home with its two new cards. **To play on the
  phone.**
- **Commit 8** *(A)* — Simulation (`packages/math_core/tool/levels_simulation.dart`,
  `tool/src/levels_simulation.dart`): median games from 0 to each tier for a perfect, a
  perfect-but-slow, an 80 % and a 60 % player (1001 seeded players each, the real update and
  fluent times). Against the spec's grind estimate: exact (20 in 5 perfect games, 50 in 13);
  a slow-but-right player climbs at 40 % of that pace; **finding**: a 60 % player creeps up a
  tier every ~24 games instead of stalling — the expected change is zero at 54 % right, not
  60–70 % (`doc/decisions.md`, for the owner; constants untouched). Tests
  (`test/tool/levels_simulation_test.dart`): the estimate, slow climbs, 60 % ≥ 4× slower
  than 80 %.

### Levels phase exit test (23 Nov 2026)

- **The spec's example table and grind estimate reproduced by tests**: yes —
  `level_change_test.dart` (+3, +1.2, +1.2, 0, −0.3, −1.0, −2 to the hundredth and as
  printed; 20 in 5 perfect games, 50 in 13) and the simulation's test.
- **Every tier generates its examples' kind of question**: yes — `tier_content_test.dart`,
  80 tiers × 3,000 draws against the spec's descriptions, each spec example of its tier's
  kind; divisions, roots and percentages exact; v2 sequences identical on VM and JavaScript.
- **A correct-but-slow game raises the level**: yes — for 4, 5, 10 and 20 questions (+1.2 at
  4); simulated: a slow-but-right player reaches every tier.
- **All levels at 0 for every player**: on the devices by schema v11 at the first load of
  commit 4's build or later; on the server by `20261125010000_levels_transition.sql`, which CI
  applied before deploying commit 4 (live since then). Not checked on live rows (the
  dashboard is the owner's). Caveat: the production server is still `352f1d5` (no deploy
  hook), so it may have written v1 levels in the minutes the old pages played after the
  reset (`doc/decisions.md`).
- **Tables mode and tips playable on a phone**: owner — widget tests play a Tables round end to
  end and open the Tips page; goldens of both in both themes.
- Not verified here: the CI smoke test (private repository); the production server's v2
  validation live (not deployed: commit 4.1 holds uploads until it is).
- Totals: core 449 (VM) / 422 (JavaScript) — the v1 suites left with their code (835 before);
  app 399; server 36; tool 10; SQL tests passed.

## Levels close-out — the level update tuned (plan v3.2)

Plan v3.2 records the Levels outcome (every provisional decision kept) and two steps. Production
was deployed by the owner before it started: `/health` = `2a6657c`, `rules: [2]`.

- **Commit 1** *(A)* — **Rules v3**: the level update tuned by simulation to the plan's four
  targets, keeping the plan's starting point (slow 0.85, dead band 0.62–0.72, down cap 3):
  stall at 63.8–65.3 % right, 4 slow answers +1.56, perfect games the full cap, worst −3
  (`doc/decisions.md`, with the simulation table). Core: `LevelRules.v2` / `.v3` and
  `LevelRules.of(RulesVersion)` (v1 throws); credits in percent (`answerCreditPercent`,
  `levelChangeHundredths(creditPercent:)`, rules required everywhere — no default to
  forget); `RulesVersion.v3` (`current`; `replayed` = v2, v3; `retired` = v1 only); v3
  generates as v2; `gameLevelUpdates` and `SessionLevelUpdates.computeUpdates` take the
  session's rules version (the app's controller passes its config's, the server's validation
  the upload's). App: the Profile curve and the recent games' change span v2 and v3 (one
  scale). Server: `/health` lists `rules: [2, 3]`. Tool: `tool/levels_simulation.dart` checks
  the targets exactly (expected change over every outcome, stall by bisection), prints both
  versions' tables, `--grid` lists every candidate meeting the targets. Tests: v3's targets,
  values and example games; the stall pinned; v2 still replayed under v2 and a v3 game
  chaining from v2 levels (validation); goldens of the mistakes result re-recorded (12 → 9,
  the −3 cap). Totals: core 463 (VM) / 436 (JavaScript), app 399, server 36.
- **Commit 2** *(A)* — Production checked after every push changing the server or the core:
  `tool/ci/server_check.sh <server url>` (read-only, one GET of `/health`) says whether the
  server runs this checkout's `server/` and core and lists `RulesVersion.current`, else prints
  the owner's action and exits 1. After commit 1: production ran `107440e` with
  `rules: [2, 3]`, deployed by CI 10 minutes after the push — the production deploy hook is set
  (the Levels phase's incident cannot recur silently). CI unchanged: a missing hook stays a
  warning, since the site's deploy waits on that job and the app holds games the server
  cannot check. `CLAUDE.md`: the command and the pitfall.

### Levels close-out exit test (23 Nov 2026)

- **Chosen values reported with the simulation table, pinned by tests**: slow 0.85, dead band
  0.62–0.72, down cap 3 (`doc/decisions.md`, both tables);
  `level_change_test.dart` and `test/tool/levels_simulation_test.dart` pin the targets, the
  stall (65.3 / 63.8 / 64.0 / 64.2 %) and v3's example games.
- **v3 stored per session**: `RulesVersion.current` = v3, written by the app (schema v10's
  column) and the upload; v2 replayed under v2 (validation test).
- **Production `/health` lists the new rules**: yes — `107440e`, `rules: [2, 3]`; the preview
  serves `107440e`.
- Not verified here: CI's smoke test (private repository); a live v3 game accepted (the
  owner's checklist).

## Patterns and Method phase (plan v3.3, `doc/levels.md` v1.2)

Pattern questions in every tier (spec section 5b) as rules v4, and a Method on every mistake
(section 9). Owner actions: none by hand (CI applies migrations; the deploy hook redeploys the
server).

- **Commit 0** *(A)* — Decisions recorded (`doc/decisions.md`, "Patterns and Method phase"):
  rules v4, its switch at commit 5, the per-question pattern share, families recomputed by
  replay, a third addend, Method lines as checked expressions — and the addition and
  subtraction tiers of v2/v3 found not to match the spec's section 5 (fixed in v4).
- **Commit 1** *(A)* — **Pattern questions, rules v4** (spec section 5b; replayed, not yet
  played — `RulesVersion.current` stays v3 until commit 5). Core: `PatternFamily` (49 families,
  the spec's order, each with its operation and starting tier; `availableAt`),
  `patternQuestion` (one backwards generator per family, within 10-digit answers);
  `longArithmeticAt` (v4's addition and subtraction, the spec's section 5 tables up to 9
  digits); `patternedContent` (a pattern question 2 times in 5 where a family is available,
  uniform among them, else the tier's standard question) next to `standardContent` (v2/v3,
  unchanged); `TieredGameGenerator(content:)` and `lastFamily`; `RulesVersion.v4` (replayed:
  2, 3, 4; `LevelRules.of(v4)` = v3's); `fluentTimeMs(type, level, rules)` (v4: addition and
  subtraction 4–25 s, the spec's); `replaySessionPatterns` (families by replay);
  `ArithmeticExercise.operandC` (three-term sums; stored only when present; the detector
  skips them). App: three-term prompt, one line or three rows. Server: `/health` lists
  `rules: [2, 3, 4]`. Tests: every family's support and the spec's examples, 3,000 draws per
  family; v4 long tables per tier with the spec's examples; the share (38–42 % over 10,000
  draws where families exist, 0 at T0) and only available families; v4 pinned on VM and
  JavaScript (`test/tiers/tier_references_v4.dart`, v2's references unchanged); a v4 upload
  replayed and accepted; families replayed as drawn.
- **Commit 2** *(A)* — **The Method generator** (spec section 9), pure core. `method_expr.dart`:
  integer expressions (`Num`, `Bin`, `Group`, `Pow`, `RootOf`, `PercentOf`) that evaluate
  themselves — a remainder, a non-power root or a fractional percentage throws — and lay
  themselves out as tokens (`exprTokens`: parentheses by precedence or by `Group`, two
  bracketed factors side by side without ×), so the app formats numbers and never places a
  bracket. `method.dart`: `MethodLine` (terms joined by = or <, continuing the previous line or
  the question), `Method` (family, strategy or fallback), `methodProblems` (the checker).
  `method_for.dart`: `methodFor(exercise, family:)` — the family's own lines for each of the
  49 families, the detector's seven strategies, a fallback per operation. Tests: every family's
  questions (2,000 each) get their own Method; every tier of every operation under v4 and
  v2/v3 (3,000 questions each) gets a sound one — every line true, never negative, the last
  the answer, 2 to 4 lines; the detector's strategy where it fits; the layout; the exit
  example ("= (20 − 3)(20 + 3)").
- **Commit 3** *(C)* — **The Method on the result screen** (spec section 9). `ResultScreen`
  (`showMethods`, `onMoreTips`): each wrong answer and timeout gets a "Method" button that
  opens in place a card with the strategy's name (`method_labels.dart`) and the lines
  (`method_view.dart`: the core's tokens rendered with grouped thousands, the true minus,
  raised exponents, √ and a raised 3), then "More tips". Families come from `gamePatterns`
  (the game's replay). The mistake row wraps. `playSessionFlow(showMethods:)`: on for games,
  off for Tables mode. `TipsView(focus:)` opens scrolled to an operation; the session flow
  pushes it over the result with the player's current levels. Tests: buttons on mistakes only;
  a missed 17 × 23 shows "= (20 − 3)(20 + 3)" under "Difference of squares"; More tips names
  the operation; no Method without `showMethods`; the Tips focus; goldens of an open Method in
  both themes. App 406.
- **Commit 4** *(A)* — **Tips linked to the families**: `Tip.families`; every family is
  exactly one tip's, of its operation (19 new tips, 54 in all); `tipFor(method)` (family, else
  strategy, else none). "More tips" opens the Tips page at that tip, scrolled to and marked
  (a bar and an arrow, heard as selected), or at the operation's section for a fallback.
  Tests: every family linked once; every Method but a fallback finds its tip; the focused tip
  in view; Tips goldens re-recorded (new tips). App 408.
- **Commit 5** *(A)* — **Rules v4 played; the simulation under v4**. `RulesVersion.current` = v4
  (new games: pattern questions, the spec's long addition and subtraction); Phase 3b's window
  restarts (`20261126000000_patterns_window.sql`; the dashboard's label says so).
  `DuelConfig.rulesVersion` (stored; absent = v3): duels no longer follow `current`, their
  pins stay under v3. Tool: the targets under v4's constants (met — v3's update), the share of
  pattern questions served per tier (`patternShareServed`, against `patternShareExpected`):
  40 % from a family's second tier, 28 % at its first, 0 at T0 (`doc/decisions.md`). Tests:
  v4's targets; the served share within 2 points of the expected for every operation and
  tier; a duel keeps its rules (JSON, v1 refused). SQL tests passed.

### Patterns and Method exit test (23 Nov 2026)

- **Every family's examples generated**: yes — `pattern_questions_test.dart`: each of the 49
  families' spec examples is its kind (the exact support of its generator), and 3,000 draws per
  family stay inside it, whole, exact, at most 10 digits. The spec's section 5 addition and
  subtraction tables likewise (`long_arithmetic_tiers_test.dart`).
- **Every Method checked by tests**: yes — `method_test.dart`: 2,000 questions per family and
  3,000 per tier of every operation (v4 and v2/v3): every line evaluated, every relation true,
  never negative, the last term the answer, 2 to 4 lines (one for 2¹).
- **Level targets still met**: yes — v4 keeps v3's update; the four targets and the served
  pattern share are tested (`test/tool/levels_simulation_test.dart`).
- **Production `/health` lists rules 4**: yes — `ca53f05`, `rules: [2, 3, 4]`, deployed by CI 5
  minutes after the push (`tool/ci/server_check.sh`: up to date); the preview serves `ca53f05`.
- **On a phone, a missed 17 × 23 shows (20 − 3)(20 + 3)**: owner — the widget test opens the
  Method under a missed 17 × 23 and finds "= (20 − 3)(20 + 3)" under "Difference of squares";
  goldens of it in both themes.
- Not verified here: CI's smoke test (private repository); the Method on a real phone.
- Totals: core 686 (VM) / 659 (JavaScript), app 408, server 36, SQL tests passed.


## Plan v3.4 — Patterns and Method outcome (23 Nov 2026)

One commit. Every provisional decision of the phase kept (`doc/decisions.md`). The owner's new
rule: `doc/levels.md` checked by a test that reads it —
`packages/math_core/test/spec/levels_spec_conformance_test.dart` (VM only; the file is not
available under `-p node`). It parses sections 5 and 5b and checks, under
`RulesVersion.current`: each tier's levels (against `Tier.of`) and fluent time (against
`fluentTimeMs`); each example a question its tier draws (one-question games through
`gameExerciseGenerator`, standard questions only); each tier's digit counts ("N-digit", "N- and
M-digit", and ranges beside the operator) — every question drawn fits a clause of the content
and every count a clause names is drawn; "up to N digits" the most drawn; each operation's
families in the spec's order, from their tier, each family example drawn by `patternQuestion`.
"Drawn" is sampled (40,000 draws): exact when the sample holds every question there is,
otherwise column by column on the example's shape. Checked by mutation: 8 spec edits (an
example, a fluent time, digit counts, a family's tier, a family example) and the old 3-digit
addition T7 each fail it. Stale mentions of v2 as "`doc/levels.md` v1" fixed (code comments,
`CLAUDE.md`, `doc/decisions.md`): v2's addition and subtraction were an earlier draft's.


## Staging live (24 Nov 2026)

Phase 5.2's exit test had its staging half unverified (the owner's setup). Done: with
`STAGING=on`, CI's full smoke test plays on staging and production's is read-only — all green
at `aaee7a2` (smoke-staging, migrations, server-production, deploy-cloudflare, smoke).

- **Upload 503 on staging** (`a7d02cf`, `28f8391`): the smoke failed at "no server levels after
  150 s". Traced with `SMOKE_TRACE=1` (now prints each write's status and error body): every
  `POST /v1/sessions` answered 503. The server now logs the reason (`503 on POST /v1/sessions:
  …`); Render's log showed `permission denied for table uploaded_sessions`. Newer Supabase
  projects (staging) give the API roles no default privileges on new tables, older ones
  (production) do; no migration granted them. Migration `20261127000000_explicit_table_grants`
  grants the server's five tables to `service_role` and `profiles` to the app's roles (a no-op
  on production); the SQL test stub now models the newer kind, so a missing grant fails there.
  `ServerConfig` also refuses a legacy anon JWT as the secret key (a first guess, kept as a
  guard).
- **GitHub Pages** (`aaee7a2`): since the repository went private, `deploy-pages` fails (404,
  free Pages serves public repositories only). The redirect from
  `geriogerg.github.io/Math-Trainer/` is opt-in (`GITHUB_PAGES_REDIRECT=on`); old links no
  longer forward.
- **Staging `ALLOWED_ORIGINS`** (`ff10dad`): `https://math-trainer-staging*.pages.dev` matches the
  bare project address (`*` = zero or more characters in one label, tested); doc/online.md
  gives the exact value.
- **Spec-conformance test** (plan v3.4): done at `97e41c1`; it passes; the remaining
  "`doc/levels.md` v1" mentions are historical and correct.

**Next: the beta — owner actions.**
1. The Patterns and Method phone checklist (below, and in the phase report).
2. Invite testers: `bash tool/dashboard/dashboard.sh new-code <label> [uses]`, one code per
   tester; `codes` shows their uses.
3. Phase 3b starts at ~300 sessions from 10+ testers since the v5 release (was: v4)
   (`owner_dashboard.calibration_window`; the dashboard's report counts them).
4. Still parked, optional: the slow-4G first-question measurement past the gate (needs a CI
   beta code; Phase 5.2 commit 0).

## Rules v5 — pattern questions sized by tier (24 Nov 2026, `doc/levels.md` v1.4)

Beta bug: level 15–20 games served level-70 questions (2²⁰ at level 15). Diagnosis (games at
levels 5, 15, 25, 50, every operation, rules v4): the level reached the generator correctly
(whole part, `Tier.of`); the cause was the v4 pattern generator, which had no tier input —
every family drew its full range from its first tier (powers of 2: 2⁷–2²⁰ at T1;
√2²⁰ at T2; 4-digit × 5, ÷ 2, 25 % of 4-digit at T2; ∫₀¹⁹ 2x at T1) — plus 30 % review
questions from the tier below (spec v1.2).

- **Rules v5** (current): `patternQuestion(family, tier, r)` sizes every family by tier
  (size table and hard limit, `doc/decisions.md` "Rules v5"); no reviews
  (`withReviews: false`); √ of powers of 2 from T3. v2–v4 generators unchanged (references
  regenerate byte-identical). Server replays v5; `/health` lists `[2, 3, 4, 5]`.
- **Method**: four addition families recognised at any size.
- **Tests**: spec-conformance test reads section 5b's size table and checks every row band by
  band, and the hard limit for every other family at T0–T8 (3,000 seeds per family and tier);
  every family at every tier (kind, exact, ≤ 10 digits, grows, throws below its tier); no
  question from a lower tier at any level (every 0.37 level, every n); no power above 2⁶ and
  none above 225 at every hundredth of levels 10–19; v5 determinism pins VM/JS; the Method on
  every family at every tier.
- **Simulation**: the four targets met (65.3 / 63.8 / 64.0 / 64.2 % stall; +1.56 slow; full
  cap; −3); v5 serves 40 % pattern questions from each family's first tier, 0 % lower-tier.
- Phase 3b window restarted at the release (migration `20261128000000_rules_v5_window`).
- **Rules v6** (same day): `doc/levels.md` v1.5 at the owner's request — √ of powers of 2
  sized by its own row (√64–√1 024 at T3–T4, up to √65 536 from T5) instead of the v1.4
  mirror (one question per band). Current; v5 kept for replay; `/health` lists
  `[2, 3, 4, 5, 6]`; window not restarted. CI's Supabase CLI pinned to 3.3.0 (the staging
  migration job had failed on GitHub's API rate limit, blocking the v5 deploy).

## Phase 4 — Learning layer: weak spots and drills (plan v3.5)

Owner actions: none by hand (CI applies migrations; the deploy hook redeploys the server). At
the end: the phone checklist, and `bash tool/dashboard/dashboard.sh weak-spots` locally.

- **Commit 0** *(A)* — Plan v3.5 committed. **Phase 3b is now a data check, not a blocker**
  (owner, 24 Nov): when the dashboard reaches its threshold (~300 sessions from 10+ testers
  since the rules v5 release, `owner_dashboard.calibration_window`), a report compares the
  targets of `doc/levels.md` section 3 with real games; constants change only if the data
  contradicts them. Phase 4 goes first. Decisions recorded (`doc/decisions.md`, "Phase 4"):
  the fact and skill catalogue, an item's tiers ("current tier only"), the scheduler's
  details, rules v7's cap and storage, the practice kinds, the drill of a tip without a family.
- **Commit 1** *(A)* — **Fact and skill catalogue** (`packages/math_core/lib/weak_spots/`).
  `Item` (sealed: `FactItem`, `SkillItem`) with a stored key (`fact:multiplication:7,8`,
  `skill:differenceOfSquares`) and `Item.parse`; `isCanonicalFact` (the plan's list:
  150 addition, 289 subtraction, 210 multiplication, 400 division, 50 power, 42 root and 249
  percentage facts); `factOf` (commutative facts merged), `exercisesOf`, `allFacts`;
  **`factsAt(type, tier)`** — the facts a tier's standard questions draw, from the section 5
  tables (`standardQuestionV4`, now public; `powerSupport`/`rootSupport` read the generator's
  own tables), `formsAt`, `homeTier`; `itemOf(exercise, family:)` (pattern question → its
  family; standard → its fact if some tier draws it, else its strategy's family via
  `skillFamilyOf`; split factor untracked). Tests: catalogue counts, keys round-trip, merges;
  `fact_tiers_test.dart` (VM, 600,000 draws per operation and tier): every fact a tier draws
  is listed and every listed one is drawn, for all 80 operation × tier pairs; the 208 facts no
  tier draws as a standard question (15 − 3, 130 ÷ 10, 2¹¹…) pinned by count — never keyed.
- **Commit 2** *(A)* — **Five-box scheduler** (`weak_spots/scheduler.dart`, `history.dart`).
  `WeakSpotSchedule` (immutable, counted in games: `afterGame`, `replay`, `isDue`, `due` most
  urgent first), `Grade` (miss / slow / fluent), `itemFluentMs` (a fact: its home tier's time;
  a skill: the game's tier's), `gradedAnswersOf` and `scheduleFromHistory` (stored sessions in
  time order; families by replay, trusted only where the replay asks the stored question).
  Core: `exerciseFromStorage` (the codec's inverse), `replaySession` (questions with families).
  Tests: the exit story (a missed 7 × 8 due in games 1, 3, 7, then out of the near games),
  every box's interval, misses, slow answers, mastery, absence, order, replay = step by step,
  grading of a real v6 game, time order, a retired game. Core 1 033 (VM) / 819 (JS).
- **Commit 3** *(A)* — **Rules v7: weak spots in Levelling games** (current). Core:
  `RulesVersion.v7` (replayed: 2–7; v3's update); `weak_spots/levelling.dart` — `belongsTo`
  (a fact the tier's standard questions draw, a family available there), caps
  (`weakSpotGameCap` ⌊N/5⌋, `weakSpotOperationCap` ⌈n/5⌉), `weakSpotProblem`,
  `chooseWeakSpots`; `TieredGameGenerator(weakSpots:)` places them like reviews (nothing drawn
  without them: **v7 without weak spots = v6**, tested on 200 games), `lastWeakSpot`;
  `gameExerciseGenerator(weakSpots:)` refuses them outside v7 or against the rules;
  `PersistedSession`/`SessionConfig.weakSpots`; upload field `weakSpots` (absent when none);
  the replay refuses weak spots off the tier, over a cap, outside a Levelling game
  (`notReplayable`); `SessionRepository.storedGames`. App: schema v13 (`weak_spots`, JSON keys),
  `storedGames` in one query, `loadWeakSpotSchedule`, the due items chosen when a Levelling game
  starts. Server: `/health` lists `[2, 3, 4, 5, 6, 7]` (no SQL: the payload is jsonb).
  Simulation (`tool/levels_simulation.dart`): v7's targets met (v3's update); weak spots
  served per operation and tier for a 70 % player — 0 off-tier everywhere, at most 20 % of a
  game, 8–20 % on average. Tests: placement, forms, families, refusals, upload round trip,
  a VM/JS pin of a v7 game with weak spots; app: a missed 3 × 4 re-asked in the next game,
  stored, replayed. Core 1 056 (VM) / 829 (JS), app 409, server 37. Phase 3b's window not
  restarted.
- **Commit 4** *(C)* — **Weak spots game and Home card.** Core: `SessionKind.weakSpots` and
  `drill` (stored names; `movesLevels`, `isPractice`); `weak_spots/practice.dart` —
  `practisable` (a fact at or below the player's tier, a family started), `chooseWeakSpotsGame`
  (≤ 10 due items), `weakSpotsGameProblem`, `WeakSpotsGameGenerator` (a fact in a form of its
  home tier, a skill at the player's tier), and the Drill's pieces for commit 6;
  `practiceGenerator`; the replay and the server's validation take both kinds (replayed,
  checked, never a level update — accepted whatever the levels, like Training);
  `gamePatterns` too (Methods on misses). App: `buildWeakSpotsController`,
  `weakSpotsGameItems`; Home's new "Practice" section with a "Weak spots" card ("3 due" /
  "None due", inert when none; `AppCard.detail`); Play again deals the next due items; the
  result screen shows level changes only for kinds that move levels. Home goldens re-recorded
  (the card). Tests: practice rules, generators, uploads accepted with no level update,
  refusals; the card; a Weak spots game stored and replayed alone, levels untouched. Core
  1 066 (VM) / 841 (JS), app 412, server 37.
- **Commit 5** *(C)* — **Profile "Weak spots" block.** Core: `worstFacts` (`WeakFact`): facts
  answered at least twice, most missed first (rate, then count), then the slowest against
  their own fluent time; never-missed fluent facts left out; five at most. App: the block
  (after Recent sessions) lists each fact with "2 of 3 missed" or its mean time, and a
  Practice button — `buildFactsPracticeController`: the facts the player can practise at
  their tiers, each twice, as a Weak spots game; "None yet" without any. Tests: the ranking,
  the cap; the block and its button; a new player.
- **Commit 6** *(C)* — **Drill button on every tip.** Core: `TipBand.low`/`high`; the
  Drill's pieces (commit 4: `drillTier`, `drillProblem`, `DrillGenerator`). App: `TipsView
  (onDrill:)` puts a "Drill" button under every tip of the Tips page opened from Home
  (`tipDrillKey`); `buildDrillController` — 10 questions, the tip's families at the player's
  tier (or the families' first tier when the player is below it), else the operation's
  standard questions at the player's tier brought into the tip's band; stored and uploaded
  as `drill`, never moving a level; Methods on misses as usual; Play again deals another.
  The Tips page opened from a Method keeps no Drill button. Tests: every tip has its button
  and it drills that tip; every one of the 54 tips builds a drill that replays alone at
  levels 0, 25, 55 and 95, its pattern questions all of the tip's families. Core 1 068 (VM) /
  843 (JS), app 416, server 37.
- **Commit 7** *(A)* — **Dashboard report: does it work?** `bash tool/dashboard/dashboard.sh
  weak-spots` (local only; needs psql and dart): psql exports every accepted session's payload
  (`uploaded_sessions`), `packages/math_core/tool/weak_spots_report.dart` replays each player's
  history through the core's scheduler (`itemAnswersOf`, the path `gradedAnswersOf` now
  shares) and prints per player and for everyone: games, items scheduled, items out of box 1
  and mastered, accuracy and median right time on each scheduled item **before** (up to and
  including the miss that scheduled it) and **after**, and on items never scheduled for
  comparison — with the regression-to-the-mean caveat printed. Player ids cut to 8
  characters. Test on a scripted history (VM). Not run here on live data: the owner's.
  Core 1 069 (VM) / 843 (JS), app 416, server 37.

### Phase 4 exit test (24 Nov 2026)

- **A missed 7 × 8 comes back within the next games until answered fluently three times**:
  yes in the core — `scheduler_test.dart`: missed in game 0, due in games 1, 3 and 7, then
  box 4 (8 games). Levelling games re-ask it only at T1 (`belongsTo`, the replay refuses
  otherwise); a T2+ player gets it from the Weak spots card. App: a missed 3 × 4 re-asked in
  the next Levelling game, stored, replayed alone (`weak_spots_levelling_test.dart`).
- **Weak spots and Drill games playable on a phone**: owner — widget and flow tests cover the
  card, the game, the Profile block and every tip's Drill (54 tips at four levels).
- **Level targets still met**: yes — v7's update is v3's; the four targets tested; weak spots
  served never off the current tier and never above 20 % of a game (simulation, every
  operation and tier).
- **Production lists rules 7**: yes — `/health` `rules: [2, 3, 4, 5, 6, 7]` since commit 3.
- Not verified here: CI's smoke test (private repository), the phone, the dashboard report on
  live data (owner's machine).

## Phase 4 close-out (plan v3.6)

Plan v3.6: Phase 4's outcome — every provisional decision kept but one (slow facts enter the
schedule); a three-commit close-out. Owner actions: none by hand (commit 3's SQL function goes
in a migration CI applies).

- **Commit 1** *(A)* — **Rules v8: slow facts enter the schedule at box 2.**
  `RulesVersion.v8` (current; replayed 2–8; v7's questions and update), with
  `slowFactsEnterSchedule` (v8) and `hasWeakSpots` (v7 on); `WeakSpotSchedule.afterGame(
  slowFactsEnter:)` — an untracked fact answered correctly but slowly enters at box 2, never a
  skill; `scheduleFromHistory` applies each game's own rules. The report counts a v8 slow fact
  as the answer that scheduled it. Simulation: targets met (v3's update); weak spots never off
  tier, at most 20 % of a game. Tests: the v8 rule, v7 unchanged, a mixed v7/v8 history, v8
  draws v7's questions. `/health` lists rules 2–8.
- **Commit 2** *(A)* — **`/health` lists the session kinds the server accepts.** Core:
  `SessionKind.acceptedByServer` (every kind but the placements) and `acceptedWithoutList`
  (games and Training: what a server listing no kinds accepts — the ones before this commit).
  Server: `/health` `kinds: [game, training, weakSpots, drill]`. App: `HttpSessionUploadClient`
  holds an upload, pending, until the server lists its kind as well as its rules (a Weak spots
  game or a Drill never reaches an older server, which would refuse it for good as
  `badRequest`). Tests: the client waits for a practice kind on a server listing none, sends a
  game there, sends a drill to a server listing it; the server's `/health`; the lists.
- **Commit 3** *(A)* — **The server checks that a game's weak spots were due.** Migration
  `20261129000000_upload_history`: `player_upload_history(player)` — the player's accepted
  payloads, oldest first (ties by id), service role only (SQL test `99_upload_history_test`).
  Core: `ValidationFlag.weakSpotsNotDue` (a stored name), `needsUploadHistory` (a Levelling game
  holding weak spots), `weakSpotsNotDue(session, history)` — the schedule rebuilt by
  `scheduleFromHistory`, each weak spot due in it; `validateSessionUpload(history:)` flags,
  never refuses (accepted for levels). Server: reads the history once, only for such a game.
  App: its schedule leaves out the sessions the server refused, so both sides rebuild from the
  same games. Tests: due → no flag; not due → accepted, levels moved, flagged; not checked
  without history; the server flags and reads the history only when needed; the app ignores a
  refused session. SQL tests passed.

### Phase 4 close-out exit (24 Nov 2026)

All three commits live (see below for the deploy check). Not verified here: CI's smoke test
(private repository). Remaining differences between the app's schedule and the server's, each
giving a flag at most: a game played on another device (the server has it, this device does
not), and a session refused after a later game chose its weak spots.

## Phase 7 — Online play: asynchronous duels and friends (plan v3.7)

Plan v3.7 (owner, 25 Nov): asynchronous duels in three modes with their own ratings, friends,
challenges; mockups in `doc/mockups/online.html` (binding). Entry checked: the Phase 4
close-out is live (server on `7b0d7e2`, rules 2–8, kinds listed). Owner actions: none by hand
(migrations and deploys by CI); at the end, two linked test accounts for the checklist.

- **Commit 0** *(A)* — Decisions recorded (`doc/decisions.md`, "Phase 7"), all provisional.
  Core: `DuelMode` (basics, advanced, count — stored names) and `DuelRulesVersion` (v1).
  Server: `/health` lists `duelModes` and `duelRules`. CLAUDE.md's Current phase is Phase 7.
- **Commit 1** *(A)* — **Duel content in the core.** `DuelConfig` rewritten per mode (mode,
  seed, difficulty, game rules, duel rules; strict JSON): Basics and Advanced draw two of each
  of their four types, shuffled by the seed, through `gameExerciseGenerator` at the tier's
  lowest level (`duelTierFor`: 150 points a tier from 900); Get the count draws three puzzles
  (`drawCountPuzzleInBand`: the solo draw of six numbers, then a target whose shortest solution
  length is in the band — `countBandFor`, `countBandOperations` — or the nearest length, shorter
  first). `startingDuelRating` (900 + 15 × main level; advanced mean; 1300) and the provisional
  threshold (10 rated duels). Pins re-recorded on purpose (4 question duels, 3 count duels):
  identical on the VM and in JavaScript. Over 540 count rounds the band fallback is under 5 %.
  Server: a stored config regenerates the pinned content (`duel_content_test.dart`).
- **Commit 2** *(A)* — **Duel runs stored and validated; the pool; fair-play flags.** Core:
  `DuelRun` (quiz answers; Get the count improvements with their operations), `DuelLane` (what
  an opponent sees: times and right/wrong, or times and distances — never values),
  `DuelScore`, `duelResult` (1 / ½ / 0); `validateDuelRun` replays a run against its config —
  questions regenerated and correctness recomputed, every improvement re-derived from its
  round's numbers (`derives`), strictly closer and later, none after the target — refusing
  with a stored `DuelRunProblem`, flagging timing (`implausiblyFast`, `flatTimes`). Migration
  `20261130000000_duels`: `duel_ratings`, `duels`, `duel_runs`, `duel_run_rejections` (service
  role only, cascade from the account) and `duel_take_run` (the pool: accepted, unflagged or
  reviewed ok, < 5 serves, the owner's 10 latest, never one's own or a guest's, never a config
  already played; closest rating, a rematch by closest tier; locked, served once more),
  `duel_insert`, `duel_context`, `apply_duel_run` (optimistic rating versions, the
  challenge's daily limit, expiry with an hour's grace) and `record_duel_run_refused` (the
  duel void). Server: `POST /v1/duels/run` (linked accounts only; turn checked before the
  replay; idempotent; unrated until commit 3). Privacy notice names duel data. Tests: core
  (VM and JavaScript), SQL (`a1_duels_test`), server (in-memory model of the SQL).
- **Commit 3** *(A)* — **Glicko-2 per mode wired to results.** Server: `rateDuel` — each
  rated duel is one rating period for both players, each against the other's pre-duel rating
  (τ 0.5, RD ≤ 350); the run endpoint decides `rated` (pool always, practice never, a challenge
  unless the pair already had a rated challenge in that mode today), starts a missing rating
  from the player's server levels (`startingDuelRating`), applies both updates under the rows'
  versions (stale → re-read, recompute, 3 tries), and answers the rating before and after with
  the provisional flag (< 10 rated duels). Tests on scripted histories: a ten-duel winning
  streak (both sides counted, "?" lifted at the tenth), practice, the daily challenge limit, a
  concurrent update, draws, upsets, the cap.
- **Commit 4** *(A)* — **Matchmaking, practice opponents, rematch.** Core: `practiceLane` (a
  simulated player of the duel's tier from the config alone: 70 % right in 60–140 % of the
  fluent time; count rounds exact half the time, else 1–9 away, in 8–28 s; pinned VM and
  JavaScript). Migration `20261130010000_matchmaking`: `duel_player` (linked, name, rating,
  levels), `duel_open_offer` (the caller's unanswered pool or practice duel of the hour —
  handed back instead of a new one, so asking again never burns runs or shops for an easier
  opponent), `duel_create_challenge` (self, guests refused; one open challenge per pair and
  mode, either way round, serialised; 7 days). Server: `POST /v1/duels` — the open duel, else
  the pool (`duel_take_run`), else practice at the caller's rating (start from levels when
  unrated); `rematchOf` — another run of the same opponent nearest the caller's tier, else a
  challenge to them (after practice: a new search); `challenge` — at the mean of both ratings,
  challenger first. `POST /v1/duels/open` — the friend opens a waiting challenge (its lane).
  Tests: practice and resume, the pool (never one's own, never flagged), Get the count, rematch
  both ways, challenges (open before and after, someone else's), refusals; SQL `a2`.
- **Commit 5** *(C)* — **Duel screens and result** (mockups 2 and 3). Core: `DuelClient`
  (offers, verdicts, `DuelRefused` / `DuelUnavailable` / `DuelAccountRequired`),
  `DuelRunQueue` + `DuelRunStore` (a run saved after every answer and round, sent when it
  ends or at the next flush; held until the server lists its mode and duel rules; a run left
  unfinished is sent with the rest as timeouts / empty rounds); `CountTile.steps` (each tile
  carries the operations that made it). App: `HttpDuelClient`,
  `SharedPreferencesDuelRunStore`; `DuelController` — Basics and Advanced on the game's own
  `SessionController` (timer, timeouts, correction pause, keyboard, effects), Get the count on
  three `CountController.round`s of 30 s (improvements kept, strictly later); lanes (mine by
  answers, theirs at the run's own pace, a miss pausing it 1 s as the correction does); quit
  sends what was played; the device's own reckoning shown at once, the server's verdict (rating
  before → after) when it answers, "Send again" while pending. `SessionScreen` and
  `CountScreen` take an optional lanes header between the counter and the timer bar (null for
  games: the pinned geometry is unchanged). `DuelFlowScreen` (finding, playing, result,
  Rematch in place), `DuelResultView` (Won / Lost / Draw, "Basics · 1 542 → 1 560", the two
  score tiles, mistakes with Method, Get the count's solutions, Online and Rematch). Tests:
  controller (quiz, lanes, quit, offline, refusal, three count rounds), flow with goldens in
  both themes (duel, result, Get the count after Rematch), guests told to save progress.
  The screens are reached from the Online tab in commit 6.
- **Commit 6** *(C)* — **Online tab, badge, the three duel boards** (mockup 1). Migration
  `20261130020000_online_reads`: `duel_overview()` (players only, own duels: linked or not,
  ratings, challenges waiting — not expired —, the 20 latest duels with the result from the
  caller's side, "raced" when their run was the recorded one), `duel_board_top(mode)` and
  `duel_board_around_me(mode)` (linked, ≥ 10 rated duels, rated within 30 days; reasons
  `noDuels`, `provisional` with the duels missing). Core: `OnlineOverview` +
  `OnlineRepository`; `LeaderboardBoard.duel(mode)` (after Main), entries and standings carry a
  rating instead of a level. App: `SupabaseOnlineRepository`, `OnlineController` (each load also
  flushes pending runs and wakes the server; a mode without a rating shows the start from the
  device's levels, "?"), `OnlineScreen` (Duels with ratings, Waiting for you with Play, Recent:
  "Tom raced your run · won", "Practice · Advanced · lost", "waiting", "not counted"; a guest is
  invited to save their progress), the tab's badge (`Badge`, a tooltip in words), duel chips
  on Ranks (a bolt icon and the mode's name) with ratings in place of level badges. The Coming
  soon placeholder is gone. Tests: SQL `a3`, core, Online tab with goldens (both themes), the
  badge, start ratings, Play on a challenge, guests; Ranks goldens re-recorded (new chips).
- **Commit 7** *(C)* — **Friends** (mockup 4). Migration `20261130030000_friends`:
  `friend_codes` (`MATH-` + 4 of the 32 easy characters, created on first use, never changes),
  `friend_requests`, `friendships` (one row per pair), `friend_request_attempts` (20 a day,
  failed lookups included); `my_friend_code`, `friend_request` (sent / friends when mutual /
  already / pending / unknown / self / tooMany), `friend_requests_incoming`, `friend_respond`,
  `friend_remove` (the duels stay), `friend_list` (head-to-head over every decided duel between
  the two, practice excluded), `friend_history`; `duel_overview` counts the requests waiting.
  Linked players only; everything cascades with the account. Core: `normalizeFriendCode`,
  `inviteLink`, models, `FriendsRepository`, `PendingInviteStore`. App: an invite link's code
  (`?friend=`) is kept on the device at start and sent as a request once the player is linked
  (the Online tab says what happened); the Friends pill (a dot and words when requests wait);
  `FriendsScreen` (code, Share link → clipboard, Add code, requests with Accept / Decline,
  friends with head-to-head and Challenge → mode → the challenger plays first),
  `FriendHistoryScreen` (date, mode, both scores, result; Remove friend). Challenges expire
  after 7 days (commit 4's SQL). Privacy notice names friends data. Tests: SQL `a4`, core,
  widgets with goldens (both themes), the invite link, the pill.
- **Fix** *(A)* — **The duel SQL tests now run.** They were named `a1_…`–`a4_…`, outside the
  runner's `[1-9]*_test.sql`: commits 2, 4, 6 and 7 said "SQL tests passed" without them.
  Renamed `99a_…`–`99d_…` and run: the migrations needed no change; the tests themselves had
  four mistakes (untyped literals in row comparisons, a pool-limit block that forgot the
  second run on the same questions, a loop variable read outside its loop, a delete the
  service role may not do). Pitfall added to CLAUDE.md.
- **Commit 8** *(A)* — **Dashboard section.** Migration `20261130040000_duel_dashboard`:
  `owner_dashboard.duels_per_day` (per UTC day, mode and kind: decided, rated, void, open,
  unanswered — opened over an hour ago with no run), `duel_rating_distribution` (bands of 100,
  provisional apart, mean RD), `flagged_runs` with `review_run(id, ok|rejected)` (a flagged
  run stays out of the pool until reviewed ok), `unanswered_duels` per player, `friend_counts`.
  `dashboard.sh duels` prints them; `dashboard.sh review-run <id> ok|reject`; the main report
  gains a 7-day duel summary. Both commands run in the SQL test runner. SQL test `99e`.
  `doc/online.md` describes Phase 7 as built.

### Phase 7 exit test (25 Nov 2026)

The plan's exit, piece by piece:
- *Two linked players race each other's runs in all three modes; ratings move on the server
  only* — `server/test/phase7_exit_test.dart`: in Basics, Advanced and Get the count, the
  first player meets a practice opponent (unrated), the second races that run (rated: both
  ratings move, the run's owner's too), then the other way round. The app never computes a
  rating: it shows the server's (`DuelVerdict`) or the start from levels, "?".
- *A friend added by link and one by code challenge each other and see their history* — SQL
  `99d_friends_test` (codes, requests both ways, head-to-head, history) and the app's
  `friends_screen_test` (Add code, an invite link sent once linked, Challenge → the
  challenger plays first, history); the challenge's second run in `matchmaking_test`.
- *A practice opponent appears when the pool is empty* — `matchmaking_test`, exit test.
- *A forged or implausible run is never served* — a forged Get the count run refused
  (`badDerivation`, nothing stored, its duel void); a run answering multi-digit questions in
  120 ms flagged and kept out of the pool (exit test; SQL `99a` for the pool rules, reviewed
  runs back in, rejected ones out).

Not verified here: the live run on a phone with two accounts (the owner's checklist);
staging's CI smoke test (private repository). Production ran commit 6's server and site at
the time of writing; commits 7–8 deploy with the next CI run.

## Phase 7 close-out (plan v3.8)

Plan v3.8: Phase 7's outcome — every provisional decision kept but one (an abandoned duel
counts); a four-commit close-out; a new CI rule (minimum test counts). Owner actions: none by
hand (the migration goes through CI).

- **Commit 0** — Plan v3.8; Phase 4's pending decisions confirmed (Phase 3b a data check; the
  close-out's commit 3 kept) and Phase 7's outcome recorded in `doc/decisions.md`; CLAUDE.md's
  Current phase is the close-out.
- **Commit 1** *(A)* — **An abandoned duel is a loss.** Migration
  `20261201000000_abandoned_duels`: `duels.progress` and `opened_at`; `duel_save_progress` (the
  second player's open duel only), `duel_mark_opened`, `duel_abandoned(limit)` (pool and
  practice 24 h after they were handed out, challenges 24 h after the friend opened them;
  unplayed challenges void on the way); `duel_context` carries the progress; the owner's
  `flagged_runs` leaves forfeits out, `abandoned_duels` counts them. Core:
  `ValidationFlag.abandoned`, `DuelClient.progress`; the queue tells the server at every
  saved step. Server: `POST /v1/duels/progress`; `/open` marks the challenge opened; every
  duel request first records up to 3 abandoned duels as losses (`sweepAbandoned`, replayed
  from the progress completed with timeouts, rated like their kind, flagged `abandoned`); the
  replay and apply shared with `/run` (`_applyRun`). Tests: server (left after 5 answers → a
  loss with those 5, rated, out of the pool, a late run gets the verdict; no progress;
  malformed progress; practice unrated; unplayed challenge void; opening marks the start), SQL
  `99f`, the queue and the app send progress.
- **Commit 2** *(A)* — **Method in duels uses the pattern's own strategy.** Core:
  `DuelConfig.questionFamilies()` — each question's pattern family from the same draw as
  `questions()` (the generator's `lastFamily`, as `gamePatterns` does for games; the pinned
  questions do not move). App: `DuelController.families`, passed to `methodFor` on the result.
  Tests: families match their questions' types over 40 duels (VM and JavaScript); a missed
  pattern question in a duel shows its family's Method.
- **Commit 3** *(A)* — **Share link opens the share sheet.** `LinkSharer` (app core) and, by
  conditional import, the Web Share API in a browser (`navigator.share`, feature-detected,
  `canShare` checked; the player closing the sheet counts as shared) or none elsewhere until
  Phase 8; the Friends page tries the sheet, else copies the link ("Link copied"). Tests: the
  sheet takes the invite link and nothing is copied; no sheet → copied. The web build compiles
  with it (checked locally); a real sheet is for the phone checklist.
- **Commit 4** *(A)* — **Minimum test counts in CI.** `tool/ci/test_count.sh`: runs a suite,
  reads the passed count from the runner's last line, prints it (an annotation), fails if the
  suite failed, if no count is found, or below the pin. Pinned in CI: core VM 1116, core
  JavaScript 890, tooling 10, server 68, app 447. `tool/sql/test_sql.sh` counts its test files
  (pin 20) and fails on any `*_test.sql` its pattern would skip. Checked locally: an empty run
  (`-n` matching nothing) fails, a run below its pin fails, a stray `zz_…_test.sql` fails.

### Phase 7 close-out exit (25 Nov 2026)

All four commits pushed (and a follow-up: `dart test` uses its GitHub reporter on Actions,
which prints no count, so CI passes `--reporter expanded`). Counts at the close: core VM 1116,
core JavaScript 890, tooling 10, server 68, app 447, SQL 20 files. Live: the site on `ad533ae` (CI's deploy runs only after every counted suite
passed — the new counts work on Actions), the server on `a3882c6` (the last server and core
change; `server_check.sh`: up to date). Not verified here: a real share sheet (needs a phone),
an abandoned duel recorded live (needs 24 hours).

## Review findings (review of 26 Nov 2026, `doc/review-2026-11-26.md`)

Every finding by ID, with the phase that fixes it (plan v3.9, "Project review" and Phases
6a–6c). **State**: `open`, `fixed` (with the commit and its evidence in the Phase 6a section
below), `part` (the part of this phase done, the rest in the phase named), or `decided` (an
owner decision, nothing to build).

| ID | Finding, in short | Phase | State |
|---|---|---|---|
| B1 | No publishable legal surface; age rule | 6c | open (age decided: 15) |
| B2 | Email confirmation off, no CAPTCHA | 6c | open |
| B3 | No password recovery | 6c | open |
| B4 | No abuse protection on the server | 6a (2) | **fixed** |
| B5 | A duel's second player escapes any loss | 6a (1) | **fixed** |
| M1 | Duel answers known before play, times self-declared, flagged runs rated | 6a (1) cheap part; 7b server-timed questions | **part**: no faked time, flagged runs earn nothing; answers still known to a modified client until 7b |
| M2 | A duel replayable with full knowledge | 6a (1) | **fixed** |
| M3 | Rated duels aimed at a chosen player; daily rule bypassed | 6a (1) | **fixed** (no block list: not in the plan) |
| M4 | Quitting bad Levelling games never costs a level | 6b (2), rules v9 | open |
| M5 | Solo sessions fabricated in bulk; no way to remove a cheater | 6a (3) | **fixed** (with the daily cap of commit 2; the seed is still the client's: a session replays to what it claims, it is not chosen by the server) |
| M6 | Names: weak filter, no uniqueness, abusable hiding, `profiles` world-readable | 6a (4) | **fixed** (the word filter itself unchanged: the owner reviews within 48 h) |
| M7 | The main leaderboard does not scale | 6a (5) | open |
| M8 | Matchmaking and the weak-spot check grow with history | 6a (5) | open |
| M9 | Free-plan capacity: stored sessions, Pages Function quota, sleeping server | 6a (5); always-on plan bought before 6c | open |
| M10 | Tiny question pools, repeats | 6b (1), rules v9 | open |
| M11 | Method explanations true but wrong as teaching | 6b (3) | open |
| M12 | Server ↔ Supabase boundary untested; no duel end to end | 6a (7) | open |
| M13 | A push can cancel a production deployment | 6a (7) | open |
| M14 | Empty account on a new device | 6b (5) | open |
| M15 | Rated duel on one tap, no cancel while waiting | 6b (4, 5) | open |
| M16 | Nothing explained to a newcomer | 6b (4) | open |
| M17 | Accessibility | 6b (6) | open |
| M18 | Missing states around the network | 6b (5) | open |
| M19 | Stale reference docs | 6b (8); the `CLAUDE.md` "v6 is current" sentence fixed in 6a (0) | part |
| m1 | An answer at the buzzer can get an honest game refused | 6a (6) | open |
| m2 | One poisoned session blocks a player's uploads for ever | 6a (6) | open |
| m3 | Main level rounded here, floored there | 6b (7) | open |
| m4 | Division never on two lines | — | decided: one line, spec fixed in `doc/levels.md` v1.6 |
| m5 | Weak spots can be 25 % of an operation | 6b (7) | open |
| m6 | No security headers | 6a (6) | open |
| m7 | Daily limits can be raced; short friend codes; invite link sends without asking | 6a (6) | open |
| m8 | Deleting an account deletes opponents' duel history; notice wording | 6a (4); notice wording with 6c (2) | **fixed** in 6a (duels kept, in-app notice says so); the published policy is 6c |
| m9 | Wrangler state committed | 6a (0) | **fixed** (GitHub still holds the old commits by hash until its own cleanup) |
| m10 | Abandonment sweep runs inside other players' requests | 6a (6) | open |
| m11 | Trivial questions at high tiers; unbalanced duels | 6b (1), rules v9 | open |
| m12 | Files that carry too much | when next touched | open |
| m13 | App contracts in the core; logic twice in Dart and SQL | when next touched | open |
| m14 | Seven replayable rules versions | 6c (6): v2–v6 retired 30 days after v9 | open |
| m15 | Dead dependencies; `PREVIEW_BUILD` always on | 6a (7) | open |
| m16 | Test gaps (SQL pin counts files, no catalogue test, two server cases) | 6a (7) | open |
| m17 | Smaller friction (sign-out, pending uploads, rules of two modes, terms) | 6b (4, 7) | open |
| m18 | No localisation mechanism | 6b (7): strings in one place, English at launch | open |
| m19 | `doc/decisions.md` unmarked superseded entries; legal README gap | 6b (8); the notice gap with 6c (2) | open |
| m20 | Pattern families that do not grow with the tier | 6b (1), rules v9 | open |
| m21 | Subtraction T8 second number, non-monotone tiers, Tables repeat | 6b (1), rules v9 | open |
| n1 | "Once a day" is a UTC calendar day | 6a (1) | **fixed** |
| n2 | Staging CORS pattern too wide | 6a (6) | open |
| n3 | Functions without `search_path`; root container; dashboard password on the command line | 6a (6) | open |
| n4 | Stale comments | 6a (7) | open |
| n5 | Reviewer agent checks 17 rules of 18; `MSYS_NO_PATHCONV` undocumented | 6a (7) | open |
| n6 | `default:` branches on `PatternFamily` | 6b (3) | open |

## Phase 6a — Integrity and capacity (plan v3.9)

- **Commit 0** *(A)* — **Repository hygiene (m9); the review's decisions recorded.** Plan v3.9
  and `doc/levels.md` v1.6 (the owner's) and the review committed; CLAUDE.md's Current phase is
  6a, and its "v6 is `current`" sentence is fixed (v8 is; the next generation change is v9, in
  6b). `tool/cloudflare/.wrangler/` (46 files) removed from the index and ignored
  (`.wrangler/`). The owner's 15 answers recorded in `doc/decisions.md` ("Project review").
  **`doc/levels.md` v1.6 broke the spec-conformance test** (it reads the owner's file and draws
  under `RulesVersion.current`, still v8, and the phase must not touch generation): until v9 is
  current the test reads `packages/math_core/test/spec/levels_v1_5.md`, the spec as committed
  before v1.6 — provisional, `doc/decisions.md` "Phase 6a". 190 conformance tests pass as before.
  **History purged** (26 Nov, 13:52 UTC): mirror backups first, outside the repository, in
  `D:\mathtrainer-backup\2026-11-26-pre-purge\` — `origin.git` (GitHub as it was, 213
  commits), `local.git` (the same plus this commit), a bundle of it, and
  `commit-map-old-new.txt`. `git filter-branch` from `9669a70` (the commit that added the
  directory) to the tip: **124 commits keep their hash, 90 are rewritten** (old `77f063c` is
  `347e4cc`; this commit is `dd5cd7a`); each rewritten commit compared with its original —
  same files apart from `.wrangler/`, same author, dates and message. No path under
  `.wrangler/` is left in the history. (A first pass rewrote everything from commit 64 on,
  because GitHub's signature on one web-made commit was dropped; redone from `9669a70` only.)
  Force-pushed with a lease on the old tip. **Verified after the push**: CI ran on the new
  history and deployed everything in order — staging site and server, production site and
  server all on `dd5cd7a` 16 minutes later (`main.dart.js` and `/health`, `server_check.sh`:
  up to date on both). **Not removed**: GitHub still serves the old commits to an
  authenticated fetch by hash until its own garbage collection (checked: `git fetch origin
  77f063c…` still answered); only GitHub Support can force it. Hashes quoted in older parts
  of this file, from `9669a70` on, are the old ones: the map translates them.
- **Commit 1** *(A)* — **Duel results hold (B5, M1 cheap part, M2, M3, n1).** Migration
  `20261202000000_duel_integrity` (every function keeps its signature: the server deployed
  before it keeps working): `duels.chosen` (challenges and rematches), rated once per pair and
  mode over a rolling 24 hours (`duel_pair_rated_recently`); `record_duel_run_forfeit` (the
  reason, the duel not void); `apply_duel_run` no longer expires an opened challenge;
  `duel_create_challenge` only to a friend or an opponent of the last 30 days, open for 6
  days then 24 hours to play; `duel_context` gives `now`, `chosen`, `firstFlags`;
  `owner_dashboard.forfeited_duels`. Core: `DuelRun.continues` and `claimedMs`,
  `DuelRunProblem.notElapsed`, `ValidationFlag.forfeited`; the queue stores a step before
  telling the server. Server: the second player's unreplayable run is a forfeit (a loss from
  the run completed with timeouts if that replays, else the progress held, else nothing);
  progress parsed, stored in the server's shape, and refused unless it continues what is
  held; a final run likewise (`progressMismatch`, the duel stays open); `rematchOf` only a
  finished duel of the same mode; a challenge played only once opened; claimed time checked
  against the database's clock (5 s margin); a flagged run earns nothing. **The review's
  exploits, replayed** (`server/test/duel_integrity_test.dart`, 13 tests; before → after):
  a run with no answer — void, new opponent at once → a rated loss, the same verdict for
  anything sent after; an unreplayable progress then silence — void → a rated loss after 24
  hours; a challenge opened in its last day and left — void → a rated loss; the same duel
  replayed from a second device — accepted → 409 `progressMismatch`, device 1's answers stand;
  a challenge to a stranger — created → `notAllowed`; `rematchOf` on any duel — a rated pool
  duel every time → `notFinished` / `wrongMode`, and the rematch unrated when the pair was
  rated within 24 hours; eight answers "in 4 s each" sent 10 s after the offer — accepted →
  a loss (`notElapsed`); a flagged winning run — rated → unrated (a flagged losing run still
  loses). SQL `99g_duel_integrity_test.sql`; core `duel_run_progress_test.dart` (7, VM and
  JavaScript). Counts: core VM 1123, core JavaScript 897, server 81, app 447, SQL 21 files.
- **Commit 2** *(A)* — **Abuse floor (B4).** Server: `rate_limit.dart` — token buckets in
  memory, per address (120, +2/s; checked before anything else, `/health` and preflights
  exempt) and per player (40, +0.5/s), bounded (20,000 keys); `readBodyWithin` counts a body
  while it is read and gives it up at the cap (sessions 256 KB, duels 64 KB) — both endpoints
  used `readAsString()`; `looksLikeAccessToken` — a bearer that cannot be a Supabase token
  (not a JWT, no user id, expired) is answered 401 by the gateway with no outbound call;
  daily caps of 300 accepted sessions and 200 new duels per player, read from calls the
  server already makes (`player_server_state.acceptedToday`, `duel_player.duelsToday`). Every
  limit answers 429, which both app clients already treat as "retry later". Migration
  `20261202010000_abuse_floor`: `refusal_digest` (SHA-256, size, first 1,000 characters) for
  refused uploads and duel runs, existing rows reduced; `record_rejected_upload` keeps 50 a
  day per player (advisory lock on the count), details cut at 500 characters; two indexes on
  `(player_id, received_at)`. **Measured** (scratch Postgres 18, 2,000 crafted refusals of
  ~250 KB with fresh ids across 40 accounts): **498 MB before, 2.8 MB after**; one account
  alone keeps 50 rows (~73 KB). The same probe is now an assertion (`99h_abuse_floor_test.sql`:
  under 5 MB). Tests: `server/test/abuse_floor_test.dart` (14: buckets, the address limit
  with CORS and `retry-after`, a chunked endless body cut after ≤ 300 KB on sessions and
  ≤ 80 KB on duels, token shapes, the real gateway against a mock HTTP client — nothing sent
  for garbage — the per-player limit, both daily caps). `supabase_gateway.dart` line
  coverage rises from 11 % (review) with these. Counts: server 95, SQL 22 files.
  **Checked on staging after the deploy** (26 Nov, server `5c2d643`), the address limit behind
  Render's proxy: 200 requests in a row with a bogus token → 193 × 401, 7 × 429 (the burst of
  120 plus the refill over the run); 260 requests each with its own forged
  `X-Forwarded-For` → 221 × 401, 39 × 429 in 51 s (120 + 2 × 51 = 222: one key — forging
  changed nothing); 260 with a forged `CF-Connecting-IP` → 260 × 403 from Cloudflare, before
  the server. Render is behind Cloudflare, which sets that header itself: the key cannot be
  chosen by a client. A bogus token now costs no call to Supabase (401 at once, locally and
  on staging).
- **Commit 3** *(A)* — **Solo integrity and moderation (M5).** Core: a session whose end
  (`createdAt` + its answers' times) is after the moment it was received (beyond the 5-minute
  skew) is refused `futureTimestamp`; one created before the player's previous session could
  have ended (2 s tolerance) is flagged `overlapsPrevious` and accepted
  (`ServerPlayerState.lastSessionEndsAt`). Migration `20261202020000_moderation`:
  `server_players.last_session_ends_at` (back-filled from each player's latest session);
  `player_moderation` (hidden / banned, reason, date; cascades with the account) read by
  `leaderboard_rows`, `duel_board_rows`, `duel_take_run` (both ways), `duel_create_challenge`
  and `friend_request` through `player_visible`; `my_account_under_review()` for the app;
  `owner_dashboard.moderate` / `unmoderate`, views `moderation` and `moderation_evidence`
  (flagged sessions by flag, refused uploads, flagged, forfeited and abandoned duel runs,
  last 30 days). Server: a banned player's uploads and new duels answer 403
  `account_suspended` (nothing decided; a hidden one still plays, unranked, against practice
  opponents). `dashboard.sh moderation | hide | ban | unhide` (run by the SQL suite). App:
  Profile says "Account under review" with one line of why; the privacy notice names
  fair-play marks and a review decision. Tests: core cadence (3), SQL
  `99i_moderation_test.sql`, server `moderation_test.dart` (4), Profile (1). Counts: core VM
  1126, core JavaScript 900, server 99, app 448, SQL 23 files.
- **Commit 4** *(A)* — **Names and privacy (M6, m8).** Migration
  `20261202030000_names_privacy`: the name rule allows **Latin letters only** (owner's answer
  15; Greek and Cyrillic names already saved are kept — `NOT VALID`); `fold_display_name`
  (422 letters folded to the Latin letter they read as, upper case included; separators
  dropped; i/l/1, o/0, rn/m, vv/w) and a **unique index** on it, after
  `resolve_duplicate_display_names` (the earliest profile keeps a name, later ones become
  "Name 2", "Name 3"…; only the count is printed); `profiles` readable by its owner only
  (anon: no grant); `report_player_name` from saved accounts only (42501), 10 a day (54000,
  advisory lock), a re-report after a review counts again; `public_display_name` hides a
  player with any report newer than their latest review (`name_reviewed_at`) — renaming no
  longer brings a reported name back; `review_name` records every verdict;
  `names_to_review` oldest report first (same columns); `duels.first_player` /
  `second_player` `on delete set null`, the practice check rewritten; `duel_opponent_name`
  ("Deleted player"); `duel_abandoned` voids open duels left with nobody and never lists them.
  **Fix of commit 1**: `duel_overview` kept a challenge in "Waiting for you" only until its
  opening date — one opened in time disappeared during its 24 hours to play; now it stays.
  Core: `displayNameCharClass` Latin only, `DisplayNameTaken`; the parity test reads the newest
  migration defining the rule. App: a taken name says so on Profile; a guest's report says
  "Save your progress to report a name." and sends nothing; the report dialog and the privacy
  notice say what changed (goldens re-rendered). SQL tests: `99j_names_privacy_test.sql`,
  `40`, `10` rewritten for the new rules; every duel test clears `public.duels` (duels now
  outlive the players the tests delete). Tests: core name samples, app (2). Counts: core VM
  1126, core JavaScript 900, server 99, app 450, SQL 24
  files.
