-- Phase 6a commit 4 (plan v3.9; review findings M6, m8): names and privacy.
--
-- - Names: Latin letters only from now on (owner, plan v3.9 answer 15; names
--   already saved are kept), unique ignoring case and look-alike letters
--   (`fold_display_name`, a unique index; duplicates already stored are
--   renamed first, the earliest keeps the name).
-- - Reports: from linked accounts only, 10 a day. One report hides the
--   player's name until the owner reviews it — the player's, not the
--   spelling's: a renamed player stays hidden until the review.
-- - `profiles` is readable by its owner only (boards, duels and friends read
--   names through `public_display_name`, a definer function).
-- - A deleted player's duels stay in their opponents' history, shown as
--   "Deleted player"; their runs, ratings and everything else go.
-- - Fix (commit 1): a challenge opened in time stays in "Waiting for you"
--   during its 24 hours to play, past its opening date.
--
-- Every function the server calls keeps its signature.

-- The name rule, Latin letters only (math_core's displayNameCharClass, the
-- same text: display_name_sql_parity_test.dart reads this file).
create or replace function public.display_name_problem(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  lowered text;
  joined text;
  w text;
begin
  if p_name is null then
    return null;
  end if;
  if p_name = '' then
    return 'empty';
  end if;
  if char_length(p_name) > 30 then
    return 'tooLong';
  end if;
  if btrim(p_name) <> p_name or position('  ' in p_name) > 0 then
    return 'spaces';
  end if;
  -- Latin letters the bundled Inter font draws, digits, space and . _ ' -
  if p_name !~ ('^' || '[A-Za-z0-9À-ÖØ-öø-ňŊ-ſẠ-ỹ ._''-]' || '+$') then
    return 'charset';
  end if;
  if p_name !~ '[^ ._''-]' then
    return 'noLetter';
  end if;
  lowered := lower(p_name);
  joined := regexp_replace(lowered, '[ ._''-]+', '', 'g');
  foreach w in array array[
    'nigger', 'nigga', 'faggot', 'retard', 'whore', 'salope', 'connard',
    'connasse', 'encule', 'enculé', 'batard', 'bâtard', 'hitler'
  ] loop
    if position(w in joined) > 0 then
      return 'blocked';
    end if;
  end loop;
  foreach w in array array['fuck', 'shit', 'cunt', 'bitch', 'slut', 'pute'] loop
    if exists (
      select from regexp_split_to_table(lowered, '[ ._''-]+') t
      where left(t, char_length(w)) = w
    ) then
      return 'blocked';
    end if;
  end loop;
  return null;
end;
$$;

-- What a name reads as: lowercase, accents and look-alike letters of any
-- script folded to the Latin letter they look like (i, l, 1 together; o
-- and 0; Cyrillic а and Latin a…), separators dropped, rn as m and vv as
-- w. Two names with the same fold cannot both be held. Changing this
-- function means rebuilding `profiles_display_name_folded`. Executable by
-- everyone: the unique index evaluates it for the player saving a name.
create or replace function public.fold_display_name(p_name text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select replace(replace(
    regexp_replace(
      translate(lower(p_name),
        'àáâãäåāăąǎạảấầẩẫậắằẳẵặæαάаβвьçćĉċčсďđðèéêëēĕėęěẹẻẽếềểễệεέеёэĝğġģĥħнһİìíîïĩīĭįıịỉιίϊΐіїӏĺļľŀł1ĵĳјķĸκкмμñńņňŉŋηήпòóôõöøōŏőœọỏốồổỗộớờởỡợοόσςθо0þρрŕŗřгśŝşšſßѕţťŧτтùúûüũūŭůűųụủứừửữựυύϋΰνŵωώшχхжýÿŷỳỵỷỹγуўźżžζзiÀÁÂÃÄÅĀĂĄǍẠẢẤẦẨẪẬẮẰẲẴẶÆΑΆАΒВЬÇĆĈĊČСĎĐÐÈÉÊËĒĔĖĘĚẸẺẼẾỀỂỄỆΕΈЕЁЭĜĞĠĢĤĦНҺÌÍÎÏĨĪĬĮIỊỈΙΊΪІЇӀĹĻĽĿŁĴĲЈĶΚКМΜÑŃŅŇŊΗΉПÒÓÔÕÖØŌŎŐŒỌỎỐỒỔỖỘỚỜỞỠỢΟΌΣΘОÞΡРŔŖŘГŚŜŞŠSЅŢŤŦΤТÙÚÛÜŨŪŬŮŰŲỤỦỨỪỬỮỰΥΎΫΝŴΩΏШΧХЖÝŸŶỲỴỶỸΓУЎŹŻŽΖЗABCDEFGHJKLMNOPQRTUVWXYZ',
        'aaaaaaaaaaaaaaaaaaaaaaaaaabbbccccccdddeeeeeeeeeeeeeeeeeeeeeegggghhhhllllllllllllllllllllllllljjjkkkkmmnnnnnnnnnoooooooooooooooooooooooooooooppprrrrssssssstttttuuuuuuuuuuuuuuuuuuuuuvwwwwxxxyyyyyyyyyyzzzzzlaaaaaaaaaaaaaaaaaaaaaaaaaabbbccccccdddeeeeeeeeeeeeeeeeeeeeeegggghhhhlllllllllllllllllllllljjjkkkmmnnnnnnnnoooooooooooooooooooooooooooppprrrrsssssstttttuuuuuuuuuuuuuuuuuuuuvwwwwxxxyyyyyyyyyyzzzzzabcdefghjklmnopqrtuvwxyz'),
      '[ ._''-]+', '', 'g'),
    'rn', 'm'), 'vv', 'w')
$$;

-- Duplicates already stored (before names were unique): the earliest
-- profile keeps the name, each later one gets the next free "Name 2",
-- "Name 3"… (cut to 30 characters), or no name if that is not allowed.
-- Returns how many were changed; the names are never printed (migration
-- logs outlive players).
create or replace function public.resolve_duplicate_display_names()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  row record;
  taken text[] := '{}';
  candidate text;
  n integer;
  changed integer := 0;
begin
  for row in
    select p.id, p.display_name, public.fold_display_name(p.display_name) as folded
    from public.profiles p
    where p.display_name is not null
    order by p.created_at, p.id
  loop
    if not row.folded = any(taken) then
      taken := taken || row.folded;
      continue;
    end if;
    n := 2;
    loop
      candidate := left(row.display_name, 30 - char_length(' ' || n)) || ' ' || n;
      candidate := regexp_replace(candidate, '\s+(\s\d+)$', '\1');
      exit when not public.fold_display_name(candidate) = any(taken)
        and not exists (
          select from public.profiles q
          where q.id <> row.id and q.display_name is not null
            and public.fold_display_name(q.display_name) = public.fold_display_name(candidate));
      n := n + 1;
    end loop;
    if public.display_name_problem(candidate) is not null then
      candidate := null;
    end if;
    update public.profiles set display_name = candidate where id = row.id;
    if candidate is not null then
      taken := taken || public.fold_display_name(candidate);
    end if;
    changed := changed + 1;
  end loop;
  return changed;
end;
$$;

do $$
declare
  changed integer;
begin
  if not exists (
    select from pg_indexes
    where schemaname = 'public' and indexname = 'profiles_display_name_folded'
  ) then
    changed := public.resolve_duplicate_display_names();
    raise notice 'names made unique: % changed', changed;
    create unique index profiles_display_name_folded
      on public.profiles (public.fold_display_name(display_name))
      where display_name is not null;
  end if;
end;
$$;

-- profiles: each player reads their own row only.
drop policy if exists "profiles readable by everyone" on public.profiles;
drop policy if exists "profile read by its owner" on public.profiles;
create policy "profile read by its owner"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);
revoke select on table public.profiles from anon;

-- Reports: when each was made (the latest one per reporter and player).
create index if not exists name_reports_reported
  on public.name_reports (reported_id, created_at desc);
create index if not exists name_reports_reporter
  on public.name_reports (reporter_id, created_at desc);

create or replace function public.name_reports_per_day() returns integer
language sql immutable set search_path = '' as $$ select 10 $$;

-- When the owner last reviewed a player's name.
create or replace function public.name_reviewed_at(p_player_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(v.reviewed_at) from public.name_reviews v where v.player_id = p_player_id
$$;

-- A linked player reports another player's name: it is hidden at once,
-- until the owner reviews it. Guests: refused (42501). Past 10 a day:
-- refused (54000). Reporting a name already waiting changes nothing;
-- reporting again after a review starts a new one.
create or replace function public.report_player_name(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if not exists (select from auth.users u where u.id = me and not u.is_anonymous) then
    raise exception 'only a saved account can report a name' using errcode = '42501';
  end if;
  if me = p_player_id then
    return;
  end if;
  perform pg_advisory_xact_lock(hashtext('name_reports' || me::text));
  if (
    select count(*) from public.name_reports r
    where r.reporter_id = me and r.created_at > now() - interval '24 hours'
  ) >= public.name_reports_per_day() then
    raise exception 'too many reports today' using errcode = '54000';
  end if;
  insert into public.name_reports (reporter_id, reported_id, reported_name)
  select me, p_player_id, pr.display_name
  from public.profiles pr
  where pr.id = p_player_id and pr.display_name is not null
  on conflict (reporter_id, reported_id) do update set
    reported_name = excluded.reported_name,
    created_at = now()
  where public.name_reports.created_at
    <= coalesce(public.name_reviewed_at(p_player_id), '-infinity');
end;
$$;

-- The name others see: hidden (null) while a report waits for review.
create or replace function public.public_display_name(p_player_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (
      select from public.name_reports r
      where r.reported_id = p_player_id
        and r.created_at > coalesce(public.name_reviewed_at(p_player_id), '-infinity')
    ) then null
    else pr.display_name
  end
  from public.profiles pr
  where pr.id = p_player_id
$$;

-- The owner's verdict on the player's current name: 'approve' shows it
-- again; 'clear' removes it (the player picks another, shown until it is
-- reported). Either one closes the reports made so far.
create or replace function owner_dashboard.review_name(p_player_id uuid, p_verdict text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  current_name text;
begin
  if p_verdict not in ('approve', 'clear') then
    raise exception 'verdict must be approve or clear, not %', p_verdict;
  end if;
  select display_name into current_name from public.profiles where id = p_player_id;
  if current_name is null then
    return 'no name';
  end if;
  insert into public.name_reviews (player_id, display_name)
  values (p_player_id, current_name)
  on conflict (player_id, display_name) do update set reviewed_at = now();
  if p_verdict = 'approve' then
    return 'approved: ' || current_name;
  end if;
  update public.profiles set display_name = null where id = p_player_id;
  return 'cleared: ' || current_name;
end;
$$;

-- Reported names waiting for the owner, oldest report first (the owner
-- answers within 48 hours, plan v3.9). The same columns as before.
create or replace view owner_dashboard.names_to_review as
select
  pr.id as player_id,
  pr.display_name,
  count(r.*) as reports,
  true as hidden,
  max(r.created_at) as last_report_at
from public.profiles pr
join public.name_reports r on r.reported_id = pr.id
where r.created_at > coalesce(public.name_reviewed_at(pr.id), '-infinity')
group by pr.id, pr.display_name
order by min(r.created_at);

-- A deleted player's duels stay, without them (plan v3.9 answer 13).
alter table public.duels drop constraint if exists duels_first_player_fkey;
alter table public.duels add constraint duels_first_player_fkey
  foreign key (first_player) references auth.users (id) on delete set null;
alter table public.duels drop constraint if exists duels_second_player_fkey;
alter table public.duels add constraint duels_second_player_fkey
  foreign key (second_player) references auth.users (id) on delete set null;
alter table public.duels alter column second_player drop not null;
alter table public.duels drop constraint if exists duels_check;
alter table public.duels drop constraint if exists duels_practice_has_no_first_player;
alter table public.duels add constraint duels_practice_has_no_first_player
  check (kind <> 'practice' or first_player is null);

-- The name of the other side of a duel, for a player's own lists.
create or replace function public.duel_opponent_name(p_kind text, p_opponent uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_kind = 'practice' then null
    when p_opponent is null then 'Deleted player'
    else public.public_display_name(p_opponent)
  end
$$;

-- duel_abandoned: also voids the open duels left with nobody to play them
-- (a deleted player's), and never lists one.
create or replace function public.duel_abandoned(p_limit integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.duels d set state = 'void', finished_at = now()
  where (d.kind = 'challenge' and d.state = 'awaitingFirst'
      and (d.created_at < now() - public.duel_abandon_after() or d.first_player is null))
    or (d.state = 'awaitingSecond' and d.second_player is null);
  return coalesce((
    select jsonb_agg(jsonb_build_object('duelId', x.id, 'player', x.second_player)
      order by x.started)
    from (
      select d.id, d.second_player,
        case when d.kind = 'challenge' then d.opened_at else d.created_at end as started
      from public.duels d
      where d.state = 'awaitingSecond'
        and d.second_player is not null
        and ((d.kind in ('pool', 'practice')
              and d.created_at < now() - public.duel_abandon_after())
          or (d.kind = 'challenge'
              and d.opened_at < now() - public.duel_abandon_after()))
      order by 3
      limit p_limit
    ) x
  ), '[]'::jsonb);
end;
$$;

-- duel_overview: "Deleted player" in Recent; a challenge opened in time
-- stays in Waiting for you during its 24 hours to play.
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
        'from', public.duel_opponent_name(d.kind, d.first_player),
        'expiresAt', d.expires_at
      ) order by d.expires_at)
      from public.duels d
      where d.kind = 'challenge' and d.second_player = me
        and d.state = 'awaitingSecond'
        and (d.expires_at > now()
          or d.opened_at > now() - public.duel_abandon_after())
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
            'opponent', public.duel_opponent_name(d.kind,
              case when d.first_player = me then d.second_player else d.first_player end),
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

revoke all on function public.resolve_duplicate_display_names() from public, anon, authenticated;
revoke all on function public.name_reviewed_at(uuid) from public, anon, authenticated;
revoke all on function public.duel_opponent_name(text, uuid) from public, anon, authenticated;
grant execute on function public.duel_opponent_name(text, uuid) to service_role;
