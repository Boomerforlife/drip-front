/// Build-time configuration, passed with `--dart-define` (or
/// `--dart-define-from-file=config/dev.json`). Nothing here is secret: the app
/// only ever gets the API address, the Supabase URL and the *publishable* key.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Where Google sends the user back after sign-in (Android / iOS). Must be
  /// listed under Supabase → Authentication → URL Configuration.
  static const authRedirect = 'com.drip.drip://login-callback';

  static bool get isConfigured =>
      apiBaseUrl.isNotEmpty &&
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty;

  /// The defines that are missing, for the startup error screen.
  static List<String> get missing => [
    if (apiBaseUrl.isEmpty) 'API_BASE_URL',
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
}
