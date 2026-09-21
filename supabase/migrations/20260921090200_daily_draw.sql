-- Daily draw. pg_cron runs in UTC, so the job is scheduled every hour and the
-- function returns immediately unless it is 10:00 in Paris. That keeps the
-- 10:00 local rendez-vous across daylight saving time changes.

-- Draw the challenge of the day for one group. Idempotent: calling it twice on
-- the same Paris day is a no-op (R2, R10).
create or replace function public.draw_challenge_for_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  tid uuid;
begin
  if exists (select 1 from group_challenges where group_id = gid and date = paris_today()) then
    return;
  end if;

  -- R3: never replay a template inside a group.
  select t.id into tid
  from templates t
  where t.active
    and not exists (select 1 from group_challenges gc where gc.group_id = gid and gc.template_id = t.id)
  order by random()
  limit 1;

  if tid is null then
    insert into admin_alerts (kind, payload)
    values ('templates_exhausted', jsonb_build_object('group_id', gid));
    return;
  end if;

  insert into group_challenges (group_id, template_id, date)
  values (gid, tid, paris_today())
  on conflict do nothing;
end $$;

-- Hourly job: only fires the draw at 10:00 Europe/Paris.
create or replace function public.daily_draw() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_key text;
begin
  if extract(hour from now() at time zone 'Europe/Paris') <> 10 then
    return;
  end if;

  perform draw_challenge_for_group(id) from groups;

  -- Secrets live in Supabase Vault, never in the migration.
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'supabase_url';
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'service_role_key';

  if v_url is null or v_key is null then
    insert into admin_alerts (kind, payload)
    values ('vault_secret_missing', jsonb_build_object('caller', 'daily_draw'));
    return;
  end if;

  -- Fan out the single daily push notification (R11).
  perform net.http_post(
    url := v_url || '/functions/v1/notify-daily',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_key,
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
end $$;

revoke execute on function public.draw_challenge_for_group(uuid), public.daily_draw() from public;

-- Schedule the hourly job when pg_cron is available (it is on Supabase and in
-- the local stack; guarded so the migration stays replayable elsewhere).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('daily-draw')
    where exists (select 1 from cron.job where jobname = 'daily-draw');

    perform cron.schedule('daily-draw', '0 * * * *', 'select public.daily_draw()');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Catalogue monitoring: how many unseen templates each group has left.
-- Admin-only, never exposed to the app.
-- ---------------------------------------------------------------------------

create view public.groups_template_stock as
select g.id as group_id, g.name,
       (select count(*) from templates t where t.active
          and not exists (select 1 from group_challenges gc where gc.group_id = g.id and gc.template_id = t.id)) as remaining
from groups g;

revoke all on public.groups_template_stock from authenticated, anon;
