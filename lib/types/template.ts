import type { Tables } from './database';

/**
 * A text zone of a template. All coordinates are percentages of the image, so
 * a meme renders identically whatever the display size (section 7 of the spec).
 */
export type TextZone = {
  id: string;
  /** Left edge, in % of the image width. */
  x: number;
  /** Top edge, in % of the image height. */
  y: number;
  /** Width, in % of the image width. */
  w: number;
  /** Height, in % of the image height. */
  h: number;
  /** Font size, in % of the image width. Shrinks further to fit the zone. */
  font_size: number;
  align: 'left' | 'center' | 'right';
  color: string;
  stroke: string;
  uppercase: boolean;
  placeholder: string;
  max_chars?: number;
};

export type Template = Omit<Tables<'templates'>, 'text_zones'> & {
  text_zones: TextZone[];
};

/** The texts a user wrote, keyed by zone id. */
export type MemeTexts = Record<string, string>;

const ALIGNMENTS = new Set(['left', 'center', 'right']);

function asAlign(value: unknown): TextZone['align'] {
  return typeof value === 'string' && ALIGNMENTS.has(value) ? (value as TextZone['align']) : 'center';
}

function asNumber(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' ? value : fallback;
}

/**
 * Parses the `text_zones` json column. The column is validated as an array in
 * the database but its contents are free-form, so every field is checked here
 * rather than cast blindly.
 */
export function parseTextZones(value: unknown): TextZone[] {
  if (!Array.isArray(value)) return [];

  return value.flatMap((raw): TextZone[] => {
    if (typeof raw !== 'object' || raw === null) return [];
    const zone = raw as Record<string, unknown>;
    if (typeof zone.id !== 'string') return [];

    const maxChars = asNumber(zone.max_chars, Number.NaN);

    return [
      {
        id: zone.id,
        x: asNumber(zone.x, 0),
        y: asNumber(zone.y, 0),
        w: asNumber(zone.w, 100),
        h: asNumber(zone.h, 20),
        font_size: asNumber(zone.font_size, 8),
        align: asAlign(zone.align),
        color: asString(zone.color, '#FFFFFF'),
        stroke: asString(zone.stroke, '#000000'),
        uppercase: zone.uppercase === true,
        placeholder: asString(zone.placeholder, ''),
        ...(Number.isFinite(maxChars) ? { max_chars: maxChars } : {}),
      },
    ];
  });
}

/** Turns a raw `templates` row into a template with parsed zones. */
export function toTemplate(row: Tables<'templates'>): Template {
  return { ...row, text_zones: parseTextZones(row.text_zones) };
}
