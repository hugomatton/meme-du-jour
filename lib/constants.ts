import {
  ANDROID_PACKAGE,
  APP_NAME,
  APP_SCHEME,
  APP_SLUG,
  IOS_BUNDLE_ID,
} from '../app.constants';

/**
 * Identity constants re-exported from app.constants.js, which the Expo config
 * also reads, so the app and the build configuration never drift apart.
 */
export { ANDROID_PACKAGE, APP_NAME, APP_SCHEME, APP_SLUG, IOS_BUNDLE_ID };

/** Business rules the client mirrors (the database stays the source of truth). */
export const MAX_GROUP_MEMBERS = 30;
export const DAILY_DRAW_HOUR_PARIS = 10;
export const PARIS_TIMEZONE = 'Europe/Paris';
