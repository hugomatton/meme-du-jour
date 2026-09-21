import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import { env, isSupabaseConfigured } from './env';
import type { Database } from './types/database';

let client: SupabaseClient<Database> | null = null;

/**
 * The one Supabase client of the app.
 *
 * It is built on first use rather than at import time: `createClient` throws
 * when the URL is missing, and a project whose .env has not been filled in yet
 * must still be able to render the screen that says so.
 *
 * Sessions are persisted in AsyncStorage so a relaunch does not ask the user to
 * sign in again; `detectSessionInUrl` is a browser-only concern and stays off.
 */
export function getSupabase(): SupabaseClient<Database> {
  if (!isSupabaseConfigured) {
    throw new Error('Supabase is not configured: set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY.');
  }

  client ??= createClient<Database>(env.supabaseUrl, env.supabaseAnonKey, {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });

  return client;
}

/** Public URL of a file in the `templates` storage bucket. */
export function templateImageUrl(imagePath: string): string {
  return getSupabase().storage.from('templates').getPublicUrl(imagePath).data.publicUrl;
}
