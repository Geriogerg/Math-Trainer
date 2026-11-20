# Math Trainer — Product Plan

> **Owned by the product owner.** This file says *what* the app is, *why*, and *in what order* it
> gets built. Claude Code reads it at the start of every phase and **never edits it**; changes come
> from the owner. The day-to-day working rules live in `CLAUDE.md`, which must always stay
> consistent with this plan (section 11).
>
> Version 2.5 — 20 November 2026: Phase 3a.1 done; Phase 5 detailed with the beta-safety rule.
> Version 2.4 — 19 November 2026: Phase 3a outcome; close-out 3a.1 before invitations; during
> the beta only Phase 5 runs, Phase 4 moves after 3b. Version 2.3 — Phase 2 outcome; Phase 3 split into 3a (build the beta, one
> pass) and 3b (calibrate on its data). Version 2.2 — Phase 1 outcome, Phase 2 revised (self-contained sessions,
> SQL migrations from CI, name charset), English UI. Version 2.1 — phases run in one pass, owner review at the end (section 7
> and 8). Version 2 — revised after the Phase 0 report. Changes from version 1:
> Phase 1 rewritten (continuous levels, first-load work, cross-platform determinism check, placement
> stored as a session, automated preview smoke test); CAPTCHA and email confirmation moved to
> Phase 6; anonymous-player cleanup moved to Phase 2; owner decisions of Phases 0–1 recorded.

---

## 1. Vision

A competitive mental-arithmetic game for teens and adults. Its promise: **get measurably faster at
mental math, and prove it against other players.**

Four pillars, in this order of priority:

1. **Speed.** Sessions of 30 seconds to two minutes, no dead time, nothing between the player and
   the next question.
2. **Visible progress.** A level per operation that honestly reflects skill, and that moves.
3. **Learning.** The app does not only measure: it corrects, teaches strategies and targets
   weaknesses.
4. **Fair competition.** Rankings and duels computed by a server that trusts nothing the client
   claims.

Interface in English (owner decision, Phase 1); French-speaking players remain a key audience. Competitive tone, not a school exercise book.

## 2. Product principles

These hold across every phase. A feature that contradicts one of them is redesigned, not shipped.

- **The level measures skill, not effort.** It rises and falls with performance; it never decays
  with absence; it is never bought or chosen.
- **Never punish absence.** Coming back after weeks costs nothing; the level re-adjusts faster for
  a few sessions instead.
- **Never show accuracy as progress.** Accuracy converges to the target by construction; progress
  is shown as level and response time.
- **The server is the only authority on anything competitive** — levels used for ranking, ranks,
  ratings, duel results.
- **Same seed and same configuration give the same questions**, everywhere, forever. Duels and
  server validation depend on it.
- **Offline first.** Solo play never needs the network.
- **No signal relies on colour alone.**
- **Every expected answer is a whole number.**
- **No dark patterns**: no ads, no streak guilt, no fake urgency.

## 3. The game as it stands

### 3.1 Session

- 7 exercise types: addition, subtraction (never negative), multiplication, division (exact),
  powers, square roots of perfect squares, whole-number percentages.
- The player chooses which types are active (2 by default). Number of questions =
  `n_min × active types` (`n_min` = 4), capped; beyond the cap, types rotate by sampling debt.
- 15 s per question with automatic move to the next; a timeout counts as wrong. Three timeouts in a
  row without any key pressed interrupt the session: it does not count for levels, but answers
  already given are kept.
- Custom on-screen keypad (digits, backspace, validate); physical keyboard on desktop.
- Result screen: level change, score breakdown, right / wrong / timed out, best streak, types
  played. Replay at once with the same types, updated levels and a **new seed**.

### 3.2 Levels

- One level per operation, 1 to 100; an overall level averaging all seven, unplayed counted as 1.
- A level is an estimate of skill: after a session, performance (correctness weighted by speed) is
  compared with a target; the gap moves the level, up faster than down, inside a dead band, with a
  maximum step per session, weighted by `√(n / n_min)` so longer sessions count more.
- New players and returning players move faster for a few sessions (calibration and return boost).
- Levels are **frozen at the start of a session** and stored with it.
- Levels are a cache: fully recomputable from the answer history.
- Difficulty is derived from the level (operand bounds per operation).
- About 20 constants govern this system; all are educated guesses until real data exists.
  Values and reasons: `doc/decisions.md`.

### 3.3 Scoring

Base points, speed bonus, capped streak bonus, difficulty multiplier. The score is session
feedback only; it never ranks anyone — the level does.

### 3.4 Accounts and screens

Supabase accounts (anonymous-first since Phase 1, email linking), player name, Profile
tab with overall level, 30-day curve, per-operation level and average time, recent games.
Day and night themes. Tabs: Play, Online (preview), Profile, Leaderboard.

## 4. Current state (19 November 2026, after Phase 3a)

- Phases 0–2 done: CI (VM and JavaScript, weekly Android compile), preview on GitHub Pages,
  anonymous-first accounts, placement test, continuous levels, monorepo with `packages/math_core`,
  Dart server with replay validation, leaderboard, SQL migrations applied by CI.
- About 1,350 tests (core 548 VM / 541 JavaScript, app 242, server 20, tooling 10, 5 SQL).
- First question on slow 4G from a fresh browser: 26.5 s on the preview.
- Web-only: mobile development is paused.

| Weakness | Why it matters | Fixed in |
|---|---|---|
| Login required before playing | Most first-time players leave before one question | Phase 1 |
| One timestamp per game, not per answer | Blocks spaced repetition and fatigue analysis | Phase 0 |
| Everyone starts at level 1 | An adult's first games are trivially easy | Phase 1 |
| Measures but does not teach | Drilling alone plateaus; players stop improving, then leave | Phases 0 and 4 |
| Level constants are guesses | The leaderboard would rank on unvalidated numbers | Phase 3 |
| Stock components, generic name | Looks like a template; the name cannot be found or protected | Phase 5 |
| No CI | Nothing checks the repo on a clean machine | Phase 0 |
| `δ` possibly not widened when `n_min` went 8 → 4 | Levels jitter more than designed | Phase 0 |

## 5. Strategy: web-first, mobile-ready

Android and iOS stay the long-term targets. **Until mobile development is possible again, the web
build is the product.**

**Why it is not a detour.**

- A hosted URL opened in a phone browser lets real people play with no store review and no 14-day
  closed test.
- An invite-only web beta produces the real sessions calibration has been waiting for.
- The owner tests on his own phone by opening the preview URL.

**What it changes.**

- Mobile web (Chrome on Android, Safari on iPhone) is the reference device for every UI decision.
- Every push to `main` deploys a preview URL; checkpoints are played there.
- Native capabilities sit behind interfaces with a web implementation or a no-op: haptics (absent
  in Safari on iOS), sound (needs a first user gesture), push notifications (deferred).
- Browser storage can be evicted (Safari in particular); until server sync exists, local history
  is at risk. Persistent storage is requested where supported.
- A Flutter web build downloads several megabytes before its first frame; load time is measured
  and a loading screen shows progress.

**Guardrails that keep mobile cheap to return to.** A scheduled CI job compiles the Android APK
once a week and on demand (not on every push, to keep CI fast);
web-specific code stays in the infrastructure layer; no dependency without Android and iOS
support unless its mobile replacement is identified; touch-first input.

## 6. Product direction

### 6.1 Mental math: from quiz to coach

People get faster through instant recall of core facts, explicit strategies and immediate
correction. All of it is built from data already stored, in the pure-Dart core, with no AI at
runtime.

- **Correct every error.** On a wrong answer or a timeout only, the correct answer stays visible
  about one second; correct answers keep the fast flow. The result screen lists the mistakes with
  their answers.
- **Fact fluency.** Fluent mental math rests on a few hundred facts retrieved without computing:
  bonds to 10 and 100, tables to 12 × 12, squares to 25², friendly percentages. Each fact is
  tracked by its own latency and errors, and slow facts come back more often (spaced repetition).
- **Strategies, not just answers.** A detector picks the best move for a generated exercise and
  shows it as a one-line tip after an error or a slow answer:

  | Strategy | Example | Triggered when |
  |---|---|---|
  | Compensation | 47 + 68 = 47 + 70 − 2 | an operand ends in 7, 8 or 9 |
  | Subtract via a round number | 603 − 298 = 603 − 300 + 2 | the subtrahend is near a round number |
  | Doubling and halving | 25 × 16 = 100 × 4 | a factor is 5, 25 or 50 |
  | Split the factor | 7 × 46 = 280 + 42 | one-digit × two-digit |
  | Square near a base | 48² = 2500 − 200 + 4 | the base is near 50 or 100 |
  | Difference of squares | 47 × 53 = 50² − 3² | factors sit evenly around a round number |
  | Swap the percentage | 8% of 25 = 25% of 8 | the swapped form is a friendly percentage |

  Later, technique drills: sessions generated to train one strategy.
- **Difficulty is structure, not size.** 47 + 38 is harder than 45 + 32 because of the carry.
  Generation gains structural features: carries or borrows, digits 6–9 in factors, distance from a
  round number. Long term, item difficulty is estimated from answers with an Elo-style update of
  both players and items, as the Math Garden adaptive-practice system does.
- **Fast-guess penalty, only on evidence.** The high-speed-high-stakes rule (score =
  (2 × correct − 1) × time left) makes a fast wrong answer cost as much as a fast right one earns.
  Typed answers invite little guessing; adopted only if the data shows spam-typing.
- **Placement test.** 60–90 seconds, adaptive, across three or four operations, sets the starting
  levels and doubles as onboarding.
- **Timeout scaled to the level**, derived from measured response times.

### 6.2 Design: from a theme to an identity

The "nuit électrique" direction (`doc/design.md`) stays the authority on palette, typography,
notation, layout and durations. Identity comes from four levers.

- **A display typeface for digits** — operations, answers, scores, levels — with Inter for
  interface text. Criteria: tabular figures, 1 and 7 unmistakable, 6/8/9/0 distinct at speed.
  Candidates: Space Grotesk, Sora, Manrope, JetBrains Mono. Bundled, never fetched at runtime.
- **A five-component kit** replacing stock Material in those roles: `AppButton`, `TypeChip`,
  `KeypadKey`, `StatTile`, `LevelBadge`.
- **Operators as the icon system**: + − × ÷ x² √ % in the accent colour; favicon and app icon from
  the same family.
- **A loop that feels alive**: key tick, a correct chime whose pitch rises with the streak, a low
  tone on error (on by default, one toggle); the streak counter and timer bar intensify at 5, 10
  and 20; a level-up moment with its own sound; haptics where the platform has them.
- **A real name** before the public launch: short, easy to say in French and English, free as a
  domain and on both stores. "Math Trainer" describes the app but cannot be found or protected.

### 6.3 Accounts and first run

- **Anonymous-first.** On first launch the app silently creates a Supabase anonymous user and the
  player answers a question at once. No form, no name. Replaces the mandatory login of step 6
  slice 2. On web the first visit is online by nature; if the anonymous sign-in fails, a retry
  screen appears.
- **Linking keeps the same user id**, so no data moves. The Profile tab offers "Save your
  progress": email, password and player name. Later the leaderboard offers it too, since only
  linked players appear on it.
- **Email already used**: the player can sign in to that account instead, after a clear warning
  that this browser's guest progress will be replaced. No merging of two histories in v1.
- **An anonymous player has no sign-out** (it would lose the account). They get "Delete my
  data" instead.
- **Existing email accounts keep working**, with sign-in reachable from Profile.
- **In-app account deletion** for every player, anonymous included: account, profile, server data
  and local history. Done through a database function that deletes only the caller's own
  account, so no service key ever reaches the app.
- **Abuse protection**: Supabase's built-in rate limit on anonymous sign-ins until the public
  launch; CAPTCHA or Turnstile from Phase 6.
- **Stale anonymous players** are cleaned up only once the server knows their activity (Phase 2).
  Deleting them earlier risks deleting someone who still plays.
- **Email confirmation with a real SMTP sender** needs a sending domain, so it arrives with the
  domain in Phase 6. Until then, linked emails are unconfirmed — acceptable for an invite-only
  audience, not for a public one.

### 6.4 Rankings

- Ranked on **level**, computed by the server. One overall board, one board per operation.
  Ordered on the continuous level value, displayed as an integer.
- **Eligibility**: a minimum of sessions per operation and play within the last 30 days. Inactive
  players leave the board; their level never decays.
- **Default view**: the player's percentile plus the five players above and below. Top 100 in a
  second tab; friends later. No weekly leagues in v1 — they reward volume, not skill.
- **Upload**: after every finished or interrupted session, through an offline queue with retries,
  idempotent on the session id.
- **Validation**: the server regenerates the exercises from the seed with the same core, rechecks
  every answer, replays the level updates and writes the rows. A mismatch is rejected and flagged.
  Everyone reads the board; only the server writes it.
- **Anti-cheat, honestly**: replay stops forged results, not a calculator in solo play. Implausible
  timing (multi-digit answers under ~300 ms, unnaturally flat times) is flagged for review, never
  auto-banned.
- **Player names are public content**: name filter and report action before the board opens.

### 6.5 Online play

- **v1 — ghost duels.** Race a real player's recorded run, replayed live at its original pace.
  Needs nobody else online; the interface says so plainly ("Race Léa's best run").
- **A duel is configured differently from solo**: fixed quotas per type, difficulty from the
  rating bracket, never from either player's levels; 10 questions, 3–4 types; same seed and duel
  configuration give identical questions on both sides.
- **Rating: Glicko-2**, server-side only, provisional for the first ~10 duels. Rating and level are
  two numbers on two screens: the level says how good you are at each operation, the rating how
  you fare against others.
- **v2 — friend challenges**: a link, same seed, 48 hours to answer.
- **v3 — live duels**, only when enough players are online together for queues under ~20 s. A
  player who drops is replaced by their recorded progress, then their ghost.

### 6.6 Business and legal

- **No ads, payments or third-party analytics before online play ships.** Usage numbers come from
  the server's own tables. Monetisation is decided on retention data; candidates that do not
  distort the ranking: ad removal, detailed statistics, cosmetic themes. **Never** a paywall on an
  exercise type — it would make the overall ranking a ranking of subscribers.
- **Public launch requires** a privacy policy, a legal notice (French publisher), in-app account
  deletion, email confirmation with a real sender. Teen users: France sets the age of digital
  consent at 15 — check what applies before opening public sign-ups.
- **Stores, later**: Google Play requires a 12-tester, 14-day closed test for a new personal
  account; Apple requires in-app account deletion and a build signed on a Mac (cloud build
  service).

### 6.7 Permanently out of scope

Fractions and Euclidean division (non-integer or composite answers).

### 6.8 Ideas kept for later, not planned

Seasons (soft reset of rating uncertainty), tournaments, daily challenges, badges, leagues ranked
on practice time (clearly separate from skill), technique courses, an explanation library for
strategies. Each is reconsidered after Phase 7 against the principles of section 2.

## 7. Roadmap

```
P0 ─ P1 ─ P2 ─ P3a Build beta ─ 3a.1 Close-out ─ invitations ─┬─ beta runs 2–3 weeks ─┬─ P3b Calibrate ─ P4 Learning ─ P6 Public ─ P7 Online
                                                                └─ P5 Identity ─────────┘
P8 Return to mobile: whenever mobile development is possible again (independent of P6 and P7).
```

**Each phase runs in one pass** (from Phase 1 on): Claude Code works through all its commits
without waiting, and the owner reviews once, at the end. *(A)* = judged by tests. *(C)* = judged by
playing: deployed to the preview URL and played by the owner at the end of the phase, from the
checklist in the phase report.

### Phase 0 — Stabilise and build the web pipeline

**Goal:** a clean base, checked automatically, with a preview URL playable on a phone.

0. *(C)* Docs: create `doc/progress.md`; bring `doc/online.md` and `doc/decisions.md` in line with
   this plan (anonymous-first, Glicko-2, ghost duels first, monorepo, web-first, no ads in v1),
   each decision with its reason and a "reopen when"; list remaining contradictions.
1. *(A)* CI on GitHub Actions: core tests, all tests, analyze, web build, Android debug build
   (compile-only), on every push. Supabase settings from CI secrets.
2. *(A)* Preview deployment of the web build on every push to `main`, stable URL. Host proposed
   with its reason.
3. *(A)* `material_ui` migration, zero analyzer notices afterwards.
4. *(A)* One timestamp per answer. Schema migration only after asking.
5. *(A)* Check `δ` against `n_min` = 4; any new value proposed, never applied without approval.
6. *(A)* Debug-only switch disabling the timeout, proven inert in release builds.
7. *(A)* Hooks refusing `assert(` in the core and unseeded `Random(`; formatting after edits;
   reviewer subagent checking diffs against the architecture rules.
8. *(A)* First-load size and time measured; persistent browser storage requested.
9. *(C)* Correct answer shown on error or timeout; mistakes review on the result screen.

**Exit:** CI green on every push; preview URL live; the owner plays 5 games on a phone browser.

**Phase 0 outcome (19 November):** code done; CI green. Owner decisions taken: `material_ui`
migration approved; `δ` stays 0.07. Still open when Phase 1 starts: GitHub Pages switched on,
preview checked online, load time re-measured, the owner's 5 games. Two findings reshape
Phase 1: a new player needs 45–90 games to reach their real level (target 10–20), caused by
integer rounding of the level rather than by `δ`; and the first visit takes ~5 s on fast 4G and
~19 s on slow 4G with a blank screen, partly because CanvasKit and a font load from Google's
servers.

### Phase 1 — First run and accounts

**Goal:** a new player answers the first question within 30 seconds, with no form, and their
level matches their skill within a few games.
**Entry:** Phase 0 closed — the open items above are done (commit 0 below finishes them).

0. *(C)* Close Phase 0: `material_ui` migration, `δ` = 0.07 recorded, preview verified online,
   load re-measured, the owner's 5 games.
1. *(A)* **Cross-platform determinism.** The core tests also run compiled to JavaScript in CI. A
   test pins the exercise sequences for a fixed set of (seed, config) and must give identical
   results on the Dart VM and in JavaScript. Players generate on the web; the server will replay
   on the VM — any difference would reject honest sessions in Phase 2. Any mismatch blocks the
   phase.
2. *(A)* **Continuous levels.** The level is kept in hundredths, as an integer, in the core, the
   level cache and the frozen session config; it is displayed as a whole number, and generation
   reads its whole part. The update computes with +, −, ×, ÷ and square root only (exactly
   reproducible across VM, JavaScript and WebAssembly), then rounds once to hundredths. Existing
   levels are migrated ×100; old sessions stay readable. The convergence simulation is rerun and
   reported.
3. *(A)* **First load.** CanvasKit and fonts served from the app itself, with no request to Google
   at runtime; Inter bundled; a loading screen with visible progress before Flutter starts;
   load re-measured on fast and slow 4G profiles.
4. *(A)* **Anonymous-first sign-in**, as designed in section 6.3. Local data keyed by the Supabase
   user id; existing email accounts unaffected and tested.
5. *(C)* **Linking and account screens** in Profile: save progress (email, password, name), sign
   in to an existing account with the replacement warning, no sign-out for anonymous players.
6. *(C)* **Placement test**, offered on first launch with a "Passer" option, only to a player
   without history. 60–90 s on the four basic operations, one adaptive staircase per operation
   (about 6 questions each, step halving after every answer). Stored as a session of its own
   kind; a pure core function turns its answers into starting levels, so levels stay
   recomputable from history and replayable by the server. Powers, roots and percentages start
   where they do today and use the calibration boost.
7. *(A)* **Account deletion**, anonymous included, through a database function the owner runs
   once in Supabase; local data wiped; a fresh anonymous player created afterwards.
8. *(A)* **Automated smoke test** in CI after every preview deployment: fresh browser, anonymous
   start, a full game with the timeout switch off, a reload, history still there.

**Exit:** on a throttled slow-4G profile from a fresh browser, the first question appears in under
30 s; the smoke test is green; an anonymous player links an email and keeps their history; the
rerun simulation shows a placed player at their level within about 10 games.

### Phase 1 outcome (19 November)

All nine commits delivered; 637 tests; VM and JavaScript identical on 206 pinned cases. Placement
brings a new player to their level in 5–19 games instead of 65–74. Open at the start of Phase 2:
the publishable-key secret, the deletion SQL, the owner's play-through, the test accounts.
Owner decisions on the provisional choices:

- Placement parameters kept (start 35, first step 25, boost on 3 games), but **5 questions per
  operation** to bring it near 80 s, and the "fast" threshold **per operation** (from `t_rapide`),
  not a flat 3 s — a flat threshold places players lower on multiplication and division.
- A skipped placement is remembered; it can be taken later from Profile while the player has no
  completed game. **An interrupted placement does not count**: it is offered again.
- Result screen: the level stays a whole number; progress inside the level is a bar, not
  "(+2.76)".
- Guest games kept hidden on the device after signing in elsewhere: accepted; they are deleted
  with the guest account (Phase 2 cleanup).
- Player name required when saving progress: accepted.

### Phase 2 — Server and leaderboard

**Goal:** every leaderboard row computed by the server from replayed answers.

0. *(A)* **Close Phase 1**: the owner decisions above; the type-selection flash before the
   placement offer; test accounts deleted.
1. *(A)* **Self-contained sessions.** Everything that decides the question order (the per-type
   game counts used by rotation, or the type sequence itself) is stored with the session, so a
   single session replays from (seed, stored config) alone — rule 2. Old sessions stay readable.
   A test replays every stored session in isolation.
2. *(A)* **SQL migrations from CI.** Supabase SQL lives in versioned migrations applied by CI on
   `main` (access token and database password as GitHub secrets, never printed). Existing files in
   `supabase/` become the first migrations. From then on no SQL is run by hand.
3. *(A)* Core extracted to `packages/math_core`; monorepo `app/`, `packages/math_core/`,
   `server/`; no behaviour change.
4. *(A)* Dart server skeleton (`shelf`, container, CI). Host and monthly cost **prepared, not
   deployed, until the owner confirms** (a decision that costs money).
5. *(A)* Session upload: offline queue, idempotent endpoint, `syncedAt`.
6. *(A)* Server replay and validation; a forged upload rejected by a test.
7. *(A)* Tables and access rules: continuous level per player and operation, rank and percentile;
   only the server writes.
8. *(C)* Leaderboard screen: percentile, neighbours, top 100, per operation.
9. *(A)* Name filter (including a character set limited to what the bundled fonts cover)
   and report action.
10. *(A)* Only linked players appear on the leaderboard; it offers anonymous players to save their
   progress.
11. *(A)* Cleanup of anonymous players with no uploaded session for 30 days, with their hidden
    guest games.
12. *(A)* Android compile-only CI job, weekly and on demand.

**Exit:** rows reproduced by replay; forged upload rejected; the owner sees their rank on a phone.

### Phase 2 outcome (19 November)

All 13 commits delivered, CI green, including the first Android compile (which caught an outdated
Gradle setup). Proven by tests, not yet live: waiting on two owner actions (database secrets in
GitHub, server deployed on Render). Owner decisions on the provisional choices:

- Pass time per operation = 1.5 × `t_rapide`: kept; all equal (3 s) until Phase 3b gives each
  operation its own `t_rapide`.
- A session whose levels don't follow from the server's is refused and the app adopts the
  server's levels: kept for the beta. Fix in 3a: the app fetches the server's levels before each
  game when online, so a second device stops losing games.
- Eligibility: played within 30 days, 3 counted games per operation (3 completed games overall):
  kept.
- Names: Latin, Greek, Cyrillic only; short English/French blocklist; 3 reports hide a name until
  reviewed: kept for the beta. Wider alphabets reconsidered before Phase 6.
- Guest cleanup also requires no session renewed in 30 days: kept.
- Server host: Render free plan (sleeps after 15 min idle; uploads run in the background).

### Phase 3a — Build the beta (one pass)

**Goal:** everything invited testers need, before the first invitation goes out.
**Entry:** Phase 2 live — secrets set, server on Render, the owner has seen their rank.

0. *(A)* Close Phase 2: plan-alignment fixes; leaderboard board chips on one line on a phone.
1. *(A)* **Move the preview to a free host that serves brotli** — proposed with measurements
   (first question on slow 4G), applied after the owner confirms. **Must happen before any
   tester arrives**: browser data and guest accounts are tied to the origin, so a later move
   would lose every tester's local history and session. Supabase site URL and redirects updated.
2. *(A)* **Server levels fetched before each game** when online; refused sessions explained in
   the app.
3. *(A)* **Beta gate**: an invitation code asked once, before the anonymous sign-in; codes in a
   table, one per tester or group, with a use limit, so each tester's data can be followed.
4. *(A)* **Short privacy notice** in the app: what is stored, why, how to delete it. Real people
   are now giving data, even in a beta; the full legal pages stay in Phase 6.
5. *(A)* **In-app feedback field**, stored server-side with the app version.
6. *(A)* **Owner dashboard** as SQL views plus a script printing a report: sessions per day,
   active testers, median time per operation and level band, abandonment rate, refused
   sessions, names reported and awaiting review (with the SQL to approve or rename).
7. *(C)* **First game on a never-played type acts as a short placement** for that type (powers,
   roots and percentages otherwise take ~65 games to climb from level 1).
8. *(A)* **Data check**: a script verifies that everything Phase 3b needs is stored per answer
   (operation, level, time, correctness, structure of the exercise) and reports any gap.

**Exit:** a fresh invited tester goes from the link to a ranked game on a phone; the dashboard
report runs on live data; the owner sends the invitations.

### Phase 3b — Calibrate on real data (after 2–3 weeks of beta)

**Entry:** at least ~300 completed sessions from at least 10 testers (checked by the dashboard).

1. *(C)* Recalibration with `tool/recalibrate.dart` on server data: new constants proposed with
   evidence (before/after convergence, jitter, bias), applied only after approval, documented.
2. *(C)* `t_rapide` per operation, then the timeout derived from the level, from measured times.
3. *(A)* Server levels recomputed for every player with the new constants (levels are a cache).
4. *(A)* Feedback triaged into a list for the owner.

**Exit:** constants updated with documented evidence; testers' levels recomputed.
Only Phase 5 runs during the beta. Phase 4 changes how players answer (tips, spaced repetition,
new difficulty features) and would mix two versions of the game in the calibration data, so it
starts after 3b.

### Phase 3a outcome (19 November)

All nine commits delivered, CI green, server live on Render, first question on slow 4G 23.1 s.
The repository is public: anything committed is public, so tester data stays out of CI logs and
the dashboard runs locally. Owner decisions on the provisional choices:

- Preview host: **Cloudflare Pages, yes** (brotli, ~4.6 s less on slow 4G). Moved before any
  invitation.
- Type placement for every never-played operation, already-played ones sitting out that game,
  same constants as the main placement: kept.
- Gate enforced by the app only, codes stored readable, asked once per device: kept for an
  invite-only beta. Server-side enforcement before Phase 6 if the gate stays.
- Names: an approved name is never hidden again; a cleared name is removed until a new one: kept.
- Timing-flag thresholds and the 03:17 UTC cleanup schedule: kept.
- **Data gaps closed before invitations**: input device, app version and the timeout in force are
  stored with every answer. Answers played without them cannot get them back.

### Phase 3a.1 — Close-out before invitations (done, 19 November)

Preview on Cloudflare Pages (`math-trainer-kjc.pages.dev`; the GitHub Pages address redirects).
Input device stored per answer, app version per session (schema v8). The timeout in force is not
stored: it is 15 s for every answer until Phase 3b, which stores it when it starts to vary.
Owner steps for the invitations: one code per tester, `SMOKE_BETA_CODE`, `BETA_GATE=true`, the
phone checklist.

### Phase 4 — Learning layer

1. *(A)* Strategy detector, one test per strategy of section 6.1.
2. *(C)* Tips after an error or a slow answer.
3. *(A)* Per-fact tracking and spaced resurfacing.
4. *(A)* Structural difficulty features.
5. *(C)* Technique drills.

**Exit:** a report, from beta data, of whether players who saw tips got faster on targeted facts.

### Phase 5 — Identity

**Goal:** the app is recognisable at a glance and the game loop feels alive — without changing
how players answer.
**Runs during the beta.** Entry: invitations sent (or about to be; nothing here depends on them).

**Beta-safety rule — the calibration data must stay comparable.** Nothing in this phase may
change: the keypad's key positions, sizes and spacing; the input paths (keypad, physical
keyboard); question order and difficulty; the 15 s timeout; the length of the correction pause;
the moment the next question appears. A golden or layout test pins the keypad geometry before
any restyling, and must still pass after. Every build already records its app version, so the
dashboard can split data before and after this phase.

0. *(A)* **Pin what must not move**: a layout test on keypad geometry and on the session screen's
   question and answer positions; a test that sound and haptics never delay the next question.
1. *(A)* **Digit typeface.** A specimen screen (debug and preview builds only, never release) shows
   the session screen's digits in Space Grotesk, Sora, Manrope and JetBrains Mono side by side,
   with the confusable glyphs (1/7, 6/8/9/0, 3/8) at play size, in both themes. Choose
   provisionally by the criteria of section 6.2 (tabular figures, unmistakable glyphs at speed,
   weight 500 legibility, file size, OFL licence); bundle only the chosen face, subset to digits
   and the operator glyphs if that saves weight. Inter stays for interface text. The first-load
   budget must not grow by more than 50 KB.
2. *(A)* **Five-component kit**: `AppButton` (primary, secondary), `TypeChip`, `KeypadKey`,
   `StatTile`, `LevelBadge`, all from the theme tokens of `doc/design.md`; every screen moved to
   them; stock Material buttons and chips no longer used in those roles. Golden tests for each
   component in both themes. `KeypadKey` keeps the pinned geometry exactly.
3. *(A)* **Operator icon system**: + − × ÷ x² √ % drawn in the accent colour as one family, used on
   type chips, Profile rows and leaderboard boards; favicon and web app icons from the same
   family.
4. *(C)* **Sound**: key tick, correct chime whose pitch rises with the streak, low tone on error or
   timeout, level-up sound. Short, quiet, mixed so that 20 questions in a row never tire. Audio
   unlocked on the first tap (browser rule); one toggle in Profile, **on by default**, remembered;
   silent when the page is hidden. Self-made or CC0 sounds only, licence recorded.
5. *(C)* **Haptics** behind an interface: light on key, success on correct, warning on wrong, where
   the browser supports vibration (Chrome on Android); a no-op elsewhere (Safari on iPhone). Its own
   toggle in Profile, on by default.
6. *(C)* **Streak escalation and level-up moment**: the streak counter and the timer bar
   intensify at 5, 10 and 20 in a row (colour step and a short pulse, never a delay); the level-up
   on the result screen uses `AppMotion.levelUp` (600 ms) with its sound. Respect the system's
   reduced-motion setting: no pulse, instant transitions.
7. *(A)* **Web app manifest**: name, icons, theme and background colours, standalone display, so
   the app can be added to a phone's home screen; checked on Chrome Android and Safari iPhone
   (Safari uses its own apple-touch-icon).

**Exit:** the layout pins still pass; golden tests on every kit component in both themes; first
load within +50 KB of Phase 3a; the owner confirms the typeface and approves the feel on a phone
(sound, haptics, streak, level-up).

### Phase 6 — Public web launch

**Entry:** Phases 3–5 done; name chosen; domain bought.

1. *(A)* Production deployment on the domain, separate from preview.
2. *(A)* Privacy policy and legal notice pages, linked in the app.
3. *(A)* CAPTCHA or Turnstile on anonymous sign-in and sign-up.
4. *(A)* Email confirmation on, with a real SMTP sender on the domain and the site URL set.
5. *(A)* Beta gate removed; abuse protections verified.
6. *(C)* Launch checklist run on a phone from a fresh browser.

### Phase 7 — Online play

1. *(A)* Duel configuration in the core, determinism tested.
2. *(A)* Duel runs stored and validated by the server.
3. *(A)* Glicko-2 on the server, provisional flag.
4. *(C)* Ghost duel screen.
5. *(C)* Friend challenges by link.
6. Live duels when the owner decides concurrency allows it.

### Phase 8 — Return to mobile

**Entry:** the owner says mobile development is possible again.

1. *(C)* Android on a device or emulator; fix what compile-only CI could not catch.
2. *(A)* Native haptics and sound behind the Phase 5 interfaces.
3. *(A)* Store assets, data-safety form, account deletion link.
4. *(C)* Google Play closed test, then production.
5. *(C)* iOS through a cloud Mac build service; TestFlight, then App Store review.

## 8. Decisions that belong to the owner

In one-pass mode Claude Code does not wait: it picks the best option with evidence, records it
as **provisional** in `doc/decisions.md`, and the owner confirms or reverses it in the phase
report. Exceptions — decisions that cost money or are hard to undo (server host and budget, app
name and domain, ads or payments) are prepared but not applied until the owner confirms.

| Decision | Needed before |
|---|---|
| ~~`δ` value~~ — decided: stays 0.07 | Phase 0 |
| ~~Preview host~~ — decided: GitHub Pages | Phase 0 |
| ~~`material_ui` migration~~ — decided: yes | Phase 0 |
| ~~Anonymous-first design~~ — decided: section 6.3 | Phase 1 |
| ~~Continuous levels in hundredths~~ — decided: yes, schema migration approved | Phase 1 |
| ~~Placement parameters~~ — decided in Phase 1 outcome | Phase 1 |
| ~~Server host and budget~~ — decided: Render free plan | Phase 2 |
| ~~Brotli preview host~~ — decided: Cloudflare Pages | Phase 3a |
| ~~Input device, app version, timeout stored~~ — decided: yes | Phase 3a.1 |
| Wider name alphabets (bigger bundled font) | Before Phase 6 |
| New level constants | Phase 3b, commit 1 |
| Server-side gate enforcement | Before Phase 6 |
| Digit typeface (provisional pick, owner confirms) | Phase 5 |
| Sound on by default | Phase 5 |
| App name and domain | Phase 6 |
| Opening live duels | Phase 7, step 6 |
| Ads, payments, analytics | After Phase 7 |

Any gap Claude Code fills with its own choice is listed in the phase report and confirmed by the
owner. Silence never turns a guess into the product.

## 9. Risks and open questions

| Risk | Mitigation |
|---|---|
| Browser storage wiped before server sync exists | Persistent storage request (P0); server backup (P2) |
| Too few beta testers for calibration | Recruit 10–20 people before Phase 3 starts |
| Flutter web too slow on first load | Slow 4G: 23.1 s to first question (P3a); ~18 s expected on Cloudflare (P3a.1) |
| Player names in scripts Inter does not cover show as boxes | Name charset restricted to Inter's coverage (P2) |
| Generation or level maths differ between web (JavaScript) and server (Dart VM) | Cross-platform determinism test in P1; levels in integer hundredths |
| Levels take too long to settle | Continuous levels and placement test in P1; recalibration in P3 |
| Unconfirmed emails during the beta | Invite-only audience; confirmation with the domain in P6 |
| Not enough players online for duels | Ghost duels first; live duels only on measured concurrency |
| Cheating in solo rankings | Server replay, timing flags; robust ratings come from duels |
| Teen users and consent rules | Check before public sign-ups (P6) |
| First iOS build on unknown ground | Budget time in P8; cloud Mac build service |
| A single developer's bandwidth | Strict phase order; checkpoints kept few |

## 10. Owner actions outside the code

- Keep the repo on GitHub (CI and preview deployment depend on it).
- Invite 10–20 beta testers at the end of Phase 3a.1, one code each (`dashboard.sh new-code`).
- Choose the app name and buy the domain before Phase 6.
- Choose the digit typeface before Phase 5.
- Play the preview URL on a phone at every checkpoint.

## 11. Keeping CLAUDE.md aligned with this plan

`CLAUDE.md` is the working file Claude Code reads every session and updates regularly. At the end
of every phase, Claude Code checks it against this plan and reports, in the phase report, any of
the following:

- a rule in `CLAUDE.md` that contradicts a principle of section 2;
- a current phase, goal or exit test that differs from section 7;
- an owner decision of section 8 that `CLAUDE.md` treats as settled without the owner;
- a direction of section 6 that the code or `CLAUDE.md` has drifted from;
- anything in this plan that reality has made obsolete — for the owner to update.

The owner reads that report and decides: fix `CLAUDE.md`, or update this plan.