-- Public storage bucket holding the meme template images. Reading is public so
-- the app can render a template from a plain URL; uploading stays restricted to
-- the service role (no insert/update policy is granted here), which means the
-- catalogue is fed from the Supabase dashboard or a seed script.
insert into storage.buckets (id, name, public)
values ('templates', 'templates', true)
on conflict (id) do nothing;
