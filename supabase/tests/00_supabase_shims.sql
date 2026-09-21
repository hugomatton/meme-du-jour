-- Minimal stand-ins for the Supabase-managed pieces of a project, so that the
-- migrations and the row level security tests can run against a plain
-- PostgreSQL instance (CI, a local cluster) without the full Supabase stack.
--
-- This file is a TEST FIXTURE. It is never applied to a real project: on
-- Supabase, auth / storage / vault / pg_net already exist.

create role anon nologin noinherit;
create role authenticated nologin noinherit;
create role service_role nologin noinherit bypassrls;

grant usage on schema public to anon, authenticated, service_role;

-- Supabase sets these up on every project: tables created in `public` are
-- reachable by the API roles, and row level security decides what they see.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- auth ----------------------------------------------------------------------
create schema auth;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- storage -------------------------------------------------------------------
create schema storage;

create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);

-- vault ---------------------------------------------------------------------
create schema vault;

create table vault.decrypted_secrets (
  name text primary key,
  decrypted_secret text
);

-- pg_net --------------------------------------------------------------------
create schema net;

-- No-op stub: the tests never assert on outbound HTTP.
create or replace function net.http_post(url text, headers jsonb default '{}'::jsonb, body jsonb default '{}'::jsonb)
returns bigint language sql as $$ select 0::bigint $$;
