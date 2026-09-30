import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0E1018),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Supabase is only for sign-in (session storage + token refresh); the app
  // talks to the Drip API for everything else.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      // Surface failures in the UI (error states) instead of silently retrying.
      retry: (retryCount, error) => null,
      child: const DripApp(),
    ),
  );
}

/// Shown when the app was built without its `--dart-define`s, instead of
/// failing on the first network call.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0E1018),
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Text(
              'Drip is missing its configuration: '
              '${Env.missing.join(', ')}.\n\nRun with:\n'
              'flutter run --dart-define-from-file=config/dev.json',
              style: const TextStyle(color: Colors.white, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
