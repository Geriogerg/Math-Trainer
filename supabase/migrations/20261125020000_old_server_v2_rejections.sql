-- Levels phase commit 4.1: when the transition went live, the production
-- server was still the build before rules v2 (its deploys wait for the
-- owner's deploy hook) and refused every rules-v2 game: it reads no level
-- 0 and replays no tier. Its rejections are not verdicts — no server knew
-- rules v2 yet — and a resend would get the same answer (a known id keeps
-- its verdict). They go; the app sends those games again once a server
-- replays rules v2 (its /health lists them). Idempotent; a later migration
-- of this phase repeats it for refusals made meanwhile.
delete from public.upload_rejections
where coalesce((payload -> 'session' ->> 'rulesVersion')::integer, 1) >= 2;
