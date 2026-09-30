# Rutta — Bitácora de implementación

> Documento vivo. Se actualiza **al empezar** y **al terminar** cada fase (ver `00-guia-general.md` §3 y §5).
> Todo en español; el código, la UI y los commits, en inglés.

## Avance

`█████████░░░░░` 9/14 fases terminadas (64 %)

**Fase actual:** ninguna — la siguiente es la Fase 10 · Auth
**Última actualización:** 2026-09-30
**Ventana planificada:** semana 2 (5 – 11 oct 2026), en paralelo con Vitrina; MVP listo antes del 11 oct.

## Estado por fase

| # | Fase | Rama | Estado | Inicio | Fin |
|---|---|---|---|---|---|
| 01 | Andamiaje | `feat/fase-01-andamiaje` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 02 | Core | `feat/fase-02-core` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 03 | Dominio | `feat/fase-03-dominio` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 04 | Mapa y rutas | `feat/fase-04-mapa-y-rutas` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 05 | Modo demo | `feat/fase-05-modo-demo` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 06 | Seguimiento del cliente | `feat/fase-06-seguimiento-cliente` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 07 | Entregas del repartidor | `feat/fase-07-entregas-repartidor` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 08 | Ubicación del repartidor | `feat/fase-08-ubicacion-repartidor` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 09 | Backend Supabase | `feat/fase-09-backend-supabase` | ✅ Terminada | 2026-09-30 | 2026-09-30 |
| 10 | Auth | `feat/fase-10-auth` | ⏳ Pendiente | — | — |
| 11 | Supabase y Realtime | `feat/fase-11-supabase-y-realtime` | ⏳ Pendiente | — | — |
| 12 | Ajustes e identidad | `feat/fase-12-ajustes-e-identidad` | ⏳ Pendiente | — | — |
| 13 | Pulido y E2E | `feat/fase-13-pulido-y-e2e` | ⏳ Pendiente | — | — |
| 14 | Lanzamiento | `feat/fase-14-lanzamiento` | ⏳ Pendiente | — | — |

Estados: ⏳ Pendiente · 🚧 En progreso · ✅ Terminada · ⛔ Bloqueada

## Versiones clave instaladas

> Se completa en la fase 01 (lee `pubspec.lock`, `flutter --version`, `supabase --version`) y se actualiza si cambia algo.
> Referencia de Centavo (2026-09-29): Flutter 3.44.6 / Dart 3.12.2, Riverpod 3.4.3, riverpod_generator 4.0.9,
> go_router 17.5.0, freezed 4.0.0-dev.3, supabase_flutter 2.17.2, very_good_analysis 10.3.0, Supabase CLI 2.118.0.

| Paquete / herramienta | Versión |
|---|---|
| Flutter / Dart | 3.44.6 / 3.12.2 |
| flutter_riverpod / riverpod_generator | 3.4.3 / 4.0.9 |
| go_router | 17.5.0 |
| freezed / freezed_annotation | 4.0.0-dev.3 / 3.1.0 |
| supabase_flutter | 2.18.0 |
| flutter_map / latlong2 | 8.3.2 / 0.10.1 |
| geolocator | 14.0.1 |
| wakelock_plus | 1.8.1 |
| very_good_analysis | 10.3.0 |
| Supabase CLI | 2.118.0 |
| Maestro | 2.10.0 |

## Registro

> Una entrada por fase terminada (la más reciente arriba). Plantilla:
>
> ### Fase NN · Nombre — AAAA-MM-DD
> - **Hecho:** qué se implementó (breve, en viñetas).
> - **Verificación:** comandos ejecutados, número de tests, qué se probó a mano y en qué dispositivo.
> - **PR:** enlace o número.
> - **Decisiones:** qué se decidió y por qué (también va a la tabla de abajo si cambia la definición o el plan).
> - **Pendientes:** lo que quedó para otra fase (con el número de fase destino).

### Fase 09 · Backend Supabase — 2026-09-30
- **Hecho:** `supabase/config.toml` (schema `rutta` expuesto, OTP de 6 dígitos, plantilla `otp.html` con `{{ .Token }}`, Realtime, seed); migración `20261005000000_rutta_init.sql` (4 tablas, índice de un pedido en curso por repartidor, `my_role`, `is_valid_transition`, triggers de guarda/historial/borrado de ubicación/hora del servidor, RPCs `ensure_profile`, `advance_order_status`, `admin_assign_order`, grants por columna, RLS con las 10 políticas comentadas, publicación de Realtime); `seed.sql` (3 usuarios, 8 pedidos, 25 eventos, 2 ubicaciones, rutas reales rellenadas con `fetch_routes.dart --from-cache`); `scripts/create_sample_orders.sql`; tests pgTAP `rls_test.sql` (29) y `business_test.sql` (25); job `database` en CI; `.env.json` local (fuera de git).
- **Verificación:** `./tool/check.sh` en verde (234 tests); `supabase db reset` sin errores (8 pedidos, 25 eventos, 2 ubicaciones); `supabase test db` en verde (54 tests); `create_sample_orders.sql` ejecutado dos veces seguidas sin error; `curl` con la publishable key contra `rutta.orders` responde `42501 permission denied` (sin datos). Se detuvieron los contenedores de Agendo y Centavo con `supabase stop --project-id` (sin borrar datos).
- **PR:** ver historial de `main` (squash de `feat/fase-09-backend-supabase`).
- **Decisiones:** dos políticas de `courier_locations` (`locations_insert_courier` y `locations_update_courier`) en lugar de la única `locations_upsert_courier` de §7.2 (cada política es de un solo comando); no se crea `is_order_customer()` (las políticas usan `exists` sobre `orders`, sin recursión); en el seed y el script los eventos `assigned` llevan `changed_by = null` (lo asigna admin) y solo picked_up/in_transit/delivered llevan al repartidor; los tests que comprueban el CHECK de estado inserta la fila directamente (un `update` con estado inválido lo intercepta antes el trigger de guarda con `RUTTA_INVALID_TRANSITION`); en el job de CI se usa `actions/checkout@v7` (igual que el job de Flutter). `supabase init` no se ejecutó: `config.toml` parte del de Centavo con `project_id = "rutta"`.
- **Pendientes:** el job `database` de CI solo se valida al abrir el PR; aplicar en remoto en la fase 14.

### Fase 08 · Ubicación del repartidor — 2026-09-30
- **Hecho:** `GeolocatorApi` + `GeolocatorDeviceLocationRepository` (permisos, posiciones UTC, errores tipados); `Env.demoUsesRealGps` (`DEMO_REAL_GPS`); `currentUserIdProvider`/`currentRoleProvider` y selección del repositorio de dispositivo por modo; `ensureLocationAccess` + hoja de permisos (denied / deniedForever / serviceDisabled, recheck al volver de ajustes); `LocationPublisherEngine` (throttling vía `ShouldSendLocation`, pausa manual y por ciclo de vida, wakelock, errores) + `LocationSharingState`, `ScreenAwake`, providers (`activeDelivery`, `locationPublisher`, `locationSharingState`); `SharingIndicator` con todos sus estados; `displayedCourierLocationProvider` y `routeProgressProvider(orderId, role)` (marcador propio y ETA del repartidor); `tool/emulator_drive.dart`; textos l10n; tests de los 4 archivos del paso 7.
- **Verificación:** `./tool/check.sh` en verde (234 tests). A mano en emulador Pixel_10_Pro con `DEMO_REAL_GPS=true`: permiso revocado, *Picked up* -> hoja -> *Continue* -> diálogo del sistema -> *While using the app*; *Start delivery* + `emulator_drive.dart r2`: marcador propio sobre la ruta, ETA/distancia, "Sharing location"; *Home* y volver (el envío sigue); ubicación del emulador apagada -> aviso "Location services are off / Open location settings". No probados a mano: denegado para siempre (dos denegaciones), *Pause* en dispositivo (cubierto por tests), *Mark as delivered* con GPS real.
- **PR:** ver historial de `main` (squash de `feat/fase-08-ubicacion-repartidor`).
- **Decisiones:** el motor no espera el `cancel()` de la suscripción del GPS (un stream de plataforma puede tardar y bloquear el cambio de estado); `NoActiveOrderError` marca el pedido como terminado para no reintentar; la hoja de permisos se cierra una sola vez (`_closed`): sin eso, el `pop` del diálogo del sistema y el de `onResume` cerraban también la pantalla de detalle (bug encontrado en el emulador); `ensureLocationAccess` devuelve `denied` si `checkAccess` lanza, para no bloquear la acción del repartidor; la ETA del repartidor aparece en `inTransit` cuando llega su primer fix (antes muestra `courierHeadToDropoff`); `screenOverrides` de los tests ahora incluye un repositorio de dispositivo mock.
- **Pendientes:** verificación manual del caso "denegado para siempre" y de *Mark as delivered* con GPS real (fase 13 o cuando el autor pueda).

### Fase 07 · Entregas del repartidor — 2026-09-30
- **Hecho:** `CourierOrdersScreen` definitiva (In progress / Assigned / Completed, nombre del cliente, pull-to-refresh, carga/vacío/error, `settings-open`); `OrderActionController` (`AsyncValue.guard`); `CourierActionButton` (botón `order-action-primary`, spinner sin doble pulsación, bloqueo `courierBusy` con texto de ayuda, diálogo de confirmación `confirm-delivered`, SnackBar de errores tipados); variante courier de `TrackingPanel` (línea de contexto por estado, fila "Customer", sin "Your courier"/"Last updated"); `TrackingMap` no observa la ubicación cuando el rol es courier; textos l10n; tests de lista, controlador y detalle del repartidor.
- **Verificación:** `./tool/check.sh` en verde (196 tests). **No** se hizo la verificación manual en emulador del paso 6 (solo tests de widgets); queda pendiente para la fase 13 o cuando el autor la haga.
- **PR:** ver historial de `main` (squash de `feat/fase-07-entregas-repartidor`).
- **Decisiones:** el `ref.listen` de errores vive en `CourierActionButton` (en vez de en la pantalla) para no acoplar el detalle; clave l10n extra `courierHeadToDropoff` para `inTransit` del repartidor (el ETA/distancia llega con su posición en la fase 08); `OrderStatusHeadline` recibe `role` (por defecto customer); `_CourierRow` pasó a `_PersonRow` (etiqueta configurable); la ubicación simulada no se muestra al repartidor porque `TrackingMap` solo se suscribe en rol customer.
- **Pendientes:** posición propia, ETA y marcador del repartidor (fase 08); verificación manual en emulador.

### Fase 06 · Seguimiento del cliente — 2026-09-30
- **Hecho:** eliminada la vista previa de desarrollo (pantalla, ruta `/dev/map`, botón y texto l10n); providers `order`, `orderEvents`, `isConnected`, `courierLocation`, `now`, `routeProgress` e `isCourierLocationStale`; widgets `OrderStatusChip`, `OrderCard`, `SectionHeader`, `StatusTimeline`, `ReconnectingBanner`, `statusLabel`; lista del cliente (Active/History, pull-to-refresh, carga/vacío/error); `OrderDetailScreen` con `TrackingMap` (marcador animado sobre la ruta, ruta recorrida/restante, recentrar), `TrackingPanel` (estado, ETA, distancia, aviso stale, repartidor, direcciones, ítems, total, línea de tiempo) y `OrderDetailSkeleton`; ids `order-card-<code>`, `order-status-headline`, `tracking-eta`, `tracking-recenter`, `settings-open`; tests del paso 8.
- **Verificación:** `./tool/check.sh` en verde (184 tests). A mano en emulador Pixel_10_Pro, demo como cliente: lista, detalle de RT-1042 con recorrido completo (~1 min) en claro y oscuro, ETA/distancia bajando, *Delivered* al final con el pin desaparecido. No se grabó `screenrecord` (se revisaron capturas separadas); la fluidez de la animación no se midió en vídeo.
- **PR:** ver historial de `main` (squash de `feat/fase-06-seguimiento-cliente`).
- **Decisiones:** la fila de progreso usa dos textos (`tracking-eta` y `tracking-distance` con `distanceLeft` "{distance} left") en vez de `etaAndDistance`; se reutiliza `ordersEmptyTitle` en lugar de `noOrdersTitle`; `isCourierLocationStaleProvider` (bool) evita reconstruir el mapa cada segundo; la ruta recorrida se divide en la proyección sobre la ruta cuando el repartidor está fuera de ruta; la ubicación solo se observa si el pedido está en curso. En tests las pantallas altas (`physicalSize`) evitan que el `ListView` perezoso omita elementos (se ajustó `demo_flow_test`).
- **Pendientes:** variante del repartidor del detalle (fase 07); el botón recentrar no persigue automáticamente al repartidor (según la fase); cuando el marcador sale de la vista el usuario debe pulsar recentrar.

### Fase 05 · Modo demo — 2026-09-30
- **Hecho:** `DemoUsers` + `buildDemoWorld` (6 pedidos con rutas reales; Alex 5, Carlos 3); `DemoCourierSimulator`; `DemoStore` (reglas de `advance` iguales a la RPC, simulación del repartidor del cliente, `dispose`); `watchStore` (helper de streams con latencia); `MockOrdersRepository`, `MockTrackingRepository`, `MockDeviceLocationRepository`, `MockConnectionMonitor`; providers `demoStore`, repositorios por `AppMode` (live provisional con `UnimplementedError`) y casos de uso; selector de rol, botón `login-explore-demo`, `DemoBanner` en `RuttaApp`; listas provisionales con `myOrdersProvider`; textos l10n; tests del paso 7.
- **Verificación:** `./tool/check.sh` en verde (167 tests). A mano en emulador Pixel_10_Pro **en modo avión**: login, *Explore demo*, cliente (5 pedidos, banner), *Exit demo*, repartidor (3 pedidos).
- **PR:** ver historial de `main` (squash de `feat/fase-05-modo-demo`).
- **Decisiones:** `fake_async` añadido a `dev_dependencies` (lint `depend_on_referenced_packages`); `DemoStore.addOrder` (`@visibleForTesting`) para el test de `CourierBusyError`; en `MockDeviceLocationRepository.onCancel` se detienen primero los timers y luego se cancela la suscripción (si no, quedaba un timer pendiente); `ignore: cancel_subscriptions` justificado (se cancela en `stopCurrent`); clave l10n extra `ordersEmptyTitle` para el estado vacío de las listas provisionales.
- **Pendientes:** las listas y el detalle definitivos llegan en las fases 06 y 07.

### Fase 04 · Mapa y rutas — 2026-09-30
- **Hecho:** `MapMarker`/`MapPolyline`, `RuttaMap`/`RuttaMapController`/`RuttaMapProps`, `ruttaMapBuilderProvider`, `FlutterMapRuttaMap` (User-Agent, atribución enlazada, `darkModeTileBuilder`, aviso "Map unavailable" tras 3 errores de tiles), `lat_lng_mapper`; `PlacePin`/`PickupPin`/`DropoffPin`/`CourierPin`; `DemoRoute`; `tool/fetch_routes.dart` ejecutado (6 rutas OSRM: 2362, 3730, 2682, 3268, 2066 y 2910 m, todas dentro de 1500-4000) con `tool/routes/routes.json` y `demo_routes.dart`; `DevMapPreviewScreen` en `/dev/map` (solo debug) con botón en el login; `FakeRuttaMap` añadido a `testOverrides()`; tests del paso 7.
- **Verificación:** `./tool/check.sh` en verde (142 tests). A mano en emulador Pixel_10_Pro: mapa claro (pines, ruta, repartidor), oscuro (filtro legible) y modo avión (aviso "Map unavailable", fondo neutro, pantalla usable).
- **PR:** ver historial de `main` (squash de `feat/fase-04-mapa-y-rutas`).
- **Decisiones:** `Routes.devMap` se excluye en `appRedirect` (si no, sin sesión redirigía al login); se añadieron `AppColors.markerContent`/`markerShadow` para no usar `Colors.white` fuera del tema; `PickupPin`/`DropoffPin` son envoltorios sobre `PlacePin`; `MapOptions` usa `initialCenter` cuando hay un solo punto; ignore justificado de `use_setters_to_change_properties` en `attach`. API de flutter_map 8.3.2 coincide con la fase. Sin capturas commiteadas.
- **Pendientes:** el archivo SQL de rutas se rellena en la fase 09 (`--from-cache`); `DevMapPreviewScreen` se borró en la fase 06.

### Fase 03 · Dominio — 2026-09-30
- **Hecho:** `GeoPoint` y `geo.dart` (haversine, rumbo, longitud, `projectOntoRoute`, `pointAlongRoute`, `splitRoute`); `OrderStatus` con tabla de transiciones; entidades freezed `Place`, `OrderItem`, `Order`, `OrderStatusEvent`, `CourierLocation`, `DevicePosition`, `RouteProgress` (+ `LocationAccess`); puertos `OrdersRepository`, `ConnectionMonitor`, `TrackingRepository`, `DeviceLocationRepository`, `AuthRepository`; casos de uso `AvailableOrderActions`, `ComputeRouteProgress`, `ShouldSendLocation`; `buildOrderTimeline`; validadores de auth; `test/helpers/builders.dart`.
- **Verificación:** `./tool/check.sh` en verde (chequeo de arquitectura, analyze sin issues, 129 tests incluyendo las 36 combinaciones de transiciones).
- **PR:** ver historial de `main` (squash de `feat/fase-03-dominio`).
- **Decisiones:** `pointAlongRoute` también lanza `ArgumentError` con menos de 2 puntos (igual que `projectOntoRoute`); `remainingMeters` se redondea a 0 con `max` y se convierte a `double`; en `_happyPath` se anotó el tipo por el lint `specify_nonobvious_property_types`. Sin desviaciones del plan.
- **Pendientes:** ninguno.

### Fase 02 · Core — 2026-09-30
- **Hecho:** `Clock`/`SystemClock`/`FixedClock`, `UserRole`, `AppMode`; `DomainError` sellado; `Env`; tema claro/oscuro (`AppColors`, `RuttaColors`, `AppTheme`) con Manrope + Inter (copiadas de Centavo) y licencias registradas; `ThemePreference` + `SettingsRepository` (`prefs_` e `in_memory_`) + `ThemeController`; providers base (`clock`, `sharedPreferences`, `settingsRepository`, `AppModeController`, `noAutomaticRetry`); `UserProfile`, `SessionState` y `sessionStateProvider` provisional; l10n (errores, validación, comunes); `errorMessage` exhaustivo; formatters; widgets comunes (`AsyncStateView`, `EmptyState`, `ErrorState`, `SkeletonList`, `rootScaffoldMessengerKey`); router con `appRedirect` puro, `StartupScreen` y pantallas provisionales; `app.dart`/`main.dart`; helpers y tests.
- **Verificación:** `./tool/check.sh` en verde (37 tests: dominio, formatters, mensajes de error, 16 casos de redirect, prefs, `AsyncStateView`, smoke). No se probó a mano en emulador (modo oscuro cubierto solo por el tema en tests).
- **PR:** ver historial de `main` (squash de `feat/fase-02-core`).
- **Decisiones:** `formatMoneyCents` usa `NumberFormat.currency(symbol: r'MX$')` porque `simpleCurrency(name: 'MXN')` en `en_US` da `$245.00`, no `MX$245.00`; `formatTime` reemplaza el espacio estrecho (U+202F) que ICU pone antes de AM/PM por un espacio normal; `SkeletonList` recibe `itemCount`/`itemHeight` (3 y 96 por defecto) según la fase; los tipos `Override` vienen de `flutter_riverpod/misc.dart`.
- **Pendientes:** verificación manual del modo oscuro en emulador (paso 15) queda para la fase 13 (pulido).

### Fase 01 · Andamiaje — 2026-09-30
- **Hecho:** `flutter create` (com.malpidev.rutta, android+ios), dependencias, lints VGA, build.yaml, l10n, permisos Android (INTERNET, FINE/COARSE; cleartext solo en debug) e iOS, estructura de carpetas, `.env.example(.json)`, `.gitignore`, `tool/check.sh` y `check_architecture.sh`, app mínima + test de humo, `CLAUDE.md` y `README.md`, CI.
- **Verificación:** `./tool/check.sh` en verde (1 test); `flutter build apk --debug` OK; app ejecutada en el emulador Pixel_10_Pro mostrando "Rutta" (captura por adb).
- **PR:** ver historial de `main` (squash de `feat/fase-01-andamiaje`).
- **Decisiones:** `freezed ^4.0.0-dev.3` (igual que Centavo); `minSdk` = `flutter.minSdkVersion` = 24 (≥ 23, sin cambios); `flutter_lints` eliminado; actions/checkout@v7 como en Centavo; `flutter gen-l10n` genera en `lib/l10n/`.
- **Pendientes:** ninguno.

## Decisiones y desviaciones respecto a la definición

| Fecha | Fase | Decisión / desviación | Motivo |
|---|---|---|---|
| 2026-09-30 | Plan | El perfil se crea **solo** con la RPC `rutta.ensure_profile(p_full_name)` llamada desde la app tras el onboarding. **No** hay trigger al registrarse (la §2 de la definición lo menciona por error). | Convención del `CLAUDE.md` del portafolio: `auth.users` es compartido; un trigger crearía perfiles en todas las apps. La §7.3 de la definición ya lo dice así. |
| 2026-09-30 | Plan | La función auxiliar `rutta.current_role()` se llama **`rutta.my_role()`**. | `current_role` es una palabra reservada de SQL (`CURRENT_ROLE`); da errores de parseo o ambigüedad. |
| 2026-09-30 | Plan | `profiles_update_own` solo compara `id = auth.uid()`; el cambio de `role` se impide con **privilegios por columna**: `grant update (full_name, phone) on rutta.profiles to authenticated`. | Más simple y robusto que comparar el rol en el `with check` (mismo patrón que Centavo). |
| 2026-09-30 | Plan | `AuthRepository.watchSession()` devuelve `Stream<SessionState>` (`SessionSignedOut`, `SessionNeedsProfile(email)`, `SessionSignedIn(profile, email)`) en lugar de `watchCurrentUser(): Stream<UserProfile?>` + `getMyProfile()`. `verifyCode` usa parámetros nombrados. | El router necesita distinguir "sin sesión" de "con sesión pero sin perfil de Rutta" (usuario que viene de otra app del portafolio). |
| 2026-09-30 | Plan | Se añade la entidad `DevicePosition` (`point`, `heading?`, `speedMps?`, `accuracyMeters?`, `timestamp`). `DeviceLocationRepository.watchPosition()` devuelve `Stream<DevicePosition>`. | La §6.5 pide "GeoPoint con heading/speed/accuracy", pero `GeoPoint` es solo lat/lng. |
| 2026-09-30 | Plan | Se añade la interfaz `ConnectionMonitor` (`Stream<bool> watchIsConnected()`) en `orders/domain`, con `SupabaseConnectionMonitor` y `MockConnectionMonitor`. | La §8.4 pide un banner "Reconnecting…"; sin un puerto propio la UI tendría que conocer Realtime. |
| 2026-09-30 | Plan | Funciones puras adicionales en el dominio (con tests): `buildOrderTimeline` (orders), `pointAlongRoute`, `splitRoute`, `bearingBetween` y `routeLengthMeters` (tracking/geo). | Son lógica real que usan la línea de tiempo y el marcador animado sobre la ruta (§6.4, §8.4). |
| 2026-09-30 | Plan | `Order` gana `customerName?` (el repartidor ve el nombre del cliente). `Place.name` es opcional: el destino no tiene nombre en la BD (solo `dropoff_address`). | §2 (el repartidor ve el perfil del cliente) y §7.1 (tabla `orders`). |
| 2026-09-30 | Plan | `courier_locations.recorded_at` lo fija un trigger con la hora del servidor (`now()`) en cada insert/update; el cliente no lo envía. | En un upsert el `default now()` no se aplica al `update`; y la hora del servidor evita relojes de teléfono desfasados. |
| 2026-09-30 | Plan | Las RPCs lanzan `raise exception` con mensajes de prefijo fijo: `RUTTA_UNAUTHORIZED`, `RUTTA_NOT_FOUND`, `RUTTA_NOT_ASSIGNED`, `RUTTA_NOT_COURIER`, `RUTTA_COURIER_BUSY`, `RUTTA_INVALID_NAME` y `RUTTA_INVALID_TRANSITION from=<a> to=<b>`. El mapper de Dart decide por prefijo del mensaje **antes** que por `code`. | Mapeo determinista (§6.6). |
| 2026-09-30 | Plan | `advance_order_status` solo acepta las 3 transiciones del repartidor (`assigned→picked_up→in_transit→delivered`); asignar y cancelar quedan para admin/SQL. `rutta.is_valid_transition` contiene las 6 transiciones de §6.2. | §6.2: tabla "Quién". |
| 2026-09-30 | Plan | Moneda de los pedidos: **MXN** (datos en CDMX). Se formatea con `NumberFormat.simpleCurrency(locale: 'en_US', name: 'MXN')` → `MX$245.00`. | La definición no fija moneda; CDMX es la ciudad decidida. |
| 2026-09-30 | Plan | Textos de UI con `flutter_localizations` + `app_en.arb` (solo inglés). Dependencias añadidas a §9: `flutter_localizations`, `collection`, `meta`, `url_launcher` (enlace de atribución OSM/créditos) y, en la fase 10, `http` (para reconocer `http.ClientException`). | Mismo patrón que Centavo; la política de OSM pide enlazar la atribución; lint `depend_on_referenced_packages`. |
| 2026-09-30 | Plan | La ruta `/` muestra `StartupScreen` (cargando la sesión o error con *Retry*) en vez de ser solo un redirect. | Mientras se lee la sesión/perfil la app necesita una pantalla (nada de pantallas en blanco). |
| 2026-09-30 | Plan | Mundo del demo: cliente **Alex Rivera** (`demo-customer`), repartidores **Carlos Méndez** (`demo-courier`, el que usa quien explora como repartidor) y **María López** (`demo-courier-2`), y otro cliente **Jordan Lee** (`demo-customer-2`). Pedidos: RT-1042 (Alex, María, `in_transit`, simulado), RT-1043 (Alex, Carlos, `assigned`), RT-1038 y RT-1035 (`delivered`), RT-1031 (`cancelled`), RT-1029 (Jordan, Carlos, `delivered`). | Un único mundo coherente: Alex tiene 5 pedidos y Carlos 3, como pide §12.2, y el pedido que entrega Carlos en el demo es de Alex. |
| 2026-09-30 | Plan | Simulador del demo: recorrido de ~60 s por ruta (velocidad = longitud/60 s, ±10 % con `Random` con semilla), un punto por segundo, velocidad **reportada** 8.3 m/s (30 km/h) para que la ETA sea realista. En el pedido del cliente empieza al 15 % de la ruta. | §8.3 (simulación acelerada) sin que la ETA diga "1 min" para 3 km. |
| 2026-09-30 | Plan | Todos los mocks comparten un `DemoStore` en memoria (pedidos, eventos, ubicaciones y simulaciones), que se crea al entrar al demo y se descarta al salir. | Un cambio de estado hecho por un mock se ve en los demás (lista, detalle, ubicación), igual que con Realtime. |
| 2026-09-30 | Plan | Rutas reales generadas por `tool/fetch_routes.dart` en `lib/features/orders/data/demo_routes.dart` (Dart commiteado, **no** `.g.dart`) y en bloques marcados de `supabase/seed.sql` y `supabase/scripts/create_sample_orders.sql`. | Una sola fuente de verdad para fixtures, seed y script remoto; los `.g.dart` están ignorados por git. |
| 2026-09-30 | Plan | El trigger de guarda de estados (`orders_guard_status`) actúa solo en `update`. El seed inserta pedidos directamente en su estado final y luego reescribe su historial de eventos con horas coherentes. | El seed necesita pedidos en todos los estados con historia realista. |
| 2026-09-30 | Plan | Variables de entorno: `.env.example` (comentado, exigido por el `CLAUDE.md`) **y** `.env.example.json` (plantilla lista para copiar a `.env.json`). | `--dart-define-from-file` necesita JSON, que no admite comentarios. |
| 2026-09-30 | Plan | Decisiones abiertas de §17 resueltas: mapa oscuro con `darkModeTileBuilder` sobre OSM (sin API key); firma con keystore propio con respaldo a la clave debug si no existe (igual que Centavo); código generado **no** se commitea; Maestro **no** corre en CI. | Propuestas de la propia definición y del precedente de Centavo. |
| 2026-09-30 | Plan | Scripts de desarrollo (no se usan en la app ni en CI): `tool/emulator_drive.dart` (GPS del emulador por la ruta, fase 08), el flag `--dart-define=DEMO_REAL_GPS=true` (el repartidor del demo usa el GPS real, fase 08), `tool/simulate_courier.sh` (mueve a un repartidor en Supabase local con `psql`, fase 11) y `tool/get_otp.sh` (código OTP de cuentas de prueba en remoto con la secret key, fase 14). | Permiten probar el tracking en vivo con un solo emulador y crear cuentas de prueba sin SMTP propio. |
| 2026-09-30 | 09 | Dos políticas de `courier_locations` (`locations_insert_courier`, `locations_update_courier`) en vez de `locations_upsert_courier`; no existe `is_order_customer()`. | Una política por comando en Postgres; `exists` sobre `orders` evita recursión. |

## Bloqueos

_Ninguno._

## Ideas para el roadmap (fuera del MVP)

_Anotar aquí; luego pasan a la sección "Roadmap" del README._
