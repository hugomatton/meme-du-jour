#!/usr/bin/env bash
#
# Runs the business-rule tests of supabase/tests against a PostgreSQL database.
#
# Two modes:
#
#   DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
#     ./scripts/test-db.sh
#       Runs the tests against an existing database that already has the
#       migrations applied — typically the local Supabase stack after
#       `supabase db reset`.
#
#   ./scripts/test-db.sh
#       Boots a throwaway PostgreSQL cluster, installs the Supabase stand-ins
#       from supabase/tests/00_supabase_shims.sql, applies every migration and
#       runs the tests. Needs a local PostgreSQL server install (pg_ctl, initdb)
#       but no Docker and no Supabase CLI.
#
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

run_tests() {
  for f in supabase/tests/1*.sql; do
    echo "--> $f"
    psql -v ON_ERROR_STOP=1 -q "$@" -f "$f"
  done
}

if [[ -n "${DATABASE_URL:-}" ]]; then
  run_tests "$DATABASE_URL"
  exit 0
fi

PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)}"
if [[ -n "$PGBIN" ]]; then export PATH="$PGBIN:$PATH"; fi
command -v initdb >/dev/null || { echo "initdb not found: install PostgreSQL or set DATABASE_URL" >&2; exit 1; }
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "initdb refuses to run as root: run this script as a normal user, or set DATABASE_URL." >&2
  exit 1
fi

workdir="$(mktemp -d)"
port="${PGPORT_TEST:-55432}"
cleanup() {
  pg_ctl -D "$workdir/data" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$workdir"
}
trap cleanup EXIT

initdb -D "$workdir/data" -U postgres --auth=trust >/dev/null
pg_ctl -D "$workdir/data" -l "$workdir/pg.log" -o "-p $port -k $workdir" start >/dev/null

export PGHOST="$workdir" PGPORT="$port" PGUSER=postgres PGDATABASE=postgres
psql -q -c 'create database app'
export PGDATABASE=app

echo "--> supabase/tests/00_supabase_shims.sql"
psql -v ON_ERROR_STOP=1 -q -f supabase/tests/00_supabase_shims.sql

# pg_cron and pg_net are Supabase-managed and not installable in a plain
# cluster; the shims provide the `cron` and `net` entry points the migrations
# need, and the scheduling block skips itself when pg_cron is absent.
mkdir -p "$workdir/migrations"
for f in supabase/migrations/*.sql; do
  sed -E 's/^create extension if not exists (pg_cron|pg_net);/-- [test harness] &/' "$f" \
    > "$workdir/migrations/$(basename "$f")"
done
for f in "$workdir"/migrations/*.sql; do
  echo "--> supabase/migrations/$(basename "$f")"
  psql -v ON_ERROR_STOP=1 -q -f "$f"
done

run_tests
