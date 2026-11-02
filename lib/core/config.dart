/// Build-time config. Change the CDN repo/branch here, not in widgets.
class AppConfig {
  static const appName = 'oxvox';
  static const contentBase =
      'https://cdn.jsdelivr.net/gh/nazmul-hussain/oxvox-cdn@main/';
  static const manifestPath = 'v1/manifest.json';

  /// Netlify function behind the site (login, profile, progress data). Same as the web app's /api.
  static const apiBase = 'https://oxvox.netlify.app/api/';

  static const whatsappGroupUrl =
      'https://chat.whatsapp.com/KsHui9d7Wus3Us4s1wMxx0';
  static const facebookGroupUrl =
      'https://www.facebook.com/groups/2079007306180324';
  static const privacyPolicyUrl =
      'https://nazmul-hussain.github.io/oxvox-cdn/privacy.html';
}
