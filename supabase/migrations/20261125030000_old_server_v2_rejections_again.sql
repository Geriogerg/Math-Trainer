-- Levels phase commit 5: the cleanup of commit 4.1 once more, for rules-v2
-- games the old production server refused between that migration and the
-- app that holds them back (a page still open on commit 4). Same statement,
-- same reason: no server replayed rules v2 yet, so none of these refusals
-- is a verdict. Idempotent.
delete from public.upload_rejections
where coalesce((payload -> 'session' ->> 'rulesVersion')::integer, 1) >= 2;
