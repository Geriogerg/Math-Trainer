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
  before, v2 = `doc/levels.md`): app schema v10 `sessions.rules_version` (NULL = v1), the
  upload's `rulesVersion` (absent = v1), and on the server a column read from the stored payload.
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

### Gaps filled by Claude Code — provisional, for the owner to confirm

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

## Leveling parameters — starting values

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

## One difficulty axis at a time

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

## Per-question timeout: 15 s, counted as wrong

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

## The level step is weighted by answer volume

*Superseded by the Levels phase (`doc/levels.md`), above.*

The formula used a pure mean: 16 additions at 85 % and 4 additions at 85 % moved the level
exactly the same. Counter-intuitive (focusing on one operation should make it progress faster) and
a perverse incentive (enable many types, play minimal sessions).

Fix: the step is multiplied by `√(n / n_min)`. The square root rather than the ratio, so that 64
answers do not move 16 times more than 4 — which would make the system unstable. It is an Elo-like
variable K applied to sample size. Side effect: small-session noise is damped, and four short
sessions give about the same result as a long one.

## `n_min` from 8 to 4 — coupled to `δ`

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

## Placement test (Phase 1, commit 6)

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

## Overall level: unplayed types count as 1

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

## Preview host: Cloudflare Pages (Phase 3a, commit 1) — owner decision pending

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

## Beta gate: a code per device, enforced by the app (Phase 3a, commit 3)

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

## Type placement: the first game on a never-played operation (Phase 3a, commit 7)

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

## Digit typeface: Space Grotesk, cut to digits (Phase 5, commit 1)

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

## Sound: synthesised in the browser, on by default (Phase 5, commit 4)

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

## Strategy detector: the plan's table made exact (Phase 5.1, commit 2) — provisional

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

## Structural features: Dart and SQL, one list of cases (Phase 5.1, commit 3) — provisional

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

## Server-side gate: who is "already in", and a 403 that is not a refusal (Phase 5.1, commit 5) — provisional

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

## Staging: a second project, deploys in order, production smoke read-only (Phase 5.2, commit 1) — provisional

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

## Duel configuration: quotas, a bracket's level, one stream (Phase 5.2, commit 2) — provisional

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

## Glicko-2 on the server (Phase 5.2, commit 3) — provisional parameters

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
