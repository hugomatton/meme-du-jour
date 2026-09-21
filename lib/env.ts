import Constants from 'expo-constants';

type PublicConfig = {
  supabaseUrl: string;
  supabaseAnonKey: string;
};

const extra = (Constants.expoConfig?.extra ?? {}) as Partial<PublicConfig>;

/**
 * Public configuration, injected at build time from the environment
 * (see .env.example and the EAS build variables). Only values that are safe to
 * ship in a client bundle belong here.
 */
export const env: PublicConfig = {
  supabaseUrl: extra.supabaseUrl ?? '',
  supabaseAnonKey: extra.supabaseAnonKey ?? '',
};

export const isSupabaseConfigured = env.supabaseUrl !== '' && env.supabaseAnonKey !== '';
