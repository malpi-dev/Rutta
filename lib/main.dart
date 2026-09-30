import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/app.dart';
import 'package:rutta/core/config/env.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/supabase/supabase_client_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Manrope', 'Inter']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
  final prefs = await SharedPreferences.getInstance();
  var backendReady = false;
  if (Env.isBackendConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
      );
      backendReady = true;
    } on Object catch (error) {
      // Malformed URL and the like: the app still works in demo mode.
      debugPrint('Supabase.initialize failed: $error');
    }
  }
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendConfiguredProvider.overrideWithValue(backendReady),
      ],
      child: const RuttaApp(),
    ),
  );
}
