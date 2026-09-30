# Fase 10 · Auth

**Rama:** `feat/fase-10-auth`
**Objetivo:** la app se conecta a Supabase (si hay `.env.json`), inicia sesión con **email + código OTP de 6 dígitos**,
pide el nombre la primera vez y crea el perfil con `rutta.ensure_profile`, lleva a cada rol a su home y permite
cerrar sesión. Sin `.env.json`, el login solo ofrece el demo. Traductor de errores de Supabase a `DomainError`.
**Referencias:** definición §3.1 F1, §5.2 (redirect), §7.4, §12.1 (login/verify/onboarding), §15 · `CLAUDE.md` del
portafolio (Convenciones del proyecto compartido: auth OTP y perfiles) · Centavo:
`lib/features/backup/data/supabase_error_mapper.dart` y `supabase_auth_repository.dart` (referencia directa).
**Requisitos previos:** fase 09 terminada. Supabase local corriendo con el seed (`supabase start`) y `.env.json` local.

> Hasta la fase 11 los repositorios de pedidos en modo live lanzan `UnimplementedError`: tras iniciar sesión, la
> lista mostrará el error genérico con *Retry*. Es lo esperado; lo importante aquí es que el redirect lleve al home
> correcto según el rol.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

```bash
flutter pub add http        # mapSupabaseError reconoce http.ClientException (lint depend_on_referenced_packages)
```

## Paso 1 · Cliente de Supabase

`lib/core/supabase/supabase_client_provider.dart`:

```dart
/// Only valid when Env.isBackendConfigured (main() initializes Supabase). Demo mode never reads it.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

/// Overridable in tests (Env values are compile-time constants).
@Riverpod(keepAlive: true)
bool backendConfigured(Ref ref) => Env.isBackendConfigured;
```

En `main.dart`, antes de `runApp`:

```dart
if (Env.isBackendConfigured) {
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey);
}
```

(En supabase_flutter 2.17 el parámetro es `publishableKey:`; si tu versión solo tiene `anonKey:`, úsalo con la
publishable key y anótalo.) Si `initialize` lanza (URL mal formada), captura, registra con `debugPrint` y continúa:
la app sigue funcionando en demo.

## Paso 2 · Traductor de errores (`lib/core/supabase/supabase_error_mapper.dart`)

Parte de la versión de Centavo y amplíala. `DomainError mapSupabaseError(Object error)`, en este orden:

1. `DomainError` → tal cual.
2. `SocketException`, `TimeoutException`, `http.ClientException`, `AuthRetryableFetchException` → `NetworkError(error)`.
3. `PostgrestException` — **primero por prefijo del mensaje** (las RPCs de la fase 09):

   | Mensaje empieza por | Resultado |
   |---|---|
   | `RUTTA_INVALID_TRANSITION` | `InvalidTransitionError(from:, to:)` extraídos con `RegExp(r'from=(\w+) to=(\w+)')` (nulos si no casa) |
   | `RUTTA_COURIER_BUSY` | `CourierBusyError()` |
   | `RUTTA_NOT_ASSIGNED`, `RUTTA_NOT_COURIER` | `NotAssignedToYouError()` |
   | `RUTTA_NOT_FOUND` | `NotFoundError('order')` |
   | `RUTTA_UNAUTHORIZED` | `UnauthorizedError()` |
   | `RUTTA_INVALID_NAME` | `ValidationError('fullName', ValidationReason.invalidFormat)` |

   Después, por código: 3 caracteres numéricos ≥ 500 → `BackendUnavailableError` (proyecto pausado/caído);
   `PGRST301`, `PGRST302` o mensaje con `jwt` → `UnauthorizedError`; `PGRST116` (sin filas en `.single()`) →
   `NotFoundError('order')`; `42501` → `UnauthorizedError`; `23505` → `ConflictError`; resto → `UnknownError`.
4. `AuthException` (como Centavo): 429 / `over_email_send_rate_limit` / `over_request_rate_limit` →
   `AuthError(rateLimited)`; ≥ 500 → `BackendUnavailableError`; `otp_expired` → `AuthError(invalidCode)` (GoTrue usa
   el mismo código para código incorrecto y caducado); `email_address_invalid` / `validation_failed` →
   `AuthError(invalidEmail)`; 401 → `UnauthorizedError`; resto → `UnknownError`.
5. Cualquier otra cosa → `UnknownError(error)`.

Helper en el mismo archivo para los repositorios:

```dart
Future<T> guardSupabase<T>(Future<T> Function() body, {Duration timeout = const Duration(seconds: 20)}) async {
  try {
    return await body().timeout(timeout);
  } on Object catch (error) {
    throw mapSupabaseError(error);
  }
}
```

## Paso 3 · Repositorios de auth

### 3.1 `lib/features/auth/data/supabase_auth_repository.dart`

`SupabaseAuthRepository(SupabaseClient client)`; consultas siempre con `client.schema('rutta')`.

- `watchSession()`: `StreamController<SessionState>` con `onListen`/`onCancel`:
  - Se suscribe a `client.auth.onAuthStateChange` (emite primero `initialSession`) y a un `_profileChanged`
    (`StreamController<void>.broadcast()` interno).
  - Con cada evento **salvo** `tokenRefreshed` (y cada `_profileChanged`) recalcula: sin `session` → `SessionSignedOut`;
    con sesión → `select('id, full_name, role, phone').eq('id', user.id).maybeSingle()` en `profiles`: `null` →
    `SessionNeedsProfile(email)`, fila → `SessionSignedIn(userProfileFromRow(row), email)`.
  - Si la consulta falla, emite `mapSupabaseError(e)` como **error** del stream (la `StartupScreen` muestra *Retry*).
  - Descarta resultados viejos si llega un evento nuevo mientras se consultaba (contador de secuencia).
  - Emite solo si cambia (`distinct` por igualdad).
- `sendCode(email)`: `isValidEmail` o `AuthError(invalidEmail)`; `guardSupabase(() => client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true))`.
- `verifyCode({email, code})`: `isValidOtpCode` o `AuthError(invalidCode)`;
  `client.auth.verifyOTP(type: OtpType.email, email: email.trim(), token: code)`.
- `ensureProfile(fullName)`: `validateFullName`; `client.schema('rutta').rpc('ensure_profile', params: {'p_full_name': name})`
  → `userProfileFromRow`; después `_profileChanged.add(null)`.
- `signOut()`: `client.auth.signOut()` capturando y descartando cualquier error (el cierre local siempre funciona).

`lib/features/auth/data/profile_mapper.dart`: `UserProfile userProfileFromRow(Map<String, dynamic> row)`
(`full_name` → `fullName`, `role` con `UserRole.fromWire`; un rol desconocido → `UnknownError`).

### 3.2 `lib/features/auth/data/mock_auth_repository.dart`

Implementación en memoria (tests y regla 4): empieza en `SessionSignedOut`; `sendCode` valida el email;
`verifyCode` acepta solo `demoOtpCode = '123456'` (constante en `auth/domain/`), si no `AuthError(invalidCode)`;
tras verificar emite `SessionNeedsProfile(email)` (o `SessionSignedIn` si el constructor recibe un perfil existente
para ese email); `ensureProfile` crea un perfil `customer` y emite `SessionSignedIn`; `signOut` vuelve a
`SessionSignedOut`. Latencia opcional (por defecto cero).

### 3.3 Providers

En `repository_providers.dart`:

```dart
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider));
```

`session_providers.dart` (reemplaza el provisional de la fase 02):

```dart
@Riverpod(keepAlive: true)
Stream<SessionState> sessionState(Ref ref) {
  if (!ref.watch(backendConfiguredProvider)) return Stream.value(const SessionSignedOut());
  return ref.watch(authRepositoryProvider).watchSession();
}
```

Ajusta `currentUserIdProvider`/`currentRoleProvider` (fase 08) si hace falta para leer `SessionSignedIn`.

## Paso 4 · Pantallas

Controladores `AsyncNotifier` con `AsyncValue.guard` (errores en el estado; la UI los muestra con `errorMessage`).
Todas las pantallas: contenido centrado con ancho máximo 420, `SingleChildScrollView` (teclado), `SafeArea`.

### 4.1 `LoginScreen` (definitiva)

- Cabecera: ícono de la app (provisional `Icons.route` en `primary`; el logo llega en la fase 12), título `appTitle`
  y `tagline` "Know exactly where your order is.".
- **Con backend** (`backendConfiguredProvider`):
  - `TextField` de email (key e identifier `login-email`, `keyboardType: emailAddress`, `autofillHints: [AutofillHints.email]`,
    `textInputAction: done`), etiqueta `emailLabel` "Email".
  - `FilledButton` `sendCode` "Send code" (key e identifier `login-send-code`), con spinner y campos deshabilitados
    mientras envía. Error bajo el campo (texto de `errorMessage`).
  - Al enviar con éxito: `context.push('${Routes.verify}?email=${Uri.encodeQueryComponent(email)}')`.
  - Separador `orDivider` "or" y el botón *Explore demo* (`login-explore-demo`, de la fase 05).
- **Sin backend:** texto `demoOnlyNotice` "This build has no backend configured. Explore the demo to try Rutta." y
  el botón *Explore demo* como `FilledButton` principal.

### 4.2 `VerifyCodeScreen(email)`

- Texto `verifyTitle` "Check your email" y `verifySubtitle` "Enter the 6-digit code we sent to {email}".
- `TextField` (key e identifier `verify-code`): `keyboardType: number`, `maxLength: 6`, solo dígitos
  (`FilteringTextInputFormatter.digitsOnly`), `autofillHints: [AutofillHints.oneTimeCode]`, texto grande espaciado.
  Al llegar a 6 dígitos se envía solo.
- `FilledButton` `verify` "Verify" (key e identifier `verify-submit`) con spinner.
- `TextButton` `resendCode` "Resend code" (key e identifier `verify-resend`): deshabilitado 60 s con cuenta atrás
  `resendIn` "Resend in {seconds}s" (`Timer.periodic` cancelado en `dispose`); al pulsar vuelve a llamar `sendCode`
  y muestra un SnackBar `codeSent` "We sent you a new code.".
- `TextButton` `useDifferentEmail` "Use a different email" → `context.pop()`.
- Errores bajo el campo: código incorrecto/caducado, límite, red.
- Solo en `kDebugMode` y con backend local (URL contiene `10.0.2.2` o `127.0.0.1`): ayuda pequeña `localMailHint`
  "Local dev: the code is in Mailpit (http://127.0.0.1:54324)".
- Tras verificar **no** navega a mano: `sessionState` emite y el redirect lleva a `/onboarding` o al home.

### 4.3 `OnboardingScreen`

- `onboardingTitle` "What's your name?" y `onboardingSubtitle` "Couriers see it when they bring your order.".
- `TextField` (key e identifier `onboarding-name`, `textCapitalization: words`, `autofillHints: [AutofillHints.name]`,
  máx. 80). Error de validación inline (`validationMessage`).
- `FilledButton` `continueLabel` (key e identifier `onboarding-continue`) → `ensureProfile(name)` con spinner.
- `TextButton` `useDifferentAccount` "Use a different account" → `signOut()`.

### 4.4 Cerrar sesión (mínimo, la pantalla completa es de la fase 12)

En la `SettingsScreen` provisional: si `AppModeLive`, `OutlinedButton` `signOut` "Sign out" (key e identifier
`settings-sign-out`) → `authRepository.signOut()`; si `AppModeDemo`, `exitDemo` (key e identifier
`settings-exit-demo`) → `exitDemo()`. El redirect lleva al login y los providers que dependen de la sesión se reconstruyen.

## Paso 5 · Tests

Overrides de test: `backendConfiguredProvider` → `true`/`false`, `authRepositoryProvider` → `MockAuthRepository`.

| Archivo | Qué comprueba |
|---|---|
| `test/core/supabase/supabase_error_mapper_test.dart` | cada fila de las tablas del paso 2 (construye `PostgrestException(message:, code:)` y `AuthException(message, statusCode:, code:)`); `from`/`to` extraídos; `23505` no se confunde con HTTP 5xx; `SocketException` → `NetworkError`. |
| `test/features/auth/data/profile_mapper_test.dart` | fila → `UserProfile`; rol desconocido → error. |
| `test/features/auth/data/mock_auth_repository_test.dart` | flujo completo SignedOut → verify → NeedsProfile → ensureProfile → SignedIn → signOut; código incorrecto; email inválido. |
| `test/features/auth/presentation/login_screen_test.dart` | email inválido → error bajo el campo; envío correcto → navega a `/verify?email=…`; mientras envía el botón está deshabilitado; sin backend → aviso de demo y sin campo de email. |
| `test/features/auth/presentation/verify_code_screen_test.dart` | código incorrecto → "The code is invalid or has expired."; 6 dígitos se envían solos; *Resend* deshabilitado y habilitado tras 60 s (`tester.pump(const Duration(seconds: 60))`); desmonta al final (timer). |
| `test/features/auth/presentation/auth_flow_test.dart` | app completa con `MockAuthRepository`: login → verify (`123456`) → onboarding → nombre vacío muestra error → "Ana" → home del cliente; *Sign out* → login. Con un perfil `courier` preexistente → tras verificar va directo a `/courier/orders`. |

Test de integración contra Supabase local (tag `supabase`, como Centavo; crea `dart_test.yaml` con
`tags: {supabase: {}}` si no existe) — `test/integration/auth_roundtrip_test.dart`:
- Se salta si no existe la variable de entorno `RUTTA_IT=1` (`skip:` en el `group`).
- Usa `SupabaseClient('http://127.0.0.1:54321', '<publishable key de RUTTA_PUBLISHABLE_KEY>')` (sin `Supabase.initialize`).
- `sendCode` a un email nuevo aleatorio (`it-<timestamp>@rutta.test`) → lee el código de Mailpit
  (`GET http://127.0.0.1:54324/api/v1/messages` → el más reciente para ese email → `GET /api/v1/message/<ID>` →
  `RegExp(r'\b\d{6}\b')`) → `verifyCode` → `watchSession` emite `SessionNeedsProfile` → `ensureProfile('IT User')` →
  `SessionSignedIn` con rol `customer` → segunda llamada a `ensureProfile('Other')` devuelve `IT User` → `signOut`.
- Ejecútalo: `RUTTA_IT=1 RUTTA_PUBLISHABLE_KEY=<key> flutter test --tags supabase test/integration/`.

## Paso 6 · Verificación manual (emulador + Supabase local)

1. `flutter run --dart-define-from-file=.env.json`.
2. Email nuevo (`me@rutta.test`) → *Send code* → abre Mailpit (`http://127.0.0.1:54324`) → copia el código → *Verify* →
   onboarding → nombre → llega a `/customer/orders` (la lista mostrará error hasta la fase 11: esperado).
3. *Settings* → *Sign out* → login. Entra con `courier1@rutta.test` → va directo a `/courier/orders` (perfil del seed).
4. Código incorrecto → mensaje legible. Cierra y reabre la app con sesión → entra directo a su home (sesión persistente).
5. `flutter run` **sin** `.env.json` → el login muestra solo el demo.

## Paso 7 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] `Supabase.initialize` solo con backend configurado; sin `.env.json` la app ofrece solo el demo.
- [ ] `mapSupabaseError` + `guardSupabase` con tests de todos los casos (prefijos `RUTTA_*` antes que códigos).
- [ ] `SupabaseAuthRepository` (OTP, sesión con perfil, `ensure_profile`, sign out) y `MockAuthRepository`.
- [ ] Login, verificación (reenvío a los 60 s) y onboarding con carga, validación y errores legibles.
- [ ] Redirect por sesión/perfil/rol probado con el flujo completo; sesión persistente al reabrir.
- [ ] Test de integración contra Supabase local ejecutado (resultado anotado en la bitácora).
- [ ] Ids para Maestro: `login-email`, `login-send-code`, `verify-code`, `verify-submit`, `verify-resend`, `onboarding-name`, `onboarding-continue`, `settings-sign-out`, `settings-exit-demo`.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
