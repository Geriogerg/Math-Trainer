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
leaderboard or a second device. Existing email accounts keep their data. Design decided by the
owner in plan v2 (section 6.3); built in Phase 1 commit 4 (`doc/online.md`). The sign-out button
is hidden for guests from commit 4 on, not commit 5: in between, a guest pressing it would have
lost their account.
**Reopen when** abuse of anonymous accounts costs more than the protections planned (CAPTCHA,
cleanup).

Gaps filled in commit 5 — **provisional, owner to confirm**:
- Signing in to another account from a guest **keeps** the guest's local games on the device
  (hidden, unmerged) rather than deleting them: "replaced" in the plan read as "no longer
  shown", the reversible option. Deleting them is commit 7's explicit "Delete my data".
- The warning appears only if the guest has played at least one game; the button then reads
  "Sign in and replace guest progress".
- The player name is required when saving progress (the plan lists it with email and
  password); 30 characters at most, as in `profiles`.
- `linkEmail` returns `null` when the project requires email confirmation (Phase 6): the
  password is set in the same call, so confirming the email is the only step left.

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
commit 3, with no behaviour change: `lib/core/domain/` became `packages/math_core/lib/` (zero
dependencies — the package itself now enforces rule 1), the Flutter app moved to `app/`, the
simulation tools and core tests went with the core, and root `tool/` (hooks, smoke test, SQL
runner) became a small package so the hook rules keep their tests. Independent packages with path
dependencies rather than a pub workspace: a workspace resolves all members together, so the
server's container build (Dart only) would need the Flutter SDK to resolve `app/`.
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

## Continuous levels in integer hundredths (Phase 1, commit 2)

Owner decision (plan v2, section 8; schema migration approved). A level is an integer number of
hundredths (`Level`, an extension type over `int`, [100, 10000]); the update computes with
`+ − × ÷` and `sqrt` and rounds **once**, to hundredths. Generation, the score multiplier and
the screens read the whole part, truncated, so the level the player sees is the one that sets
the difficulty. The overall level stays a `double` in level units (display and Profile curve
only), so its stored points before and after the change stay on one scale.

Why an extension type and not a plain `int`: the migration multiplies every level by 100, and a
whole level mistaken for hundredths (or the reverse) is silent. The compiler now refuses to mix
them. It caught 120 places at once; one more (`levels[type] ?? 1`, which widens to `Object`) was
caught by a golden image showing "level 1200".

**Rerun of `tool/delta_check.dart`** (same model and seeds as Phase 0 commit 5):

| Setting | Oscillation w 6 / w 10 | Sessions that move | Convergence from 1 (w 6 / w 10) |
|---|---|---|---|
| whole levels, `n` = 4, `δ` = 0.07 (Phase 0) | ±2.4 / ±3.1 | 27 % | 45 / 53 |
| **hundredths, `n` = 4, `δ` = 0.07** | **±1.95 / ±2.31** | 60 % | **64 / 75** |
| hundredths, `n` = 8, `δ` = 0.05 (original design) | ±1.43 / ±1.71 | 71 % | 59 / 72 |

- **At equilibrium, better**: oscillation within the ±2 target for w = 6; the rounding dead band
  (0.5 / K) is gone; most sessions now move the level a little, which the result screen shows.
- **From level 1, slower** (64 vs 45 sessions). Rounding used to turn the largest normal step
  outside calibration, 0.69 level (`(1 − p_cible − δ) × K_haut` at `n_min`), into a full +1. The
  climb is now capped at 0.69 per minimal session after the three calibration sessions. Fixing
  convergence is the placement test's job (commit 6); the constants (`K_haut`, `K_calib`,
  calibration length) are the owner's Phase 3 decision. Not changed here.

**Display — owner decision (end of Phase 1)**: the level is always a whole number; the progress
inside it is a bar, never the hundredths as text. The result screen animates the number and a
bar from the level before to the level after (crossing a whole level, the bar wraps while the
number goes up); Profile shows a continuous bar per operation. Phase 1's provisional
"level 14 (+2.76)" is gone.
**Reopen when** Phase 3 recalibrates the constants.

## Placement test (Phase 1, commit 6)

24 questions, the four basic operations in turn, one **staircase** per operation (6 answers
each): a pass (right **and** within the time limit) moves the level up by the step, a fail
down, then the step halves (`~/ 2`, integer hundredths). The final level of each staircase is
the starting level (`placementLevels`, pure, replayable). Stored as a session of kind
`placementV1` (schema v5, `sessions.kind`); the kind carries the rules' version, since a stored
placement replays only with its own rules. Powers, roots and percentages are not placed.

**Parameters — provisional, chosen by `tool/placement_check.dart`** (the owner decides;
plan section 8). Simulated players (skill uniform 15–95, the `delta_check` model, 2,000 per
setting, both steepnesses), real staircase and real `LevelUpdater`:

| Setting | Placed error (mean, w 6 / w 10) | Games to ±3 (mean, w 6 / w 10) |
|---|---|---|
| no placement (from level 1) | — | 65.5 / 73.5 |
| **start 35, first step 25 levels, pass ≤ 3 s, sessionsPlayed 0** | **4.6 / 6.7** | **5.5 / 18.9** |
| start 50, step 20, pass ≤ 3 s | 4.5 / 6.6 | 5.5 / 20.8 |
| start 25, step 32, pass ≤ 3 s | 4.6 / 6.7 | 5.7 / 19.7 |

- **Pass ≤ 3 s** beats 4, 5 and 6 s in every row: a staircase converges where half the answers
  pass, and a stricter pass puts that point near the level's own target (right and fast,
  `p_cible` 0.70).
- **sessionsPlayed 0 after placement** (the next three games keep the ×4 calibration boost)
  beats 1 and 3 everywhere: the boost corrects a placement error fast.
- **Start 35** is as accurate as 50 and shorter (modelled median ~100 s against ~112 s).
- The plan's exit test ("a placed player at their level within about 10 games") holds for the
  steeper model (5.5 games, p90 20) but **not for the noisier one** (18.9, p90 53): there the
  game updates themselves are slow (0.69 level per game at most outside calibration — commit
  2's finding). That is the Phase 3 constants decision, not the placement's.
- **Duration**: modelled median ~100 s, above the plan's 60–90 s — the model gives a wrong
  answer ~9 s (thought + correction pause), and a staircase is built to fail about half of its
  last questions. To check on the owner's phone; 5 questions per operation is the lever.

Gaps filled in Phase 1 (the offer rules were replaced by the owner, see version 2 below): the session screen says "finding your level" instead of a level; the result
screen shows the starting levels and the mistakes, no score, and a single "Play".
**Reopen when** real placements exist (Phase 3): compare placed levels with the levels the
same players settle at.

### Version 2 — owner decisions (end of Phase 1, applied in Phase 2 commit 0)

`placementRulesV2` (`SessionKind.placementV2`); version 1 stays, so a stored `placementV1`
replays with its own rules (both pinned in the determinism references).

- **5 questions per operation** (20 in all), same start (35) and first step (25 levels). Rerun
  of `tool/placement_check.dart` with 5 per operation: modelled median **81–82 s** (was ~100 s),
  placed error 4.8 / 6.9 (w 6 / w 10, was 4.6 / 6.7), games to ±3 **5.6 / 20.0** (was 5.5 /
  18.9). Pass 3 s still beats 3.5, 4, 5 and 6 s in every row.
- **Pass time per operation, from `t_rapide`**: `passMaxElapsedMsByType`, each 1.5 ×
  `t_rapide` (`placementPassTimeOverTRapide`; a test ties the values to `LevelingRules`).
  **Today the four are equal (3 s)**: `LevelingRules` has a single `t_rapide`, 2 s, for every
  operation, and no data says how much slower × and ÷ are. The structure is per operation; the
  values diverge when Phase 3 gives `t_rapide` per operation from real answers. Lowering the bar
  for × and ÷ in the placement alone would place players above where their games then pull
  them, since games score speed against the same flat `t_rapide`.
- **Offer**: on Play, to a player with **no completed session** (an interrupted session or
  placement does not count — it is offered again) who has not skipped it. A skip is remembered
  per player (`PlacementSkipStore`, `shared_preferences`); Profile keeps a "Find my level"
  entry until the player completes a session. Play draws nothing until its local read resolves,
  so the type selection no longer flashes before the offer.

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
fields. Side effect: no interface text in `math_core/lib/`; the domain is purely mathematical.

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

- `overallLevel` lives in `math_core/lib/leveling/`: it is a stored data rule, not just display.
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

## First load: nothing from Google, a loading screen with real progress (Phase 1, commit 3)

- **CanvasKit from the site** (`flutter build web --no-web-resources-cdn`): no third-party CDN
  at runtime (privacy, availability, and one origin to measure). Cost: the build output keeps
  every CanvasKit variant (~43 MB on disk); the browser fetches one.
- **Fonts from the site**: with local resources, Flutter ships its default fallback font itself
  (`assets/fonts/fallback/Roboto-Regular.ttf`, 89 KiB on the wire). The engine still fetches
  Noto fonts for glyphs no bundled font has, from `fontFallbackBaseUrl` — set to `'fonts/'`
  in `web/flutter_bootstrap.js`, where nothing is hosted, so those requests 404 instead of
  reaching Google. A walk of every screen and all seven exercise types requested none — Inter
  covers + − × ÷ √ % and the rest. **Consequence**: a glyph outside Inter now renders as a box
  — a new UI symbol must be checked (network panel), and **player names in scripts Inter lacks
  (CJK, Arabic, Hebrew, Devanagari…) would show as boxes** once names of others appear
  (Phase 2 leaderboard). Owner to decide there: restrict names to supported scripts (also
  simpler moderation), host the Noto fonts needed, or allow Google for fallbacks only.
- **Licences**: the OFL texts of Inter and Roboto (both served from the site now) ship in
  `web/fonts/*/OFL.txt`; Inter's had been missing since step 5.
- **Loading screen** in `web/index.html`, plain HTML/CSS painted before any script: palette of
  `doc/design.md`, the stored day/night choice, system font. The bar moves when each large file
  has actually arrived (resource timing, weighted by size), then through engine start; removed
  on Flutter's first frame. Not a byte counter: a 1.5 MB file moves the bar when it completes.
  Rejected: fetching the files ahead with a streamed byte count — with gzip, the size on the
  wire is unknown to the page, and a cache miss would download everything twice.
- **Measured cost of self-hosting** (preview, cold cache): 3.41 MiB before the first frame
  against 2.86 MiB from Google's CDN; Fast 4G 4.6 s (was 3.6 s), Slow 4G 20.0 s (was 16.0 s).
  Google serves `canvaskit.wasm` brotli-compressed (1.5 MiB), GitHub Pages only gzip
  (2.0 MiB); Slow 4G is bandwidth-bound (3.41 MiB ≈ 18 s at 1.6 Mbit/s), so only bytes count.
  Levers, none applied: a host serving brotli (Phase 6 production host — e.g. Cloudflare
  Pages); subsetting Inter (451 KiB → roughly 100 KiB, about −1.7 s on Slow 4G, at the price
  of the glyph coverage above).
**Reopen when** a UI symbol needs a fallback font, or the Wasm renderer (`--wasm`, skwasm) is
adopted.

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

A pure-Dart UUID v4 generator (`math_core/lib/persistence/uuid.dart`, ~15 lines, `Random.secure()`)
is enough.

## `points_awarded` removed from `answers` (step 2)

Proposed in the initial plan, removed during implementation: it grew the change by touching
`Scorer` and `AnswerResult`, both stable.

## Self-contained sessions: the type sequence is stored (Phase 2, commit 1)

Phase 1 found that a game's question order depends on the player's per-type session counts at
the time (`DebtAwareTypeSelectionStrategy`, least-played types first), read from the level
cache and stored nowhere: a single session could not be replayed without the player's whole
history. The plan offered two fixes: store the counts, or store the type sequence itself.

Chosen: **the type sequence** (`sessions.type_sequence`, schema v6; `SessionConfig.typeSequence`,
`PersistedSession.typeSequence`). The app decides it once at the start with the debt strategy
and generates through `FixedTypeSequence`, which consumes no randomness — so the questions are
exactly what they were (a test checks both paths give the same exercises; no pinned sequence
changed). Why not the counts: the sequence also covers the placement (fixed rotation) and any
future strategy without keeping old strategy code replayable, and the server's replay needs no
history. A forged sequence gains nothing the server cannot see: it still regenerates every
question from it and checks every answer (commit 6).

- `replaySessionQuestions(session, answers)` (`math_core/lib/replay/`): the questions of a stored
  session from (seed, kind, frozen levels, type sequence), one per answer; a placement replays
  with its own rules version. Throws `SessionNotReplayable` when the session lacks what it
  needs — never guesses a missing level.
- **Old sessions**: schema v6 backfills every session played to its end with its answers'
  types in the order given (`rowid`), which is exactly its sequence. An older interrupted
  session keeps `null`: readable as before, not replayable.
- `answersForSession` now returns answers in the order given (it had no `ORDER BY`).
- The plan's test: `test/state/self_contained_sessions_test.dart` plays a placement, five games
  (2 to 7 types, rotation exercised) and an interrupted game through the app's builders into
  SQLite, then replays each stored session alone and gets back every question.

## Uploads: the local database is the queue, sent in order (Phase 2, commit 5)

No separate queue table: "pending" is a query on the sessions themselves (never synced, never
refused), so a closed tab, a crash or an offline week loses nothing, and there is nothing to
keep consistent. Sent **one at a time, oldest first**, because the server checks each session's
frozen levels against the levels its predecessor produced (commit 6) — parallel or reordered
uploads would be refused as out of order. Only the server's answer is final: every transport
failure is retried, every refusal is recorded and never resent (resending cannot change a
replay's verdict). The server's verdict carries `received_at`, stored as `syncedAt` (rule 6:
`createdAt` ≠ `syncedAt`). Bearer verification by asking Supabase Auth (`/auth/v1/user`) rather
than checking the JWT locally: no JWT library, works with Supabase's rotating signing keys, and
catches revoked sessions — one HTTP call per upload, negligible here.

## Validation: the chain of levels, and adopting the server's (Phase 2, commit 6)

Replaying questions and answers alone would let a forger claim **easier frozen levels** (level 1
questions, answered perfectly) and climb. So each game must start from the levels the server
itself produced from the player's previous accepted session — the server never takes a level
from the client. Its cost: a session played on another device, or local history from before
uploads (whole-number levels until Phase 1, never replayable to the same values), does not
chain and is refused (`levelsMismatch`). Rather than leave that player stuck, the refusal carries
the server's levels and the app adopts them: its next games chain again. The refused sessions
stay in the local history and the Profile, they only never reach the board.
Alternatives rejected: trusting the client's frozen level (forgeable); recomputing every level
from the whole uploaded history on each upload (same verdict, more work, and still nothing to do
with sessions the server never saw).
**Provisional (owner to confirm)**: rejection reasons and flags as listed in `doc/online.md`;
the timing-flag thresholds (300 ms, 40 ms spread) are guesses until Phase 3 data.
**Reopen when** multi-device play matters (Phase 7): sync levels down at sign-in instead.

## Leaderboard read path and eligibility (Phase 2, commit 7)

The board is read from Supabase directly, through two `security definer` SQL functions that
expose rank, name and level only; nothing about other players' sessions, answers or ids leaves
the database. Through the Dart server instead: one more hop, and a free host's cold start would
put a minute's spinner on the Leaderboard tab. Ranks are computed on each read (window
functions over at most a few thousand rows during the beta) rather than stored: nothing to keep
in sync, and "within 30 days" moves with the clock by itself.
**Provisional (owner to confirm)**: eligibility = active within 30 days and ≥ 3 counted
sessions on the operation (overall: ≥ 3 completed games) — 3 matches the calibration boost's
length, after which a level means something; "Top N %" rounds up (the best player is "Top 1 %"
of a 100-player board, never "Top 0 %").
**Reopen when** the beta shows boards too empty (lower the bar) or noisy (raise it).

## Player names: a charset the font draws, a short blocklist, reports (Phase 2, commit 9)

The plan asked for a name filter "including a character set limited to what the bundled fonts
cover" (no font is fetched at runtime, Phase 1 commit 3). Inter's character map, read from the
font file, covers Latin (with Vietnamese), Greek and Cyrillic; the allowed set is a curated
subset of that (letters people type in names, no symbols, no combining marks), and a test
re-reads the font so a font change cannot silently break it. CJK, Arabic, Hebrew, Devanagari,
emoji: refused with a message naming what is allowed — **owner decision** whether to bundle a
font for more scripts later (megabytes on the first load).
The rule lives in Dart (instant feedback) and in SQL (the enforcement, since the app writes
`profiles` directly under row-level security); a parity test keeps them identical. The
blocklist is deliberately short — a list never catches everything and false positives anger
real players ("Draper" contains "rape": not in the list) — and **reports** cover the rest.
**Provisional (owner to confirm)**: the allowed set, the word lists, and hiding a name after 3
reports pending review.
**Reopen when** the beta shows abuse the list misses, or players whose names are refused.

## Stale guests: activity = uploads or a renewed session (Phase 2, commit 11)

The plan: delete anonymous players with no uploaded session for 30 days. Taken literally, before
the server is deployed (no uploads at all) that deletes every guest older than 30 days,
including ones who play every day — their progress would vanish behind a new guest. So a guest
counts as active if it uploaded **or** renewed a sign-in session (`auth.sessions`, renewed by
the app whenever it is open) in the last 30 days. Device side, a guest left for another account
keeps its hidden games 30 days (owner's Phase 1 decision: "deleted with the guest account").
**Provisional (owner to confirm)**: the extra activity signal, the 03:17 UTC daily schedule.

## Android: compile-only, weekly, outside the push pipeline (Phase 2, commit 12)

Plan v2.2 §5 settles the Phase 0 question: a scheduled job compiles the APK once a week and on
demand, not on every push. A separate workflow (`android.yml`) rather than a job in `ci.yml`:
its failure never cancels or blocks a preview deployment, and a push never waits for Gradle.
It also runs when its own file changes, so a change to it is checked at once.

## Server host: Render free, prepared (Phase 2, commit 4) — owner decision pending

The plan: host and monthly cost prepared, **not deployed until the owner confirms** (it costs
money or has limits). What the server must do here is small: receive an upload after each game
(background work, retried from an offline queue) and write to Supabase. Reads (the leaderboard)
go straight to Supabase, so a sleeping server never slows a screen.

| Host | Cost (as of late 2026, to check) | Trade-off |
|---|---|---|
| **Render, free web service** — recommended to start | 0 | Docker from the repo, `render.yaml` blueprint, deploys on push. Sleeps after 15 min idle: the first upload after a pause waits ~1 min — invisible to the player (background). |
| Render Starter | ~7 $/month | Same, always awake. The upgrade path when uploads must land at once. |
| Google Cloud Run | free tier covers the beta | Scales to zero, starts in ~1 s; needs a Google Cloud billing account (card) and more setup. |
| Fly.io | ~2–5 $/month | Small always-on VM; no free tier for new accounts. |
| Supabase Edge Functions | 0 | Deno only. The core could run there compiled to JavaScript (VM = JS is pinned), but the plan chose a Dart server; noted as a fallback. |

**Provisional: Render free** — `render.yaml` and `server/Dockerfile` ready, nothing deployed.
**Reopen when** the owner chooses, or uploads need to land immediately (live duels, Phase 7).

## SQL migrations applied by CI, tested on plain Postgres (Phase 2, commit 2)

The plan: Supabase SQL in versioned migrations applied by CI on `main`, access token and database
password as secrets, no SQL by hand. Done with the Supabase CLI's own flow (`supabase link` +
`supabase db push`, migration history kept by the CLI in the project) rather than `psql` on a
connection string: the CLI finds the project's connection pooler from the access token, so no
region-specific host is stored anywhere.

Added beyond the plan: every migration is **tested before it reaches the project** — the `sql`
CI job applies them to a scratch Postgres with a small stand-in for Supabase's auth schema and
roles, twice (idempotence: the first two were run by hand before migrations existed), then runs
SQL tests. A full local Supabase stack (`supabase start`, Docker) was the alternative: heavier in
CI, and unavailable on the owner's machine. The stand-in only fakes what the migrations use; the
server's tables and functions (commits 5–7) are tested the same way.

The Phase 1 test accounts are deleted by a migration listing their eight ids
(`20261119000100_delete_phase1_test_accounts.sql`): auditable, applied once by CI, a no-op after.
**Reopen when** a migration needs a Supabase feature the stand-in cannot fake (then: `supabase
start` in CI).

## Cross-platform determinism: pinned references, VM and JavaScript (Phase 1, commit 1)

Players generate in the browser (dart2js); the server will replay on the Dart VM. `dart:math`'s
`Random(seed)` and IEEE 754 arithmetic are specified the same on both, but "specified" is not
"checked": `packages/math_core/test/determinism/` pins 144 session sequences (12 seeds × 12 setups, built
exactly as `buildSessionController` builds them), 12 endless sequences and a 5,040-update grid
of `LevelUpdater`, as strings generated on the VM (`tool/determinism_references.dart`). CI runs
the core suite on the VM and with `-p node`. **Result on 19 Nov 2026: identical, 158 of 158.**
Seeds include real ones (millisecond timestamps, ~2^41), around 2^32 (where a JavaScript port
of a 64-bit seed splits it), negative and 2^53 − 1. Seeds beyond 2^53 cannot exist in a browser.

The references are regenerated only by a change meant to alter sequences, in the same commit;
never to make a JavaScript failure pass.

Found along the way:

- **A session's sequence also depends on `sessionsPlayedByType`** (the debt-aware strategy
  orders the interleaving by it), which is not in `SessionConfig` nor stored with the session.
  It is recomputable by replaying a player's history in order, but a session cannot be replayed
  on its own. **Phase 2 must settle it** — store the counts (or the type sequence) with the
  session, or replay histories in order.
- `Random.secure()` throws under dart2js on Node 24 (SDK bug reading `globalThis.crypto`);
  browsers are fine. The UUID test is `@TestOn('!node')`; nothing deterministic depends on it.

**Reopen when** the core gains floating-point functions beyond `sqrt` (rule 18), or a WebAssembly
build (`--wasm`) ships: add a `-p chrome --compiler dart2wasm` run then.

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
`math_core/lib/`, `SharedPreferences` implementation in `infrastructure/`). Until something is stored,
the system theme stays the default — the button only overrides it once used.
