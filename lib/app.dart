import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/domain/app_mode.dart';
import 'package:rutta/core/presentation/l10n_extension.dart';
import 'package:rutta/core/presentation/root_scaffold_messenger.dart';
import 'package:rutta/core/router/app_router.dart';
import 'package:rutta/core/theme/app_theme.dart';
import 'package:rutta/features/demo/presentation/demo_banner.dart';
import 'package:rutta/features/orders/presentation/orders_providers.dart';
import 'package:rutta/features/settings/domain/theme_preference.dart';
import 'package:rutta/features/settings/presentation/theme_controller.dart';
import 'package:rutta/l10n/app_localizations.dart';

class RuttaApp extends ConsumerStatefulWidget {
  const RuttaApp({super.key});

  @override
  ConsumerState<RuttaApp> createState() => _RuttaAppState();
}

class _RuttaAppState extends ConsumerState<RuttaApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Android may cut the socket while the app is in the background: on
    // resume (live only) re-read the list; open detail screens re-subscribe
    // and re-read on their own when their channel reconnects.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(appModeControllerProvider) is AppModeLive) {
          ref.invalidate(myOrdersProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      routerConfig: ref.watch(appRouterProvider),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (ref.watch(themeControllerProvider)) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        if (ref.watch(appModeControllerProvider) is! AppModeDemo) return child!;
        // Painted AFTER the navigator so Maestro can see it: an opaque route
        // hides the semantics of whatever was painted before it.
        return Column(
          verticalDirection: VerticalDirection.up,
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child!,
              ),
            ),
            const DemoBanner(),
          ],
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
