# Math Trainer

Competitive mental-arithmetic game in Flutter, for teens and adults. UI, code, docs and commits
in English.

**`doc/plan.md` (version 3.8) is the product plan**, and **`doc/levels.md` (v1.5) specifies the
level system**. Both are the owner's: read them at the start of every phase; never edit them.
This file is the working file: keep it short, update it as the project moves, keep it
consistent with the plan. Other docs when relevant: `doc/architecture.md`, `doc/decisions.md`,
`doc/design.md`, `doc/online.md`, `doc/progress.md`. The plan wins any conflict — report it.

## Current phase

**Phase 7 close-out** (`doc/plan.md` v3.8, section 7), run in **one pass**, four commits.
Phase 7 (asynchronous duels in three rated modes, friends) is live; its outcome kept every
provisional decision but one — an abandoned duel now counts — which commit 1 applies.

| # | Commit | Note |
|---|---|---|
| 1 | *(A)* **An abandoned duel is a loss**: a duel started but not submitted within 24 hours is recorded as a loss with the answers the server received so far; clearing the browser or switching device no longer escapes it | done |
| 2 | *(A)* **Method in duels** uses the pattern-specific strategy, like solo games | |
| 3 | *(A)* **Share link** opens the phone's share sheet (Web Share API) where the browser has one, clipboard otherwise | |
| 4 | *(A)* **Minimum test counts** in CI for every suite (core VM, core JavaScript, app, server, SQL) | |

**New rule (plan v3.8):** every test suite in CI states how many tests it ran and fails below a
pinned minimum — a suite that silently runs nothing turns red. **Known limit:** the free Render
server sleeps (30–60 s before the first duel after a quiet period); a paid plan is an owner
decision before Phase 6.

**Phase 7's rules** (plan v3.7–v3.8; detail in `doc/decisions.md`, "Phase 7"):
- **No live matches**: every duel is asynchronous — a player races another's recorded run,
  replayed at its original pace as a second lane. **Linked accounts only** (guests are invited
  to save their progress). Chain operations stays solo. Tournaments: later.
- **Three modes, each with its own rating and board**: **Basics** (8 questions, 2 each of
  + − × ÷) and **Advanced** (2 each of x², √, %, ∫) — more correct wins, then less total
  time; 30 s per question, Method on misses. **Get the count**: 3 rounds of **30 s**, same
  numbers and targets for both — smaller total distance wins, then less total time (a round's
  time = when the closest value was reached; reaching the target ends it).
- **Difficulty from the rating**: Basics/Advanced — every 150 points is a tier (900 → T0,
  1500 → T4, ≥ 2250 → T9), drawn exactly as a game at that tier with the duel's own seed and
  rules version. Get the count — shortest-solution length 2–3 / 3–4 / 4–5 operations below
  1300 / 1300–1700 / above 1700 (tunable). Both players always get the same questions.
- **Glicko-2, server only**, one rating per mode, each duel its own period, RD capped at 350,
  τ = 0.5. Start: Basics 900 + 15 × main level, Advanced 900 + 15 × mean of the four advanced
  levels, Get the count 1300; "?" for the first 10 duels of a mode. **Both sides move** (a
  run's owner learns it later). Friend duels rated **once a day per pair and mode**.
- **Matchmaking**: the run of the player with the closest rating — never one's own, never a
  run already raced; a run served at most **5 times**, only a player's **10 latest runs** per
  mode in the pool. Empty pool → **Practice** opponent (simulated, no rating change).
  **Rematch** races another run of the same opponent, else sends them a challenge.
- **Friends**: a friend code (`MATH-7K2P`) and an invite link; requests, accept, remove; list
  with head-to-head, history per friend; **challenges** (challenger plays first, the friend
  plays the same questions from "Waiting for you"; **7-day expiry**). In-app badges only.
- **Fair play**: every run replayed and validated by the server; a failed run never enters the
  pool and its duel does not count; implausible timing keeps a run out of the pool until
  reviewed; friend requests limited (~20 a day). **An abandoned duel is a loss** (v3.8): a duel
  started but not submitted within 24 hours, recorded from the progress the app sends during
  play (`/v1/duels/progress`), by the next duel request (`sweepAbandoned`).

Done: nothing yet. Phase 7 (commits 0–8, exit test) is live since 25 Nov; its provisional
decisions are settled (plan v3.8), and so are Phase 4's.
Phase 3b is a data check, not a blocker (confirmed in v3.8): a report at ~300 sessions from
10+ testers since the rules v5 release (`owner_dashboard.calibration_window`).

**Weak spots** (Phase 4, rules v7–v8; detail in `doc/decisions.md`, "Phase 4"): facts and
skills, five boxes counted in games (due after 1, 2, 4, 8, 16), rebuilt from stored answers
(`scheduleFromHistory`); Levelling games re-ask at most ⌊N/5⌋ due items, **only from the
operation's current tier**; Weak spots and Drill games are practice kinds (uploaded, never move
levels, never ranked).

**The level system** (`doc/levels.md`; constants: `LevelRules.of`)
- **Levels 0–100**, integer hundredths, shown whole; everyone started at 0 at the transition
  (rules v2); no placement test. Never decay; frozen at the start of a game.
- **Ten tiers** per operation (T0 = 0–9 … T9 = 90–100): the tier decides the content and the
  **fluent time**; from rules v5 every question comes from the player's tier (v2–v4: 30 % from
  the tier below). Generation stays backwards (rule 10). From rules v4, **pattern questions**
  (spec 5b, 49 `PatternFamily`): 2 in 5 where a family is available; from v5 **sized by tier**
  (`patternQuestion(family, tier, r)`: spec 5b's size table, and a hard limit of the standard
  questions of the tier or the next). Every mistake of a game gets a **Method** (spec 9,
  `methodFor`).
- **Level update, per operation, Levelling games only**: credit per answer (fluent 1.0, correct
  but slow within 30 s, wrong or timeout 0); `q` = mean credit; a dead band; up
  `cap_up(n) × min(1, (q − high) / 0.25)`, `cap_up` 3 / 3 / 4 / 5 for n = 4 / 5 / 10 / 20; down
  `cap_down × min(1, (low − q) / 0.35)`. Integer arithmetic only (rule 18); the server replays it.
- **Rules versioned**: stored with each session; the server replays each session under its own
  rules and lists them in `/health`; the app holds a session until the server lists its rules.
- Display: one line, two right-aligned lines when it doesn't fit, ÷ always one line. Tables mode
  and the Tips page are never ranked. Kept: 30 s timer, three silent timeouts end the game
  uncounted, questions per operation 4/5/10/20, Training never moves levels (T1 / T4 / T7),
  main level = mean of the four basics.

**Rules v5–v6** (24 Nov): pattern questions sized by tier, no reviews (`doc/levels.md` v1.4);
√ of powers of 2 by its own row (v1.5). v4 and v5 kept for replay. Staging is live: with
`STAGING=on` the full smoke test plays on staging, production's is read-only. Still parked: the
slow-4G measurement past the gate (a CI beta code). The repository is private since 20 Nov: CI
results are visible to the owner only — a push is verified by its commit appearing in the live
`main.dart.js` (deploy runs only after the tests).

Preview: `https://math-trainer-kjc.pages.dev/` (Cloudflare Pages), deployed on every push to
`main`. The old `https://geriogerg.github.io/Math-Trainer/` redirect is off since the
repository went private (free GitHub Pages: public repositories only); CI publishes it again
with the variable `GITHUB_PAGES_REDIRECT=on`.

## Who you work with

Experienced developer (Python, Java, C/C++, ML), strong in architecture; new to Dart, Flutter and
mobile. Don't explain general concepts; explain non-obvious Dart/Flutter idioms the first time
only.

## Platform

Windows. **Web-first**: the web build is the product, mobile web is the reference device. Mobile
development is paused until Phase 8. Never propose anything needing Xcode locally.

## Architecture rules

Non-negotiable without explicit discussion.

1. **Pure-Dart core**: `packages/math_core` has no dependency at all (no Flutter); app and
   server import it by path.
2. **Deterministic generation**: explicit seed, no unseeded `Random()`; same (seed, config) → same
   sequence.
3. **Persistence behind abstractions**: storage packages only in `infrastructure/`.
4. **Repositories always async.**
5. **UUIDs**, never `AUTOINCREMENT`.
6. **UTC timestamps**; `createdAt` ≠ `syncedAt`.
7. **Strict layers**: never UI + logic + state in one file.
8. **Immutable models**: `final`, `copyWith`.
9. **Every expected answer is an `int`**; division with `~/`.
10. **Generation builds the result** (draw `r`, show `r²`); never rejection sampling.
11. **No `default`** in a `switch` on `Exercise`, `ExerciseType`, `OperationType`.
12. **`OperationType` stays inside `ArithmeticExercise`**; the selection axis is `ExerciseType`.
13. **Invariants by `throw`, never `assert`**, each with a test of the invalid case.
14. **No signal by colour alone.**
15. **Web-specific code only in `infrastructure/`**, chosen in `composition_root.dart`.
16. **No dependency without Android and iOS support**, unless its mobile replacement is in
    `doc/decisions.md`.
17. **The server never trusts the client.** The service-role key never appears in the app, the
    repo or CI logs.
18. **Same result on VM, JavaScript and WebAssembly**: generation and level maths use only
    `+ − × ÷` and `sqrt` — no `pow`, `exp`, `log`, trigonometry — and store integers.

## Data and accounts

- Local SQLite (web: WebAssembly + IndexedDB), keyed by the Supabase user id. Every answer stored
  with its own timestamp, operands, given answer, time, correctness, level.
- **Levels**: integer hundredths in [0, 10000] (3742 = 37.42), shown as a whole number with a
  progress bar inside the level; the whole part's tier (`Tier.of`) sets the content and the fluent
  time. An absent level is 0. Recomputable from history by a core function. The **main level**
  (`mainLevel`) is the mean of the four basics only, unplayed at 0; the main board keeps the
  server key `overall` (cached builds call it by that name).
- **Rules versions** (`RulesVersion`, stored with every session): v2 = the Levels phase's
  `doc/levels.md` v1, except addition and subtraction (an earlier draft's 4-digit tables); v3 = v2's
  questions, the update tuned (Levels close-out, `LevelRules.v3`); v4 = v3's update, pattern
  questions (one size for every tier — 2²⁰ at level 15) and the spec's long addition and
  subtraction; v5 = v4 with pattern questions sized by tier and no reviews (`doc/levels.md`
  v1.4); v6 = v5 with √ of powers of 2 sized by its own row (v1.5); v7 = v6 plus weak spots
  in Levelling games (Phase 4; without weak spots a v7 game is a v6 game); v8 = v7 with slow
  facts entering the schedule at box 2 (Phase 4 close-out, current; scheduled per game's own
  rules, `slowFactsEnterSchedule`); v1 (all before
  the transition)
  is retired — never replayed, refused by the server (`rulesRetired`),
  never sent by the app, kept in history.
- **Sessions are self-contained**: everything deciding question order is stored with them.
- **Session kinds**: game or training (fixed levels frozen in the session, no level update —
  `NoLevelUpdates`; uploaded and validated, never ranked). The placement kinds are history only.
- **Duels and friends** (Phase 7) live on the server only (Supabase tables, closed to the API;
  the app reads through `security definer` functions, writes through the Dart server). On the
  device: only runs waiting to be sent (`DuelRunQueue`, `shared_preferences`) and an invite
  code waiting for the player to be linked. A duel never touches levels or session history.
- **Anonymous-first**: anonymous user created on first launch; linking keeps the same user id;
  email already used → sign in after a "guest progress replaced" warning, no merge; no sign-out
  for anonymous players; deletion via a `security definer` SQL function on `auth.uid()` only.
  Only linked players appear on the leaderboard. Detail: `doc/plan.md` section 6.3.

## How a phase runs

**One pass**: the owner's prompt is "Run Phase N" (or "Continue Phase N" after an interruption).
The whole phase runs without waiting for the owner.

1. Read the phase in `doc/plan.md`, this file, `doc/progress.md`, `doc/decisions.md`.
2. **Send one message listing everything the owner must do by hand** for the whole phase (GitHub,
   Supabase dashboard, SQL to run — write SQL files first so they can be run early), with exact
   steps. **Do not wait** for the answer.
3. Every commit in order: short plan in the commit message, implement, test, document, commit,
   push. Checkpoint commits are deployed and played by the owner at the end, not one by one.
4. **Owner decisions** reached mid-phase: choose the best option with evidence (simulation,
   measurement), mark it **provisional** in `doc/decisions.md`, continue. The owner confirms or
   reverses in the report.
5. **Blocked on something only the owner can do**: park that step in `doc/progress.md`, continue
   with what does not depend on it, come back to it before the end.
6. After each commit: update "Current phase" and `doc/progress.md` — enough for "Continue
   Phase N" to resume cleanly after an interruption.
7. End: exit test, then the phase report.

**Hard stops — the only reasons to stop mid-phase**: an action that could destroy or lose user
data beyond what the plan approves; a secret that would land in the repo, the app or CI logs; a
new dependency without Android and iOS support; tests red after two attempts; a blocking issue
with no fix (e.g. a VM/JavaScript mismatch you cannot resolve). Anything else: decide, record,
continue, report.

**Phase report**: delivered vs plan; deviations; **provisional decisions to confirm**; what the
owner must play on the preview (a short checklist); what could not be verified; debt; numbers;
**plan alignment** (`doc/plan.md` section 11). Honest over flattering.

**Collaboration**: Plan mode for non-trivial work; trace ripples to persistence first; don't
rewrite working code; list files touched; no abstraction for a single use case.

## Conventions

- Business logic comes with unit tests. Determinism tests keyed on (seed, config), on VM and JS.
- Every `Exercise` variant implements `==` and `hashCode`.
- No hard-coded UI values (`Theme.of(context)`); `SafeArea` everywhere; comment the non-obvious.
- On-screen keypad is the primary input; the native keyboard never appears during a game.

**Before every commit**: core tests on VM and JS, `flutter test`, `flutter analyze` clean, CI
green. Until Phase 8, the weekly "Android build" workflow (`.github/workflows/android.yml`,
compile-only, also on demand) is the only Android check — say so when it matters.

## Commands

```bash
# packages/math_core/
dart test                        # core on the VM
dart test -p node                # core compiled to JavaScript
# app/
flutter test
flutter analyze
flutter run -d edge --web-port=8080 --dart-define-from-file=dart_defines.json
# server/
dart test
docker build -f server/Dockerfile .          # from the repo root
dart run tool/gate_probe.dart <server> <supabase url> <key>  # in server/: direct-API gate probe
# repo root
dart format app/lib app/test packages server tool   # what CI checks
node tool/smoke/preview_smoke.mjs <url> [chrome]   # smoke test; SMOKE_NETWORK=slow4g to time it
bash tool/sql/test_sql.sh <postgres admin url>     # migrations (twice) + SQL tests, scratch DB
bash tool/dashboard/dashboard.sh [command]        # owner report and chores (live DB, local only); weak-spots: Phase 4 report
bash tool/ci/server_check.sh <server url>          # server up to date with HEAD (commit, rules)? read-only
python -P -E tool/fonts/subset_digits.py <Font[wght].ttf> <out.ttf>  # digit face subset (fonttools)
python -P -E tool/fonts/instance_inter.py <Inter[opsz,wght].ttf> app/assets/fonts/Inter.ttf
node tool/web/boot_config.mjs app/build/web app/dart_defines.json  # after a local release build
SMOKE_TRACE=1 node tool/smoke/preview_smoke.mjs <url> [chrome]  # + request waterfall
# app/: flutter test tool/icons/render_web_icons_test.dart  # favicon + web app icons from OperatorIconPainter
```

`app/dart_defines.json` (not versioned) holds the Supabase URL and public key; in CI they come from
the `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` secrets.

## Pitfalls (append new ones)

- `session_layout_pin_test.dart` holds the game screen's keypad and session geometry (and the
  30 s timeout). Re-measured once at the Redesign phase's commit 6 on the new screen; frozen
  again since — never update its numbers to make a restyling pass, change the restyling. Sound and haptics go through
  `SessionEffects` (fire and forget, after the controller moved on), never inline in a widget.
- Screens build buttons, chips, keys, figures and levels from `presentation/kit/` — never
  `FilledButton`, `TextButton`, `FilterChip` or `ChoiceChip` directly. Find a level in tests
  with `findLevelBadge(n)`, not its text.
- Local `flutter build web` on Windows can drop `web/` files (sqlite3.wasm, manifest) from an
  incremental build: `rm -rf build/web` first when testing a local release build.
- The page signs in before Flutter starts (`web/index.html`, `window.mtBootAuth`): it must
  never create a player where the app would ask for a beta code first, and the app must await
  it (`waitForBootSignIn`) before `Supabase.initialize`. A local release build needs
  `tool/web/boot_config.mjs` to get it; without, the app signs in by itself.
- Cloudflare serves the big files from `.br` copies (`tool/cloudflare/`): a new large asset
  outside `_routes.json` is served by Cloudflare's weaker on-the-fly brotli — add its path.
- `Inter.ttf` holds weights 400–500 only: a style asking for 600+ renders at 500.
- Vibration goes through `GameHaptics` (feature-detected; none on iPhone Safari).
- Sound goes through `GameSound` (Web Audio synthesis, no files); the smoke test fails if a
  game schedules no tone — a change that silences the game breaks CI on purpose.
- Digits use `TextStyle.digits` (Space Grotesk subset: digits, operators, "of" only). A line
  mixing faces grows 1 px — keep each prompt in one face; anything else falls back to Inter.

- CI analyzes with `--fatal-infos` (core and tooling): run `dart analyze --fatal-infos` locally,
  an info-level lint fails the build.
- Never draw at random from a `Set` (insertion order); use a list sorted by enum `index`.
- `ExerciseType` and `SessionKind` names are stored discriminants; renaming breaks history.
  Phase 4 added `weakSpots` and `drill` (practice: replayed and checked by the server, never a
  level update); test `kind.movesLevels`, never `kind != training`.
- `duel_config_test.dart` pins duels' questions and Get the count rounds (re-recorded once, on
  purpose, at Phase 7 commit 1, when duels moved from rating brackets to modes; no duel was
  stored before): a change to generation that moves them breaks every stored duel — never
  update the pins to make a test pass. Duels store their game rules and `DuelRulesVersion`.
  `Strategy` names are stored too (Phase 4 tips).
- Changing what a tier draws changes every stored v2 session's replay: a new rules version
  instead (`RulesVersion`, `doc/levels.md` section 4), the old one kept replayable.
- A new rules version goes in `RulesVersion` (`current`, `replayed`), `LevelRules.of` and
  `gameExerciseGenerator`. The app holds its games until the server's `/health` lists it: after
  every push changing `server/` or the core, `tool/ci/server_check.sh <production url>`; not up to
  date (CI's deploy waits for tests, ~15 min) → tell the owner at once.
- `PersistedSession`'s `rulesVersion` defaults to v1 (rows stored before it): a test session
  meant to upload or replay passes `RulesVersion.current`.
- Integer levels round small steps to zero — never round before storing hundredths.
- `Level` is an `int` at runtime: string interpolation prints hundredths, and `level ?? 1`
  compiles (widens to `Object`). Display through `.whole`; fall back to `Level.zero`.
- **`doc/levels.md` is checked by reading the file** (plan v3.4):
  `packages/math_core/test/spec/levels_spec_conformance_test.dart` (VM only) parses sections 5
  and 5b — each example drawn by its tier or family under `RulesVersion.current`, each tier's
  digit counts, levels and fluent time, each family's tier. When it fails after a spec change,
  the code is behind the spec: a new rules version, never an edit of the test to fit the code.
  Hand-copied tables in other tests are no proof of conformance.
- `packages/math_core/test/tiers/tier_references.dart` (v2), `tier_references_v4.dart` (v4),
  `tier_references_v5.dart` (v5) and `tier_references_v6.dart` (v6) are generated (in `packages/math_core`: `dart run
  tool/tier_references.dart`) only by a change meant to alter a version's questions — never to
  make a JavaScript failure pass. The tool rewrites them all: an older file that changes is a
  bug. v6 is `current` and played: its generation is frozen like the others' — a change is v7
  (v6 shows the pattern: `patternQuestion` delegates to the frozen `patternQuestionV5` except
  where it differs).
- A pattern family's Method recognises the family from the question's shape
  (`method_for.dart`): a family that grows must keep its shape recognisable at every size —
  the Method test runs every family at every tier.
- Pattern families are never stored: `replaySessionPatterns` recomputes them from the session.
- **Duel names are stored or sent**: `DuelMode`, `DuelKind`, `DuelRunProblem`,
  `FriendRequestOutcome`, `DuelRulesVersion.number` — never rename one. A duel's content,
  its practice lane and its count rounds are pinned (VM and JavaScript): a change that moves
  them is a new `DuelRulesVersion`. Never a bitwise operation on a seed (JavaScript cuts it
  to 32 bits: `practiceLane` uses `seed + 1`).
- `SessionScreen` and `CountScreen` take a `header` (a duel's lanes): games pass none — the
  game screen's geometry is pinned. A duel's `SessionController` uses a throwaway repository
  and `NoLevelUpdates` (`buildDuelController`).
- The server checks a duel run's turn **before** replaying it: a refused replay voids the duel,
  so a run sent out of turn must never reach it.
- **Weak-spot item keys are stored** (`PersistedSession.weakSpots`, schema v13, upload
  `weakSpots`): `fact:<type>:<numbers>`, `skill:<family>` — never change the format, an
  `ExerciseType` or a `PatternFamily` name. Weak spots in a Levelling game come only from the
  operation's current tier (`belongsTo`, checked by the replay); `factsAt` must match what each
  tier's standard questions draw (`fact_tiers_test.dart`) — a change to section 5's tables
  changes it. The schedule is never stored: `scheduleFromHistory` rebuilds it.
- `Random.secure()` throws under `-p node` (dart2js + Node 24); browsers are fine.
- `web/sqlite3.wasm` and `web/sqflite_sw.js` come from `dart run sqflite_common_ffi_web:setup`;
  rerun with `--force` after upgrades. On GitHub Pages every path respects `/Math-Trainer/`.
- Always web port 8080 locally: session and settings live in `localStorage`, scoped by port.
- Signing out an anonymous user loses the account — never offer it.
- Anonymous sign-ins are rate-limited (30/hour/IP); automated tests delete the accounts they
  create (the smoke test through "Delete my data", which needs `delete_my_account()`).
- SQL goes in versioned migrations applied by CI (from commit 2); never run SQL by hand, never
  print the access token or database password.
- The dashboard prints testers' data: run it locally only, never from CI (logs outlive any
  change of the repository's visibility). A new
  view goes in `owner_dashboard`, never in `public` (the API serves `public`).
- Tests never write to production (Phase 5.2): with `STAGING=on` the full smoke test runs on
  staging, production's is read-only (`SMOKE_READ_ONLY=1`). Never point a test, probe or
  script that creates accounts at the production project.
- Render services deploy only through CI's hooks (`tool/ci/render_deploy.sh`, after that
  environment's migrations); a new deploy step goes after migrations, staging before production.
- Deploy jobs run on a push **or** a manual run on `main` (`event_name != 'pull_request'`):
  owner steps that say "Run workflow" rely on it.
- `*.pages.dev` names are global: `math-trainer.pages.dev` is someone else's site, ours has a
  suffix. Never hard-code the Cloudflare address; CI reads it from the project and checks
  `PREVIEW_URL` before publishing the redirect.
- `supabase db push` needs `--remote`: newer CLIs target a local stack by default and fail on
  `127.0.0.1:54322`. CI pins the CLI (`.github/actions/supabase-migrate`, v3.3.0): `version:
  latest` hits GitHub's anonymous API rate limit and fails the migration job (24 Nov).
- `tool/sql/test_sql.sh` runs only `supabase/tests/[1-9]*_test.sql`: a test named otherwise
  (`a1_…`) is silently skipped and "SQL tests passed" still prints (Phase 7: four duel tests
  went unrun for five commits). Name new ones `99x_…` or with a leading digit, and check the
  runner's list shows them.
- SQL tests run on plain Postgres with `supabase/tests/00_supabase_stub.sql` standing in for
  Supabase: a migration using anything else of Supabase's must add it to the stub. Every
  migration must be idempotent (CI applies them twice).
- Browser storage can be evicted until server sync is live (a build with `SERVER_URL`).
- Uploads go one at a time, oldest first: the server checks that levels chain. Never upload in
  parallel or skip a refused session's successors.
- Adopt the server's levels only when no upload is pending (`syncLevelsBeforeGame`): pending
  sessions chain from the local levels. Never without a server either — its levels are empty.
- The privacy notice (`privacy_screen.dart`) states what is stored and that deletion removes it
  all: a new table of player data must cascade from `auth.users` and be named there.
- Level updates have one implementation: `gameLevelUpdates`, used by the app's orchestrator
  and the server's validation. Never compute levels elsewhere. Questions likewise:
  `gameExerciseGenerator` for the app, the replay and duels.
- The server enforces the gate too (`upload_allowed`, env `BETA_GATE`, on unless `false`): a
  blocked upload is a 403 the app retries, never a refusal — keep it so, or late-redeemed
  testers lose games. Check a deploy with `/health` (`version`, `betaGate`).
- Uploads answering 503 `unavailable` while `/health` is fine: Supabase refused the server's
  call — the reason is in the Render logs (`503 on POST /v1/sessions: …`). `SMOKE_TRACE=1`
  prints each upload's status and error body. (`ServerConfig` also refuses a legacy anon JWT.)
- **Every new table gets explicit grants in its migration** (`grant … to service_role`, and to
  `anon`/`authenticated` if the app reads it): newer Supabase projects (staging) give the API
  roles no default table privileges, older ones (production) do — staging's uploads all failed
  on this (24 Nov). The SQL test stub models the newer kind, so a missing grant fails there.
- The beta gate is a build switch (`BETA_GATE=true`): with it on, the smoke test needs the
  `SMOKE_BETA_CODE` secret. Never put a real code in the repository, private or not.
- The app holds an upload back until the server's `/health` lists both its **rules version**
  and its **session kind** (`kinds`; none listed = games and Training). A new `SessionKind`
  goes in `SessionKind.acceptedByServer` with its validation — never a kind the server would
  refuse as `badRequest`.
- The server flags a Levelling game whose weak spots were not due in the schedule it rebuilds
  from the accepted history (`weakSpotsNotDue`); the app's schedule must leave out the
  sessions the server refused (`loadWeakSpotSchedule`), or honest games get flagged.
- `ValidationFlag.abandoned` marks a forfeited duel run (never in the pool, never reviewed):
  the dashboard's `flagged_runs` leaves it out — a new flag that is not a review matter must be
  left out there too.
- `RejectionReason` and `ValidationFlag` names are stored server-side and sent to the app:
  renaming breaks both. Same for `InputDevice` names (answers, uploads).
- Tests apply every migration twice: a later migration must not change the columns of a view
  an earlier one creates (its `create or replace` fails on the second pass) — make a view
  under a new name and drop the old one.
- Structural features exist twice — `math_core/difficulty/structural_features.dart` and SQL
  `owner_dashboard.structural_features`; the SQL test's cases run against Dart: change both.
- The name rule exists twice — `math_core/account/display_name.dart` and the SQL
  `display_name_problem`; change both (a parity test fails otherwise). Allowed letters must stay
  inside Inter's coverage (`name_charset_font_test.dart`).
- SQL tests set `PGCLIENTENCODING=UTF8`: psql on Windows otherwise reads files in the console's
  code page. Git Bash also mangles non-ASCII command-line arguments to Windows programs — put
  such SQL in a file.
- Sessions store their type sequence (schema v6), shuffled once by the seed: replay with
  `replaySessionQuestions`, never by re-running `shuffledTypeSequence`.
- No Google fonts at runtime (`fontFallbackBaseUrl: 'fonts/'` in `web/flutter_bootstrap.js`):
  a glyph missing from the bundled fonts shows as a box. Check new UI symbols in the network
  panel.
- Web builds use `--no-web-resources-cdn` (CanvasKit from the site), locally too.
- GitHub Pages serves gzip, not brotli: self-hosted CanvasKit loads slower than from Google.
- The deployed release build has no timeout switch; automated tests answer instantly instead.
- A release-build Supabase key must be a repository **secret** (not a variable, not an
  environment secret) named exactly as the workflow reads it.
- Integer arithmetic for perfect squares, never floating-point `sqrt()`.
- *Android, Phase 8*: use `build apk` + `adb install`, not attached `flutter run`;
  `kotlin.incremental=false` works around a Windows cross-drive Kotlin crash; corrupted Gradle
  cache → clear `<user home>\.gradle\caches\<version>\transforms`.