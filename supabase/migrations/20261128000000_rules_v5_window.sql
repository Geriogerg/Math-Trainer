-- Rules v5 (doc/levels.md v1.4, 24 Nov 2026): pattern questions sized by
-- tier, no review questions. Rules v4 served oversized pattern questions at
-- low tiers (2^20 at level 15) and 30 % from the tier below, so Phase 3b's
-- window restarts here — its sessions must measure the questions players now
-- get (provisional, doc/decisions.md "Rules v5"). Applied by CI right before
-- the server and the site that play v5. The owner can move it
-- (`update owner_dashboard.calibration_window set starts_at = …`).
-- Idempotent: running it again only restarts the window again (CI's tests
-- apply every migration twice on a scratch database).
update owner_dashboard.calibration_window set starts_at = now();
