-- Initial schema: profiles, groups, templates, challenges, memes, social and
-- moderation tables. Every table gets row level security in the next migration.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Today's date in Paris: the whole product runs on the Paris calendar day.
create or replace function public.paris_today() returns date
language sql stable set search_path = public as $$
  select (now() at time zone 'Europe/Paris')::date
$$;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  pseudo text not null unique check (char_length(pseudo) between 2 and 24),
  avatar_url text,
  accepted_terms_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Groups
-- ---------------------------------------------------------------------------

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  invite_code text not null unique default upper(substr(md5(random()::text), 1, 8)),
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  notif_mode text not null default 'all' check (notif_mode in ('all', 'daily_only')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Templates
-- ---------------------------------------------------------------------------

create table public.templates (
  id uuid primary key default gen_random_uuid(),
  image_path text not null,          -- path inside the `templates` storage bucket
  width int not null check (width > 0),
  height int not null check (height > 0),
  text_zones jsonb not null,         -- array of zones, coordinates in % of the image
  source text not null,              -- where the image comes from
  license text not null,             -- 'own' | 'unsplash' | 'pexels' | 'public-domain' | 'cc0'
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint templates_text_zones_is_array check (jsonb_typeof(text_zones) = 'array')
);

-- ---------------------------------------------------------------------------
-- Challenges: exactly one per group per Paris day (R2), never the same
-- template twice inside a group (R3).
-- ---------------------------------------------------------------------------

create table public.group_challenges (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  template_id uuid not null references public.templates(id),
  date date not null,
  published_at timestamptz not null default now(),
  unique (group_id, date),           -- R2
  unique (group_id, template_id)     -- R3
);

-- ---------------------------------------------------------------------------
-- Memes and interactions
-- ---------------------------------------------------------------------------

create table public.memes (
  id uuid primary key default gen_random_uuid(),
  group_challenge_id uuid not null references public.group_challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  texts jsonb not null,              -- { "<zone_id>": "text", ... }
  created_at timestamptz not null default now(),
  unique (group_challenge_id, user_id),  -- R4
  constraint memes_texts_not_empty check (jsonb_typeof(texts) = 'object' and texts <> '{}'::jsonb)
);

create table public.likes (
  meme_id uuid not null references public.memes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (meme_id, user_id)     -- R8
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  meme_id uuid not null references public.memes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 500),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Moderation
-- ---------------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('meme', 'comment', 'profile')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'actioned', 'dismissed')),
  created_at timestamptz not null default now()
);

create table public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

create table public.push_tokens (
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

create table public.notification_queue (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  meme_id uuid not null references public.memes(id) on delete cascade,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

-- Admin-side alerts (e.g. a group has run out of unseen templates).
create table public.admin_alerts (
  id bigint generated always as identity primary key,
  kind text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index on public.memes (group_challenge_id);
create index on public.likes (meme_id);
create index on public.comments (meme_id, created_at);
create index on public.group_challenges (group_id, date desc);
create index on public.notification_queue (sent_at) where sent_at is null;
-- "my groups" lookups and the RLS membership check.
create index on public.group_members (user_id);
create index on public.blocks (blocker_id);

-- ---------------------------------------------------------------------------
-- Meme feed view: like / comment counters plus whether the caller liked it.
-- security_invoker keeps the row level security of `memes` in force.
-- ---------------------------------------------------------------------------

create view public.memes_with_stats
with (security_invoker = true) as
select m.*,
       (select count(*) from public.likes l where l.meme_id = m.id)::int as like_count,
       (select count(*) from public.comments c where c.meme_id = m.id)::int as comment_count,
       exists (select 1 from public.likes l where l.meme_id = m.id and l.user_id = auth.uid()) as liked_by_me
from public.memes m;

grant select on public.memes_with_stats to authenticated;
