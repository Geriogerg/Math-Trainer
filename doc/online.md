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
| Phase 1 | Anonymous-first (commit 4, done), linking and account screens, account deletion | in progress |
| Phase 6 | Email confirmation with a real SMTP sender, CAPTCHA | planned |
| Phase 2 | Monorepo, Dart server, session upload, replay validation, leaderboard | planned |
| Phase 7 | Ghost duels, Glicko-2, friend challenges; live duels on owner decision | planned |

The old "slice 3" (leaderboard, sync, validation service) is Phase 2 of the plan.

## Current state (Phase 1, commit 4)

- Supabase client in `infrastructure/backend/`, behind `AccountRepository`/`ProfileRepository`
  (`math_core/lib/account/`). The Supabase SDK is never imported outside `infrastructure/` and
  `composition_root.dart`.
- **Anonymous-first** (`AuthGate`, plan section 6.3). No session on launch → the gate calls
  `AccountRepository.signInAnonymously()` once (guarded against repeated "no session" events)
  and goes straight to the game; failure → `StartErrorView` (no connection / rate limited /
  other) with "Try again". The session is persisted locally like any other, so later launches
  work offline. The gate never starts an anonymous sign-in before the local session is resolved,
  or a returning player would get a second, empty account. `Account.isAnonymous`; a guest has
  no email (Supabase reports `''`, mapped to `null`).
- **No sign-out for a guest** (Profile shows "Guest — progress saved on this device only"): it
  would lose the account for good. An email account still signs out; a new guest is then
  created. Linking, sign-in to an existing account and deletion: commits 5 and 7.
- **Linking** (commit 5, Profile → "Save your progress"): email, password and player name.
  `AccountRepository.linkEmail` = one Supabase `updateUser(email, password)` call, checked on
  the real project (19 Nov 2026): atomic (a weak password, 422 `weak_password`, leaves the
  guest untouched), applied at once with confirmation off, same id, `is_anonymous` false; a
  taken email answers 422 `email_exists`. The name is saved after; if only the name fails, the
  progress is still linked and the player is told. The flow lives in `AccountFormController`
  (`core/state/`); `SaveProgressScreen` and `SignInScreen` render it.
- **Email already used / "I already have an account"**: `SignInScreen` with a warning when the
  guest has played — the account replaces the guest on this browser. The guest's local games
  are **kept** in SQLite under the guest id (not deleted, not shown, never merged); its server
  user stays until Phase 2's cleanup of stale guests.
- Sign-up from scratch no longer exists (`signUp` and `AuthForm` removed): a new player is a
  guest, and saving their progress replaces sign-up.
- **Account deletion** (commit 7), every player, guests included: Profile → "Delete my
  data" (guest) / "Delete my account", after a confirmation. `AccountDeletionController`:
  1. `AccountRepository.deleteAccount()` — RPC `delete_my_account()`
     (`supabase/migrations/20261119000000_delete_my_account.sql`, `security definer`, deletes only `auth.uid()`; the
     profile and Supabase's sessions follow by cascade). If it fails, **nothing** is touched;
  2. `SessionRepository.deletePlayerData(id)` — this player's sessions, answers and level
     cache on this device, atomically; other players on the device untouched;
  3. local sign-out → `AuthGate` creates a fresh guest.
  If the local wipe fails after the server deletion, the player is still signed out and told
  that data stayed on the device. Device settings (theme, type selection) are kept.
- Supabase project settings this relies on: anonymous sign-ins **on** (owner, 19 Nov 2026);
  built-in rate limit on anonymous sign-ins (30 per hour per IP) until CAPTCHA (Phase 6);
  `delete_my_account()` (run by hand in Phase 1, a migration since Phase 2 commit 2). Checked
  live: the CI smoke test's guest deletes itself through it (first green run 19 Nov 2026).
- Email confirmation is **off** in the Supabase project for development: the default mailer only
  sends to organisation members. Phase 1 turns it on with a real SMTP sender and a site URL.

### Player name

Postgres table `profiles` (`id` references `auth.users.id`, `display_name`) rather than Auth
`user_metadata`: `user_metadata` is not designed to be readable by other players, while a player
name must be (RLS: public read, write restricted to one's own row) — and it is the table the
leaderboard needs to show a name next to a level.

Schema and RLS versioned in `supabase/migrations/20261117000000_profiles.sql` (idempotent: it was
run by hand before migrations existed). No sign-up trigger: the row is created by the first chosen name (`upsert`), and a missing
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

## SQL: migrations applied by CI (Phase 2 commit 2)

Every change to the Supabase database is a file in `supabase/migrations/`
(`<timestamp>_<name>.sql`, applied in name order). Nobody runs SQL by hand any more.

- **CI `sql` job, every push**: a scratch Postgres 17 (service container) gets
  `supabase/tests/00_supabase_stub.sql` — a stand-in for the parts of Supabase the migrations
  use (roles `anon`/`authenticated`/`service_role`, `auth.users`, `auth.uid()`, default grants)
  — then every migration **twice** (each must be idempotent), then `supabase/tests/*_test.sql`
  (PL/pgSQL `assert`s; row-level security exercised with `set role` and JWT claims).
  Locally: `bash tool/sql/test_sql.sh <postgres admin url>`.
- **CI `migrations` job, on `main` after `test` and `sql`**: Supabase CLI (`supabase/setup-cli`),
  `supabase link` (project ref = subdomain of `SUPABASE_URL`), `supabase db push` — applies the
  migrations the project has not recorded yet. Secrets `SUPABASE_ACCESS_TOKEN` and
  `SUPABASE_DB_PASSWORD`, never printed; missing → a warning and nothing applied. `deploy` waits
  for it, so the preview never expects SQL the project lacks.
- The stand-in is not Supabase: a migration that relies on something else of Supabase's must
  add it to the stub first.

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

## The server (Phase 2 commit 4 on)

`server/`: a Dart package (`shelf` + `http`, `math_core` by path), AOT-compiled into a small
container (`server/Dockerfile`, built from the repo root). Configuration only from environment
variables (`server/lib/src/config.dart`): `SUPABASE_URL`, `SUPABASE_SECRET_KEY` (refused if it is
the publishable key; never printed), `PORT` (default 8080), `ALLOWED_ORIGINS` (web origins
allowed by CORS — the preview `https://math-trainer-kjc.pages.dev` and the old
`https://geriogerg.github.io`, now a redirect). `GET /health` answers
`{"status":"ok"}`; errors are JSON, a 500 never carries details. CI (`server` job): analyzer,
tests, and the image builds and answers `/health`.

### Deploying the server — decided by the owner: Render free (plan v2.3)

`render.yaml` is a Render Blueprint, inert until the owner creates it in Render. Steps, once
the owner says yes:

1. render.com → sign up with GitHub → **New → Blueprint** → pick `Geriogerg/Math-Trainer`.
   Render reads `render.yaml`: one web service, Docker, free plan, deploys `main` when `server/`
   or `packages/math_core/` change.
2. When asked for the two secret values: `SUPABASE_URL` (same as the GitHub secret) and
   `SUPABASE_SECRET_KEY` — Supabase dashboard → Project Settings → API Keys → **Secret keys** →
   create one named `math-trainer-server`, copy it into Render only.
3. Copy the service URL Render shows (`https://math-trainer-server-….onrender.com`) into a
   GitHub **repository variable** (not a secret: it is public) named `SERVER_URL` — the web
   build passes it to the app (commit 5).

### Moving the preview to Cloudflare Pages (Phase 3a commit 1) — after the owner's yes

Brotli instead of gzip: ~920 KB and ~4.6 s less on slow 4G (`doc/decisions.md`, "Preview
host"). Prepared and dormant in `ci.yml`; nothing changes until step 4. Steps for the owner:

1. dash.cloudflare.com → sign up (free). The account id is on the right of **Workers & Pages**
   (or in the URL after `dash.cloudflare.com/`).
2. My profile → **API Tokens** → Create token → template **Edit Cloudflare Workers** (it
   includes Cloudflare Pages: Edit) → limit it to this account → create, copy once.
3. GitHub → Settings → Secrets and variables → Actions:
   - **Secrets**: `CLOUDFLARE_API_TOKEN` (step 2), `CLOUDFLARE_ACCOUNT_ID` (step 1).
   - **Variables**: `PREVIEW_URL` = `https://math-trainer-kjc.pages.dev`, the project's
     address. **Not** `https://math-trainer.pages.dev`: that name belongs to someone else's
     site, so Cloudflare added a suffix. CI checks the variable against the project (job
     deploy-cloudflare, run summary and annotation) and holds back the redirect and the smoke
     test until they match.
4. Variables: `PREVIEW_HOST` = `cloudflare`. **This is the switch**: the next push (or
   Actions → CI → Run workflow on `main`) builds for the root path, creates the Cloudflare
   project, deploys there, smoke-tests the new address, and turns GitHub Pages into a redirect.
5. Supabase → Authentication → **URL Configuration**: Site URL = the new address; Redirect URLs:
   add `https://math-trainer-kjc.pages.dev/**` (keep the GitHub one until no link points there).
6. Render → the service → **Environment** → `ALLOWED_ORIGINS` =
   `https://math-trainer-kjc.pages.dev,https://geriogerg.github.io` (as in `render.yaml`; the
   dashboard value is what runs), save, let it redeploy.

Your own progress on the old address stays in that browser for the old origin: if you saved it
to an email, sign in at the new address; a guest starts over. No tester is affected as long as
the move happens before the invitations.

## Beta gate (Phase 3a commit 3)

- **Tables** (`…_beta_codes.sql`): `beta_codes` (code, label — who it is for —, `max_uses`,
  `disabled`) and `beta_code_uses` (one row per player who came in with a code; cascades with
  the account, so a deleted account frees its use). Not exposed to the API.
- **Functions**: `beta_code_status(code)` (no session needed: the gate screen asks it before the
  guest exists) → `ok`/`unknown`/`full`/`disabled`; `redeem_beta_code(code)` (the new guest) →
  `redeemed`/`already`/…, row-locked against two players racing for the last use;
  `create_beta_code(label, max_uses)` for the owner only (random 8 characters from 32 easy ones).
  Codes are compared upper-case without spaces or dashes.
- **App**: built with `BETA_GATE=true` (CI: repository variable `BETA_GATE`), `AuthGate` shows
  `BetaGateScreen` on a device with no session and no accepted code, *before* creating the guest;
  "I already have an account" signs in without a code. The accepted code is kept on the device
  (`BetaCodeStore`): a later guest on that device (after signing out of an email account) is not
  asked again, and `redeemDeviceBetaCode` ties each new guest to it after sign-in.
- **Not enforced server-side**: someone calling Supabase directly can create a guest without a
  code; their data shows as "no code" in the dashboard. Enough for an invite-only beta
  (`doc/decisions.md`).

### Turning the gate on — owner, when sending the invitations

1. Create the codes with the dashboard script (commit 6): one per tester or group.
2. Create one more, labelled for the CI smoke test (its account deletes itself, which frees the
   use: `max_uses` 2 is enough), and store it as the repository **secret** `SMOKE_BETA_CODE`.
3. Repository **variable** `BETA_GATE` = `true`, then re-run CI: the next preview asks for a code.

## Feedback (Phase 3a commit 5)

Profile → "Send feedback": one free text (≤ 2,000 characters, `math_core/feedback`), sent by
`send_feedback(message, app_version)` (`…_feedback.sql`): stored trimmed in `feedback` with the
player id and the app version — the build's commit, `APP_VERSION` from CI (`dev` locally). At
most 20 messages per player per 24 hours (`tooMany`). Not queued offline: a failed send keeps
the text on screen. Players cannot read the table; it cascades with the account. The owner
reads it with the dashboard script (commit 6); Phase 3b triages it.

## Owner dashboard (Phase 3a commit 6)

SQL views in the schema `owner_dashboard` (`…_owner_dashboard.sql`; the API never exposes it,
the API roles cannot enter it), printed by `tool/dashboard/dashboard.sh` on the owner's
machine — never in CI on live data (public logs). Sections of the report: Phase 3b readiness
(~300 completed games from 10+ testers), active testers (1/7/30 days), sessions per day,
testers by invitation code (and "(no code)"), answer times per operation and level band (median,
quartiles, % right; games only — placement levels move within the session), interrupted games
(7/30 days), refused uploads per reason, timing flags, names awaiting review, latest feedback,
and the state of the `cleanup-stale-guests` cron job with its last runs.

Chores: `new-code <label> [max uses]`, `codes`, `disable-code <code>`, `approve-name <id>` /
`clear-name <id>` (`owner_dashboard.review_name`: an approved name is never hidden again —
`name_reviews`, read by `public_display_name`; a cleared one is removed from the profile),
`feedback [count]`. Every command is exercised by `tool/sql/test_sql.sh` on the scratch database.

### Connecting — owner, once

Supabase → **Connect** → *Session pooler* (works over IPv4) → copy the URI, put the database
password in place of `[YOUR-PASSWORD]`, save it as the only line of
`tool/dashboard/connection.txt` (git-ignored). Needs `psql` 15+ (installed with PostgreSQL on
this machine). Then `bash tool/dashboard/dashboard.sh`.

## Type placement (Phase 3a commit 7)

`buildSessionController`: when the selection holds operations with no level yet
(`neverPlayedTypes`), Start builds `buildTypePlacementController` on those operations only — the
placement test's staircase, rules version 3, kind `typePlacementV3`, 5 questions per operation in
turn (`typePlacementSequence`, by enum index). Replay checks the stored rotation against the
operations; validation (shared) refuses an operation the server already has a level for
(`typeAlreadyPlayed`) or a start other than 35, and sets the placed levels with
`sessionsPlayed` 0 (calibration boost kept). The Play tab says it under Start ("First time on
Powers: 5 quick questions find your starting level."); the result screen lists the placed
operations.

## Data check for Phase 3b (Phase 3a commit 8)

`owner_dashboard.data_check` (`…_data_check.sql`, `…_input_device_app_version.sql`): every
uploaded answer checked against what calibration needs — operation; level at the time (a game's
frozen level, or a placement's seed and rotation to replay its staircase); response time
(0–15 s); correctness and the typed value (−1 = timeout); structure (each operation's operands,
integers); time answered; input device (none only for a timeout with no key pressed); the
session's app version. One row per requirement: answers checked, failing, one session to
inspect. `dashboard.sh data-check` prints it with a verdict and what is **not stored at all**
(the timeout in force). `math_core/test/sync/phase3b_fields_test.dart` holds the upload format
to the same eight requirements for all seven operations.

### Input device and app version (owner decision after Phase 3a)

Each answer stores how it was typed — `inputDevice`: `keypad` (on-screen), `keyboard`
(physical), `mixed` (both in one answer), absent for a timeout with no key pressed; each session
the build that played it — `appVersion`. App: `SessionScreen` tells the controller which source
every key came from (`registerActivity`, `submitAnswer`), SQLite schema v8 (`answers.input_device`,
`sessions.app_version`, `NULL` for what was played before). Upload: optional fields, same
`formatVersion` (`SessionUpload`). Dashboard: answer times per operation, level band **and
input device** (`answer_times_by_input`, replacing `answer_times`), games per build
(`app_versions`).

The smoke test also checks the whole online path when the build has a server: after its game it
reads the guest's `my_server_levels()` until the server has validated the upload (≤ 150 s,
covering a sleeping free instance), then deletes the guest either way.

## Session upload (Phase 2 commit 5)

- **The queue is the local database**: `SessionRepository.pendingUploads(player)` — sessions
  never accepted (`synced_at` null) nor refused (`upload_refused` null, schema v7), **oldest
  first**. `SessionUploadQueue` (`math_core/sync/`) sends them one at a time: the server checks
  that levels chain from one session to the next, so order matters. Accepted → `markSynced`
  (session and answers get the server's `received_at`); refused → `markUploadRefused(reason)`,
  never resent; a network or server failure stops the pass and retries after 30 s, 1, 2, 5,
  then every 10 min. Flushed at sign-in (`AuthGate`) and after every session flow
  (`playSessionFlow`); one pass at a time, a call during a pass makes it run once more.
- **Format**: `SessionUpload` (`math_core/sync/`), JSON, `formatVersion` 1 — the session's stored
  fields (seed, kind, enabled types, frozen levels in hundredths, type sequence, `createdAt`) and
  its answers in order. One codec for the app and the server; strict parsing (a wrong type is a
  400, never a guess). A game interrupted before schema v6 has no type sequence: refused
  locally (`notReplayable`), never sent.
- **App**: `HttpSessionUploadClient` (`infrastructure/backend/`, package `http`), the player's
  Supabase access token as bearer (`AccountRepository.accessToken`, refreshed if expired).
  Only the server's own answer is final; offline, timeout (90 s: a free host wakes up in about
  a minute), 401, 5xx or a non-JSON page → retry later. `SERVER_URL` (`--dart-define`, from the
  repository variable in CI) empty → no client: sessions stay local and pending until a build
  has one.
- **Server**: `POST /v1/sessions` — bearer checked by Supabase Auth (`GET /auth/v1/user`), body
  ≤ 256 KB, parsed, the session's player must be the caller, then `record_session_upload`
  (service role only): **idempotent** on the session id — `inserted`, `duplicate` (resent after
  a lost answer: same `received_at`) or `conflict` (another player's id: refused). Answers 200
  `{status: accepted, syncedAt, duplicate}`, 400/409 `{status: refused, reason}`, 401, 413, 503.
- **Table** `uploaded_sessions` (id, player_id → `auth.users` on delete cascade, created_at,
  received_at, kind, payload jsonb): RLS on, no policy, API roles' grants revoked — only the
  server reads and writes it.

## Server levels before each game (Phase 3a commit 2)

`buildSessionController` first calls `syncLevelsBeforeGame` (`math_core/sync/server_levels.dart`)
when the build has a server: if **no session waits to be uploaded**, it reads the player's server
levels (`my_server_levels()`, Supabase, own rows only — not the Dart server, which may be asleep)
and, if level or session count differ, replaces the local cache with them. At most 2 s; offline,
slow or failing → the local levels, as before. With uploads pending it does nothing: those
sessions chain from the local levels, and the server's would roll them back. Effect: a game on a
second device starts where the other device left off and is accepted, instead of refused
(`levelsMismatch`) and the levels adopted only afterwards.

Refused sessions keep their reason (`sessions.upload_refused`, read into
`PersistedSession.uploadRefused`); Profile's recent sessions say under such a game why it is not
ranked (`presentation/upload_refusal_text.dart`, one sentence per `RejectionReason`).

## Replay and validation (Phase 2 commit 6)

`validateSessionUpload` (`math_core/validation/`, pure, VM and JavaScript) decides every upload
from the server's own state (`ServerPlayerState`: level cache, last accepted session, whether
one was completed):

1. the caller is the session's player; `createdAt` not after reception + 5 min, not before the
   last accepted session; 1 to `exerciseCount` answers, each 0–15 s;
2. **every question regenerated** with `replaySessionQuestions` and compared with the stored
   one; **correctness recomputed** from the submitted value (a placement's next question
   depends on it, so in order);
3. **the chain**: a game's frozen levels must be the server's current levels (level 1 for a
   type never played); a placement's, its rules' starting level; a completed placement only
   before any completed session;
4. level updates **replayed with the app's own functions** (`gameLevelUpdates`,
   `placementLevelUpdates`), with the session's `createdAt` as "now"; an interrupted session
   is stored, no level moves;
5. implausible timing flagged, never refused: ≥ 2 right multi-digit answers under 300 ms
   (`implausiblyFast`), or response-time spread under 40 ms over ≥ 8 right answers
   (`flatTimes`).

Refused → `upload_rejections` (once per id; a resend gets the same verdict) and 409
`{status: refused, reason}`; for `levelsMismatch` the answer carries the server's levels and
the app **adopts them** (`replaceLevelCache`), so its next games chain again — the refused
session stays in local history, off the board. Accepted → `apply_validated_session`, one
transaction: the session (`uploaded_sessions`), its level updates (`server_levels`), its
flags (`upload_flags`), the player's version (`server_players`) — optimistic lock: a
concurrent upload makes it "stale", the server re-reads and re-validates (3 tries, then 503).
All four tables: RLS on, API grants revoked; the four functions are the service role's only.

Exit-test evidence: `app/test/state/server_replay_test.dart` plays a placement, four games and
an interrupted game through the app's builders, then validates the six uploads in order: the
server's levels equal the app's cache — level, sessions played, update time.

## Data flow (Phase 2)

1. The player plays solo exactly as today; local storage stays the source of truth for solo play.
2. After every finished or interrupted session, the session and its answers go into an offline
   upload queue with retries. The endpoint is idempotent on the session id; `syncedAt` (already on
   every row) marks what has been accepted.
3. The server regenerates the exercises from the seed and the frozen levels with the same core,
   rechecks every answer, replays the level updates and writes the validated rows. A mismatch is
   rejected and flagged.
4. The leaderboard reads only server-written levels; everyone reads it, only the server writes it.

## Leaderboard data (Phase 2 commit 7)

Read straight from Supabase by the app (no server hop: a sleeping server never slows a
screen), through two `security definer` functions everyone may call — signed out included —
which return only rank, player name and level; the tables themselves stay closed:

- `leaderboard_top(board)`: at most 100 entries `{rank, name, level, isMe}`, best first;
- `leaderboard_around_me(board)`: `{eligible: true, rank, total, topPercent, level,
  neighbours}` (five above and five below, the caller included), or `{eligible: false, reason,
  sessionsNeeded}` with `reason` ∈ `signedOut`, `noSessions`, `notEnoughSessions`, `inactive`.

**Linked players only** (commit 10, plan 6.3): `leaderboard_rows` skips anonymous accounts
(`auth.users.is_anonymous`); a guest's own standing answers `notLinked` before any other
reason, and the tab offers "Save your progress" (the Profile screen) — same id once linked,
so their place appears at once. A guest's sessions are uploaded and validated like anyone's.

`board` is `overall` or an `ExerciseType` name. Ranked on the level in hundredths, descending
(`rank()`: equal levels share a rank); displayed as a whole number. Overall level = mean of the
seven, an unplayed one counting as level 1 (the app's `overallLevel`), rounded to hundredths.
"Top N %" = ⌈100 × rank / total⌉. **Eligibility, provisional**: an accepted session within 30
days; per operation, ≥ 3 counted sessions on it (`sessions_played`); overall, ≥ 3 completed
games. Inactive players leave the board; their level never decays.

### The Leaderboard tab (Phase 2 commit 8)

`LeaderboardScreen` replaces the tab's placeholder: board chips (Overall and the seven), "Around
me" (default: "Top N %", "Rank r of t · level L", the neighbours) and "Top 100". The player's own
row is bold and labelled "(You)" (rule 14); a nameless player reads "Player". Not on the board:
the reason in words, with the games still missing. Reloads every time the tab is shown; offline
→ "Could not load the leaderboard." and Retry. State in `LeaderboardController`
(`core/state/`); reads through `LeaderboardRepository` (Supabase RPC, no server hop).

## Player names: filter and reports (Phase 2 commit 9)

- **The rule** (`math_core/account/display_name.dart`, mirrored by `public.display_name_problem`
  in SQL; a VM test checks the migration holds the same character class and word lists): 1–30
  characters, no leading/trailing/double space, at least one letter or digit, only letters the
  bundled Inter draws — Basic Latin, Latin-1, Latin Extended-A, Vietnamese, modern Greek, basic
  Cyrillic — digits, space and `. _ ' -`; no blocked word (a short English/French list: long
  words anywhere once separators are removed, short ones at the start of a word).
  `app/test/presentation/name_charset_font_test.dart` reads Inter's character map and checks it
  draws every allowed character.
- **Enforced by the database**: `profiles_display_name_allowed`, a check constraint added
  `NOT VALID` (names already stored stay; reports cover them). The app checks first for
  immediate feedback (save-progress form, Profile name dialog); a database refusal (23514)
  becomes `DisplayNameRefused` → "This name is not allowed."
- **Reports**: a flag button on every other player's named row of the board → confirmation →
  `report_player_name(player)` (`security definer`, signed-in players incl. guests, one report
  per reporter and player, never oneself; stores the name reported). A name reported **as it
  is now** by 3 different players reads "Player" on the boards (`public_display_name`) until
  reviewed; changing the name starts clean. Board entries now carry the player id (already
  public in `profiles`). `name_reports`: RLS on, no API access — the owner reviews in SQL
  until the Phase 3 dashboard.

## Stale guests (Phase 2 commit 11)

- **Server**: `cleanup_stale_guests()` deletes anonymous accounts older than 30 days with **no
  upload received and no sign-in session renewed** in 30 days (everything of theirs follows by
  cascade). The plan's wording is "no uploaded session for 30 days"; renewed sessions are added
  because until the server is deployed nobody uploads, and a guest playing daily would
  otherwise be deleted — the plan's own warning (6.3: only once the server knows their
  activity). The app renews its token whenever it is open. Daily at 03:17 UTC through
  `pg_cron` where available (Supabase); a failure to schedule warns, never blocks the
  migration.
- **Device**: a guest replaced by another account on this browser (signing in from Profile)
  can never come back; `AuthGate` records it (`AbandonedGuestStore`) and, at every sign-in,
  `deleteAbandonedGuests` removes the local games of guests left more than 30 days ago —
  the same delay as the server's.

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

Settled in Phase 2 commits 6–7: the tables (above) and the eligibility thresholds
(provisional).

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
