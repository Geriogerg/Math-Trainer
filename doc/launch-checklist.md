# Launch checklist — Phase 6c switch-on

The build part of Phase 6c is done: everything the launch needs is in the code, **behind a
switch or a visible placeholder**. This is the way to switch it on (plan v4.1, Phase 6c
commits 7–9), in order. Part A is the owner's (accounts, money, legal); part B is Claude
Code's, started on the owner's word once A is done; part C is played on a phone.

## A. The owner's prerequisites

Each item names where the value goes. Nothing here goes in the repository except what A.3
sends to Claude Code.

1. **The name.** Confirm "Math Trainer" or choose another (plan 6.2: short, easy in French
   and English, free as a domain and on both stores; check INPI and EUIPO). Send it — and a
   short form of 12 characters or fewer if it is longer — to Claude Code.
2. **The domain.** Buy it. In Cloudflare: Pages → the production project → Custom domains →
   add it (Cloudflare writes the DNS records when the domain is on Cloudflare).
3. **The legal pages' details** (they show as highlighted placeholders today, Profile →
   Privacy policy / Legal notice), per language if they differ:
   - **publisher** — your name, or, as a private publisher, the sentence "a private
     individual whose identity is kept by the host, Cloudflare, Inc." (LCEN art. 6 III-2);
   - **contact email** — ideally on the domain (e.g. `contact@<domain>`);
   - **director of publication** — usually the same as the publisher;
   - **Cloudflare's address and telephone number** (Cloudflare, Inc., 101 Townsend St, San
     Francisco, CA 94107, USA — to verify on cloudflare.com);
   - **the Supabase project's region** (Supabase → Project Settings → General);
   - **the date** this version takes effect.

   Then the professional review of both pages (`doc/legal/README.md` lists its questions).
4. **An email service on the domain** (Brevo, Resend, Postmark… — a few hundred emails a
   day is plenty at first): verify the domain (SPF, DKIM, DMARC records), get its SMTP
   settings. In Supabase (production) → Authentication → Emails:
   - SMTP Settings: host, port, user, password; sender `no-reply@<domain>`, name = the name;
   - Templates: paste `supabase/templates/confirmation.html` ("Confirm sign up"),
     `email_change.html` ("Change email address") and `recovery.html` ("Reset password");
     each file's first lines give its subject;
   - Rate Limits: raise "emails per hour" to what the service allows.
   Do **not** turn on "Confirm email" yet (B, commit 7 does it with you).
5. **A Turnstile key.** Cloudflare → Turnstile → Add widget: the domain (and
   `math-trainer-kjc.pages.dev` while it still serves), mode Managed. Keep the site key and
   the secret key for B (commit 7). Staging, any time: Supabase (staging) → Authentication →
   Attack Protection → Enable CAPTCHA protection → Cloudflare Turnstile → secret key
   `1x0000000000000000000000000000000AA` (Cloudflare's test secret, which matches the test
   site key staging already builds with).
6. **Render always-on.** Render → the production service → change the plan from Free to an
   always-on one (Starter is enough for 1,000 players, `doc/capacity.md`).
7. **A confirmed staging account for the smoke test's duel** (any time): Supabase (staging)
   → Authentication → Users → Add user → an email and a password, "Auto Confirm User" on.
   Then GitHub → Settings → Secrets → Actions: `STAGING_SMOKE_DUEL_EMAIL`,
   `STAGING_SMOKE_DUEL_PASSWORD`. From the next push the staging smoke test plays a rated
   duel with it (until then it prints a warning and skips the duel).

## B. The switch-on commits (Claude Code, on the owner's word)

7. **Production on the domain.** GitHub variables: `SITE_URL=https://<domain>`,
   `TURNSTILE_SITE_KEY=<site key>`; Render (production) `ALLOWED_ORIGINS` gains the domain;
   Supabase (production) → Authentication → URL Configuration: Site URL `https://<domain>`,
   Redirect URLs `https://<domain>/**`; Attack Protection: CAPTCHA on, Turnstile, the secret
   key; Providers → Email: "Confirm email" on. The code: `Brand` set to the name (then the
   brand tool), `LegalDetails.given` filled, the old address redirecting to the domain.
8. **Rules v2–v6 retired** (from 27 December, 30 days after v9): `RulesVersion.replayed`
   loses them, the server refuses them as `rulesRetired`, the app stops sending them.
9. **Gate removed**: the variable `BETA_GATE` deleted, the production server's `BETA_GATE`
   set to `false`; the production smoke test then reaches Home with a made-up guest (it
   already does when there is no gate) and opens the legal pages from Profile.

## C. On a phone, from a fresh browser (the exit of Phase 6c)

- [ ] The domain opens; the game starts and Home shows within about 20 s on 4G.
- [ ] A game plays; the result says why each level moved ("8 right, 6 fast, of 10: up").
- [ ] Profile → Save your progress: "I am 15 or older" is required; the confirmation email
      comes from the domain; its link says "Email confirmed".
- [ ] Sign out; Sign in → Forgot password? → the email → its link → Set a new password →
      signed in.
- [ ] Online → Basics: the rules once, then the reminder line; a rated duel to its result.
- [ ] Profile → Privacy policy and Legal notice, in English and in French, with no
      highlighted placeholder and no Draft banner.
- [ ] `bash tool/dashboard/dashboard.sh errors` shows nothing alarming after the test.
