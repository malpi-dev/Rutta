# Fase 08 · Ubicación del repartidor

**Rama:** `feat/fase-08-ubicacion-repartidor`
**Objetivo:** el repartidor comparte su ubicación mientras tiene un pedido en curso y la app está en primer plano:
flujo de permisos completo con explicación previa, repositorio real con `geolocator`, `LocationPublisher` con
throttling (5 s / 10 m / latido 30 s, descarta precisión > 50 m), pausa manual y por ciclo de vida, pantalla encendida
con `wakelock_plus`, indicador "Sharing location" y marcador propio en el mapa.
**Referencias:** definición §3.1 F8, F9 · §5.1 flujos B y D · §6.3 reglas 3, 6 · §6.4 (`ShouldSendLocation`) ·
§8.4 (`LocationPublisher`) · §12.1 (detalle del repartidor: sin permiso, GPS apagado, denegado para siempre,
esperando GPS) · §17 (GPS en emulador).
**Requisitos previos:** fase 07 terminada.

> El cliente **nunca** pide permiso de ubicación. Sin permiso, el repartidor puede cambiar estados igualmente,
> pero ve un aviso de que el cliente no lo verá en el mapa.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Repositorio real (`lib/features/tracking/data/geolocator_device_location_repository.dart`)

Para poder testearlo sin plugin, el acceso a `geolocator` pasa por una fachada mínima en el mismo `data/`:

```dart
/// Thin wrapper over the static Geolocator API so the repository can be unit tested.
class GeolocatorApi {
  const GeolocatorApi();
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  Stream<Position> getPositionStream({required LocationSettings locationSettings}) =>
      Geolocator.getPositionStream(locationSettings: locationSettings);
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
```

`GeolocatorDeviceLocationRepository({GeolocatorApi api = const GeolocatorApi()})`:

| Método | Comportamiento |
|---|---|
| `checkAccess()` | servicio apagado → `serviceDisabled`; si no, `checkPermission()`: `whileInUse`/`always` → `granted`, `deniedForever` → `deniedForever`, `denied`/`unableToDetermine` → `denied`. |
| `requestAccess()` | servicio apagado → `serviceDisabled` (no pide nada); si no, `requestPermission()` con el mismo mapeo. |
| `watchPosition()` | `getPositionStream` con `AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 0, intervalDuration: const Duration(seconds: 2))` en Android y `LocationSettings(accuracy: LocationAccuracy.high)` en el resto (`defaultTargetPlatform`). Cada `Position` → `DevicePosition(point, timestamp: position.timestamp.toUtc(), heading: heading >= 0 ? heading : null, speedMps: speed >= 0 ? speed : null, accuracyMeters: accuracy)`. Errores: `PermissionDeniedException` → `LocationPermissionDeniedError(permanently: false)`, `LocationServiceDisabledException` → `LocationServiceDisabledError()`, cualquier otro → `UnknownError(e)` (usa `handleError` + rethrow tipado o un `StreamTransformer`). |
| `openAppSettings()` / `openLocationSettings()` | delegan; nunca lanzan (captura y descarta). |

**Sin** `ACCESS_BACKGROUND_LOCATION` ni foreground service (definición §3.2). Verifica los nombres de la API en la
versión instalada de `geolocator` (`~/.pub-cache/hosted/pub.dev/geolocator_android-*/`).

## Paso 2 · Qué implementación se usa

En `repository_providers.dart`:

```dart
@Riverpod(keepAlive: true)
DeviceLocationRepository deviceLocationRepository(Ref ref) => switch (ref.watch(appModeControllerProvider)) {
  AppModeDemo() when !Env.demoUsesRealGps => MockDeviceLocationRepository(ref.watch(demoStoreProvider)),
  _ => const GeolocatorDeviceLocationRepository(),
};
```

Añade a `Env`: `static const demoUsesRealGps = bool.fromEnvironment('DEMO_REAL_GPS');` — **solo para desarrollo**:
`flutter run --dart-define=DEMO_REAL_GPS=true` hace que el repartidor del demo use el GPS real del emulador, para
probar permisos y throttling antes de tener backend (ya anotado en la bitácora como herramienta de desarrollo).

Añade también `currentUserIdProvider` y `currentRoleProvider` al composition root:
- demo → `demoStore.currentUserId` y `AppModeDemo.role`;
- live → `SessionSignedIn.profile.id` / `.role` de `sessionStateProvider` (o `null` si no hay sesión).

## Paso 3 · Hoja de permisos (`lib/features/location_permission/presentation/location_permission_sheet.dart`)

```dart
/// Checks access and, when missing, explains why before the system dialog (F9). Returns the final access.
Future<LocationAccess> ensureLocationAccess(BuildContext context, WidgetRef ref);
```

1. `checkAccess()`; si es `granted` devuelve sin mostrar nada.
2. Si no, abre `showModalBottomSheet<LocationAccess>` con un `StatefulWidget` que muestra el contenido según el acceso
   actual y se actualiza al volver de ajustes (`AppLifecycleListener(onResume: recheck)`; si pasa a `granted`, se
   cierra solo devolviendo `granted`):

| Acceso | Título / cuerpo (l10n) | Botón principal | Secundario |
|---|---|---|---|
| `denied` | `permissionTitle` "Share your location" / `permissionBody` "Rutta shares your location with the customer only while a delivery is in progress and the app is open." | `permissionContinue` "Continue" (id `permission-continue`) → `requestAccess()`; si queda `granted` cierra; si no, muestra el nuevo estado | `notNow` "Not now" (id `permission-not-now`) |
| `deniedForever` | `permissionBlockedTitle` "Location is blocked" / `permissionBlockedBody` "Allow location for Rutta in the app settings so the customer can follow the delivery." | `openAppSettings` "Open app settings" (id `permission-open-settings`) | "Not now" |
| `serviceDisabled` | `locationOffTitle` "Location services are off" / `locationOffBody` "Turn on location so the customer can see where you are." | `openLocationSettings` "Open location settings" (id `permission-open-location-settings`) | "Not now" |

Ícono grande `location_on` (primary) o `location_off` (warning) arriba. "Not now" cierra devolviendo el acceso actual.

**Dónde se llama:** en `CourierActionButton` (fase 07), **antes** de ejecutar `pickUp` y `startDelivery`:
`await ensureLocationAccess(context, ref);` y después se ejecuta la acción **siempre**, haya permiso o no (F9).
En demo el mock devuelve `granted` y la hoja nunca aparece.

## Paso 4 · `LocationPublisher` (`lib/features/tracking/presentation/location_publisher.dart`)

La lógica vive en una clase Dart normal (fácil de probar con `fakeAsync`) y Riverpod solo la conecta.

### 4.1 Estado

```dart
enum SharingStatus { idle, waitingForFix, sharing, paused, blocked }

@freezed
abstract class LocationSharingState with _$LocationSharingState {
  const factory LocationSharingState({
    @Default(SharingStatus.idle) SharingStatus status,
    String? orderId,                    // active delivery being shared
    DevicePosition? lastPosition,       // latest GPS fix (drives the courier's own marker)
    DateTime? lastSentAt,
    LocationAccess? blockedBy,          // set when status == blocked
  }) = _LocationSharingState;
}
```

### 4.2 Motor

```dart
class LocationPublisherEngine {
  LocationPublisherEngine({
    required DeviceLocationRepository device,
    required TrackingRepository tracking,
    required ShouldSendLocation shouldSend,
    required Clock clock,
    required ScreenAwake screenAwake,
    required String courierId,
  });

  Stream<LocationSharingState> get states;    // broadcast, emits the current state on listen
  LocationSharingState get state;

  Future<void> setActiveOrder(Order? order);  // null or not in progress → stop everything
  void pause();                                // user toggle
  Future<void> resume();
  void onAppPaused();                          // AppLifecycleState.paused/hidden → stop GPS (foreground only)
  Future<void> onAppResumed();                 // re-check access and restart if needed
  Future<void> retryAccess();                  // after the permission sheet or settings
  void dispose();
}
```

Reglas:
1. `setActiveOrder(order)`: si `order == null || !order.status.isInProgress` → cancela la suscripción al GPS,
   `screenAwake.disable()`, estado `idle` (sin `orderId`). Si es el mismo pedido que ya se comparte, no hace nada.
2. Con pedido en curso (y no pausado por el usuario ni con la app en segundo plano): `checkAccess()`;
   si no es `granted` → estado `blocked` con `blockedBy`; si es `granted` → `screenAwake.enable()`, estado
   `waitingForFix`, se suscribe a `watchPosition()`.
3. Por cada `DevicePosition`: actualiza `lastPosition`; si
   `shouldSend(candidate: pos, nowUtc: clock.nowUtc(), lastSentPoint: …, lastSentAt: …)` → llama
   `tracking.publishLocation(CourierLocation(courierId, orderId, point, recordedAt: pos.timestamp, heading, speedMps, accuracyMeters))`;
   si tiene éxito guarda `lastSentAt`/`lastSentPoint` y estado `sharing`. Solo un envío en vuelo a la vez (si hay uno
   pendiente, se ignora la lectura).
4. Errores de `publishLocation`: `NetworkError`/`BackendUnavailableError` → se ignoran (se reintenta en la siguiente
   lectura que pase el filtro); `NoActiveOrderError` → el pedido terminó: se deja de enviar.
5. Errores del stream de GPS: `LocationPermissionDeniedError` → `blocked(denied)`;
   `LocationServiceDisabledError` → `blocked(serviceDisabled)`; se cancela la suscripción.
6. `pause()` → cancela GPS, estado `paused`, `screenAwake.disable()`. `resume()` → vuelve al punto 2.
7. `onAppPaused()` → cancela GPS (sin cambiar a `paused`: al volver se reanuda solo). `onAppResumed()` → punto 2 si
   hay pedido en curso y el usuario no pausó.
8. `dispose()` → cancela todo y `screenAwake.disable()`.

`lib/features/tracking/presentation/screen_awake.dart`:

```dart
// ignore: one_member_abstracts — tiny seam so tests don't call the wakelock plugin.
abstract interface class ScreenAwake { Future<void> enable(); Future<void> disable(); }
class WakelockScreenAwake implements ScreenAwake { /* WakelockPlus.enable() / disable(), errors swallowed */ }
```

### 4.3 Conexión con Riverpod

```dart
/// Courier only: the order currently in picked_up / in_transit, if any.
@riverpod
Order? activeDelivery(Ref ref) {
  if (ref.watch(currentRoleProvider) != UserRole.courier) return null;
  final orders = ref.watch(myOrdersProvider).value ?? const [];
  return orders.firstWhereOrNull((o) => o.status.isInProgress);
}

@Riverpod(keepAlive: true)
ScreenAwake screenAwake(Ref ref) => WakelockScreenAwake();

@Riverpod(keepAlive: true)
LocationPublisherEngine locationPublisher(Ref ref) {
  final engine = LocationPublisherEngine(
    device: ref.watch(deviceLocationRepositoryProvider),
    tracking: ref.watch(trackingRepositoryProvider),
    shouldSend: ref.watch(shouldSendLocationProvider),
    clock: ref.watch(clockProvider),
    screenAwake: ref.watch(screenAwakeProvider),
    courierId: ref.watch(currentUserIdProvider) ?? '',
  );
  final lifecycle = AppLifecycleListener(
    onPause: engine.onAppPaused,
    onHide: engine.onAppPaused,
    onResume: engine.onAppResumed,
  );
  ref
    ..listen(activeDeliveryProvider, (_, next) => engine.setActiveOrder(next))
    ..onDispose(() { lifecycle.dispose(); engine.dispose(); });
  engine.setActiveOrder(ref.read(activeDeliveryProvider));
  return engine;
}

@riverpod
Stream<LocationSharingState> locationSharingState(Ref ref) => ref.watch(locationPublisherProvider).states;
```

- Cambiar de modo (demo ↔ live) o de usuario reconstruye el motor (depende de repositorios e id).
- **Quién lo arranca:** `CourierOrdersScreen` y el detalle del repartidor hacen `ref.watch(locationPublisherProvider)`.
  Al ser `keepAlive`, sigue vivo al navegar entre ellas.
- Si `ref.read(activeDeliveryProvider)` todavía no tiene la lista (carga), el `listen` lo corrige al llegar.

## Paso 5 · UI del repartidor

### 5.1 Marcador propio y progreso

Crea `displayedCourierLocationProvider(String orderId, UserRole role)` en `tracking_providers.dart`:
- `customer` → `courierLocationProvider(orderId)` (lo que ya usaba la fase 06).
- `courier` → a partir de `locationSharingStateProvider`: si `state.orderId == orderId` y hay `lastPosition`, un
  `CourierLocation(courierId: yo, orderId, point, recordedAt: lastPosition.timestamp, heading, speedMps)`; si no, `null`.

Cambia `TrackingMap` y `routeProgressProvider` para usar este provider (así el repartidor ve su propio marcador
animado sobre la ruta, y su ETA/distancia en el panel cuando está `inTransit`).

### 5.2 Indicador `SharingIndicator` (`lib/features/tracking/presentation/sharing_indicator.dart`)

Debajo del botón principal, solo con pedido en curso (key e identifier del contenedor `sharing-indicator`):

| Estado | Contenido |
|---|---|
| `waitingForFix` | spinner pequeño + `gettingLocation` "Getting your location…" |
| `sharing` | punto verde (success) + `sharingLocation` "Sharing location" + `TextButton` `pause` "Pause" (id `sharing-toggle`) |
| `paused` | punto neutral + `sharingPaused` "Location sharing paused" + `TextButton` `resume` "Resume" (id `sharing-toggle`) |
| `blocked(denied)` | ícono `location_off` warning + `locationOffCustomerCantSee` "Location off — the customer can't see you" + `enable` "Enable" → `ensureLocationAccess` y luego `engine.retryAccess()` |
| `blocked(deniedForever)` | mismo aviso + "Open app settings" → `openAppSettings()` (al volver, `onAppResumed` re-evalúa) |
| `blocked(serviceDisabled)` | `locationOffTitle` + "Open location settings" → `openLocationSettings()` |
| `idle` | nada |

### 5.3 Al entregar

Al pasar a `delivered`, `activeDelivery` pasa a `null` → el motor deja de enviar y apaga el wakelock; la BD (fase 09)
o el `DemoStore` borran la última posición. El indicador desaparece.

## Paso 6 · Script para conducir el emulador (`tool/emulator_drive.dart`)

Herramienta de desarrollo para probar en el emulador con GPS "real":

```bash
dart run tool/emulator_drive.dart r2 --interval 2
```

- Lee `tool/routes/routes.json`, toma la ruta indicada, se queda con puntos separados ≥ 20 m y cada `--interval`
  segundos ejecuta `adb emu geo fix <lng> <lat>` (**ojo: longitud primero**). Opción `--serial <id>` para elegir
  emulador cuando hay varios (`adb -s <id> emu geo fix …`; se usa en la fase 11). Sale con código 1 si `adb` no está en el
  PATH o no hay emulador. Mensajes con `stdout.writeln`.
- Sirve con `DEMO_REAL_GPS=true` (esta fase) y con el backend real (fase 11).

## Paso 7 · Tests

| Archivo | Qué comprueba |
|---|---|
| `test/features/tracking/data/geolocator_device_location_repository_test.dart` | con un `GeolocatorApi` falso (mocktail): servicio apagado → `serviceDisabled` sin pedir permiso; cada `LocationPermission` → su `LocationAccess`; `Position` con `heading: -1`, `speed: -1` → `null`; `timestamp` en UTC; `PermissionDeniedException` en el stream → `LocationPermissionDeniedError`; `LocationServiceDisabledException` → `LocationServiceDisabledError`. |
| `test/features/location_permission/presentation/location_permission_sheet_test.dart` | `granted` → no muestra hoja; `denied` → texto y *Continue* llama a `requestAccess` y cierra con `granted` si se concede; si sigue `denied`, la hoja sigue abierta; `deniedForever` → *Open app settings* llama a `openAppSettings`; `serviceDisabled` → *Open location settings*; *Not now* devuelve el acceso actual. |
| `test/features/tracking/presentation/location_publisher_engine_test.dart` | con `fakeAsync`, repos falsos y `ScreenAwake` falso: sin pedido → `idle`, sin suscripción; pedido `inTransit` + permiso → `waitingForFix`, wakelock activado; lecturas cada 1 s moviéndose 20 m → envíos a los 0, 5, 10… s (no más de uno cada 5 s); quieto 35 s → latido a los 30 s; lectura con precisión 80 m descartada; `pause` detiene envíos y apaga el wakelock, `resume` los reanuda; `onAppPaused` cancela el GPS y `onAppResumed` lo reanuda; `denied` → `blocked(denied)` sin suscripción; error del stream de servicio → `blocked(serviceDisabled)`; `NetworkError` al publicar no detiene el motor; pedido `delivered` → `idle` y wakelock apagado. |
| `test/features/orders/presentation/courier_location_flow_test.dart` | detalle del repartidor con repo de dispositivo falso en `denied`: *Picked up* → aparece la hoja → *Not now* → el estado **sí** cambia a `pickedUp` y se ve "Location off — the customer can't see you"; con `granted`: indicador "Getting your location…" → "Sharing location" tras la primera lectura; *Pause* → "Location sharing paused"; en rol cliente nunca se llama a `checkAccess`. |

## Paso 8 · Verificación manual

1. **Demo normal** (mock): repartidor → RT-1043 → *Picked up* (sin hoja) → *Start delivery* → el marcador propio se
   mueve por la ruta, "Sharing location" visible, la pantalla no se apaga → *Mark as delivered* → el indicador desaparece.
2. **GPS real del emulador:** `flutter run --dart-define=DEMO_REAL_GPS=true`. Revoca el permiso
   (`adb shell pm revoke com.malpidev.rutta android.permission.ACCESS_FINE_LOCATION` y `…COARSE_LOCATION`) → repartidor
   → *Picked up* → la hoja explica → *Continue* → diálogo del sistema → *While using the app* → *Start delivery* →
   `dart run tool/emulator_drive.dart r2` en otra terminal → el marcador sigue la ruta.
   Prueba también: denegar dos veces (denegado para siempre → *Open app settings*) y apagar la ubicación del emulador
   (`adb shell cmd location set-location-enabled false` → aviso *Open location settings*; vuelve con `true`).
3. Pulsa *Home* durante la entrega y vuelve: el envío se reanuda solo.
Anota en la bitácora qué casos se probaron a mano.

## Paso 9 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] `GeolocatorDeviceLocationRepository` (+ fachada testeable) con mapeo de permisos, posiciones y errores tipados.
- [ ] Hoja de permisos con explicación previa y los casos concedido / denegado / denegado para siempre / GPS apagado.
- [ ] `LocationPublisherEngine` con throttling 5 s / 10 m / latido 30 s, precisión > 50 m descartada, pausa manual y por ciclo de vida, wakelock.
- [ ] Indicador de compartir con todos sus estados; el repartidor puede cambiar estados sin permiso (con aviso).
- [ ] Marcador propio del repartidor animado sobre la ruta; el cliente nunca pide permiso.
- [ ] `tool/emulator_drive.dart` y `DEMO_REAL_GPS` documentados; casos probados a mano anotados.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
