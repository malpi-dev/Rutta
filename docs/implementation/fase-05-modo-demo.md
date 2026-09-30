# Fase 05 · Modo demo

**Rama:** `feat/fase-05-modo-demo`
**Objetivo:** la app funciona **sin backend** con datos de ejemplo realistas: `DemoStore` en memoria, fixtures de
CDMX, simulador de repartidor, repositorios mock (`orders`, `tracking`, `device location`, `connection`), cambio de
repositorios según `AppMode`, selector de rol *Explore demo* y banner *Demo mode* con salida.
**Referencias:** definición §2 (modo demo), §3.1 F2, §5.1 flujo C, §6.4 (`DemoCourierSimulator`), §8.3, §12.2 ·
bitácora (mundo del demo, simulador, `DemoStore`) · `CLAUDE.md` del portafolio (reglas 4 y 5).
**Requisitos previos:** fase 04 terminada (`demo_routes.dart` generado).

> Al terminar: login provisional → *Explore demo* → *Explore as customer* muestra una lista provisional con los
> 5 pedidos de Alex y el banner de demo; *Exit demo* vuelve al login. Todo funciona en modo avión.
> Las pantallas definitivas de lista y detalle llegan en las fases 06 y 07.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Fixtures (`lib/features/demo/data/demo_fixtures.dart`)

Constantes de usuarios:

```dart
abstract final class DemoUsers {
  static const customerId = 'demo-customer';      // Alex Rivera — the user when exploring as customer
  static const customerName = 'Alex Rivera';
  static const courierId = 'demo-courier';        // Carlos Méndez — the user when exploring as courier
  static const courierName = 'Carlos Méndez';
  static const otherCourierId = 'demo-courier-2'; // María López — simulated courier of RT-1042
  static const otherCourierName = 'María López';
  static const otherCustomerId = 'demo-customer-2';
  static const otherCustomerName = 'Jordan Lee';
}
```

`DemoWorld buildDemoWorld(DateTime nowUtc)` devuelve `({List<Order> orders, List<OrderStatusEvent> events})`.
Los pedidos usan `demoRoutes['rN']` (origen con nombre, destino sin nombre, `route` = `points`,
`routeDistanceMeters`/`routeDurationSeconds` de la ruta). Ids `demo-order-<número>`. Horas relativas a `nowUtc`:

| Código | Cliente | Repartidor | Estado | Ruta | Ítems · total (centavos) | Eventos (minutos respecto a `now`) |
|---|---|---|---|---|---|---|
| RT-1042 | Alex | María | `inTransit` | r1 | 2× Flat white, 1× Butter croissant · 18500 | created −25, assigned −22, picked_up −12, in_transit −8 |
| RT-1043 | Alex | Carlos | `assigned` | r2 | 1× Ibuprofen 400 mg, 2× Electrolyte drink · 24900 | created −10, assigned −6 |
| RT-1038 | Alex | María | `delivered` | r3 | 1× Quinoa bowl, 1× Green juice · 21000 | ayer: created −1490, assigned −1487, picked_up −1475, in_transit −1472, delivered −1456 |
| RT-1035 | Alex | Carlos | `delivered` | r4 | 6× Concha, 1× Café de olla · 13500 | hace 2 días: created −2930, assigned −2926, picked_up −2915, in_transit −2911, delivered −2890 |
| RT-1031 | Alex | — | `cancelled` | r5 | 1× Vitamin C 1 g · 9900 | hace 3 días: created −4330, cancelled −4325 |
| RT-1029 | Jordan | Carlos | `delivered` | r6 | 1× Salmon poke bowl · 23500 | created −3100, assigned −3096, picked_up −3085, in_transit −3080, delivered −3062 |

- `customerName` y `courierName` rellenos según la tabla (`null` si no hay repartidor).
- `createdAt` = hora del evento `created`; `updatedAt` = hora del último evento.
- Ids de eventos: enteros correlativos empezando en 1.

## Paso 2 · Simulador (`lib/features/tracking/data/demo_courier_simulator.dart`)

```dart
/// Moves a fake courier along [route] (definition §8.3). Lives in data/ because it is a mock implementation detail.
class DemoCourierSimulator {
  DemoCourierSimulator({
    required this.route,
    required this.clock,
    this.targetDuration = const Duration(seconds: 60),
    this.tick = const Duration(seconds: 1),
    this.startFraction = 0,
    this.reportedSpeedMps = 8.3,          // 30 km/h, so the ETA looks realistic
    Random? random,
  }) : _random = random ?? Random(42);

  /// Single-subscription stream. Emits the start point immediately, then one position per [tick],
  /// then exactly route.last, then closes. Cancelling the subscription stops the timer.
  Stream<DevicePosition> positions();
}
```

Algoritmo: `total = routeLengthMeters(route)`; `baseSpeed = total / targetDuration.inSeconds` (m/s);
`meters = startFraction * total`. En cada tick: `meters += baseSpeed * tick.inSeconds * (0.9 + 0.2 * random.nextDouble())`;
si `meters >= total` emite `route.last` y cierra; si no, `pointAlongRoute(route, meters)` → punto y segmento;
`heading = bearingDegrees(route[seg], route[seg + 1])`. Cada `DevicePosition` lleva `timestamp: clock.nowUtc()`,
`speedMps: reportedSpeedMps`, `accuracyMeters: 5`. Implementa con `StreamController` + `Timer.periodic`, cancelando el
timer en `onCancel`.

## Paso 3 · `DemoStore` (`lib/features/demo/data/demo_store.dart`)

Estado en memoria compartido por todos los mocks (bitácora). Resumen de la API:

```dart
class DemoStore {
  DemoStore.seeded({
    required this.role,
    required this.clock,
    this.latency = const Duration(milliseconds: 450),       // simulated read latency (tests: Duration.zero)
    this.simulationDuration = const Duration(seconds: 60),  // tests: a few seconds
    this.simulationTick = const Duration(seconds: 1),
  });
  DemoStore.idle(...);                   // empty store used while the app is live (no data, no timers)

  final UserRole role;
  String get currentUserId;              // DemoUsers.customerId or DemoUsers.courierId

  Stream<void> get changes;              // broadcast; fires after every mutation
  List<Order> ordersForCurrentUser();    // customer: customerId == me; courier: courierId == me; createdAt desc
  Order? order(String id);
  List<OrderStatusEvent> events(String orderId);   // createdAt asc
  CourierLocation? location(String orderId);

  /// Applies business rules exactly like rutta.advance_order_status (see step 4). Adds the event.
  Order advance(String orderId, OrderStatus next, {required String actorId, bool asSystem = false});
  void setLocation(String orderId, CourierLocation? location);

  /// Starts (once) the simulation of a courier that is NOT the current user (RT-1042 when exploring as customer).
  void ensureCustomerSimulation(String orderId);

  void dispose();                        // cancels simulations, closes controllers
}
```

- **Reglas de `advance`** (mismas que la RPC de la fase 09, así mock y Supabase se comportan igual):
  1. Pedido inexistente → `NotFoundError('order', id)`.
  2. Si `!asSystem` y `order.courierId != actorId` → `NotAssignedToYouError`.
  3. Si `!asSystem` y la transición no es de repartidor (`assigned→pickedUp`, `pickedUp→inTransit`,
     `inTransit→delivered`) → `InvalidTransitionError(from, to)` (con los `wireName`).
  4. Si `asSystem`, basta con `order.status.canTransitionTo(next)`; si no → `InvalidTransitionError`.
  5. Si `next.isInProgress` y el repartidor ya tiene **otro** pedido en curso → `CourierBusyError`.
  6. Actualiza `status` y `updatedAt`, añade `OrderStatusEvent` con `createdAt = clock.nowUtc()`.
  7. Si `next.isTerminal` → borra la ubicación de ese pedido (regla 4 de §6.3).
- **Simulación del cliente** (`ensureCustomerSimulation`): solo si el pedido está `inTransit` y su repartidor no es
  el usuario actual. Crea `DemoCourierSimulator(route, startFraction: 0.15, targetDuration: simulationDuration, tick: simulationTick)`;
  cada posición → `setLocation(orderId, CourierLocation(courierId, orderId, point, recordedAt: timestamp, heading, speedMps))`.
  Al terminar el stream → `advance(orderId, OrderStatus.delivered, actorId: courierId, asSystem: true)`.
  Si el pedido está `pickedUp` (no ocurre con los fixtures, pero cúbrelo), fija una ubicación estática en el origen.
- **Ubicación inicial:** RT-1042 no tiene ubicación hasta que arranca la simulación (la primera posición llega al
  instante).

## Paso 4 · Repositorios mock

Todos en su feature `data/`, reciben el `DemoStore` por constructor.

### 4.1 `lib/features/orders/data/mock_orders_repository.dart`

- `watchMyOrders()`: `StreamController` con `onListen`: espera `store.latency`, emite `ordersForCurrentUser()` y
  vuelve a emitir en cada `store.changes`. Cancela la suscripción en `onCancel`.
- `watchOrder(id)`: igual; si el pedido no existe emite `NotFoundError` como error del stream.
- `watchStatusEvents(id)`: igual con `events(id)`.
- `advanceStatus(id, next)`: espera `latency`, llama `store.advance(id, next, actorId: store.currentUserId)` y devuelve
  el pedido. Los `DomainError` se propagan tal cual.

### 4.2 `lib/features/tracking/data/mock_tracking_repository.dart`

- `watchCourierLocation(orderId)`: en `onListen` llama `store.ensureCustomerSimulation(orderId)` y emite
  `store.location(orderId)` (puede ser `null`) al inicio y en cada cambio (usa `distinct()`).
- `publishLocation(location)`: si el pedido no existe, no está en curso o su repartidor no es el usuario actual →
  `NoActiveOrderError`; si no, `store.setLocation(location.orderId, location)`.

### 4.3 `lib/features/tracking/data/mock_device_location_repository.dart`

Sustituye al GPS en demo (funciona en emulador y en modo avión):

- `checkAccess()` / `requestAccess()` → `LocationAccess.granted`. `openAppSettings()`/`openLocationSettings()` → no-op.
- `watchPosition()`: escucha `store.changes` y mira el pedido en curso del repartidor actual:
  `pickedUp` → emite el punto de origen cada 5 s (con el primer valor inmediato);
  `inTransit` → arranca un `DemoCourierSimulator(route, targetDuration: store.simulationDuration)` y reenvía sus
  posiciones (al terminar, sigue emitiendo `route.last` cada 5 s); sin pedido en curso → no emite.
  Cambiar de estado cancela lo anterior. Todo se cancela en `onCancel`.

### 4.4 `lib/features/orders/data/mock_connection_monitor.dart`

`watchIsConnected()` → emite `true`. Para tests, un constructor con `StreamController<bool>` controlable
(`MockConnectionMonitor.controlled(controller)`).

## Paso 5 · Providers (`lib/core/di/repository_providers.dart`)

```dart
@Riverpod(keepAlive: true)
DemoStore demoStore(Ref ref) {
  final mode = ref.watch(appModeControllerProvider);
  final store = switch (mode) {
    AppModeDemo(:final role) => DemoStore.seeded(role: role, clock: ref.watch(clockProvider)),
    AppModeLive() => DemoStore.idle(clock: ref.watch(clockProvider)),
  };
  ref.onDispose(store.dispose);          // entering/leaving demo rebuilds it: a fresh world every time
  return store;
}

@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) => switch (ref.watch(appModeControllerProvider)) {
  AppModeLive() => throw UnimplementedError('SupabaseOrdersRepository arrives in phase 11'),
  AppModeDemo() => MockOrdersRepository(ref.watch(demoStoreProvider)),
};
```

Mismo patrón para `trackingRepository` (live: fase 11), `connectionMonitor` (live: fase 11) y
`deviceLocationRepository` (live: `GeolocatorDeviceLocationRepository`, fase 08). Los `UnimplementedError` en live
son temporales y **no** se alcanzan: sin sesión el router manda al login.

Providers de casos de uso (mismo archivo o `use_case_providers.dart`), `keepAlive`: `computeRouteProgress`,
`availableOrderActions`, `shouldSendLocation` (este con `minInterval: Env.locationMinInterval` y
`minDistanceMeters: Env.locationMinDistanceMeters`).

## Paso 6 · Presentación

### 6.1 `lib/features/demo/presentation/demo_role_picker_sheet.dart`

`Future<void> showDemoRolePicker(BuildContext context, WidgetRef ref)` abre un `showModalBottomSheet` con:
- Título `demoPickerTitle` "Explore Rutta" y subtítulo `demoPickerSubtitle` "Sample data, no account and no internet needed.".
- Dos tarjetas grandes (`Card` + `InkWell`, ícono, título y descripción):
  - `demoAsCustomer` "Explore as customer" / `demoAsCustomerHint` "Follow a courier live on the map" —
    key y `Semantics(identifier:)` `demo-as-customer`.
  - `demoAsCourier` "Explore as courier" / `demoAsCourierHint` "Deliver an order step by step" —
    key y identifier `demo-as-courier`.
- Al tocar: cierra el sheet y llama `ref.read(appModeControllerProvider.notifier).enterDemo(role)`. El router redirige.

### 6.2 Login provisional

Añade un `OutlinedButton` `exploreDemo` "Explore demo" (key e identifier `login-explore-demo`) que abre el sheet.
(La fase 10 construye el login definitivo y conserva este botón con el mismo id.)

### 6.3 `lib/features/demo/presentation/demo_banner.dart`

Igual que en Centavo (`../Centavo/lib/features/demo/presentation/demo_banner.dart`): franja
`tertiaryContainer` con ícono `science_outlined`, texto `demoBannerMessage` "Demo mode — sample data" y `TextButton`
`exitDemo` "Exit demo" (key e identifier `demo-exit`) que llama `exitDemo()`. Key del contenedor `demo-banner`.

En `RuttaApp`, `MaterialApp.router(builder: …)`:

```dart
builder: (context, child) {
  final inDemo = ref.watch(appModeControllerProvider) is AppModeDemo;
  if (!inDemo) return child!;
  // Painted AFTER the navigator so Maestro can see it (see implementation log of Centavo, phase 13).
  return Column(
    verticalDirection: VerticalDirection.up,
    children: [
      Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child!)),
      const DemoBanner(),
    ],
  );
},
```

(El banner lleva `SafeArea(bottom: false)`, por eso se quita el padding superior del resto.)

### 6.4 Listas provisionales

Para verificar la fase, `CustomerOrdersScreen` y `CourierOrdersScreen` provisionales pasan a mostrar
`AsyncStateView` sobre un provider `myOrdersProvider` (`lib/features/orders/presentation/orders_providers.dart`:
`@riverpod Stream<List<Order>> myOrders(Ref ref) => ref.watch(ordersRepositoryProvider).watchMyOrders();`) con un
`ListTile` por pedido (código + `status.wireName`). Las fases 06 y 07 las reemplazan.

## Paso 7 · Tests

Crea en `test/helpers/demo.dart` un `DemoStore testDemoStore({UserRole role = UserRole.customer, FixedClock? clock})`
con `latency: Duration.zero`, `simulationDuration: const Duration(seconds: 5)`, `simulationTick: const Duration(seconds: 1)`.
Usa `fakeAsync` (paquete `fake_async`, ya incluido por `flutter_test`; si el lint pide declararlo, añádelo a
`dev_dependencies` y anótalo) para avanzar el tiempo en tests del simulador y de los mocks.

| Archivo | Qué comprueba |
|---|---|
| `test/features/demo/data/demo_fixtures_test.dart` | Alex tiene 5 pedidos (1 `inTransit`, 1 `assigned`, 2 `delivered`, 1 `cancelled`); Carlos tiene 3 (1 `assigned`, 2 `delivered`); ningún repartidor tiene 2 pedidos en curso; el último evento de cada pedido coincide con su estado y los eventos están en orden ascendente; todas las transiciones consecutivas de eventos son válidas (`canTransitionTo`). |
| `test/features/tracking/data/demo_courier_simulator_test.dart` | con `targetDuration` 5 s y `tick` 1 s: el primer punto es el inicio (o el 15 % con `startFraction`); el último es `route.last`; el stream se cierra; todos los puntos están a < 1 m de la ruta (`projectOntoRoute`); `traveledMeters` no decrece; cancelar la suscripción detiene el timer (no quedan timers pendientes). |
| `test/features/orders/data/mock_orders_repository_test.dart` | cliente ve sus 5 pedidos ordenados por fecha desc; repartidor ve sus 3; `advanceStatus` feliz `assigned→pickedUp→inTransit→delivered` emite cambios en `watchMyOrders`, `watchOrder` y añade eventos; salto `assigned→delivered` → `InvalidTransitionError(from: 'assigned', to: 'delivered')`; avanzar RT-1042 como Carlos → `NotAssignedToYouError`; `CourierBusyError` (store de test con un segundo pedido `assigned` de Carlos mientras otro está `pickedUp`); `watchOrder('nope')` → `NotFoundError`; al entregar se borra la ubicación. |
| `test/features/tracking/data/mock_tracking_repository_test.dart` | como cliente, `watchCourierLocation(RT-1042)` emite posiciones que avanzan por la ruta y, al terminar la simulación, el pedido pasa a `delivered` (evento añadido) y la ubicación vuelve a `null`; `publishLocation` como cliente → `NoActiveOrderError`; como repartidor sin pedido en curso → `NoActiveOrderError`. |
| `test/features/tracking/data/mock_device_location_repository_test.dart` | como repartidor: sin pedido en curso no emite; tras `pickedUp` emite el origen; tras `inTransit` emite puntos que avanzan; permisos siempre `granted`. |
| `test/core/di/repository_providers_test.dart` | en demo cliente `ordersRepositoryProvider` es `MockOrdersRepository`; entrar al demo como repartidor crea un store nuevo con rol courier; salir del demo llama a `dispose` del store anterior (sin timers pendientes). |
| `test/features/demo/presentation/demo_flow_test.dart` | app completa con overrides de test: login → *Explore demo* → *Explore as customer* → se ve el banner (`demo-banner`) y la lista provisional con `RT-1042`; *Exit demo* → login sin banner. Igual con *as courier* → `RT-1043`. Desmonta la app al final. |

## Paso 8 · Verificación manual

En el emulador, **en modo avión**: login → *Explore demo* → *as customer* → lista con 5 pedidos y banner →
*Exit demo* → *as courier* → 3 pedidos. Anota en la bitácora que se probó en modo avión.

## Paso 9 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] Fixtures con el mundo de la bitácora (Alex 5 pedidos, Carlos 3) y rutas reales.
- [ ] `DemoCourierSimulator` con tests de tiempo (`fakeAsync`) y sin timers colgados.
- [ ] `DemoStore` con las mismas reglas de negocio que la RPC (inválida, no asignado, ocupado, borrar ubicación al terminar).
- [ ] `MockOrdersRepository`, `MockTrackingRepository`, `MockDeviceLocationRepository`, `MockConnectionMonitor` con tests.
- [ ] Providers de repositorio que cambian según `AppMode`; mundo nuevo al entrar y `dispose` al salir.
- [ ] Selector de rol (`demo-as-customer`, `demo-as-courier`), botón `login-explore-demo` y banner (`demo-banner`, `demo-exit`).
- [ ] Probado en el emulador en modo avión.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
