/**
 * Application identity, shared by the Expo config and the app itself.
 *
 * This file is plain CommonJS on purpose: app.config.ts is loaded by the Expo
 * CLI through a bare `require`, which cannot resolve TypeScript modules. The
 * app imports these values through lib/constants.ts.
 *
 * The product name is provisional: change it here, in this single place, when
 * the final name is chosen.
 */
const APP_NAME = 'Meme du Jour';
const APP_SLUG = 'meme-du-jour';
const APP_SCHEME = 'memedujour';
const IOS_BUNDLE_ID = 'com.memedujour.app';
const ANDROID_PACKAGE = 'com.memedujour.app';

module.exports = {
  APP_NAME,
  APP_SLUG,
  APP_SCHEME,
  IOS_BUNDLE_ID,
  ANDROID_PACKAGE,
};
