# Math Trainer

Competitive mental-arithmetic game in Flutter, for teens and adults. UI, code, docs and commits
in English.

**`doc/plan.md` (version 2.3) is the product plan.** Read it at the start of every phase; never
edit it. This file is the working file: keep it short, update it as the project moves, keep it
consistent with the plan. Other docs when relevant: `doc/architecture.md`, `doc/decisions.md`,
`doc/design.md`, `doc/online.md`, `doc/progress.md`. The plan wins any conflict — report it.

## Current phase

**Phase 3a — Build the beta** (`doc/plan.md`, section 7), run in **one pass**.
Next commit: **0**. Update this block at every commit.

| # | Commit | Note |
|---|---|---|
| 0 | Close Phase 2: plan-alignment fixes, leaderboard chips on one line on a phone | — |
| 1 | Preview moved to a free brotli host | propose with measurements; **move only after owner's yes, and before any tester** |
| 2 | Server levels fetched before each game; refused sessions explained | — |
| 3 | Beta gate: invitation code before anonymous sign-in, codes table with use limit | — |
| 4 | Short privacy notice in the app | — |
| 5 | In-app feedback, stored with the app version | — |
| 6 | Owner dashboard: SQL views + report script, name-review queue | — |
| 7 | First game on a never-played type = short placement | played at phase end |
| 8 | Data check for Phase 3b | — |

Waiting on the owner (finish everything else meanwhile): host confirmation for commit 1.
Phase 3b (calibration) starts only when the dashboard shows ~300 sessions from 10+ testers.

Preview: `https://geriogerg.github.io/Math-Trainer/`, deployed on every push to `main`.

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
   sequence. Placement: same (seed, answers so far) → same next question.
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
- **Levels**: integer hundredths (3742 = 37.42), shown as a whole number with a progress bar
  inside the level; generation reads the whole part. Recomputable from history by a core function.
- **Sessions are self-contained**: everything deciding question order is stored with them.
- **Session kinds**: game or placement. Placement answers become starting levels through a pure
  core function.
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
# repo root
dart format app/lib app/test packages server tool   # what CI checks
node tool/smoke/preview_smoke.mjs <url> [chrome]   # smoke test; SMOKE_NETWORK=slow4g to time it
bash tool/sql/test_sql.sh <postgres admin url>     # migrations (twice) + SQL tests, scratch DB
```

`app/dart_defines.json` (not versioned) holds the Supabase URL and public key; in CI they come from
the `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` secrets.

## Pitfalls (append new ones)

- Never draw at random from a `Set` (insertion order); use a list sorted by enum `index`.
- The useless `nextInt(1)` in `CompositeExerciseGenerator` stays: removing it changes every
  sequence.
- `ExerciseType` and `SessionKind` names are stored discriminants; renaming breaks history.
- Changing `placementRulesV1` changes stored placements' replay: add a `placementV2` instead.
- Integer levels round small steps to zero — never round before storing hundredths.
- `Level` is an `int` at runtime: string interpolation prints hundredths, and `level ?? 1`
  compiles (widens to `Object`). Display through `.whole`; fall back to `Level.floor`.
- `packages/math_core/test/determinism/determinism_references.dart` is generated (in
  `packages/math_core`: `dart run tool/determinism_references.dart`) only by a change meant to alter sequences or
  level updates — never to make a JavaScript failure pass.
- `Random.secure()` throws under `-p node` (dart2js + Node 24); browsers are fine.
- `web/sqlite3.wasm` and `web/sqflite_sw.js` come from `dart run sqflite_common_ffi_web:setup`;
  rerun with `--force` after upgrades. On GitHub Pages every path respects `/Math-Trainer/`.
- Always web port 8080 locally: session and settings live in `localStorage`, scoped by port.
- Signing out an anonymous user loses the account — never offer it.
- Anonymous sign-ins are rate-limited (30/hour/IP); automated tests delete the accounts they
  create (the smoke test through "Delete my data", which needs `delete_my_account()`).
- SQL goes in versioned migrations applied by CI (from commit 2); never run SQL by hand, never
  print the access token or database password.
- SQL tests run on plain Postgres with `supabase/tests/00_supabase_stub.sql` standing in for
  Supabase: a migration using anything else of Supabase's must add it to the stub. Every
  migration must be idempotent (CI applies them twice).
- Browser storage can be evicted until server sync is live (a build with `SERVER_URL`).
- Uploads go one at a time, oldest first: the server checks that levels chain. Never upload in
  parallel or skip a refused session's successors.
- Level updates have one implementation: `gameLevelUpdates` / `placementLevelUpdates`, used by
  the app's orchestrators and the server's validation. Never compute levels elsewhere.
- `RejectionReason` and `ValidationFlag` names are stored server-side and sent to the app:
  renaming breaks both.
- The name rule exists twice — `math_core/account/display_name.dart` and the SQL
  `display_name_problem`; change both (a parity test fails otherwise). Allowed letters must stay
  inside Inter's coverage (`name_charset_font_test.dart`).
- SQL tests set `PGCLIENTENCODING=UTF8`: psql on Windows otherwise reads files in the console's
  code page. Git Bash also mangles non-ASCII command-line arguments to Windows programs — put
  such SQL in a file.
- Rotation by sampling debt makes question order depend on past games: sessions store their
  type sequence (schema v6). Replay with `replaySessionQuestions`, never by re-running the
  strategy.
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
  cache → clear `D:\Users\GREgo\.gradle\caches\<version>\transforms`.