import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // A challenge changes once a day: no need to refetch aggressively.
      staleTime: 60_000,
      retry: 2,
    },
  },
});

/** Query keys, kept in one place so invalidation stays predictable. */
export const queryKeys = {
  templates: ['templates'] as const,
  myGroups: ['groups', 'mine'] as const,
  group: (groupId: string) => ['groups', groupId] as const,
  currentChallenge: (groupId: string) => ['groups', groupId, 'challenge', 'current'] as const,
  feed: (challengeId: string) => ['challenges', challengeId, 'memes'] as const,
  comments: (memeId: string) => ['memes', memeId, 'comments'] as const,
  monthlyTop: (groupId: string, month: string) => ['groups', groupId, 'recap', month] as const,
};
