import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/core/di/provider_retry.dart';
import 'package:rutta/core/presentation/root_scaffold_messenger.dart';
import 'package:rutta/core/theme/app_theme.dart';
import 'package:rutta/l10n/app_localizations.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}
