# Online — Math Trainer

Accounts, server, leaderboard, duels and rating. **Not loaded automatically** — read it before any
work on accounts, the network, `infrastructure/backend/` or the server. The product direction
lives in `doc/plan.md` (sections 6.3 to 6.5 and the roadmap); this file holds the technical
detail and the state of the code. Where the two disagree, the plan wins.

## Phasing

| When | What | State |
|---|---|---|
| Step 6, slice 1 | Email/password sign-up and sign-in | done (`0d884c1`) |
| Step 6, slice 2 | Mandatory sign-in, player name, Profile tab | done (`7400f9b`) |
| Phase 1 | Anonymous-first, existing accounts migrated, account deletion, real SMTP | planned |
| Phase 2 | Monorepo, Dart server, session upload, replay validation, leaderboard | planned |
| Phase 7 | Ghost duels, Glicko-2, friend challenges; live duels on owner decision | planned |

The old "slice 3" (leaderboard, sync, validation service) is Phase 2 of the plan.

## Current state (step 6, slices 1–2)

- Supabase client in `infrastructure/backend/`, behind `AccountRepository`/`ProfileRepository`
  (`core/domain/account/`). The Supabase SDK is never imported outside `infrastructure/` and
  `composition_root.dart`.
- **Sign-in is mandatory** (`AuthGate`). This is the current behaviour, **not the direction**:
  the plan replaces it with anonymous-first in Phase 1 (section 6.3). Supabase persists the
  session locally, so a player who has signed in once plays offline afterwards; only a fresh
  browser or an explicit sign-out needs the network.
- Email confirmation is **off** in the Supabase project for development: the default mailer only
  sends to organisation members. Phase 1 turns it on with a real SMTP sender and a site URL.

### Player name

Postgres table `profiles` (`id` references `auth.users.id`, `display_name`) rather than Auth
`user_metadata`: `user_metadata` is not designed to be readable by other players, while a player
name must be (RLS: public read, write restricted to one's own row) — and it is the table the
leaderboard needs to show a name next to a level.

Schema and RLS versioned in `supabase/profiles.sql` (idempotent, run by hand in the project's SQL
editor). No sign-up trigger: the row is created by the first chosen name (`upsert`), and a missing
row reads as "no name chosen" (`maybeSingle`). Name limited to 30 characters (`check` constraint,
same bound in the input dialog). Player names are public content: a name filter and a report
action come before the leaderboard opens (Phase 2, commit 7).

### Identity: `playerId` is the account id

Decision of 17 Nov 2026, replacing the initial approach that kept the device UUID
(`LocalPlayerIdProvider`) as `playerId` and linked the account server-side. With that approach two
accounts on the same browser shared levels and history.

- On sign-in, `AuthGate` swaps the device id for the account id (`environmentForAccount`): screens
  only ever read and write under the account.
- Games played under the device id are adopted by the first account that signs in on that device
  (`SessionRepository.transferPlayerData`): one transaction rewriting `player_id` in `sessions` and
  `player_levels` — `answers` follow through `session_id`. Never a merge: if the account already
  has data on the device, nothing is adopted.
- For upload (Phase 2), a local row carries the id that RLS checks (`auth.uid()`) directly, with no
  mapping table.
- Anonymous-first (Phase 1) keeps this: an anonymous Supabase user has an id from the first launch,
  and linking an email keeps the same id, hence the same history.

## Backend: Supabase + a Dart server

Supabase provides Auth and Postgres (native aggregations, `ORDER BY` and window functions suit
rankings). **Supabase never computes a level.**

Supabase Edge Functions run Deno/TypeScript; the pure-Dart core cannot run there, and duplicating
`LevelUpdater`/`Scorer` in TypeScript would mean two implementations to keep in sync — exactly what
architecture rule 1 prevents. Hence a **separate Dart server** (`shelf`, in a container) that
reuses the core unchanged. Its host and monthly budget are an owner decision (Phase 2, commit 2).

Code layout, from Phase 2 commit 1: monorepo `app/` (the Flutter app), `packages/math_core/` (the
pure-Dart core, imported by both sides through a path dependency), `server/`.

The Supabase service-role key exists only on the server, never in the app nor in the repo.

## Data flow (Phase 2)

1. The player plays solo exactly as today; local storage stays the source of truth for solo play.
2. After every finished or interrupted session, the session and its answers go into an offline
   upload queue with retries. The endpoint is idempotent on the session id; `syncedAt` (already on
   every row) marks what has been accepted.
3. The server regenerates the exercises from the seed and the frozen levels with the same core,
   rechecks every answer, replays the level updates and writes the validated rows. A mismatch is
   rejected and flagged.
4. The leaderboard reads only server-written levels; everyone reads it, only the server writes it.

## Rankings (Phase 2)

- Ranked on **level**: one overall board, one board per operation. Ordered on the continuous level
  value, displayed as an integer.
- **Eligibility**: a minimum number of sessions per operation and play within the last 30 days.
  Inactive players leave the board; their level never decays.
- **Default view**: the player's percentile plus the five players above and below; top 100 in a
  second tab; friends later. No weekly leagues in v1.
- **Anti-cheat**: replay stops forged results, not a calculator in solo play. Implausible timing
  (multi-digit answers under ~300 ms, unnaturally flat times) is flagged for review, never
  auto-banned.

Open, to settle in the Phase 2 plan: exact table schema, minimum sessions for eligibility.

## Online play (Phase 7)

- **v1 — ghost duels**: race a real player's recorded run, replayed live at its original pace.
  Needs nobody else online; the interface says so plainly.
- **Duel configuration differs from solo**: fixed quotas per type, difficulty from the rating
  bracket, never from either player's levels; 10 questions, 3–4 types. Same seed and duel
  configuration give identical questions on both sides (architecture rule 2).
- **Rating: Glicko-2**, server-side only, provisional for the first ~10 duels. Rating and level are
  two numbers on two screens.
- **v2 — friend challenges**: a link, same seed, 48 hours to answer.
- **v3 — live duels**, only when the owner decides that concurrency allows queues under ~20 s. Each
  client times its questions locally and reports results — no shared live clock, so the network
  never touches per-question timing. A player who drops is replaced by their recorded progress,
  then their ghost.
- Duel results and ratings are computed by the server only.

Nothing in this section is built before Phase 7; it exists so that Phase 1 and 2 choices do not
have to be undone.

## Settled decisions

- Email/password sign-in (slice 1); Google sign-in later (plan, section 6.3).
- Player name in a dedicated `profiles` table, not `user_metadata`.
- `playerId` = account id; device games adopted by the first account that signs in.
- Dart server for validation, never Supabase Edge Functions; monorepo layout above.
- Anonymous-first replaces mandatory sign-in (plan, section 6.3) — design to be approved by the
  owner before Phase 1 commit 1.
- Glicko-2 rather than Elo; ghost duels before live duels (plan, section 6.5).
