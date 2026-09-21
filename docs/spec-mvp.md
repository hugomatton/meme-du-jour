# Meme du Jour — Spécification MVP

> Document de référence pour Claude Code. Nom de l'app provisoire : **Meme du Jour** (à remplacer partout quand le nom définitif sera choisi — utiliser une constante `APP_NAME`).
>
> Langue de l'interface : **français**. Code, noms de variables et commentaires : anglais.

---

## 1. Concept

Application mobile (iOS + Android) de défi d'humour quotidien entre amis, inspirée d'**AskUs** (groupes d'amis, rendez-vous quotidien) et de **Make It Meme** (compléter un meme).

- Les utilisateurs forment des **groupes d'amis** (~10 personnes en général).
- Chaque jour à **10h (heure de Paris)**, chaque groupe reçoit un **template de meme tiré au hasard**, différent pour chaque groupe, et **jamais deux fois le même template dans un même groupe**.
- Chaque membre écrit **son meme** (les textes à placer sur le template).
- **Tant qu'on n'a pas posté son meme, on ne voit pas ceux des autres.** Une fois posté, on accède au feed du groupe.
- On peut **liker** les memes des autres (pas le sien, un like max par meme) et **commenter** chaque meme.
- Les memes sont affichés **triés par nombre de likes** (décroissant).
- Chaque nouveau meme posté déclenche une **notification** aux membres du groupe (regroupées si rapprochées).
- **Deadline** : le challenge du jour est clos à l'arrivée du suivant (10h le lendemain).
- **Récap mensuel** : top 5 des memes les plus likés du mois, par groupe, exportable en image pour partage.

Il n'y a **pas de phase de vote** séparée : les likes font office de vote.

---

## 2. Règles métier (source de vérité)

| # | Règle |
|---|---|
| R1 | Un utilisateur peut appartenir à plusieurs groupes. |
| R2 | Un groupe a exactement **un challenge par jour** (date Europe/Paris). |
| R3 | Un template n'est **jamais** rejoué dans un même groupe (contrainte base de données). |
| R4 | Un utilisateur poste **au maximum un meme par challenge**. Pas d'édition après publication ; suppression de son propre meme autorisée. |
| R5 | On ne peut poster que sur le **challenge courant** du groupe (= le plus récent). |
| R6 | Pendant que le challenge est courant, un membre ne voit les memes des autres **que s'il a posté le sien**. |
| R7 | Une fois le challenge clos, **tous les membres** voient tous les memes de ce challenge (choix par défaut, utile pour l'historique et le récap). |
| R8 | Un like max par utilisateur et par meme ; impossible de liker son propre meme. |
| R9 | Les memes et commentaires d'un utilisateur bloqué sont masqués pour celui qui l'a bloqué. |
| R10 | Un groupe créé en cours de journée reçoit immédiatement un challenge daté du jour. Le tirage de 10h suivant ne crée rien si un challenge existe déjà pour la date. |
| R11 | À 10h, un utilisateur reçoit **une seule** notification, même s'il est dans plusieurs groupes. |
| R12 | Notifications « nouveau meme » : réglables par groupe (`all` ou `daily_only`), regroupées par fenêtre de 5 minutes. |

---

## 3. Stack technique

- **App** : Expo (dernière version stable du SDK), React Native, **TypeScript strict**, **Expo Router** (navigation par fichiers).
- **Données côté client** : `@supabase/supabase-js` + **TanStack Query** (cache, invalidation, optimistic updates pour les likes).
- **Backend** : **Supabase** (Postgres, Auth, Storage, Edge Functions en Deno/TypeScript, `pg_cron`, `pg_net`).
- **Auth** : Sign in with Apple (`expo-apple-authentication`) + Google. Apple est **obligatoire** sur iOS dès qu'un login social tiers est proposé.
- **Notifications** : `expo-notifications` + API Expo Push (appelée depuis les Edge Functions).
- **Rendu et export d'image** : `react-native-view-shot` + `expo-sharing`.
- **Build et distribution** : EAS Build / EAS Submit ; bêta via TestFlight et le test fermé Google Play.
- **Police des memes** : **Anton** (Google Fonts, licence OFL), chargée via `expo-font`. Ne pas utiliser Impact (licence propriétaire).

---

## 4. Structure du dépôt

```
/app                     # écrans (Expo Router)
  (auth)/login.tsx
  (auth)/onboarding.tsx  # choix du pseudo
  (tabs)/index.tsx       # liste des groupes
  (tabs)/settings.tsx
  group/[id]/index.tsx   # écran du groupe (challenge du jour + feed)
  group/[id]/editor.tsx  # éditeur de meme
  group/[id]/recap.tsx   # récap mensuel
  group/[id]/settings.tsx
  meme/[id].tsx          # détail + commentaires
  join/[code].tsx        # deep link d'invitation
/components
  MemeRenderer.tsx       # affiche template + textes (utilisé partout)
  ...
/lib
  supabase.ts
  queries/               # hooks TanStack Query
  types/database.ts      # généré par `supabase gen types typescript`
/supabase
  migrations/            # SQL versionné
  functions/             # Edge Functions
  seed.sql
```

---

## 5. Modèle de données

Toutes les tables ont la **RLS activée**. Aucune clé `service_role` dans l'app mobile.

```sql
-- Extensions
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Helper : date du jour à Paris
create or replace function public.paris_today() returns date
language sql stable as $$ select (now() at time zone 'Europe/Paris')::date $$;

-- Profils
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  pseudo text not null unique check (char_length(pseudo) between 2 and 24),
  avatar_url text,
  accepted_terms_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Groupes
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

-- Templates
create table public.templates (
  id uuid primary key default gen_random_uuid(),
  image_path text not null,          -- chemin dans le bucket Storage `templates`
  width int not null,
  height int not null,
  text_zones jsonb not null,         -- voir section 7
  source text not null,              -- provenance de l'image
  license text not null,             -- ex. 'own', 'unsplash', 'public-domain', 'cc0'
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Challenges (un par groupe et par jour)
create table public.group_challenges (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  template_id uuid not null references public.templates(id),
  date date not null,
  published_at timestamptz not null default now(),
  unique (group_id, date),           -- R2
  unique (group_id, template_id)     -- R3
);

-- Memes
create table public.memes (
  id uuid primary key default gen_random_uuid(),
  group_challenge_id uuid not null references public.group_challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  texts jsonb not null,              -- { "<zone_id>": "texte", ... }
  created_at timestamptz not null default now(),
  unique (group_challenge_id, user_id)  -- R4
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

-- Modération
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

-- Notifications
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

-- Alertes admin (ex. catalogue épuisé)
create table public.admin_alerts (
  id bigint generated always as identity primary key,
  kind text not null,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

-- Index utiles
create index on public.memes (group_challenge_id);
create index on public.likes (meme_id);
create index on public.comments (meme_id, created_at);
create index on public.group_challenges (group_id, date desc);
create index on public.notification_queue (sent_at) where sent_at is null;
```

### Vue avec compteur de likes

```sql
create view public.memes_with_stats
with (security_invoker = true) as
select m.*,
       (select count(*) from public.likes l where l.meme_id = m.id)::int as like_count,
       (select count(*) from public.comments c where c.meme_id = m.id)::int as comment_count,
       exists (select 1 from public.likes l where l.meme_id = m.id and l.user_id = auth.uid()) as liked_by_me
from public.memes m;
```

`security_invoker = true` garantit que la RLS de `memes` s'applique à la vue.

---

## 6. Sécurité (RLS)

### Fonctions utilitaires (`security definer` pour éviter la récursion RLS)

```sql
create or replace function public.is_group_member(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = gid and user_id = auth.uid());
$$;

create or replace function public.has_posted(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memes where group_challenge_id = cid and user_id = auth.uid());
$$;

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
```

### Politiques

```sql
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
alter table public.notification_queue enable row level security;  -- aucune policy : service_role uniquement
alter table public.admin_alerts enable row level security;        -- aucune policy : service_role uniquement

-- profiles
create policy "profiles read" on public.profiles for select to authenticated using (true);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid());

-- groups : lecture si membre ; création / adhésion uniquement via RPC
create policy "groups read" on public.groups for select to authenticated using (is_group_member(id));
create policy "groups update admin" on public.groups for update to authenticated
  using (exists (select 1 from group_members where group_id = id and user_id = auth.uid() and role = 'admin'));

-- group_members
create policy "members read" on public.group_members for select to authenticated using (is_group_member(group_id));
create policy "members update own prefs" on public.group_members for update to authenticated using (user_id = auth.uid());
create policy "members leave" on public.group_members for delete to authenticated using (user_id = auth.uid());

-- templates
create policy "templates read" on public.templates for select to authenticated using (true);

-- group_challenges
create policy "challenges read" on public.group_challenges for select to authenticated using (is_group_member(group_id));

-- memes (R5, R6, R7, R9)
create policy "memes read" on public.memes for select to authenticated using (
  is_group_member(challenge_group(group_challenge_id))
  and not is_blocked_by_me(user_id)
  and (
    user_id = auth.uid()
    or has_posted(group_challenge_id)
    or not is_current_challenge(group_challenge_id)
  )
);
create policy "memes insert" on public.memes for insert to authenticated with check (
  user_id = auth.uid()
  and is_group_member(challenge_group(group_challenge_id))
  and is_current_challenge(group_challenge_id)
);
create policy "memes delete own" on public.memes for delete to authenticated using (user_id = auth.uid());

-- likes (R8) : le meme doit être visible (RLS de memes appliquée dans la sous-requête) et pas le sien
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

-- reports : insertion seule
create policy "reports insert" on public.reports for insert to authenticated with check (reporter_id = auth.uid());

-- blocks
create policy "blocks own" on public.blocks for all to authenticated
  using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- push_tokens
create policy "tokens own" on public.push_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
```

**Exigence** : écrire des tests SQL (ou un script de test avec deux utilisateurs) qui vérifient au minimum R5, R6, R7, R8 et R9.

---

## 7. Templates et éditeur

### Format de `text_zones`

Coordonnées **en pourcentage** de l'image (indépendantes de la résolution d'affichage) :

```json
[
  {
    "id": "top",
    "x": 5, "y": 3, "w": 90, "h": 20,
    "max_chars": 80,
    "font_size": 8,
    "align": "center",
    "color": "#FFFFFF",
    "stroke": "#000000",
    "uppercase": true,
    "placeholder": "Texte du haut"
  }
]
```

`font_size` est exprimé en % de la largeur de l'image. Le texte doit **réduire automatiquement sa taille** pour tenir dans sa zone.

### `MemeRenderer`

Composant unique utilisé dans l'éditeur, le feed, le détail et le récap : image du template + textes positionnés selon `text_zones`. Les memes sont stockés **sous forme de textes** (`memes.texts`), jamais comme image : le rendu est toujours fait côté client.

### Éditeur (MVP)

- Zones de texte **prédéfinies** par le template (pas de déplacement libre dans le MVP).
- Un champ de saisie par zone, aperçu en direct au-dessus.
- Bouton « Publier » → confirmation (« Pas de modification possible après publication ») → insert → redirection vers le feed.
- Au moins une zone doit être non vide.

### Catalogue

- Bucket Storage `templates` en lecture publique.
- Alimentation dans le MVP via le dashboard Supabase et `seed.sql` (pas de back-office dédié).
- **Images autorisées uniquement** : créations propres, Unsplash, Pexels, domaine public, CC0 (renseigner `source` et `license`). Pas de captures de films/séries ni d'images aspirées d'autres sites de memes.
- Prévoir au moins 60 templates au lancement.

---

## 8. Tirage quotidien

`pg_cron` fonctionne en UTC : on planifie **toutes les heures** et la fonction ne s'exécute réellement qu'à 10h heure de Paris (gère l'heure d'été automatiquement).

```sql
create or replace function public.draw_challenge_for_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  tid uuid;
begin
  if exists (select 1 from group_challenges where group_id = gid and date = paris_today()) then
    return;
  end if;

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

create or replace function public.daily_draw() returns void
language plpgsql security definer set search_path = public as $$
begin
  if extract(hour from now() at time zone 'Europe/Paris') <> 10 then
    return;
  end if;
  perform draw_challenge_for_group(id) from groups;
  -- Déclenche l'envoi des notifications du jour
  perform net.http_post(
    url := '<SUPABASE_URL>/functions/v1/notify-daily',
    headers := jsonb_build_object('Authorization', 'Bearer <SERVICE_ROLE_KEY>', 'Content-Type', 'application/json'),
    body := '{}'::jsonb
  );
end $$;

select cron.schedule('daily-draw', '0 * * * *', $$ select public.daily_draw() $$);
```

Les secrets (`SUPABASE_URL`, `SERVICE_ROLE_KEY`) doivent être lus depuis **Supabase Vault**, pas écrits en dur dans la migration.

### Surveillance du catalogue

```sql
create view public.groups_template_stock as
select g.id as group_id, g.name,
       (select count(*) from templates t where t.active
          and not exists (select 1 from group_challenges gc where gc.group_id = g.id and gc.template_id = t.id)) as remaining
from groups g;
```

À consulter régulièrement : alerte si `remaining < 15`. Cette vue n'est pas exposée à l'app (révoquer `select` pour `authenticated` et `anon`).

---

## 9. RPC (fonctions appelées par l'app)

```sql
-- Créer un groupe : ajoute le créateur comme admin et tire immédiatement un challenge (R10)
create or replace function public.create_group(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare gid uuid;
begin
  insert into groups (name, created_by) values (p_name, auth.uid()) returning id into gid;
  insert into group_members (group_id, user_id, role) values (gid, auth.uid(), 'admin');
  perform draw_challenge_for_group(gid);
  return gid;
end $$;

-- Rejoindre un groupe via code d'invitation
create or replace function public.join_group(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare gid uuid;
begin
  select id into gid from groups where invite_code = upper(p_code);
  if gid is null then raise exception 'INVALID_CODE'; end if;
  insert into group_members (group_id, user_id) values (gid, auth.uid()) on conflict do nothing;
  return gid;
end $$;

-- Récap mensuel : top 5 par likes pour un groupe et un mois (p_month = premier jour du mois)
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
```

Limiter la taille d'un groupe à **30 membres** dans `join_group` (lever `GROUP_FULL`).

---

## 10. Notifications

### Enregistrement

Au premier lancement après login : demander la permission, récupérer le token Expo, l'upserter dans `push_tokens`. Mettre à jour à chaque lancement.

### Notification du jour (R11)

Edge Function `notify-daily` (appelée par `daily_draw`) : pour chaque utilisateur ayant au moins un groupe, **une seule** notification :
- 1 groupe → « 🎭 Le meme du jour est tombé dans *Nom du groupe* »
- N groupes → « 🎭 Tes N memes du jour sont tombés »

Tap → écran du groupe (1 groupe) ou liste des groupes (N groupes). Envoyée à tous les membres, quel que soit `notif_mode`.

### Nouveaux memes (R12)

1. Trigger `after insert on memes` → insère une ligne dans `notification_queue` pour chaque membre du groupe tel que : ce n'est pas l'auteur, `notif_mode = 'all'`, et il n'a pas bloqué l'auteur.
2. `pg_cron` toutes les 5 minutes → Edge Function `send-notifications` qui regroupe les lignes non envoyées par `(user_id, group_id)` :
   - 1 meme → « *Pseudo* a posté son meme dans *Groupe* 👀 »
   - N memes → « N nouveaux memes dans *Groupe* 👀 »
3. Marquer `sent_at`. Tap → écran du groupe.

Supprimer automatiquement les tokens renvoyés comme invalides par l'API Expo Push (`DeviceNotRegistered`).

---

## 11. Écrans

| Écran | Contenu |
|---|---|
| **Login** | Sign in with Apple, Google. Lien CGU + politique de confidentialité. |
| **Onboarding** | Choix du pseudo (unique), acceptation des CGU (case obligatoire → `accepted_terms_at`). |
| **Mes groupes** | Liste des groupes avec statut du jour : « À toi de jouer » / « Posté ✓ » + nombre de memes postés. Boutons « Créer un groupe » et « Rejoindre avec un code ». |
| **Groupe** | Template du jour. **Pas encore posté** : aperçu du template, bouton « Faire mon meme », compteur « 4 memes t'attendent 👀 ». **Posté** : feed trié par likes (like en optimistic update, compteur de commentaires). Accès à l'historique des jours précédents et au récap. |
| **Éditeur** | Voir section 7. |
| **Détail d'un meme** | Meme en grand, auteur, likes, commentaires (ordre chronologique), champ de saisie. Menu « … » : signaler, bloquer l'auteur, supprimer (si c'est le sien). |
| **Récap mensuel** | Sélecteur de mois, top 5 avec auteur et likes, bouton « Partager » → export image (`view-shot`) + feuille de partage native. |
| **Réglages du groupe** | Nom, code et lien d'invitation (partage natif), mode de notification, liste des membres, quitter le groupe. |
| **Réglages** | Pseudo, utilisateurs bloqués (débloquer), CGU, confidentialité, déconnexion, **supprimer mon compte**. |

### Invitation

- Lien : `memedujour://join/<CODE>` (scheme Expo), avec universal links / app links à ajouter avant la sortie publique.
- Si l'utilisateur n'est pas connecté, conserver le code, le faire passer par login/onboarding, puis appeler `join_group`.

---

## 12. Modération et conformité (obligatoire avant publication)

Exigences Apple (guideline 1.2 — contenu généré par les utilisateurs) et Google Play :

- [ ] Acceptation des CGU à l'inscription, avec une clause de tolérance zéro pour les contenus abusifs.
- [ ] Signalement d'un meme, d'un commentaire ou d'un profil (`reports`).
- [ ] Blocage d'un utilisateur, qui masque immédiatement ses contenus (R9).
- [ ] Traitement des signalements sous 24h : dans le MVP, via le dashboard Supabase + une notification e-mail à l'admin (Edge Function déclenchée sur insert dans `reports`).
- [ ] **Suppression du compte depuis l'app** : Edge Function `delete-account` (service role) qui supprime l'utilisateur `auth` ; les données suivent par `on delete cascade`.
- [ ] Sign in with Apple sur iOS.
- [ ] Politique de confidentialité (RGPD) accessible dans l'app et sur les fiches des stores.
- [ ] Classification d'âge renseignée sur les deux stores.

---

## 13. Plan de réalisation

Chaque phase se termine par une app fonctionnelle et testée.

1. **Socle** — projet Expo + TypeScript + Expo Router, projet Supabase, migrations initiales (section 5), génération des types, client Supabase.
   *Terminé quand* : l'app démarre et lit la table `templates`.
2. **Auth et profil** — Apple + Google, onboarding pseudo + CGU, session persistante.
   *Terminé quand* : login, création du profil, logout et relance sans nouvelle connexion fonctionnent.
3. **Groupes** — RPC `create_group` / `join_group`, liste, réglages du groupe, deep link d'invitation.
   *Terminé quand* : deux comptes rejoignent le même groupe via le lien.
4. **Templates et tirage** — bucket, seed de 10 templates de test, `draw_challenge_for_group`, `daily_draw`, cron, surveillance du stock.
   *Terminé quand* : un nouveau groupe a son challenge immédiatement, et un appel manuel du tirage respecte R2 et R3.
5. **Éditeur et `MemeRenderer`** — rendu, auto-ajustement de la taille du texte, publication.
   *Terminé quand* : un meme publié s'affiche identiquement sur iOS et Android.
6. **Feed, likes, commentaires** — RLS section 6, vue `memes_with_stats`, tri par likes, détail, historique.
   *Terminé quand* : les tests RLS (R5 à R9) passent.
7. **Notifications** — tokens, `notify-daily`, file + `send-notifications`, deep links depuis les notifs.
   *Terminé quand* : notification unique à 10h, notifs regroupées pour les nouveaux memes, tap vers le bon écran.
   → **Bêta interne** (TestFlight + test interne Google Play) avec le premier groupe d'amis.
8. **Modération et conformité** — section 12 complète.
9. **Récap mensuel** — RPC `monthly_top`, écran, export image.
10. **Test fermé Google Play** — au moins 12 testeurs inscrits pendant 14 jours consécutifs (en recruter 15 à 20), puis demande d'accès à la production. Soumission App Store en parallèle.

---

## 14. Hors périmètre du MVP

- Classement global entre groupes, badges, Hall of Fame, compte officiel sur les réseaux.
- IA « humoristes » (personnages inventés et déclarés comme IA, qui ne peuvent pas gagner).
- Templates proposés par les utilisateurs ou photos perso de groupe.
- Monnaie virtuelle, séries (streaks), packs de templates, abonnement.
- Déplacement libre des zones de texte, stickers, GIF.
- Back-office d'administration dédié.

---

## 15. Conventions pour Claude Code

- Toute modification du schéma passe par une **nouvelle migration** dans `supabase/migrations` ; ne jamais modifier une migration déjà appliquée.
- Régénérer `lib/types/database.ts` après chaque migration.
- **RLS activée sur toute nouvelle table**, avec des politiques explicites.
- Aucun secret dans le code client : seules l'URL Supabase et la clé `anon` sont dans l'app (via `app.config.ts` / variables EAS).
- Les règles métier de la section 2 sont appliquées **côté base** (contraintes, RLS, RPC), pas seulement côté client.
- Les textes affichés à l'utilisateur sont en français et regroupés dans un fichier (`lib/strings.ts`) pour faciliter une future traduction.
- Avant de passer à la phase suivante, vérifier les critères « Terminé quand » de la phase en cours.
