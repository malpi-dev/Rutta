# Fase 03 · Dominio

**Rama:** `feat/fase-03-dominio`
**Objetivo:** todo el dominio en Dart puro y con tests: `GeoPoint` y geometría, entidades de pedidos y tracking,
máquina de estados `OrderStatus`, interfaces de repositorio y los casos de uso con lógica real
(`ComputeRouteProgress`, `ShouldSendLocation`, `AvailableOrderActions`) más la línea de tiempo.
**Referencias:** definición §6 completo, §13 (tests de dominio) · bitácora (decisiones `SessionState`, `DevicePosition`,
`ConnectionMonitor`, funciones de geometría, `customerName`, `Place.name` opcional).
**Requisitos previos:** fase 02 terminada.

> Esta fase no toca la UI. Todo lo que se crea aquí vive en carpetas `domain/` (o `core/domain/`) y el chequeo de
> arquitectura debe seguir pasando: **nada** de Flutter, Riverpod, Supabase, `latlong2` ni `intl`.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Geometría (`lib/core/domain/`)

`GeoPoint` vive en `core/` (y no en una feature) porque también lo usa la abstracción del mapa (`core/map/`, fase 04).

### 1.1 `geo_point.dart`

```dart
@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng);   // assert lat in -90..90 and lng in -180..180
  final double lat;
  final double lng;
  // ==, hashCode, toString: 'GeoPoint(19.41932, -99.16235)'
}
```

### 1.2 `geo.dart` — funciones puras

```dart
const earthRadiusMeters = 6371000.0;

/// Great-circle distance in meters.
double haversineMeters(GeoPoint a, GeoPoint b);

/// Initial bearing from a to b in degrees, 0..360 (0 = north, 90 = east).
double bearingDegrees(GeoPoint a, GeoPoint b);

/// Sum of the haversine lengths of every segment. 0 for fewer than 2 points.
double routeLengthMeters(List<GeoPoint> route);

@immutable
class RouteProjection {
  const RouteProjection({required this.snappedPoint, required this.segmentIndex,
      required this.distanceToRouteMeters, required this.traveledMeters});
  final GeoPoint snappedPoint;       // closest point on the polyline
  final int segmentIndex;            // segment i goes from route[i] to route[i + 1]
  final double distanceToRouteMeters;
  final double traveledMeters;       // along the route from route[0] to snappedPoint
}

/// Projects [point] on the closest segment of [route] (>= 2 points, otherwise ArgumentError).
RouteProjection projectOntoRoute(List<GeoPoint> route, GeoPoint point);

/// Point located [meters] along [route] (clamped to 0..length) and the segment it falls in.
({GeoPoint point, int segmentIndex}) pointAlongRoute(List<GeoPoint> route, double meters);

/// Splits [route] at [snappedPoint], which lies on segment [segmentIndex].
/// traveled = route[0..segmentIndex] + snappedPoint; remaining = snappedPoint + route[segmentIndex+1..].
({List<GeoPoint> traveled, List<GeoPoint> remaining}) splitRoute(
    List<GeoPoint> route, int segmentIndex, GeoPoint snappedPoint);
```

Algoritmo de `projectOntoRoute` (distancias cortas, basta una proyección equirectangular local):

1. Para cada segmento `a = route[i]`, `b = route[i + 1]`, convierte a coordenadas planas alrededor de la latitud del
   punto: `x = lng * cos(lat0 * π / 180)`, `y = lat` (en grados; la escala no importa para `t`).
2. `t = ((p − a) · (b − a)) / |b − a|²`, limitado a `[0, 1]` (si `|b − a| = 0`, `t = 0`).
3. `closest = a + t (b − a)` (interpolando lat y lng); `d = haversineMeters(point, closest)`.
4. Gana el segmento de menor `d` (empate: el de menor índice).
5. `traveledMeters = suma de longitudes de los segmentos 0..i−1 + haversineMeters(route[i], closest)`.

Algoritmo de `pointAlongRoute`: recorre segmentos acumulando longitud; en el segmento donde se supera `meters`,
interpola linealmente lat/lng con la fracción restante. `meters <= 0` → `route.first` (segmento 0);
`meters >= longitud` → `route.last` (último segmento).

## Paso 2 · Pedidos (`lib/features/orders/domain/`)

### 2.1 `order_status.dart` — máquina de estados (§6.2)

```dart
enum OrderStatus {
  created('created'),
  assigned('assigned'),
  pickedUp('picked_up'),
  inTransit('in_transit'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.wireName);
  final String wireName;

  static OrderStatus fromWire(String value);      // FormatException for unknown values

  /// Same table as rutta.is_valid_transition in SQL (the source of truth). Tests keep them identical.
  static const Map<OrderStatus, Set<OrderStatus>> transitions = {
    created: {assigned, cancelled},
    assigned: {pickedUp, cancelled},
    pickedUp: {inTransit},
    inTransit: {delivered},
    delivered: {},
    cancelled: {},
  };

  bool canTransitionTo(OrderStatus next) => transitions[this]!.contains(next);
  bool get isActive => this == created || this == assigned || this == pickedUp || this == inTransit;
  bool get isInProgress => this == pickedUp || this == inTransit;   // courier location is visible
  bool get isTerminal => this == delivered || this == cancelled;
}
```

### 2.2 Entidades (freezed)

```dart
@freezed
abstract class Place with _$Place {
  const factory Place({required String address, required GeoPoint point, String? name}) = _Place;
}

@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({required String name, required int quantity}) = _OrderItem;
}

@freezed
abstract class Order with _$Order {
  const factory Order({
    required String id,
    required String code,                 // 'RT-1042'
    required String customerId,
    required OrderStatus status,
    required Place pickup,
    required Place dropoff,
    required List<OrderItem> items,
    required int totalCents,              // MXN cents
    required List<GeoPoint> route,        // precomputed polyline, >= 2 points
    required int routeDistanceMeters,
    required int routeDurationSeconds,
    required DateTime createdAt,          // UTC
    required DateTime updatedAt,          // UTC
    String? courierId,
    String? courierName,
    String? customerName,
  }) = _Order;
}

@freezed
abstract class OrderStatusEvent with _$OrderStatusEvent {
  const factory OrderStatusEvent({
    required int id,
    required String orderId,
    required OrderStatus status,
    required DateTime createdAt,          // server time, UTC
  }) = _OrderStatusEvent;
}
```

(Si el lint `always_put_required_named_parameters_first` lo pide, deja los opcionales al final, como arriba.)

### 2.3 `orders_repository.dart`

```dart
abstract interface class OrdersRepository {
  /// Customer: their orders. Courier: orders assigned to them. Newest first (createdAt desc).
  /// Emits again whenever any of those orders changes (Realtime / demo store).
  Stream<List<Order>> watchMyOrders();

  /// Emits the order and every later change. Errors with NotFoundError if it does not exist or is not visible.
  Stream<Order> watchOrder(String orderId);

  /// Status history ordered by createdAt ascending.
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId);

  /// Courier only. Throws InvalidTransitionError, NotAssignedToYouError, CourierBusyError, NotFoundError,
  /// NetworkError… Returns the updated order.
  Future<Order> advanceStatus(String orderId, OrderStatus next);
}
```

### 2.4 `connection_monitor.dart`

```dart
// ignore: one_member_abstracts — port implemented by Supabase Realtime and by the demo mock.
abstract interface class ConnectionMonitor {
  /// true while the live channel is connected. Emits the current value first.
  Stream<bool> watchIsConnected();
}
```

### 2.5 `available_order_actions.dart` — caso de uso

```dart
enum OrderAction {
  pickUp(OrderStatus.pickedUp),
  startDelivery(OrderStatus.inTransit),
  markDelivered(OrderStatus.delivered);

  const OrderAction(this.target);
  final OrderStatus target;
}

enum ActionBlockReason { courierBusy }

@immutable
class OrderActionState {
  const OrderActionState(this.action, {this.blockReason});
  final OrderAction action;
  final ActionBlockReason? blockReason;
  bool get enabled => blockReason == null;
  // ==, hashCode
}

class AvailableOrderActions {
  const AvailableOrderActions();

  /// Primary action for the detail screen, or null when there is none.
  OrderActionState? call({
    required UserRole role,
    required OrderStatus status,
    required bool hasOtherOrderInProgress,
  });
}

/// True if [orders] contains an order other than [currentOrderId] in picked_up / in_transit.
bool hasOtherOrderInProgress(List<Order> orders, String currentOrderId);
```

Reglas: `customer` → `null`. `courier`: `assigned` → `pickUp` (bloqueada con `courierBusy` si
`hasOtherOrderInProgress`); `pickedUp` → `startDelivery`; `inTransit` → `markDelivered`; cualquier otro → `null`.

### 2.6 `order_timeline.dart` — línea de tiempo (F5)

```dart
enum TimelineStepState { done, current, upcoming }

@immutable
class TimelineStep {
  const TimelineStep({required this.status, required this.state, this.at});
  final OrderStatus status;
  final TimelineStepState state;
  final DateTime? at;               // time of the latest event with this status, if any
}

List<TimelineStep> buildOrderTimeline({required OrderStatus current, required List<OrderStatusEvent> events});
```

Reglas:
- Camino feliz: `created → assigned → pickedUp → inTransit → delivered`.
- Si `current` no es `cancelled`: un paso por estado del camino feliz; anteriores a `current` → `done`,
  `current` → `current` (salvo `delivered`, que es `done`), posteriores → `upcoming` (atenuados en la UI).
- Si `current == cancelled`: solo los estados del camino feliz que tengan evento (en orden, `done`) y al final
  `cancelled` como `current`. Sin pasos `upcoming`.
- `at` = `createdAt` del último evento con ese estado; `null` si no hay (p. ej. datos antiguos).

## Paso 3 · Tracking (`lib/features/tracking/domain/`)

### 3.1 Entidades

```dart
@freezed
abstract class CourierLocation with _$CourierLocation {
  const factory CourierLocation({
    required String courierId,
    required String orderId,
    required GeoPoint point,
    required DateTime recordedAt,       // UTC. The server overwrites it with its own time on insert/update.
    double? heading,                    // 0..360
    double? speedMps,
    double? accuracyMeters,
  }) = _CourierLocation;
  const CourierLocation._();

  /// Definition §6.3 rule 7: older than 30 s = stale (shown as such, never hidden).
  bool isStale(DateTime nowUtc, {Duration threshold = const Duration(seconds: 30)}) =>
      nowUtc.difference(recordedAt) > threshold;
}

@freezed
abstract class DevicePosition with _$DevicePosition {
  const factory DevicePosition({
    required GeoPoint point,
    required DateTime timestamp,        // UTC
    double? heading,
    double? speedMps,
    double? accuracyMeters,
  }) = _DevicePosition;
}

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

@freezed
abstract class RouteProgress with _$RouteProgress {
  const factory RouteProgress({
    required GeoPoint snappedPoint,
    required int segmentIndex,
    required double traveledMeters,
    required double remainingMeters,
    required Duration eta,
    required bool isOffRoute,
    required double distanceToRouteMeters,
  }) = _RouteProgress;
}
```

### 3.2 Interfaces

```dart
abstract interface class TrackingRepository {
  /// Customer side: the courier's last position for [orderId] while the order is in progress; null otherwise.
  Stream<CourierLocation?> watchCourierLocation(String orderId);

  /// Courier side: upserts the courier's last position. Throws NoActiveOrderError if the order is not in progress
  /// or not assigned to the caller.
  Future<void> publishLocation(CourierLocation location);
}

abstract interface class DeviceLocationRepository {
  Future<LocationAccess> checkAccess();
  /// Shows the system dialog when possible. Returns the resulting access.
  Future<LocationAccess> requestAccess();
  /// Throws LocationPermissionDeniedError / LocationServiceDisabledError (as stream errors) when not available.
  Stream<DevicePosition> watchPosition();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}
```

### 3.3 `compute_route_progress.dart` — caso de uso

```dart
class ComputeRouteProgress {
  const ComputeRouteProgress({
    this.offRouteThresholdMeters = 75,
    this.fallbackSpeedMps = 25 / 3.6,        // 25 km/h
  });
  final double offRouteThresholdMeters;
  final double fallbackSpeedMps;

  RouteProgress call({required List<GeoPoint> route, required GeoPoint position, double? speedMps});
}
```

1. `projection = projectOntoRoute(route, position)`.
2. `total = routeLengthMeters(route)`; `remaining = max(0, total − projection.traveledMeters)`.
3. Velocidad fiable: `speedMps != null && speedMps >= 1.5 && speedMps <= 45`; si no, `fallbackSpeedMps`.
4. `eta = Duration(seconds: (remaining / speed).round())`.
5. `isOffRoute = projection.distanceToRouteMeters > offRouteThresholdMeters`.

### 3.4 `should_send_location.dart` — caso de uso (§6.3 regla 6)

```dart
class ShouldSendLocation {
  const ShouldSendLocation({
    this.minInterval = const Duration(seconds: 5),
    this.minDistanceMeters = 10,
    this.heartbeat = const Duration(seconds: 30),
    this.maxAccuracyMeters = 50,
  });

  bool call({
    required DevicePosition candidate,
    required DateTime nowUtc,
    GeoPoint? lastSentPoint,
    DateTime? lastSentAt,
  });
}
```

Reglas, en este orden:
1. `candidate.accuracyMeters != null && > maxAccuracyMeters` → `false` (lectura mala, se descarta).
2. Nunca se ha enviado (`lastSentAt == null || lastSentPoint == null`) → `true`.
3. `elapsed = nowUtc − lastSentAt`; `elapsed < minInterval` → `false`.
4. `elapsed >= heartbeat` → `true` (latido aunque no se mueva).
5. `haversineMeters(lastSentPoint, candidate.point) >= minDistanceMeters` → `true`; si no, `false`.

## Paso 4 · Auth (`lib/features/auth/domain/`)

`auth_repository.dart`:

```dart
abstract interface class AuthRepository {
  /// Emits the current state first and then every change (sign in, profile created, sign out).
  Stream<SessionState> watchSession();
  /// Sends the 6-digit code. Throws AuthError(invalidEmail | rateLimited), NetworkError…
  Future<void> sendCode(String email);
  /// Throws AuthError(invalidCode | codeExpired), NetworkError…
  Future<void> verifyCode({required String email, required String code});
  /// Calls rutta.ensure_profile. Idempotent. Afterwards watchSession emits SessionSignedIn.
  Future<UserProfile> ensureProfile(String fullName);
  /// Never throws because of the network (local sign-out always succeeds).
  Future<void> signOut();
}
```

`auth_validators.dart`:

```dart
bool isValidEmail(String email);        // trimmed; ^[^@\s]+@[^@\s]+\.[^@\s]+$
bool isValidOtpCode(String code);       // ^\d{6}$
/// Returns the trimmed name or throws ValidationError('fullName', required | tooLong) (1..80 chars, §7.1).
String validateFullName(String input);
```

## Paso 5 · Helpers de test

`test/helpers/builders.dart`:

- `const straightRoute = [GeoPoint(0, 0), GeoPoint(0, 0.01), GeoPoint(0, 0.02)];` (sobre el ecuador; cada segmento
  mide ≈ 1111.95 m).
- `Order buildOrder({String id = 'o1', String code = 'RT-1000', OrderStatus status = OrderStatus.assigned, String customerId = 'c1', String? courierId = 'k1', List<GeoPoint> route = straightRoute, DateTime? createdAt})`
  con valores razonables para el resto.
- `OrderStatusEvent buildEvent(OrderStatus status, DateTime at, {int id = 1, String orderId = 'o1'})`.
- `DevicePosition buildPosition(GeoPoint point, DateTime at, {double? accuracy, double? speed})`.

## Paso 6 · Tests

Usa `closeTo(esperado, tolerancia)` para los `double`.

| Archivo | Qué comprueba |
|---|---|
| `test/core/domain/geo_test.dart` | `haversineMeters((0,0),(0,0.01))` ≈ 1111.95 (±0.5); misma posición = 0; `bearingDegrees` (0,0)→(0,1) ≈ 90 y (0,0)→(1,0) ≈ 0 y (0,0)→(0,−1) ≈ 270; `routeLengthMeters(straightRoute)` ≈ 2223.9; `projectOntoRoute` con los casos de abajo; `pointAlongRoute` (0 → inicio, 555.97 → ≈ (0, 0.005) segmento 0, 1667.9 → ≈ (0, 0.015) segmento 1, −5 → inicio, 99999 → fin); `splitRoute(straightRoute, 0, (0, 0.005))` → traveled `[(0,0),(0,0.005)]`, remaining `[(0,0.005),(0,0.01),(0,0.02)]`; ruta de 1 punto lanza `ArgumentError`. |
| `test/features/orders/domain/order_status_test.dart` | **Las 36 combinaciones** de `canTransitionTo` contra la lista esperada exacta: `created→assigned`, `created→cancelled`, `assigned→pickedUp`, `assigned→cancelled`, `pickedUp→inTransit`, `inTransit→delivered` (todo lo demás `false`, incluido X→X); `isActive`/`isInProgress`/`isTerminal` de los 6; `fromWire`/`wireName` ida y vuelta; valor desconocido lanza. |
| `test/features/orders/domain/available_order_actions_test.dart` | cliente → `null` en los 6 estados; repartidor: `assigned` → `pickUp` habilitada, `assigned` + ocupado → `pickUp` con `courierBusy`, `pickedUp` → `startDelivery`, `inTransit` → `markDelivered`, `created`/`delivered`/`cancelled` → `null`; `hasOtherOrderInProgress` (otro pedido `inTransit` → true; el propio pedido `inTransit` no cuenta; solo `assigned`/`delivered` → false). |
| `test/features/orders/domain/order_timeline_test.dart` | `assigned` con eventos created/assigned → created `done`, assigned `current` (ambos con su `at`), pickedUp/inTransit/delivered `upcoming` con `at` null; `delivered` → los 5 `done`; `cancelled` desde `assigned` → created `done`, assigned `done`, cancelled `current` (3 pasos); `at` toma el último evento si hay repetidos; sin eventos → `at` null sin fallar. |
| `test/features/tracking/domain/compute_route_progress_test.dart` | punto (0.0001, 0.005): segmento 0, traveled ≈ 555.97, remaining ≈ 1667.9, distancia ≈ 11.1, no off-route; punto (0.0001, 0.015): segmento 1, traveled ≈ 1667.9; antes del inicio (0, −0.001): traveled 0; después del final (0, 0.03): remaining 0, off-route; punto (0.001, 0.005): distancia ≈ 111.2 → off-route; ETA: remaining 1667.9 sin velocidad → 240 s (25 km/h), con `speedMps: 10` → 167 s, con `speedMps: 0.5` → 240 s (no fiable); ruta de 2 puntos funciona. |
| `test/features/tracking/domain/should_send_location_test.dart` | primer envío → true; 3 s después y 50 m → false (intervalo); 6 s y 5 m → false (distancia); 6 s y 12 m → true; 31 s y 0 m → true (latido); precisión 80 m → false aunque sea el primero; precisión `null` se acepta. |
| `test/features/tracking/domain/courier_location_test.dart` | `isStale` con 30 s exactos → false, 31 s → true. |
| `test/features/auth/domain/auth_validators_test.dart` | emails válidos/ inválidos (`a@b.co` ok; `a@b`, `a b@c.com`, vacío no); códigos (`123456` ok; `12345`, `1234567`, `12a456` no); nombre: `"  Ana "` → `"Ana"`, vacío → `required`, 81 caracteres → `tooLong`. |

## Paso 7 · Cierre

`00-guia-general.md` §3.3. Comprueba que `./tool/check_architecture.sh` sigue en verde (ningún `domain/` importa
Flutter, Riverpod, Supabase, `latlong2` ni `intl`).

---

## Criterios de terminado

- [ ] `GeoPoint` y funciones de geometría en `core/domain` con tests numéricos.
- [ ] `OrderStatus` con la tabla de transiciones de §6.2 y test de las 36 combinaciones.
- [ ] Entidades freezed (`Place`, `OrderItem`, `Order`, `OrderStatusEvent`, `CourierLocation`, `DevicePosition`, `RouteProgress`, `UserProfile`) y `SessionState`.
- [ ] Interfaces `AuthRepository`, `OrdersRepository`, `TrackingRepository`, `DeviceLocationRepository`, `ConnectionMonitor`.
- [ ] `ComputeRouteProgress`, `ShouldSendLocation`, `AvailableOrderActions`, `buildOrderTimeline` y validadores con tests.
- [ ] Chequeo de arquitectura en verde; `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
