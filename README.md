# Meme du Jour

Défi d'humour quotidien entre amis. Chaque jour à 10h (heure de Paris), chaque
groupe reçoit un template de meme tiré au hasard ; chacun écrit le sien, et on
ne découvre ceux des autres qu'après avoir posté.

> Le nom est provisoire. Il est défini une seule fois dans `app.constants.js`
> (`APP_NAME`), que lisent à la fois la configuration Expo et l'application.

La spécification complète du MVP fait foi pour les règles métier (R1 à R12) et
le découpage en phases.

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

## Démarrer

```bash
npm install
cp .env.example .env     # puis renseigner l'URL et la clé anon du projet Supabase
npm start
```

L'écran d'accueil actuel est l'écran de vérification du socle : il affiche le
nombre de templates lus dans la base, ou le message de configuration si le
`.env` n'est pas rempli.

> Les variables `EXPO_PUBLIC_*` sont figées dans le bundle par Metro. Après les
> avoir modifiées, relancer avec `npx expo start --clear`, sinon l'ancienne
> valeur reste en cache.

## Base de données

Tout le schéma est versionné dans `supabase/migrations`. Les règles métier sont
appliquées **côté base** (contraintes, RLS, RPC), pas seulement côté client.

```bash
npx supabase start          # stack locale (Docker)
npx supabase db reset       # applique les migrations puis supabase/seed.sql
npm run db:types            # régénère lib/types/database.ts
```

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
./scripts/test-db.sh                        # cluster PostgreSQL jetable, sans Docker
DATABASE_URL=... ./scripts/test-db.sh       # contre une base qui a déjà les migrations
npm run typecheck
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
  queries/            hooks de données
  types/              types de la base et des templates
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
