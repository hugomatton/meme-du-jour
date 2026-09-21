/** Shared visual tokens. Kept deliberately small until the design settles. */
export const theme = {
  colors: {
    background: '#0F0F14',
    surface: '#1B1B24',
    border: '#2C2C38',
    text: '#F5F5F7',
    textMuted: '#9A9AAB',
    accent: '#FFD23F',
    danger: '#FF5A5F',
    success: '#3DDC97',
  },
  spacing: (n: number) => n * 8,
  radius: 16,
  /** Anton is the meme font (OFL licensed); Impact is proprietary and unused. */
  memeFontFamily: 'Anton_400Regular',
} as const;
