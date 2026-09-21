# Meme du Jour

Défi d'humour quotidien entre amis. Chaque jour à 10h (heure de Paris), chaque
groupe reçoit un template de meme tiré au hasard ; chacun écrit le sien, et on
ne découvre ceux des autres qu'après avoir posté.

> Le nom est provisoire. Il est défini une seule fois dans `app.constants.js`
> (`APP_NAME`), que lisent à la fois la configuration Expo et l'application.

La spécification complète du MVP est dans [`docs/spec-mvp.md`](docs/spec-mvp.md) :
elle fait foi pour les règles métier (R1 à R12) et le découpage en phases.

## État

| Phase | Sujet | État |
|---|---|---|
| 1 | Socle Expo + Supabase | ✅ |
| 2 | Auth et profil | à faire |
| 3 | Groupes | à faire |
| 4 | Templates et tirage | schéma et tirage en place, catalogue à alimenter |
| 5 | Éditeur et `MemeRenderer` | à faire |
| 6 | Feed, likes, commentaires | RLS et tests en place, écrans à faire |
| 7 | Notifications | tables en place, Edge Functions à faire |
| 8 | Modération et conformité | tables en place, écrans à faire |
| 9 | Récap mensuel | RPC `monthly_top` en place, écran à faire |

## Stack

Expo SDK 57 · React Native 0.86 · TypeScript strict · Expo Router ·
Supabase (Postgres, Auth, Storage, Edge Functions) · TanStack Query ·
police Anton (OFL — Impact est propriétaire et n'est pas utilisée).

## Tester sur un Mac (Apple silicon)

Il faut Node 20+, puis une base : la stack Supabase locale (option A, tout en
local) ou un projet hébergé gratuit (option B, indispensable pour tester depuis
un vrai téléphone).

```bash
npm install
```

### Option A — stack Supabase locale (Docker)

Docker Desktop (Apple silicon) ou OrbStack doit tourner.

```bash
npx supabase start     # affiche l'API URL et la clé anon
npx supabase db reset  # applique les migrations puis supabase/seed.sql
```

Puis `cp .env.example .env` et y mettre l'URL locale et la clé `anon` affichée
par `supabase start` :

```
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_ANON_KEY=<clé anon affichée par supabase start>
```

### Option B — projet Supabase hébergé

1. Créer un projet sur supabase.com, récupérer sa référence.
2. Appliquer le schéma et les données de développement :

   ```bash
   npx supabase login
   npx supabase link --project-ref <ref>
   npx supabase db push
   ```

   puis coller `supabase/seed.sql` dans le SQL editor du dashboard.
3. Dashboard > Authentication > Sign In / Providers : activer les connexions
   anonymes (voir la note plus bas ; elles ne servent que le temps de la phase 1).
4. `.env` avec l'URL et la clé `anon` du dashboard (Project Settings > API).

### Lancer l'app

```bash
npx expo start --clear
```

- **Navigateur** — le plus rapide : touche `w`.
- **Simulateur iOS** — Xcode installé depuis l'App Store, puis touche `i`.
- **iPhone** — Expo Go depuis l'App Store, scanner le QR code. Avec l'option A,
  remplacer `127.0.0.1` par l'IP du Mac sur le réseau local
  (`ipconfig getifaddr en0`), sinon le téléphone n'atteint pas la base.
- **Android** — Android Studio pour l'émulateur, touche `a`.

Expo Go suffit pour la phase 1. Les phases suivantes (Sign in with Apple,
notifications push, export d'image) demanderont un *development build*
(`npx expo run:ios` ou EAS Build).

### Ce qu'on doit voir

Le titre en police Anton, une carte verte « Connexion à Supabase établie. »,
« 3 templates dans le catalogue » et les trois chemins d'images du seed. C'est
le critère « Terminé quand » de la phase 1 : l'app démarre et lit `templates`.

> **Session anonyme.** `templates` n'est lisible que par le rôle
> `authenticated` (section 6 de la spéc). Tant que l'écran de connexion n'existe
> pas, l'écran de fondation ouvre une session anonyme
> (`lib/queries/session.ts`) — supprimée en même temps que lui à la phase 2.

> Les variables `EXPO_PUBLIC_*` sont figées dans le bundle par Metro. Après les
> avoir modifiées, relancer avec `npx expo start --clear`, sinon l'ancienne
> valeur reste en cache.

## Base de données

Tout le schéma est versionné dans `supabase/migrations`. Les règles métier sont
appliquées **côté base** (contraintes, RLS, RPC), pas seulement côté client.

Régénérer les types après toute migration : `npm run db:types`.

Les images des templates ne sont pas versionnées : les déposer dans le bucket
public `templates` aux chemins référencés par `supabase/seed.sql`.

### Secrets du tirage quotidien

`daily_draw()` appelle l'Edge Function `notify-daily` et lit ses secrets dans
Supabase Vault — jamais en dur dans une migration. À créer une fois par projet :

```sql
select vault.create_secret('https://<ref>.supabase.co', 'supabase_url');
select vault.create_secret('<service_role_key>', 'service_role_key');
```

Sans ces secrets, le tirage a quand même lieu et une ligne
`vault_secret_missing` est écrite dans `admin_alerts`.

### Surveillance du catalogue

La vue `groups_template_stock` (réservée à l'administration) donne le nombre de
templates encore jamais tirés par groupe. Alerter en dessous de 15.

## Tests

`supabase/tests/10_rls_rules.sql` vérifie les règles R2 à R10 avec trois
utilisateurs : ce qu'un membre voit avant et après avoir posté, la fermeture
d'un challenge, les likes, le blocage, le plafond de 30 membres.

```bash
npm run typecheck

# contre la stack locale déjà démarrée (option A) :
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres ./scripts/test-db.sh

# ou sur un cluster jetable, sans Docker (demande PostgreSQL installé :
# brew install postgresql@16) :
./scripts/test-db.sh
```

Le script ne peut pas tourner en `root` (restriction d'`initdb`).

## Structure

```
app/                  écrans (Expo Router)
components/           composants partagés (MemeRenderer, …)
lib/
  constants.ts        APP_NAME et règles métier reprises côté client
  env.ts              configuration publique (URL + clé anon)
  supabase.ts         client Supabase (créé à la première utilisation)
  query-client.ts     TanStack Query et clés de cache
  strings.ts          tous les textes affichés, en français
  queries/            hooks de données (session, templates)
  types/              types de la base et des templates
docs/spec-mvp.md      spécification du MVP (source de vérité)
scripts/test-db.sh    lanceur des tests SQL
supabase/
  migrations/         schéma versionné
  tests/              tests des règles métier
  seed.sql            données de développement
```

## Conventions

- Toute modification du schéma passe par une **nouvelle** migration ; ne jamais
  retoucher une migration déjà appliquée.
- RLS activée sur toute nouvelle table, avec des politiques explicites.
- Aucun secret dans le client : seules l'URL Supabase et la clé `anon` y vivent.
- Interface en français, code et commentaires en anglais.
- Les textes affichés passent par `lib/strings.ts`.
