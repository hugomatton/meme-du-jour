import { useQuery } from '@tanstack/react-query';

import { queryKeys } from '../query-client';
import { getSupabase } from '../supabase';
import { toTemplate, type Template } from '../types/template';

/**
 * The active template catalogue. Reading it is the smoke test of the whole
 * data path: the app talks to Supabase, and row level security lets a signed-in
 * user read `templates`.
 */
export function useTemplates(options?: { enabled?: boolean }) {
  return useQuery<Template[]>({
    queryKey: queryKeys.templates,
    enabled: options?.enabled ?? true,
    queryFn: async () => {
      const { data, error } = await getSupabase()
        .from('templates')
        .select('*')
        .eq('active', true)
        .order('created_at', { ascending: true });

      if (error) throw new Error(error.message);
      return (data ?? []).map(toTemplate);
    },
  });
}
