-- RPCs called by the app. Group creation and joining are `security definer`
-- because `groups` and `group_members` have no insert policy: membership can
-- only be granted through these two entry points.

-- Create a group, make the caller its admin, and draw today's challenge right
-- away so a group created mid-day is immediately playable (R10).
create or replace function public.create_group(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into groups (name, created_by) values (p_name, auth.uid()) returning id into gid;
  insert into group_members (group_id, user_id, role) values (gid, auth.uid(), 'admin');
  perform draw_challenge_for_group(gid);

  return gid;
end $$;

-- Join a group from its invite code. Capped at 30 members.
create or replace function public.join_group(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
  member_count int;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Lock the group row so two concurrent joins cannot both slip past the cap.
  select id into gid from groups where invite_code = upper(btrim(p_code)) for update;

  if gid is null then
    raise exception 'INVALID_CODE';
  end if;

  if exists (select 1 from group_members where group_id = gid and user_id = auth.uid()) then
    return gid;  -- already a member, nothing to do
  end if;

  select count(*) into member_count from group_members where group_id = gid;
  if member_count >= 30 then
    raise exception 'GROUP_FULL';
  end if;

  insert into group_members (group_id, user_id) values (gid, auth.uid()) on conflict do nothing;

  return gid;
end $$;

-- Monthly recap: the five most liked memes of a group for the month starting at
-- p_month. `security invoker` keeps the row level security of `memes` in force.
create or replace function public.monthly_top(p_group uuid, p_month date)
returns table (meme_id uuid, user_id uuid, like_count int, template_id uuid, texts jsonb)
language sql stable security invoker set search_path = public as $$
  select m.id, m.user_id, ms.like_count, gc.template_id, m.texts
  from memes m
  join memes_with_stats ms on ms.id = m.id
  join group_challenges gc on gc.id = m.group_challenge_id
  where gc.group_id = p_group
    and gc.date >= p_month
    and gc.date < (p_month + interval '1 month')
  order by ms.like_count desc, m.created_at asc
  limit 5;
$$;

revoke execute on function
  public.create_group(text),
  public.join_group(text),
  public.monthly_top(uuid, date)
from public;

grant execute on function
  public.create_group(text),
  public.join_group(text),
  public.monthly_top(uuid, date)
to authenticated;
