-- Phase 6a commit 6 (plan v3.9; review findings m7, n3): details.
--
-- - Daily limits taken under a per-caller lock: two requests at once can no
--   longer both pass the 20th (friend requests, feedback).
-- - Friend codes of 8 characters ("MATH-7K2P-QX4M": 32⁸ ≈ 10¹² codes, from
--   32⁴ ≈ 10⁶), every existing code replaced; a player can draw a new one
--   (`new_friend_code`), which ends their old invite links.
-- - `search_path` fixed on the seven functions that had none.

-- 8 code characters; the prefix and separators optional when typed.
create or replace function public.normalize_friend_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when c ~ '^[A-HJ-NP-Z2-9]{8}$'
    then 'MATH-' || substr(c, 1, 4) || '-' || substr(c, 5, 4) end
  from (
    -- The prefix only when the whole code is there: M, A, T and H are
    -- code characters themselves.
    select case when length(raw) = 12 and raw like 'MATH%' then substr(raw, 5)
      else raw end as c
    from (
      select regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g') as raw
    ) r
  ) x
$$;

-- A fresh code (not yet anyone's).
create or replace function public.draw_friend_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  drawn text;
begin
  for attempt in 1..50 loop
    bytes := uuid_send(gen_random_uuid());
    drawn := 'MATH-';
    for i in 0..7 loop
      if i = 4 then
        drawn := drawn || '-';
      end if;
      drawn := drawn || substr(alphabet, get_byte(bytes, i) % 32 + 1, 1);
    end loop;
    if not exists (select from public.friend_codes c where c.code = drawn) then
      return drawn;
    end if;
  end loop;
  raise exception 'no free friend code' using errcode = '53400';
end;
$$;

-- Every 4-character code replaced (their invite links stop working), and
-- the table's own check moved to the new format.
alter table public.friend_codes drop constraint if exists friend_codes_code_check;
update public.friend_codes c set code = public.draw_friend_code()
where c.code !~ '^MATH-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$';
alter table public.friend_codes add constraint friend_codes_code_check
  check (code ~ '^MATH-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$');

-- The caller's code, created on first use.
create or replace function public.my_friend_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
  existing text;
begin
  select c.code into existing from public.friend_codes c where c.player_id = me;
  if found then
    return existing;
  end if;
  for attempt in 1..5 loop
    begin
      insert into public.friend_codes as c (player_id, code) values (me, public.draw_friend_code())
      returning c.code into existing;
      return existing;
    exception when unique_violation then
      -- Taken meanwhile, or this player's own row created by a parallel
      -- call (return it).
      select c.code into existing from public.friend_codes c where c.player_id = me;
      if found then
        return existing;
      end if;
    end;
  end loop;
  raise exception 'no free friend code' using errcode = '53400';
end;
$$;

-- A new code for the caller: the old one (and its links) finds nobody now.
create or replace function public.new_friend_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
  drawn text;
begin
  perform pg_advisory_xact_lock(hashtext('friend_codes' || me::text));
  for attempt in 1..5 loop
    begin
      drawn := public.draw_friend_code();
      insert into public.friend_codes as c (player_id, code) values (me, drawn)
      on conflict (player_id) do update set code = excluded.code;
      return drawn;
    exception when unique_violation then
      null; -- drawn meanwhile by someone else: draw again
    end;
  end loop;
  raise exception 'no free friend code' using errcode = '53400';
end;
$$;

-- friend_request, the count and the insert under one lock per caller.
create or replace function public.friend_request(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
  target uuid;
begin
  perform pg_advisory_xact_lock(hashtext('friend_request' || me::text));
  if (select count(*) from public.friend_request_attempts a
      where a.player_id = me and a.at > now() - interval '24 hours')
     >= public.friend_daily_requests() then
    return 'tooMany';
  end if;
  insert into public.friend_request_attempts (player_id) values (me);
  select c.player_id into target
  from public.friend_codes c
  join auth.users u on u.id = c.player_id and not u.is_anonymous
  where c.code = public.normalize_friend_code(p_code)
    and public.player_visible(c.player_id);
  if target is null then
    return 'unknown';
  end if;
  if target = me then
    return 'self';
  end if;
  if exists (select from public.friendships f
             where f.player_a = least(me, target) and f.player_b = greatest(me, target)) then
    return 'already';
  end if;
  if exists (select from public.friend_requests r
             where r.from_player = target and r.to_player = me) then
    delete from public.friend_requests r where r.from_player = target and r.to_player = me;
    insert into public.friendships (player_a, player_b)
    values (least(me, target), greatest(me, target))
    on conflict do nothing;
    return 'friends';
  end if;
  insert into public.friend_requests (from_player, to_player) values (me, target)
  on conflict do nothing;
  if not found then
    return 'pending';
  end if;
  return 'sent';
end;
$$;

-- send_feedback likewise.
create or replace function public.send_feedback(p_message text, p_app_version text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  perform pg_advisory_xact_lock(hashtext('feedback' || caller::text));
  if (select count(*) from public.feedback
      where player_id = caller and created_at > now() - interval '24 hours') >= 20 then
    return 'tooMany';
  end if;
  insert into public.feedback (player_id, message, app_version)
  values (caller, btrim(p_message), p_app_version);
  return 'sent';
end;
$$;

-- A fixed search_path on the functions that had none (review n3).
alter function public.duel_abandon_after() set search_path = '';
alter function public.duel_board_min_duels() set search_path = '';
alter function public.duel_check_mode(text) set search_path = '';
alter function public.duel_max_serves() set search_path = '';
alter function public.duel_pool_latest() set search_path = '';
alter function public.friend_daily_requests() set search_path = '';

revoke all on function public.draw_friend_code() from public, anon, authenticated;
revoke all on function public.new_friend_code() from public, anon;
grant execute on function public.new_friend_code() to authenticated;
