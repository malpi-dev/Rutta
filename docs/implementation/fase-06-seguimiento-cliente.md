# Fase 06 · Seguimiento del cliente

**Rama:** `feat/fase-06-seguimiento-cliente`
**Objetivo:** la experiencia completa del cliente en modo demo: lista *Active* / *History*, detalle con mapa (origen,
destino, ruta recorrida vs. restante), **marcador del repartidor animado sobre la ruta**, panel con distancia
restante, ETA, aviso de posición antigua, repartidor asignado, ítems, total y línea de tiempo de estados.
**Referencias:** definición §3.1 F3, F4, F5 · §5.1 flujo A · §6.3 · §8.4 (`AnimatedCourierMarker`) · §12.1 (estados
de lista y detalle del cliente) · §13 (tests de widget).
**Requisitos previos:** fase 05 terminada.

> Al terminar, en demo como cliente: al abrir RT-1042 el repartidor se desliza suavemente por la ruta durante
> ~1 minuto, la distancia y la ETA bajan, y el pedido termina en *Delivered* (y pasa a *History*).

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1. Borra la vista previa de desarrollo de la fase 04 (`dev_map_preview_screen.dart`, su ruta
`/dev/map` y el botón del login) — ya no hace falta.

## Paso 1 · Providers (`lib/features/orders/presentation/orders_providers.dart` y `lib/features/tracking/presentation/tracking_providers.dart`)

```dart
// orders_providers.dart
@riverpod
Stream<List<Order>> myOrders(Ref ref) => ref.watch(ordersRepositoryProvider).watchMyOrders();

@riverpod
Stream<Order> order(Ref ref, String orderId) => ref.watch(ordersRepositoryProvider).watchOrder(orderId);

@riverpod
Stream<List<OrderStatusEvent>> orderEvents(Ref ref, String orderId) =>
    ref.watch(ordersRepositoryProvider).watchStatusEvents(orderId);

@riverpod
Stream<bool> isConnected(Ref ref) => ref.watch(connectionMonitorProvider).watchIsConnected();
```

```dart
// tracking_providers.dart
@riverpod
Stream<CourierLocation?> courierLocation(Ref ref, String orderId) =>
    ref.watch(trackingRepositoryProvider).watchCourierLocation(orderId);

/// Ticks once per second so "Last updated X s ago" and the stale state refresh without new data.
@riverpod
Stream<DateTime> now(Ref ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock.nowUtc());
}

/// Progress of the courier over the route. null when there is no location yet.
@riverpod
RouteProgress? routeProgress(Ref ref, String orderId) {
  final order = ref.watch(orderProvider(orderId)).value;
  final location = ref.watch(courierLocationProvider(orderId)).value;
  if (order == null || location == null) return null;
  return ref.watch(computeRouteProgressProvider)(
      route: order.route, position: location.point, speedMps: location.speedMps);
}
```

- Solo se observa `courierLocationProvider` cuando el pedido está **en curso** (`status.isInProgress`); así en
  `created`/`assigned`/terminados no hay suscripción (ni simulación).
- `nowProvider` se observa solo desde el widget pequeño que muestra "Last updated…" (no desde toda la pantalla), para
  no reconstruir el mapa cada segundo.

## Paso 2 · Widgets comunes de pedidos (`lib/features/orders/presentation/widgets/`)

| Widget | Detalle |
|---|---|
| `status_chip.dart` → `OrderStatusChip(status)` | `Chip` pequeño con texto de l10n y color: `created` neutral, `assigned` secondary, `pickedUp`/`inTransit` primary, `delivered` success, `cancelled` neutral. Texto con contraste suficiente (usa el color como fondo al 15 % y como texto). |
| `order_card.dart` → `OrderCard(order, {onTap, showCustomer = false})` | `Card` + `InkWell`: fila superior código (`titleMedium`, Manrope) + `OrderStatusChip`; debajo el nombre del origen, hora (`formatOrderDate`) y total (`formatMoneyCents`, cifras tabulares). Si `showCustomer`, muestra `customerName`. Key e identifier `order-card-<code>` (p. ej. `order-card-RT-1042`). |
| `section_header.dart` → `SectionHeader(title)` | Texto `labelLarge` en mayúsculas pequeñas con padding. |
| `status_timeline.dart` → `StatusTimeline(steps)` | Lista vertical (no scroll propio) a partir de `buildOrderTimeline`: punto relleno (`done`, color success; `current`, color primary más grande), punto hueco (`upcoming`, neutral) y línea conectora; texto del estado y hora (`formatTime`) si `at != null`. `upcoming` con opacidad 0.45. `cancelled` en color de error. Cada fila con key `timeline-<wireName>`. |

Textos en `app_en.arb`: `statusCreated` "Placed", `statusAssigned` "Courier assigned", `statusPickedUp` "Picked up",
`statusInTransit` "In transit", `statusDelivered` "Delivered", `statusCancelled` "Cancelled".
Función `String statusLabel(OrderStatus s, AppLocalizations l10n)` en `widgets/status_labels.dart` (switch exhaustivo).

## Paso 3 · Lista del cliente (`customer_orders_screen.dart`)

- `Scaffold` con `AppBar(title: l10n.myOrdersTitle "My orders")` y acción `IconButton(Icons.settings_outlined)`
  (tooltip `settings`, key e identifier `settings-open`) → `context.push(Routes.settings)`.
- Cuerpo: `ReconnectingBanner` (paso 6) arriba + `RefreshIndicator` (`onRefresh: () => ref.refresh(myOrdersProvider.future)`)
  con `AsyncStateView<List<Order>>`:
  - Carga: `SkeletonList(itemCount: 3, itemHeight: 96)`.
  - Vacío: `EmptyState(icon: Icons.receipt_long_outlined, title: l10n.noOrdersTitle "No orders yet", message: …)`.
    En live el mensaje sugiere probar el demo (`noOrdersLiveHint` "Orders placed for you will appear here. Want to look
    around? Sign out and tap Explore demo."); en demo, `noOrdersDemoHint` "Nothing here yet.".
  - Error: `ErrorState` con *Retry* → `ref.invalidate(myOrdersProvider)`.
  - Datos: `ListView` con `SectionHeader(l10n.activeSection "Active")` + tarjetas de `status.isActive`, y
    `SectionHeader(l10n.historySection "History")` + el resto. Omite la sección que quede vacía. Toca una tarjeta →
    `context.push(Routes.customerOrder(order.id))`.
- El `ListView` debe ser siempre desplazable (`AlwaysScrollableScrollPhysics`) para que el pull-to-refresh funcione
  con pocos elementos.

## Paso 4 · Detalle del pedido — estructura (`order_detail_screen.dart`)

`OrderDetailScreen(orderId, role)` es **una** pantalla con variante por rol. En esta fase se implementa la variante
del cliente; la del repartidor (fase 07) reutiliza el mapa, la cabecera, las secciones y la línea de tiempo.

```
Scaffold(
  appBar: AppBar(title: Text(order.code)),
  body: AsyncStateView<Order>(
    value: ref.watch(orderProvider(orderId)),
    loading: const OrderDetailSkeleton(),        // map placeholder + panel skeleton
    onRetry: () => ref.invalidate(orderProvider(orderId)),
    data: (order) => Stack(children: [
      Positioned.fill(child: TrackingMap(order: order, role: role, controller: _mapController)),
      const Positioned(top: 0, left: 0, right: 0, child: ReconnectingBanner()),
      DraggableScrollableSheet(
        initialChildSize: 0.42, minChildSize: 0.22, maxChildSize: 0.88,
        builder: (context, scroll) => TrackingPanel(order: order, role: role, scrollController: scroll),
      ),
    ]),
  ),
)
```

- Pantalla `ConsumerStatefulWidget` (guarda el `RuttaMapController`).
- Error `NotFoundError` → `ErrorState` con el texto `errorNotFound` ("This order no longer exists.") y *Retry*.

## Paso 5 · Mapa con marcador animado (`lib/features/tracking/presentation/tracking_map.dart`)

`TrackingMap(order, role, controller)` — `ConsumerStatefulWidget` con `SingleTickerProviderStateMixin`.

**Marcadores y polilíneas:**
- `pickup`: `PlacePin(storefront, colors.pickupMarker)` en `order.pickup.point`; `dropoff`: `PlacePin(home, colors.dropoffMarker)`.
- Sin ubicación: una sola polilínea `route` (`routeRemaining`, ancho 6).
- Con ubicación: `splitRoute(order.route, progress.segmentIndex, displayedSnappedPoint)` → polilínea `traveled`
  (`colors.routeTraveled`, ancho 6) y `remaining` (`colors.routeRemaining`, ancho 6).
- `courier`: `CourierPin(headingDegrees, stale)` en la posición **mostrada** (animada), solo si el pedido
  `isInProgress` y hay ubicación. Al pasar a `delivered` desaparece.
- `darkMode: Theme.of(context).brightness == Brightness.dark`; `initialFit: order.route`.

**Animación sobre la ruta** (el "Destaca" de la app, §8.4):

1. Guarda `_fromMeters`, `_toMeters` (distancia recorrida sobre la ruta), `_fromPoint`/`_toPoint` (para cuando está
   fuera de ruta) y un `AnimationController(duration: Env.locationMinInterval)` con curva lineal.
2. Escucha `courierLocationProvider(order.id)` con `ref.listen` (en `initState` vía `ref.listenManual`, o en `build`
   con `ref.listen`). Con cada nueva ubicación:
   - Calcula `progress = computeRouteProgress(route, location.point, location.speedMps)`.
   - Primera ubicación: coloca el marcador sin animar (`_from = _to`).
   - Siguientes: `_from = valor mostrado actual`, `_to = nuevo`; `controller.forward(from: 0)`.
   - Duración: el intervalo entre `recordedAt` consecutivos, limitado a `[0.5 s, 6 s]` (en el demo llegan cada 1 s;
     en live cada ~5 s). Así el marcador no se detiene entre posiciones ni salta.
3. En cada frame (`AnimatedBuilder` sobre el controller alrededor de `RuttaMap`):
   - Si **no** está fuera de ruta: `meters = lerp(_fromMeters, _toMeters, t)`;
     `(point, segmentIndex) = pointAlongRoute(route, meters)`; heading = `bearingDegrees(route[seg], route[seg + 1])`.
     El marcador **sigue las curvas de la ruta** en vez de cortar esquinas.
   - Si está fuera de ruta (`isOffRoute`): interpola lat/lng linealmente entre `_fromPoint` y `_toPoint`; heading =
     `location.heading ?? bearingDegrees(_fromPoint, _toPoint)`.
   - Retroceso: si `_toMeters < _fromMeters − 30` (dato raro), coloca sin animar.
4. `dispose`: `controller.dispose()`.

**Cámara:** en el primer frame encuadra la ruta (`initialFit`). No persigue al repartidor automáticamente (el usuario
puede mover el mapa); el botón de recentrar (paso 7) lo centra.

Para que los tests puedan observar la posición mostrada sin mapa real, expone la posición calculada en el marcador:
`MapMarker(id: 'courier', child: Semantics(label: …, value: '${point.lat.toStringAsFixed(5)},${point.lng.toStringAsFixed(5)}', child: CourierPin(...)))`
(o una `Key('courier-pin')` y compara con `FakeRuttaMap.lastProps`).

## Paso 6 · `ReconnectingBanner` (`lib/features/orders/presentation/widgets/reconnecting_banner.dart`)

Observa `isConnectedProvider`: si el último valor es `false`, muestra una franja `warning` con un indicador pequeño y
`reconnecting` "Reconnecting…" (key `reconnecting-banner`); si es `true`, carga o error → `SizedBox.shrink()`
(el error del monitor no debe romper la pantalla). En demo siempre está conectado.

## Paso 7 · Panel inferior del cliente (`lib/features/tracking/presentation/tracking_panel.dart`)

`TrackingPanel(order, role, scrollController)`: `Material` con esquinas superiores redondeadas (radio 24), color
`surface`, un "asa" de 36×4 arriba, y un `ListView(controller: scrollController)` con estas secciones:

1. **Cabecera de estado** (`OrderStatusHeadline`): texto grande (`headlineSmall`) con el estado (key e identifier
   `order-status-headline`; el texto visible es exactamente el de `statusLabel`, p. ej. "In transit", "Delivered").
   Debajo, una línea de contexto según el estado:
   - `created`: `waitingForCourier` "Waiting for a courier".
   - `assigned`: `trackingStartsOnPickup` "Tracking starts when the courier picks up your order".
   - `pickedUp`/`inTransit` sin ubicación aún: `waitingForLocation` "Waiting for the courier's location…".
   - `pickedUp`/`inTransit` con progreso: fila con **ETA** (`formatEta`, key e identifier `tracking-eta`) y
     **distancia restante** (`formatDistance`, key `tracking-distance`), p. ej. "4 min · 1.2 km left"
     (`etaAndDistance` con placeholders `{eta}` y `{distance}`).
   - `delivered`: `deliveredAt` "Delivered at {time}" (hora del evento `delivered`).
   - `cancelled`: `orderCancelled` "This order was cancelled".
2. **Aviso de posición antigua** (`StaleLocationNotice`, widget pequeño que observa `nowProvider`): si la ubicación
   `isStale(now)`, muestra ícono `schedule` color `warning` + `lastUpdatedAgo` "Last updated {ago}" (`formatAgo`),
   key `stale-indicator`. El `CourierPin` se pinta con `stale: true` (gris). **No** se oculta el marcador.
   (Para calcular `stale` en `TrackingMap` usa también `nowProvider` pero con `select` a un `bool` para no reconstruir
   cada segundo.)
3. **Repartidor**: si hay `courierName`, fila con avatar de iniciales y `courierLabel` "Your courier" + nombre.
4. **Direcciones**: origen (nombre + dirección, ícono `storefront`) y destino (`dropoffLabel` "Drop-off" + dirección,
   ícono `home`), unidos por una línea punteada vertical.
5. **Ítems y total**: `itemsTitle` "Items"; filas `2× Flat white`; total `formatMoneyCents` en negrita (`totalLabel` "Total").
6. **Línea de tiempo**: `timelineTitle` "Status"; `StatusTimeline(buildOrderTimeline(current: order.status, events: …))`
   con `AsyncStateView` sobre `orderEventsProvider` (carga: 3 filas skeleton; error: texto pequeño + *Retry*).

**Botón recentrar:** `FloatingActionButton.small` sobre el mapa, arriba a la derecha (debajo del AppBar), visible solo
con ubicación del repartidor. Icono `my_location`, tooltip `recenterOnCourier` "Center on courier", key e identifier
`tracking-recenter`. Llama `controller.centerOn(displayedPoint, zoom: 16)`.

**Al entregar** (el stream del pedido pasa a `delivered`): el marcador desaparece, la cabecera dice "Delivered", la
línea de tiempo añade "Delivered 2:32 PM". Al volver atrás, el pedido aparece en *History*.

## Paso 8 · Tests

Usa los overrides base (con `FakeRuttaMap`) y un `DemoStore` de test (fase 05) o `mocktail` sobre los repositorios.
Recuerda desmontar la app al final de cada test con timers (`nowProvider`, simulación).

| Archivo | Qué comprueba |
|---|---|
| `test/features/orders/presentation/status_timeline_test.dart` | pasos `done` con hora, `current` resaltado, `upcoming` atenuados (opacidad) y sin hora; variante `cancelled` en color de error. |
| `test/features/orders/presentation/customer_orders_screen_test.dart` | carga → skeleton; vacío → "No orders yet"; error → mensaje + *Retry* que vuelve a pedir; datos → secciones Active (RT-1042, RT-1043) e History (RT-1038, RT-1035, RT-1031); tocar `order-card-RT-1042` navega al detalle; un cambio en el store (p. ej. pedido pasa a `delivered`) lo mueve a History **sin refrescar**. |
| `test/features/tracking/presentation/customer_detail_test.dart` | RT-1043 (`assigned`): sin marcador `courier`, texto "Tracking starts…"; RT-1042: aparece `marker-courier`, la ETA y la distancia; tras avanzar el reloj/simulación la distancia baja; al terminar la simulación: "Delivered", sin marcador, timeline con `timeline-delivered` hecho; `NotFoundError` → mensaje "This order no longer exists."; el botón `tracking-recenter` llama a `centerOn` (delegate falso adjunto al controller). |
| `test/features/tracking/presentation/stale_location_test.dart` | con una ubicación de hace 45 s (reloj fijo) aparece `stale-indicator` con "Last updated 45 s ago" y el pin gris; con 10 s no aparece. |
| `test/features/tracking/presentation/tracking_map_animation_test.dart` | con un stream controlado de ubicaciones sobre `straightRoute`: tras la segunda ubicación, a mitad de la animación la posición mostrada está **sobre la ruta** y entre ambas; al terminar coincide con la nueva; una ubicación fuera de ruta (> 75 m) se muestra en su posición real. |

## Paso 9 · Verificación manual

En el emulador, demo como cliente: abrir RT-1042, mirar el recorrido completo (~1 min) en claro y oscuro; comprobar
que el marcador gira en las curvas y no salta, que la ruta recorrida se atenúa, que la ETA/distancia bajan, que
*recentrar* funciona y que al final aparece *Delivered* y el pedido pasa a *History*. Graba 10 s con
`adb shell screenrecord --time-limit 10 /sdcard/rutta-f06.mp4` y revisa que la animación sea fluida (anótalo).

## Paso 10 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] Lista del cliente con Active/History, pull-to-refresh, carga/vacío/error y actualización en vivo desde el store.
- [ ] Detalle con mapa, pines, ruta recorrida/restante y marcador **animado sobre la ruta** (sigue curvas; fuera de ruta usa la posición real).
- [ ] Panel con estado, ETA y distancia, aviso *stale* (> 30 s), repartidor, direcciones, ítems, total y línea de tiempo.
- [ ] Botón recentrar; estados `created`/`assigned`/`delivered`/`cancelled` con su texto; "Order not found".
- [ ] Ids para Maestro: `order-card-<code>`, `order-status-headline`, `tracking-eta`, `tracking-recenter`, `settings-open`.
- [ ] Vista previa de desarrollo de la fase 04 eliminada.
- [ ] Recorrido completo verificado a mano en claro y oscuro.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
