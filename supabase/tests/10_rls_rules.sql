-- Row level security tests for the business rules of section 2.
--
-- Covers R2, R3, R4, R5, R6, R7, R8, R9, R10 plus the invite-code and
-- group-size guards of `join_group`.
--
-- Run with psql and ON_ERROR_STOP=1: a failed assertion aborts the script.
--   ./scripts/test-db.sh                       (throwaway local cluster)
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/10_rls_rules.sql "$DB_URL"
--
-- Each assertion runs in its own transaction with `set local role authenticated`
-- so the policies are evaluated exactly as they are for an app user.

\set alice '11111111-1111-1111-1111-111111111111'
\set bob   '22222222-2222-2222-2222-222222222222'
\set carol '33333333-3333-3333-3333-333333333333'

-- ===========================================================================
-- A. Fixtures
-- ===========================================================================

begin;

delete from public.admin_alerts;
delete from public.groups;
delete from public.templates;
delete from public.profiles;
delete from auth.users;

insert into auth.users (id, email) values
  (:'alice', 'alice@example.test'),
  (:'bob',   'bob@example.test'),
  (:'carol', 'carol@example.test');

insert into public.profiles (id, pseudo, accepted_terms_at) values
  (:'alice', 'Alice', now()),
  (:'bob',   'Bob',   now()),
  (:'carol', 'Carol', now());

insert into public.templates (image_path, width, height, source, license, text_zones)
select 'test/' || n || '.jpg', 1200, 1200, 'own', 'own',
       '[{"id":"top","x":5,"y":4,"w":90,"h":18,"font_size":8,"align":"center","color":"#FFF","stroke":"#000","uppercase":true,"placeholder":"Haut"}]'::jsonb
from generate_series(1, 3) as n;

commit;

-- ===========================================================================
-- B. create_group: R10 (a group created mid-day plays immediately) and
--    R2 (one challenge per group per day, the draw is idempotent)
-- ===========================================================================

begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ begin perform public.create_group('Les copains'); end $$;
commit;

-- A user who has not joined yet cannot read the group, he receives the code
-- through the invite link; the test pins it to a known value.
update public.groups set invite_code = 'COPAINS1' where name = 'Les copains';

begin;
do $$
declare n int;
begin
  select count(*) into n
  from public.group_challenges gc
  join public.groups g on g.id = gc.group_id
  where g.name = 'Les copains' and gc.date = public.paris_today();
  assert n = 1, 'R10: a new group must get today''s challenge immediately (got ' || n || ')';
end $$;

-- Drawing again on the same day must change nothing.
do $$ begin perform public.draw_challenge_for_group(id) from public.groups where name = 'Les copains'; end $$;

do $$
declare n int;
begin
  select count(*) into n
  from public.group_challenges gc
  join public.groups g on g.id = gc.group_id
  where g.name = 'Les copains';
  assert n = 1, 'R2: a second draw on the same day must not create a challenge (got ' || n || ')';
end $$;
commit;

-- ===========================================================================
-- C. R3: a template is never replayed inside a group, and the catalogue
--    running dry raises an admin alert instead of failing
-- ===========================================================================

begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ begin perform public.create_group('Groupe stock'); end $$;
commit;

begin;
do $$
declare
  gid uuid;
  drawn int;
  distinct_templates int;
  alerts int;
begin
  select id into gid from public.groups where name = 'Groupe stock';

  -- Three templates exist, so three successive days must yield three of them.
  for i in 1..2 loop
    update public.group_challenges set date = date - 1 where group_id = gid;
    perform public.draw_challenge_for_group(gid);
  end loop;

  select count(*), count(distinct template_id) into drawn, distinct_templates
  from public.group_challenges where group_id = gid;

  assert drawn = distinct_templates,
    'R3: a template was replayed inside a group (' || drawn || ' challenges, ' || distinct_templates || ' templates)';
  assert distinct_templates = 3,
    'R3: expected the three templates to be drawn, got ' || distinct_templates;

  -- Fourth day: nothing left to draw.
  update public.group_challenges set date = date - 1 where group_id = gid;
  perform public.draw_challenge_for_group(gid);

  select count(*) into drawn from public.group_challenges where group_id = gid;
  assert drawn = 3, 'R3: the draw must not invent a fourth template (got ' || drawn || ')';

  select count(*) into alerts
  from public.admin_alerts
  where kind = 'templates_exhausted' and (payload ->> 'group_id')::uuid = gid;
  assert alerts = 1, 'an exhausted catalogue must raise exactly one admin alert (got ' || alerts || ')';
end $$;
commit;

-- ===========================================================================
-- D. Bob joins, then R6 (post before you look), R4 (one meme per challenge)
--    and R8 (likes)
-- ===========================================================================

begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin perform public.join_group('COPAINS1'); end $$;
commit;

-- Alice posts.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into public.memes (group_challenge_id, user_id, texts)
select gc.id, '11111111-1111-1111-1111-111111111111', '{"top":"Le meme d''Alice"}'::jsonb
from public.group_challenges gc
join public.groups g on g.id = gc.group_id
where g.name = 'Les copains';
commit;

-- R4: Alice cannot post twice on the same challenge.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$
begin
  begin
    insert into public.memes (group_challenge_id, user_id, texts)
    select gc.id, '11111111-1111-1111-1111-111111111111', '{"top":"Encore"}'::jsonb
    from public.group_challenges gc
    join public.groups g on g.id = gc.group_id
    where g.name = 'Les copains';
    raise exception 'ASSERT FAILED R4: a second meme on the same challenge was accepted';
  exception when unique_violation then null;
  end;
end $$;
commit;

-- R6: Bob has not posted yet, so he sees nothing but his own (empty) side.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare n int;
begin
  select count(*) into n from public.memes;
  assert n = 0, 'R6: a member who has not posted must not see the others (got ' || n || ')';
end $$;
commit;

-- Bob posts, and now sees Alice's meme.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into public.memes (group_challenge_id, user_id, texts)
select gc.id, '22222222-2222-2222-2222-222222222222', '{"top":"Le meme de Bob"}'::jsonb
from public.group_challenges gc
join public.groups g on g.id = gc.group_id
where g.name = 'Les copains';

do $$
declare n int;
begin
  select count(*) into n from public.memes;
  assert n = 2, 'R6: once he has posted, a member sees the whole feed (got ' || n || ')';
end $$;
commit;

-- R8: one like per meme, never on your own.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into public.likes (meme_id, user_id)
select id, '22222222-2222-2222-2222-222222222222'
from public.memes where user_id = '11111111-1111-1111-1111-111111111111';

do $$
begin
  begin
    insert into public.likes (meme_id, user_id)
    select id, '22222222-2222-2222-2222-222222222222'
    from public.memes where user_id = '11111111-1111-1111-1111-111111111111';
    raise exception 'ASSERT FAILED R8: the same meme was liked twice';
  exception when unique_violation then null;
  end;

  begin
    insert into public.likes (meme_id, user_id)
    select id, '22222222-2222-2222-2222-222222222222'
    from public.memes where user_id = '22222222-2222-2222-2222-222222222222';
    raise exception 'ASSERT FAILED R8: a member liked his own meme';
  exception when insufficient_privilege then null;
  end;
end $$;

do $$
declare c int;
begin
  select like_count into c
  from public.memes_with_stats
  where user_id = '11111111-1111-1111-1111-111111111111';
  assert c = 1, 'memes_with_stats.like_count should be 1 (got ' || coalesce(c::text, 'null') || ')';
end $$;
commit;

-- ===========================================================================
-- E. R7 (a closed challenge is visible to every member) and R5 (you can only
--    post on the current challenge)
-- ===========================================================================

begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$ begin perform public.join_group('COPAINS1'); end $$;

-- Carol has not posted: R6 still hides the feed from her.
do $$
declare n int;
begin
  select count(*) into n from public.memes;
  assert n = 0, 'R6: a member who joined without posting must not see the feed (got ' || n || ')';
end $$;
commit;

-- Tomorrow's challenge arrives, which closes today's one.
begin;
insert into public.group_challenges (group_id, template_id, date)
select g.id,
       (select t.id from public.templates t
         where not exists (select 1 from public.group_challenges gc
                            where gc.group_id = g.id and gc.template_id = t.id)
         limit 1),
       public.paris_today() + 1
from public.groups g where g.name = 'Les copains';
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
declare n int;
begin
  select count(*) into n
  from public.memes m
  join public.group_challenges gc on gc.id = m.group_challenge_id
  where gc.date = public.paris_today();
  assert n = 2, 'R7: once closed, a challenge is visible to every member (got ' || n || ')';
end $$;

-- R5: the closed challenge no longer accepts memes.
do $$
begin
  begin
    insert into public.memes (group_challenge_id, user_id, texts)
    select gc.id, '33333333-3333-3333-3333-333333333333', '{"top":"En retard"}'::jsonb
    from public.group_challenges gc
    join public.groups g on g.id = gc.group_id
    where g.name = 'Les copains' and gc.date = public.paris_today();
    raise exception 'ASSERT FAILED R5: a meme was accepted on a closed challenge';
  exception when insufficient_privilege then null;
  end;
end $$;
commit;

-- ===========================================================================
-- F. R9: blocking hides the blocked user's memes and comments
-- ===========================================================================

-- Alice comments on Bob's meme.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into public.comments (meme_id, user_id, content)
select id, '11111111-1111-1111-1111-111111111111', 'Bien joué'
from public.memes where user_id = '22222222-2222-2222-2222-222222222222';
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare n int;
begin
  select count(*) into n from public.comments;
  assert n = 1, 'Bob should see Alice''s comment before blocking her (got ' || n || ')';
end $$;

insert into public.blocks (blocker_id, blocked_id)
values ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');

do $$
declare memes_seen int; comments_seen int;
begin
  select count(*) into memes_seen from public.memes
  where user_id = '11111111-1111-1111-1111-111111111111';
  assert memes_seen = 0, 'R9: a blocked user''s memes must be hidden (got ' || memes_seen || ')';

  select count(*) into comments_seen from public.comments;
  assert comments_seen = 0, 'R9: a blocked user''s comments must be hidden (got ' || comments_seen || ')';
end $$;
rollback;  -- keep the block out of the remaining fixtures

-- ===========================================================================
-- G. join_group guards
-- ===========================================================================

begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
begin
  begin
    perform public.join_group('NOPE0000');
    raise exception 'ASSERT FAILED: an unknown invite code was accepted';
  exception when raise_exception then
    if sqlerrm <> 'INVALID_CODE' then raise; end if;
  end;
end $$;
commit;

-- Fill the group up to 30 members, then a 31st join must be refused.
begin;
insert into auth.users (id) select gen_random_uuid() from generate_series(1, 27);
insert into public.profiles (id, pseudo, accepted_terms_at)
select u.id, 'Filler' || row_number() over (order by u.id), now()
from auth.users u
where u.id not in ('11111111-1111-1111-1111-111111111111',
                   '22222222-2222-2222-2222-222222222222',
                   '33333333-3333-3333-3333-333333333333');

insert into public.group_members (group_id, user_id)
select g.id, p.id
from public.groups g, public.profiles p
where g.name = 'Les copains'
  and p.id not in ('11111111-1111-1111-1111-111111111111',
                   '22222222-2222-2222-2222-222222222222',
                   '33333333-3333-3333-3333-333333333333')
on conflict do nothing;

do $$
declare n int;
begin
  select count(*) into n from public.group_members gm
  join public.groups g on g.id = gm.group_id where g.name = 'Les copains';
  assert n = 30, 'fixture: the group should hold 30 members (got ' || n || ')';
end $$;
commit;

begin;
insert into auth.users (id) values ('44444444-4444-4444-4444-444444444444');
insert into public.profiles (id, pseudo, accepted_terms_at)
values ('44444444-4444-4444-4444-444444444444', 'Dave', now());
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
do $$
begin
  begin
    perform public.join_group('COPAINS1');
    raise exception 'ASSERT FAILED: a 31st member was allowed into the group';
  exception when raise_exception then
    if sqlerrm <> 'GROUP_FULL' then raise; end if;
  end;
end $$;
commit;

\echo '--- All row level security rule tests passed ---'
