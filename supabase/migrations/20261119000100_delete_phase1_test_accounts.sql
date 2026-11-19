-- Phase 2 commit 0 (plan v2.2): the throwaway accounts Phase 1's checks
-- created in the live project (doc/progress.md, Phase 1) — seven guests
-- and one guest linked to an example.com address. Listed one by one: this
-- deletes these ids and nothing else. Their profiles go by cascade.
-- Re-applying it is a no-op.
delete from auth.users
where id in (
  '8bec648d-3323-48be-8952-4f740e3b07b0',
  'e188e86d-37b2-4ac3-87bd-bf82c0c46268',
  '7969cb24-8b10-4b54-9831-c509e8ffb428',
  '7ea74633-2b87-4b6b-9011-566a9bd8baac',
  '58c28fa0-6748-43e0-8e3a-219cb515fd30',
  'c655e665-b926-4c7e-b8c6-0103236b7d20',
  '4d09177b-6504-4588-af7d-4525b7f215bd',
  'fb154e14-3c47-4933-b1ad-6815646128b9'
);
