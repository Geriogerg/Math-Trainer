# Levels — specification (v1, 22 November 2026)

> Owned by the product owner, like `doc/plan.md`. Claude Code implements it and never edits it.
> It replaces the level formula, the placement test and the operand-bound curves used until the
> Redesign phase. Values marked *tunable* are first guesses that Phase 3b calibrates on real data.

## 1. Principles

1. **Everyone starts at level 0** in every operation. No placement test.
2. **You get stuck because you can't answer, not because you're slow.** A correct answer given
   within the 30 s timer always counts in your favour. Speed only decides *how much*.
3. **The early grind is easy but not instant**: a perfect game moves you at most 3 to 5 levels.
4. **Going down is gentler than going up**: a bad game costs at most 2 levels.
5. **Few constants, all readable.** The old formula (`p_cible`, `f`, `K_haut`, `K_bas`, `δ`,
   `Δ_max`, `K_calib`, `boost_retour`, the √n weighting) is retired.

## 2. Scale

- Levels run from **0 to 100**, stored in integer hundredths (0–10000), shown as whole numbers.
- **Ten tiers** of ten levels: T0 = 0–9, T1 = 10–19, … T9 = 90–100.
- The level's tier decides the content of the questions (section 5). Within a game, **70 %** of
  questions come from the player's tier and **30 %** from the tier below (review); T0 has no
  review. *Tunable.*
- Frozen at the start of a game, as today.

## 3. How a game moves a level

Computed **per operation**, at the end of a Levelling game, from that operation's answers.

**Credit per answer:**

| Answer | Credit |
|---|---|
| Correct within the tier's **fluent time** (section 5) | 1.0 |
| Correct, slower than the fluent time, within 30 s | 0.75 |
| Wrong | 0 |
| Timeout (30 s) | 0 |

**Quality** `q` = average credit over the operation's answers (0 to 1).

**Change** `Δ` (in levels):

- `q` between 0.55 and 0.65 → `Δ = 0` (dead band: you're at your level). *Tunable.*
- `q` above 0.65 → `Δ = cap_up(n) × min(1, (q − 0.65) / 0.25)`
- `q` below 0.55 → `Δ = −cap_down × min(1, (0.55 − q) / 0.35)`

with `n` = number of questions on that operation:

| Questions per operation `n` | 4 | 5 | 10 | 20 |
|---|---|---|---|---|
| `cap_up(n)`, maximum gain | 3 | 3 | 4 | 5 |

`cap_down` = 2. *Tunable.*

**What this gives** (4 questions per operation):

| Game | q | Change |
|---|---|---|
| 4 / 4 correct and fluent | 1.00 | +3 |
| 4 / 4 correct, all slow | 0.75 | +1.2 |
| 3 / 4 fluent, 1 wrong | 0.75 | +1.2 |
| 3 / 4 correct, all slow | 0.56 | 0 |
| 2 / 4 correct, fluent | 0.50 | −0.3 |
| 2 / 4 correct, slow | 0.38 | −1.0 |
| 0 / 4 | 0 | −2 |

A player who answers everything correctly but slowly **still climbs** (q = 0.75). A player stalls
around 60–70 % correct answers — that is, when the questions become too hard to answer, which is
principle 2.

**Rules kept from before:** levels never decay with absence; three timeouts in a row without a key
pressed end the game without counting it; Training games never move levels; the formula uses
integer or `+ − × ÷` arithmetic only (rule 18) and is replayed by the server.

**Grind estimate** (perfect games, 10 questions per operation, +4 each): level 0 → 20 in 5 games,
→ 50 in 13 games. Real players stall earlier, at the tier where their accuracy drops.

## 4. Transition

- **All levels reset to 0** for every player, history kept. Old sessions stay in the history but
  are not replayed under the new rules and are off the leaderboards.
- The leaderboards start fresh.
- The placement test and the first-play type placement are removed.
- Training difficulty: Easy = T1, Medium = T4, Hard = T7.
- The rules carry a version number stored with each session, so the server replays each session
  with the rules it was played under.

## 5. Content by tier

All questions are generated **backwards** (rule 10): draw the parts, compute the answer, so every
answer is a whole number and division, roots and percentages are always exact. "Fluent" = the time
under which a correct answer earns full credit. *All fluent times tunable.*

### Addition — up to 9 digits

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | 1-digit + 1-digit, sum ≤ 10 | 4 + 5 | 4 s |
| T1 | 10–19 | 1-digit + 1-digit crossing 10; 2-digit + 1-digit | 8 + 7, 47 + 8 | 5 s |
| T2 | 20–29 | 2-digit + 2-digit, with carry | 47 + 38 | 6 s |
| T3 | 30–39 | 3-digit + 2-digit and 3-digit + 3-digit | 347 + 258 | 8 s |
| T4 | 40–49 | 4-digit + 3-digit | 2 468 + 785 | 10 s |
| T5 | 50–59 | 4-digit + 4-digit, several carries | 4 789 + 3 657 | 12 s |
| T6 | 60–69 | 5-digit + 5-digit | 47 806 + 38 597 | 15 s |
| T7 | 70–79 | 6-digit + 6-digit | 482 761 + 359 846 | 18 s |
| T8 | 80–89 | 7- and 8-digit numbers | 4 736 285 + 2 948 617 | 21 s |
| T9 | 90–100 | 9-digit + 9-digit | 538 274 916 + 287 649 385 | 25 s |

### Subtraction — never negative, up to 9 digits

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | within 10 | 9 − 4 | 4 s |
| T1 | 10–19 | teens − 1-digit; 2-digit − 1-digit with borrow | 15 − 7, 43 − 7 | 5 s |
| T2 | 20–29 | 2-digit − 2-digit, with borrow | 72 − 38 | 6 s |
| T3 | 30–39 | 3-digit − 2- and 3-digit, across zeros | 403 − 178 | 8 s |
| T4 | 40–49 | 4-digit − 3-digit | 3 042 − 687 | 10 s |
| T5 | 50–59 | 4-digit − 4-digit, several borrows | 7 003 − 2 468 | 12 s |
| T6 | 60–69 | 5-digit − 5-digit | 52 004 − 27 368 | 15 s |
| T7 | 70–79 | 6-digit − 6-digit | 700 251 − 384 769 | 18 s |
| T8 | 80–89 | 7- and 8-digit numbers | 6 030 417 − 2 958 639 | 21 s |
| T9 | 90–100 | 9-digit − 9-digit | 900 040 301 − 457 386 529 | 25 s |

### Multiplication

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | tables 1–5 (× 1–10) | 4 × 7 | 4 s |
| T1 | 10–19 | tables 6–10 (× 1–10) | 8 × 7 | 4 s |
| T2 | 20–29 | 10–15 × 1–9; multiples of 10 × 1–9 | 13 × 6, 70 × 8 | 6 s |
| T3 | 30–39 | 16–25 × 2–9; 2-digit × 11 | 24 × 7, 43 × 11 | 7 s |
| T4 | 40–49 | any 2-digit × 1-digit | 87 × 6 | 8 s |
| T5 | 50–59 | 11–19 × 11–19; 2-digit × 5, 25, 50 | 14 × 17, 36 × 25 | 10 s |
| T6 | 60–69 | 2-digit × 2-digit up to 40 × 40; multiples of 10 × 2-digit | 23 × 34, 60 × 47 | 12 s |
| T7 | 70–79 | 3-digit × 1-digit | 347 × 6 | 12 s |
| T8 | 80–89 | any 2-digit × 2-digit | 67 × 84 | 15 s |
| T9 | 90–100 | 3-digit × 2-digit up to 250 × 50 | 125 × 36 | 18 s |

### Division — exact, built from the multiplication of the same tier

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | facts of tables 1–5 | 28 ÷ 4 | 4 s |
| T1 | 10–19 | facts of tables 6–10 | 56 ÷ 8 | 5 s |
| T2 | 20–29 | dividends from 10–15 × 1–9; tens | 78 ÷ 6, 560 ÷ 8 | 6 s |
| T3 | 30–39 | dividends from 16–25 × 2–9 | 168 ÷ 7 | 7 s |
| T4 | 40–49 | 3-digit ÷ 1-digit | 522 ÷ 6 | 8 s |
| T5 | 50–59 | ÷ 11–19; ÷ 5, 25, 50 | 238 ÷ 14, 900 ÷ 25 | 10 s |
| T6 | 60–69 | 3-digit ÷ 2-digit up to 40 | 782 ÷ 34 | 12 s |
| T7 | 70–79 | 4-digit ÷ 1-digit | 2082 ÷ 6 | 12 s |
| T8 | 80–89 | 4-digit ÷ 2-digit | 5628 ÷ 67 | 15 s |
| T9 | 90–100 | 4-digit ÷ 2-digit, larger quotients | 4500 ÷ 36 | 18 s |

### Powers

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | squares 1–10 | 7² | 4 s |
| T1 | 10–19 | squares 11–15; 2¹–2⁶ | 13², 2⁵ | 5 s |
| T2 | 20–29 | squares 16–20; cubes 1–5 | 18², 4³ | 6 s |
| T3 | 30–39 | squares of 25, 35 … 95 and tens | 35², 70² | 6 s |
| T4 | 40–49 | squares 21–30; 2⁷–2¹⁰ | 27², 2⁹ | 8 s |
| T5 | 50–59 | squares 31–50; cubes 6–10 | 46², 8³ | 10 s |
| T6 | 60–69 | squares 51–70; 3¹–3⁶ | 58², 3⁵ | 12 s |
| T7 | 70–79 | squares 71–100 | 87² | 14 s |
| T8 | 80–89 | squares 101–125; cubes 11–15 | 112², 13³ | 16 s |
| T9 | 90–100 | squares 126–200; 5⁴, 6⁴, 7⁴ | 175², 6⁴ | 18 s |

### Roots — exact, mirror of powers

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | √ of squares 1–10 | √49 | 4 s |
| T1 | 10–19 | √ of squares 11–15 | √169 | 5 s |
| T2 | 20–29 | √ of squares 16–20; ∛ of cubes 1–5 | √324, ∛64 | 6 s |
| T3 | 30–39 | √ of squares of 25, 35 … 95 and tens | √1225 | 6 s |
| T4 | 40–49 | √ of squares 21–30 | √729 | 8 s |
| T5 | 50–59 | √ of squares 31–50; ∛ of cubes 6–10 | √2116, ∛512 | 10 s |
| T6 | 60–69 | √ of squares 51–70 | √3364 | 12 s |
| T7 | 70–79 | √ of squares 71–100 | √7569 | 14 s |
| T8 | 80–89 | √ of squares 101–125; ∛ of cubes 11–15 | √12544, ∛2197 | 16 s |
| T9 | 90–100 | √ of squares 126–200 | √30625 | 18 s |

### Percentages — whole-number answers

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | 50 %, 10 % of tens up to 100 | 50 % of 80 | 4 s |
| T1 | 10–19 | 25 %, 20 % of round numbers | 25 % of 120 | 5 s |
| T2 | 20–29 | 10 %, 20 %, 50 % of 2-digit and 3-digit numbers | 20 % of 350 | 6 s |
| T3 | 30–39 | 5 %, 75 % | 75 % of 64 | 7 s |
| T4 | 40–49 | 1 %, 15 %, 30 %, 40 % of hundreds | 15 % of 600 | 8 s |
| T5 | 50–59 | any multiple of 5 % | 35 % of 140 | 10 s |
| T6 | 60–69 | any whole percentage of a round hundred | 37 % of 300 | 10 s |
| T7 | 70–79 | 12.5 %, 37.5 %, 62.5 %, 87.5 % (eighths) | 37.5 % of 64 | 12 s |
| T8 | 80–89 | above 100 % | 150 % of 86, 120 % of 45 | 12 s |
| T9 | 90–100 | any whole percentage, 3-digit base, whole result | 64 % of 175 | 15 s |

### Integrals — area under the curve, whole-number answers

| Tier | Levels | Content | Example | Fluent |
|---|---|---|---|---|
| T0 | 0–9 | constant, from 0 | ∫₀⁴ 3 dx | 6 s |
| T1 | 10–19 | 2x, from 0 | ∫₀³ 2x dx | 8 s |
| T2 | 20–29 | 2x, from a to b | ∫₂⁵ 2x dx | 10 s |
| T3 | 30–39 | 2x + c, from 0 | ∫₀³ (2x + 4) dx | 12 s |
| T4 | 40–49 | 3x², from 0 | ∫₀³ 3x² dx | 12 s |
| T5 | 50–59 | 3x², from a to b | ∫₁³ 3x² dx | 14 s |
| T6 | 60–69 | degree 2 with linear term | ∫₀² (3x² + 2x) dx | 16 s |
| T7 | 70–79 | 4x³, from 0 or from 1 | ∫₁² 4x³ dx | 16 s |
| T8 | 80–89 | degree 3 mixed | ∫₀² (4x³ + 6x) dx | 18 s |
| T9 | 90–100 | degree 3–4, wider bounds | ∫₁³ (5x⁴ − 3x²) dx | 20 s |

Every integrand stays ≥ 0 on its interval, so the answer is an area.

## 6. Display

- **One line by default** (`47 × 8`, `2 468 + 785`).
- **Two lines, aligned on the right, when one line does not fit** the screen width at the play
  font size: the first number on top, the operator and the second number below, a rule, then the
  typed answer, all aligned on the units digit — like written column arithmetic. Applies to the
  four basic operations. The choice is made once per question, before it appears, from the real
  width (screen size and system text size); the layout never switches while the player types.
  The font is never shrunk to force one line.
- **Thousands grouped with a thin space** in questions and in the typed answer (2 468, 538 274 916)
  so long numbers stay readable.
- **Answers up to 10 digits** (the sum of two 9-digit numbers). The input cap, currently 7 digits,
  rises to 10.
- Powers, roots, percentages and integrals keep their current layout.
- Tabular figures everywhere, so digits stay aligned.

## 7. Tables mode (new)

Practice of multiplication tables from 1 to 50.

- Its own card on Home, under Challenges.
- Setup: **which tables** (a range within 1–50, e.g. 12–19) and **multiplier range** (1–10 or
  1–20); number of questions (10, 20, 50).
- Each question: a table number × a multiplier, both in the chosen ranges, shuffled by the seed;
  same game screen, timer and keypad as the operation games.
- Practice only: never moves levels, never ranked. Personal stats on the device (games, accuracy,
  slowest facts).

## 8. Tips page (new)

A page of mental-arithmetic advice, reached from a "Tips" card on Home.

- One section per operation, each split by tier band: **beginner (T0–T2), intermediate (T3–T5),
  advanced (T6–T9)**. Each tip = one sentence and one worked example. The player's own tier is
  highlighted.
- Content (to be written in that format):
  - **Addition**: make 10 (8 + 7 = 8 + 2 + 5); add tens then units; compensation (47 + 68 =
    47 + 70 − 2); left to right for long sums.
  - **Subtraction**: count up from the smaller number; round the subtrahend (603 − 298 =
    603 − 300 + 2); subtract across zeros by borrowing once (1000 − 357 = 999 − 357 + 1).
  - **Multiplication**: tables by patterns (× 9 = × 10 − 1); split the factor (7 × 46 = 280 + 42);
    × 5 = × 10 ÷ 2; × 25 = × 100 ÷ 4; × 11 for 2-digit numbers (43 × 11 = 4|7|3); doubling and
    halving (16 × 25 = 4 × 100); near a base (98 × 7 = 700 − 14); difference of squares
    (47 × 53 = 50² − 3²).
  - **Division**: think of the multiplication; halve repeatedly for ÷ 4, ÷ 8; ÷ 5 = × 2 ÷ 10;
    ÷ 25 = × 4 ÷ 100; split the dividend (522 ÷ 6 = 480 ÷ 6 + 42 ÷ 6).
  - **Powers**: squares ending in 5 (35² = 3 × 4 | 25 = 1225); near 50 (48² = 2500 − 200 + 4);
    (a + b)² = a² + 2ab + b²; powers of 2 by doubling.
  - **Roots**: the last digit narrows it (√…6 ends in 4 or 6); bracket between known squares;
    cube roots by the last digit (∛…7 ends in 3).
  - **Percentages**: 10 % = move the decimal point; build from 10 %, 5 % and 1 %; swap (8 % of
    25 = 25 % of 8); eighths for 12.5 %, 37.5 %.
  - **Integrals**: power rule (∫ xⁿ = xⁿ⁺¹ ÷ (n + 1)); F(b) − F(a); a constant is a rectangle;
    2x from 0 to b is a triangle of area b².
- The strategy detector built in Phase 5.1 links each tip to its strategy, so a later phase can
  show the right tip after a wrong answer.