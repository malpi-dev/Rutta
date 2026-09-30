# Fase 11 · Supabase y Realtime

**Rama:** `feat/fase-11-supabase-y-realtime`
**Objetivo:** repositorios reales de pedidos, tracking y conexión sobre Supabase con **Realtime `postgres_changes`**
(canales con prefijo `rutta:`), estado del pedido y ubicación del repartidor en vivo, relectura al reconectar y
banner "Reconnecting…", scripts de simulación y prueba en vivo con dos sesiones.
**Referencias:** definición §3.1 F3–F8 (en vivo), §7.5 (Realtime), §8.1 (DTOs), §8.4 (reconexión), §16 (tracking en vivo
y RLS verificados), §17 (Realtime en schema propio) · `CLAUDE.md` del portafolio (canales `<app>:<tema>:<id>`).
**Requisitos previos:** fase 10 terminada. Supabase local corriendo con el seed recién aplicado (`supabase db reset`).

> Al terminar, en live: el cliente ve moverse al repartidor y cambiar el estado sin refrescar; el repartidor publica su
> ubicación real; al cortar la red aparece "Reconnecting…" y al volver se relee todo.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Mappers (`data/`)

Solo donde el formato difiere del dominio (regla 7).

`lib/features/orders/data/order_mapper.dart`:

```dart
/// Columns requested for every order query. Both FKs point to profiles, so the embed needs the FK name.
const orderColumns = '*, courier:profiles!orders_courier_id_fkey(full_name), '
    'customer:profiles!orders_customer_id_fkey(full_name)';

Order orderFromRow(Map<String, dynamic> row);
OrderStatusEvent statusEventFromRow(Map<String, dynamic> row);
```

- `route` (`jsonb`) llega como `List<dynamic>` de `[lng, lat]` → `GeoPoint(lat: (e[1] as num).toDouble(), lng: (e[0] as num).toDouble())`.
  **Ojo al orden.**
- Números: `(row['pickup_lat'] as num).toDouble()`; enteros con `(… as num).toInt()`.
- `items`: lista de mapas `{name, quantity}`.
- Fechas: `DateTime.parse(row['created_at'] as String).toUtc()`.
- `courier`/`customer` embebidos pueden ser `null` → `courierName`/`customerName` `null`.
- `pickup` con `name: pickup_name`; `dropoff` sin nombre.
- Formato inesperado (falta una clave, tipo erróneo) → lanza `UnknownError(error)`.

`lib/features/tracking/data/courier_location_mapper.dart`: `CourierLocation courierLocationFromRow(Map<String, dynamic> row)`
y `Map<String, dynamic> courierLocationToUpsertRow(CourierLocation l)` → `{courier_id, order_id, lat, lng, heading, speed_mps, accuracy_m}`
(**sin** `recorded_at`: lo pone el servidor). `heading` fuera de 0..360 → `null`.

## Paso 2 · Estado de los canales (`lib/core/supabase/realtime_status_hub.dart`)

Para el banner "Reconnecting…" sin que la UI conozca Realtime:

```dart
/// Collects the subscribe status of every live channel. Connected = no channel is failing.
class RealtimeStatusHub {
  void report(String channelKey, RealtimeSubscribeStatus status);  // subscribed / channelError / timedOut / closed
  void remove(String channelKey);                                   // when a channel is removed on purpose
  Stream<bool> watchIsConnected();                                  // emits current value first, then changes (distinct)
  void dispose();
}
```

Regla: `false` si algún canal registrado está en `channelError` o `timedOut`; `true` en cualquier otro caso (incluido
sin canales). `closed` al quitar un canal a propósito no cuenta como fallo (se llama `remove` antes).

`lib/features/orders/data/supabase_connection_monitor.dart`: `SupabaseConnectionMonitor(hub)` implementa
`ConnectionMonitor` delegando en `hub.watchIsConnected()`.

## Paso 3 · Patrón de stream en vivo

Todos los `watch…` de Supabase siguen el mismo patrón (escríbelo una vez como helper en
`lib/core/supabase/live_query.dart` y reutilízalo):

```dart
/// Initial fetch + postgres_changes subscription. On every change (debounced) and on every (re)subscribe,
/// it fetches again, so nothing is lost across reconnections (definition §8.4).
Stream<T> liveQuery<T>({
  required SupabaseClient client,
  required RealtimeStatusHub hub,
  required String channelName,                 // 'rutta:<topic>:<id>' (+ unique suffix, see below)
  required Future<T> Function() fetch,
  required void Function(RealtimeChannel channel, void Function() onChange) bind,   // adds onPostgresChanges
  Duration debounce = const Duration(milliseconds: 250),
});
```

Implementación: `StreamController<T>` con `onListen`:
1. `fetch()` → `add` (errores → `addError(mapSupabaseError(e))`).
2. `channel = client.channel(channelName)`; `bind(channel, scheduleRefetch)`;
   `channel.subscribe((status, error) { hub.report(channelName, status); if (status == RealtimeSubscribeStatus.subscribed) scheduleRefetch(); })`.
3. `scheduleRefetch` usa un `Timer` de `debounce`; si llega otro cambio, reinicia el timer; ignora resultados viejos.
4. `onCancel`: cancela el timer, `hub.remove(channelName)`, `client.removeChannel(channel)`.

**Nombres de canal:** el prefijo es obligatorio (`rutta:`) porque los canales son globales al proyecto compartido.
Añade un sufijo único por suscripción (`rutta:order:<id>:<contador>`) para que dos pantallas que observan lo mismo no
choquen al unirse al mismo *topic*.

Verifica la API de la versión instalada (`onPostgresChanges`, `PostgresChangeFilter`, `PostgresChangeFilterType.eq`,
`RealtimeSubscribeStatus`) en `~/.pub-cache/hosted/pub.dev/realtime_client-*/`.

## Paso 4 · `SupabaseOrdersRepository` (`lib/features/orders/data/supabase_orders_repository.dart`)

`SupabaseOrdersRepository(client, hub, {required String userId, required UserRole role})`; siempre
`client.schema('rutta')`.

| Método | Implementación |
|---|---|
| `watchMyOrders()` | `liveQuery`: fetch `from('orders').select(orderColumns).eq(role == customer ? 'customer_id' : 'courier_id', userId).order('created_at', ascending: false)` → `map(orderFromRow)`. Canal `rutta:orders:<userId>:<n>` con `onPostgresChanges(event: all, schema: 'rutta', table: 'orders', filter: eq(<columna del rol>, userId))`. Un pedido recién asignado al repartidor llega como `UPDATE` cuyo registro nuevo casa con el filtro. |
| `watchOrder(id)` | `liveQuery`: fetch `…select(orderColumns).eq('id', id).maybeSingle()` → `null` ⇒ `NotFoundError('order', id)`. Canal `rutta:order:<id>:<n>`, filtro `id=eq.<id>`. |
| `watchStatusEvents(id)` | `liveQuery`: fetch `from('order_status_events').select('id, order_id, status, created_at').eq('order_id', id).order('created_at')`. Canal `rutta:events:<id>:<n>`, evento `insert`, filtro `order_id=eq.<id>`. |
| `advanceStatus(id, next)` | `guardSupabase(() => rpc('advance_order_status', params: {'p_order_id': id, 'p_next': next.wireName}))`; después relee el pedido con `orderColumns` (la RPC no trae los nombres embebidos) y lo devuelve. |

## Paso 5 · `SupabaseTrackingRepository` (`lib/features/tracking/data/supabase_tracking_repository.dart`)

- `watchCourierLocation(orderId)`: aquí **no** se relee en cada cambio (llega una posición cada ~5 s): fetch inicial
  `from('courier_locations').select().eq('order_id', orderId).maybeSingle()`; canal `rutta:location:<orderId>:<n>` con
  `onPostgresChanges(event: all, table: 'courier_locations', filter: eq('order_id', orderId))`; en `insert`/`update`
  emite `courierLocationFromRow(payload.newRecord)` directamente; al (re)suscribirse vuelve a hacer el fetch.
  (Realtime no entrega `DELETE` filtrados: el marcador desaparece porque el pedido deja de estar en curso.)
  Puedes reutilizar `liveQuery` con un parámetro opcional `onPayload` o escribirlo aparte.
- `publishLocation(location)`: `from('courier_locations').upsert(courierLocationToUpsertRow(location), onConflict: 'courier_id')`.
  `PostgrestException` con `code == '42501'` (RLS: pedido no en curso o no asignado) → `NoActiveOrderError`; el resto
  con `mapSupabaseError`. Timeout corto (10 s).

## Paso 6 · Providers (composition root)

```dart
@Riverpod(keepAlive: true)
RealtimeStatusHub realtimeStatusHub(Ref ref) {
  final hub = RealtimeStatusHub();
  ref.onDispose(hub.dispose);
  return hub;
}

@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) => switch (ref.watch(appModeControllerProvider)) {
  AppModeLive() => SupabaseOrdersRepository(
      ref.watch(supabaseClientProvider),
      ref.watch(realtimeStatusHubProvider),
      userId: ref.watch(currentUserIdProvider) ?? '',
      role: ref.watch(currentRoleProvider) ?? UserRole.customer,
    ),
  AppModeDemo() => MockOrdersRepository(ref.watch(demoStoreProvider)),
};
```

Igual para `trackingRepository` (`SupabaseTrackingRepository(client, hub)`) y `connectionMonitor`
(`SupabaseConnectionMonitor(hub)`). Quita los `UnimplementedError` de la fase 05. Cambiar de usuario reconstruye los
repositorios (dependen de `currentUserId`).

## Paso 7 · Relectura al volver a primer plano

Android puede cortar el socket en segundo plano. En `RuttaApp` (o un provider `keepAlive` de presentación), un
`AppLifecycleListener(onResume: …)` que, **en live**, invalida `myOrdersProvider` (y los `orderProvider`/
`orderEventsProvider` activos se re-suscriben solos al reconstruirse). Mantenlo simple: `ref.invalidate(myOrdersProvider)`
y deja que los canales hagan su fetch al resuscribirse.

## Paso 8 · Scripts de desarrollo

### 8.1 `tool/simulate_courier.sh`

Mueve al repartidor de un pedido **en curso** en Supabase **local** escribiendo en `courier_locations` como `postgres`
(sin RLS). Realtime lo entrega al cliente con sus políticas, así que basta **un** emulador con el cliente.

```bash
./tool/simulate_courier.sh RT-1042 2        # order code, seconds between points (default 2)
```

- `DB_URL` por defecto `postgresql://postgres:postgres@127.0.0.1:54322/postgres`; se niega a correr si `DB_URL` no es
  `127.0.0.1`/`localhost` (protege el proyecto compartido).
- Lee los puntos en orden: `select (p->>1) || ' ' || (p->>0) from rutta.orders o, jsonb_array_elements(o.route) with ordinality t(p, i) where o.code = '<code>' order by i;`
- Toma ~60 puntos equiespaciados (uno de cada `ceil(n/60)`), y por cada uno hace un upsert:
  `insert into rutta.courier_locations (courier_id, order_id, lat, lng, speed_mps) select courier_id, id, <lat>, <lng>, 8.3 from rutta.orders where code = '<code>' and status in ('picked_up','in_transit') on conflict (courier_id) do update set order_id = excluded.order_id, lat = excluded.lat, lng = excluded.lng, speed_mps = excluded.speed_mps;`
- Si el pedido no está en curso, avisa y sale con código 1. `set -euo pipefail`, mensajes en inglés.

### 8.2 `tool/emulator_drive.dart` (fase 08)

Para probar el lado del repartidor con GPS del emulador.

## Paso 9 · Tests

| Archivo | Qué comprueba |
|---|---|
| `test/features/orders/data/order_mapper_test.dart` | fila completa → `Order` (ruta `[lng, lat]` → `GeoPoint(lat, lng)`, números `int`/`double`, ítems, fechas UTC, nombres embebidos, `null` sin repartidor); fila incompleta → `UnknownError`; evento → `OrderStatusEvent`. |
| `test/features/tracking/data/courier_location_mapper_test.dart` | ida (fila → entidad) y vuelta (entidad → fila de upsert sin `recorded_at`); `heading` 400 → `null`. |
| `test/core/supabase/realtime_status_hub_test.dart` | sin canales → `true`; un canal `timedOut` → `false`; vuelve a `subscribed` → `true`; `remove` de un canal fallido → `true`; emite solo cambios. |
| `test/features/orders/presentation/reconnecting_banner_test.dart` | con `MockConnectionMonitor.controlled`: `false` muestra `reconnecting-banner`; `true` lo oculta. |

Integración contra Supabase local (tag `supabase`, `RUTTA_IT=1`; ejecuta `supabase db reset` justo antes) —
`test/integration/orders_realtime_test.dart`, con dos `SupabaseClient` (cliente `customer@rutta.test` y repartidor
`courier1@rutta.test`, códigos OTP leídos de Mailpit como en la fase 10):
1. El cliente ve 8 pedidos en `watchMyOrders`; el repartidor ve RT-1042, RT-1044 y RT-1038.
2. El cliente observa `watchCourierLocation(RT-1042)`; el repartidor publica una posición → el cliente la recibe en ≤ 5 s.
3. El repartidor intenta `advanceStatus(RT-1044, pickedUp)` → `CourierBusyError`.
4. El cliente intenta `publishLocation` → `NoActiveOrderError`; intenta `advanceStatus` → `NotAssignedToYouError`.
5. El cliente observa `watchOrder(RT-1042)`; el repartidor lo marca `delivered` → el cliente recibe `delivered` en ≤ 5 s
   y `watchStatusEvents` incluye el evento nuevo.
6. Cierra canales y sesiones al terminar.

## Paso 10 · Verificación manual en vivo

`supabase db reset` y `flutter run --dart-define-from-file=.env.json`.

1. **Cliente + script:** entra como `customer@rutta.test` → RT-1042 → en otra terminal
   `./tool/simulate_courier.sh RT-1042 2` → el marcador se desliza por la ruta, bajan distancia y ETA; al parar el
   script, a los 30 s aparece "Last updated…" (stale).
2. **Estado en vivo:** con la app en RT-1042, en `psql`
   `update rutta.orders set status = 'delivered' where code = 'RT-1042';` → el detalle pasa a *Delivered* sin refrescar
   y el pedido se mueve a *History*.
3. **Repartidor real:** `supabase db reset`; entra como `courier1@rutta.test` → RT-1042 (`in_transit`) → "Sharing
   location" → `dart run tool/emulator_drive.dart r1` → comprueba en `psql` que `courier_locations` cambia cada ~5 s
   (`select lat, lng, recorded_at from rutta.courier_locations;`) → *Mark as delivered* → la fila desaparece.
   Intenta *Picked up* en RT-1044 con RT-1042 en curso → "Finish your current delivery…".
4. **Dos sesiones a la vez:** abre un segundo emulador (`flutter emulators --launch <otro>`) y ejecuta la app en ambos
   (`flutter run -d emulator-5554 …` y `-d emulator-5556 …`): uno como cliente y otro como `courier1` → el cliente ve
   moverse al repartidor mientras este conduce con `dart run tool/emulator_drive.dart r1 --serial emulator-5556`. Si la máquina no aguanta dos emuladores: **🙋 Acción del autor** → probar con su
   teléfono en la misma red (en `.env.json` del teléfono, `SUPABASE_URL=http://<IP de la máquina>:54321`).
5. **Reconexión:** con el detalle del cliente abierto, activa el modo avión 20 s → aparece "Reconnecting…"; al
   desactivarlo desaparece y el estado se pone al día.
6. **RLS desde la app:** entra como `courier2@rutta.test` → no ve RT-1042 ni RT-1044.

Anota en la bitácora qué casos se probaron y en qué dispositivos.

## Paso 11 · Cierre

`00-guia-general.md` §3.3 (incluye `supabase db reset` y `supabase test db`).

---

## Criterios de terminado

- [ ] Mappers de pedido, evento y ubicación con tests (orden `[lng, lat]` cubierto).
- [ ] `liveQuery` con fetch inicial, `postgres_changes`, debounce, relectura al (re)suscribirse y limpieza de canales.
- [ ] Canales con prefijo `rutta:` y sufijo único; `RealtimeStatusHub` + banner "Reconnecting…".
- [ ] `SupabaseOrdersRepository`, `SupabaseTrackingRepository`, `SupabaseConnectionMonitor`; sin `UnimplementedError`.
- [ ] Test de integración de Realtime/RLS en verde contra Supabase local (resultado en la bitácora).
- [ ] `tool/simulate_courier.sh` (solo local); prueba en vivo con dos sesiones hecha y anotada.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
