import { APP_NAME } from './constants';

/**
 * Every string shown to the user, in French, gathered here so a translation can
 * be added later without touching the screens.
 */
export const strings = {
  appName: APP_NAME,

  common: {
    loading: 'Chargement…',
    retry: 'Réessayer',
    cancel: 'Annuler',
    error: 'Une erreur est survenue',
  },

  setup: {
    title: 'Configuration requise',
    missingEnv:
      "L'URL et la clé anon de Supabase sont absentes. Copie .env.example vers .env, renseigne les deux valeurs, puis relance le serveur de développement.",
    checking: 'Connexion à Supabase…',
    connected: 'Connexion à Supabase établie.',
    templatesCount: (count: number) =>
      count === 1 ? '1 template dans le catalogue' : `${count} templates dans le catalogue`,
    emptyCatalogue:
      "Le catalogue est vide. Applique les migrations puis charge les templates (supabase db reset).",
    failed: 'Lecture de la table templates impossible.',
  },
} as const;
