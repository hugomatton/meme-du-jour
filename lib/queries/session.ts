import { useQuery } from '@tanstack/react-query';
import type { Session } from '@supabase/supabase-js';

import { queryKeys } from '../query-client';
import { getSupabase } from '../supabase';

/**
 * Phase 1 scaffolding.
 *
 * `templates` is readable by the `authenticated` role only, so the foundation
 * screen needs a session before it can prove the data path works end to end.
 * An anonymous sign-in stands in until the real Apple / Google flow lands in
 * phase 2, and this hook disappears with it.
 *
 * It needs anonymous sign-ins enabled on the project: already the case for the
 * local stack (supabase/config.toml), a toggle in Authentication > Sign In /
 * Providers on a hosted one.
 */
export function useFoundationSession(options?: { enabled?: boolean }) {
  return useQuery<Session>({
    queryKey: queryKeys.session,
    enabled: options?.enabled ?? true,
    retry: false,
    staleTime: Infinity,
    queryFn: async () => {
      const supabase = getSupabase();

      const { data: existing } = await supabase.auth.getSession();
      if (existing.session) return existing.session;

      const { data, error } = await supabase.auth.signInAnonymously();
      if (error) throw new Error(error.message);
      if (!data.session) throw new Error('No session returned by signInAnonymously.');
      return data.session;
    },
  });
}
