# Expo HAS CHANGED

Read the exact versioned docs at https://docs.expo.dev/versions/v57.0.0/ before writing any code.

La spécification du MVP est dans `docs/spec-mvp.md` : elle fait foi pour les
règles métier (R1 à R12), le modèle de données, les écrans et le découpage en
phases. `README.md` dit où en est chaque phase.

# Project conventions

- Schema changes go in a **new** migration under `supabase/migrations`; never
  edit one that has already been applied. Regenerate `lib/types/database.ts`
  afterwards (`npm run db:types`).
- Row level security is enabled on every new table, with explicit policies.
- Business rules live in the database (constraints, RLS, RPC), not only in the
  client. Add a case to `supabase/tests/10_rls_rules.sql` when you add one.
- No secret in the client bundle: only the Supabase URL and the anon key, read
  through `lib/env.ts`.
- The interface is in French, the code and comments are in English. Every
  user-facing string goes through `lib/strings.ts`.
- The product name comes from `APP_NAME` in `app.constants.js` — the single
  place to change it.
- Before moving to the next phase of the spec, check the "Terminé quand"
  criteria of the current one.
