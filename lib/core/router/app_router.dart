import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rutta/core/di/app_mode_provider.dart';
import 'package:rutta/core/domain/user_role.dart';
import 'package:rutta/core/router/app_redirect.dart';
import 'package:rutta/core/router/routes.dart';
import 'package:rutta/core/router/startup_screen.dart';
import 'package:rutta/features/auth/presentation/login_screen.dart';
import 'package:rutta/features/auth/presentation/onboarding_screen.dart';
import 'package:rutta/features/auth/presentation/session_providers.dart';
import 'package:rutta/features/auth/presentation/verify_code_screen.dart';
import 'package:rutta/features/orders/presentation/courier_orders_screen.dart';
import 'package:rutta/features/orders/presentation/customer_orders_screen.dart';
import 'package:rutta/features/orders/presentation/order_detail_screen.dart';
import 'package:rutta/features/settings/presentation/settings_screen.dart';

part 'app_router.g.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Part of the composition root: it may import screens of every feature.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(sessionStateProvider, (_, _) => refresh.value++)
    ..listen(appModeControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.startup,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      mode: ref.read(appModeControllerProvider),
      session: ref.read(sessionStateProvider),
    ),
    routes: [
      GoRoute(path: Routes.startup, builder: (_, _) => const StartupScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.verify,
        builder: (_, state) => VerifyCodeScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.customerOrders,
        builder: (_, _) => const CustomerOrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) => OrderDetailScreen(
              orderId: s.pathParameters['id']!,
              role: UserRole.customer,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.courierOrders,
        builder: (_, _) => const CourierOrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) => OrderDetailScreen(
              orderId: s.pathParameters['id']!,
              role: UserRole.courier,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
