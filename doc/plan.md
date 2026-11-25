# Math Trainer — Product Plan
 
> **Owned by the product owner.** This file says *what* the app is, *why*, and *in what order* it
> gets built. Claude Code reads it at the start of every phase and **never edits it**; changes come
> from the owner. The day-to-day working rules live in `CLAUDE.md`, which must always stay
> consistent with this plan (section 11).
>
> Version 3.7 — 25 November 2026: Phase 7 (asynchronous duels, three rated modes, friends) detailed and next; mockups in
> `doc/mockups/online.html`. Version 3.6 — 24 November 2026: Phase 4 outcome and close-out.
> Version 3.5 — 24 November 2026: Phase 3b becomes a data check, not a blocker; Phase 4 redesigned
> (weak spots, drills) and next. Version 3.4 — 23 November 2026: Patterns and Method outcome; spec-conformance rule.
> Version 3.3 — 23 November 2026: Patterns and Method phase added (`doc/levels.md` sections 5b
> and 9). Version 3.2 — 23 November 2026: Levels outcome; level tuning targets; sections 2, 3, 6 and 10
> aligned with `doc/levels.md`. Version 3.1 — 23 November 2026: Levels phase added, specified in `doc/levels.md`.
> Version 3.0 — 22 November 2026: Redesign outcome and close-out; alignment fixes.
> Version 2.9 — 22 November 2026: the Redesign phase (game modes and new interface) added; it changes the
> level structure, the session flow and the home screen — section 3 describes the game before it.
> Version 2.8 — 22 November 2026: Phase 5.2 outcome; Phase 6 entry and environments; Phase 7
> trimmed. Version 2.7 — 20 November 2026: Phase 5.1 outcome; Phase 5.2 (staging and online groundwork)
> added; alignment fixes. Version 2.6 — Phase 5 outcome; Phase 5.1 (beta-period groundwork) added;
> alignment fixes. Version 2.5 — Phase 3a.1 done; Phase 5 detailed with the beta-safety rule.
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
- **Never punish absence.** Coming back after weeks costs nothing; the level simply waits.
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
 
- 8 operations in two families: *Basics* (addition, subtraction, multiplication, division) and
  *Advanced* (powers, roots, percentages, integrals). Plus Tables mode and two challenges.
- The player picks operations, 4/5/10/20 questions per operation, and Levelling or Training mode.
- 30 s per question, ✓ to validate, a timeout counts as wrong; three timeouts in a row without a
  key pressed end the game without counting it.
- Result screen with Play again (same settings, new seed) and Home.
### 3.2 Levels
 
Specified in **`doc/levels.md`**: levels 0–100 from zero for everyone, ten tiers of content per
operation, credit per answer (fluent, slow, wrong), capped gains per game, versioned rules
replayed by the server. Main level = the four basic operations. Levels are frozen at the start of
a game and are a cache recomputable from history.
 
### 3.3 Scoring
 
Base points, speed bonus, capped streak bonus, difficulty multiplier. The score is session
feedback only; it never ranks anyone — the level does.
 
### 3.4 Accounts and screens
 
Supabase accounts (anonymous-first since Phase 1, email linking), player name, Profile
tab with overall level, 30-day curve, per-operation level and average time, recent games.
Day and night themes. Tabs: Play, Online (preview), Profile, Leaderboard.
 
## 4. Current state (22 November 2026, after the Redesign phase)
 
- Phases 0, 1, 2, 3a and 5 done: CI (VM and JavaScript, weekly Android compile), preview on
  Cloudflare Pages (`math-trainer-kjc.pages.dev`), anonymous-first accounts, beta gate, placement
  and type placement, continuous levels, monorepo with `packages/math_core`, Dart server on Render
  with replay validation, leaderboard, SQL migrations applied by CI, owner dashboard, digit
  typeface, component kit, operator icons, sound, haptics, home-screen install.
- Also done: early sign-in, server-side gate, strategy detector and structural features (unused
  by the app), staging pipeline (waiting on its setup), duel configuration and Glicko-2 (no UI),
  legal drafts in `doc/legal/`.
- Redesign shipped: Basics / Advanced / Challenges home, setup page, Training and Levelling modes,
  30 s timer, 4/5/10/20 questions per operation, integrals, Get the count, Chain operations.
  Main level = the four basic operations only.
- Tests: core 673 (VM) / 646 (JavaScript), app 372, server 36, plus tooling and SQL tests.
- Gate shown at 15–17 s on slow 4G; first question estimated 18–20 s, not yet measured live.
- The repository is **private** since 20 November.
- Web-only: mobile development is paused.
| Weakness | Why it matters | Fixed in |
|---|---|---|
| Login required before playing | Most first-time players leave before one question | Phase 1 |
| One timestamp per game, not per answer | Blocks spaced repetition and fatigue analysis | Phase 0 |
| Everyone starts at level 1 | An adult's first games are trivially easy | Phase 1 |
| Measures but does not teach | Drilling alone plateaus; players stop improving, then leave | Phases 0 and 4 |
| Level constants are guesses | The leaderboard would rank on unvalidated numbers | Phase 3b |
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
- **No placement test**: everyone starts at 0 (`doc/levels.md`).
- **Fluent time per tier** decides full or partial credit; the 30 s timer stays fixed.
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
 
- Ranked on **level**, computed by the server. A main board (the four basic operations) and one board per operation.
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
*(Superseded by v3.5: Phase 3b is a data check, and Phase 4 ran before it.)*
 
### Phase 3a outcome (19 November)
 
All nine commits delivered, CI green, server live on Render, first question on slow 4G 23.1 s.
The repository was public at the time (private since 20 November); tester data stays out of CI
logs and the dashboard runs locally either way. Owner decisions on the provisional choices:
 
- Preview host: **Cloudflare Pages, yes** (brotli, ~4.6 s less on slow 4G). Moved before any
  invitation.
- Type placement for every never-played operation, already-played ones sitting out that game,
  same constants as the main placement: kept.
- Gate enforced by the app only, codes stored readable, asked once per device: kept for an
  invite-only beta. Server-side enforcement before Phase 6 if the gate stays.
- Names: an approved name is never hidden again; a cleared name is removed until a new one: kept.
- Timing-flag thresholds and the 03:17 UTC cleanup schedule: kept.
- **Data gaps closed before invitations**: input device per answer and app version per session.
  The timeout in force is not stored: it is 15 s for every answer until Phase 3b.
### Phase 3a.1 — Close-out before invitations (done, 19 November)
 
Preview on Cloudflare Pages (`math-trainer-kjc.pages.dev`; the GitHub Pages address redirects).
Input device stored per answer, app version per session (schema v8). The timeout in force is not
stored: it is 15 s for every answer until Phase 3b, which stores it when it starts to vary.
Owner steps for the invitations: one code per tester, `SMOKE_BETA_CODE`, `BETA_GATE=true`, the
phone checklist.
 
### Phase 4 — Learning layer: weak spots and drills (one pass)
 
**Owner decision (24 November):** the current calibration feels right after rules v5–v6, so
Phase 3b is no longer a blocker. It becomes a **data check** run once the dashboard reaches its
threshold: a report comparing the targets with real games, changes only if the data contradicts
them. Phase 4 goes first.
 
**Goal:** the app trains each player's own weak spots, not just tests them. Pure core, no AI,
no change to how Levelling games move levels.
 
**Two kinds of things are tracked per player:**
- **Facts** — small, repeatable questions worth knowing by heart: addition bonds within 20 and
  complements to 100, tables up to 20 × 20, squares to 30², cubes to 10³, powers of 2 to 2¹²,
  friendly percentages (10, 20, 25, 50, 75 % of round numbers), and their roots and divisions.
  Commutative facts share one entry (7 × 8 = 8 × 7).
- **Skills** — the pattern families and Method strategies (difference of squares, × 25, near a
  base…), for questions too big to repeat exactly.
**Scheduling — five boxes, counted in games, never in days** (absence never punished):
- wrong or timeout → box 1; correct and fluent → one box up; correct but slow → stays;
- an item in box 1, 2, 3, 4, 5 is due again after 1, 2, 4, 8, 16 of the player's games;
- history is recomputable from stored answers, like levels.
**Where weak spots appear:**
- **Levelling games:** up to **20 %** of questions are due facts or skills **from the player's
  current tier only** (the no-lower-tier rule stands). The chosen items are stored with the session
  so the server replays it alone.
- **New "Weak spots" card on Home:** a practice game of the player's due items, any tier up to
  their own; never moves levels, never ranked.
- **Profile:** a "Weak spots" block — the five slowest or most-missed facts, with a Practice button.
**Technique drills:**
- Every tip on the Tips page gets a **Drill** button: 10 questions of that one strategy, at the
  player's tier size, practice only. Methods shown on misses as usual.
**Commits:**
0. *(A)* Decisions recorded; Phase 3b turned into a data check in `doc/progress.md`.
1. *(A)* Fact and skill catalogue in the core; item key for any question; tests that every
   tier's facts are covered and commutative facts merge.
2. *(A)* Five-box scheduler, recomputable from history; tests on scripted histories.
3. *(A)* Due items in Levelling games (≤ 20 %, current tier only), stored with the session,
   replayed by the server; this is rules v7. Level targets rechecked by simulation.
4. *(C)* "Weak spots" practice game and Home card.
5. *(C)* Profile "Weak spots" block.
6. *(C)* Drill button on every tip, drill games.
7. *(A)* Dashboard report: for each player, accuracy and time on items before and after they were
   scheduled — does it work?
**Exit:** a missed 7 × 8 comes back within the next games until answered fluently three times;
Weak spots and Drill games playable on a phone; level targets still met; production lists rules 7.
 
### Phase 4 outcome (24 November)
 
All eight commits live as rules v7. Owner decisions on the provisional choices — kept, with one
change: subtraction facts include their inverses (15 − 7, 100 − 37); a pattern question trains its
family's skill; fluent time of the fact's own tier for scheduling; cap N/5 per game, N/5 per
operation; two practice session kinds, never ranked; drills for tips without a family use the
operation's standard questions; the 208 never-asked facts stay pinned in the catalogue; the Phase 3b
window is not restarted. **Changed:** a correct but slow answer on a fact also enters the schedule
(box 2) — slow facts are weak spots too, and Profile already ranks them.
 
**Known limit:** the server checks the tier and cap of a game's weak spots, not that they were
actually due. Closing it means rebuilding each player's schedule server-side from uploaded
history — worth doing before Phase 7 ranks duels on it.
 
### Phase 4 close-out (one pass)
 
1. *(A)* Slow correct answers on facts enter the schedule at box 2 (rules v8 — it changes which
   items are due).
2. *(A)* `/health` lists the session kinds the server accepts; the app holds an upload until its
   kind is listed, as it already does for rules versions.
3. *(A)* Server-side check that a game's weak spots were due, from the player's uploaded history;
   a game that fails it is still accepted for levels but its weak spots are flagged.
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
 
### Phase 5 outcome (20 November)
 
All eight commits delivered, live on the preview. Keypad and session layout pinned by tests to
the pixel; sound and haptics proven unable to delay a question. First load +16.4 KB (budget
+50). Owner decisions on the provisional choices:
 
- Digit typeface: **Space Grotesk**, unless the owner prefers another after `?specimen`.
- Sound on by default, synthesised in the browser (no files, nothing to license): kept.
- Vibration on by default; one pulse right, two wrong; disabled with an explanation where the
  browser can't vibrate: kept.
- Streak tiers 5, 10, 20 and their colours: kept.
- Reduced motion covers only the new effects; the answer flash, shake and question fade stay
  until after the beta (frozen by the beta-safety rule): kept, revisit after Phase 3b.
- App icon: + − × ÷ in a 2 × 2 grid (seven operators are unreadable at icon size): kept.
- "of" in "25% of 80" drawn in the digit face (avoids a mixed line): kept.
- Key tick and key tap on the on-screen keypad only: kept.
### Phase 5.1 — Beta-period groundwork (one pass)
 
**Goal:** use the beta weeks for work that prepares Phases 3b, 4 and 6 **without changing how
players answer**. The beta-safety rule of Phase 5 still applies, and its pinning tests must pass
at every commit.
 
0. *(A)* **Close Phase 5**: own-row leaderboard weight 700 → 500 (`doc/design.md`); the profile
   golden test no longer depends on the time of day; plan-alignment points recorded.
1. *(A)* **First load: overlap sign-in with boot.** Restore the session or start the anonymous
   sign-in while Flutter loads, instead of after; cache what can be cached. Measure on slow 4G
   from a fresh browser; target under 20 s to the first question. Question order, timing and
   input untouched.
2. *(A)* **Strategy detector in the core, no UI** (Phase 4, commit 1, moved earlier): for any
   exercise, the best strategy of section 6.1 or none; one test per strategy, VM and JavaScript.
   Nothing in the app calls it yet.
3. *(A)* **Structural features in the core, for analysis only**: carries, borrows, digits 6–9,
   distance from a round number, per exercise. A dashboard view attaches them to every stored
   answer, so Phase 3b can measure which features predict slow or wrong answers. Generation does
   not use them.
4. *(A)* **Beta progress in the dashboard report**: sessions and testers against the Phase 3b
   entry threshold (~300 sessions, 10+ testers), sessions per tester, days since each tester's
   last game.
5. *(A)* **Server-side gate enforcement** (prerequisite of Phase 6): an anonymous user without a
   valid code cannot upload; existing testers unaffected; tested against a direct API call.
**Exit:** pinning tests still pass; slow-4G first question measured (target < 20 s); detector and
features tested on VM and JavaScript; the report shows beta progress.
 
### Phase 5.1 outcome (20 November)
 
All six commits delivered. Gate shown at 15–17 s on slow 4G (first question not yet measured
live; estimated 18–20 s). Strategy detector and structural features in the core, tested on VM and
JavaScript, unused by the app. Beta progress and a features view in the dashboard. Server-side
gate live. Owner decisions on the provisional choices — all kept:
 
- Pre-compression through a Cloudflare Pages Function (free plan: 100,000 calls a day, ~5 per
  first visit) — revisit at Phase 6 if traffic nears the limit.
- Early sign-in only where the app would sign in at once; the gate still comes first for new
  visitors.
- Inter limited to weights 400–500, the design's two weights.
- Strategy thresholds and feature definitions as recorded in `doc/decisions.md`; Phase 4 tunes
  them on beta data.
- Server gate: a code or one accepted game lets a player through; email-linked accounts never
  asked; a blocked upload is retried later, never lost; switched off at Phase 6.
- Server levels read ahead used once, only when nothing was pending.
### Phase 5.2 — Staging and online groundwork (one pass)
 
**Goal:** stop testing against the testers' database, and prepare Phases 6 and 7 without anything
players can see. The beta-safety rule still applies.
 
**Why staging now:** CI's smoke test creates and deletes accounts in the very project that holds
the testers' data, which already left stray "(no code)" guests in the dashboard. Before the public
launch, tests must run elsewhere.
 
0. *(A)* Close Phase 5.1: plan-alignment points; live slow-4G measurement of the first question
   with the CI beta code, reported.
1. *(A)* **Staging**: a second Supabase project (owner creates it; free plan allows two) and a
   second Render service. CI applies migrations to staging first, runs the smoke test against a
   staging build, and only then migrates and deploys production. The current project stays
   production, so testers keep their accounts and levels.
2. *(A)* **Duel configuration in the core** (Phase 7, commit 1): fixed quotas per type, difficulty
   from a rating bracket, never from a player's levels; same (seed, duel config) gives the same
   questions on VM and JavaScript. No UI.
3. *(A)* **Glicko-2 on the server**, no endpoint yet: tested against Glickman's published worked
   example, and on rating periods with no games.
4. *(A)* **Legal drafts** in `doc/legal/`: privacy policy and legal notice (mentions légales),
   with placeholders for the publisher's identity, host and contact. Not published. To be
   reviewed by the owner — and by a professional before Phase 6.
**Exit:** smoke green on staging and production; production untouched by tests; duel config and
Glicko-2 tested; legal drafts ready for review.
 
### Phase 5.2 outcome (22 November)
 
All five commits pushed; staging and the live slow-4G measurement wait on the owner's setup.
Owner decisions on the provisional choices — all kept:
 
- Deploy order enforced by CI through Render deploy hooks; the server redeploys only when the
  server or the core changed.
- Production smoke test read-only; rethought at Phase 6, where the gate is off and the page's
  early sign-in is itself a write.
- Staging has no beta gate.
- Duel brackets of 100 rating points, level 5 + 5 × bracket (1500 → level 40), standard duel of
  12 questions (divisible by 3 and 4 types) — provisional until Phase 7 compares ratings with
  real levels.
- Glicko-2 with τ = 0.5 and uncertainty capped at 350.
- Legal drafts based on contract performance and legitimate interest, not consent — to be
  confirmed by the professional review.
### Redesign phase — Game modes and new interface (one pass)
 
**Goal:** a clearer game with more to play: two families of operations with separate levels,
a setup page with modes, integrals, two solo challenges, and a cleaner interface.
**Reference screens:** `doc/mockups/redesign.html`, approved by the owner. Their layout and
content are binding; colours, type and spacing come from `doc/design.md` and the theme.
 
**The beta-safety rule is lifted for this phase** (owner decision). This phase changes how players
answer; the app version recorded with every session separates the data, and the Phase 3b
calibration window starts after the Redesign phase ships. The layout pins of Phase 5 are updated
deliberately to the new screens, then pin them again.
 
**Interface principle:** minimal text. No explanatory captions, hints or helper sentences on any
screen; labels only ("Basics", "Advanced", "Challenges", "Questions", "Mode", "Play", "Start").
Players understand by themselves.
 
#### Product rules
 
- **Two families.** *Basics*: addition, subtraction, multiplication, division. *Advanced*:
  powers, square roots, percentages, integrals.
- **Main level** = the average of the four basic operations only. It is the level shown at the top
  of Home and the one ranked on the main leaderboard.
- **Advanced operations** each keep their own level and their own leaderboard; they never count in
  the main level. Server levels and leaderboard rows are recomputed for the new definition.
- **Timer: 30 seconds per question** (was 15). A timeout counts as wrong. Three timeouts in a row
  without a key pressed still end the game.
- **Validate key (✓) kept. No auto-validation, no Skip button.**
- **Questions per operation: 4, 5, 10 or 20**, default 10, remembered. Each selected operation
  gets exactly that many questions, order shuffled by the seed; the per-operation counts are stored
  with the session (self-contained replay). Every operation therefore reaches `n_min` (4), so
  levels always move in Levelling mode. Replaces the derived count and the rotation by sampling
  debt for these games.
- **Modes:**
  - *Levelling*: difficulty follows the player's levels; the game moves levels and counts for the
    leaderboards. Same as today.
  - *Training*: the player picks Easy, Medium or Hard; fixed difficulty (proposed: the bounds of
    levels 15, 40 and 70 for each operation); **never changes levels, never ranked**; stored as its
    own session kind. The Easy/Medium/Hard row appears only in Training.
- **Placement** unchanged in behaviour; its timer follows the new 30 s.
#### Integrals
 
- New advanced type: definite integral of a small polynomial, **area under the curve**, whole-number
  answer, e.g. ∫₀³ 2x dx = 9, ∫₁² 3x² dx = 7.
- **Generated backwards** (rule 10): draw an antiderivative F with integer coefficients and no
  constant, degree 2–4, take p = F′, draw integer bounds a < b; answer F(b) − F(a). Integer
  arithmetic only (rule 18).
- **Area, not signed integral**: p ≥ 0 on [a, b], so the answer is a positive whole number.
- Difficulty grows with the level: degree, coefficient size, width and position of the bounds.
- Rendered like the mockup: integral sign, bounds top and bottom, polynomial with superscript
  exponents, `dx`.
- Full chain like any type: codec, server replay, its own leaderboard, short placement on first
  play, determinism pinned on VM and JavaScript.
#### Challenges (solo practice for now; online 1v1 in Phase 7)
 
No levels, not ranked, not uploaded for now; personal stats kept on the device (games, solved,
best time). Both are seeded and live in the pure core, so Phase 7 can replay them on the server.
 
**Get the count**
- 6 numbers: big ones from {25, 50, 75, 100}, each at most once; small ones from 1–9, each at most
  twice. Between 1 big + 5 small and 3 big + 3 small.
- Target 101–999, **built backwards** from the six numbers with valid operations, so **a solution
  always exists**.
- Rules: + − × ÷ on two available tiles; whole numbers only, no negatives, division only when
  exact; each number used at most once; intermediate results become new tiles.
- Input: tap a tile, an operator, another tile → the two fade, the result appears as a tile.
  Undo (↶) and Reset (⟲).
- **45 seconds.** A tile equal to the target ends the round as solved. At the end: the correction,
  i.e. the shortest solution found by a solver in the core, and the player's closest value.
**Chain operations**
- Setup page like the others: seconds per screen 1, 2 or 3; operations 5, 10 or 15.
- A starting number, then one operation per screen (+7, −2, ×3, ÷8), with a short blank between
  screens so two identical steps stay distinguishable.
- Every intermediate result a whole number, never negative, at most 999; division only when exact;
  generated to satisfy this.
- Final screen: the keypad with ✓. Then the result and the full chain as correction.
#### Navigation and layout
 
- **Home** (scrolls): main level badge top right; "Basics" — one row of 4 operation buttons, each
  showing its level, multi-select, selection remembered — then a full-width, shorter **Play**
  button centred under the row; "Advanced" — same; "Challenges" — two cards.
- **Play** is dimmed and inert until at least one operation of its row is selected.
- **Setup page**: back arrow top left, the selected operators as title, Questions (4 / 5 / 10 / 20),
  Mode (Training / Levelling), difficulty row in Training only, Start at the bottom.
- **Games**: ✕ top left (quit, with a confirmation; a Levelling game quit early is kept as
  interrupted), progress `n / N` top right, timer bar, operation, answer, keypad
  1–9 / ⌫ 0 ✓. No bottom bar during a game.
- **Bottom bar** (Play, Online, Profile, Ranks) on every other page.
- **Accessibility:** touch targets ≥ 48 dp, text contrast ≥ 4.5:1 in both themes, layouts hold at
  large system text sizes, reduced motion respected everywhere (the Phase 5 freeze no longer
  applies).
#### Commits
 
0. *(A)* Record the owner decisions above in `doc/decisions.md`; lift the beta-safety pins.
1. *(A)* Level structure: main level = 4 basics; advanced levels separate; server, leaderboard
   boards and dashboard updated; levels recomputed.
2. *(A)* Session flow: 30 s timer; questions per operation (4/5/10/20) stored with the session.
3. *(A)* Training mode: fixed difficulty, own session kind, never changes levels, never ranked.
4. *(A)* Integrals, end to end (core, display, codec, server, leaderboard, type placement).
5. *(C)* Home, setup page and navigation per the mockups.
6. *(C)* Game screens cleaned per the mockups; quit confirmation; accessibility pass; new pins
   and goldens in both themes.
7. *(C)* Chain operations (core generator and UI, setup page).
8. *(C)* Get the count (core generator, solver, tile UI, correction).
9. *(A)* Smoke test and dashboard follow the new flow; first-load budget checked.
**Exit:** every screen matches the mockups in both themes; a Levelling game on basics moves the
main level and the leaderboard, a Training game moves nothing; integrals generated, answered,
validated by the server and ranked; both challenges playable end to end with their correction;
every Get-the-count target solvable (tested on thousands of seeds); all chain values whole,
non-negative, ≤ 999 (same).
 
### Redesign outcome (22 November)
 
All ten commits live on the preview; app download +13 KB. Owner decisions on the provisional
choices:
 
- Palette contrast fixes (muted text #7F90B2 dark / #5E6E8C light; error red #F06968 dark /
  #BF3433 light): kept; `doc/design.md` updated to match.
- Correction pause without words (wrong answer struck through, hourglass on timeout): kept.
- A never-played operation shows level 1: kept.
- Training games uploaded and checked, counted as activity: kept. **Changed:** they never count
  toward leaderboard eligibility (the "3 completed games"); only Levelling games do.
- Integrals start at ∫₀ᵇ 2x dx on level 1: kept. Their placement pass time stays the shared 3 s
  until Phase 3b gives each operation its own.
- Chain operations details kept. **Changed:** its setup choices are remembered, like the other
  setup pages.
- Get the count details kept (uniform reachable target, forbidden move drops the operator,
  timeout = played, not solved).
- Phase 3b window counted from this release: kept.
- **Changed:** the result screen offers **Play again** (same operations and settings, new seed)
  and **Home**; it no longer sends the player straight to Home.
- Bottom bar label "Ranks", day/night switch in Profile, streak line removed from the game screen:
  kept.
### Redesign close-out (one pass)
 
1. *(A)* The three changes above (Training out of eligibility, Chain setup remembered, Play again
   on the result screen); `doc/design.md` palette updated; plan-alignment points recorded.
### Levels phase — new level system, tables mode, tips (one pass)
 
**Goal:** levels that are easy to start, never punish slowness inside the timer, and stall only
when the player can no longer answer. **Specification: `doc/levels.md`** — it is binding, and
replaces the previous level formula, placement and operand curves.
**Entry:** Redesign close-out done. The beta-safety rule stays lifted.
 
0. *(A)* Record the decisions in `doc/decisions.md`; version the level rules (stored per session).
1. *(A)* New level update (section 3 of the spec) in the core and on the server; old constants
   retired; tests reproduce the spec's example table exactly.
2. *(A)* Ten tiers per operation (section 5): generators rewritten tier by tier, 70 % current tier
   and 30 % review; every tier's example reproducible; all answers whole, divisions, roots and
   percentages exact; determinism pinned on VM and JavaScript.
3. *(A)* Fluent time per tier replaces the shared `t_rapide`.
4. *(A)* Transition (section 4): all levels reset to 0, history kept, old sessions off the boards,
   placement and type placement removed, Training = T1 / T4 / T7.
5. *(C)* Display (section 6): one line, two right-aligned lines when it doesn't fit, thousands
   grouped, 10-digit answers; new layout pins and goldens.
6. *(C)* Tables mode (section 7).
7. *(C)* Tips page (section 8), the player's tier highlighted.
8. *(A)* Simulation updated: games to reach each tier for a perfect, an 80 % and a 60 % player;
   reported against the spec's grind estimate.
**Exit:** the spec's example table and grind estimate reproduced by tests; every tier generates
its examples' kind of question; a correct-but-slow game raises the level; all levels at 0 for
every player; tables mode and tips playable on a phone.
 
### Levels outcome (23 November)
 
All nine commits and the Redesign close-out delivered; levels reset to 0; the spec's example table
and grind estimate reproduced by tests. Incident: the production server was not redeployed, so for
about 30 minutes it refused rules-v2 games; fixed by holding uploads until the server announces
rules v2 in `/health`. Owner decisions on the provisional choices — all kept (late v1 games
refused; fluent time of the player's own tier; exact review counts; tier content choices; Profile
curve on new rules only; duels drawing from tiers; Phase 3b window restarted at the reset; digits
grouped with a space; "Roots" label; tables stats as right / answers; one tip per strategy).
 
**Finding:** the simulation shows a 60 % player still creeping up (about one tier per 24 games);
the level only stops moving at ~54 % correct, because gains outweigh losses. The spec intends a
stall between 60 and 70 % correct.
 
### Levels close-out (one pass)
 
1. *(A)* **Tune the level update to these targets**, by simulation, changing only the credit for a
   correct slow answer, the dead band and the down cap (`doc/levels.md` section 3):
   - a player stalls between **60 and 70 % correct** answers;
   - a game of 4 questions all correct but slow gains **at least +1.5**;
   - a perfect game still gains the full cap (+3 / +3 / +4 / +5);
   - a bad game never costs more than 3 levels.
   Starting point to test: slow credit 0.85, dead band 0.62–0.72, down cap 3. Report the chosen
   values with the simulation table; they become rules v3 (stored per session, v2 games still
   replayed under v2).
2. *(A)* After every push that changes the server or the core, check production `/health` serves
   the new commit and the expected rules; if not, say so at once as an owner action.
### Levels close-out outcome (23 November)
 
Rules v3 live (slow credit 0.85, dead band 0.62–0.72, down cap 3): stall at 64–65 % correct,
all-correct-slow +1.56, perfect = cap, bad game −3. Owner confirmed all three effects. The deploy
hook works: the server redeploys itself after a push.
 
### Patterns and Method phase (one pass)
 
**Goal:** questions that reward shortcuts, not only digit count, and a worked method on every
mistake. **Specification: `doc/levels.md` sections 5b and 9** (binding). Runs before the testers
accumulate data, so the Phase 3b window restarts at this release at little cost.
 
0. *(A)* Decisions recorded; rules v4 = v3 level update + new generation; v2 and v3 generators
   kept so their games still replay.
1. *(A)* Pattern families in the core generator, operation by operation, each with its examples
   reproduced, about 40 % of a tier's questions from the tier where families start; answers whole
   and exact; determinism pinned on VM and JavaScript; server replays v4.
2. *(A)* Method generator in the core: strategy steps for every pattern family and detector
   strategy, fallback for every operation; tests on thousands of questions per tier and family —
   every line true, last line = the answer.
3. *(C)* Method on the result screen: a button on each wrong answer and timeout of Basics and
   Advanced games, steps expanding in place, "More tips" link; minimal text; goldens in both
   themes.
4. *(A)* Tips page: each pattern family linked to its tip; tips added where a family has none.
5. *(A)* Simulation rerun under v4: the four level targets still met; report the share of pattern
   questions actually served per tier.
**Exit:** every family's examples generated; every Method checked by tests; level targets still
met; production `/health` lists rules 4; on a phone, a missed 17 × 23 shows (20 − 3)(20 + 3).
 
### Patterns and Method outcome (23 November)
 
All six commits live as rules v4; production updated itself after each push. 49 pattern families,
a checked Method for every wrong answer and timeout, 54 tips. Owner decisions on the provisional
choices — all kept (addition and subtraction fixed in v4 to the 9-digit tables; probabilistic
2-in-5 pattern share; families recomputed by replay; third operand stored for three-term sums;
fallback methods and strategy names as written; Method in Levelling and Training; duels pinned to
their own rules version).
 
**Finding:** addition and subtraction had been built from an earlier version of `doc/levels.md`
(the 4-digit tables), and the tests checked the code against itself. **Rule from now on:** the
tier tables and examples of `doc/levels.md` are checked by a test that reads the spec file itself —
each example must be a question its tier can generate, and each tier's digit counts must match.
A spec change then breaks a test instead of drifting silently.
 
### Phase 6 — Public web launch
 
**Entry:** Phases 3a, 3b, 4, 5, 5.1, 5.2, the Redesign, the Levels phase and the Patterns and Method phase done (staging running); name chosen; domain bought;
legal drafts reviewed.
 
**Environments after launch:** production = the domain (Cloudflare Pages project and current
Supabase project); the old `math-trainer-kjc.pages.dev` address redirects to the domain; staging
stays on `math-trainer-staging*.pages.dev` with its own Supabase project; the read-only production
check moves to the domain and is rethought for an ungated page.
 
1. *(A)* Production deployment on the domain, separate from preview.
2. *(A)* Privacy policy and legal notice pages, linked in the app.
3. *(A)* CAPTCHA or Turnstile on anonymous sign-in and sign-up.
4. *(A)* Email confirmation on, with a real SMTP sender on the domain and the site URL set.
5. *(A)* Beta gate removed; abuse protections verified.
6. *(C)* Launch checklist run on a phone from a fresh browser.
### Phase 7 — Online play: asynchronous duels and friends (one pass)
 
**Goal:** players compete against each other and their friends, even when few are online at once.
**Entry:** Phase 4 close-out done (the server checks that weak spots were due; `/health` lists the
session kinds). Runs during the beta, before the public launch.
**Reference screens:** `doc/mockups/online.html` (binding layout, minimal text).
 
#### Principles (owner decisions, 25 November)
 
- **No live matches.** Every duel is asynchronous: a player races the recorded run of another,
  replayed live at its original pace as a second progress lane.
- **Online play needs a linked account** — no guests. The Online tab invites a guest to save their
  progress.
- **Three modes, each with its own rating and leaderboard** (Basics, Advanced, Get the count).
  Chain operations stays solo.
- **Friends count for the rating.** Tournaments: later.
#### The three modes
 
| Mode | Content | Winner |
|---|---|---|
| **Basics** | 8 questions: 2 each of + − × ÷ | more correct answers; equal → less total time |
| **Advanced** | 8 questions: 2 each of x², √, %, ∫ | more correct answers; equal → less total time |
| **Get the count** | 3 rounds, **30 s each**, same numbers and targets for both | smaller total distance to the three targets; equal → less total time |
 
- Basics and Advanced: 30 s timer per question, ✓ to validate, Method on misses in the result.
- Get the count: a round's time is when the player reached their closest value; reaching the
  target ends the round.
#### Difficulty from the rating
 
- **Basics and Advanced: every 150 rating points is one tier** of `doc/levels.md`:
  rating 900 → T0, 1500 → T4, 2250 and above → T9. Questions are drawn exactly as in a game at that
  tier (standard and pattern questions, sized by tier), with the duel's own seed and rules version.
- **Get the count:** the rating sets the target's difficulty, measured by the length of its
  shortest solution: 2–3 operations at low ratings, up to 4–5 at high ratings; three bands, the
  thresholds *tunable* (proposed: below 1300 → 2–3 operations, 1300–1700 → 3–4, above 1700 → 4–5).
- **Both players always get the same questions:** the challenger plays exactly the questions of
  the recorded run.
#### Rating
 
- **Glicko-2** (built in Phase 5.2), on the server only, one rating per mode; each duel is its own
  rating period; uncertainty capped at 350; τ = 0.5.
- **Starting rating from the player's levels**: Basics = 900 + 15 × main level; Advanced =
  900 + 15 × the average of the four advanced levels; Get the count = 1300. Provisional ("?") for
  the first 10 duels of that mode.
- **Both players' ratings move**, including the owner of a recorded run, who learns the result
  later.
- **Friend duels are rated**, at most **once a day per pair and mode**; later duels that day are
  played and recorded but unrated.
- **Leaderboards**: a Basics, an Advanced and a Get the count board on Ranks (non-provisional
  players, played within 30 days).
#### Matchmaking and opponents
 
- **Find an opponent**: the server picks a recorded run from a player whose rating is closest to
  the challenger's, never the challenger's own, never one this challenger already raced. Each run
  is served at most **5 times**; only a player's **10 latest runs** per mode are in the pool.
- **Practice opponent** when no suitable run exists: a simulated player of that tier, labelled
  "Practice", **no rating change** for either side, recorded in Recent.
- **Rematch** (result screen): immediately races another recorded run of the same opponent at a
  close rating, if one exists; otherwise it sends that opponent a challenge.
#### Friends
 
- Every linked player has a **friend code** (e.g. `MATH-7K2P`, short, no ambiguous characters) and
  a **personal invite link**. Opening the link or entering the code sends a friend request;
  accepting makes both friends. Remove a friend at any time.
- **Friends page**: the code, Share link, Add code, the friend list with the **head-to-head score**
  per friend; tapping a friend opens the **history of games** between you (date, mode, score,
  result).
- **Challenge**: the challenger plays first in the chosen mode; the friend sees it under **"Waiting
  for you"** on the Online tab (with a badge on the tab) and plays the same questions when they
  want; both get the result. A challenge expires after **7 days**.
- **Notifications**: in the app only for now (badges); push notifications come with Phase 8.
#### Fair play
 
- Every duel run is replayed and validated by the server like any game; a run that fails never
  enters the pool and its duel does not count.
- Implausible timing (multi-digit answers under ~300 ms, unnaturally flat times) flags a run: kept
  out of the pool until reviewed in the dashboard.
- Friend requests limited (e.g. 20 per day per player); friend codes not guessable in practice.
#### Commits
 
0. *(A)* Decisions recorded; duel session kinds and duel rules version listed in `/health`.
1. *(A)* Duel content in the core: the three modes, difficulty from rating, Get the count target
   bands; determinism on VM and JavaScript; server replay.
2. *(A)* Duel runs stored and validated; run pool (5 serves, 10 latest per mode); fair-play flags.
3. *(A)* Glicko-2 per mode wired to results: starting ratings from levels, provisional flag, both
   sides updated, friend-duel daily limit; tests on scripted duel histories.
4. *(A)* Matchmaking endpoint, practice opponents (deterministic simulated runs), rematch logic.
5. *(C)* Duel screens for Basics, Advanced and Get the count, with the opponent's lane, and the
   result screen with Rematch, per the mockups.
6. *(C)* Online tab: three modes with their ratings, "Waiting for you", Recent, badge; the three
   boards on Ranks; account required (guests invited to save progress).
7. *(C)* Friends: codes, invite links, requests, list with head-to-head, game history per friend,
   challenges with 7-day expiry.
8. *(A)* Dashboard section: duels per day and mode, rating distributions, flagged runs, friend
   counts.
**Exit:** two linked test players race each other's runs in all three modes and their ratings
move on the server only; a friend added by link and one by code can challenge each other and see
their history; a practice opponent appears when the pool is empty; a forged or implausible run is
never served.
 
### Phase 7b — Live duels and tournaments (later)
 
Live duels only when the dashboard shows enough players online together for queues under ~20 s
(Supabase Realtime; the server validates both runs). Tournaments after that.
 
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
| ~~Server-side gate enforcement~~ — done in Phase 5.1 | Phase 5.1 |
| Production on the current Supabase project, a new one for staging | Phase 5.2 |
| ~~Phase 5 provisional choices~~ — see Phase 5 outcome | Phase 5 |
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
| Flutter web too slow on first load | Gate visible at 15–17 s on slow 4G (P5.1); first question estimated 18–20 s, to be measured |
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
- Set the Render deploy hooks (production and staging) as GitHub secrets; until then, deploy the
  server by hand after any change to the server or the core.
- Keep 10–20 testers playing; watch Beta progress in the dashboard report.
- Confirm the digit typeface (Phase 5 picked Space Grotesk provisionally).
- Choose the app name before Phase 6; the domain, SMTP sender and store listings depend on it.
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
 