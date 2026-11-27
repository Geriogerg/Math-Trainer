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

Gaps filled in commit 5 — **Confirmed by the owner (19 Nov 2026, after Phase 3a)**:
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

### Preview on GitHub Pages — superseded

**Superseded** by "Preview host: Cloudflare Pages" (Phase 3a): the repository went private on
20 Nov, and GitHub Pages now only redirects when `GITHUB_PAGES_REDIRECT=on`. *(Status marked at Phase 6b commit 8, review m19.)*

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

## Levels phase — owner decisions (plan v3.1, `doc/levels.md` v1, 23 Nov 2026)

The level system is specified by the owner in `doc/levels.md` (binding, never edited by Claude
Code); this section only records it and the gaps filled. In short: everyone starts at level 0
(0–100, hundredths); ten tiers per operation decide the content and the fluent time; a game
moves each operation by its quality `q` (credit 1 fluent, 0.75 slow, 0 wrong or timeout), dead
band 0.55–0.65, at most +3/+3/+4/+5 (4/5/10/20 questions) and −2; no placement; all levels reset
to 0 at the transition, history kept, boards fresh; Training Easy/Medium/Hard = T1/T4/T7; a
rules version stored with every session; a Tables mode and a Tips page.

**Supersedes**: "Leveling parameters — starting values", "The level step is weighted by answer
volume", "`n_min` from 8 to 4", "One difficulty axis at a time" (operand curves), "Placement
test" and its version 2, the type placement, "Overall level: unplayed types count as 1" and the
Redesign's "a never-played operation shows level 1" (now 0, the floor). Kept: levels in integer
hundredths, frozen at the start, never decaying, recomputable, replayed by the server.

### Gaps filled by Claude Code — confirmed by the owner (plan v3.2)

Every choice below was provisional at the phase's end; the owner kept them all (plan v3.2,
"Levels outcome"). The level update's constants moved afterwards, as rules v3 (next section).

- **The rules version** is an enum stored with each session (`RulesVersion`: v1 = everything
  before, v2 = `doc/levels.md`, except addition and subtraction, built from an earlier draft —
  found and fixed in v4, see "Patterns and Method phase"): app schema v10
  `sessions.rules_version` (NULL = v1), the upload's `rulesVersion` (absent = v1), and on the
  server a column read from the stored payload.
  **v2 is built alongside v1** through commits 1–3 and becomes the one new games use at commit 4,
  the transition: every intermediate build deployed to testers plays exactly as before, and the
  switch, the reset and the new content arrive together.
- **A rules-v1 session uploaded after the transition is refused** (`rulesRetired`), not
  validated: it was played on levels that no longer exist, so it can move nothing, and keeping
  the whole v1 machinery alive only to store it would contradict principle 5 of the spec. It stays
  in the player's local history like any refused session. Played-and-pending v1 sessions are rare
  (a game finished offline before the update).
- **The fluent time is the frozen level's tier's**, for every question of that operation in
  the game, review questions included (`fluentTimeMs`). The spec says "the tier's fluent time";
  the player's tier is the one the game is played at and the one the level measures, and a
  review question is meant to be easy — crediting it against the lower tier's shorter time
  would make reviews cost credit. Commit 3.
- **The review split is exact per operation**: 30 % rounded half up (1 of 4, 2 of 5, 3 of 10,
  6 of 20), the review questions placed at random in the game by its own seeded stream —
  rather than a 30 % chance per question, which would give a 4-question game anywhere from 0
  to 4 reviews. Commit 2.
- **The level change rounds once, to the nearest hundredth** (halves away from zero), from
  integer arithmetic: the spec's −0.3 is −0.29 (`(0.55 − 0.5) / 0.35 × 2`). Commit 1.
- **Questions per tier, where the spec leaves room** (commit 2): subtraction T0 never gives 0;
  T7 subtraction is half "across a zero" (403 − 178), half other double borrows;
  multiplication T0–T1 shows the table on either side; T6 addition never carries out of the
  hundreds; percentages: T1 bases up to 200, T3 up to 400, T5 from 20 to 400, T8 percentages
  110, 120, 125, 150, 175, 200 % of 2-digit numbers; integrals: bounds kept small (answers
  under 6 digits), T9's second term negative half the time, never larger than the leading
  term covers from the lower bound on. A tier with two kinds draws each half the time.
- **Cube roots show a small raised 3 before √**: no bundled face has `∛`, and the page never
  fetches a font (a missing glyph shows as a box).
- **The transition (commit 4)**: rules v1's code is deleted (the `p_cible` formula and its
  constants, the operand curves, the v1 generators, the placement and type placement); the
  stored `SessionKind` placement names stay, never replayed. Locally (schema v11) the level
  cache empties — an absent level is 0 — and on the server `server_levels` empties in the same
  release; the main board counts only rules-v2 games toward its three, an unplayed basic at 0.
  The app never sends a v1 session (refused locally, `rulesRetired`); the server refuses one
  anyway. Known gap: between CI's migration and the new server's deploy (minutes), the old
  server can accept a v1 game from an old page and write a v1 level to the fresh cache — small
  (it chains from the reset), and it becomes that player's v2 starting point.
- **Profile after the reset**: the curve and its 30-day change use the sessions of the
  current rules only (a v1 level is on another scale); the recent games keep the whole history,
  with no change shown across the reset. The main level shows 0 before any game.
- **Duels move to the tiers** (`DuelConfig.questions` draws like a game under the current
  rules, reviews included): their three pinned duels are re-recorded on purpose — no duel was
  ever stored (Phase 7 builds them).
- **Phase 3b's window restarts at this release** (`calibration_window`, moved by the
  transition's migration): its games must measure the new rules. The owner can move it.
- **Scores**: the difficulty multiplier runs from 1 at level 0 to 2 at level 100 (it ran from
  level 1). The score is feedback only.
- **Training keeps 15 / 40 / 70**: inside T1 / T4 / T7, so stored Training games keep their
  difficulty and the server's check of them is unchanged.
- **Display — the plan's rule over the spec's** (commit 5): `doc/levels.md` section 6 sets
  + − × **always** on two right-aligned lines; the plan's commit 5 says "one line, two
  right-aligned lines when it doesn't fit, thousands grouped, 10-digit answers". `CLAUDE.md`:
  the plan wins a conflict, reported. Built: one line when it fits the game's width, stacked
  otherwise (a rule under the operands, the answer right-aligned on their units column);
  division never stacks (the spec). Switching to "always stacked" is one condition in
  `promptStacks`.
- **Thousands grouped with a space** ("12 500"), not a comma: French-speaking players read
  "4,789" as a decimal, and the space is the SI separator. A plain space, which the digit face
  draws (a narrow no-break space is not in its subset).
- **"Roots"** replaces "Square roots" as the label: the family has cube roots since the tiers.
- **Tables mode, the gaps** (commit 6): the card is the last of Home's Challenges; the setup is
  From / To steppers (1–50, the first pushing the last along), Multipliers 1–10 / 1–20,
  Questions 10 / 20 / 50, defaults 2–10, 1–10, 20, remembered. A round deals every fact of the
  chosen tables shuffled by its seed, a longer round deals them again (each fact once per
  pass); the table is written first ("17 × 6"). Played on the game screen as Training, with a
  throwaway repository: never in the history, the level cache or the upload queue. Stats on
  the device: games, right answers as "right / answers" (a raw count, as the result screen's —
  never a rate presented as progress), and the three slowest facts by average time, on
  Profile under the challenges.
- **Tips page, the gaps** (commit 7): reached from a "Tips" card under Tables; the spec's tips
  written one sentence and one example each and placed in bands by the tier their example
  belongs to, so every operation has tips in all three bands; the seven strategies of the
  detector are each one tip's (`Tip.strategy`). The player's band on each operation is marked
  by an outline, a marker icon and a heavier label (never colour alone) and heard as selected;
  a never-played operation is in the beginner band (level 0). Plain text in Inter: "cube root
  of", "∫ … from 0 to 4" — no glyph the bundled faces lack.

### The grind, simulated (commit 8, `tool/levels_simulation.dart`)

Median games from level 0 to the start of each tier, 1001 seeded players each, the real update
with each tier's fluent time; accuracy the same at every tier (real players stall where their
accuracy drops):

| 10 questions per game | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 |
|---|---|---|---|---|---|---|---|---|---|
| perfect | 3 | 5 | 8 | 10 | 13 | 15 | 18 | 20 | 23 |
| perfect, all slow | 7 | 13 | 19 | 25 | 32 | 38 | 44 | 50 | 57 |
| 80 % right, fluent | 5 | 9 | 13 | 17 | 22 | 26 | 30 | 34 | 38 |
| 60 % right, fluent | 22 | 45 | 71 | 95 | 119 | 143 | 169 | 192 | 215 |

With 4 questions per game: perfect 4 / 7 / 10 / 14 / 17 …, 80 % 7 / 12 / 19 / 25 / 31 …

- **The spec's grind estimate holds exactly**: level 20 in 5 perfect games, 50 in 13.
- **A correct-but-slow player climbs**, at 40 % of the perfect pace (q = 0.75 → +1.6 a game).
- **Finding, for the owner (Phase 3b)**: a 60 % player does **not** stall as the spec expects
  ("a player stalls around 60–70 % correct answers") — they creep up about a tier every 24
  games. The dead band 0.55–0.65 is centred on 60 %, but games vary (4 of 10 right one game,
  8 the next) and a step up is larger than a step down (cap +4 vs −2, span 25 vs 35 points),
  so the expected change is +0.4 level a game at 60 % (+1.3 at 70 %). The expected change is
  zero at **54 %** right (53 % with 4 questions, 56 % with 20). In play, accuracy falls as the
  tiers get harder, so players will still stall — one tier or so above where the spec places
  them. Nothing changed: the constants are the owner's (`doc/levels.md`, tunable); to stall
  at 60–70 %, raise the dead band (e.g. 0.62–0.72) or make the down cap equal to the up cap.

## Patterns and Method phase — owner decisions (plan v3.3, `doc/levels.md` v1.2, 23 Nov 2026)

Specified by the owner in `doc/levels.md` sections 5b and 9 (binding). In short: each tier mixes
in **pattern questions** — numbers a shortcut makes easy (17 × 23, 65 + 98, 123 456 ÷ 3) — about
40 % of a tier's questions from the tier where a family starts, among the families available
there, reviews included, same fluent time; generated backwards; a new rules version (**v4** = v3's
level update + new generation), v2 and v3 generators kept so their games replay. On the result
screen, every wrong answer and timeout of a Basics or Advanced game gets a **Method**: the
strategy's name and 2 to 4 lines of arithmetic with the question's numbers, ending on the
answer, a "More tips" link; the pattern family's own strategy for a pattern question, the
detector's best otherwise, a fallback per operation; every line checked by tests.

### Gaps filled by Claude Code — confirmed by the owner (plan v3.4)

Every choice below was provisional at the phase's end; the owner kept them all (plan v3.4,
"Patterns and Method outcome"), and added a rule: `doc/levels.md` is checked by a test that
reads the file (`packages/math_core/test/spec/levels_spec_conformance_test.dart`).

- **Addition and subtraction follow the spec's section 5 tables from v4 on — a mismatch found
  in v2/v3.** The spec's addition and subtraction tiers run to 9 digits (T2 47 + 38, T5
  4 789 + 3 657, T7 482 761 + 359 846) with fluent times 4–25 s; the generator built at the
  Levels phase's commit 2 stops at 4 digits (T7 is 3-digit + 3-digit, T9 4-digit + 4-digit)
  with fluent times 4–14 s, and its tests checked that table, not the spec's. The spec has
  said this since it arrived (`5cdabd8`); the Levels phase's exit test was wrong to call these
  two operations conforming. v2 and v3 games keep their generator and fluent times (they must
  replay); **v4 generates and times addition and subtraction as section 5 says**. The other
  six operations already matched. Players' levels carry over: an addition player at T5 meets
  4-digit + 4-digit questions from v4 on instead of 3-digit + 2-digit.
- **Fluent times are versioned** with the generation: `fluentTimeMs` takes the rules version
  (v2/v3: the old addition and subtraction times; v4: the spec's). The level update itself is
  v3's, unchanged.
- **v4 is replayed from commit 1 and played from the last commit** (`RulesVersion.current` moves
  to v4 with the simulation, commit 5): the server learns v4 first, the pattern generation can
  still be corrected while the Method's tests exercise it, and no game is ever played under a
  generation that later changes. The Phase 3b window restarts at that switch (migration, like
  the Levels transition's).
- **The pattern share is a per-question draw**: each question is a pattern question with
  probability 2 / 5 when at least one family is available at the tier it is drawn from (its
  own or, for a review, the one below), the family then drawn uniformly among them. "About
  40 %" is the spec's wording; an exact quota per operation (as for reviews) would interact
  with the review split, and a 4-question game is too short for "40 %" to mean one count.
  Commit 5 reports the share actually served per tier.
- **The pattern family is not stored**: a game's questions replay from its stored seed, so the
  family of each question is recomputed by the same replay (`replaySessionPatterns`), never
  guessed from the numbers. The Method uses it; history and uploads carry nothing new.
- **A third addend** for "three terms, two of them complements" (27 + 46 + 73):
  `ArithmeticExercise.operandC`, addition only, stored as `operandC` only when present (older
  questions keep their shape); shown "27 + 46 + 73", stacked on three lines when too wide.
  Structural features (Dart and SQL) keep reading the first two operands.
- **Method lines are expressions, not strings**: each line is a chain of integer expressions
  joined by = or <, rendered with the app's notation (raised exponents, grouped thousands); the
  tests evaluate every term and every relation, and the last term of the last line is the
  answer. A line may continue the previous one ("= 400 − 9").

- **The Method's fallbacks, where section 9 leaves room** (commit 2): addition by place value
  — digit columns up to 3 digits, groups of three digits (thousands, millions) beyond, the
  "column with carries" of long numbers in at most three lines; under 10 + 10, make 10 (8 + 7
  = 8 + 2 + 5). Subtraction: within 10, the addition it undoes (4 + 5 = 9, 9 − 4 = 5); else count
  up through the round number at the subtrahend's leading place (178 → 200 → 403), else by
  place value. Multiplication: split the larger factor (347 × 6 = (300 + 40 + 7) × 6); tables
  by fives (8 × 7 = 8 × 5 + 8 × 2); × 1 and × 10 by the swapped fact. Division: the dividend
  split along the quotient's leading place ((1 800 + 282) ÷ 6 = 300 + 47); a one-digit quotient
  by its multiplication (4 × 7 = 28, 28 ÷ 4 = 7). Powers: squares from the nearest ten, other
  powers one factor at a time. Roots: bracket between tens, the last digit, and — two roots
  end the same way — the middle square (85² = 7 225 < 7 569 → 87). Percentages: the friendly
  fractions (÷ 2, ÷ 4, ÷ 5, ÷ 10, × ¾), eighths, 10 % / 5 % / 1 % on a base divisible by 100,
  the whole and the rest above 100 %, else p × base ÷ 100. Integrals: F(b) − F(a).
- **The detector's "round the subtrahend" is skipped when it would pass below zero** (9 − 8 as
  9 − 10 + 2): the fallback takes over. A question whose answer is already on screen (2¹) gets
  one line; every other gets 2 to 4.

- **The Method on the result screen, the gaps** (commit 3): every Levelling and Training game of
  the Basics and Advanced operations (both are "a Basics or Advanced game"); never Tables mode
  or the challenges. Under each mistake a "Method" button (its label turns to "Hide method";
  screen readers hear it expanded) opens a card in place — the strategy's name, the lines,
  "More tips" — one card per mistake, any number open. The mistake row now wraps (a 9-digit sum,
  its answer and the struck-through one do not fit a phone line); a long Method line shrinks to
  the width rather than breaking mid-expression. "More tips" opens the Tips page over the
  result, scrolled to that operation, the bands marked from the player's levels after the game.
  Strategy names are the app's words (`method_labels.dart`), the fallbacks named after section
  9's table.

- **Tips for the families** (commit 4): each of the 49 families is one tip's (`Tip.families`),
  of its operation. 30 families joined an existing tip that teaches their shortcut (× 9 is
  × 10 minus once for × 99; round the subtrahend for 9 856 − 996; split the dividend for
  123 456 ÷ 3…); 19 new tips, one sentence and one example each, placed in the band of their
  family's first tier: doubles, complements, big round numbers, three terms; across a round
  number, same gap; same tens with units to 10, × 101, powers of 2 multiplied, both near 100;
  dropping zeros; splitting the exponent, 11 and 111; roots of powers of 2, roots ending in
  25, roots near 100 or 1 000; half and quarter, near 100 %; 2x from a to b. "More tips" lands
  on the Method's tip — its family's, else its strategy's — marked by a bar and an arrow; a
  fallback lands on the operation's section.

- **Duels carry their rules version** (commit 5): `DuelConfig.rulesVersion`, stored in its JSON
  (`rules`; absent means v3, what duels drew under until then), default the current rules. Duels
  had drawn under `RulesVersion.current`: a stored duel would have changed its questions at
  this very switch. The three pinned duels stay pinned under v3 — nothing re-recorded.

### The share of pattern questions served (commit 5, `tool/levels_simulation.dart`)

Games of 10 questions at each tier, 2,000 per cell, reviews included, the real v4 generator:

| % | T0 | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 |
|---|---|---|---|---|---|---|---|---|---|---|
| addition | 0 | 28 | 40 | 40 | 40 | 40 | 40 | 40 | 40 | 40 |
| subtraction | 0 | 0 | 0 | 28 | 40 | 41 | 40 | 40 | 40 | 41 |
| multiplication | 0 | 0 | 28 | 40 | 39 | 41 | 40 | 40 | 40 | 40 |
| division | 0 | 0 | 28 | 40 | 40 | 40 | 40 | 40 | 40 | 40 |
| powers | 0 | 28 | 40 | 40 | 40 | 40 | 40 | 40 | 40 | 40 |
| roots | 0 | 0 | 28 | 41 | 41 | 40 | 40 | 40 | 39 | 40 |
| percentages | 0 | 0 | 28 | 40 | 40 | 40 | 40 | 40 | 40 | 40 |
| integrals | 0 | 28 | 40 | 40 | 39 | 40 | 40 | 40 | 40 | 40 |

- **40 % from the second tier with families on**, as the spec asks. At a family's first tier
  the game serves **28 %**: its own 7 questions in 10 carry 40 %, its 3 reviews come from the tier
  below, where no family exists yet ("review questions follow the same mix for the tier below").
- **The level targets still hold**: v4 keeps v3's update (`LevelRules.of(v4)` is v3's), so the
  stall (63.8–65.3 %), the slow game (+1.56), the full caps and the −3 floor are unchanged. The
  simulation models players by accuracy, not by question: whether pattern questions are easier
  or harder for real players is Phase 3b's to measure.

## Levels close-out — rules v3, the level update tuned (plan v3.2, 23 Nov 2026)

The plan set four targets and opened three constants — the slow credit, the dead band and the
down cap — to reach them; the spans (25 / 35 points) and the up caps (+3 / +3 / +4 / +5) stay.
Chosen: **the plan's starting point, unchanged: slow 0.85, dead band 0.62–0.72, down cap 3.**
They are **rules v3** (`LevelRules.v3`, `RulesVersion.v3`): v3 games are stored as v3, v2 games
are replayed under v2 (`LevelRules.of`), v3's questions are v2's, levels carry over (no reset).

Measured exactly (`tool/levels_simulation.dart`: every outcome of a game weighted by its
multinomial probability through the real `levelChangeHundredths`, the stall found by bisection;
tests pin the numbers):

| Target | v2 | v3 |
|---|---|---|
| Stall (expected change 0), fluent players, n = 4 / 5 / 10 / 20 — 60–70 % | 53.2 / 54.6 / 54.4 / 55.6 % | **65.3 / 63.8 / 64.0 / 64.2 %** |
| 4 questions all correct but slow — at least +1.5 | +1.20 | **+1.56** |
| Perfect game — the full cap | +3 / +3 / +4 / +5 | **+3 / +3 / +4 / +5** |
| Worst game — never below −3 | −2 | **−3** |

Median games of 10 questions from level 0 to each tier (1001 seeded players, accuracy the same
at every tier, each tier's fluent time):

| v3 | T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 |
|---|---|---|---|---|---|---|---|---|---|
| perfect | 3 | 5 | 8 | 10 | 13 | 15 | 18 | 20 | 23 |
| perfect, all slow | 5 | 10 | 15 | 20 | 25 | 29 | 34 | 39 | 44 |
| 80 % right, fluent | 7 | 13 | 20 | 26 | 33 | 39 | 46 | 52 | 59 |
| 70 % right, fluent | 17 | 36 | 55 | 74 | 92 | 112 | 130 | 150 | 169 |
| 60 % right, fluent | 406 | — | — | — | — | — | — | — | — |

(— : not within 500 games. v2 for comparison: perfect identical; all slow 7 / 13 / 19 …; 80 %
5 / 9 / 13 …; 70 % 8 / 16 / 24 …; 60 % 22 / 45 / 71 ….)

Why the starting point, among the 44 candidates of the grid that meet every target (slow
0.80 / 0.85 / 0.90, band edges by 2 points, down cap 2 or 3 — `--grid`): its stall sits 3.8 to
5.3 points inside both bounds at every game length, so the target survives Phase 3b's noise;
the best-centred candidate (0.64–0.72) only moves it to 65.0 % with a narrower band, which
makes a level at the player's skill jitter more; slow credit 0.85 is the smallest that gives
4 slow answers +1.5 with this band's upper edge. Down cap 3 is what centres it: with 2 and the
same band, the stall drops to 60.4–62.7 %, at the lower bound's edge.

Consequences, reported:
- **Speed still matters at the stall**: a player half fluent stalls at ~70 % right, an all-slow
  one at ~76 % (credit 0.85 per right answer). Principle 2 holds — a slow-but-right player
  climbs, faster than under v2 (T5 in 25 games, was 32).
- **The 80 % player climbs slower than under v2** (T5 in 33 games, was 22): the band's top
  moved from 0.65 to 0.72, so 8 of 10 earns less. The perfect player's pace is unchanged.
- **A bad game costs up to 3** (was 2): the spec's principle 4 ("at most 2") is superseded by
  the plan's target.

**Mechanics**: credits are now in percent of a fluent answer (100, 85 or 75, 0) — v2's quarters
times 25, so every v2 result is identical; the update stays integer-only (rule 18). The
server lists `rules: [2, 3]` in `/health`; the app holds a v3 game, pending, until the server
it talks to lists 3 (commit 4.1's guard) — nothing is lost while production lags.
**Reopen when** Phase 3b's data shows where real players stall.

## Redesign phase — owner decisions (plan v2.9, 22 Nov 2026)

Decided by the owner in the plan; recorded here with their reason so they are not re-argued.
Reference screens: `doc/mockups/redesign.html` (layout and content binding).

- **Two families, a main level.** Basics (+ − × ÷) and Advanced (powers, roots, percentages,
  integrals). The main level is the mean of the four basics only, an unplayed one counting as
  1; it is the Home badge and the main board. Each advanced operation keeps its own level and
  board and never counts in the main level. Why: the old overall level mixed seven operations a
  player may never have chosen, so it measured selection as much as skill.
- **30 s per question** (was 15). A timeout still counts as wrong; three silent timeouts in a
  row still end the game. The validate key stays; no auto-validation, no Skip.
- **Questions per operation are chosen**: 4, 5, 10 or 20 (default 10, remembered). Every
  selected operation gets exactly that many, so each reaches `n_min` (4) and its level moves;
  the order is shuffled by the seed and stored with the session (its type sequence). Replaces
  the derived count (below) and the debt rotation for these games.
- **Training mode**: Easy / Medium / Hard at a fixed difficulty; never moves a level, never
  ranked, its own session kind. *Levelling* is the game as before.
- **Integrals** join the advanced family, with the whole chain of a type.
- **Two solo challenges**, Get the count and Chain operations: no level, not ranked, not
  uploaded for now; seeded and in the pure core so Phase 7 can replay them on the server.
- **Minimal text**: labels only, no explanatory captions, hints or helper sentences.
- **The beta-safety rule is lifted for this phase.** The app version stored with every session
  separates the data; the Phase 3b calibration window starts after the Redesign phase ships.
  The Phase 5 pins (`session_layout_pin_test.dart`) are re-measured on the new game screen
  (commit 6) and frozen again from then on.
- **Accessibility**: touch targets ≥ 48 dp, text contrast ≥ 4.5:1 in both themes, layouts hold
  at large text sizes, reduced motion respected everywhere (the Phase 5 exception for the
  answer feedback ends).

**Supersedes**: "The number of questions is derived, not chosen", "Overall level: unplayed
types count as 1" (now over the four basics), "Difficulty is not a user setting" (still true of
levels; Training picks a fixed difficulty that never touches them), the 15 s of "Per-question
timeout", and the reduced-motion scope of "Streak escalation and level-up within the
beta-safety rule".

### Gaps filled by Claude Code — confirmed by the owner (plan v3.0)

- **Contrast**: the palette's muted text (dark `#5A6B8C`: 3.4:1 on the background, 2.9:1 on a
  surface; light `#7A8AA6`: 3.2:1) and the light theme's error red (`#E24B4A`: 3.6:1) fail the
  4.5:1 rule. Nearest tones that pass on both background and surface: muted dark `#7F90B2`
  (5.6 / 4.8), muted light `#5E6E8C` (4.8 / 5.1), error light `#BF3433` (5.2), error dark
  `#F06968` (5.1 on a surface). Applied in commit 6; `doc/design.md` updated.
- **Bottom bar label "Ranks"**, as in the mockups (the plan's text says Leaderboard): the
  mockups' content is binding and the shorter word fits four tabs at large text sizes.
- **Day/night toggle moves to Profile**: the mockups' Home has the level badge in that corner.
- **A never-played operation shows level 1** on Home, as the mockups' ∫ does (the kit used to
  show a dash): it is the level that counts in the main level.
- **Training's levels** are the plan's proposal, 15 / 40 / 70 for every operation
  (`TrainingDifficulty`). Training games are **uploaded and validated** like games (replayed
  at their frozen levels; the server checks they are one difficulty for every operation) and
  never touch a level or a board; they count as activity (the 30-day window) and as a
  completed session (a later full placement is refused, as after any game). Why upload: the
  owner's data stays whole, and the replay costs nothing. The default mode is **Levelling**,
  the game as it was.
- **Integrals' difficulty** (uncalibrated, like every type): the antiderivative's degree 2 → up
  to 4, its leading coefficient 1 → 4, its other coefficients 0 → 3, the lower bound 0 → 3,
  the width 1–3 → 1–4, from level 1 to 100 (`IntegralDifficulty`). Level 1 is `∫₀ᵇ 2x dx`,
  b ≤ 3; the largest answers stay under 7 typed digits. Their type placement uses the same
  pass time as every type (3 s, the level update's own speed scale). Structural features:
  the bounds, like a power's base. Phase 3b calibrates all of it.
- **After a game, back to Home** (not the setup page): the levels that moved are on Home; Play
  again on the result screen keeps the same setup. One selection set is stored for both rows;
  each row reads its family from it.
- **Chain operations, the gaps**: start 2–20; operands 1–9 for + and −, 2–9 for × and ÷;
  values stay in **[1, 999]** (never 0 either: it would make × and ÷ trivial); at each step the
  operator is drawn among those that keep the value valid, then its operand among the valid
  ones (no rejection). A 250 ms blank between screens. Setup defaults 2 s and 10 operations,
  ~~kept for the app's lifetime, not stored~~ — remembered since the close-out (below). The best time runs from the keypad's appearance to
  the answer. A round quit before the answer is not counted.
- **Get the count, the gaps**:
  - *Why a target always exists* (with B the largest big and the smalls' running sums, each
    step at most 9): B = 25 — the smalls (at least five, two of each value at most) sum to at
    least 9, so some running sum lies in [5, 13] and 25 × it is in [125, 325]; B = 50 — at
    least 3 smalls summing to ≥ 4, a running sum lands in [3, 11], 50 × it in [150, 550];
    B = 75 — a running sum in [2, 10], 75 × it in [150, 750]; B = 100 — any small in [2, 9]
    gives 100 × s in [200, 900], and there is one (at most two 1s among three or more smalls).
    The generator throws if the set is ever empty; 2000 seeds are checked on the VM.
  - The target is drawn uniformly among every value in [101, 999] the six numbers can make.
  - The solver is a dynamic programme over the 63 subsets (a subset of k numbers needs k − 1
    operations): the smallest subset reaching the target is the shortest solution. ~10 ms a
    puzzle on the VM, computed once with the puzzle at the start of a round. Intermediate
    values are not capped.
  - Results must be positive: 0 is refused (useless, and a division by zero).
  - A result takes the second tile's place; the first fades where it was (the mockup shows six
    places). The closest value counts every value that was on the board, undone moves left out.
  - A forbidden move drops the operator and keeps the first tile. Undo and reset are inert
    until a move is made. A round quit before its end is not counted; time up counts as a
    game, not solved.
  - The stats show on Profile ("Challenges": games, solved, best) — the mockups show no place
    for them, and Profile already holds the player's numbers.
- **Phase 3b's count starts at the release**: `owner_dashboard.calibration_window` (one row)
  is set to the moment the Redesign phase's dashboard migration first reaches the project —
  CI applies it with the release — and the progress view counts completed games from then.
  The owner can move it with one `update`. Training never counts; it has its own column in
  the players' activity (it used to fall under "placements": every kind but `game`).
- **The smoke test finds Home's Play by its accessible label** ("Play Basics"): "Play" alone
  is also the screen's title and a tab. Screen readers gain the same precision.
- **Correction pause without words**: the wrong answer is shown struck through under the right
  one, a timeout as an hourglass icon, instead of "Your answer: 54" / "Time's up".

### Redesign outcome — owner decisions (plan v3.0, 22 Nov 2026)

Every provisional choice above is **kept** (palette, wordless correction pause, level 1 for a
never-played operation, integrals' start, Chain and Get-the-count details, the Phase 3b window,
"Ranks", the theme switch in Profile), except three, changed by the owner and done in the
close-out commit:

- **Training never counts toward leaderboard eligibility** (the "3 completed games"); only
  Levelling games do. Training still counts as activity (the 30-day window). It was already so
  on the server — the main board counts `kind = 'game'` sessions and a board's own count is
  `sessions_played`, which Training never moves — and is now pinned by a SQL test.
- **Chain operations' setup is remembered** (`ChainSetupStore`), like the setup page's.
- **Every result screen offers Play again and Home** — a placement's too, which used to offer
  only "Play" (to Home).

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

## Leveling parameters — starting values — superseded

**Superseded** by the Levels phase (`doc/levels.md`, rules v2 on). *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded by the Levels phase (`doc/levels.md`), above.*

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

## One difficulty axis at a time — superseded

**Superseded** by tiers (`doc/levels.md` section 5): the tier decides the content. *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded by the Levels phase (`doc/levels.md`), above.*

Difficulty derives from the level through operand size. **Do not vary operand size and allotted
time together**: the effects would compound into a brutal curve mid-scale, hard to diagnose. (The
plan's timeout derived from the level, Phase 3, is a separate measured change.)

Consequence on rule 2: the sequence is not reproducible from the seed alone, since bounds depend on
the level. The level enters the config explicitly, is **frozen at the start of the session** and
never recomputed during it — otherwise the server cannot revalidate and duels fail.

700 steps (7 operations × 100) are not calibrated by hand: one continuous `level → bounds` function
per operation, five anchor points checked by hand (1, 25, 50, 75, 100), and two tests —
monotonicity and no brutal jump between consecutive levels.

## Per-question timeout: 15 s, counted as wrong — superseded

**Superseded**: 30 s since the Redesign (plan v2.9, schema migration `…_thirty_second_questions`). *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded in part or whole by the Redesign phase (plan v2.9), above.*

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

## The level step is weighted by answer volume — superseded

**Superseded** by `doc/levels.md` section 3 (caps by questions per operation, rules v2 on). *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded by the Levels phase (`doc/levels.md`), above.*

The formula used a pure mean: 16 additions at 85 % and 4 additions at 85 % moved the level
exactly the same. Counter-intuitive (focusing on one operation should make it progress faster) and
a perverse incentive (enable many types, play minimal sessions).

Fix: the step is multiplied by `√(n / n_min)`. The square root rather than the ratio, so that 64
answers do not move 16 times more than 4 — which would make the system unstable. It is an Elo-like
variable K applied to sample size. Side effect: small-session noise is damped, and four short
sessions give about the same result as a long one.

## `n_min` from 8 to 4 — coupled to `δ` — superseded

**Superseded** by `doc/levels.md` section 3 (rules v2 on). *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded by the Levels phase (`doc/levels.md`), above.*

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

## Placement test (Phase 1, commit 6) — superseded

**Superseded**: no placement since the Levels phase (plan v3.1, everyone starts at 0); placement
sessions are history only. *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded by the Levels phase (`doc/levels.md`), above.*

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
  them, since games score speed against the same flat `t_rapide`. **Kept by the owner** (plan
  v2.3, Phase 2 outcome) until Phase 3b gives each operation its own `t_rapide`.
- **Offer**: on Play, to a player with **no completed session** (an interrupted session or
  placement does not count — it is offered again) who has not skipped it. A skip is remembered
  per player (`PlacementSkipStore`, `shared_preferences`); Profile keeps a "Find my level"
  entry until the player completes a session. Play draws nothing until its local read resolves,
  so the type selection no longer flashes before the offer.

## The number of questions is derived, not chosen

*Superseded in part or whole by the Redesign phase (plan v2.9), above.*

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

## Overall level: unplayed types count as 1 — superseded

**Superseded**: the main level is the mean of the four basics, an unplayed one at 0 (Levels
phase, schema v9); shown as its whole part everywhere (Phase 6b commit 7). *(Status marked at Phase 6b commit 8, review m19.)*

*Superseded in part or whole by the Redesign phase (plan v2.9), above.*

*Superseded by the Levels phase (`doc/levels.md`), above.*

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

*Superseded in part or whole by the Redesign phase (plan v2.9), above.*

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
**Owner decision (plan v2.3, Phase 2 outcome)**: refusing and adopting the server's levels is
kept for the beta; Phase 3a commit 2 fetches the server's levels before each game, so a second
device stops losing games. **Confirmed by the owner (19 Nov 2026, after Phase 3a)**: the rejection reasons and flags listed in
`doc/online.md`, and the timing-flag thresholds (300 ms, 40 ms spread) — still guesses until
Phase 3b data.
**Reopen when** multi-device play matters (Phase 7): sync levels down at sign-in instead.

## Leaderboard read path and eligibility (Phase 2, commit 7)

The board is read from Supabase directly, through two `security definer` SQL functions that
expose rank, name and level only; nothing about other players' sessions, answers or ids leaves
the database. Through the Dart server instead: one more hop, and a free host's cold start would
put a minute's spinner on the Leaderboard tab. Ranks are computed on each read (window
functions over at most a few thousand rows during the beta) rather than stored: nothing to keep
in sync, and "within 30 days" moves with the clock by itself.
**Owner decision (plan v2.3, Phase 2 outcome)**: eligibility = active within 30 days and ≥ 3
counted sessions on the operation (overall: ≥ 3 completed games), kept — 3 matches the calibration boost's
length, after which a level means something; "Top N %" rounds up (the best player is "Top 1 %"
of a 100-player board, never "Top 0 %").
**Reopen when** the beta shows boards too empty (lower the bar) or noisy (raise it).

## Player names: a charset the font draws, a short blocklist, reports (Phase 2, commit 9) — extended

**Extended** by Phase 6a (unique names by fold, reports by saved accounts only, `profiles` private);
the alphabets (Latin, Greek, Cyrillic) **confirmed** by the owner (plan v4.0). *(Status marked at Phase 6b commit 8, review m19.)*

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
**Owner decision (plan v2.3, Phase 2 outcome)**: the allowed set (Latin, Greek, Cyrillic), the
short English/French blocklist and hiding a name after 3 reports are kept for the beta; wider
alphabets (a bigger bundled font) are reconsidered before Phase 6.
**Reopen when** the beta shows abuse the list misses, or players whose names are refused.

## Stale guests: activity = uploads or a renewed session (Phase 2, commit 11)

The plan: delete anonymous players with no uploaded session for 30 days. Taken literally, before
the server is deployed (no uploads at all) that deletes every guest older than 30 days,
including ones who play every day — their progress would vanish behind a new guest. So a guest
counts as active if it uploaded **or** renewed a sign-in session (`auth.sessions`, renewed by
the app whenever it is open) in the last 30 days. Device side, a guest left for another account
keeps its hidden games 30 days (owner's Phase 1 decision: "deleted with the guest account").
**Owner decision (plan v2.3, Phase 2 outcome)**: the extra activity signal is kept. The 03:17
UTC daily schedule: **Confirmed by the owner (19 Nov 2026, after Phase 3a)**.

## Android: compile-only, weekly, outside the push pipeline (Phase 2, commit 12)

Plan v2.2 §5 settles the Phase 0 question: a scheduled job compiles the APK once a week and on
demand, not on every push. A separate workflow (`android.yml`) rather than a job in `ci.yml`:
its failure never cancels or blocks a preview deployment, and a push never waits for Gradle.
It also runs when its own file changes, so a change to it is checked at once.

## Server host: Render free (Phase 2, commit 4) — decided by the owner (plan v2.3)

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

**Owner decision (plan v2.3)**: Render free plan, from `render.yaml` and `server/Dockerfile`.
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

## Cross-platform determinism: pinned references, VM and JavaScript (Phase 1, commit 1) — principle kept, files replaced

**The principle holds; the files changed**: `test/determinism/` and `LevelUpdater` are gone with the
Levels phase. Today's pins are the tier references (`test/tiers/tier_references*.dart`, one per
rules version that changed generation), the duel pins (`duel_config_test.dart`) and the Method
pins, all run on the VM and JavaScript. *(Status marked at Phase 6b commit 8, review m19.)*

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

## Useless RNG draw in `CompositeExerciseGenerator` — obsolete

**Obsolete**: the class went with tiered generation (Levels phase). *(Status marked at Phase 6b commit 8, review m19.)*

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

## Preview host: Cloudflare Pages (Phase 3a, commit 1) — decided by the owner (plan v2.4)

GitHub Pages sends gzip only. Measured on the live preview (19 Nov 2026, fresh browser, every
file the app loads before its first question, re-compressed locally):

| | Bytes on the wire | Transfer on slow 4G (1.6 Mbit/s) |
|---|---|---|
| GitHub Pages today (gzip) | 3,945 KB | 19.7 s |
| Same files, brotli (quality 11) | 3,024 KB | 15.1 s |

Brotli saves ~920 KB, **~4.6 s on slow 4G** (canvaskit.wasm alone: 2,046 → 1,515 KB; main.dart.js
884 → 670 KB; Inter.ttf 451 → 356 KB; sqlite3.wasm 351 → 307 KB). The first question measured
26.5 s on slow 4G (Phase 2); expected ~22 s after the move, to be re-measured there.

| Host (free plan) | Brotli, checked on live sites | Limits | Trade-off |
|---|---|---|---|
| **Cloudflare Pages** — recommended | `.wasm` served `br` on a Flutter site behind Cloudflare (wonderous.app) | unlimited bandwidth and requests; 25 MiB per file (canvaskit.wasm 5.3 MB) | deploy from CI with an API token; `<project>.pages.dev` |
| Netlify | `main.dart.js` served `br` on two Flutter sites; `.wasm` not confirmed (forum reports say it is not compressed) | credit-based free plan; bandwidth counts | same CI flow |
| Firebase Hosting | brotli announced (2020) | small daily transfer quota on the free plan | a Google Cloud project |
| GitHub Pages (today) | gzip only | — | nothing to change |

Prepared, dormant: `ci.yml` builds for the root path, deploys with `wrangler pages deploy` and
smoke-tests the new address only when the repository variable `PREVIEW_HOST` is `cloudflare`;
GitHub Pages then serves a redirect page (`tool/preview_redirect/`). Browser storage belongs to
an origin: a guest's progress at the old address does not follow (a linked player signs in again),
which is why the plan wants the move **before any tester**.
**Reopen when** a custom domain arrives (Phase 6): the preview then moves once more, onto it.

## Beta gate: a code per device, enforced by the app (Phase 3a, commit 3) — extended

**Extended** by the server-side gate (Phase 5.1 commit 5); both go at the public launch (Phase 6c). *(Status marked at Phase 6b commit 8, review m19.)*

The plan: an invitation code asked once, before the anonymous sign-in; codes in a table with a
use limit, so each tester's data can be followed. The code is checked before the guest exists
(`beta_code_status`, callable without a session), then tied to the guest right after its
creation (`redeem_beta_code`). The device keeps the accepted code: "asked once" holds even
after a sign-out of an email account. An existing account signs in without a code.
**Confirmed by the owner (19 Nov 2026, after Phase 3a)**: the gate lives in the app only — the Supabase API still
lets anyone create an anonymous user. Server-side enforcement (refusing uploads, hiding from the
board without a code) would also lock out the owner's pre-beta account and needs a migration of
existing players; for 10–20 invited testers, a "no code" bucket in the dashboard is enough.
Codes are stored readable (not hashed): only the owner reads the table, and the dashboard shows
which code is whose. A build switch (`BETA_GATE`) rather than always on: the preview stays
open while the beta is prepared, and the smoke test needs its own code first.
**Reopen when** the public launch removes the gate (Phase 6), or someone gets in uninvited.

## Owner dashboard: SQL views and a local script (Phase 3a, commit 6)

The plan: "SQL views plus a script printing a report". The views live in a schema of their own
that the API does not serve and the API roles cannot use, so no RLS policy can leak them. The
script runs on the owner's machine with `psql` and the session-pooler connection string: a CI job
(scheduled report) was the alternative, rejected because the repository is public and so are its
job logs and annotations — the report holds testers' names and feedback. Review actions go
through one function (`review_name`) instead of hand-written SQL, so the "never run SQL by hand"
rule keeps its meaning for schema changes; the report still prints the SQL equivalent, as the
plan asks. Answer times use games only and the level the session froze for that operation;
placement answers move along a staircase within one session, so their level would mislead.
**Reopen when** Phase 3b needs a view the report lacks, or the owner wants it in a browser.

## Type placement: the first game on a never-played operation (Phase 3a, commit 7) — superseded

**Superseded**: no placement since the Levels phase (plan v3.1). *(Status marked at Phase 6b commit 8, review m19.)*

Plan: "First game on a never-played type acts as a short placement for that type" — from level
1, powers, roots and percentages take ~65 games to settle. Starting a game whose selection holds
operations with no level yet plays, instead, the placement test's staircase on **those
operations only**: rules version 3 (`typePlacementRules`: start 35, first step 25 levels,
5 questions per operation, pass time 1.5 × `t_rapide`), stored as `typePlacementV3` with its
operations (`enabledTypes`) and rotation (`typeSequence`). The next Start plays the whole
selection as a game. An interrupted one sets nothing and comes back, like the placement test.
Evidence: `tool/placement_check.dart`'s player model has one response curve for every operation,
so its Phase 1 result for 5 questions per staircase (placed error 4.8 / 6.9 levels, ±3 within
5.6 / 20.0 games instead of 65.5 / 73.5) applies to each operation alike.
Server: accepted only for operations the server has no level for (`typeAlreadyPlayed`
otherwise), from the start level, replayed from the stored rotation; allowed after games.
**Confirmed by the owner (19 Nov 2026, after Phase 3a)**:
- every never-played operation is placed this way, the four basic ones included — a player
  who skipped the placement test meets it in short form on their first Start;
- the already-played operations of the selection sit out that first game (a session mixing a
  staircase and a game would need a third kind of replay for one game);
- the same staircase constants as the placement test for powers, roots and percentages, whose
  levels have not been calibrated either (Phase 3b).
**Reopen when** Phase 3b's data shows where type-placed players actually settle.

## Data check: what Phase 3b needs is stored (Phase 3a, commit 8, then owner decision)

Every requirement the plan names — operation, level, time, correctness, structure of the
exercise — is in each uploaded answer (`owner_dashboard.data_check`, and a format test on the
app side). Three things that would matter to calibration were not stored anywhere:
- **Input device** (on-screen keypad or physical keyboard): desktop typing is faster, so
  `t_rapide` per operation would mix both. Recommended before the invitations go out, since
  answers already recorded cannot get it back.
- **App version per session**: to set aside games of a buggy build. Recommended with it.
- **The timeout in force**: constant (15 s) today; must be stored once Phase 3b makes it
  depend on the level — part of that change, not needed before.

**Owner decision (19 Nov 2026): record the first two, before the invitations.** Built as:
- **Input device per answer**, not per session: times are per answer, and a player can switch
  mid-game (a laptop with a touch screen). `InputDevice` (`keypad`, `keyboard`, `mixed`: both
  within one answer), from every key of the question — digits, Backspace, submit. `null` only
  for a timeout with no key pressed. Stored names, never renamed.
- **App version per session**: `APP_VERSION` (the commit's first 7 characters from CI, `dev`
  locally), as feedback already had.
- Both **optional in the upload, same `formatVersion`**: sessions recorded before (local schema
  v8 leaves them `null`) still upload; an older server ignores the fields. The server keeps the
  validated payload, so no new column: the dashboard reads them from it
  (`answer_times_by_input`, `app_versions`, two more `data_check` rows).
**Reopen when** Phase 3b stores the timeout with the session.

## Digit typeface: Space Grotesk, cut to digits (Phase 5, commit 1) — confirmed (plan v2.6)

The plan's four candidates (section 6.2), each from google/fonts (SIL OFL, no Reserved Font
Name, licences in `app/assets/fonts/licences/`), cut by `tool/fonts/subset_digits.py` to a static
weight-500 instance of digits, operators and "of":

| Face | Tabular at play size | Glyphs | Subset, brotli |
|---|---|---|---|
| Space Grotesk | yes (`tnum`; 111111 = 888888 = 119.0 px at 32 sp) | all | 2.7 KB |
| Sora | yes (`tnum`) | **no √** (falls back to Inter) | 2.6 KB |
| Manrope | yes (`tnum`) | all | 2.4 KB |
| JetBrains Mono | yes (monospaced) | all | 2.0 KB |

All four pass the size and licence criteria; the choice is on legibility at speed, judged on
close-ups at play size (48 sp, weight 500, both themes; the specimen goldens record them):
- **Space Grotesk**: the 1 carries a long flag, unmistakable for a 7; the 3's flat top keeps it
  apart from 8; 6 and 9 are open, never read as 0 or 8. Proportional operators keep "24 × 7"
  compact. The most character of the four — the plan's "recognisable at a glance".
- JetBrains Mono: the least ambiguous (based 1, dotted 0), but monospaced operators open wide
  gaps ("24  ×  7") and it reads as a code editor.
- Manrope: its 1 is a plain stroke, closer to 7 at speed; lighter at 500.
- Sora: no √ — a root prompt would mix two faces.

**Provisional (owner confirms on the specimen, `?specimen` on the preview).** Used by the three
digit styles (operation, typed answer, keypad) and, from commit 2, the kit's numbers; Inter stays
for interface text and draws every letter but "of". First load: +2.7 KB (budget +50 KB).
Line boxes stay Material 3's (`height` per style), so no session position moves; two exceptions
found by the pins and fixed rather than re-measured: a prompt in two faces grows 1 px (hence "of"
in the subset), and the power prompt's raised exponent depends on the face's metrics (its line is
fixed at the 57 px it measured in Inter).
**Reopen when** the owner picks another candidate (regenerate with the script, change
`digitFontFamily`), or a public name brings a brand face (Phase 6).

## The kit wraps Material, styled by tokens (Phase 5, commit 2)

`AppButton` and `TypeChip` are built on `FilledButton`, `TextButton` and `FilterChip`, not drawn
from scratch: focus rings, keyboard activation, disabled handling and semantics come for free and
stay consistent with dialogs and text fields. Identity comes from the tokens (accent, radius 16
shared with the keypad, control height, the digit face for numbers); screens never use the
Material widgets directly in those roles. A busy primary button keeps the accent (the player's
own action is running); only a truly disabled one greys out. Delete stays a secondary in the
error colour: an irreversible action is never the filled button. The leaderboard's own row keeps
its weight-700 emphasis, outside the kit (noted, not changed).
**Reopen when** a component needs a behaviour Material cannot give (a duel's live state, Phase 7).

## Operator icons: one painter, the app icon from the same family (Phase 5, commit 3)

Drawn in code (`CustomPainter`) rather than as an icon font or SVG files: no new dependency, no
asset to load, crisp at any size, colour from the theme — and the app icon is rendered by the
same painter, so the family cannot drift. The app icon is + − × ÷ in a grid (the game's four
basic operations, recognisable at 16 px), not the whole family: seven glyphs do not read at
favicon size. Maskable icons keep the grid inside the 80 % safe circle; the Apple touch icon is
full bleed (iOS rounds it). On a selected chip the check mark moves before the label so the
operator stays visible (a selected chip still has a non-colour signal, rule 14).
**Reopen when** the app gets its real name (Phase 6): the app icon may become a mark.

## Sound: synthesised in the browser, on by default (Phase 5, commit 4) — confirmed (plan v2.6)

The plan asks for self-made or CC0 sounds with their licence recorded. The sounds are
**synthesised** with the Web Audio API (oscillators and gain envelopes, a few nodes per sound):
self-made by construction, nothing to license, **zero bytes to download** (the first-load
budget), and the chime's pitch follows the streak exactly. Through `dart:js_interop` behind a
conditional import, like `persistent_storage` — no new dependency. Elsewhere `createGameSound()`
is silence; **mobile replacement (Phase 8)**: an audio package behind the same `GameSound`.
- Unlock: the `AudioContext` is created on the first `pointerdown`/`keydown` (capture phase,
  before Flutter handles it); sounds before that are skipped, never queued.
- Hidden page: the context is suspended, nothing is scheduled.
- Mix for twenty questions in a row: peaks of 0.03 (tick) to 0.1 (chime), 5 ms attacks (no
  click), exponential decays of 18–200 ms; a pentatonic climb so no streak step clashes.
- The key tick plays for the on-screen keypad only.
- Checked in a real browser: the smoke test counts the tones a game schedules (11 for its
  10 answers) and fails at zero.
**Provisional (owner confirms on a phone)**: sound **on by default** (plan section 8), the
sounds themselves, their loudness.
**Reopen when** the owner finds them tiring or too quiet, or Phase 8 brings native audio.

## Haptics: the browser's vibration API, a switch that says when it cannot (Phase 5, commit 5)

`GameHaptics` (key, success, warning) behind the player's switch, on by default. Web:
`navigator.vibrate` directly (`dart:js_interop`), for patterns Flutter's `HapticFeedback` cannot
express on the web — a warning is two pulses, a success one. Feature-detected: Safari on iPhone
has no vibration, so `supported` is false, nothing is called, and Profile shows the switch
disabled with "This browser cannot vibrate" (a disabled state explains why). Outside the browser
(Phase 8) Flutter's `HapticFeedback` (selection click, light, heavy) behind the same interface.
Replaces the pre-Phase-5 haptics (a light tap on every answer, a heavy one added on a mistake):
the key tap is new, for the on-screen keypad only, like the sound.
**Reopen when** the owner finds the pulses too strong or too weak on a phone.

## Streak escalation and level-up within the beta-safety rule (Phase 5, commit 6)

The plan asks the streak counter and the timer bar to "intensify" at 5, 10, 20 — colour step and
a short pulse, never a delay. The bar's height stays 4 px (a thicker bar would push the question
down: the pins would fail); the pulse is a `ScaleTransition` on the streak line, which moves
nothing in layout; colours are derived from the theme (no new palette entry). Level-up: the
existing 600 ms count-up, a "▲ Level up" mark in words (rule 14) and the sound, once per result,
also after the level updates arrive late.
**Reduced motion, scoped**: no pulse, an instant count-up. The answer feedback (flash, shake,
scale) and the 150 ms question fade are **not** changed under reduced motion during the beta —
they shape how players answer, and the beta-safety rule freezes them. To revisit after the beta.
Found on the way: the result screen's two buttons overflowed with a wide text (a large system
text size); they are a `Wrap` now and stack instead.
**Reopen when** the beta ends (reduced motion for the answer feedback), or the owner finds the
escalation too strong.

## Home screen: the manifest, Safari's own tags, and the browser's verdict (Phase 5, commit 7)

`web/manifest.json`: a stable `id`, `scope` and `start_url` of `./` (the preview serves from the
root; relative stays right if a domain changes it in Phase 6), standalone, portrait, dark
Background as splash and theme colour (it matches the loading screen), icons `any` and
`maskable` at 192 and 512. Safari on iPhone ignores most of it: `index.html` carries the 180 px
`apple-touch-icon` (full bleed, iOS rounds it) and `apple-mobile-web-app-capable` for a
full-screen launch; `theme-color` per system theme so the browser bar matches day or night.
Checked by `test/web_manifest_test.dart` (every icon at its declared size) and, on the live
preview at every push, by the smoke test asking Chrome itself (`Page.getInstallabilityErrors`:
none). The owner adds it to a home screen on both phones at the end of the phase.
**Reopen when** the domain and the name arrive (Phase 6): `name`, `short_name`, icons.

## First load: pre-compressed files on Cloudflare (Phase 5.1, commit 1)

Measured on the live preview (20 Nov): Cloudflare compresses on the fly at a lower brotli
quality than the files allow — `canvaskit.wasm` 2,011 KB served vs 1,514 KB at quality 11,
`main.dart.js` 901 vs 687, `Inter.ttf` 437 vs 356, `sqlite3.wasm` 355 vs 307: about 840 KB,
four seconds on slow 4G (200 KB/s), on a load that is bandwidth-bound (the files arrive one
after another at full link speed; nothing waits on a round trip until the engine starts).
Cloudflare Pages cannot serve a pre-compressed file by itself, so a Pages Function does it
(`tool/cloudflare/functions/[[path]].js`): for the paths of `_routes.json` only (the big
files; the rest stays plain static), when the browser accepts brotli and the file has a copy
listed in `_precompressed.json`, it answers with the `.br` bytes as they are
(`encodeBody: 'manual'`), the right content type (`application/wasm` for streaming
compilation), the asset's ETag (revalidation still answers 304), `Vary: Accept-Encoding`.
Anything else falls through to the static server unchanged. CI's Cloudflare deploy writes the
copies (`tool/cloudflare/precompress.mjs`, Node's own brotli: no dependency) and deploys from
`tool/cloudflare/` so wrangler finds the Function. Free plan: 100,000 Function calls a day;
a first visit makes about five. **Alternatives**: a Worker in front of Pages (same code, one
more thing to deploy); smaller files (Inter subset: later in this commit if needed).
**Reopen when** Cloudflare Pages serves pre-compressed files natively, or the host changes
(Phase 6).

## First load: sign-in during the download, levels read ahead, Inter cut (Phase 5.1, commit 1)

Where the slow-4G time went (request waterfall, `SMOKE_TRACE=1`): about 17 s of downloads at
full link speed, then — only once the engine runs — the database worker, the anonymous
sign-up (CORS preflight + request, ~0.9 s), the first screen, and at Start the server levels
(~0.9 s). Three changes, none touching question order, timing or input:

- **The page signs in while the files download** (`web/index.html`, `window.mtBootAuth`). A
  stored session that expires within two minutes is refreshed there (returning players: the
  token lives one hour, so nearly every visit); with no session, the anonymous player is
  created there — **only where the app would create it at once**: no beta gate, or a device
  whose code is stored. A new visitor to the gated beta still meets the gate before any player
  exists (the gate's rule, Phase 3a, unchanged). The result goes where supabase_flutter keeps
  its session (`sb-<ref>-auth-token`, the auth API's own JSON); the app waits for the page's
  promise before starting its client (`infrastructure/web/boot_sign_in.dart`, at most 16 s),
  so the two never sign in side by side. Any failure leaves storage untouched and the app
  does what it always did. The settings (Supabase address, publishable key, gate switch) are
  written into `index.html` after the build by `tool/web/boot_config.mjs` from the same
  `dart_defines.json` — it refuses a secret key; a build without them (`flutter run`) simply
  skips the early sign-in. The page also preconnects to Supabase. Checked by the smoke test:
  "signed up" on a fresh visit without a gate, "refreshed" after a reload with a session
  about to expire, same player.
- **Server levels read ahead** (`PrefetchedServerLevels`, math_core): read once the sign-in's
  uploads are settled, used by the next Start instead of a round trip — once, and only if
  nothing waited for upload when it was read and no session was stored since (either would
  change the server's levels). Otherwise Start reads as before.
- **Inter cut to the app's use** (`tool/fonts/instance_inter.py`): optical size pinned at its
  default (14, what Flutter renders without a variation), weight narrowed to 400–500 (the
  design's two weights; the theme caps every style to them). Every character stays — player
  names keep Latin, Greek, Cyrillic and Vietnamese (`name_charset_font_test.dart`): 356 →
  174 KB brotli. Weight-500 advances round a hair differently: 16 goldens moved by under
  0.2 % of their pixels (sub-pixel edges, no reflow); the session screen's goldens and the
  layout pins did not move.

Measured locally, same machine, alternating runs (slow 4G, fresh browser, no gate, local
server at brotli 5 for both): first question 19.0–19.8 s vs 19.8–20.6 s before. The live
preview adds the pre-compression above; its measurement is in `doc/progress.md`.
**Rejected**: creating the guest before the gate (would bypass it: an account on the device
skips the code screen); preloading `sqlite3.wasm` (the link is saturated during the download:
it would only push CanvasKit later). **Reopen when** Turnstile arrives (Phase 6: the page's
sign-up would need the token — skip it then), or supabase_flutter changes its storage key.

## Strategy detector: the plan's table made exact (Phase 5.1, commit 2) — confirmed (plan v2.7)

`math_core/strategies/strategy.dart`: `bestStrategy(exercise)` returns the move of section
6.1's table that fits, with the numbers of its worked line (`CompensationMove(kept: 47,
rounded: 70, adjustment: 2)` for 47 + 68), or `null`. No UI: Phase 4 writes the tip from it.
Each move recomputes the answer through its own steps, and a test checks that over ~100,000
exercises (sums and differences to 300, products to 120 × 120, squares to 130, percentages to
100% of 400): a tip can never teach a wrong line. The table's words left open; my reading,
**provisional**:

- **Compensation** (addition only): an operand ending in 9, 8 or 7 goes to the next ten; when
  both do, the one closer to it; single digits count (47 + 9 = 47 + 10 − 1).
- **Subtract via a round number**: the subtrahend within 3 of a round number but not on it,
  the coarsest such (298 → 300, 1003 → 1000, 47 → 50); 7–9 → 10.
- **Doubling and halving**: 5 (other even) → 10, 25 (other a multiple of 4) → 100, 50 (other
  even) → 100 — only when the result stays whole.
- **Split the factor**: one digit 2–9 × two digits 11–99, not a multiple of ten.
- **Square near a base**: within 5 of 50 or 100, not on it (45–55, 95–105).
- **Difference of squares**: factors evenly around a multiple of ten, 1 to 9 away.
- **Swap the percentage**: p% of n when n is friendly (10, 20, 25, 50, 75) and p is not.
- **Two fit, fewer steps win**: doubling and halving, then difference of squares, then split
  (5 × 46 → 10 × 23; 48 × 52 → 50² − 2²).
- Division and square roots: none (the table has no row for them).

`Strategy` names will be stored once tips are shown: never renamed. **Reopen when** Phase 4
shows tips (wording, thresholds by level) or Phase 3b data shows which moves help.

## Structural features: Dart and SQL, one list of cases (Phase 5.1, commit 3) — confirmed (plan v2.7)

`math_core/difficulty/structural_features.dart`: per exercise, **carries** (columns that carry
in an addition), **borrows** (columns that borrow in a subtraction), **digits 6–9** (among the
operands shown; a power's exponent not counted), **distance from a round number** (the
smallest, among operands of 10 or more, to the nearest multiple of ten; none when all are
single digits). Analysis only: generation never reads them.

The answers live on the server as the upload's JSON, so the dashboard needs the same rules in
SQL (`owner_dashboard.structural_features`, migration `…_structural_features.sql`). Rather than
store the features at upload (the server would need a change, and answers already uploaded
would lack them), the view computes them on read: `owner_dashboard.answer_features` (every
stored answer, games and placements) and `feature_summary` (per operation and value: answers,
% right, median time of the right ones; `dashboard.sh features`). One list of cases holds both
together: the SQL test's cases (`96_structural_features_test.sql`) are read and run against the
Dart code by `structural_features_sql_parity_test.dart` — a rule changed in one place fails
there. **Provisional**: the definitions above (the plan names the features, not their exact
counting). **Reopen when** Phase 3b fits a model on them (a feature may need splitting:
carries into the tens vs the hundreds; distance to 100 vs to 10).

## Server-side gate: who is "already in", and a 403 that is not a refusal (Phase 5.1, commit 5) — confirmed (plan v2.7)

Plan: "an anonymous user without a valid code cannot upload; existing testers unaffected". The
server asks `upload_allowed(player)` (SQL, service role only) before storing an anonymous
player's session: **a redeemed code, or at least one accepted session**. The second clause is
what keeps every existing tester in: players from before the gate (no code), and a device whose
code redemption has not reached the server yet but whose player uploaded before. A guest made
by calling Supabase directly has neither, and never gets a first session in. Linked (email)
accounts are never asked: they came through the app, and linking is a step a script gains
nothing from during the beta.

The answer to a blocked upload is **403 `beta_code_required`, not a refusal**: refusals are
final (the app records them and never resends), while a 403 is "try later" (the app's queue
retries with back-off). A tester whose code redeems late — offline at sign-in; the app redeems
in the background, again at every start — loses nothing: the queued sessions go once the code
lands. Default **on** when `BETA_GATE` is unset (the beta is invite-only until Phase 6, which
sets it to `false`); `/health` reports the switch and the deployed commit (`RENDER_GIT_COMMIT`)
— with the repository private, that is how a deploy is checked from outside.

The migration went out one push before the server (the server asks a function CI must have
created first; uploads in between would only have been retried). **Reopen when** Phase 6
removes the gate, or Turnstile protects the anonymous sign-up itself.

## Staging: a second project, deploys in order, production smoke read-only (Phase 5.2, commit 1) — confirmed (plan v2.8)

The plan asks for a second Supabase project and Render service, staging first, production
untouched by tests. Choices made to get there, **provisional**:

- **Order enforced by CI, not by the hosts.** Both Render services stop deploying on push
  (`autoDeploy: false`); CI calls each service's deploy hook with the exact commit, after that
  environment's migrations, and waits for `/health` to report it. Production's server and site
  go only after the full smoke test passed on staging. A deploy is skipped when neither
  `server/` nor `packages/math_core/` changed since the running commit (a Docker build on the
  free plan takes minutes). A missing hook is a warning — the site keeps deploying while the
  owner sets things up.
- **Production smoke: read-only.** The full visit creates and deletes an account; production
  now gets a visit where the browser itself blocks every request that could write (anything
  but GET/HEAD/OPTIONS leaving the site), stopping at the first screen: it proves the site
  boots, is installable and serves this commit's build (`SMOKE_EXPECT_VERSION`, matched as
  the compiler's string literal). With the gate on, the page attempts no write at all.
  **Reopen at Phase 6**: with the gate off, the page's early sign-up is a write — the
  read-only visit will then see a start error, and must accept it or stop before sign-in.
- **Staging has no beta gate** (app and server): the smoke test plays without a code and no
  code ever has to exist in staging. The gate stays covered by widget and server tests, the
  read-only production visit (the gate screen must show) and the gate probe.
- **The staging site's address is read, not configured**: Cloudflare may suffix the name; CI
  reads it from the API, and the staging server accepts `https://math-trainer-staging*.pages.dev`
  (one DNS label: `originAllowed`), so nobody has to copy it anywhere.
- **Composite actions** (`.github/actions/`): the migrations, the web build and the Cloudflare
  deploy exist once, used by both environments.

**Rejected**: Supabase branching (paid plan); one project with a test schema (tests would
still write `auth.users` in the testers' project). **Reopen when** Phase 6 adds the domain
(production becomes the real site; the preview may become staging).

## Duel configuration: quotas, a bracket's level, one stream (Phase 5.2, commit 2) — superseded

**Superseded** by Phase 7 (plan v3.7): three modes of 8 questions, the tier from the rating (150
points a tier), recorded in "Phase 7: asynchronous duels and friends". *(Status marked at Phase 6b commit 8, review m19.)*

**Superseded at Phase 7 commit 1** (plan v3.7): duels are per mode, a tier per 150 rating
points, two of each of four types ("Phase 7" below). Kept for the record; no duel was stored
under it.

`math_core/duel/duel_config.dart`: `DuelConfig(seed, quotas, bracket)` → `questions()`. Both
players get the same questions; the server can regenerate them (Phase 7 commit 2). Choices,
**provisional** (Phase 7 tunes them on play):

- **Difficulty from the rating alone.** Fifteen brackets of 100 Glicko points (≤ 899, 900–999,
  …, ≥ 2200; a new player's 1500 is bracket 7); a bracket's level is 5 + 5 × bracket (5 to 75;
  bracket 7 → 40), the same for every type. No input takes a player's levels. Two players of
  different ratings: the server picks the bracket (their mean's, Phase 7).
- **Fixed quotas per type.** The standard duel: 12 questions — the four operations twice each,
  percentages twice, one power, one square root. Up to 40 questions.
- **Order: the quotas shuffled by the seed.** The multiset is listed by `ExerciseType.index`
  (never a `Set`'s order), shuffled (Fisher–Yates, `nextInt` only) with `Random(seed)`, and
  the same stream then draws the values through the game's own generators
  (`CompositeExerciseGenerator`, `FixedTypeSequence`): a type at a level is drawn exactly as in
  a game.
- Three sequences are pinned in the test (brackets 0, 7, 14) and run on the VM and in
  JavaScript. Strict JSON (`toJson`/`fromJson`), `==` independent of the quotas' map order.

**Reopen when** Phase 7 measures duels: the level per bracket (players' real levels by
rating), per-type levels if one type is much harder at the same level, the quotas.

## Glicko-2 on the server (Phase 5.2, commit 3) — confirmed (plan v2.8; used by Phase 7)

`server/lib/src/rating/glicko2.dart`: `glicko2Update(player, games, tau)`, steps 1–8 of
Glickman's "Example of the Glicko-2 system" (2013), the volatility by the Illinois algorithm
(ε = 0.000001). In the server, not the core: ratings are computed by the server alone (rule
17), and the maths needs `exp`/`log` and doubles — rule 18 (integers, no `exp`) covers what
must match between the VM and JavaScript, which ratings never need to. No endpoint, no
storage yet (Phase 7). **Provisional**: τ = 0.5 (the example's; Glickman suggests 0.3–1.2), a
new player at 1500 / RD 350 / σ 0.06, and the deviation **capped at 350** after periods
without games (a player away for long is as uncertain as a new one, no more — the paper
leaves it uncapped). Tested: the worked example (r′ 1464.06, RD′ 151.52, σ′ 0.05999, and μ′,
φ′ on the Glicko-2 scale), a period without games (φ′ = √(φ² + σ²), rating and σ unchanged,
the cap), win/loss/draw symmetry, volatility rising on upsets, invalid input throwing.
**Reopen when** Phase 7 chooses the rating period (per day? per N duels?) and the provisional
flag's threshold.

**Settled by plan v3.7** (owner, 25 Nov): τ = 0.5 and the cap of 350 kept; each duel is its
own rating period; provisional for the first 10 rated duels of a mode. Wired in Phase 7
commit 3 (`rateDuel`).

## Rules v5: pattern questions sized by tier, no reviews (`doc/levels.md` v1.4) — confirmed; v6 for √ of powers of 2

Beta report (24 Nov): questions at level 15–20 that felt like level 70. Cause, measured on
2,000 games per operation and level under v4: `patternQuestionV4` took no tier — every family
drew its largest size from its first tier (powers of 2 drew 2⁷–2²⁰ from T1, never 2⁶ or less;
√2²⁰ from T2; 4-digit × 5 and ÷ 2 from T2; ∫₀¹⁹ 2x from T1; 900 000 + 900 000 from T3), and
30 % of each game came from the tier below. The level itself was read correctly (`Tier.of`
on the whole part, frozen per game; checked at every hundredth). Spec v1.4 answers with tier
sizing and no reviews; rules v5 implements it (`patternQuestion(family, tier, r)`,
`patternedContentV5`, `TieredGameGenerator.withReviews: false`); v4's generator is kept
verbatim (`patternQuestionV4`, `availableAtV4`, pinned references unchanged).

Readings of the spec (provisional at the release, **confirmed by the owner on 24 Nov**, who
left each case to Claude's judgement — see "Outcome" below):

- **Hard limit, measure**: the significant digits (trailing zeros dropped) of every number the
  question shows — operands, exponent, percent, bounds — and of its answer.
- **Hard limit, "tier T + 1"**: the limit at T is the larger of the standard questions of T
  and T + 1. Taken strictly (T + 1 only), the spec's own √7 225 at T3 would break it (T4's
  standard roots stop at √900), as would 99 × 11 at T3.
- **T9** has no tier above: the 10-digit keypad and the size table bound it.
- **Size-table families follow the table only**: several entries exceed T + 1 on purpose
  (4-digit × 5 at T6, 6-digit ÷ 2 at T6, 2²⁰ at T9).
- **Size-table bands**: an entry holds from its tier to the next entry's. A band draws above
  the band below and up to its own limit ("N-digit" read as "up to N"); the first band starts
  one step below its limit (2⁵–2⁶ at T1, 2–3-digit ÷ 2 at T2). Powers of 3, 4, 5 at T8: only
  3 grows (3⁷–3⁸); 4 and 5 keep T6's.
- **√ of powers of 2, "mirror … two tiers later"**: the even exponents of the powers-of-2
  band two tiers lower: √64 only at T3–T4, √256 at T5–T6, √1 024 at T7–T8, √4 096–√65 536
  at T9. One question per band until T9 — faithful, but repetitive; widen if testers notice.
- **Examples**: "A → B" is A at the family's first tier and B at T9; any other example at some
  tier from the family's first. Under the hard limit some examples arrive later than their
  family: 352 × 11 from T5, 103² and √10 201 and 111² from T7, 88 × 125 from T8, 236 × 999
  at T9 only.
- **Growth of families outside the table** (my schedule, within the limit): addition and
  subtraction families use the tier's standard operand size (1, 2, 2, 3, 4, 4, 5, 6, 8, 9
  digits); the others step up where the limit allows (e.g. × 11: 2-digit to T4, 100–909 at
  T5–T7, any 3-digit from T8). Squares and roots ending in 5 start at 25 (15² is T1 content).
- **Method**: four addition families were recognised at v4's sizes only (complements to 100
  or 1 000, just below a hundred, units 100–10 000, three terms around 100) — a v5 question
  would have lost its family's Method. Now any size; a v4 round-numbers question whose two
  terms share a larger unit shows it ((2 + 3) × 100 000 instead of (20 + 30) × 10 000), still
  true.
- **Phase 3b window restarted** at the v5 release (migration `20261128000000_rules_v5_window`),
  as at v4: v4's sessions measured oversized questions and reviews.

Pattern share: 40 % from a family's first tier on (v4: 28 % at the first tier, diluted by
reviews). The four level targets are unchanged (v5's update is v3's; simulation rerun).
**Reopen when** Phase 3b measures v5 sessions: per-family accuracy and time by tier.

**Outcome (24 Nov).** Every reading above is kept as built; no code change, no v6:

- Limit measure with the answer, limit = max(T, T + 1), T9 bounded by the table and the
  keypad, table families by the table only, the band reading, the growth schedule, the
  examples arriving later, the window restart: each is the reading that keeps the spec's own
  examples valid and closes the reported bug; the alternatives either reopen big answers at
  low tiers or contradict the table.
- **√ of powers of 2 — kept, with a spec suggestion for the owner.** The strict mirror is the
  only reading the spec's text allows without lower-tier questions, but it gives one question
  per band: at T3–T4 the family is half of the root patterns, so about 1 root question in 5 is
  √64 (√256 at T5–T6, about 1 in 7). Widening it within the spec would only add √4 and √16
  (T0 content). Suggested spec row: "√ of powers of 2 and 4 | T3: √64 to √1 024 · T5: up to
  √65 536".
- **Rules v6 (24 Nov, the owner's go-ahead: "make the changes now").** The suggested row went
  into `doc/levels.md` as v1.5 — edited by Claude at the owner's request — and shipped as
  rules v6: `patternQuestion` = `patternQuestionV5` except √ of powers of 2 (√64, √256,
  √1 024 at T3–T4; √4 096, √16 384, √65 536 from T5). v5 frozen for replay
  (`patternQuestionV5`, `patternedContentV5`; references unchanged). Phase 3b's window **not**
  restarted: v5 was live a few hours and v6 changes one family's draws.


## Phase 4: weak spots and drills (plan v3.5) — confirmed (plan v3.6, v3.8)

**Owner decisions (24 Nov):** Phase 3b is a data check, not a blocker; Phase 4 runs first.
**Confirmed again (plan v3.8, 25 Nov):** Phase 3b stays a data check (decided in v3.5): a
report once the dashboard reaches its threshold, changes only if the data contradicts the
targets.
**Weak-spot questions in Levelling games come only from the player's current tier** in that
operation — the no-lower-tier rule of `doc/levels.md` section 2 stands. Everything below is
Claude's reading, provisional until the phase report.

**Items.** Every item belongs to one operation. Keys are stored strings (sessions, uploads):
never rename a key's parts, `ExerciseType` or `PatternFamily` names.
- **Facts** (`fact:<type>:<numbers>`), the plan's list made exact: addition bonds `a + b ≤ 20`
  and complements `a + b = 100` (a, b ≥ 1), one entry per pair (7 + 8 = 8 + 7); tables
  `a × b`, 1 ≤ a, b ≤ 20, one entry per pair; squares 1²–30², cubes 1³–10³, 2¹–2¹² (one
  entry per exercise: 2² is a square and a power of 2 alike); 10, 20, 25, 50, 75 % of
  multiples of 10 from 10 to 1 000 with a whole answer. **"Their roots and divisions"**:
  √ of the squares and of 2², 2⁴ … 2¹² (√1 024, √4 096), ∛ of the cubes; `(a × b) ÷ b` for the
  tables — ordered (56 ÷ 8 and 56 ÷ 7 are two facts). **Subtraction**, the inverse of the
  bonds, is read in: `s − a` with s ≤ 20 and a difference ≥ 1, and `100 − a` — otherwise
  subtraction's first two tiers would have nothing to track. Not commutative: one entry per
  ordered pair.
- **Skills** (`skill:<family>`): the 49 pattern families. A Method strategy counts as the family
  that teaches it (the Tips page's links): compensation → add just below a round number,
  subtract via a round number → subtract just below a round number, doubling and halving,
  difference of squares, square near a base → squares near 50 and 100, swap → swap. Splitting a
  factor has no family (it is multiplication's general method): not tracked.
- **The item of a question**: a pattern question is its family's skill (even when fact-sized,
  like 2⁸ at T3); a standard question is its fact if it is one, else its strategy's skill, else
  nothing.

**Tiers of an item** — what "current tier only" means in code. A fact belongs to a tier when
that tier's **standard** questions (`doc/levels.md` section 5, current rules) can draw it:
`factsAt(type, tier)` lists them, built from the section 5 tables and tested against the
generator both ways (every fact drawn is listed; every listed fact is drawn). Its **home
tier** is the lowest. A fact may belong to several tiers (12 × 7 at T2 and T4) and is re-asked
in one of the forms that tier draws (8 × 7 and 7 × 8 at T1; only 12 × 7 at T4). A skill
belongs to every tier where its family is available; it is re-asked as a new question of its
family **at that tier's size** (`patternQuestion`). A Levelling game re-asks an item only at a
tier it belongs to — the operation's current tier.

**Scheduler** — five boxes, counted in the player's games (every stored session, in order,
whatever its kind; Tables mode is not stored and does not count):
- an item enters at box 1 on its first wrong answer or timeout; correct answers to an untracked
  item leave it untracked;
- wrong or timeout → box 1; fluent → one box up; slow → stays; **fluent in box 5 → mastered**,
  out of the schedule until a new miss. So a missed 7 × 8 is due in the next game, then after
  2, then after 4 games, and leaves the near future after three fluent answers (box 4: 8
  games) — the exit test's reading;
- **fluent** for the scheduler: a fact within its home tier's fluent time (7 × 8: T1's 4 s,
  wherever it was asked); a skill within the fluent time of the tier it was drawn at. The level
  update keeps its own rule (the game's tier), untouched;
- due: box b, last answered in game g, due from game g + 1, 2, 4, 8, 16; overdue items stay due
  (absence never punished). Order when more are due than fit: lowest box, then most overdue,
  then key.

**Rules v7** = v6 plus weak-spot questions in Levelling games:
- **Cap**: at most ⌊N / 5⌋ in a game of N questions and at most ⌈n / 5⌉ for an operation of n
  (1 of 4 or 5, 2 of 10, 4 of 20) — never above 20 % of the game; a one-operation game of 4
  questions gets none.
- The app chooses the items (due, eligible at the operation's tier, each once) and stores their
  keys with the session (`weakSpots`, an upload field of the same name, a new local column). The
  generator places them on the game's stream, like v2's reviews: the k-th of m remaining
  questions of an operation is a weak spot with probability (items left) / m. Nothing is drawn
  for a game without items: **v7 without items is v6, question for question.**
- Replay checks the stored items (known key, an operation of the game, eligible at its frozen
  tier, caps, no repeats); a breach is `notReplayable`. The server cannot check that the items
  were due (it would need the whole history): accepted as is — the items are from the player's
  tier, so choosing them gains little. Training games under v7 have no weak spots.
- Phase 3b's window is **not** restarted: at most 20 % of a game, all from its tier.

**Practice games** — two new session kinds, `weakSpots` and `drill`, stored and uploaded like
Training (replayed and checked by the server, never move a level, never ranked):
- **Weak spots** (Home card): up to 10 due items, one question each, any tier up to the
  player's own: a fact whose home tier is at or below the player's tier in its operation (asked
  in a form of its home tier), a skill whose family has started by the player's tier (drawn at
  the player's tier). Stored: the items in question order and the player's levels.
- **Profile Practice**: the block's five facts, each twice (10 questions), as a Weak spots game.
- **Profile block**: the five worst facts of the history — most missed first (miss rate, then
  misses), then the slowest against their fluent time; a fact needs two answers to be listed.
- **Drill** (every tip): 10 questions. A tip with families: a family drawn among them at the
  player's tier, or at the lowest tier one of them starts at when the player is below it. A tip
  without a family (13 of 54: "make 10 first", "add the tens, then the units"…): its
  operation's standard questions at the player's tier, brought into the tip's band (a beginner
  tip played at T2 at most, an advanced one at T6 at least). Stored: the families and the tier
  (as its lowest level).

**Dashboard** (`dashboard.sh weak-spots`): the server's accepted sessions replayed through the
same core scheduler (a Dart tool, no new dependency): per player, accuracy and time on each
scheduled item before and after it entered the schedule. Caveat printed with it: an item enters
on a miss, so "before" is biased low (regression to the mean) — compare with items never
scheduled.

**Outcome (plan v3.6, 24 Nov).** Every provisional choice above kept, with one change: **a
correct but slow answer on a fact enters the schedule at box 2** (slow facts are weak spots
too; Profile already ranks them). Applied as **rules v8**, because it changes which items are
due and so which weak spots a game may hold: each game is scheduled under its own rules
(`RulesVersion.slowFactsEnterSchedule`), so a v7 game's slow answers never enter — the schedule
of an existing history changes only from the first v8 game on. Skills keep v7's rule (a slow
skill does not enter). v8's questions and level update are v7's. Known limit (the outcome's):
the server checks a game's weak spots for tier and caps, not that they were due — the
close-out's commit 3.

**Close-out, commit 3 (plan v3.6): the weak spots checked against the accepted history** —
**confirmed, kept as built (owner, plan v3.8, 25 Nov).** The server rebuilds the player's schedule from every session it accepted
(`player_upload_history`) and flags a Levelling game whose weak spots are not all due
(`weakSpotsNotDue`); the game still counts for levels. Read only for a game holding weak spots
(its cost grows with the history: fine at beta scale, to revisit before Phase 7). The app
leaves refused sessions out of its own schedule so both sides rebuild from the same games;
what can still differ (another device's games, a refusal arriving after a later game was
built) only raises the flag. Weak spots games and Drills are not checked: never ranked.

## Phase 7: asynchronous duels and friends (plan v3.7) — confirmed but one (plan v3.8)

**Owner decisions (25 Nov):** no live matches — every duel races a recorded run; online play
needs a linked account; three modes (Basics, Advanced, Get the count), each with its own
rating and board; friend duels are rated (once a day per pair and mode); difficulty from the
rating (150 points a tier; Get the count by shortest-solution length); Glicko-2 on the server,
τ 0.5, RD capped at 350, starting ratings from levels, "?" for 10 duels; a run served at most 5
times, a player's 10 latest runs per mode in the pool; practice opponents; rematch; friend
codes, invite links, challenges expiring after 7 days; in-app badges only. Everything below is
Claude's reading, provisional until the phase report.

**Content** (`math_core/duel/`, commit 1).
- A duel is a **`DuelConfig`** — mode, seed, difficulty, the game rules its questions are drawn
  under, the duel rules (`DuelRulesVersion` v1) — stored with every duel and run; both players
  play exactly its questions. It replaces Phase 5.2's bracket-based config (fifteen brackets of
  100 points, levels 5–75, twelve mixed questions), which no duel ever stored: its pins are
  re-recorded once, on purpose.
- **Basics / Advanced**: difficulty = a tier, ⌊(rating − 900) / 150⌋ clamped to T0–T9, the
  rating rounded to the point. The 8 types (two of each of the mode's four, by `.index`) are
  shuffled by the seed, then drawn with the **game's own generator** at the tier's lowest level
  (T4 → level 40), from the same random stream, under the config's game rules (new duels: the
  current rules, without weak spots — a v8 duel draws v6's questions).
- **Get the count**: difficulty = a band — below 1300 → targets whose shortest solution takes
  2–3 operations; 1300–1700 → 3–4; above 1700 → 4–5. Three puzzles from the seed's stream: the
  six numbers as in solo, then the target among the values in [101, 999] whose shortest
  solution length is in the band (built backwards, never rejection sampling). If none is (a
  rare draw of six numbers), the nearest length the numbers allow, lower first — the round
  stays playable, slightly off band. 30 s a round (solo keeps 45 s).
- **Winner**: Basics/Advanced — more correct, then less total time (the sum of the eight
  response times; a timeout counts 30 s), else a draw. Get the count — smaller total distance,
  then less total time (each round's time = when its closest value was reached; the six
  numbers count from 0 s; a round never improved counts 0 s), else a draw.

**Runs and validation** (commit 2).
- A **quiz run** holds the 8 answers (value, time; a timeout is −1 at 30 s). A **count run**
  holds, per round, every improvement of the closest value: its time, its value and the
  operations that made it from the six numbers. The server replays both: the questions from
  the config, correctness recomputed (the client's word is never taken), times in range;
  every improvement a legal derivation, strictly closer, strictly later, none after the target.
- **Quitting counts**: the app stores the run after every answer and round; ✕ sends it with the
  remaining questions as timeouts (unplayed rounds as never improved), and a run left by a
  closed tab is sent at the next start. Escape remains possible by clearing the browser or
  switching device — the dashboard counts duels never answered (commit 8).
- **Flags** (kept out of the pool until the owner reviews them; the duel still counts):
  quiz — the solo game's rules (`implausiblyFast`, `flatTimes`); count — `implausiblyFast`
  when two rounds reach a target of 3+ operations in under 3 s each.
- A refused run never enters the pool and its duel does not count (no rating change); the
  reason is recorded once and the same answer is returned on a resend.
- **What an opponent receives**: a *lane* — per question its time and whether it was right
  (per round, each improvement's time and distance) — never the values typed.

**Ratings** (commit 3).
- One `duel_ratings` row per player and mode, created at the player's first accepted run of
  that mode at the **starting rating** (900 + 15 × main level; 900 + 15 × mean of the four
  advanced levels, unplayed at 0; Get the count 1300 — `startingDuelRating`, in the core so the
  app shows the same "?" value before any duel), RD 350, σ 0.06.
- Each rated duel is **one rating period for both players**: each is updated against the
  other's rating as it stood before the duel; 1 a win, ½ a draw, 0 a loss. No inactivity
  growth between duels (a period is a duel), so the RD cap of 350 only matters for new rows.
- "?" while a mode has fewer than 10 **rated** duels (practice and unrated friend duels don't
  count). Boards: non-provisional linked players with a rated duel in the last 30 days.
- **Rated**: a pool duel always; a practice duel never; a challenge (friend or rematch) only if
  no other challenge between the same pair in the same mode was rated that UTC day — the limit
  applies to every challenge, not only between friends, since a rematch can also send one.
- Concurrency: each rating row carries a version; the server applies a result only if both
  versions are unchanged, else re-reads and recomputes (3 tries, then 503 — the app retries).

**Matchmaking** (commit 4) — a **Dart server endpoint**, not a SQL function: the tier, the
count band, the current rules and the practice run come from the core, one implementation (rule
17). Cost: a sleeping free server delays the first duel (~30–60 s); the Online tab wakes it
(`/health`) when it opens, and the duel screen says "Finding an opponent…".
- Candidates: accepted, unflagged (or reviewed) runs of the mode, served fewer than 5 times,
  among their owner's 10 latest, never the caller's own, never on a config the caller has
  already played (racing a second run of the same questions would be a replay). Ordered by
  |owner's rating − caller's rating|, then newest. A serve is counted when the run is handed
  out (locked, so two callers cannot take its fifth serve).
- **Practice**: no candidate → a new config at the caller's rating, raced against a simulated
  run drawn from the seed (core `practiceRun`): per question right 70 % of the time, in 60–140 %
  of the tier's fluent time; per round exact half the time, else 1–9 away, in 8–28 s. No rating
  change; the caller's run then enters the pool, which is how an empty pool fills.
- **Rematch** (result screen): another pool run of the same opponent not yet raced, the closest
  tier to the caller's first; else a challenge sent to them (the caller plays first). After a
  practice duel: a new search.
- **Challenge difficulty**: from the mean of the two players' ratings.

**Friends** (commit 7).
- **Code** `MATH-` + 4 characters from the beta codes' 32 unambiguous ones (no I, O, 0, 1):
  about a million codes. Guessing is bounded by the request limit — **20 friend requests a day,
  failed lookups included** — and a hit only sends a request the stranger must accept.
  Created on first use, never changes. **Invite link**: the site with `?friend=MATH-7K2P`; the
  app keeps the code and sends the request once the player is linked.
- A request to someone who already asked you makes you friends at once. Removing a friend
  removes the friendship, never the history. Head-to-head: wins each over every duel between
  the two (pool and challenges), draws left out. History: date, mode, both scores, result.
- **Challenges** go to any linked player (friends from the Friends page, the last opponent
  from Rematch): one open challenge per pair and mode at a time; 7 days, then expired. A
  challenge is offered to the friend only once the challenger's run is accepted.

**Badges**: the Online tab shows a dot when a challenge waits or a friend request arrives;
the Friends button the same for requests. Read when the tab opens and after each duel.

**Reopen when** the dashboard (commit 8) shows: practice duels dominating (the pool too thin to
match), ratings piling at the tier edges, Get the count bands off target (rounds unsolved or
trivially solved), or abandoned duels by the same players.

**Phase 7 outcome (plan v3.8, owner, 25 Nov).** Kept: matchmaking on the server (the Online
tab wakes it); the same unplayed duel handed back within an hour; the once-a-day rating limit
on every challenge, rematches included; challenges at the mean of both ratings; the practice
opponent (70 %, 60–140 % of the fluent time); 4-character friend codes with the 20-a-day cap.
**Changed:** quitting by closing the browser no longer escapes — an abandoned duel is a loss
(close-out commit 1, below). New rule: every CI test suite states how many tests it ran and
fails below a pinned minimum (close-out commit 4). Known limit: the free Render server sleeps
(30–60 s before the first duel after a quiet period); a paid plan is an owner decision before
Phase 6.

**Close-out, commit 1 (plan v3.8): an abandoned duel is a loss** — confirmed (plan v3.9, 26 Nov). The app sends
its run as it stands after every answer and round (`POST /v1/duels/progress`, stored as sent,
replayed only at the end); the server records a duel started but not submitted within 24 hours
— a pool or practice duel from when it was handed out, a challenge from when the friend opened
it — as a loss (result 0, whatever the answers), from that progress completed with timeouts
(empty rounds); rated like any duel of its kind (practice never). The run is flagged
`abandoned`: never in the pool, not in the owner's review list (`owner_dashboard.abandoned_duels`
counts them). A progress that no longer replays voids the duel instead. The free server has no
clock: every duel request (find, open, run) first records up to 3 abandoned duels — a player who
comes back late finds the loss already there; a run sent after it gets the recorded verdict. A
challenge whose challenger never played within 24 hours is void (no run to lose against).

## Project review: the owner's decisions of 26 November (plan v3.9) — decided

The review (`doc/review-2026-11-26.md`) ended with 15 questions; the owner answered them in
plan v3.9 ("Project review"). Recorded here so that later entries can point at them; the plan
is the source.

1. **Quitting a Levelling game (M4)**: counts once it has one answer, unanswered questions as
   timeouts. Rules v9 (Phase 6b).
2. **Duels at launch (B5, M1–M3)**: fixed first (Phase 6a), then opened **rated**.
3. **Cheating resistance (M1)**: stop casual abuse now — no escaping a loss, no faked time.
   Server-revealed, server-timed questions come with live duels (Phase 7b).
4. **Paid plans (M9)**: launch sized for ~1,000 players; Render always-on from launch; Supabase
   free with an alert at 50 % of the database once stored sessions are slimmed; static files
   content-hashed.
5. **Minimal text (M16)**: relaxed for strangers (Phase 6b).
6. **Question pools (M10)**: widened and de-duplicated, `doc/levels.md` v1.6 (rules v9).
7. **Age and legal (B1)**: minimum 15, declared at account creation; legal pages in French and
   English; the host's details in the legal notice; professional review kept.
8. **Names (M6)**: unique, ignoring case and look-alike letters; only accounts report; a
   reported name is hidden until the owner reviews it, within 48 h.
9. **Moderation (M5)**: the owner decides from the dashboard; a hidden player leaves boards,
   pool and friend search, and their Profile says "Account under review".
10. **Old rules (m14)**: v2–v6 retired 30 days after v9 ships (Phase 6c).
11. **Spec readings (m4, m5)**: division stays on one line (spec fixed); weak spots at most
    ⌊n/5⌋ per operation.
12. **French (m18)**: strings in one place in 6b; English at launch; French right after.
13. **Deleted accounts (m8)**: duels kept, shown as "Deleted player".
14. **Plan fixes**: done in v3.9.
15. **Still provisional**: the abandoned-duel choices are **confirmed** (the entry "Close-out,
    commit 1" under Phase 7 above); Latin letters only for names at launch; no ads, payments or
    analytics at launch; live duels in 7b.

## Phase 6a: integrity and capacity (plan v3.9) — confirmed but one (plan v4.0)

Each choice below filled a gap the plan leaves. **The owner's verdicts (plan v4.0, "Phase 6a
outcome", 27 November):** sessions not slimmed — **confirmed**, with **no retention rule**
(levels must stay recomputable) and Supabase's paid plan when the 50 % alert fires; the sweep
on a server timer — **confirmed**, and it must catch up at start (done in 6b commit 0);
"Latin letters only" read as narrowing — **reversed**: Greek and Cyrillic are allowed again
(6b commit 0); one report hides a name — **confirmed until 6c** (then confirmed accounts
only); duplicates renamed "Name 2", cached Pages files, the rate limits, 300 games and 200
duels a day, the 60 s board cache, the 200-session cap — **confirmed**; the frozen spec copy —
**confirmed**, deleted in 6b commit 1. Everything else below stands as written.

**Commit 0 — the conformance test reads a frozen spec until rules v9.**
`levels_spec_conformance_test.dart` reads `doc/levels.md` and draws every example under
`RulesVersion.current`. The owner's v1.6 describes rules v9 (new Powers, Roots and Integrals
tables), which Phase 6b builds; Phase 6a must not touch generation. With v1.6 in place the test
cannot even load, which would turn the core suite red and stop every deploy of this phase.
Options: (a) skip the test until 6b — a skipped suite hides a real drift of v8 and drops the
count under its pin; (b) implement v9 now — against the phase's scope; (c) check v8 against the
spec it implements. **Chosen: (c).** `packages/math_core/test/spec/levels_v1_5.md` is
`doc/levels.md` as committed before v1.6, byte for byte; the test reads it while
`RulesVersion.current` is below 9 and the owner's file from v9 on, with no further edit. The
190 conformance tests run as before. Phase 6b deletes the copy with the commit that makes v9
current. This is not "editing the test to fit the code": the test still fails if v8 drifts from
its spec, and it will fail in 6b until v9 matches v1.6.

**Commit 1 — duel results hold (B5, M1, M2, M3, n1).** The plan fixes the rules; these are
the gaps it leaves.

- **What a forfeit keeps.** "A loss with what was received": the run as sent, completed with
  timeouts, if that replays (a run cut short, or one refused only for its clock); else the
  progress the server holds, completed; else an empty run. The result is 0 whatever it holds.
  Flagged `forfeited` (new stored name): never in the pool, not in the owner's review list;
  the reason stays in `duel_run_rejections`, listed by `owner_dashboard.forfeited_duels`. The
  answer to the app is the accepted shape with `result: 0` — the stock app never sends such a
  run, so no screen changes.
- **A run that does not continue the progress is refused, not forfeited** (409
  `progressMismatch`). The duel stays open: the device that started it can still finish, and
  otherwise the 24-hour rule records the loss from the progress. A forfeit on the spot would
  punish a player who opened the same duel on a second device by mistake more than the plan
  asks ("only a run that extends it is accepted"). Get the count sends its progress after
  each round, so a round once received can no longer gain an improvement.
- **A flagged run earns nothing — but a flagged loss stands.** The plan says "a flagged run's
  duel is recorded unrated". Applied literally, getting flagged would be a way out of a loss
  for a client that can produce two instant right answers. Chosen: the duel is unrated unless
  the flagged run's player lost it (either side). The owner's later review (`review-run … ok`)
  puts the run back in the pool but does not rate the duel after the fact.
- **The clock.** A run may not claim more answering time than has passed, by the database's
  clock, since its duel was handed out (a challenger: the challenge's creation; a friend:
  when they opened it), plus 5 s. Unanswered questions claim nothing — the app fills in
  timeouts without waiting, and a quit must stay an ordinary run. For the second player the
  refusal is a forfeit like any other; for a challenger it voids the challenge.
- **Challenge lifetime.** "Cannot be opened in its last 24 hours" is kept by the dates
  themselves: `expires_at` is now the last moment to **open** it (6 days), and an opened
  challenge is played or lost within 24 hours whatever that date — 7 days in all, and the
  "Waiting for you" list needs no new filter. Challenges already open keep the date they
  were given. A challenge must be opened before it is played.
- **Recent opponent** = any finished duel between the two in the last 30 days, any mode,
  either way round. No block list (the review suggested one; the plan does not ask for it).
- **Once per 24 hours**: the earlier duel that blocks the rating is itself a chosen, rated
  one. A duel matchmaking made between the same two players does not use up the pair's daily
  rated challenge, and stays rated itself.
- **Progress is parsed before it is stored** (malformed: 400, nothing kept), and stored in
  the server's own shape — it was stored as sent.

**Commit 2 — abuse floor (B4).** The plan names the mechanisms; the numbers are mine.

- **Limits.** Per address 120 requests in a burst, then 2 a second; per player 40, then one
  every 2 s. A duel is about ten requests over a minute or more; a backlog of offline games
  uploads one at a time and simply slows down past the burst (the app retries a 429). A
  school or a phone network behind one address gets 120 a minute sustained. Daily: 300
  accepted sessions (five hours of 10-question games back to back) and 200 new duels per
  player over a rolling 24 hours. Refusals kept: 50 a day per player, each a digest with the
  first 1,000 characters of the payload.
- **Every limit is a 429, never a refusal.** A refusal is final for the app (the session is
  dropped from the queue); a limit must only delay. Past the daily duel cap the duel still
  open is handed back.
- **In memory.** One server instance; a restart forgives everyone. A second instance would
  need the counts in the database — not before the load asks for it.
- **The address** is what the host's proxy reports (`cf-connecting-ip`, else the first
  `x-forwarded-for` entry), else the socket. If Render does not overwrite those headers a
  client can choose its own key: that weakens the address limit, never turns it against
  other players, and leaves the per-player limit and the daily caps intact. Taking the last
  forwarded entry instead would be safe against forging but would put every player in one
  bucket if that entry is the proxy. **To verify on staging after the deploy** (a burst with
  forged headers): recorded in the phase report.
- **Tokens.** Shape only (a JWT naming a user id, not expired): no signature check on the
  server, Supabase Auth still decides. A well-formed forged token still costs one call to
  Supabase — bounded by the address limit.
- **A refusal past the daily count is not stored.** If it were ever resent it would be
  decided again, to the same verdict; the app never resends a refusal.

**Commit 2, verified on staging.** The address limit's key is `cf-connecting-ip`: Render is
behind Cloudflare, which sets it and refuses a request carrying its own (403). The caveat
above no longer holds for Render; it would again on a host without Cloudflare in front.

**Commit 3 — solo integrity and moderation (M5).**

- **Overlap is a flag, received-too-soon is a refusal.** "Created before the previous one could
  end" also happens honestly when a phone's clock is set back between two games, so it is
  flagged and accepted (the owner sees it in `moderation_evidence`). "Received sooner than
  its own total time" cannot happen honestly beyond the clock skew already tolerated (5
  minutes), so it is refused like a session dated in the future, with the same reason
  (`futureTimestamp`: no new stored name). The overlap tolerance is 2 s.
- **Two levels of moderation.** `hidden` (the plan's "hidden player": off boards, pool and
  friend search) and `banned` (also nothing more accepted). Neither is a refusal: a banned
  player's uploads get 403 and stay on the device, so lifting a ban mistaken loses nothing.
  A hidden player keeps playing and levelling; duels match them with practice opponents only
  (they are out of the pool both ways) and stay unrated as practice is.
- **What the player sees**: "Account under review" and one line ("Your results are not shown
  on the boards until the review is done") on Profile — not the state, not the reason. A
  hidden player's code finds nobody, and a challenge to them answers `notAllowed` like one to
  a stranger: other players are not told.
- **Evidence for the owner**: one view, a row per player with anything over the last 30 days.
  No automatic hiding: the plan says the owner decides.

**Commit 4 — names and privacy (M6, m8).**

- **"Latin letters only for names at launch"** (answer 15) is read as narrowing today's rule
  (Latin, Greek, Cyrillic) to Latin — Basic Latin, Latin-1, Latin Extended-A and Vietnamese —
  applied now because this commit owns names. Names already saved in Greek or Cyrillic are
  kept (the database's check is `NOT VALID`; the fold covers both scripts so they cannot be
  imitated). If "Latin only" meant "no wider than today", it is one line in Dart and one in
  SQL to restore.
- **What counts as the same name**: case, accents, look-alike letters of Latin, Greek and
  Cyrillic, i/l/1 (I and l are the same glyph in Inter, and case is ignored), o/0, rn/m,
  vv/w, and separators (space . _ ' -) ignored altogether: "Jean-Paul", "jean paul" and
  "JeanPaul" are one name. Digits other than 0 and 1 are not folded ("Max 2" ≠ "Max 3").
- **Duplicates already stored**: the profile that chose the name first keeps it; each later
  one becomes "Name 2", "Name 3"… (cut to 30 characters), or no name if the result breaks the
  rule. The players are not told; the next Profile visit shows the new name. Only the count
  is printed by the migration (CI logs are no place for names).
- **Reports**: saved accounts only (a guest is told to save their progress), 10 a day per
  reporter. **One report hides the name** (answer 8: "a reported name is hidden until the
  owner reviews it") — on the player, not the spelling. The hiding lasts until the owner's
  next verdict on that player; a report made after it starts again. Abuse of reporting is
  visible to the owner in `names_to_review` and `name_reports`, and the reporter can be
  hidden or banned.
- **A deleted player's duels**: kept with their result, their lane (times and right/wrong per
  question, never the values typed) and the opponent's rating change; the deleted player's
  name, runs, ratings, friends and everything else go. Open duels left with nobody to play
  them are voided. The in-app notice says so; the published policy (6c) must too.

**Commit 5 — capacity (M7, M8, M9).**

- **Stored sessions are not slimmed** (deviation from the plan, to confirm). Measured on 20,000
  rows each, indexes included: a 20-answer game takes 1,519 bytes as stored today, because
  Postgres compresses the uploaded JSON (5.9 KB of text) — and 1,791 bytes slimmed to "seed,
  config, answers and times", which is too small to be compressed. Only 80-answer games shrink
  (3,378 → 1,790). Slimming would also break the owner's SQL views that read each answer's
  numbers (the Phase 3b data check, features, structural features): questions can only be
  regenerated in Dart. What the database really holds: about 1.5 KB per game. At 1,000 daily
  players × 10 games that is 15 MB a day — the 50 % alert in about 17 days, the free 500 MB in
  about a month. Slimming does not change that order of magnitude; **retention** does (keep
  each answer's detail for N months, then only the session row), or Supabase Pro (8 GB). Both
  are owner decisions; the alert is in place to make one in time.
- **`board_rows` is unlogged and has no foreign key**: a cache rebuilt every minute; a crash
  empties it and the next call refills it. Without the key a deleted player's rows would stay
  up to a minute, so `delete_my_account` deletes them first (other deletions — guests, the
  owner's — never concern ranked players or are rare; their rows go within the minute).
- **Boards cached 60 s.** A player's own place can lag a game by up to a minute; a hidden or
  deleted player leaves the cached board within the minute (a deleted one at once, by
  cascade). One caller recomputes, the others serve the previous minute (a try-lock); the very
  first call waits.
- **Matchmaking windows** 50, 150, 400 points, then anyone: the same pick as before whenever
  someone is within 50 points (the closest); beyond, the closest of a wider window.
- **Weak-spot history: the latest 200 sessions.** An item last seen more than 200 sessions ago
  and still due would be flagged `weakSpotsNotDue` for an honest player — a flag, never a
  refusal, and unlikely (items are due within 16 games).
- **Web caching.** "The Pages Function only on HTML" is not what this does: the Function still
  serves the large files' first download (brotli 11, the reason it exists), but returning
  players never call it for the hashed files (a year, `immutable`) nor the fonts (a day). Only
  `sqlite3.wasm` is still revalidated on every visit: it must match `sqflite_sw.js`, which keeps
  its name. That is one Function call per returning visit instead of five: the free quota
  (100,000 a day) is ~100,000 returning visits a day, ~25,000 first visits.

**Commit 6 — details (m1, m2, m6, m7, m10, n2, n3).**

- **The sweep runs on a server timer, not `pg_cron`** (deviation). Recording an abandoned duel
  needs the Dart replay (score, lane) and Glicko-2, both in the server; `pg_cron` could only
  call the server back through `pg_net` with a shared secret stored in the database — more
  moving parts than the finding is worth. The server sweeps every 5 minutes and soon after a
  duel request (at most once a minute), never inside one. On Render's free plan the timer
  stops while the server sleeps; the first request after waking sweeps. With the always-on
  plan (6c) it runs all the time.
- **Setting a session aside**: 20 failures *the server answered* (5xx), the first at least 3
  days before the last. Being offline or the server asleep never counts. The session is
  marked refused on the device (`setAside`, shown as "the server could not check this game")
  and the games after it are sent; they may then be refused `levelsMismatch` and the app
  adopts the server's levels, as for any refusal.
- **Friend codes**: 8 characters in two groups of 4 (about 10¹² codes); every existing code
  was replaced and old invite links find nobody (a handful of beta testers). "New code" is
  confirmed first and keeps friends.
- **CSP**: `'unsafe-inline'` for scripts stays (the boot sign-in and the loader are inline in
  `index.html`); `'wasm-unsafe-eval'` for CanvasKit and SQLite; no `'unsafe-eval'`;
  `connect-src` limited to the site, its Supabase project (HTTPS and WebSocket) and its server.
- **Container**: UID 65534 by number (the scratch image has no user database). The base image
  stays a tag (`dart:3.14`): pinning a digest needs a way to bump it, not in this phase.

## Phase 6b: player experience (plan v4.0) — confirmed but four (plan v4.1)

Each choice below filled a gap the plan left. **The owner's verdict (plan v4.1, "Phase 6b
outcome", 27 November):** kept — v9's generation choices, quitting counts from one answer,
the Method readings, one quiet line per control, 15 s on Supabase calls, Cancel only while
the server wakes, edges at 3:1, body text 15 px, strings as Dart classes (**one class per
language, so a missing translation fails to compile** — the owner's reading, stricter than
the subclass-with-English-fallback written below), the terms, √ of powers of 2 as v1.6 says.
**Changed**: the result's reason in **counts, not a percentage** (commit 4 below; Phase 6c
commit 0); the duel rules sheet **once per mode**, then a reminder line (commit 4 below;
Phase 6c commit 0); semantics on for everyone **kept but measured** (commit 6 below; Phase 6c
commit 0); a deploy-window duel never opened by an app that knows its rules is **void, not a
loss** (commit 1 below, "Duels"; Phase 6c commit 0). The spec conflict of commit 1 (∫₀²⁵) and
the √ row's wording were fixed by the owner in `doc/levels.md` v1.6.1.

**Commit 0 — close-out of 6a.**

- **A session's end is its `createdAt`** (a fix, not a choice: recorded because it changes a
  6a rule). The app has always stored a game at its end — when the last answer is given or the
  game is left — and 6a's commit 3 took `createdAt` for the start: it refused as
  `futureTimestamp` every game with more than five minutes of answers sent at once (a default
  40-question game at 8 s an answer is 5.3 minutes), stored `createdAt` + the answers' times
  as the end, and so flagged `overlapsPrevious` a short game played right after a long one.
  Now: the end is `createdAt`; a session overlaps when `createdAt` minus its answers' times is
  before the previous end (2 s tolerance); "received sooner than its answers took" is the
  existing `createdAt` check. The stored ends are reset to each player's latest `createdAt`
  (migration `20261203000000_phase6a_closeout`). Games refused this way since 26 November
  cannot be sent again: the app dropped them and adopted the server's levels — their count is
  for the owner to read (the phase report gives the query).
- **The catch-up.** A sweep outside requests takes batches of 3 until the database lists
  fewer than 3, or a batch records nothing (a duel failing every time must not hold the
  loop), or 200 batches (600 duels; the next sweep goes on). The server runs one at start —
  not awaited: the first request is served at once — then every 5 minutes and after a duel
  request, at most once a minute, as before. Inside requests (the tests) still one batch.
- **The split of `duel_endpoint.dart`** (969 lines): `server/lib/src/duels/` —
  `duel_matchmaking.dart` (find, rematch, challenge, open), `duel_runs.dart` (run, progress,
  forfeit, apply), `duel_abandonment.dart` (sweep, catch-up), `duel_ratings.dart` (who is
  rated, start ratings), `duel_json.dart` (the decided answer, JSON reading);
  `duel_endpoint.dart` keeps the HTTP surface (routes, authentication, body) and the
  constructor the tests use. No behaviour changed but the catch-up.

**Commit 1 — rules v9 generation (M10, m11, m20, m21; m5).** The spec (`doc/levels.md` v1.6)
fixes the tables and the rules; these are the readings and gaps.

- **How "no repeat" is kept without rejection sampling (rule 10).** Every tier's standard
  questions and every family at every tier is a space of distinct questions (`QuestionSpace`):
  listed when it holds at most 30,000, drawn number by number above (the long sums from T3).
  A listed space draws an index among the questions the game has not asked; a drawn one, on
  the one-in-a-million question already asked, steps to the next in a fixed order. One
  memory per operation per game (`OperationDraws`) covers standard, pattern and weak-spot
  questions together: a weak spot's fact is never drawn as another question of the game.
- **"While the tier still has unused questions"** is read as the whole tier, not the source:
  when the drawn family has nothing left unasked, another family with something left is drawn,
  else a standard question (and the reverse). Only a tier used up repeats — never twice in a
  row. The price: where the only family is small (roots T3: 4 questions; integrals T1: 4) the
  pattern share falls from 40 % to about 30 %.
- **"Uniform over distinct questions"** is exact in every listed space — all of the small
  pools, where a question could be frequent: 9 + 1 is 1 in 25 of T0 addition (was 11 %),
  2⁵ 1 in 12 of T1 powers (was 25 %). Literally, it also makes a small form of a tier rare:
  the 20 crossing-10 facts (8 + 7) are 2.4 % of T1 standard addition, beside 810 sums of a
  2-digit and a 1-digit number (v8 gave each form half); teens − 1-digit 9 % of T1
  subtraction; 11–19 × 11–19 14 % of T5 multiplication. Kept literal; the other reading
  (each form of a row an equal share, uniform within it) would make each of the 20 facts
  40 times as likely as a 47 + 8 — the favouring the rule forbids. **In a drawn space** (the
  long sums) every question is below one in 10⁵ either way; there each form of the row gets
  an equal share, so every size it names stays in the mix: 7 + 7 is a third of T8 (by count
  it would be 0.8 %, and the spec's own T8 example, 4 736 285 + 2 948 617, would hardly ever
  be drawn).
- **Within a family, uniform too**: v5 drew a form first — `× 99` was half of `× 9s` at T5,
  each of 99 %, 101 %, 125 %, 200 % a quarter of its family. Now each question counts once:
  `× 99` is 9 % of `× 9s` at T5, 200 % of n most of "99 %, 101 %, 125 %, 200 %". Owner's rule
  as written; to revisit if the families feel lopsided.
- **No trivial factor above T0**: also 1 % at T6 and T9 ("any whole percentage" does not list
  it); quotient 1 (8 ÷ 8) dropped with × 1 (division mirrors multiplication).
- **T7 integrals offered 8 questions** (4x³ from 0 or 1, b 2–5): the upper bound now goes to 7
  (12 questions, the spec's minimum). The row names no bound.
- **Families skipped (fewer than 4 questions)**, with v8's band edges kept: powers of 2 at
  T1–T6 (two a band), √ of powers of 2 everywhere (v1.6's row mirrors powers of 2 two tiers
  later: one to three questions a band), ∫₀ᵇ 3x² at T4–T5 and ∫₀ᵇ 4x³ at T7–T9 (three or two),
  repunits at T6. Each of these questions is also standard content at the same tier (2⁴–2⁷
  at T1, √64 at T0, 3x² from 0 at T4, 4x³ at T7), so nothing is lost; repunits would have
  vanished everywhere, so they take 11² (T7–T8) and 11⁵, 111³ (T9) within the hard limit.
  **To the owner**: v1.6's √ row ("mirror of powers of 2, two tiers later") reads like v1.4's,
  as does the line "Changing the generation is a new rules version (v4)" — v1.5's edits
  ("T3: √64 to √1 024 · T5: up to √65 536"; "v4, v5 at v1.4, v6 at v1.5") seem lost. Under
  either √ row the family has three questions a band at most, so it is skipped either way.
- **Families grow** (v1.6's lower bound): the test reads "size" as the median answer.
  Outside the size table a family must grow at least every two tiers until it reaches its T9
  size; families that stayed the same over three tiers (× 11, × 25, difference of squares,
  doubling and halving, × 9s, ÷ 25, halving chains, √ of squares ending in 25, ∫ difference of
  squares) now grow tier by tier — the top of their range rises. Size-table families follow
  their bands (several hold three tiers: the spec's).
- **Spec conflict, reported**: the family table still ends ∫₀ᵇ 2x at "∫₀²⁵ 2x dx" (v1.4's T5
  size) while v1.6's size table takes it to b ≤ 50 at T7 and b ≤ 100 at T9; the code follows
  the size table, and the conformance test checks that one example at any tier
  (`_exampleConflicts`), until the spec is fixed.
- **Weak spots** (m5, moved here from commit 7 because it changes what a v9 game draws): at
  most ⌊n/5⌋ per operation — none with 4 questions an operation (so a main game of 4 × 4
  questions holds none), 1 of 5, 2 of 10, 4 of 20. A v9 weak spot must belong to v9's tier;
  the fact catalogue's home tiers stay v8's (practice games replay with them).
- *(The last part superseded, plan v4.1: an app that does not know the server's rules gets no duel — Phase 6c commit 0.)* **Duels** draw under the game rules they store: a new duel is v9 (no question twice);
  v8 duels replay as they were. No new `DuelRulesVersion`. An app opened before this deploy
  and never reloaded cannot read a v9 duel — it shows an error until the page is reloaded (a
  duel left that way would be lost after 24 hours, as any). Not guarded: the app reloads on
  its next visit, and the window is one deploy.
- **Practice games** (Weak spots, Drill) keep their generators: v9 is about Levelling,
  Training and duels.

**Commit 2 — quitting counts (M4).** The spec (`doc/levels.md` v1.6 section 3, "Quitting never
pays") fixes the rule; these are the readings.

- **"Every unanswered question counts as a timeout for its operation"**, read literally:
  an operation the game planned but never reached gets all its questions as timeouts — q = 0,
  the full cap (−3). Quitting a 4-operation game after one answer costs every operation up to
  3 levels. The spec says so; the quit dialog now warns ("The questions left count as missed:
  your levels can go down.").
- **A closed tab**: a Levelling game is kept on the device after every answer
  (`shared_preferences`, one game, its upload shape — on the web `localStorage`, written at
  once, so a tab closed right after an answer still has it). The next start stores it before
  anything else, as a game left at its last answer (`createdAt` = that answer's time, its end),
  then clears it; a game whose session is already stored (its write landed, the clear did
  not) is only cleared; one that cannot be read is dropped. The session's id is now drawn at
  its first answer, its answers' ids as they come — the same order as before, so the kept
  game and the stored one are the same rows. **Not covered**: two tabs playing at once (the
  second tab's start would store the first tab's live game; the first tab's own write then
  fails, shown as "not saved") — rare, and nothing is counted twice.
- **What still counts only finished games**: the main board's game count
  (`completed_games`) and `hasCompletedSession` — a quit game moves levels, it is not a
  finished game.
- **Screens**: three timeouts end the game on its result screen, which now shows the level
  change of a v9 game; ✕ (confirmed) returns to the setup as before, the levels shown there
  already moved. Training, practice games and duels are unchanged (Training never moves
  levels; a duel left was already a loss).
- **Simulation** (`tool/levels_simulation.dart`, a player who quits at the first mistake,
  games of 10 at level 50, mean change per game, finished / quit): 80 % v8 +1.55 / +0.52,
  v9 +1.55 / −1.41; 70 % v8 +0.53 / +0.14, v9 +0.53 / −2.28; 60 % v8 −0.31 / **+0.03** (the
  exploit: quitting turned a loss into a gain), v9 −0.31 / −2.68. A perfect player never
  quits: unchanged. From level 0, a 70 % quitter reached T7 in 468 games under v8; under v9
  never reaches T1.

**Commit 3 — Method quality (M11, n6).** The spec (`doc/levels.md` v1.6 section 9) fixes the
rules; these are the readings.

- **The guards are the Method's, not the detector's.** "A strategy is offered only if it makes
  the question easier" is applied in `methodFor` (`offersMethod`); the strategy detector
  (`bestStrategy`) is unchanged, because weak spots key a standard question's skill on it —
  changing it would change every player's rebuilt schedule, on the app and the server, at
  once.
- **"A round number"** (compensation "within 3 of a round number") is a number with one
  significant digit — 70, 200, 9 000 — so 9 449 → 9 450 is not one (the spec's own "no"),
  and the same rule holds for rounding what is taken away (742 − 198 yes, 10 − 7 no: rounding
  onto the minuend restates the question).
- **Long division**: a one-digit (or round) quotient is the multiplication; a two-digit one
  splits the dividend by the quotient's places (522 ÷ 6 = 480 ÷ 6 + 42 ÷ 6); a larger one
  takes off parts, the largest first — the divisor times a one-digit number times 10ᵏ, or a
  round number the divisor divides into a quotient of at most two significant digits — until
  what is left has a two-digit quotient: exactly the spec's 5 104 ÷ 4 = 4 000 ÷ 4 + 1 000 ÷ 4
  + 104 ÷ 4. The last part is "at sight" only as much as the spec's 104 ÷ 4 = 26 is (2 082 ÷ 6
  ends on 282 ÷ 6 = 47).
- **Subtraction counts up** through a round number only when the first step is short (at most
  two significant digits: 403 − 178 = 22 + 203, not 40 000 − 30 549 first), and up to the
  minuend itself when it is round (297 + 3 = 300).
- **Percentages**: friendly fractions first (a half, a quarter, a fifth, a tenth, a
  hundredth, three quarters, eighths, and 5 % as half of 10 %); above 100 % the whole and a
  friendly rest (120 % of 45 = 45 + 45 ÷ 5); else built from 100 %, 50 %, 25 %, 10 %, 5 %, 1 %
  with every part whole; else swapped and built (64 % of 175 = 175 % of 64 = 64 + 32 + 16).
  "p × base ÷ 100" is never shown for a v9 question (tested over every one); it remains for
  an older version's question no build fits. 20 % is not a building block (the spec lists 50,
  25, 10, 5, 1), so 80 % of 385 is a long swap — readable and correct, not short.
- **"No line holds a number with more significant digits than the question's largest number
  or its answer, plus one"**: the answer is counted by its length, not its significant
  digits — a round answer is not a smaller question (∫₁⁷ 4x³ dx = 2 401 − 1 = 2 400 would
  otherwise fail on the 2 401 every method must compute).
- **Trivial facts take one line**: × 1 and × 10 show the answer ("= 30"); writing "1 × 30"
  again would restate the question. The spec asks for 2 to 4 steps; there is no second step
  to these.
- **Names match lines**: a fallback now says what its lines do (`MethodFallback`: make 10, a
  near double, count on, place value; think of the addition, count up, take away in parts;
  times 1 or 10, through 5 ×, add it up, tens first, split the larger factor; think of the
  multiplication, split the dividend; from the nearest ten, square the tens, multiply it out;
  a known power, last digit then bracket; a friendly fraction, the whole and the rest, build,
  swap then build; antiderivative). "Near a base" reads "Near 100 or 1 000". 4⁵ splits its
  exponent like 3⁵ (it was written 2¹⁰ under "Split the exponent").
- **Pinned examples** (`test/method/method_pins.dart`, 137, generated by
  `tool/method_pins.dart`): per family and band, the first question its v9 space draws at
  the band's first tier where it is drawn; per fallback kind and band, the first standard
  question that falls back to it. Every family drawn in a band, and every operation's
  fallback in every band, has one. They were read one by one; six read badly and were fixed
  before pinning (300 − 297, 79 278 − 30 549, 10 × 3, 10², 5 % of 380, 120 % of 45).
- **`method_for.dart`** (1 067 lines, review m12) is one library in four files — the entry
  and its guards, the building blocks, the families (one exhaustive switch, n6), the
  fallbacks — `part` files, so nothing private became public.

**Commit 4 — explained, not wordy (M15 part, M16, m17 part).**

- **One line, quiet**: every Home and setup control gets one line in the small, muted style
  (`Caption`, the kit), under the control — never a paragraph, never a tooltip a phone cannot
  hover. Home: the main level ("the mean of + − × ÷"), each row, each card; setup: the
  question count in all, what the mode does (Levelling: "Quitting counts the questions left
  as missed"), Training's levels (10 / 40 / 70). Online: one line per mode.
- *(Superseded, plan v4.1: the reason is in counts — Phase 6c commit 0.)* **The result line is "Addition: 12 → 15 (+3.00)"**, whole levels then the change in
  levels with two decimals ("no change" at 0), and under it the reason: "Quality 80 %: above
  72 %, up" (62–72 %, kept; below 62 %, down; "already at 0 / 100" when a bound stopped it;
  "· 3 left, counted as missed" for a v9 quit). The quality is `gameQualities` (core), the
  same arithmetic as the update — never a second formula. It is a percentage, which
  `doc/design.md` forbids "presented as progress": it is the game's score against the band
  that moved the level, not progress, so kept; the test that forbade any "%" now allows that
  line only. The level itself is never shown in hundredths (owner, Phase 1).
- **The first-run card** ("How levels work": three sentences, "Got it") sits under the main
  level until dismissed, remembered on the device (`HintsStore`, `shared_preferences`, one
  flag per `Hint`). A new device shows it again; an account-wide flag is not worth a table.
- *(Superseded, plan v4.1: once per mode, then a reminder line — Phase 6c commit 0.)* **Rules before every rated duel, every time** (Start / Cancel), not only the first: a rated
  duel moves a rating and leaving it is a loss, so one extra tap is the price. A waiting
  challenge's Play asks too. Get the count and Chain operations show their rules once, on
  the first open (practice: nothing at stake).
- **Sign out is confirmed** (a dialog naming what happens); **games not sent yet** are
  counted under "Recent sessions" when there is a server to send them to.

**Commit 5 — network and devices (M14, M15, M18).**

- **The server's levels right after sign-in**, by the rule used before every game
  (`syncLevelsBeforeGame`: only when no game waits to be sent), once the sign-in's uploads are
  settled, with a 15 s limit instead of a game's 2 s; Home and Profile read the levels again
  (`LevelsRefresh`). History, the curve and weak spots are still not downloaded (the review's
  "never downloaded"): Profile says "Games played on other devices are not shown here" to a
  saved account. Downloading history is a feature of its own (stored answers per device, a
  read API, a merge), not in the plan.
- **The sign-in hint** shows to a guest with no level anywhere: "Played before, on this or
  another device? Sign in to get your levels back." It is one line, under the main level.
- **15 s on every Supabase call**, auth and database alike, through one HTTP client given to
  `Supabase.initialize` (`TimeLimitedClient`); past it the call fails as offline does, so every
  screen shows the error state it already had. That bounds the account-deletion spinner the
  review found undismissable (it now ends on "Nothing was deleted" and the network reason).
  The two server clients keep their own limits (uploads; duels 90 s, the server's wake).
- **Cancel only while nothing has been asked**: finding an opponent first wakes the server
  (`/health`, the long part), with Cancel and, after 3 s, "Waking the server… It can take up
  to a minute"; the duel itself is asked for only then, without Cancel. A Cancel after the
  request would leave a duel the server already made, recorded as a loss 24 hours later (pool
  and practice duels are made at `find`). A server-side cancel would let a player see the
  opponent's run and walk away from a strong one; not offered.
- **The duel timer keeps running when the tab is hidden** (review M15, last clause): kept on
  purpose. A duel races a recorded run; pausing would let a player leave the tab to work an
  answer out. The rules sheet says leaving counts as a loss.
- **The unfinished duel notice** is a one-time line when the Online data loads (at start and
  on the tab): "Your unfinished Basics duel was sent: what you had not played counts as
  missed." `DuelRunQueue.flush` answers the unfinished runs the server decided.
- **The loader**: after 40 s without the first frame (slow 4G loads in about 20 s) it shows
  "Still loading…" and a Reload button, without stopping the load; at once "The game could not
  be downloaded" when a script fails, "The game could not start" when the engine fails. `main`
  catches everything else and shows "The game could not start", the detail and Reload.
- **Friend actions** that fail say "Could not reach the server — try again."; a removal that
  fails leaves the friend's page open.
- **A friend challenge shows the duel's rules too** (commit 4 left it out: it went from the
  mode picker straight to the duel).

**Commit 6 — accessibility (M17).**

- *(Kept, plan v4.1, and measured — Phase 6c commit 0.)* **Semantics on from the start** (`ensureSemantics` in `main`): on the web Flutter otherwise
  builds the accessibility tree only after a screen reader presses a hidden "Enable
  accessibility" button. The cost is a DOM tree beside the canvas on every device; not measured
  on a low-end phone (an owner check).
- **What is said**: each question, as a live region ("Question 3 of 10: 47 times 8"); right,
  or wrong with the answer ("Wrong. 12 squared is 144."), or "Time's up" with it, as polite
  announcements; the timer bar's value in whole seconds, and "10 seconds left" once a question —
  not every second, which would drown the question. Spoken prompts use words and ungrouped
  numbers ("4 789" is read as two numbers). The duel timer is the same widget.
- **Edges at 3:1, a new role**: `outline` is the edge of what can be tapped (cards, keys,
  tiles, chips, segments; light `#7C8AA4`, dark `#616F90`), `outlineVariant` keeps the design's
  light line for what only decorates (tracks, separators). Cards and keys gained a 1 px edge.
  The design's look is heavier; the alternative (only focus rings) would not meet WCAG 1.4.11.
- **Text**: body 15 px (was 13), captions 13 px (12), the level on Home's tiles 13 px (11).
  Section labels on the setup pages moved 4 px closer (24 → 20) so Start stays in view on a
  640 px phone. Two Home captions shortened to stay on one line.
- **Viewport meta** in `index.html`: the loader is at phone width from its first paint
  (Flutter replaces the tag with its own when it starts).

**Commit 7 — strings and consistency (m3, m18, m17 terms).**

- **Every player-facing word in `app/lib/presentation/strings/`**, as plain Dart classes per
  area (`strings.home`, `.game`, `.profile`, `.account`, `.online`, `.ranks`, `.common`) plus
  the tables that already were tables (exercise types, Method labels, tips, duel texts, account
  messages, refusal texts, spoken prompts, the privacy notice), moved there. Not ARB files with
  `gen-l10n`: no new dependency, no `BuildContext` to thread into helpers, enum labels stay
  exhaustive switches, and no test needs localisation delegates. French (plan v4.0: "right
  after") is then a subclass per area overriding what it translates, chosen at start from the
  device's language; a member it misses stays English (a test can list the members a
  translation leaves out). Revisit if a translator needs a file format: an export to ARB is a
  script over these classes. A guard test (`strings_in_one_place_test.dart`) fails on any
  word-holding literal elsewhere in `lib/presentation/`, with five explained exceptions (two
  font names, `dx`, a placeholder friend code, an internal error) and the developer-only
  specimen screen.
- **Terms**: "game", never "session", in what players read ("Game complete", "Recent games");
  "Ranks", never "Leaderboard" (the tab's name: the screen's title, its messages, Save your
  progress, the privacy notice); times in seconds with one decimal everywhere ("2.4 s": the
  result's average and Profile's per-operation times were in ms). "Practice" keeps one meaning:
  what never moves a level or a rating (Home's Practice section, Get the count, Chain
  operations, a duel against a practice opponent). "Not available in this build" (owner text)
  became "not available yet".
- **Levels as whole parts everywhere** (m3): Home's and Profile's main level is now floored
  like Ranks and every operation (10.5 shows 10, not 11).
- **A password can be shown** on Sign in and Save your progress (m17).

## Phase 6c build: public launch behind switches (plan v4.1) — provisional choices

Each choice below fills a gap the plan leaves; the owner confirms or reverses it in the phase
report. What needs the owner's inputs is behind a switch or a visible placeholder (plan v4.1:
"build now, switch on later").

**Commit 0 — close-out of 6b.**

- **Nothing to recover: production refused no game as `futureTimestamp`.** Read on production
  (27 Nov, 09:30 UTC, read-only): `upload_rejections` holds 5 refusals in all, the last on
  22 Nov (`badElapsed` ×3, `typeAlreadyPlayed`, `placementAfterGames`) — none
  `futureTimestamp`. No session reached the server between 26 Nov 12:39 UTC (the last
  upload) and the reading: the regression went live about 15:40 UTC on 26 Nov (6a commit 3)
  and was replaced about 01:00 UTC on 27 Nov (6b commit 0), and no tester sent a game in that
  window (one played duels at 21:00, which were not affected). A device holds a refusal only
  if the server answered one, and it records every refusal before answering (50 a day per
  player at most; none came close), so no device holds such a game either. **Recovered: 0 of
  0.** No resend path was built: it would have reopened server verdicts — skipping
  `outOfOrder` and `levelsMismatch` for a game older than the player's accepted ones — for no
  game at all. If a refusal of this kind ever shows up, the earlier precedent applies (Levels
  phase commit 4.1: a migration deletes the verdicts, the app's schema upgrade clears its
  marks, the games are sent again in order).
- **The reason in counts** ("8 right, 6 fast, of 10: up"): *right* is every correct answer,
  *fast* those within the tier's fluent time (full credit), *of* the questions counted — a
  quit's missing ones included. The zone word stays (up, kept, down), with "already at 0 /
  100" and "N left, counted as missed" as before. `OperationQuality` lost its percentages
  (`qualityPercent`, the band's edges) — nothing else read them; the result screen's test
  again forbids any "%".
- **The duel rules once per mode** (`Hint.duelRulesBasics`, `…Advanced`, `…Count`, per
  device like every hint): remembered when the player presses Start, not on Cancel. The
  waiting challenge's Play and a friend challenge use the same per-mode memory.
- **"The find screen" read as Online's duel list** (and a friend challenge's mode picker):
  the reminder "Rated · leaving counts as a loss" sits under the Duels heading with a "Rules"
  link to every mode's rules. The "Finding an opponent…" screen itself shows for well under
  a second once the server is awake (it is always-on from the launch) — too short to read a
  line or tap a link, and a rules sheet opened there would cover a duel whose timer already
  runs.
- **Deploy-window duels: never handed out rather than voided afterwards.** Every request for
  a duel (`find`, `open`) now declares the game and duel rules versions the app can play
  (`knownDuelRules`); the server hands a duel only to an app that knows its own current
  versions — otherwise 409 `appOutdated`, before anything is made, served or marked opened,
  and the app says "A new version of the game is out" with Reload. So no duel can be opened
  by an app that cannot read it: a pool or practice duel is never made, a waiting challenge
  stays unopened (an unopened challenge was never a loss). The owner's rule holds without a
  void path: there is nothing to void. **Production has no duel to void either**: all 30 are
  rules v8 and finished; the one abandoned run is a v8 practice duel of 25 Nov (no rating).
  The cost: a page still open on a 6b build (which declares nothing, and does not know the new
  refusal) says "This duel is not available." on its next duel request until it is reloaded —
  once, after this deploy; nothing is lost.
- **`submitted_value` INTEGER** (local schema v14): SQLite cannot change a column's type, so
  the `answers` table is rebuilt within the upgrade's transaction — same rows, the value cast
  (every one was written from an int), the same index; the repository reads it as an `int`.
  Supabase never had the column (answers travel in the JSON payload).
- **Semantics on a low-end phone profile** — **kept on for everyone: no real cost found.** Measured with
  `tool/perf/semantics_cost.mjs` (Edge headless, Chrome DevTools' low-end mobile CPU — 6×
  slower —, 360 × 780 at 2×, cache off, files from localhost, a local stand-in for Supabase;
  two release builds, the second with `SEMANTICS_ALWAYS=false`; 5 visits each, alternated; a
  game of 10 answers 1.6 s apart):

  | 5 visits each | semantics on | off |
  |---|---|---|
  | first frame, median (range) | 3.00 s (2.56–4.55) | 3.53 s (2.83–10.85) |
  | main thread busy until the first frame | 2.50 s | 2.22 s |
  | game: frame interval p50 / p95 / p99 | 16.7 / 33.3 / 66.6 ms | 16.7 / 33.4 / 66.7 ms |
  | game: frames over 50 ms | 1.4 % | 2.3 % |
  | game: main thread busy per second | 483 ms | 483 ms |
  | game: DOM elements | 57 | 36 |

  The first frame and every game figure are the same within the noise; the one consistent
  difference is about 0.3 s more work before the first frame (a first trial: 0.1 s) and 21
  more elements. "If the cost is real" (plan v4.1): it is not, on this profile, so the
  owner's rule keeps semantics on. **Limits**: an emulated slow CPU on a desktop is not a
  real low-end phone (its GPU, memory and thermal limits are not emulated) — one look on a
  cheap Android phone is in the owner's checklist. A first run of 5 visits, taken while other
  work loaded the machine, varied from 3 to 25 s and was discarded. `SEMANTICS_ALWAYS` stays
  as a build switch (default on): the fallback, should a real phone disagree.

**Commit 1 — the name as a single setting.**

- **`Brand` is Dart, the web files are generated from it** (a tool, like the icons), and a
  test fails while they differ — rather than a JSON file read by both the build and the
  app: the app needs the name as a compile-time constant in its strings, and a generated,
  checked-in page is what Cloudflare serves without a build step of its own. Changing the
  name: edit `Brand`, run `flutter test tool/brand/write_brand_test.dart`, commit (switch-on
  commit 7).
- **It lives in `presentation/strings/`**: the name is a word players read; the strings
  guard already covers that folder, and the brand test forbids the name as a literal
  anywhere else in `lib/`.
- **The link preview**: Open Graph and Twitter tags with an image of the operator family and
  the name; its address is absolute only when the build knows the site's address
  (`SITE_URL`), because most unfurlers ignore a relative one — production gets the Pages
  address now, the domain after the switch-on (the repository variable `SITE_URL`).
- **The short name equals the name** ("Math Trainer", 12 characters, fits under an icon);
  a longer confirmed name gets its own short form here.
- **The old address's redirect page** (`tool/preview_redirect/`, GitHub Pages, off since
  the repository went private) still says "Math Trainer has moved": it is published only by
  the switch-on's redirect step, which writes its text then.

**Commit 2 — privacy policy and legal notice (B1).**

- **The pages are Dart strings, one class per language** (the owner's rule for strings,
  plan v4.1), not Markdown files or a web page: they read the same offline, inside the app,
  and a French page that misses a paragraph does not compile. A test also holds both
  languages to the same sections, paragraphs and owner details.
- **Placeholders are marks in the text** (`⟦contactEmail⟧`), filled from one map per language
  (`LegalDetails.given`) — a value can differ by language (a date, a region's name). Until
  filled: highlighted, in brackets, bold (never colour alone), said "not filled in yet", and
  a "Draft" banner on the page. Nothing shows the drafts' `[[…]]` syntax.
- **What is filled already**: the hosts' company names (Cloudflare, Inc.; Render Services,
  Inc., United States — `render.yaml` sets no region, Render's default is Oregon; Supabase,
  Inc.), the processors' roles, the rights, the CNIL, the 30-day guest deletion (read from
  `abandonedGuestRetention` by a test). Owner-only facts stay placeholders, Cloudflare's
  address included (the old draft's address was marked "to verify").
- **The legal bases**: the service (contract, 6(1)(b)) for play, levels, boards, duels,
  friends and the account; legitimate interest (6(1)(f)) for fair play, abuse limits, name
  review, keeping finished duels for opponents, and calibration — as the Phase 5.2 draft
  argued; no consent-based processing, so no consent banner. For the review.
- **The age box is on Save your progress only**: it is where an account is created (a
  guest gives nothing; signing in reaches an existing account). It is required, unticked by
  default, and its moment is kept in the account's metadata (Supabase `user_metadata`), sent
  in the same call as the email — no account without it. **Accounts saved before** (7
  testers) declared nothing: not asked again (adult testers; to ask, a one-time prompt at
  sign-in would do).
- **The language** opens as the device's (French on a French device, English otherwise),
  with a switch; the rest of the interface stays English until 6d.
- **The Phase 5.2 drafts are removed** (`doc/legal/privacy-policy.md`,
  `legal-notice.md`): two versions would drift. Their review questions moved to
  `doc/legal/README.md`, updated (the language and the age are decided).

**Commit 3 — Turnstile, email confirmation ready, an unconfirmed account a guest (B2).**

- **Turnstile in the page, asked for by the app** (`window.mtHumanCheck`, like the boot
  sign-in): no Dart dependency, the widget is the page's own element over the canvas,
  "interaction-only" (most players never see it). Asked before every call Supabase's CAPTCHA
  protection covers — anonymous sign-in (sign-up), password sign-in, a resent link (and the
  recovery email, commit 4) — not only the two the plan names: once the protection is on,
  Supabase refuses those calls without a token. Refreshing a session needs none.
- **The page's early sign-in steps aside when Turnstile is on**: the app makes the guest
  with a token after it starts — the first visit loses the overlap of the sign-in with the
  download (about a second on slow 4G). Getting the token in the page during the download
  would win it back; not done now (the switch is off until launch). Also when the address
  holds an email link's session (`access_token`, `error_description`, `code`): a guest
  made there would be a stray account.
- **Staging is on with the test key** (always passes, `1x00000000000000000000AA`): the path
  runs in the staging smoke test. Supabase staging checks nothing until its CAPTCHA
  protection is enabled with the matching test secret — the owner's step; until then the
  tokens are ignored. Production is off.
- **Mobile (rule 16)**: no new dependency; Turnstile has no native SDK — Phase 8 needs a web
  view or another check (`human_check_stub.dart` answers none off the web).
- **Confirmation follows Supabase's answer, no app switch**: when the project requires it,
  linking answers "pending" and the form says "Check your inbox"; when it does not, the
  account is saved at once, as today. The switch is the project's own (Confirm email, with
  the owner's sender).
- **The implicit flow for email links**: Supabase's default (PKCE) only completes in the
  browser that asked; a phone's mail app often opens another. The implicit flow carries
  the session in the link's fragment (never sent to a server).
- **The resend uses the "email change" type**: a guest linking an address is an email
  change for Supabase (the guest stays anonymous until the link is opened). To be confirmed
  on staging with confirmation on (owner's checklist).
- **"Unconfirmed" in SQL is `email_confirmed_at is null`**, beside `not is_anonymous`, in
  the 11 functions that grant something to a saved account — not the owner's dashboard
  views (they report everyone), not the stale-guest cleanup (a pending guest is still
  anonymous and is cleaned as one). A test stub difference: the stub's `auth.users`
  confirms at insert unless a test says otherwise (real Supabase leaves it null).
- **The emails' wording** (templates): short, English, the name from `Brand`; French with
  6d. Subjects are on each file's first line, for the owner to paste.

**Commit 4 — "Forgot password?" (B3).**

- **The link is read from the address at start** (`authLinkFrom`, before
  `Supabase.initialize` consumes it), not from the client's `passwordRecovery` event: the
  event fires during initialisation, before any screen listens, and the auth stream replays
  only its latest event. The address is certain and testable.
- **The new password is asked at once, full screen**, over the game the link opened;
  leaving it keeps the old password (the account stays signed in: the link already proved
  the address). A recovery link on a guest's session (impossible from the app; a stale
  link) does nothing.
- **"Forgot password?" says the same whatever the address**: Supabase answers alike, and
  the screen never says whether an account exists.
- **Supabase's built-in sender until the owner's**: it works now, limited to a few emails an
  hour for the whole project — enough for the beta, not for a launch (the switch-on brings
  the owner's sender).

**Commit 5 — error reporting to our own server.**

- **Nothing about the player**: no account id, no token, no address stored — a report
  helps fix the game, it does not need to know whose game it was. So no consent and no
  link to deletion: reports are kept 30 days, then deleted by the next report's insert.
- **Masked on the server**, whatever the app sends (rule 17): JWTs, `sb_…` keys, bearer
  values, email addresses, `access_token=`/`refresh_token=`/`apikey=`/`code=`/`password=`
  values — an exception's text can carry a URL from an auth error.
- **Bounded three ways**: the app sends the same error once a run and 10 a run at most; the
  server takes 10 an address then one every six minutes; the database keeps 2,000 a day in
  all. A broken release reports enough to be seen, a script cannot fill the database.
- **What is reported**: Flutter's errors (`FlutterError.onError`), anything uncaught
  (`PlatformDispatcher.onError`), a start that failed (main's catch-all), and, from the
  loading page, a script that did not download or an engine that did not start — the
  failures where no Dart runs. Not the watchdog's "still loading" (a slow network is not an
  error). The console keeps its messages (the previous handlers still run).
- **No third-party service** (plan 6.6: no third-party analytics): our server and our
  database.
