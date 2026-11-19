# Decisions — Math Trainer

Past trade-offs and their reasons. **Not loaded automatically.** Purpose: avoid re-arguing a
settled question, and record under which condition to reopen it. Product decisions owned by the
plan are summarised here with their reason; `doc/plan.md` remains the authority.

## Product direction (plan of 18 Nov 2026)

### Web-first, mobile-ready

The Android emulator is unusable and iOS needs a Mac: the web build is the product until mobile
development is possible again. A hosted URL opened in a phone browser gets real players with no
store review, and an invite-only web beta produces the sessions calibration waits for. Guardrails:
web-specific code only in `infrastructure/`, no dependency without a mobile path, touch-first
input. Android is not checked until Phase 8 (owner, 18 Nov 2026).
**Reopen when** the owner says mobile development is possible again (Phase 8).

### Anonymous-first replaces mandatory sign-in

Mandatory sign-in (step 6, slice 2) makes most first-time players leave before one question. A
player is created silently on first launch; email (later Google) is linked when they want the
leaderboard or a second device. Existing email accounts keep their data. The detailed design is
proposed to the owner before Phase 1 commit 1.
**Reopen when** abuse of anonymous accounts costs more than the protections planned (CAPTCHA,
cleanup).

### Glicko-2 rather than Elo

Glicko-2 carries a rating deviation: a new or returning player's rating moves fast and settles,
which Elo only approximates with ad-hoc K-factors, and the deviation gives a natural "provisional"
flag. Server-side only, provisional for the first ~10 duels.
**Reopen when** duel volume shows the provisional period is too long or too short.

### Ghost duels before live duels

Live duels need enough players online at once for queues under ~20 s, which a young app does not
have. A ghost duel (a real recorded run replayed at its pace) needs nobody else online and reuses
the same deterministic generation. Live duels open on an owner decision, on measured concurrency.
**Reopen when** concurrency is measured high enough.

### Monorepo `app/`, `packages/math_core/`, `server/`

The server must run the same core as the app (rule 1). A pure-Dart package imported by path from
both sides keeps one implementation and one test suite, with no publishing step. Done in Phase 2
commit 1, with no behaviour change.
**Reopen when** the server needs a release cycle independent of the app.

### No ads, payments or third-party analytics before online play

They would distort an unproven product and add consent obligations; usage numbers come from the
server's own tables. Never a paywall on an exercise type — the overall ranking would become a
ranking of subscribers.
**Reopen** after Phase 7, on retention data (owner decision).

### Preview on GitHub Pages

Phase 0 commit 2. Needs no account or token beyond GitHub: the deployment runs in the same
workflow as CI, after tests and build are green, and the repo being public keeps it on the free
plan. Limits accepted: no custom HTTP headers (none needed — SQLite runs in a shared worker, no
`SharedArrayBuffer`), a sub-path (`/Math-Trainer/`) the build must know (`--base-href`), a
10-minute cache.
**Reopen when** the app needs custom headers, the repo goes private, or the public launch needs
a production host on its own domain (Phase 6).

### English everywhere

Owner decision of 18 Nov 2026: interface text, code comments, docs and commit messages are in
English. One language for the code, the docs and the product; it also removes translation as a
prerequisite to a wider audience. Earlier commit messages stay in French.
**Reopen when** a localisation layer (French and others) is planned.

Confirmed on 19 Nov 2026 after plan v2 (which says "French-speaking audience first" and quotes
French labels such as "Passer", "Sauvegarder ta progression", "Supprimer mes données"): **new
screens stay in English** (owner). The plan's French labels are read as their English
equivalents ("Skip", "Save your progress", "Delete my data").

### Phases run in one pass

Owner, 19 Nov 2026 (plan v2.1): a phase runs without stopping; checkpoints are played at the end
of the phase. Stops only where necessary — the hard stops of `CLAUDE.md`, or a step that cannot
proceed without the owner (then parked, the rest continues).
**Reopen when** a phase shows that end-of-phase review lets a wrong direction run too long.

## `correctAnswer` typed `int`, not `num` (step 3)

Originally `num`, with `/` for division — so a `double`. Rule 9 was then a documentary promise the
type system contradicted. It worked by luck: in Dart `4 == 4.0` is `true`. The day a result is not
exactly representable in binary, the comparison fails silently and the player sees a right answer
counted wrong. Switched to `int` and `~/` before three new variants inherited the fragile signature.

## `ExerciseType` above `OperationType` (step 3)

Rejected: extending `OperationType` with `power`, `squareRoot`, `percentage`. `OperationType` is
not a selection axis but a field internal to `ArithmeticExercise`, consumed by two exhaustive
`switch` producing a symbol and a binary computation. Extending it would have made those `switch`
non-exhaustive and forced absurd cases (a binary operator symbol for a root).

## The level estimates skill, it is not a progress bar

Rejected: a level that only rises with play time. It would rank diligence rather than skill and
pile up at the ceiling within months, killing the overall leaderboard.

Chosen: one level per operation reflecting the difficulty at which the player answers right and
fast. It rises, plateaus, and **falls on insufficient performance**.

Also rejected: lowering the level only through inactivity. Inconsistent with a skill estimate — a
player failing systematically would stay stuck at their best day — and punishing absence is an
aggressive retention mechanic that breeds guilt and uninstalls.

Instead: after a long absence, `boost_retour` makes the level move faster **in both directions**
for a few sessions. The player loses nothing, the system re-adjusts.

Consequences: the level is the comparable unit of the leaderboard (raw scores are not, since
players get different questions); and accuracy converges to `p_cible` for everyone, so **it
measures nothing and must never be shown as a reward**.

## Leveling parameters — starting values

**Not calibrated.** They come from a simulator built on a logistic performance curve, not from real
data. To be recalibrated by replaying history (`tool/recalibrate.dart`, Phase 3) — the intended use
of per-answer storage.

Per question: `p = 0` if wrong, else `p = f + (1 − f) · speed`, where `speed` is 1 below
`t_rapide`, 0 above `t_lent`, linear in between. At the end of a session:
`Δ = mean(p) − p_cible`; if `|Δ| < δ` the level does not move; otherwise the dead band is removed,
the result is multiplied by `K_haut` or `K_bas`, then by the confidence multiplier and by
`√(n / n_min)`, capped at `Δ_max`, and applied.

| Parameter | Value | Note |
|---|---|---|
| `p_cible` | 0.70 | target equilibrium performance |
| `f` | 0.30 | credit for a slow right answer; **temperament parameter** — towards 0.60 the game gets twitchier |
| `K_haut` | 3.0 | rising speed |
| `K_bas` | 1.5 | falling speed; 2:1 ratio on purpose |
| `δ` | 0.07 | dead band; was 0.05 at `n_min` = 8 — checked in Phase 0 commit 5, **kept by the owner** (19 Nov 2026, see below) |
| `Δ_max` | 3 | maximum move per session |
| `n_min` | 4 | below this, a type's answers do not count for the session (noise) |
| `K_calib` | ×4 over 3 sessions | initial calibration |
| `boost_retour` | ×2 over 2 sessions | after a long absence (30 days) |
| `t_rapide` / `t_lent` | 2 s / 8 s | speed credit bounds |

Tuning targets: convergence in 10–20 sessions, oscillation at equilibrium within ±2 levels, a
slightly positive mean bias (expected from `K_haut > K_bas`, harmless to fairness since it applies
to everyone equally).

## One difficulty axis at a time

Difficulty derives from the level through operand size. **Do not vary operand size and allotted
time together**: the effects would compound into a brutal curve mid-scale, hard to diagnose. (The
plan's timeout derived from the level, Phase 3, is a separate measured change.)

Consequence on rule 2: the sequence is not reproducible from the seed alone, since bounds depend on
the level. The level enters the config explicitly, is **frozen at the start of the session** and
never recomputed during it — otherwise the server cannot revalidate and duels fail.

700 steps (7 operations × 100) are not calibrated by hand: one continuous `level → bounds` function
per operation, five anchor points checked by hand (1, 25, 50, 75, 100), and two tests —
monotonicity and no brutal jump between consecutive levels.

## Per-question timeout: 15 s, counted as wrong

Automatic move to the next question after 15 s. Fixed value, not derived from `t_lent` — an
assumed simplification: 15 s is probably too long for `7 + 4` at level 3 and maybe short for a
multiplication at level 80. The plan derives it from the level in Phase 3, from measured times.

A timeout counts as a wrong answer: hesitating too long on a question one cannot solve must cost.

### Exception: interruption on abandonment

**Three consecutive timeouts without any key pressed** interrupt the session, which then does not
count for levels. Answers already given stay in history — they are real data, and the level is
recomputable anyway.

Reason: the useful distinction is not timeout versus wrong answer but **playing badly** versus
**having stopped playing**. A player who puts the phone down mid-session would otherwise pile up
zeros and lose levels for a reason unrelated to skill. Consistent with never lowering the level
through inactivity.

## The level step is weighted by answer volume

The formula used a pure mean: 16 additions at 85 % and 4 additions at 85 % moved the level
exactly the same. Counter-intuitive (focusing on one operation should make it progress faster) and
a perverse incentive (enable many types, play minimal sessions).

Fix: the step is multiplied by `√(n / n_min)`. The square root rather than the ratio, so that 64
answers do not move 16 times more than 4 — which would make the system unstable. It is an Elo-like
variable K applied to sample size. Side effect: small-session noise is damped, and four short
sessions give about the same result as a long one.

## `n_min` from 8 to 4 — coupled to `δ`

Product reason: 8 answers per operation made the minimal session too long. At 4, a single-type
session lasts about thirty seconds, which makes the "play, replay" loop viable.

**Statistical cost:** the standard deviation of the mean varies as `1/√n`, so going from 8 to 4
raises noise by about 40 %. A player exactly at the right level can score 4/4 then 2/4 by chance.

**`δ` must therefore widen** — the two parameters are coupled; never move one without the other.
Commit `1f8b891` (12 Aug 2026) widened it from 0.05 to 0.07 as an indicative value, without the
owner's approval. Checked in Phase 0 commit 5 (below); **the owner decided on 19 Nov 2026 to keep
0.07** (plan v2, section 8).

### Check of Phase 0 commit 5 (`tool/delta_check.dart`)

Simulated players (logistic model, two steepnesses `w` = 6 and 10, 2,000 players, seeded) run the
real `LevelUpdater`. A model compares settings, it does not calibrate them. At equilibrium
(oscillation = mean of (max − min) / 2 over 100 sessions; target ±2):

| Setting | Oscillation (w 6 / w 10) | Sessions that move | Convergence from level 1 |
|---|---|---|---|
| original: `n` = 8, `δ` = 0.05 | ±1.5 / ±1.7 | 7 % | 60 / 89 sessions |
| `n` = 4, `δ` = 0.05 | ±2.6 / ±3.2 | 29 % | 45 / 53 |
| **`n` = 4, `δ` = 0.07 (current)** | **±2.4 / ±3.1** | 27 % | 45 / 53 |
| `n` = 4, `δ` = 0.10 | ±2.2 / ±2.8 | 23 % | 49 / 56 |
| `n` = 4, `δ` = 0.15 | frozen | 1 % | never |

Findings:

1. **`n_min` = 4 does jitter more than designed** (±2.4 against ±1.5), and over the ±2 target.
2. **`δ` is a weak lever.** Going from 0.05 to 0.07 changes the oscillation by about 0.1 level. The
   level is an integer and the change is rounded, which adds `0.5 / K` to the dead band: to move
   one level at `n` = 4, `|mean p − p_cible|` must reach 0.237 upwards and 0.403 downwards — rising
   needs a mean `p` of 0.94.
3. **A cliff at `δ` ≈ 0.133**: mean `p` is at most 1.0, so the gap upwards is at most 0.30; with
   `(0.30 − δ) × K_haut < 0.5` the level can never rise outside calibration. `δ` = 0.15 freezes it.
4. **Convergence is far slower than its 10–20-session target** (45–90 sessions from level 1, for
   every `δ`): outside calibration a session moves the level by at most one step upwards.

**Decision: keep `δ` = 0.07** (recommended, confirmed by the owner on 19 Nov 2026). Widening further buys
little and moves towards the cliff. The real levers are elsewhere and already planned: the
placement test (Phase 1) for convergence, the continuous level value the leaderboard ranks on
(plan, section 6.4) which removes the rounding dead band, and recalibration on real data
(Phase 3).
**Reopen when** Phase 3 recalibrates on real sessions, or a continuous level is stored.

## The number of questions is derived, not chosen

`exerciseCount = n_min × active types`, capped at 24 (a target of ~90 s). With `n_min = 4`: one
type → 4 questions, three types → 12, seven types → 24 (capped; types then rotate by sampling
debt).

Rejected: letting the player set the number of questions (4 to 50). It would reintroduce the defect
fixed in step 4.1 — a session too short for the selection makes no operation progress — this time
triggered by the player without understanding why their level stalls.

## Immediate replay at the end of a session

Result-screen button: same types, same number of questions, **updated levels** and a **new seed**.
The new seed is essential — reusing it would replay the same questions. Updated levels make
difficulty follow progress from one session to the next, which makes the level system perceptible.

## Never show accuracy as a measure of progress

It converges to `p_cible` by construction, for every player at every level. Shown as progress, it
would teach the player that nothing moves while they improve.

The two metrics that really progress are **the level** and **the average response time**. The
second is the better one: it does not self-regulate, it is immediately understandable, and broken
down by operation it says *where* to work. Accuracy keeps its place as session feedback ("9/12"),
never as a curve.

## Resolved audit findings (step 5)

Kept for history; all fixed.

- **Stored history was never read back** — the Profile tab now reads sessions, answers and levels
  through aggregated queries on `SessionRepository` (SQL aggregation rather than loading
  everything: it does not degrade with time and prepares server-side recomputation).
- **The Android back gesture destroyed the running session** — a `PopScope` intercepts it, asks for
  confirmation, and stores the session as **interrupted**.
- **`SizedBox.shrink()` as a screen state** — replaced by explicit empty states with a way out.
- **Level-up animation never used** — the result screen shows the level change with
  `AppMotion.levelUp`.

## Visual direction: "nuit électrique"

Four directions compared (sober slate, light paper, nuit électrique, warm field). Chosen: nuit
électrique — a competitive register consistent with leaderboard and duels, where "slate" would have
better served a training tool.

Direct consequence: with a sea-green accent, green can no longer signal a right answer. Positive
feedback uses a white flash — which also settles accessibility, since colour alone was never a
reliable signal. Promoted to rule 14. Palette, typography and durations: `doc/design.md`.

## Inter, bundled

Interface font: Inter, variable (opsz + wght axes), one file in `assets/fonts/` from the official
google/fonts repository (SIL OFL). Bundled rather than fetched at runtime: works offline and
renders the first frame without a network round-trip. `TextStyle.fontWeight` drives the `wght` axis
directly. A display typeface for digits is chosen by the owner before Phase 5.

## `Exercise.prompt` left the domain

Exponents must be raised, which a flat `String` cannot express (Unicode `²`/`³` stop quickly and
render poorly across fonts). The display is composed in the presentation layer from each variant's
fields. Side effect: no interface text in `core/domain/`; the domain is purely mathematical.

## No negative result in subtraction

The generator guarantees `operandA ≥ operandB`. Negative answers cause typing errors with no
teaching value at this stage, and their absence removes the `−` key from the keypad. If this
changes, the keypad changes too.

## Built-in keypad rather than the native keyboard

The system keyboard hides the field and the timer, imposes an entrance animation and offers useless
keys. A drawn keypad has a fixed height, hence no layout shift between questions, and saves tens of
milliseconds per answer.

## Bottom tab bar rather than a side drawer

A drawer needs two gestures, hides navigation and pushes the thumb to the top-left corner. The
bottom bar stays visible and will carry duel notification badges. The session screen carries no
navigation.

## `assert` does not defend an invariant — use `throw` (rule 13)

The trap came back three times: division by zero (step 1), non-UTC timestamps (step 2), then
`OperandRange` and `CompositeExerciseGenerator` (step 3). Same cause each time: a precondition
guarded by `assert()`, removed from release builds — the invariant disappears exactly where it
matters. Fixed in step 4 (when computed bounds made invalid ranges reachable) and promoted to rule
13, each guard with a test of the invalid case.

## Levels are a recomputable cache, not a source of truth

What is stored can be rebuilt entirely from the answer history. The server can recompute the level
instead of trusting the client, and the update function belongs to the pure domain, with a
signature taking a list of answers — which also makes recalibration on real data possible.

What is stored **with each session** is the levels frozen at play time, not "the difficulty": the
pair (seed, levels) lets the server regenerate the sequence. One JSON per session (levels are per
operation). First real schema migration: `schemaVersion` → 2.

## Profile curve: overall level after each session (schema v3)

Each session stores `overall_level_after`: the overall level (`overallLevel`, 7 types, unplayed
counted as 1) right after it, updated cache included. The curve plots this value; the 30-day change
is the gap between its first and last points; a game's change in the list is the gap with the
previous game — exactly the effect of that game.

This replaced a session-entry snapshot over the types played that day, which never showed the last
game and made switching from addition to multiplication look like a level drop.

- `overallLevel` lives in `core/domain/leveling/`: it is a stored data rule, not just display.
- Nullable column, no reconstruction for older sessions: the overall level after an old session
  depends on the whole cache at that time, which history cannot faithfully rebuild. Those sessions
  are absent from the curve.
- Cache unreadable when recording: the session is written without this value rather than lost.

## Overall level: unplayed types count as 1

The overall level averages all seven types, an unplayed type counting as 1 (not 0, outside the
valid `[1, 100]` range of `LevelCacheEntry`). Averaging only played types inflated the overall level
of a player who had tried two types out of seven.

## Failed save: "Retry saving"

The result screen reports a game that was not saved and offers to retry the write
(`SessionController.retryPersistence`). Same session, same ids: `recordSession` is atomic, a failure
left nothing, so nothing can be written twice. No background queue: the failure is local (storage
full or blocked), and an in-memory queue would vanish on reload without guaranteeing more. Server
upload (Phase 2) relies on `synced_at`, already on every row.

## Difficulty is not a user setting

Rejected: a global easy/medium/hard selector, or a setting per type. Both contradict the meaning of
the level — if the player chooses the difficulty, the level no longer measures skill and the
leaderboard loses its meaning.

## The score is session feedback, the level is the ranking unit

Weighting points by difficulty is legitimate: without it, progressing changes nothing in the feel.
But the score never ranks — the level does. Two numbers telling the same story leave the player not
knowing which to watch.

## No generic `List<int> operands` on `Exercise`

Rule 9 closes the door on exotic types, so the gain would be nil, while the cost would be touching
stable code and losing the domain names of operands. `operands_json` already covers storage.

## Fractions and Euclidean division excluded

Final product decision. Both violate rule 9: fractions by their answer type, Euclidean division by
its composite answer (quotient + remainder, two input fields).

## Native `ChangeNotifier` rather than provider / riverpod / bloc

One active controller over three sequential screens does not justify a package.
**Reopen when** online play brings concurrent network streams (duel state, opponent presence).

## `sqflite` rather than `drift`

Hand-written schema, no code generation or build_runner in the loop.
**Reopen if** the analytical queries of the learning layer (Phase 4) become painful by hand.

## Web persistence: SQLite in WebAssembly (`sqflite_common_ffi_web`)

Until 17 Nov 2026, `InMemorySessionRepository` was the web fallback: a reload erased everything.
Chosen: `sqflite_common_ffi_web` — SQLite compiled to WebAssembly, run in a shared worker, database
stored in the browser's IndexedDB. **Same `SqfliteSessionRepository`, same schema, same
migrations** as on mobile, where plain `sqflite` replaces it (rule 16).

Rejected: a hand-written repository on `localStorage` (~5 MB quota, quickly reached with one row
per answer) or directly on IndexedDB (a second implementation of every query); `drift`.

Cost: two generated files in `web/` (`sqlite3.wasm`, `sqflite_sw.js`, versioned) from
`dart run sqflite_common_ffi_web:setup` — rerun with `--force` after upgrading the package.
Missing, the app stops on a "web storage unavailable" screen rather than silently falling back to
memory. The package is still labelled experimental by its author.
**Reopen when** browser eviction loses real data before server upload exists, or the package
stalls.

## `material_ui` package rather than `package:flutter/material.dart`

Flutter 3.47 moved the Material library out of the SDK into the `material_ui` package; the old
import is deprecated (28 analyzer notices). Owner's yes on 19 Nov 2026 (plan v2, section 8).
Migrated with the official data-driven fix (`dart fix --apply --code=migrate_design_widgets`):
imports only, no widget or golden image changed. Official Flutter package, every platform
(rule 16). No `MaterialUiCompatibilityBridge`: the two dependencies that still import the old
library (`supabase_flutter`'s lifecycle observer, `url_launcher_web`'s `Link`, unused) read no
`Theme`. CI's analyzer treats infos as fatal again.
**Reopen when** a dependency renders Material widgets through the old import (themes would then
need the bridge).

## No `uuid` dependency

A pure-Dart UUID v4 generator (`core/domain/persistence/uuid.dart`, ~15 lines, `Random.secure()`)
is enough.

## `points_awarded` removed from `answers` (step 2)

Proposed in the initial plan, removed during implementation: it grew the change by touching
`Scorer` and `AnswerResult`, both stable.

## Useless RNG draw in `CompositeExerciseGenerator`

Reusing `ArithmeticExerciseGenerator` with a one-element list still calls `random.nextInt(1)`
(always 0). Deterministic and harmless, but **removing it would change every sequence for a given
seed**. If fixed one day, it must be an isolated commit, with the determinism references
regenerated in the same commit.

## Android-only workarounds (Phase 8)

- Verify Android with `flutter build apk --debug`, `adb install -r`, `adb shell am start`: an
  attached `flutter run` disconnected five or six times.
- `kotlin.incremental=false` works around a Windows Kotlin crash when the project and Gradle caches
  are on different drive letters. Recheck on a clean machine or in CI before the first
  `flutter build appbundle`.

## Manual day/night toggle

A corner button on the Play screen, persisted through `ThemeModeStore` (interface in
`core/domain/`, `SharedPreferences` implementation in `infrastructure/`). Until something is stored,
the system theme stays the default — the button only overrides it once used.
