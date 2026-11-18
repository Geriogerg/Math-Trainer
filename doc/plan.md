# Math Trainer — Product Plan

> **Owned by the product owner.** This file says *what* the app is, *why*, and *in what order* it
> gets built. Claude Code reads it at the start of every phase and **never edits it**; changes come
> from the owner. The day-to-day working rules live in `CLAUDE.md`, which must always stay
> consistent with this plan (section 11).
>
> Version 1 — 18 November 2026, written from the project state of that date.
> Version 1.1 — 18 November 2026: English-speaking audience, Android out of CI until Phase 8,
> facts updated after Phase 0 commit 0 (edited by Claude Code at the owner's request).

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

English-speaking audience first; everything is in English — interface, code, docs. Competitive
tone, not a school exercise book.

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

Supabase accounts (email and password, currently mandatory before playing), player name, Profile
tab with overall level, 30-day curve, per-operation level and average time, recent games.
Day and night themes. "Online" and "Leaderboard" tabs are previews.

## 4. Current state (18 November 2026)

- 49 commits, 176 core tests / 328 in total, steps 1 to 5 and step 6 slices 1–2 done.
- Web-only since 17 November: the Android emulator is unusable; mobile development is paused.
- Web storage survives reloads (SQLite in WebAssembly).
- 28 analyzer deprecation notices since Flutter 3.50 moved Material to `material_ui`.
- Local branch `main`; no GitHub remote yet (section 10).

| Weakness | Why it matters | Fixed in |
|---|---|---|
| Login required before playing | Most first-time players leave before one question | Phase 1 |
| One timestamp per game, not per answer | Blocks spaced repetition and fatigue analysis | Phase 0 |
| Everyone starts at level 1 | An adult's first games are trivially easy | Phase 1 |
| Measures but does not teach | Drilling alone plateaus; players stop improving, then leave | Phases 0 and 4 |
| Level constants are guesses | The leaderboard would rank on unvalidated numbers | Phase 3 |
| Stock components, generic name | Looks like a template; the name cannot be found or protected | Phase 5 |
| No CI | Nothing checks the repo on a clean machine | Phase 0 |
| `δ` widened 0.05 → 0.07 when `n_min` went 8 → 4, never checked or approved | Levels may jitter more or less than designed | Phase 0 |

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

**Guardrails that keep mobile cheap to return to.** Web-specific code stays in the infrastructure
layer; no dependency without Android and iOS support unless its mobile replacement is identified;
touch-first input. Android is not built or checked until Phase 8 (owner decision): CI is web-only,
and Phase 8 accepts the cost of fixing whatever drifted.

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
- **A real name** before the public launch: short, easy to say in English and French, free as a
  domain and on both stores. "Math Trainer" describes the app but cannot be found or protected.

### 6.3 Accounts and first run

- **Anonymous-first.** A player is created silently on first launch and plays immediately. Email
  (later Google) is linked when they want the leaderboard or a second device. Replaces the
  mandatory login of step 6 slice 2.
- Existing email accounts keep working with no data loss.
- Abuse protection (CAPTCHA or Turnstile), cleanup of stale anonymous players.
- In-app account deletion: account, personal data and history.
- Email confirmation with a real SMTP sender.

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
P0 Stabilise ─ P1 First run ─ P2 Server ─┬─ P3 Invite-only beta (data) ─┬─ P6 Public web ─ P7 Online
                                          ├─ P4 Learning layer ─────────┤
                                          └─ P5 Identity ────────────────┘
P8 Return to mobile: whenever mobile development is possible again (independent of P6 and P7).
```

*(A)* = autonomous commit, judged by tests. *(C)* = checkpoint: implemented, deployed to the
preview URL, then stopped until the owner has played it.

### Phase 0 — Stabilise and build the web pipeline

**Goal:** a clean base, checked automatically, with a preview URL playable on a phone.

0. *(C)* Docs: create `doc/progress.md`; bring `doc/online.md` and `doc/decisions.md` in line with
   this plan (anonymous-first, Glicko-2, ghost duels first, monorepo, web-first, no ads in v1),
   each decision with its reason and a "reopen when"; list remaining contradictions. No preview
   URL exists yet: this checkpoint is read, not played.
1. *(A)* CI on GitHub Actions: core tests, all tests, analyze, web build, on every push. Supabase
   settings from CI secrets. No Android build until Phase 8.
2. *(A)* Preview deployment of the web build on every push to `main`, stable URL. Host proposed
   with its reason.
3. *(A)* `material_ui` migration, zero analyzer notices afterwards.
4. *(A)* One timestamp per answer. Schema migration only after asking.
5. *(A)* Check `δ` = 0.07 against `n_min` = 4; any new value proposed, never applied without
   approval.
6. *(A)* Debug-only switch disabling the timeout, proven inert in release builds.
7. *(A)* Hooks refusing `assert(` in the core and unseeded `Random(`; formatting after edits;
   reviewer subagent checking diffs against the architecture rules.
8. *(A)* First-load size and time measured; persistent browser storage requested.
9. *(C)* Correct answer shown on error or timeout; mistakes review on the result screen.

**Exit:** CI green on every push; preview URL live; the owner plays 5 games on a phone browser.

### Phase 1 — First run and accounts

**Goal:** a new player answers the first question within 30 seconds, with no form.

1. *(A)* Anonymous-first sign-in (design proposed first): restrictive access rules where needed,
   abuse protection, cleanup.
2. *(A)* Existing email accounts migrated with no data loss, tested.
3. *(C)* Placement test setting starting levels.
4. *(A)* In-app account deletion.
5. *(A)* Email confirmation on, real SMTP sender, site URL set.

**Exit:** from a fresh browser profile, first question in under 30 s; an anonymous player links an
email and keeps their history.

### Phase 2 — Server and leaderboard

**Goal:** every leaderboard row computed by the server from replayed answers.

1. *(A)* Core extracted to `packages/math_core`; monorepo `app/`, `packages/math_core/`,
   `server/`; no behaviour change.
2. *(A)* Dart server skeleton (`shelf`, container, CI, deployment); host and monthly cost proposed.
3. *(A)* Session upload: offline queue, idempotent endpoint, `syncedAt`.
4. *(A)* Server replay and validation; a forged upload rejected by a test.
5. *(A)* Tables and access rules: continuous level per player and operation, rank and percentile;
   only the server writes.
6. *(C)* Leaderboard screen: percentile, neighbours, top 100, per operation.
7. *(A)* Name filter and report action.

**Exit:** rows reproduced by replay; forged upload rejected; the owner sees their rank on a phone.

### Phase 3 — Invite-only web beta

**Goal:** a few hundred validated real sessions and the first data-based calibration.
**Entry:** Phase 2 done; testers invited by the owner (10–20 people).

1. *(A)* Beta gate (invitation code or allow-list).
2. *(A)* Owner dashboard from the server's own data: sessions per day, active players, median time
   per operation, abandonment rate.
3. *(A)* In-app feedback field.
4. *(C)* Recalibration with `tool/recalibrate.dart` on server data; new constants proposed with
   evidence, applied after approval, documented.
5. *(C)* Timeout derived from the level.

**Exit:** constants updated with documented evidence. Phases 4 and 5 run meanwhile.

### Phase 4 — Learning layer

1. *(A)* Strategy detector, one test per strategy of section 6.1.
2. *(C)* Tips after an error or a slow answer.
3. *(A)* Per-fact tracking and spaced resurfacing.
4. *(A)* Structural difficulty features.
5. *(C)* Technique drills.

**Exit:** a report, from beta data, of whether players who saw tips got faster on targeted facts.

### Phase 5 — Identity

**Entry:** the owner has chosen the digit typeface from mockups.

1. *(A)* Bundled digit typeface, tabular figures everywhere.
2. *(A)* Five-component kit, golden tests for each in both themes.
3. *(A)* Operator icon system, favicon, web app icon.
4. *(C)* Sound and haptics behind an interface; streak escalation; level-up moment.
5. *(A)* Web app manifest for "add to home screen".

**Exit:** golden tests on every kit component; the owner approves the feel on a phone.

### Phase 6 — Public web launch

**Entry:** Phases 3–5 done; name chosen; domain bought.

1. *(A)* Production deployment on the domain, separate from preview.
2. *(A)* Privacy policy and legal notice pages, linked in the app.
3. *(A)* Beta gate removed; abuse protections verified.
4. *(C)* Launch checklist run on a phone from a fresh browser.

### Phase 7 — Online play

1. *(A)* Duel configuration in the core, determinism tested.
2. *(A)* Duel runs stored and validated by the server.
3. *(A)* Glicko-2 on the server, provisional flag.
4. *(C)* Ghost duel screen.
5. *(C)* Friend challenges by link.
6. Live duels when the owner decides concurrency allows it.

### Phase 8 — Return to mobile

**Entry:** the owner says mobile development is possible again.

1. *(C)* Android build added to CI; Android on a device or emulator; fix what drifted while it was
   unbuilt.
2. *(A)* Native haptics and sound behind the Phase 5 interfaces.
3. *(A)* Store assets, data-safety form, account deletion link.
4. *(C)* Google Play closed test, then production.
5. *(C)* iOS through a cloud Mac build service; TestFlight, then App Store review.

## 8. Decisions that belong to the owner

Claude Code proposes options with their consequences, then waits.

| Decision | Needed before |
|---|---|
| `δ` value (0.07 in code, not yet approved) | Phase 0, commit 5 |
| Preview host (accepted unless the owner objects) | Phase 0, commit 2 |
| Anonymous-first design | Phase 1, commit 1 |
| Server host and budget | Phase 2, commit 2 |
| New level constants | Phase 3, commit 4 |
| Digit typeface | Phase 5 |
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
| Flutter web too slow on first load | Measure in P0; loading screen; revisit renderer choice if needed |
| Not enough players online for duels | Ghost duels first; live duels only on measured concurrency |
| Cheating in solo rankings | Server replay, timing flags; robust ratings come from duels |
| Teen users and consent rules | Check before public sign-ups (P6) |
| First iOS build on unknown ground | Budget time in P8; cloud Mac build service |
| Android drifts while unbuilt until P8 | Mobile-supported dependencies only; fix cost accepted in P8 |
| A single developer's bandwidth | Strict phase order; checkpoints kept few |

## 10. Owner actions outside the code

- Keep the repo on GitHub (CI and preview deployment depend on it).
- Recruit beta testers before Phase 3.
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
