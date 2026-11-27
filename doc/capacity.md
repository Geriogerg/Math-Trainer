# Capacity report — Phase 6c (27 November 2026)

What the launch can carry, sized for **about 1,000 players** (the owner's answer to the
review, plan v3.9: "Launch sized for ~1,000 players. Render always-on from launch; Supabase
free with an alert at 50 %"). Measured where it could be, estimated (and said so) where it
could not. Re-read it when the dashboard's numbers move.

## Measured

| What | Number | Where from |
|---|---|---|
| Main board, 10,000 players and 1,000,000 games | 291 ms recomputed, 1.4 ms cached (60 s) | Phase 6a commit 5, local Postgres |
| Matchmaking at the same size | 59–78 ms | Phase 6a commit 5 |
| 2,000 crafted refused uploads | 2.8 MB stored (was 498 MB) | Phase 6a commit 2 |
| Production database today | 14 MB, 2.8 % of the free plan's 500 MB | `owner_dashboard.database_usage`, 27 Nov |
| Stored games | 255, 728 kB; 1.85 kB per upload on average | production, 27 Nov |
| Accounts | 71, of which 63 guests | production, 27 Nov |
| First visit, slow 4G | gate in 15–17 s, first question in 20–23 s | Phase 5.1 (`doc/architecture.md`) |
| Semantics on a low-end phone profile | no measurable cost (first frame, frame times, main thread) | Phase 6c commit 0 |

## At 1,000 daily players (estimates)

Assumption, to be replaced by the dashboard's real numbers: **5 games a day** per player,
**20 board or Online views** a day, **1 duel** a day.

| Resource | Limit | Estimated use | Margin |
|---|---|---|---|
| Supabase database (free) | 500 MB; the dashboard's alert at 50 % | 5,000 games × ~1.5 kB ≈ 7.5 MB a day: **50 % in about a month** | the plan's rule: Supabase's paid plan when the alert fires |
| Supabase monthly active users (free) | 50,000 | guests count; unused guests are deleted after 30 days | wide |
| Supabase egress (free) | 5 GB a month | ~2 kB × 20 views × 1,000 × 30 ≈ 1.2 GB, plus uploads and duels | watch it on Supabase's usage page |
| Supabase built-in email | a few emails an hour for the whole project | confirmations and recoveries: tens a day | **not enough: the owner's email service is a switch-on prerequisite** |
| Render (server) | the free plan sleeps (a minute to wake); always-on: one small instance | 5,000 uploads (a few ms of replay each) and ~1,000 duels a day | always-on is a switch-on prerequisite; one instance is far from busy |
| Cloudflare Pages | static files unlimited; the Pages Function (HTML only) 100,000 calls a day on the free plan | a few page loads per player a day | wide |
| Cloudflare Turnstile | free | one check per new guest and per sign-in | wide |

## Floors under abuse (in the code)

| Floor | Value |
|---|---|
| Requests per address (server) | 120, then 2 a second |
| Requests per player (server) | 40, then one every 2 seconds |
| Accepted games per player | 300 a rolling day |
| New duels per player | 200 a rolling day |
| Refused uploads kept | 50 a day per player, as a 1 kB digest |
| Error reports (commit 5, bounded in 6) | 10 per address then one every 6 minutes; 500 a day in all, kept 14 days — at most about 38 MB |
| Anonymous sign-ins (Supabase) | 30 an hour per address; Turnstile once switched on |
| Supabase calls (app) | 15 s each, then offline |

**Corrected here**: commit 5 kept 2,000 error reports a day for 30 days — a flood of the
longest could have held about 300 MB, most of the free database. Now 500 a day for 14 days
(migration `20261204020000_client_errors_bounds.sql`).

## What to watch after launch

- `bash tool/dashboard/dashboard.sh usage` — the database against 500 MB; ALERT from 50 %.
- `bash tool/dashboard/dashboard.sh errors` — what goes wrong in players' apps.
- `bash tool/dashboard/dashboard.sh` — games, players, the beta's progress.
- Supabase → Usage (egress, monthly active users); Render → Metrics (CPU, memory, restarts).

## What this report cannot know

How many players come, how much each plays, how many save an account or duel. The
estimates above are a guess at 1,000; the first week's dashboard replaces them.
