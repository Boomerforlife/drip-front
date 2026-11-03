/// Backend configuration. Defaults are baked in; override with `--dart-define`
/// (or `--dart-define-from-file=config/dev.json`). Nothing here is secret: the
/// app only ever gets the API address, the Supabase URL and the *publishable*
/// key, never a service key.
abstract final class Env {
  // Defaults point at the live beta backend, so a plain `flutter run` (an IDE
  // run button, Antigravity, `flutter build`) works without any flags. These
  // are public values: the publishable key ships in every build by design and
  // Row Level Security protects the data. Pass a --dart-define to override.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://drip-backend-production-dc7f.up.railway.app',
  );
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://arpqhpnmuifqjtbqomrh.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_4nPyv0VB8QMqbVMniUwenw_mcLaaTzy',
  );

  /// Where Google sends the user back after sign-in (Android / iOS). Must be
  /// listed under Supabase → Authentication → URL Configuration.
  static const authRedirect = 'com.drip.drip://login-callback';

  /// This build's version, sent with bug reports. Keep in step with
  /// `version:` in pubspec.yaml (or pass --dart-define=APP_VERSION=…).
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );

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
