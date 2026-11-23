-- Patterns and Method phase (doc/plan.md v3.3, commit 5): new games play
-- rules v4 (pattern questions, the spec's long addition and subtraction)
-- from this release, so Phase 3b's window restarts here — its sessions must
-- measure the questions players now get. Applied by CI right before the
-- server and the site that play v4. The owner can move it
-- (`update owner_dashboard.calibration_window set starts_at = …`).
-- Idempotent: running it again only restarts the window again (CI's tests
-- apply every migration twice on a scratch database).
update owner_dashboard.calibration_window set starts_at = now();
