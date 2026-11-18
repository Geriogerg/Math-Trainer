# Math Trainer

Competitive mental-arithmetic game in Flutter, for teens and adults. **Everything in English**:
interface text, code comments, docs, commit messages (owner decision, 18 Nov 2026 — older commits
stay in French).

**`doc/plan.md` is the product plan: vision, principles, direction, roadmap, owner decisions.**
Read it at the start of every phase. Never edit it — it belongs to the owner. This file is the
working file: keep it under 200 lines, update it as the project moves (current phase, rules,
pitfalls), and keep it consistent with the plan (see "Phase report").

Other docs, read when the topic comes up: `doc/architecture.md` (structure, state, exercise model,
dependencies), `doc/decisions.md` (trade-offs and reasons), `doc/design.md` (palette, typography,
notation, UI rules), `doc/online.md` (accounts, server, online), `doc/progress.md` (commit log by
phase). Where another doc disagrees with `doc/plan.md`, the plan wins — report the conflict.

## Current phase

**Phase 0 — Stabilise and build the web pipeline.** Commit list and exit test: `doc/plan.md`,
section 7. Commit 0 (docs alignment) done, waiting for the owner's read. Next: the owner-requested
switch of the interface and comments to English, then commit 1 (CI) — blocked until the repo is
on GitHub. Update this block at every commit.

## Who you work with

Experienced developer (Python, Java, C/C++, algorithms, ML/DL), strong in architecture; new to
Dart, Flutter, mobile and store publishing. Don't explain general concepts. Explain non-obvious
Dart/Flutter idioms the first time only (`late`, `factory`, `sealed class`, enhanced enums,
`switch` exhaustiveness, widget lifecycle, `BuildContext`, `const`/`final`, `Key`,
`async`/`Future`/`Stream`, conditional imports).

## Platform

Windows. **Web-first for now**: mobile development is paused (Android emulator unusable); the web
build is the product and mobile web is the reference device. Android and iOS return in Phase 8;
until then Android is not a concern (owner, 18 Nov 2026) beyond the compile-only CI build and
rule 16. Never propose anything that needs Xcode locally.

## Architecture rules

Non-negotiable without explicit discussion.

1. **Pure-Dart core**: no `package:flutter` in `core/domain/` — the server runs the same code.
2. **Deterministic generation**: explicit seed, no unseeded `Random()`; same (seed, config) → same
   sequence. Config = player levels (solo) or duel config.
3. **Persistence behind abstractions**: no `sqflite`/`shared_preferences`/`drift` outside
   `infrastructure/`.
4. **Repositories always async** (`Future<T>`).
5. **UUIDs**, never `AUTOINCREMENT` on syncable entities.
6. **UTC timestamps**, local only at display; `createdAt` ≠ `syncedAt`.
7. **Strict layers**: never UI + logic + state in one file.
8. **Immutable models**: `final`, `copyWith`.
9. **Every expected answer is an `int`**; division with `~/`.
10. **Generation builds the result** (draw `r`, show `r²`); never rejection sampling.
11. **No `default`** in a `switch` on `Exercise`, `ExerciseType`, `OperationType`.
12. **`OperationType` stays inside `ArithmeticExercise`**; the selection axis is `ExerciseType`.
13. **Invariants by `throw`, never `assert`**, each with a test of the invalid case.
14. **No signal by colour alone**: colour + motion + haptic or sound.
15. **Web-specific code only in `infrastructure/`** (`dart:html`, `package:web`,
    `dart:js_interop`), chosen in `composition_root.dart`, conditional imports if needed.
16. **No dependency without Android and iOS support**, unless its mobile replacement is named in
    `doc/decisions.md`.
17. **The server never trusts the client**: levels for ranking, ranks, ratings and duel results
    are server-side;
    the Supabase service-role key never appears in the app or the repo.

## Data and backend

- Local: `shared_preferences` for scalars, SQLite for history (web: WebAssembly + IndexedDB).
  Solo play works offline — except the very first launch, which needs the network to sign in,
  until anonymous-first (Phase 1).
- Store **every answer** with its own timestamp, operands, given answer, time, correctness and
  level at play time. Never aggregates only.
- Levels are a cache, recomputable from history; the update function lives in the core and
  replays a list of answers.
- Supabase = Auth + Postgres. A separate Dart service (`shelf`) validates sessions and computes
  levels, ranks and ratings — Supabase Edge Functions can't run Dart. From Phase 2: monorepo
  `app/`, `packages/math_core/`, `server/`.

## How a phase runs

The owner's prompt is usually "Start Phase N" or "Continue Phase N".

1. Read `doc/plan.md` (the phase), this file, `doc/progress.md`, `doc/decisions.md`, and the
   design or online doc if relevant. Check entry conditions.
2. Propose the plan of the **first commit only**: files, one-line reason each, tests. Wait.
3. *(A)* commits chain without asking: plan briefly, implement, test, document, commit.
4. *(C)* commits: propose, wait, implement, deploy to the preview URL, **stop until the owner has
   played it**.
5. After each commit: update "Current phase" above and append to `doc/progress.md`.
6. End of phase: exit test, then the phase report.

**Stop and ask** when: a schema migration not listed in the plan; a new dependency (justify it,
name its mobile support); a domain contract change not listed; tests red after two attempts; docs
and code disagree in a way that needs a decision; an owner decision (`doc/plan.md`, section 8).

**Phase report**, in this order: delivered vs plan; deviations and why; choices made without
explicit approval; what could not be verified; debt found; numbers (tests, load time, sessions);
**plan alignment** — every point where this file, the code or the other docs drift from
`doc/plan.md` (checklist in its section 11), with a proposal for each. Honest over flattering.

**Collaboration**: propose before implementing (Plan mode); trace ripples down to persistence
before implementing; explain consequences on later phases; don't rewrite working code; list files
touched; simplicity first, no abstraction for a single use case; report gaps with
`doc/architecture.md`.

## Conventions

- Business logic always comes with unit tests.
- Every `Exercise` variant implements `==` and `hashCode` (guarded by a test over
  `ExerciseType.values`).
- Determinism tests are keyed on (seed, config), never the seed alone.
- Comment only the non-obvious.
- No hard-coded UI values: `Theme.of(context)` and theme extensions.
- `SafeArea` on every screen.
- The on-screen keypad is the primary input; physical keyboard on desktop; the native keyboard
  never appears during a game.
- Lints: `flutter_lints`, checked by `dart analyze`.

**Before every commit**: `dart test test/domain`, `flutter test`, `flutter analyze` clean; CI green
after push. Checkpoint commits are played by the owner on a phone browser (a docs-only checkpoint
is read instead). *Until Phase 0 commit 3, `flutter analyze` shows the Flutter 3.50
`material_ui` deprecation infos and nothing else; until the repo is on GitHub (owner) and commit
1 lands, there is no CI to check.*

## Commands

```bash
dart test test/domain      # core — the scope is mandatory (see pitfalls)
flutter test               # all tests
flutter analyze
flutter run -d edge --web-port=8080 --dart-define-from-file=dart_defines.json
flutter build web --dart-define-from-file=dart_defines.json
```

`dart_defines.json` (not versioned; template `dart_defines.example.json`) holds the Supabase URL
and public key. Without it the app shows "Missing configuration".

## Pitfalls (append when you find a new one)

- **Never draw at random directly from a `Set`**: iteration follows insertion order, so the same
  seed gives different sequences. Use a list sorted by enum `index`.
- `CompositeExerciseGenerator` makes a useless `nextInt(1)` per arithmetic exercise. Removing it
  changes every sequence for a seed — never together with anything else.
- `ExerciseType` value names are the stored discriminant (`exercise_codec`); renaming breaks
  history.
- `dart test` without the `test/domain` scope fails (it picks up widget tests).
- `web/sqlite3.wasm` and `web/sqflite_sw.js` come from `dart run sqflite_common_ffi_web:setup`
  (versioned); rerun with `--force` after upgrading `sqflite_common_ffi_web` or `sqlite3`. Missing →
  "Web storage unavailable".
- **Always web port 8080**: Supabase session, `playerId`, theme and type selection live in
  `localStorage`, scoped to the origin including the port.
- The Supabase `profiles` table comes from `supabase/profiles.sql`, run by hand in the SQL editor.
- Browser storage can be evicted (Safari especially): local web history is unsafe until server
  sync.
- Floating-point `sqrt()` is forbidden: integer arithmetic only.
- *Android, for Phase 8*: prefer `flutter build apk --debug` + `adb install -r` + `adb shell am
  start` over an attached `flutter run` (it disconnects). `kotlin.incremental=false` works around
  a Windows Kotlin crash across drives. Environment split C:/D: (SDK, AVD, `GRADLE_USER_HOME` on
  `D:\Users\GREgo`); a corrupted Gradle cache is fixed by clearing
  `D:\Users\GREgo\.gradle\caches\<version>\transforms`.