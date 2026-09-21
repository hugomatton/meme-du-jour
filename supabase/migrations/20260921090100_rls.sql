-- Row level security. Business rules R5 to R9 are enforced here, not in the app.
--
-- The helpers are `security definer` so that a policy on one table can look at
-- another one without triggering that table's own policies (which would either
-- recurse or hide rows the check legitimately needs to see).

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_group_member(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = gid and user_id = auth.uid());
$$;

create or replace function public.has_posted(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memes where group_challenge_id = cid and user_id = auth.uid());
$$;

-- The current challenge of a group is its most recent one: posting closes when
-- the next day's challenge arrives (R5).
create or replace function public.is_current_challenge(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from group_challenges gc
    where gc.id = cid
      and gc.date = (select max(date) from group_challenges where group_id = gc.group_id)
  );
$$;

create or replace function public.challenge_group(cid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select group_id from group_challenges where id = cid;
$$;

create or replace function public.is_blocked_by_me(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from blocks where blocker_id = auth.uid() and blocked_id = uid);
$$;

revoke execute on function
  public.is_group_member(uuid),
  public.has_posted(uuid),
  public.is_current_challenge(uuid),
  public.challenge_group(uuid),
  public.is_blocked_by_me(uuid),
  public.paris_today()
from public;

grant execute on function
  public.is_group_member(uuid),
  public.has_posted(uuid),
  public.is_current_challenge(uuid),
  public.challenge_group(uuid),
  public.is_blocked_by_me(uuid),
  public.paris_today()
to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.templates enable row level security;
alter table public.group_challenges enable row level security;
alter table public.memes enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.push_tokens enable row level security;
alter table public.notification_queue enable row level security;  -- no policy: service_role only
alter table public.admin_alerts enable row level security;        -- no policy: service_role only

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------

-- profiles: pseudos are visible to every signed-in user (feed authorship).
create policy "profiles read" on public.profiles for select to authenticated using (true);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid());

-- groups: readable by members. Creating a group or joining one goes through the
-- RPCs, never through a direct insert.
create policy "groups read" on public.groups for select to authenticated using (is_group_member(id));
create policy "groups update admin" on public.groups for update to authenticated
  using (exists (select 1 from group_members where group_id = id and user_id = auth.uid() and role = 'admin'));

-- group_members
create policy "members read" on public.group_members for select to authenticated using (is_group_member(group_id));
create policy "members update own prefs" on public.group_members for update to authenticated using (user_id = auth.uid());
create policy "members leave" on public.group_members for delete to authenticated using (user_id = auth.uid());

-- templates: the catalogue is public to signed-in users.
create policy "templates read" on public.templates for select to authenticated using (true);

-- group_challenges
create policy "challenges read" on public.group_challenges for select to authenticated using (is_group_member(group_id));

-- memes (R5, R6, R7, R9)
create policy "memes read" on public.memes for select to authenticated using (
  is_group_member(challenge_group(group_challenge_id))
  and not is_blocked_by_me(user_id)
  and (
    user_id = auth.uid()                          -- always see your own
    or has_posted(group_challenge_id)             -- R6: post first, then look
    or not is_current_challenge(group_challenge_id) -- R7: closed challenges are open to all members
  )
);
create policy "memes insert" on public.memes for insert to authenticated with check (
  user_id = auth.uid()
  and is_group_member(challenge_group(group_challenge_id))
  and is_current_challenge(group_challenge_id)    -- R5
);
create policy "memes delete own" on public.memes for delete to authenticated using (user_id = auth.uid());
-- No update policy: a published meme cannot be edited (R4).

-- likes (R8). The subqueries run as the caller, so the RLS of `memes` decides
-- which memes can be liked at all.
create policy "likes read" on public.likes for select to authenticated
  using (exists (select 1 from memes m where m.id = meme_id));
create policy "likes insert" on public.likes for insert to authenticated with check (
  user_id = auth.uid()
  and exists (select 1 from memes m where m.id = meme_id and m.user_id <> auth.uid())
);
create policy "likes delete own" on public.likes for delete to authenticated using (user_id = auth.uid());

-- comments
create policy "comments read" on public.comments for select to authenticated using (
  exists (select 1 from memes m where m.id = meme_id) and not is_blocked_by_me(user_id)
);
create policy "comments insert" on public.comments for insert to authenticated with check (
  user_id = auth.uid() and exists (select 1 from memes m where m.id = meme_id)
);
create policy "comments delete own" on public.comments for delete to authenticated using (user_id = auth.uid());

-- reports: insert only, reports are read from the dashboard.
create policy "reports insert" on public.reports for insert to authenticated with check (reporter_id = auth.uid());

-- blocks
create policy "blocks own" on public.blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- push_tokens
create policy "tokens own" on public.push_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
