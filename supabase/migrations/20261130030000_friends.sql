-- Phase 7 commit 7 (plan v3.7): friends. Every linked player has a friend
-- code (MATH- and 4 characters from the beta codes' 32 easy ones) and an
-- invite link carrying it; a request by code becomes a friendship once
-- accepted (or at once when the other had already asked). At most 20
-- requests a day per player, failed lookups included: a code cannot be
-- guessed by trying. All through `security definer` functions on
-- auth.uid(); the tables stay closed. Everything cascades with the account.

create table if not exists public.friend_codes (
  player_id uuid primary key references auth.users (id) on delete cascade,
  code text not null unique check (code ~ '^MATH-[A-HJ-NP-Z2-9]{4}$'),
  created_at timestamptz not null default now()
);

create table if not exists public.friend_requests (
  from_player uuid not null references auth.users (id) on delete cascade,
  to_player uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_player, to_player),
  check (from_player <> to_player)
);

create index if not exists friend_requests_to on public.friend_requests (to_player);

-- One row per pair, the smaller id first.
create table if not exists public.friendships (
  player_a uuid not null references auth.users (id) on delete cascade,
  player_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (player_a, player_b),
  check (player_a < player_b)
);

create index if not exists friendships_b on public.friendships (player_b);

-- Every request attempt, found or not, for the daily limit.
create table if not exists public.friend_request_attempts (
  player_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);

create index if not exists friend_request_attempts_player
  on public.friend_request_attempts (player_id, at);

alter table public.friend_codes enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.friend_request_attempts enable row level security;
revoke all on table public.friend_codes, public.friend_requests, public.friendships,
  public.friend_request_attempts from anon, authenticated;
grant select, insert, update, delete on table public.friend_codes, public.friend_requests,
  public.friendships, public.friend_request_attempts to service_role;

create or replace function public.friend_daily_requests() returns integer
language sql immutable as $$ select 20 $$;

-- The caller must be a linked player (online play, plan v3.7).
create or replace function public.friend_caller()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null or not exists (
    select from auth.users u where u.id = me and not u.is_anonymous
  ) then
    raise exception 'a linked account is required' using errcode = '42501';
  end if;
  return me;
end;
$$;

-- "MATH-7K2P", "math 7k2p", "7K2P" → "MATH-7K2P" (or null if it cannot be
-- one). I, O, 0 and 1 are never in a code.
create or replace function public.normalize_friend_code(p_code text)
returns text
language sql
immutable
as $$
  select case when c ~ '^[A-HJ-NP-Z2-9]{4}$' then 'MATH-' || c end
  from (
    -- The prefix only when the whole code is there: M, A, T and H are
    -- code characters themselves ("MATH-MATH").
    select case when length(raw) = 8 and raw like 'MATH%' then substr(raw, 5)
      else raw end as c
    from (
      select regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g') as raw
    ) r
  ) x
$$;

-- The caller's code, created on first use; it never changes.
create or replace function public.my_friend_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  new_code text;
  existing text;
  attempt integer := 0;
begin
  select c.code into existing from public.friend_codes c where c.player_id = me;
  if found then
    return existing;
  end if;
  loop
    attempt := attempt + 1;
    if attempt > 50 then
      raise exception 'no free friend code' using errcode = '53400';
    end if;
    bytes := uuid_send(gen_random_uuid());
    new_code := 'MATH-';
    for i in 0..3 loop
      new_code := new_code || substr(alphabet, get_byte(bytes, i) % 32 + 1, 1);
    end loop;
    begin
      insert into public.friend_codes (player_id, code) values (me, new_code);
      return new_code;
    exception when unique_violation then
      -- Taken by someone (try another), or this player's own row created
      -- meanwhile by a parallel call (return it).
      select c.code into existing from public.friend_codes c where c.player_id = me;
      if found then
        return existing;
      end if;
    end;
  end loop;
end;
$$;

-- A friend request by code. Outcomes: 'sent'; 'friends' (they had asked
-- the caller: now friends); 'already' (friends already); 'pending' (asked
-- already); 'unknown' (no such code, or not a linked player); 'self';
-- 'tooMany' (20 attempts in the last 24 hours, failed ones included).
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
  if (select count(*) from public.friend_request_attempts a
      where a.player_id = me and a.at > now() - interval '24 hours')
     >= public.friend_daily_requests() then
    return 'tooMany';
  end if;
  insert into public.friend_request_attempts (player_id) values (me);

  select c.player_id into target
  from public.friend_codes c
  join auth.users u on u.id = c.player_id and not u.is_anonymous
  where c.code = public.normalize_friend_code(p_code);
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

-- Requests waiting for the caller's answer, oldest first.
create or replace function public.friend_requests_incoming()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'fromId', r.from_player,
    'name', public.public_display_name(r.from_player),
    'at', r.created_at
  ) order by r.created_at), '[]'::jsonb)
  from public.friend_requests r
  where r.to_player = public.friend_caller()
$$;

-- Accept or decline p_from's request: 'accepted', 'declined', 'none'.
create or replace function public.friend_respond(p_from uuid, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
begin
  delete from public.friend_requests r where r.from_player = p_from and r.to_player = me;
  if not found then
    return 'none';
  end if;
  if not p_accept then
    return 'declined';
  end if;
  insert into public.friendships (player_a, player_b)
  values (least(me, p_from), greatest(me, p_from))
  on conflict do nothing;
  return 'accepted';
end;
$$;

-- Removes the friendship (and any request between the two). The duels
-- played stay: they belong to both players' history.
create or replace function public.friend_remove(p_friend uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
begin
  delete from public.friendships f
  where f.player_a = least(me, p_friend) and f.player_b = greatest(me, p_friend);
  delete from public.friend_requests r
  where (r.from_player = me and r.to_player = p_friend)
     or (r.from_player = p_friend and r.to_player = me);
end;
$$;

-- The duels decided between two players (pool or challenge; practice has
-- no second player), with p_me's result.
create or replace function public.duels_between(p_me uuid, p_other uuid)
returns table (duel_id uuid, mode text, at timestamptz, result double precision,
  my_score jsonb, their_score jsonb, rated boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select d.id, d.mode, d.finished_at,
    case when d.first_player = p_me then 1 - d.result else d.result end,
    (select r.score from public.duel_runs r where r.duel_id = d.id and r.player_id = p_me),
    -- The other's score: their run in this duel, or the run raced (pool).
    coalesce(
      (select r.score from public.duel_runs r where r.duel_id = d.id and r.player_id = p_other),
      (select r.score from public.duel_runs r where r.id = d.first_run)
    ),
    d.rated
  from public.duels d
  where d.state = 'done' and d.kind in ('pool', 'challenge')
    and ((d.first_player = p_me and d.second_player = p_other)
      or (d.first_player = p_other and d.second_player = p_me))
$$;

-- The caller's friends, with the head-to-head: wins each over every duel
-- between them, draws apart.
create or replace function public.friend_list()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with me as (select public.friend_caller() as id),
  friends as (
    select case when f.player_a = me.id then f.player_b else f.player_a end as id
    from public.friendships f, me
    where f.player_a = me.id or f.player_b = me.id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', fr.id,
    'name', public.public_display_name(fr.id),
    'wins', (select count(*) from public.duels_between(me.id, fr.id) b where b.result = 1),
    'losses', (select count(*) from public.duels_between(me.id, fr.id) b where b.result = 0),
    'draws', (select count(*) from public.duels_between(me.id, fr.id) b where b.result = 0.5)
  ) order by lower(coalesce(public.public_display_name(fr.id), 'zzz')), fr.id), '[]'::jsonb)
  from friends fr, me
$$;

-- The duels between the caller and p_friend, newest first.
create or replace function public.friend_history(p_friend uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'duelId', b.duel_id,
    'mode', b.mode,
    'at', b.at,
    'result', b.result,
    'you', b.my_score,
    'them', b.their_score,
    'rated', b.rated
  ) order by b.at desc), '[]'::jsonb)
  from public.duels_between(public.friend_caller(), p_friend) b
$$;

-- The Online tab's overview now also counts the friend requests waiting
-- (the Friends button's dot and the tab's badge).
create or replace function public.duel_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null or not exists (
    select from auth.users u where u.id = me and not u.is_anonymous
  ) then
    return jsonb_build_object('linked', false);
  end if;
  return jsonb_build_object(
    'linked', true,
    'ratings', coalesce((
      select jsonb_object_agg(o.mode, jsonb_build_object(
        'rating', o.rating,
        'ratedDuels', o.rated_duels
      ))
      from public.duel_ratings o where o.player_id = me
    ), '{}'::jsonb),
    'waiting', coalesce((
      select jsonb_agg(jsonb_build_object(
        'duelId', d.id,
        'mode', d.mode,
        'fromId', d.first_player,
        'from', public.public_display_name(d.first_player),
        'expiresAt', d.expires_at
      ) order by d.expires_at)
      from public.duels d
      where d.kind = 'challenge' and d.second_player = me
        and d.state = 'awaitingSecond' and d.expires_at > now()
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(r.entry order by r.at desc)
      from (
        select coalesce(d.finished_at, d.created_at) as at,
          jsonb_build_object(
            'duelId', d.id,
            'mode', d.mode,
            'kind', d.kind,
            'at', coalesce(d.finished_at, d.created_at),
            'state', d.state,
            'raced', d.first_player = me,
            'opponentId', case when d.first_player = me then d.second_player
              else d.first_player end,
            'opponent', public.public_display_name(
              case when d.first_player = me then d.second_player else d.first_player end
            ),
            'result', case when d.first_player = me then 1 - d.result else d.result end,
            'rated', d.rated
          ) as entry
        from public.duels d
        where (d.second_player = me and d.state in ('done', 'void'))
           or (d.first_player = me and d.state = 'done')
           or (d.first_player = me and d.kind = 'challenge' and d.state = 'awaitingSecond')
        order by coalesce(d.finished_at, d.created_at) desc
        limit 20
      ) r
    ), '[]'::jsonb),
    'friendRequests', (
      select count(*) from public.friend_requests r where r.to_player = me
    )
  );
end;
$$;

revoke all on function public.friend_caller() from public, anon, authenticated;
revoke all on function public.duels_between(uuid, uuid) from public, anon, authenticated;
revoke all on function public.my_friend_code() from public, anon;
revoke all on function public.friend_request(text) from public, anon;
revoke all on function public.friend_requests_incoming() from public, anon;
revoke all on function public.friend_respond(uuid, boolean) from public, anon;
revoke all on function public.friend_remove(uuid) from public, anon;
revoke all on function public.friend_list() from public, anon;
revoke all on function public.friend_history(uuid) from public, anon;
grant execute on function public.my_friend_code() to authenticated;
grant execute on function public.friend_request(text) to authenticated;
grant execute on function public.friend_requests_incoming() to authenticated;
grant execute on function public.friend_respond(uuid, boolean) to authenticated;
grant execute on function public.friend_remove(uuid) to authenticated;
grant execute on function public.friend_list() to authenticated;
grant execute on function public.friend_history(uuid) to authenticated;
