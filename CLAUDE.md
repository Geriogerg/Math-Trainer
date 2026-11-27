# Math Trainer

Competitive mental-arithmetic game in Flutter, for teens and adults. UI, code, docs and commits
in English.

**`doc/plan.md` (version 4.0) is the product plan**, and **`doc/levels.md` (v1.6) specifies the
level system** (v1.6 is rules v9, built in Phase 6b). Both
are the owner's: read them at the start of every phase; never edit them.
This file is the working file: keep it short, update it as the project moves, keep it
consistent with the plan. Other docs when relevant: `doc/architecture.md`, `doc/decisions.md`,
`doc/design.md`, `doc/online.md`, `doc/progress.md`. The plan wins any conflict — report it.

## Current phase

**Phase 6b — Player experience** (`doc/plan.md` v4.0, section 7), run in **one pass**, nine
commits. Goal: what a stranger meets in the first ten minutes. **Rules v9** from
`doc/levels.md` v1.6 (wider pools, no repeats, quitting counts, Method quality). Every 6b review
finding is tracked by ID in `doc/progress.md` ("Review findings"); mark each as it closes.

| # | Commit | Findings | Note |
|---|---|---|---|
| 0 | *(A)* **Close-out of 6a**: Greek and Cyrillic allowed again in names; `duel_endpoint.dart` split by responsibility (matchmaking, runs, abandonment, rating, JSON); the abandonment sweep catches up at server start | — | |
| 1 | *(A)* **Rules v9 generation**: the spec test reads the live `doc/levels.md`, the frozen v1.5 copy deleted; ≥ 12 distinct questions per tier; no repeat in a game or duel while the pool allows, never two in a row; uniform draws; no trivial factors above T0; new Powers, Roots, Integrals tables; Swap, round-number division, round cube roots, from-zero integrals sized by tier; both lengths at T8; the lower-bound size test; level targets rechecked by simulation | M10, m11, m20, m21 (and m5) | pushed with 2 |
| 2 | *(A)* **Quitting counts**: a v9 Levelling game with one answer counts, unanswered questions as timeouts, however it ends (✕, three timeouts, a closed tab); server replay; a "quits after a mistake" player in the simulation | M4 | |
| 3 | *(A)* **Method quality**: `doc/levels.md` section 9 v1.6; exhaustive switches on `PatternFamily`; pinned word-for-word examples | M11, n6 | |
| 4 | *(C)* **Explained, not wordy**: one line under each Home and setup control; result "12 → 12" with the change in hundredths and its reason; a first-run card; a rules sheet before a rated duel; rules on first open of Get the count and Chain operations; Sign out confirmed; pending uploads visible | M15, M16, m17 | |
| 5 | *(C)* **Network and devices**: server levels right after sign-in; "history from other devices is not shown here"; a sign-in hint for a level-0 guest; 15–20 s timeout on every Supabase call; Cancel and "Waking the server…" while finding an opponent; a notice when an unfinished duel was sent; loader watchdog with Reload; catch-all at start; failures shown on friend actions | M14, M15, M18 | |
| 6 | *(C)* **Accessibility**: semantics on; a live region for question, feedback and timer; spoken labels per exercise type; outlines at 3:1; body text 15–16 px; viewport meta; guideline tests on Online, duel, Friends and Ranks | M17 | |
| 7 | *(A)* **Strings and consistency**: every string in one place (English only); levels shown as whole parts everywhere; terms unified (game, Ranks, seconds) | m3, m18, m17 (terms) | m5 moved to 1 |
| 8 | *(A)* **Docs**: `doc/architecture.md` regenerated; stale parts of `doc/online.md` rewritten; README numbers → a pointer to the CI pins; superseded and confirmed entries marked in `doc/decisions.md`; `CLAUDE.md` aligned | M19, m19 | |

**Exit:** no repeated question in a 10-question game at any tier; quitting after a mistake costs
levels; the Method examples of the review read correctly; a first-time player on a phone
understands Home, a game result and a duel without help; a screen reader can play a game.

**Rules v9 is one version for commits 1 and 2** (generation and the quitting rule): both are
committed separately but pushed together, so no v9 game is ever played under half of it. m5
(weak spots ⌊n/5⌋ per operation) changes what a game draws, so it is part of v9 (commit 1),
not commit 7.

**The owner's decisions that bind this phase** (plan v4.0, "Phase 6a outcome"; plan v3.9,
"Project review"): Greek and Cyrillic allowed again in names ("Latin only" meant no new
alphabets at launch); sessions not slimmed and no retention rule (Supabase's paid plan when the
50 % alert fires); the sweep stays on a server timer and catches up at start; one report hides a
name until 6c; quitting counts once a game has one answer (M4); "minimal text" relaxed for
strangers (M16); pools widened and de-duplicated by spec v1.6 (M10); division always on one
line; weak spots at most ⌊n/5⌋ per operation; strings in one place, English at launch, French
right after. m12 (large files) and m13 (app contracts in the core) are fixed when the files are
next touched — the phase report says what moved.

Done: 0, 1 (27 Nov; `doc/progress.md`, "Phase 6b"; 1 committed, pushed with 2). Next: commit 2.

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
  run's owner learns it later). A duel reached through a **chosen opponent** (a challenge, a
  rematch — `duels.chosen`) is rated **once per pair and mode over a rolling 24 hours** (6a).
- **Matchmaking**: the run of the player with the closest rating — never one's own, never a
  run already raced; a run served at most **5 times**, only a player's **10 latest runs** per
  mode in the pool. Empty pool → **Practice** opponent (simulated, no rating change).
  **Rematch** (a finished duel of the same mode only) races another run of the same opponent,
  else sends them a challenge.
- **Friends**: a friend code (`MATH-7K2P`) and an invite link; requests, accept, remove; list
  with head-to-head, history per friend; **challenges** — only to a friend or an opponent of
  the last 30 days (6a) — the challenger plays first, the friend plays the same questions from
  "Waiting for you": **6 days to open it, then 24 hours to play it**. In-app badges only.
- **Fair play**: every run replayed and validated by the server; implausible timing keeps a
  run out of the pool until reviewed; friend requests limited (~20 a day). **An abandoned duel
  is a loss** (v3.8): a duel started but not submitted within 24 hours, recorded from the
  progress the app sends during play (`/v1/duels/progress`), by the next duel request
  (`sweepAbandoned`).
- **Duel results hold** (6a, plan v3.9): **for the second player a run that does not replay
  is a loss** (a `forfeited` run applied in its place, the reason kept in
  `duel_run_rejections`; `void` only for a challenger's own first run); a run must **continue
  the progress** the server holds (`DuelRun.continues`, else 409 `progressMismatch` and the
  duel stays open); a run claiming more answering time than has passed since the offer is a
  forfeit (`notElapsed`, `DuelRun.claimedMs`, the database's clock, 5 s margin); **a flagged
  run earns nothing** — its duel is unrated unless the flagged player lost.

Phase 7 and its close-out are done and their decisions settled (plan v3.8–v3.9; the
abandoned-duel choices confirmed on 26 Nov). Still for the owner: Share link on a phone.
Phase 3b is a data check, not a blocker (confirmed in v3.8): a report at ~300 sessions from
10+ testers since the rules v5 release (`owner_dashboard.calibration_window`).

**Weak spots** (Phase 4, rules v7–v9; detail in `doc/decisions.md`, "Phase 4"): facts and
skills, five boxes counted in games (due after 1, 2, 4, 8, 16), rebuilt from stored answers
(`scheduleFromHistory`); Levelling games re-ask at most ⌊N/5⌋ due items, **only from the
operation's current tier**, and per operation ⌈n/5⌉ (v7–v8) or **⌊n/5⌋ (v9)** —
`belongsTo` and `weakSpotOperationCap` take the rules; Weak spots and Drill games are
practice kinds (uploaded, never move levels, never ranked).

**The level system** (`doc/levels.md`; constants: `LevelRules.of`)
- **Levels 0–100**, integer hundredths, shown whole; everyone started at 0 at the transition
  (rules v2); no placement test. Never decay; frozen at the start of a game.
- **Ten tiers** per operation (T0 = 0–9 … T9 = 90–100): the tier decides the content and the
  **fluent time**; from rules v5 every question comes from the player's tier (v2–v4: 30 % from
  the tier below). Generation stays backwards (rule 10). From rules v4, **pattern questions**
  (spec 5b, 49 `PatternFamily`): 2 in 5 where a family is available; from v5 **sized by tier**
  (`patternQuestion(family, tier, r)`: spec 5b's size table, and a hard limit of the standard
  questions of the tier or the next). Every mistake of a game gets a **Method** (spec 9,
  `methodFor`). **From rules v9** (spec v1.6) every tier and every family at every tier is a
  `QuestionSpace` of distinct questions, drawn uniformly by the game's own memory
  (`DrawsV9`, `OperationDraws`): no question twice in a game while the tier has unused ones,
  never twice in a row; a family with fewer than 4 questions at a tier is skipped there
  (`familiesAtV9`).
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
app code (deploy runs only after the tests). Since 6a the code is `main.<hash>.dart.js`: read its
name from the live `flutter_bootstrap.js` (`"mainJsPath"`), then fetch it.

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
  facts entering the schedule at box 2 (Phase 4 close-out; scheduled per game's own
  rules, `slowFactsEnterSchedule`); v9 = `doc/levels.md` v1.6 (Phase 6b, current): question
  spaces drawn without repeats, the new Powers/Roots/Integrals tables, resized and growing
  families, weak spots ⌊n/5⌋ per operation, and (commit 2) quitting counts; v1 (all before
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
green; a commit adding tests raises its suite's pin (`.github/workflows/ci.yml`). Until Phase 8, the weekly "Android build" workflow (`.github/workflows/android.yml`,
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
  `tier_references_v5.dart` (v5), `tier_references_v6.dart` (v6) and `tier_references_v9.dart`
  (v9) are generated (in `packages/math_core`: `dart run tool/tier_references.dart`, then
  `dart format test/tiers` — the tool writes unformatted) only by a change meant to alter a
  version's questions — never to make a JavaScript failure pass. The tool rewrites them all: an
  older file that changes is a bug. v9 is `current` and played: every version's generation is
  frozen — the next change to generation is **v10**. v2–v8 draw through `ContentDraws` (each
  question on its own), v9 through `DrawsV9`; `standard_v9.dart` and `pattern_spaces_v9.dart`
  are v9's tables.
- **A v9 generator holds the game's memory** (what it asked): one `gameExerciseGenerator` per
  game, never shared or reused — a replay builds its own. `QuestionSpace`s are built once per
  tier or family and kept (`standardSpaceV9`, `familySpaceV9`). `tool/question_pools.dart`
  prints the pools (distinct questions per tier, repeats, skipped families) for v8 and v9.
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
- The server checks a duel run's turn **before** replaying it: a refused replay costs its
  sender the duel (a loss for the second player, a void challenge for a challenger), so a run
  sent out of turn must never reach it.
- A duel's progress is what its final run must continue: the app stores each step **before**
  telling the server (`DuelRunQueue.saveProgress`) — the device must never know less than the
  server. Test helpers building successive progress must keep earlier answers' times.
- `ValidationFlag.abandoned` and `forfeited` are losses the server wrote itself, not review
  matters: `_reviewFlags` (server) and `owner_dashboard.flagged_runs` leave both out.
- **The abuse floor** (6a commit 2, `server/lib/src/rate_limit.dart`): token buckets in
  memory per address (120, +2/s; before any work, `/health` and preflights exempt) and per
  player (40, +0.5/s); daily caps of 300 accepted sessions and 200 new duels per player
  (`acceptedToday`, `duelsToday`, counted by SQL the server already calls). **Every limit
  answers 429 `{error}`, never `{status: refused}`**: the app keeps what it was sending and
  retries — a limit that refused would lose honest games. Bodies are read with
  `readBodyWithin` (never `readAsString`); a refused payload is stored as
  `refusal_digest` (hash, size, first 1,000 characters), 50 a day per player.
- The address limit's key is `cf-connecting-ip`: Render sits behind Cloudflare, which sets it
  and refuses a request that sets it itself (checked on staging, 26 Nov: forged
  `x-forwarded-for` changed nothing, forged `cf-connecting-ip` got Cloudflare's 403). Keep it
  first in `clientAddress`.
- **Moderation** (6a commit 3): `player_moderation` (`hidden` | `banned`), written only by
  `owner_dashboard.moderate` / `unmoderate` (`dashboard.sh hide|ban|unhide`). Every board,
  `duel_take_run` (both ways), `duel_create_challenge` and `friend_request` read
  `player_visible`; a new place that lists or matches players must too. `banned` = hidden plus
  403 `account_suspended` on uploads and new duels — **a 403, never a refusal**: lifting the
  ban must lose nothing. The player sees "Account under review" (`my_account_under_review`).
- **A session's `createdAt` is its END**: the app stores a game when its last answer is
  given or it is left. Its end is stored (`server_players.last_session_ends_at`); one that
  started (`createdAt` − its answers' times) before the previous one ended is flagged
  `overlapsPrevious` (accepted). 6a read `createdAt` as the start and refused every game of
  more than 5 minutes of answers sent at once (`futureTimestamp`) — fixed in 6b commit 0; a
  test now holds a 20-minute game.
- **Boards are cached a minute** (6a commit 5): `leaderboard_top`, `leaderboard_around_me`,
  `duel_board_top`, `duel_board_around_me` read `board_rows`, refreshed by `board_refresh` when
  older than `board_cache_age()` — so they are **VOLATILE** (called with POST, as the app does).
  The SQL tests' database sets `mt.board_cache_seconds = 0` (`00_supabase_stub.sql`); a test of
  the cache sets it back. The main board counts `server_players.completed_games`, kept by
  `apply_validated_session`: a test inserting sessions by hand must set it too.
- **The duel pool is a column** (`duel_runs.in_pool`), kept by triggers on insert and on
  `serves`, `flags`, `review`: never set it by hand; a new rule for the pool goes in
  `duel_run_poolable` (or the trigger). Matchmaking compares configs by `config_hash`.
- **Web builds are content-hashed** (`tool/web/hash_assets.mjs`, CI's web build, after
  `boot_config.mjs`): `main.<hash>.dart.js` and `canvaskit/<hash>/`, served `immutable` for a
  year by the Pages Function; fonts a day; `sqlite3.wasm` revalidated (it must match the
  unhashed `sqflite_sw.js`). `precompress.mjs` routes the hashed name it finds. A new large file
  loaded by name needs a decision: hashed (and its reference rewritten) or revalidated.
- **Answer times never leave [0, 30 s]** (6a commit 6): `SessionController` times answers on a
  monotonic clock (a `Stopwatch`; tests that inject `clock` time by it) and clamps them.
- **Supabase's refusal is final**: `HttpSupabaseGateway.rpc` throws `GatewayRejected` on a
  PostgREST 4xx other than 401/403/404/408/429, and the endpoints answer 400 `badRequest`; a
  5xx stays `GatewayUnavailable` (503, retried). The app sets a session aside after 20
  server-answered failures over 3 days (`UploadAttemptLog`, reason `setAside`).
- **Security headers** come from `tool/web/security_headers.mjs` (`_headers`, written by CI's
  web build from `dart_defines.json`): a new place the app talks to must be added to its
  `connect-src`, or the browser blocks it. Inline scripts stay allowed (index.html's boot).
- **Friend codes have 8 characters** (`MATH-7K2P-QX4M`, `normalizeFriendCode` and SQL
  `normalize_friend_code`: change both); `new_friend_code()` replaces one. An invite link
  asks before it sends a request (`OnlineController.takePendingInvite`).
- Abandoned duels are swept by the production server outside requests (`sweepSoon`: **at
  start**, on a timer every 5 minutes, and after a duel request at most once a minute), each
  sweep catching up batch after batch until none is left (`DuelAbandonment.catchUp`; plan
  v4.0: the free server sleeps); `DuelEndpoint` keeps `sweepInRequests: true` (one batch per
  request) by default for the tests. `duel_endpoint.dart` is the HTTP surface only; the work
  is in `server/lib/src/duels/` (matchmaking, runs, abandonment, ratings, JSON).
- Every function in `public` and `owner_dashboard` sets `search_path` (`99l_details_test.sql`
  checks the whole catalogue): a new one without it fails CI.
- **The integration job** (6a commit 7) runs `bin/server.dart` against every migration through
  `server/tool/postgrest_shim.dart` (a stand-in for `/auth/v1/user` and `/rest/v1/rpc/*`, each
  call as `service_role`): a new SQL function the server calls is exercised there with its real
  grants. Locally: a scratch database with the stub and migrations, then
  `dart run tool/postgrest_shim.dart 54321 <db url>`, the server with
  `SUPABASE_URL=http://localhost:54321`, and `INTEGRATION_DB_URL=… INTEGRATION_SERVER_URL=…
  dart test integration` (in `server/`).
- **The catalogue test** (`99m_catalogue_test.sql`) lists every `security definer` function
  players may call and the tables they may touch (only `profiles`): a new one fails CI until it
  is added there on purpose. `test_sql.sh` also pins the number of `assert` statements.
- CI cancels a superseded run only off `main` (a run on `main` may be deploying), the
  workflow's token is `contents: read`, and every third-party action is pinned by commit (the
  tag in a comment): bump an action by its commit, never back to a tag.
- `PREVIEW_BUILD` (the typeface specimen) is on for staging only (`preview-build` input).
- A local `flutter build web` from Git Bash needs `MSYS_NO_PATHCONV=1` for `--base-href /`
  (Git Bash rewrites `/` to its install path).
- `HttpSupabaseGateway.userForToken` refuses what cannot be a Supabase token
  (`looksLikeAccessToken`) without calling Supabase; fakes take any string, so endpoint tests
  keep their short tokens.
- SQL functions the server calls keep their signature across a deploy (migrations run before
  the server restarts: the old server must still be able to call them) — add keys to a JSON
  result, or a new function, never a new required parameter.
- **Weak-spot item keys are stored** (`PersistedSession.weakSpots`, schema v13, upload
  `weakSpots`): `fact:<type>:<numbers>`, `skill:<family>` — never change the format, an
  `ExerciseType` or a `PatternFamily` name. Weak spots in a Levelling game come only from the
  operation's current tier (`belongsTo(item, tier, rules)`, checked by the replay); `factsAt`
  must match what each v4–v8 tier's standard questions draw (`fact_tiers_test.dart`), v9's tier
  is its space (`factAtV9`). A fact's home tier (`homeTier`, its fluent time, practice games)
  stays v8's: changing it would change how stored practice games replay. The schedule is
  never stored: `scheduleFromHistory` rebuilds it.
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
- **Every CI test suite has a pinned minimum** (plan v3.8): `tool/ci/test_count.sh <suite>
  <min> -- <command>` (core VM, core JavaScript, tooling, server, app; pins in
  `.github/workflows/ci.yml`) and `min_sql_tests` in `tool/sql/test_sql.sh`, which also fails
  on a `*_test.sql` its `[1-9]*` pattern would skip (Phase 7: the duel tests, named `a1_…`,
  went unrun for six commits). Raise a pin when a commit adds tests; never lower one to make
  CI pass — find what stopped running.
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
- `RejectionReason` and `ValidationFlag` names are stored server-side and sent to the app:
  renaming breaks both. Same for `InputDevice` names (answers, uploads).
- Tests apply every migration twice: a later migration must not change the columns of a view
  an earlier one creates (its `create or replace` fails on the second pass) — make a view
  under a new name and drop the old one.
- Structural features exist twice — `math_core/difficulty/structural_features.dart` and SQL
  `owner_dashboard.structural_features`; the SQL test's cases run against Dart: change both.
- The name rule exists twice — `math_core/account/display_name.dart` and the SQL
  `display_name_problem` (latest definition: `…_names_privacy.sql`; the parity test reads the
  newest migration defining it); change both. Latin, Greek and Cyrillic letters (6a allowed
  Latin only; reversed by the owner, plan v4.0 — 6b commit 0); the constraint is `NOT VALID`. Allowed letters must stay
  inside Inter's coverage (`name_charset_font_test.dart`).
- **Names are unique by `fold_display_name`** (lowercase, accents and look-alikes of any script
  folded, i/l/1 and o/0 together, separators dropped, rn → m, vv → w) — a unique index on it.
  It folds upper case explicitly: `lower()` leaves non-ASCII letters alone under a C collation.
  Changing the fold means rebuilding `profiles_display_name_folded` (and resolving the
  duplicates first, `resolve_duplicate_display_names`). The app maps 23505 to
  `DisplayNameTaken`.
- **A report hides the player's name, not the spelling**, until the owner's next review
  (`name_reviewed_at`); only saved accounts report, 10 a day. `profiles` is readable by its
  owner only: anything showing another player's name goes through `public_display_name`.
- **Duels outlive their players** (6a, "Deleted player"): `duels.first_player` and
  `second_player` are `on delete set null`; runs, ratings and the rest still cascade. A SQL
  test that starts with `delete from auth.users` and uses duels must also
  `delete from public.duels`. A list of duels shows the other side through
  `duel_opponent_name`.
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