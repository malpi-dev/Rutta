import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/di/repository_providers.dart';
import 'package:rutta/core/presentation/root_scaffold_messenger.dart';
import 'package:rutta/core/supabase/supabase_client_provider.dart';
import 'package:rutta/core/theme/app_theme.dart';
import 'package:rutta/features/auth/domain/auth_repository.dart';
import 'package:rutta/l10n/app_localizations.dart';

List<Override> authOverrides(AuthRepository repo, {bool backend = true}) => [
  backendConfiguredProvider.overrideWithValue(backend),
  authRepositoryProvider.overrideWithValue(repo),
];

/// Pumps [routes] with go_router (no redirect) so screens can push/pop.
Future<void> pumpRoutes(
  WidgetTester tester, {
  required List<GoRoute> routes,
  required List<Override> overrides,
  String initialLocation = '/',
}) {
  return tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: routes,
        ),
      ),
    ),
  );
}
