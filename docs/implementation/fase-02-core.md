# Fase 02 · Core

**Rama:** `feat/fase-02-core`
**Objetivo:** las piezas compartidas que usarán todas las features: reloj inyectable, `UserRole`, `AppMode`, errores de
dominio, configuración de entorno, tema claro/oscuro con fuentes propias, preferencia de tema persistida, router con
redirect puro por sesión/rol/demo (pantallas provisionales) y widgets comunes de estado y formato.
**Referencias:** definición §5.2, §6.1 (`UserProfile`), §6.6, §8.1, §8.4, §11, §12.1, §15.
**Requisitos previos:** fase 01 terminada.

> Al terminar: la app abre en `/login` (provisional, "Coming soon"), respeta el modo oscuro del sistema, y el
> redirect está cubierto por tests para todas las combinaciones de sesión, rol y demo.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Dominio compartido (`lib/core/domain/`)

Dart puro (sin Flutter). Cada clase `@immutable` (de `package:meta`) con `==`, `hashCode` y `toString`.

### 1.1 `clock.dart`

```dart
abstract interface class Clock {
  DateTime nowUtc();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Deterministic clock for tests. [now] is mutable so tests can advance time.
class FixedClock implements Clock {
  FixedClock(DateTime now) : now = now.toUtc();
  DateTime now;
  void advance(Duration by) => now = now.add(by);
  @override
  DateTime nowUtc() => now;
}
```

### 1.2 `user_role.dart`

```dart
enum UserRole {
  customer('customer'),
  courier('courier');

  const UserRole(this.wireName);
  final String wireName;           // value stored in rutta.profiles.role

  /// Throws FormatException for unknown values (mappers translate it to UnknownError).
  static UserRole fromWire(String value);
}
```

### 1.3 `app_mode.dart`

```dart
/// Live = real repositories (Supabase). Demo = mock repositories with the chosen role. Never persisted.
sealed class AppMode {
  const AppMode();
}

final class AppModeLive extends AppMode {
  const AppModeLive();
}

final class AppModeDemo extends AppMode {
  const AppModeDemo(this.role);
  final UserRole role;
}
```

Implementa `==`/`hashCode` en ambas (dos `AppModeLive` son iguales; `AppModeDemo` compara `role`).

## Paso 2 · Errores de dominio (`lib/core/errors/domain_error.dart`)

Clases Dart normales (no freezed), `sealed` para que el `switch` de la UI sea exhaustivo (definición §6.6):

```dart
/// Typed errors thrown by repositories and use cases. Presentation switches over them exhaustively.
/// Portfolio-wide codes: NetworkError/BackendUnavailableError=network, UnauthorizedError=unauthorized,
/// NotFoundError=notFound, ConflictError/InvalidTransitionError/NotAssignedToYouError/CourierBusyError=conflict,
/// ValidationError=validation, UnknownError=unknown.
sealed class DomainError implements Exception {
  const DomainError();
}

// ---- common
final class NetworkError extends DomainError { const NetworkError([this.cause]); final Object? cause; }
/// The backend answered 5xx or is paused (free-tier projects pause after 7 days).
final class BackendUnavailableError extends DomainError { const BackendUnavailableError([this.cause]); final Object? cause; }
final class UnauthorizedError extends DomainError { const UnauthorizedError(); }
final class NotFoundError extends DomainError { const NotFoundError(this.entity, [this.id]); final String entity; final String? id; }
final class ConflictError extends DomainError { const ConflictError([this.detail]); final String? detail; }
enum ValidationReason { required, tooLong, invalidFormat }
final class ValidationError extends DomainError { const ValidationError(this.field, this.reason); final String field; final ValidationReason reason; }
final class UnknownError extends DomainError { const UnknownError([this.cause]); final Object? cause; }

// ---- auth
enum AuthErrorKind { invalidEmail, invalidCode, codeExpired, rateLimited }
final class AuthError extends DomainError { const AuthError(this.kind); final AuthErrorKind kind; }

// ---- orders
final class InvalidTransitionError extends DomainError {
  const InvalidTransitionError({this.from, this.to});
  final String? from;   // wire names ('picked_up'); null when unknown
  final String? to;
}
final class NotAssignedToYouError extends DomainError { const NotAssignedToYouError(); }
final class CourierBusyError extends DomainError { const CourierBusyError(); }

// ---- tracking
final class NoActiveOrderError extends DomainError { const NoActiveOrderError(); }
final class LocationPermissionDeniedError extends DomainError {
  const LocationPermissionDeniedError({required this.permanently});
  final bool permanently;
}
final class LocationServiceDisabledError extends DomainError { const LocationServiceDisabledError(); }
```

- `InvalidTransitionError` usa `String` y no `OrderStatus` porque `core/` no puede depender de `features/`.
- Añade `toString()` útil en cada una (ayuda en los tests).

## Paso 3 · Configuración de entorno (`lib/core/config/env.dart`)

```dart
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  static const mapUserAgentPackage = String.fromEnvironment(
    'MAP_USER_AGENT_PACKAGE', defaultValue: 'com.malpidev.rutta');
  static const _minIntervalS = String.fromEnvironment('LOCATION_MIN_INTERVAL_S', defaultValue: '5');
  static const _minDistanceM = String.fromEnvironment('LOCATION_MIN_DISTANCE_M', defaultValue: '10');

  /// Without both values the app runs in demo-only mode (definition §15).
  static bool get isBackendConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  static Duration get locationMinInterval => Duration(seconds: int.tryParse(_minIntervalS) ?? 5);
  static double get locationMinDistanceMeters => double.tryParse(_minDistanceM) ?? 10;
}
```

Nunca lanza. Sin `.env.json` la app funciona (solo demo).

## Paso 4 · Fuentes

1. Descarga los TTF estáticos (subset latino) a `assets/fonts/`:
   ```bash
   cd assets/fonts
   for w in 600 700 800; do curl -fL -o "Manrope-$w.ttf" "https://cdn.jsdelivr.net/fontsource/fonts/manrope@latest/latin-$w-normal.ttf"; done
   for w in 400 500 600; do curl -fL -o "Inter-$w.ttf" "https://cdn.jsdelivr.net/fontsource/fonts/inter@latest/latin-$w-normal.ttf"; done
   file *.ttf      # each one must say "TrueType Font data"
   cd ../..
   ```
   Si falla: copia los mismos archivos desde `../Centavo/assets/fonts/` (mismas fuentes y licencias). Si tampoco existen:
   **🙋 Acción del autor** → descargar Manrope (600, 700, 800) e Inter (400, 500, 600) estáticas desde fonts.google.com.
2. Licencias: `assets/fonts/OFL-Manrope.txt` y `assets/fonts/OFL-Inter.txt` (cópialas de Centavo o del repo de cada
   fuente). Regístralas con `LicenseRegistry.addLicense` en `main.dart` (paso 11).
3. `pubspec.yaml` → `flutter:`:
   ```yaml
   assets:
     - assets/fonts/OFL-Manrope.txt
     - assets/fonts/OFL-Inter.txt
   fonts:
     - family: Manrope
       fonts:
         - { asset: assets/fonts/Manrope-600.ttf, weight: 600 }
         - { asset: assets/fonts/Manrope-700.ttf, weight: 700 }
         - { asset: assets/fonts/Manrope-800.ttf, weight: 800 }
     - family: Inter
       fonts:
         - { asset: assets/fonts/Inter-400.ttf, weight: 400 }
         - { asset: assets/fonts/Inter-500.ttf, weight: 500 }
         - { asset: assets/fonts/Inter-600.ttf, weight: 600 }
   ```

## Paso 5 · Tema (`lib/core/theme/`)

### 5.1 `app_colors.dart`

Constantes de la definición §11 (única carpeta donde se permiten `Color(0x…)`):

| Token | Claro | Oscuro |
|---|---|---|
| primary | `0xFFFF5A1F` | `0xFFFF7A45` |
| onPrimary | `0xFFFFFFFF` | `0xFF1A0E08` |
| secondary | `0xFF1E3A5F` | `0xFF8FB3E0` |
| success | `0xFF1F9D55` | `0xFF4ADE80` |
| warning | `0xFFD97706` | `0xFFFBBF24` |
| error | `0xFFDC2626` | `0xFFF87171` |
| background | `0xFFF7F7F5` | `0xFF0F141A` |
| surface | `0xFFFFFFFF` | `0xFF1A212B` |
| onSurface | `0xFF1B1F24` | `0xFFE6EAF0` |
| neutral (estados `created`/`cancelled`, marcador *stale*) | `0xFF6B7280` | `0xFF9CA3AF` |

`routeTraveled` = `primary` con alfa 35 % (`primary.withValues(alpha: 0.35)`).

### 5.2 `rutta_colors.dart` — `ThemeExtension<RuttaColors>`

Campos (`Color`): `success`, `warning`, `neutral`, `routeRemaining` (= primary), `routeTraveled`, `pickupMarker`
(= secondary), `dropoffMarker` (= secondary), `courierMarker` (= primary), `courierStale` (= neutral).
Implementa `copyWith` y `lerp`. Acceso:
`extension RuttaColorsX on BuildContext { RuttaColors get colors => Theme.of(this).extension<RuttaColors>()!; }`.

### 5.3 `app_theme.dart`

```dart
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) { … }
}
```

- `ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(primary:, onPrimary:, secondary:, surface:, onSurface:, error:)`
  con los valores de la tabla según el brillo. `scaffoldBackgroundColor` = background. `useMaterial3: true`.
- `textTheme`: `display*`, `headline*`, `title*` con `fontFamily: 'Manrope'` (800 en display, 700 en headline,
  600 en title); `body*` y `label*` con `fontFamily: 'Inter'`. Parte de `Typography.material2021().black/white` según
  el brillo y aplica `.apply(bodyColor: onSurface, displayColor: onSurface)`.
- `extensions: [RuttaColors(...)]`.
- Estilos comunes: `CardTheme` (sin elevación, radio 16, color surface), `InputDecorationTheme` (outline, radio 12),
  `FilledButtonTheme` (altura mínima 52, radio 14), `ChipTheme` (radio 8), `SnackBarTheme` (`behavior: floating`).

## Paso 6 · Preferencia de tema (`lib/features/settings/`)

`domain/theme_preference.dart`: `enum ThemePreference { system, light, dark }`.

`domain/settings_repository.dart`:

```dart
abstract interface class SettingsRepository {
  ThemePreference loadTheme();                       // synchronous: needed before the first frame
  Future<void> saveTheme(ThemePreference preference);
}
```

`data/prefs_settings_repository.dart` (clave `settings.theme`, guarda `preference.name`; valor ausente o desconocido →
`system`, nunca lanza) y `data/in_memory_settings_repository.dart` (valor inicial opcional).

`presentation/theme_controller.dart`:

```dart
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  ThemePreference build() => ref.watch(settingsRepositoryProvider).loadTheme();

  Future<void> change(ThemePreference preference) async {
    await ref.read(settingsRepositoryProvider).saveTheme(preference);
    state = preference;
  }
}
```

## Paso 7 · Providers base (`lib/core/di/`)

`provider_retry.dart` (copia de Centavo):

```dart
/// Riverpod retries failed providers with exponential backoff by default, which keeps a failing screen in
/// "loading" for a long time. Errors are surfaced right away with a manual *Retry* instead.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
```

`repository_providers.dart` — **composition root** (el único archivo, junto con `main.dart`, que importa `data/` de
varias features). En esta fase:

```dart
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => PrefsSettingsRepository(ref.watch(sharedPreferencesProvider));
```

`app_mode_provider.dart`:

```dart
@Riverpod(keepAlive: true)
class AppModeController extends _$AppModeController {
  @override
  AppMode build() => const AppModeLive();          // never persisted (definition §8.3)
  void enterDemo(UserRole role) => state = AppModeDemo(role);
  void exitDemo() => state = const AppModeLive();
}
```

## Paso 8 · Sesión (tipos mínimos para el router)

El router necesita saber si hay sesión, perfil y rol. Crea ya estos tipos del dominio de auth (la interfaz del
repositorio llega en la fase 03):

`lib/features/auth/domain/user_profile.dart` (freezed):

```dart
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String fullName,
    required UserRole role,
    String? phone,
  }) = _UserProfile;
}
```

`lib/features/auth/domain/session_state.dart`:

```dart
sealed class SessionState { const SessionState(); }
final class SessionSignedOut extends SessionState { const SessionSignedOut(); }
/// Signed in to Supabase but without a Rutta profile yet (new user or coming from another portfolio app).
final class SessionNeedsProfile extends SessionState { const SessionNeedsProfile(this.email); final String email; }
final class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.profile, this.email);
  final UserProfile profile;
  final String email;
}
```

(Con `==`/`hashCode`.) `lib/features/auth/presentation/session_providers.dart` — **provisional** (la fase 10 lo
conecta al repositorio):

```dart
@Riverpod(keepAlive: true)
Stream<SessionState> sessionState(Ref ref) => Stream.value(const SessionSignedOut());
```

## Paso 9 · Localización, mensajes y formato

1. `lib/core/presentation/l10n_extension.dart`:
   `extension L10nX on BuildContext { AppLocalizations get l10n => AppLocalizations.of(this); }`
2. Añade a `app_en.arb`:
   - Comunes: `retry` "Retry", `cancel` "Cancel", `confirm` "Confirm", `continueLabel` "Continue", `comingSoon` "Coming soon",
     `settings` "Settings".
   - Errores (uno por caso de `DomainError`):
     `errorNetwork` "You're offline. Check your connection and try again." ·
     `errorBackendUnavailable` "The service is unavailable right now. Please try again in a moment." ·
     `errorUnauthorized` "Your session has expired. Sign in again." ·
     `errorNotFound` "This order no longer exists." ·
     `errorConflict` "Someone else changed this. Refresh and try again." ·
     `errorValidation` "Please check the highlighted field." ·
     `errorUnknown` "Something went wrong. Please try again." ·
     `errorAuthInvalidEmail` "Enter a valid email address." ·
     `errorAuthInvalidCode` "The code is invalid or has expired." ·
     `errorAuthCodeExpired` "The code has expired. Request a new one." ·
     `errorAuthRateLimited` "Too many attempts. Wait a few minutes and try again." ·
     `errorInvalidTransition` "This order can't move to that status." ·
     `errorNotAssignedToYou` "This order isn't assigned to you." ·
     `errorCourierBusy` "Finish your current delivery before starting another one." ·
     `errorNoActiveOrder` "There's no delivery in progress." ·
     `errorLocationPermissionDenied` "Location permission is needed to share your position." ·
     `errorLocationPermissionDeniedForever` "Location is blocked for Rutta. Enable it in the app settings." ·
     `errorLocationServiceDisabled` "Turn on location services to share your position."
   - Validación: `validationRequired` "Required", `validationTooLong` "Too long", `validationInvalidFormat` "Invalid value".
3. `lib/core/presentation/error_messages.dart`:
   - `String errorMessage(DomainError error, AppLocalizations l10n)` con `switch` **exhaustivo** sobre el tipo (y
     sobre `kind`/`permanently` donde aplique). **Sin** `default`: si mañana se añade un error, el analyzer avisa.
   - `String validationMessage(ValidationReason reason, AppLocalizations l10n)`.
   - `String messageFor(Object error, AppLocalizations l10n)` → `errorMessage` si es `DomainError`, si no `errorUnknown`.
4. `lib/core/presentation/formatters.dart` (usa `intl`; solo para mostrar):

   | Función | Ejemplos |
   |---|---|
   | `String formatMoneyCents(int cents)` | `24500` → `MX$245.00` (`NumberFormat.simpleCurrency(locale: 'en_US', name: 'MXN')`) |
   | `String formatDistance(double meters)` | `850.4` → `850 m`; `999.6` → `1.0 km`; `2430` → `2.4 km` (< 1000 m: entero en m; si no, 1 decimal en km) |
   | `String formatEta(Duration eta)` | `< 60 s` → `< 1 min`; `125 s` → `3 min` (redondeo hacia arriba); `≥ 60 min` → `1 h 5 min` |
   | `String formatTime(DateTime utc)` | hora local `h:mm a` → `2:32 PM` (`DateFormat.jm('en_US')`) |
   | `String formatOrderDate(DateTime utc, DateTime nowUtc)` | mismo día local → `2:32 PM`; otro día → `Sep 28, 2:32 PM` |
   | `String formatAgo(Duration elapsed)` | `45 s ago`, `2 min ago` (mín. 0 s) |

   Tests con `Intl.defaultLocale` fijo y fechas UTC construidas; para la hora local usa `DateTime.utc(...).toLocal()`
   dentro del test para calcular lo esperado (no dependas de la zona de la máquina de CI).

## Paso 10 · Widgets comunes (`lib/core/presentation/`)

| Archivo | Widget / función | Detalle |
|---|---|---|
| `skeleton.dart` | `SkeletonBox(width, height, radius)`, `SkeletonList(itemCount, itemHeight)` | Cajas con `colorScheme.surfaceContainerHighest`; **sin animación** (evita timers en tests). |
| `empty_state.dart` | `EmptyState(icon, title, message?, actionLabel?, onAction?, actionKey?)` | Centrado, ícono grande `onSurfaceVariant`. |
| `error_state.dart` | `ErrorState(message, onRetry?)` | Ícono de error + mensaje + botón *Retry* (key `error-retry`). |
| `async_state_view.dart` | `AsyncStateView<T>` | Ver abajo. |
| `root_scaffold_messenger.dart` | `final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();` y `void showErrorSnackBar(Object error, AppLocalizations l10n)` | Todos los SnackBars pasan por aquí. |

```dart
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value, required this.data, this.isEmpty, this.empty, this.loading, this.onRetry, super.key,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;        // default: SkeletonList(itemCount: 3, itemHeight: 96)
  final VoidCallback? onRetry;
  // If value has a value (even while reloading) → data/empty. Else loading → loading. Else error → ErrorState.
}
```

## Paso 11 · Router (`lib/core/router/`)

### 11.1 `routes.dart`

```dart
abstract final class Routes {
  static const startup = '/';
  static const login = '/login';
  static const verify = '/verify';                     // ?email=<email>
  static const onboarding = '/onboarding';
  static const customerOrders = '/customer/orders';
  static String customerOrder(String id) => '/customer/orders/$id';
  static const courierOrders = '/courier/orders';
  static String courierOrder(String id) => '/courier/orders/$id';
  static const settings = '/settings';
  static String homeFor(UserRole role) => switch (role) {
        UserRole.customer => customerOrders,
        UserRole.courier => courierOrders,
      };
}
```

### 11.2 `app_redirect.dart` — función **pura** (testeable sin widgets)

```dart
String? appRedirect({
  required String location,                // state.uri.path
  required AppMode mode,
  required AsyncValue<SessionState> session,
}) {
  const entry = {Routes.startup, Routes.login, Routes.verify, Routes.onboarding};

  String? forRole(UserRole role) {
    final home = Routes.homeFor(role);
    final otherPrefix = role == UserRole.customer ? '/courier' : '/customer';
    if (entry.contains(location) || location.startsWith(otherPrefix)) return home;
    return null;                               // own routes and /settings are allowed
  }

  if (mode case AppModeDemo(:final role)) return forRole(role);

  final current = session.hasValue ? session.value : null;
  if (current == null) return location == Routes.startup ? null : Routes.startup;   // loading or error
  return switch (current) {
    SessionSignedOut() =>
      (location == Routes.login || location == Routes.verify) ? null : Routes.login,
    SessionNeedsProfile() => location == Routes.onboarding ? null : Routes.onboarding,
    SessionSignedIn(:final profile) => forRole(profile.role),
  };
}
```

Si tu versión de Riverpod expone `value` de otra forma (p. ej. `valueOrNull`), adapta y anótalo.

### 11.3 `app_router.dart`

```dart
final rootNavigatorKey = GlobalKey<NavigatorState>();

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
      GoRoute(path: Routes.verify, builder: (_, state) => VerifyCodeScreen(email: state.uri.queryParameters['email'] ?? '')),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: Routes.customerOrders,
        builder: (_, _) => const CustomerOrdersScreen(),
        routes: [GoRoute(path: ':id', builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!, role: UserRole.customer))],
      ),
      GoRoute(
        path: Routes.courierOrders,
        builder: (_, _) => const CourierOrdersScreen(),
        routes: [GoRoute(path: ':id', builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!, role: UserRole.courier))],
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
```

- El router importa pantallas de `features/*/presentation`: es parte del composition root, está permitido.
- Si tu versión de Dart no acepta `(_, _)` (wildcards), usa `(_, __)`.

### 11.4 Pantallas provisionales (se reemplazan en sus fases)

Cada una en su feature, `Scaffold` + `AppBar` + `EmptyState(icon: Icons.construction, title: l10n.comingSoon)`:
`auth/presentation/login_screen.dart` (título `appTitle`), `verify_code_screen.dart` (recibe `email`),
`onboarding_screen.dart`, `orders/presentation/customer_orders_screen.dart`, `courier_orders_screen.dart`,
`order_detail_screen.dart` (recibe `orderId` y `role`), `settings/presentation/settings_screen.dart`.

`lib/core/router/startup_screen.dart` (definitiva): `ConsumerWidget` que observa `sessionStateProvider`; si tiene
error muestra `ErrorState(messageFor(error), onRetry: () => ref.invalidate(sessionStateProvider))`; en cualquier
otro caso, un `CircularProgressIndicator` centrado (key `startup-loading`). El redirect la saca de ahí en cuanto hay
sesión.

## Paso 12 · `app.dart` y `main.dart`

`RuttaApp` pasa a `ConsumerWidget`:

```dart
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
  debugShowCheckedModeBanner: false,
);
```

`main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Manrope', 'Inter']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RuttaApp(),
    ),
  );
}
```

## Paso 13 · Helpers de test

- `test/helpers/pump_app.dart`: `Future<void> pumpApp(WidgetTester tester, Widget child, {List overrides = const [], ThemeData? theme})`
  → envuelve en `ProviderScope(retry: noAutomaticRetry, overrides: …)` + `MaterialApp` con `AppTheme.light()` (o el
  `theme` pasado), delegados de l10n, `scaffoldMessengerKey: rootScaffoldMessengerKey` y `home: child`.
  (Ajusta el tipo de `overrides` al que exponga tu versión de Riverpod.)
- `test/helpers/test_overrides.dart`: lista base de overrides para tests de app completa:
  `settingsRepositoryProvider` → `InMemorySettingsRepository()`, `clockProvider` → `FixedClock(DateTime.utc(2026, 10, 7, 18))`.

## Paso 14 · Tests

| Archivo | Qué comprueba |
|---|---|
| `test/core/domain/user_role_test.dart` | `fromWire` de ambos valores; valor desconocido lanza `FormatException`. |
| `test/core/domain/app_mode_test.dart` | igualdad de `AppModeLive` y `AppModeDemo(role)`. |
| `test/core/presentation/formatters_test.dart` | todos los ejemplos de la tabla del paso 9.4. |
| `test/core/presentation/error_messages_test.dart` | cada `DomainError` produce un texto no vacío y distinto de `errorUnknown` (salvo `UnknownError`). |
| `test/core/router/app_redirect_test.dart` | Tabla completa (abajo). |
| `test/features/settings/prefs_settings_repository_test.dart` | con `SharedPreferences.setMockInitialValues({})`: default `system`; guardar/leer ida y vuelta; valor desconocido → `system`. |
| `test/core/presentation/async_state_view_test.dart` | loading → skeleton; data vacía → `empty`; error `NetworkError` → su mensaje y *Retry* llama al callback. |
| `test/app_smoke_test.dart` (reemplaza el de la fase 01) | con overrides de test, la app arranca y termina en la pantalla de login provisional (texto "Rutta" en el AppBar). |

Casos mínimos de `app_redirect_test.dart`:

| mode | session | location | esperado |
|---|---|---|---|
| live | loading | `/customer/orders` | `/` |
| live | loading | `/` | `null` |
| live | error | `/login` | `/` |
| live | SignedOut | `/` | `/login` |
| live | SignedOut | `/verify` | `null` |
| live | SignedOut | `/customer/orders` | `/login` |
| live | NeedsProfile | `/login` | `/onboarding` |
| live | NeedsProfile | `/onboarding` | `null` |
| live | SignedIn(customer) | `/login` | `/customer/orders` |
| live | SignedIn(customer) | `/courier/orders/abc` | `/customer/orders` |
| live | SignedIn(customer) | `/customer/orders/abc` | `null` |
| live | SignedIn(courier) | `/onboarding` | `/courier/orders` |
| live | SignedIn(courier) | `/settings` | `null` |
| demo(customer) | SignedOut | `/login` | `/customer/orders` |
| demo(courier) | SignedOut | `/customer/orders` | `/courier/orders` |
| demo(courier) | loading | `/courier/orders/x` | `null` |

## Paso 15 · Verificación manual

`flutter run`: abre en el login provisional. Activa el modo oscuro del sistema (`adb shell cmd uimode night yes`) y
comprueba que fondo y textos cambian; vuelve con `night no`.

## Paso 16 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] `Clock`, `UserRole`, `AppMode` en `core/domain` sin imports de Flutter, con tests.
- [ ] `DomainError` sellado con todos los casos de §6.6 (+ `BackendUnavailableError`); `errorMessage` exhaustivo sin `default`.
- [ ] `Env` con `isBackendConfigured` y valores por defecto; nunca lanza.
- [ ] Tema claro y oscuro con los tokens de §11, `RuttaColors`, fuentes Manrope + Inter empaquetadas y licencias registradas.
- [ ] Preferencia de tema persistida (`prefs`) con implementación en memoria para tests.
- [ ] Router con redirect puro y la tabla de casos en verde; `StartupScreen` con carga y error; pantallas provisionales.
- [ ] `AsyncStateView`, `EmptyState`, `ErrorState`, `SkeletonList`, formatters y `rootScaffoldMessengerKey` creados.
- [ ] `ProviderScope(retry: noAutomaticRetry)` en `main.dart` y en los helpers de test.
- [ ] Ningún texto de UI literal fuera de `app_en.arb`.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
