# Design — Math Trainer

Visual direction and interface rules. **Not loaded automatically** — read it before any work on
`presentation/` or on the theme. `doc/plan.md` (section 6.2) names this file as the authority on
palette, typography, notation, layout and durations.

Guiding principle: the game sells on speed. Anything that slows reading, moves an element or asks
for an extra gesture is a defect, not a detail. Restraint is not an aesthetic here, it is a
functional constraint — the operation must be the only thing the eye catches.

## Chosen direction: "nuit électrique"

An openly competitive register, consistent with the product's path (leaderboard, ratings, duels).
The direction keeps its original French name.

### Palette — dark mode (default)

| Role | Hex | Use |
|---|---|---|
| Background | `#101528` | canvas of every screen |
| Surface | `#1B2340` | cards, keypad keys, fields |
| Border | `#2A3352` | separators, timer track |
| Accent | `#5DCAA5` | primary action, timer, active input, active tab |
| Primary text | `#E6F1FB` | operation, digits, titles |
| Secondary text | `#85B7EB` | labels, metadata |
| Muted text | `#5A6B8C` | inactive tabs, hints |

### Palette — light mode (mandatory, not optional)

A mobile game is played outdoors as much as in bed. Light mode is not a comfort variant.

| Role | Hex |
|---|---|
| Background | `#F4F6FB` |
| Surface | `#FFFFFF` |
| Border | `#D6DEEC` |
| Accent | `#0F6E56` |
| Primary text | `#101528` |
| Secondary text | `#3E5170` |
| Muted text | `#7A8AA6` |

### Right / wrong feedback

The accent being sea-green, **green cannot signal a correct answer** — it would be confused with
the action colour. And in any case:

**Feedback never relies on colour alone.** Simultaneous channels, ~120 ms:

- **Right** — brief white flash on the input field, slight scale (1.0 → 1.06 → 1.0), very short
  vibration where the platform has one.
- **Wrong** — `#E24B4A` flash, low-amplitude horizontal shake, longer vibration where available.

Haptics are absent in Safari on iOS; colour + motion still satisfies the rule.

**Sound** (Phase 5, on by default, one switch in Profile): synthesised, short and quiet —
a 18 ms tick for each on-screen key (not for a physical keyboard, which the player already
hears); a soft chime on a right answer that climbs a pentatonic scale from C5 with the streak,
up to 10 in a row; a low falling tone (G3) on a wrong answer or a timeout; a rising four-note
arpeggio for a level-up. Unlocked by the first tap or key (browser rule), silent while the page
is hidden. Never delays anything: scheduled after the answer is recorded.

**After a correct answer**: no intermediate screen, no "next" button, no pause beyond 150 ms. The
next question arrives as the flash fades.

**After a wrong answer or a timeout** (`doc/plan.md`, section 6.1; Phase 0, commit 9): the
correct answer stays visible for about one second before the next question. This is the only
pause the session allows — correcting an error is worth more than the second it costs, and
correct answers keep the fast flow.

During that pause (`SessionController.correctionDelay`, 1,000 ms): the question stays on screen,
the answer field shows the correct answer after the error feedback, and a muted caption under it
says "Your answer: 54" or "Time's up" (the caption line is always laid out, so nothing moves). The
timer bar freezes, keys are ignored, and the next question's clock starts after the pause — it
never counts in a response time. No pause after the last question: the result screen lists every
mistake.

## Typography

`Inter` (bundled in `assets/fonts/`, never fetched at runtime) for interface text. Two weights
only: 400 for running text, 500 for digits and titles. Never 600 or 700.

**Digits** — operations, typed answers, keypad, and the kit's scores and levels — use the display
face **Space Grotesk** (Phase 5, provisional pick, `doc/decisions.md`), weight 500, bundled as a
4.8 KB subset of digits, operators and "of" (`tool/fonts/subset_digits.py`); `TextStyle.digits`
(`app_theme.dart`) applies it with Inter as the fallback for letters.

**Tabular figures everywhere** (`FontFeature.tabularFigures()`). Without them, the answer being
typed shifts at every key and the eye loses its anchor.

| Element | Size |
|---|---|
| Operation | 48 sp, weight 500 |
| Typed answer | 32 sp, weight 500 |
| Screen titles | 17 sp, weight 500 |
| Labels | 13 sp, weight 400 |
| Metadata | 11 sp, weight 400 |

## Mathematical notation

These characters are non-negotiable — the hyphen and the caret are forbidden.

| Type | Rendering |
|---|---|
| Addition | `47 + 68` |
| Subtraction | `92 − 35` — true minus sign U+2212, never `-` |
| Multiplication | `24 × 7` — U+00D7, never `x` |
| Division | `96 ÷ 8` — U+00F7, never `/` |
| Power | full-size base, raised exponent at ~55 % of the size, never `^` |
| Square root | `√` with a **horizontal bar over the radicand** — without it, `√169` reads `√1` then `69` |
| Percentage | `25% of 80` — the word is kept |

The exponent is rendered with `Text.rich`: one `TextSpan` for the base, a raised and reduced span
for the exponent. The root bar is a plain `Border(top:)` on the radicand.

The domain exposes no display string: the presentation layer composes the prompt from each
variant's fields (`base`/`exponent`, `percent`/`base`, etc.). The word "of" in percentages lives
in the presentation, the only translatable part of the notation.

## Session screen

No navigation. Full screen over the tab bar — it frees room for a truly large operation and
prevents leaving a game by aiming at a tab.

Top to bottom: progress counter and **timer as a bar** (never as digits — a timer is not read
while calculating, it is perceived; and the bar shows the time of **the question**, not of the
session), type and level in muted text, the centred operation, the answer being typed below it,
then the keypad.

## Built-in keypad

**Always visible, never the native keyboard.** The system keyboard hides the field and the timer,
imposes an entrance animation, and offers useless keys.

Layout consequence to respect: **size the screen backwards** — keypad height fixed first, the
operation takes what remains. Nothing then moves between two questions, and the eye stays anchored
to the same spot for the whole session.

Layout: 1–9 on three rows, then a bottom row `backspace` / `0` / `validate`.

- **Validate on the right**: the thumb side for most people, and the most frequent gesture of the
  session — it must be the fastest.
- **Backspace on the left**: rarer, so further away.
- **No `−` key.** Associated product decision: subtraction never produces a negative result
  (`operandA ≥ operandB`). If that decision changes, the keypad changes too.

**Physical keyboard alongside the keypad** (web, desktop, tablet with keyboard): top-row digits
*without Shift* (physical keys — on AZERTY they produce "& é " …"), numeric keypad, backspace,
Enter to validate. Same paths as the touch keypad, hence the same timing. Input capped at 7 digits
(longest possible answer: 10⁵).

## Navigation

**Bottom tab bar**, four entries: Play, Online, Profile, Leaderboard. Online and Leaderboard are
previews until Phases 2 and 7.

No side drawer: two gestures instead of one, hidden navigation, and on a large phone it pushes the
thumb to the top-left corner, the least reachable spot. The bottom bar stays visible, reachable,
and will carry notification badges when duels arrive.

The Profile tab (formerly Progress) carries the player's identity (player name, email, sign-out)
alongside the statistics — an explicit owner decision that replaced the original "no fifth tab,
profile as a corner icon". The day/night toggle stays a corner icon on the Play screen.

## Animation

Snappy temperament, no whimsy. No bounce, no `elasticOut`, no decorative transition.

| Element | Duration | Curve |
|---|---|---|
| Answer feedback | 120 ms | `easeOut` |
| Key press | 60 ms | `easeOut` |
| Transition between questions | ≤ 150 ms | `easeOut` |
| Tab change | ≤ 200 ms | `easeInOut` |
| Level-up (result screen) | 600 ms | `easeOutCubic` |

The level-up is the only animation allowed to take its time: it is the emotional moment of solo
play, the only place where the player watches instead of reacting.

## Result screen

The end of the session and the moment the level system becomes visible.

Top to bottom: **the level change first** (`AppMotion.levelUp`, 600 ms), the score with its
breakdown (base, speed bonus, streak bonus, difficulty multiplier), right / wrong / **timed out
counted separately**, average time, best streak, and the types played. Then **Mistakes** (Phase 0
commit 9): every wrong answer and timeout in play order, as "7 × 8 = 56" in the session's
notation followed by "your answer 54" or "timed out" in muted text.

Accuracy is shown as a raw count ("9/12"), never as a curve nor as a percentage presented as
progress.

Two centred actions: **Play again** (dominant, filled) and **New selection**, pinned at the bottom
under the scrolling results — a long mistakes list never pushes "Play again" out of reach. Worth considering:
putting the type chips directly on this screen — changing a single type costs 3 taps today.

## Profile statistics

Four blocks, from general to detailed: overall level with its recent change; 30-day level curve;
breakdown per operation (level bar + **average time**, which tells the player where they are
slow); recent games with score and level change. Curve and changes all use the overall level after
each game (`doc/decisions.md`): one scale everywhere, whatever types were played.

Operations never played appear in a "not played" state rather than hidden — that is what makes
visible what the default selection leaves out.

## Kit (Phase 5)

Five components, `app/lib/presentation/kit/`, replace stock Material in their roles; every
screen uses them. Shared tokens in `AppMetrics`: `radius` 16 (the keypad's corner), `keyGap` 4,
`controlHeight` 52.

| Component | Role | Look |
|---|---|---|
| `AppButton.primary` | the screen's main action, one per screen | filled accent, 52 high, radius 16, title style |
| `AppButton.secondary` | every other action, in-text links, dialog actions; `destructive` for Delete | accent (or error) text only |
| `TypeChip` | an operation or a board to pick | surface, outline; selected: accent outline, tinted, check mark |
| `KeypadKey` | a key of the session keypad | **geometry pinned for the beta** |
| `StatTile` | one figure and its label | surface tile, number in the digit face, muted label |
| `LevelBadge` | a level, whole number | digit face in the accent, accent outline; a dash when not played |
| `OperatorIcon` | the operation, next to its name | the family below, in the accent |

**Operator icons** (`OperatorIconPainter`): + − × ÷ x² √ % drawn as one family on a unit square —
one stroke weight (11 % of the side), round caps, the same box; the root keeps its bar, the
power is a small x with a raised, thinner 2. On the type chips (always visible, the check mark
goes before the label when selected), the Profile's operation rows, the leaderboard's boards.
Decorative next to a label: excluded from semantics. The favicon and the web app icons are the
four basic operators in a 2 × 2 grid, dark Accent on dark Background, rendered from the same
painter (`app/tool/icons/render_web_icons_test.dart`).

Selection and emphasis never rely on colour alone: a selected chip has a check mark, the
player's own row stays bold with "(You)", a badge reads "Level 12" to screen readers.

## Layout rules

- **Uniform root padding on every screen** (`AppMetrics`).
- **A single screen-title style.**
- **Every `Text` names an explicit theme style.** No inherited default style.
- **Keypad height as a fixed value, never a ratio of the screen.** A ratio moves the layout from
  one device to another and contradicts sizing backwards.
- **An error message does not contain the action.** The text describes the problem, the button
  carries the action — one wording everywhere.
- **A disabled state explains why.** A greyed button without a message (empty type selection)
  leaves the player with no readable way out.

## Implementation rules

- **No colour, size or duration hard-coded in a widget.** Everything goes through `ThemeData` and
  theme extensions, read via `Theme.of(context)`.
- `SafeArea` on every screen.
- Both modes (light and dark) must be tested — a screen that only exists in dark is unfinished.
- **Golden tests** on the session screen, the result screen and the profile screen, in both modes.
  They are the only net against visual regressions.
- **No literal Flutter colour.** A fallback must come from the theme.
- **No `SizedBox.shrink()` as a screen state.** An empty screen is a dead end: message and exit
  action required.
- **Centralised labels**, on the model of `exercise_type_labels.dart`. Every string literal added
  in a widget is one more line to revisit at internationalisation.
