# Rutta — Documento de definición

| Campo | Valor |
|---|---|
| **Tagline** | *Know exactly where your order is.* Delivery con la ubicación del repartidor en vivo sobre el mapa |
| **Stack** | Flutter (stable más reciente) · Riverpod · go_router · Supabase · flutter_map + OpenStreetMap |
| **Plataforma** | Android (v1.0.0) · iOS fuera de la v1.0.0 (código compatible, no verificado) |
| **Estado** | 📋 Planificado |
| **Bundle id** | `com.malpidev.rutta` *(confirmado)* |
| **Versión del documento** | 0.1 |
| **Fecha** | 2026-09-25 |

> Este documento define **qué** se construye y qué no. Es la referencia para el plan de implementación.
> Las reglas generales (arquitectura, stack, backend, seguridad, convenciones) viven en `../../CLAUDE.md`
> y prevalecen sobre este documento si hubiera contradicción.

---

## 1. Resumen del producto

**Qué es.** Rutta es una app de seguimiento de entregas con dos roles en la misma app: el **cliente** ve sus
pedidos y sigue en un mapa, en vivo, al repartidor que trae su pedido; el **repartidor** ve los pedidos que
tiene asignados, cambia su estado (recogido → en camino → entregado) y comparte su ubicación mientras entrega.

**Qué problema resuelve.** La pregunta "¿dónde está mi pedido?" genera llamadas, ansiedad y soporte. Rutta
muestra la posición real del repartidor, la ruta, la distancia restante y una línea de tiempo de estados.

**Para quién.** Negocios pequeños con reparto propio (restaurantes, farmacias, tiendas locales) que quieren una
app de seguimiento sin pagar una plataforma de delivery. En el portafolio, representa el tipo de proyecto
"logística / on-demand" que piden muchos clientes freelance.

**Qué demuestra a un cliente freelance** (los "Destaca" del CLAUDE.md):

| Capacidad | Cómo se evidencia en Rutta |
|---|---|
| Tiempo real | Ubicación del repartidor en vivo con **Supabase Realtime** (`postgres_changes` sobre `rutta.courier_locations`) y estado del pedido que se actualiza sin refrescar |
| Mapas y animación | **Marcador animado** que se desliza sobre la ruta (interpolación entre posiciones + proyección sobre la polilínea), ruta recorrida vs. restante |
| Mapas sin costo y portables | `flutter_map` + OpenStreetMap, detrás de una abstracción propia que permite cambiar a Google Maps tocando solo `lib/core/map/` |
| Geolocalización y permisos | Flujo completo de permisos de ubicación (denegado, denegado para siempre, GPS apagado) |
| Reglas de negocio en la BD | Máquina de estados validada en Postgres (RPC + trigger), historial automático, un solo pedido activo por repartidor, RLS que limita quién ve la ubicación |
| Arquitectura limpia | Repositorios intercambiables `supabase` / `mock` y **modo demo** con un repartidor simulado moviéndose sin backend |

---

## 2. Usuarios y roles

| Rol | Valor en `rutta.profiles.role` | Qué puede hacer |
|---|---|---|
| **Cliente** | `customer` | Ver la lista de sus pedidos (activos e historial) · abrir un pedido y ver el mapa con origen, destino, ruta y repartidor en vivo · ver la línea de tiempo de estados · ver nombre del repartidor asignado |
| **Repartidor** | `courier` | Ver los pedidos que tiene asignados · abrir un pedido y ver el mapa con ruta, origen y destino · avanzar el estado (`assigned → picked_up → in_transit → delivered`) · compartir su ubicación (automático mientras tiene un pedido en curso y la pantalla está en primer plano) |

**Decisión: no hay rol admin/despacho dentro de la app.** El alcance del MVP solo nombra cliente y repartidor.
La creación de pedidos y su asignación a un repartidor se hacen **fuera de la app**: con `seed.sql` en local y con
un script SQL (`supabase/scripts/create_sample_orders.sql`) o la RPC `rutta.admin_assign_order` ejecutada con la
secret key / desde el SQL editor en remoto. Justificación: una consola de despacho es una tercera experiencia
completa (lista de repartidores, mapa global, asignación) que duplicaría el esfuerzo y no aporta a lo que se quiere
demostrar (tracking en vivo). Queda en el Roadmap.

**Asignación de rol.** Todo usuario nuevo nace como `customer` (trigger al registrarse). El rol `courier` solo se
asigna por SQL (no hay auto-promoción desde el cliente; RLS lo impide). En **modo demo**, quien revisa elige
"Explore as customer" o "Explore as courier".

---

## 3. Alcance del MVP

### 3.1 Incluye

| # | Feature | Descripción | Criterios de aceptación |
|---|---|---|---|
| F1 | **Auth** | Email + código OTP de 6 dígitos (convención común de las 4 apps, sin contraseñas); onboarding de nombre; cierre de sesión; sesión persistente | - Un email nuevo recibe el código, lo introduce y, tras escribir su nombre, queda con perfil `customer` (RPC `ensure_profile`). <br>- Al reabrir la app con sesión válida, entra directo a su home según rol. <br>- Código incorrecto o caducado muestra un error legible (no el mensaje crudo del SDK). <br>- Cerrar sesión vuelve al login y limpia el estado. |
| F2 | **Modo demo** | Botón *Explore demo* en el login → elegir rol → la app usa repositorios mock | - Funciona en modo avión. <br>- Como cliente, hay un pedido `in_transit` cuyo repartidor se mueve solo sobre la ruta y termina en `delivered`. <br>- Como repartidor, puede avanzar estados y ve su marcador moverse (posición simulada). <br>- Un banner "Demo mode" es visible y permite salir al login. |
| F3 | **Lista de pedidos (cliente)** | Pedidos del cliente agrupados en *Active* e *History* | - Muestra código, comercio de origen, estado (chip de color), hora y total. <br>- Un cambio de estado hecho por el repartidor se refleja sin refrescar (Realtime). <br>- Pull-to-refresh. Estados de carga, vacío y error. |
| F4 | **Seguimiento en el mapa (cliente)** | Detalle del pedido con mapa, ruta, marcadores y panel inferior | - Se ven origen, destino y la ruta. <br>- Con el pedido en `picked_up` o `in_transit`, el marcador del repartidor aparece y se **anima** a cada nueva posición (sin saltos). <br>- La ruta se divide en recorrida (atenuada) y restante. <br>- Muestra distancia restante y ETA aproximada. <br>- Si la última posición tiene > 30 s, se indica "Last updated X s ago". <br>- Botón para recentrar la cámara en el repartidor. |
| F5 | **Línea de tiempo de estados** | Lista vertical de estados con hora, en el detalle (cliente y repartidor) | - Cada transición aparece con su hora exacta, generada por la BD (no por el cliente). <br>- Los estados futuros se muestran atenuados. <br>- `cancelled` se muestra como estado terminal si ocurre. |
| F6 | **Pedidos asignados (repartidor)** | Lista de pedidos asignados al repartidor, activos arriba | - Solo ve pedidos donde `courier_id` = él. <br>- Un pedido nuevo asignado aparece sin refrescar (Realtime). <br>- Estados de carga, vacío y error. |
| F7 | **Cambiar estado (repartidor)** | Botón principal contextual en el detalle: *Picked up* → *Start delivery* → *Mark as delivered* | - Solo se ofrecen transiciones válidas. <br>- La transición se valida en la BD (RPC); si falla, se muestra un error tipado y el estado no cambia. <br>- *Mark as delivered* pide confirmación. <br>- No se puede iniciar un segundo pedido en curso si ya hay uno (error `CourierBusy`). |
| F8 | **Compartir ubicación (repartidor)** | Envío de la posición GPS mientras hay un pedido en `picked_up`/`in_transit` y la app está en primer plano | - Envía como máximo 1 posición cada **5 s** y solo si se movió ≥ **10 m** (o cada 30 s como latido aunque no se mueva). <br>- Indicador visible "Sharing location" con opción de pausar. <br>- Al pasar a `delivered`, deja de enviar y la BD borra su última posición. <br>- La pantalla se mantiene encendida durante la entrega en curso. |
| F9 | **Permisos de ubicación** | Flujo de solicitud "while in use" para el repartidor | - Antes del diálogo del sistema se muestra una explicación propia. <br>- Casos cubiertos: concedido, denegado (reintentar), denegado para siempre (abrir ajustes), GPS apagado (abrir ajustes de ubicación). <br>- Sin permiso, el repartidor puede cambiar estados pero ve un aviso de que el cliente no lo verá en el mapa. <br>- El cliente **nunca** pide permiso de ubicación. |
| F10 | **Ajustes y tema** | Tema claro/oscuro/sistema, cuenta, salir de demo, créditos de mapas | - El tema se persiste entre sesiones. <br>- El mapa usa estilo oscuro en modo oscuro. <br>- Se muestran créditos © OpenStreetMap contributors. |

### 3.2 Fuera del MVP

| Excluido | Por qué |
|---|---|
| Crear pedidos desde la app (checkout, carrito, pagos) | Eso es Vitrina; Rutta se enfoca en el tracking. Los pedidos vienen del seed / SQL. |
| Panel de despacho / rol admin | Ver sección 2; triplica las pantallas sin aportar al "Destaca". |
| Ubicación en **segundo plano** | Requiere `ACCESS_BACKGROUND_LOCATION`, foreground service con notificación, revisión de política en Google Play y background modes en iOS; alto costo y riesgo para un demo. |
| Cálculo de rutas en tiempo de ejecución (llamar a OSRM/Google desde la app) | Las rutas se precalculan al crear el pedido (seed/script). Evita depender de un servicio público sin SLA. |
| Recalcular ruta si el repartidor se desvía | Depende del punto anterior. |
| Notificaciones push | Necesitan Edge Function + FCM/APNs; Agendo ya demuestra push en el portafolio. |
| Chat o llamada cliente ↔ repartidor | Fuera del objetivo de demostración. |
| Varios pedidos en curso a la vez por repartidor (batching) | Complica RLS, rutas y UI; la BD impone uno a la vez. |
| Prueba de entrega (foto/firma) | Requiere Storage y cámara; no es parte de "Incluye". |
| Calificaciones y propinas | Fuera de alcance. |
| Historial de posiciones / replay del recorrido | Se guarda solo la última posición (privacidad y cuota del plan gratuito). |
| Modo offline / caché local (Drift) | El tracking es intrínsecamente en línea; ver sección 9. |
| Web y desktop | Plataformas no objetivo. |
| Internacionalización | UI solo en inglés (convención del portafolio). |

### 3.3 Futuro / Roadmap

- Panel de despacho (rol `dispatcher`): crear pedidos, asignar repartidor, mapa con toda la flota.
- Ubicación en segundo plano con foreground service.
- Rutas en tiempo de ejecución con un proveedor configurable (OSRM propio, OpenRouteService, Google Directions) y re-ruteo.
- ETA basada en tráfico / velocidad real del repartidor.
- Push al cambiar de estado ("Your order is on the way").
- Prueba de entrega con foto (Supabase Storage).
- Chat cliente ↔ repartidor (Realtime Broadcast).
- Proveedor de mapas Google Maps (`google_maps_flutter`) como segunda implementación de la abstracción de mapa.
- Replay del recorrido y métricas del repartidor.

---

## 4. Módulos / features

| Feature (carpeta) | Descripción | Pantallas | ¿MVP? |
|---|---|---|---|
| `auth` | Email + código OTP, onboarding de nombre, sesión, perfil y rol | `LoginScreen`, `VerifyCodeScreen`, `OnboardingScreen` | Sí |
| `demo` (transversal) | Entrada al modo demo, elección de rol, simulador de repartidor | `DemoRolePickerSheet` (bottom sheet sobre login) | Sí |
| `orders` | Lista y detalle de pedidos, línea de tiempo, transición de estados | `CustomerOrdersScreen`, `CourierOrdersScreen`, `OrderDetailScreen` (variante por rol) | Sí |
| `tracking` | Ubicación del repartidor: publicar (repartidor) y suscribirse (cliente); progreso sobre la ruta y ETA | Componentes dentro de `OrderDetailScreen` (`TrackingMap`, `TrackingPanel`) | Sí |
| `location_permission` (transversal) | Estado del permiso y del GPS, explicación previa, enlaces a ajustes | `LocationPermissionSheet` | Sí |
| `settings` (transversal) | Tema, cuenta, salir de demo, créditos | `SettingsScreen` | Sí |
| `core/map` (transversal) | Abstracción del mapa (`RuttaMap`) e implementación `flutter_map` | — | Sí |
| `dispatch` | Crear/asignar pedidos | — | No |
| `notifications` | Push de cambios de estado | — | No |
| `proof_of_delivery` | Foto/firma al entregar | — | No |

---

## 5. Flujos de usuario y navegación

### 5.1 Flujos principales

**A. Cliente sigue su pedido (flujo feliz)**
1. Abre la app → sesión válida → `/customer/orders`.
2. Ve en *Active* el pedido `RT-1042` con estado `in_transit`. Toca la tarjeta.
3. `/customer/orders/:id`: mapa encuadrado a la ruta, marcador de origen (tienda), destino (casa) y repartidor.
4. Cada ~5 s llega una posición por Realtime → el marcador se desliza hasta ella; la ruta recorrida se atenúa; baja la distancia restante y la ETA.
5. El repartidor marca *delivered* → la línea de tiempo añade "Delivered 14:32", el marcador del repartidor desaparece y aparece un estado "Delivered".
6. Vuelve atrás: el pedido pasó a *History*.

**B. Repartidor entrega un pedido**
1. Login → `/courier/orders`. Ve `RT-1042` en estado `assigned`.
2. Abre el detalle: mapa con ruta; botón *Picked up*.
3. Toca *Picked up* → si no hay permiso de ubicación, aparece `LocationPermissionSheet` → concede "while in use".
4. Estado `picked_up`; empieza a compartir ubicación (indicador "Sharing location"). Botón *Start delivery*.
5. *Start delivery* → `in_transit`. Conduce; la app envía posiciones (5 s / 10 m).
6. *Mark as delivered* → confirmación → `delivered`. Se detiene el envío; la BD borra su última posición.

**C. Explorar demo**
1. Login → *Explore demo* → sheet: *Explore as customer* / *Explore as courier*.
2. La app cambia los repositorios a mock (sin red) y navega al home del rol elegido, con banner *Demo mode*.
3. Cliente: el pedido activo tiene un repartidor simulado recorriendo la ruta (~1 min de recorrido); al llegar, el mock pasa el pedido a `delivered`.
4. Repartidor: al avanzar estados, el simulador mueve su propio marcador por la ruta (no usa GPS, así funciona en emulador).
5. *Exit demo* (banner o ajustes) → vuelve al login y restaura los repositorios reales.

**D. Permiso denegado para siempre**
1. Repartidor toca *Picked up* sin permiso y con denegación permanente.
2. El sheet explica y ofrece *Open settings*. Si continúa sin permiso, el estado sí cambia pero aparece el aviso "Customer can't see your location".

### 5.2 Mapa de rutas (go_router)

```
/                         → redirect según sesión/rol/demo
/login                    LoginScreen (+ DemoRolePickerSheet)
/verify                   VerifyCodeScreen (código de 6 dígitos)
/onboarding               OnboardingScreen (nombre; sesión sin perfil)
/customer/orders          CustomerOrdersScreen         [rol customer]
/customer/orders/:id      OrderDetailScreen(customer)  [rol customer]
/courier/orders           CourierOrdersScreen          [rol courier]
/courier/orders/:id       OrderDetailScreen(courier)   [rol courier]
/settings                 SettingsScreen               [autenticado o demo]
```

Reglas de `redirect`:
- Sin sesión y sin demo → `/login` (excepto `/login` y `/verify`).
- Con sesión pero sin perfil de Rutta → `/onboarding`.
- Con sesión o demo en `/login` → home del rol (`/customer/orders` o `/courier/orders`).
- Un rol que intente abrir rutas del otro rol → su propio home.
- El `refreshListenable` escucha el estado de sesión (`authStateProvider`) y el modo de la app (`appModeProvider`).

`LocationPermissionSheet` y `DemoRolePickerSheet` son bottom sheets, no rutas.

---

## 6. Modelo de dominio

### 6.1 Entidades (freezed, sin dependencias de Supabase ni de Flutter)

| Entidad | Campos clave | Notas |
|---|---|---|
| `UserProfile` | `id`, `fullName`, `role: UserRole`, `phone?` | `UserRole { customer, courier }` |
| `GeoPoint` | `lat`, `lng` | Tipo propio del dominio; **no** se usa `LatLng` de `latlong2` en `domain/` (así el mapa es intercambiable). |
| `Place` | `name`, `address`, `point: GeoPoint` | Origen (pickup) y destino (dropoff). |
| `Order` | `id`, `code`, `customerId`, `courierId?`, `courierName?`, `status: OrderStatus`, `pickup: Place`, `dropoff: Place`, `items: List<OrderItem>`, `totalCents`, `route: List<GeoPoint>`, `routeDistanceMeters`, `routeDurationSeconds`, `createdAt`, `updatedAt` | `route` es la polilínea precalculada. |
| `OrderItem` | `name`, `quantity` | Solo informativo. |
| `OrderStatusEvent` | `id`, `orderId`, `status`, `createdAt` | Historial para la línea de tiempo. |
| `CourierLocation` | `courierId`, `orderId`, `point`, `heading?`, `speedMps?`, `accuracyMeters?`, `recordedAt` | Última posición conocida. |
| `RouteProgress` | `snappedPoint`, `segmentIndex`, `traveledMeters`, `remainingMeters`, `eta: Duration`, `isOffRoute` | Resultado de un caso de uso (no se persiste). |

Relaciones: `UserProfile (customer) 1—N Order`, `UserProfile (courier) 1—N Order`, `Order 1—N OrderStatusEvent`,
`UserProfile (courier) 1—0..1 CourierLocation` (asociada al pedido en curso).

### 6.2 Máquina de estados del pedido

```
            ┌──────────┐ assign ┌──────────┐ pick up ┌───────────┐ start ┌────────────┐ deliver ┌───────────┐
            │ created  │───────▶│ assigned │────────▶│ picked_up │──────▶│ in_transit │────────▶│ delivered │
            └────┬─────┘        └────┬─────┘         └───────────┘       └────────────┘         └───────────┘
                 │ cancel            │ cancel
                 ▼                   ▼
            ┌───────────┐
            │ cancelled │
            └───────────┘
```

| Desde | Hacia | Quién | Dónde ocurre en el MVP |
|---|---|---|---|
| `created` | `assigned` | admin (SQL / secret key) | `rutta.admin_assign_order` |
| `assigned` | `picked_up` | repartidor asignado | App (RPC `advance_order_status`) |
| `picked_up` | `in_transit` | repartidor asignado | App |
| `in_transit` | `delivered` | repartidor asignado | App |
| `created` / `assigned` | `cancelled` | admin | SQL (sin UI) |

- `delivered` y `cancelled` son terminales.
- **Activos** = `created`, `assigned`, `picked_up`, `in_transit`. **En curso** (con ubicación visible) = `picked_up`, `in_transit`.
- La tabla de transiciones existe **dos veces a propósito**: en Dart (`OrderStatus.canTransitionTo`) para decidir qué
  botón mostrar, y en SQL (fuente de verdad). Los tests verifican que coinciden.

### 6.3 Reglas de negocio

1. Solo el repartidor asignado puede avanzar el estado de un pedido, y solo por transiciones válidas.
2. Un repartidor tiene **como máximo un pedido en curso** (`picked_up`/`in_transit`) a la vez.
3. Solo se publica ubicación con un pedido en curso; el cliente solo ve la ubicación del repartidor **de su propio pedido en curso**.
4. Al terminar el pedido (`delivered`/`cancelled`) se borra la última posición del repartidor.
5. Cada cambio de estado genera un `OrderStatusEvent` con hora del servidor.
6. Throttling de envío: ≥ 5 s entre envíos y ≥ 10 m de desplazamiento, con latido cada 30 s.
7. Una posición con más de 30 s se considera *stale* (se muestra como tal, no se oculta).

### 6.4 Casos de uso (solo donde hay lógica real)

| Caso de uso | Lógica | Feature |
|---|---|---|
| `ComputeRouteProgress` | Proyecta la posición del repartidor sobre el segmento más cercano de la polilínea; calcula metros recorridos/restantes (haversine), ETA = restante / velocidad (velocidad real si es fiable, si no 25 km/h), y `isOffRoute` si la distancia a la ruta > 75 m | `tracking` |
| `ShouldSendLocation` | Decide si una nueva lectura GPS se envía (5 s / 10 m / latido 30 s; descarta precisión > 50 m) | `tracking` |
| `AvailableOrderActions` | Dado el rol, el estado y si el repartidor ya tiene otro pedido en curso, devuelve la acción primaria permitida | `orders` |
| `DemoCourierSimulator` *(data/mock)* | Genera posiciones a lo largo de la polilínea a velocidad constante con ligera variación; vive en `data/` porque es una implementación mock, no dominio | `tracking` |

No se crean casos de uso para "listar pedidos" o "obtener pedido": la presentación llama al repositorio.

### 6.5 Interfaces de repositorio (domain)

```dart
abstract interface class AuthRepository {
  Stream<UserProfile?> watchCurrentUser();
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<UserProfile?> getMyProfile();                 // null si aún no tiene perfil de Rutta
  Future<UserProfile> ensureProfile(String fullName);  // RPC rutta.ensure_profile
  Future<void> signOut();
}

abstract interface class OrdersRepository {
  Stream<List<Order>> watchMyOrders();                 // según rol
  Stream<Order> watchOrder(String orderId);
  Stream<List<OrderStatusEvent>> watchStatusEvents(String orderId);
  Future<Order> advanceStatus(String orderId, OrderStatus next);
}

abstract interface class TrackingRepository {
  Stream<CourierLocation?> watchCourierLocation(String orderId);   // cliente
  Future<void> publishLocation(CourierLocation location); // repartidor
}

abstract interface class DeviceLocationRepository {
  Future<LocationAccess> checkAccess();      // granted | denied | deniedForever | serviceDisabled
  Future<LocationAccess> requestAccess();
  Stream<GeoPoint> watchPosition();          // con heading/speed/accuracy
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}
```

`DeviceLocationRepository` tiene implementación `geolocator` y `mock` (el mock emite posiciones del simulador).

### 6.6 Errores de dominio tipados

Convención común (regla 6 del `CLAUDE.md`): los repositorios **lanzan** un `DomainError` tipado; no devuelven `Result`.
`DomainError` es una `sealed class` en `lib/core/errors/domain_error.dart`; Riverpod (`AsyncValue.guard`) captura la
excepción y la UI hace `switch` exhaustivo sobre ella.

| Grupo | Variantes (`code`) |
|---|---|
| Comunes | `Network`, `Unauthorized`, `NotFound`, `Conflict`, `Validation`, `Unknown` |
| Auth | `InvalidCode`, `CodeExpired` |
| Pedidos | `InvalidTransition(from, to)`, `NotAssignedToYou`, `CourierBusy` |
| Tracking | `NoActiveOrder`, `LocationPermissionDenied`, `LocationServiceDisabled` |

Los repositorios `supabase_*` traducen `PostgrestException`/`AuthException` a estas variantes. Las RPCs lanzan
errores con `SQLSTATE` y mensajes con prefijo conocido (p. ej. `RUTTA_INVALID_TRANSITION`, `RUTTA_COURIER_BUSY`)
para que el mapeo sea determinista.

---

## 7. Backend: uso de Supabase

### 7.1 Schema `rutta` y tablas

Sin PostGIS: coordenadas como `double precision` y ruta como `jsonb`. Los cálculos geométricos se hacen en el
cliente (dominio) y el volumen es mínimo. PostGIS queda como mejora futura.

**`rutta.profiles`**

| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `uuid` | PK, FK → `auth.users(id)` on delete cascade |
| `full_name` | `text` | not null, `char_length between 1 and 80` |
| `role` | `text` | not null, default `'customer'`, check in (`customer`, `courier`) |
| `phone` | `text` | null |
| `created_at` | `timestamptz` | default `now()` |

**`rutta.orders`**

| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `uuid` | PK, default `gen_random_uuid()` |
| `code` | `text` | unique, not null (p. ej. `RT-1042`) |
| `customer_id` | `uuid` | not null, FK → `rutta.profiles` |
| `courier_id` | `uuid` | null, FK → `rutta.profiles` |
| `status` | `text` | not null, default `'created'`, check in (`created`,`assigned`,`picked_up`,`in_transit`,`delivered`,`cancelled`) |
| `pickup_name`, `pickup_address` | `text` | not null |
| `pickup_lat`, `pickup_lng` | `double precision` | check rango (−90..90, −180..180) |
| `dropoff_address` | `text` | not null |
| `dropoff_lat`, `dropoff_lng` | `double precision` | check rango |
| `items` | `jsonb` | not null, check `jsonb_typeof(items) = 'array'` |
| `total_cents` | `integer` | check `>= 0` |
| `route` | `jsonb` | not null, array de `[lng, lat]` (orden GeoJSON), check `jsonb_array_length(route) >= 2` |
| `route_distance_m`, `route_duration_s` | `integer` | check `> 0` |
| `created_at`, `updated_at` | `timestamptz` | default `now()`; `updated_at` por trigger |

Constraints adicionales:
- `check (status in ('created','cancelled') or courier_id is not null)` — no hay estados de reparto sin repartidor.
- Índice único parcial `one_active_order_per_courier on orders(courier_id) where status in ('picked_up','in_transit')` → regla 2.
- Índices en `customer_id` y `courier_id`.

**`rutta.order_status_events`**

| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `bigint` | identity PK |
| `order_id` | `uuid` | FK → `rutta.orders` on delete cascade |
| `status` | `text` | mismo check que `orders.status` |
| `changed_by` | `uuid` | null (null = sistema/admin) |
| `created_at` | `timestamptz` | default `now()` |

**`rutta.courier_locations`** (una fila por repartidor: última posición)

| Columna | Tipo | Constraints |
|---|---|---|
| `courier_id` | `uuid` | PK, FK → `rutta.profiles` |
| `order_id` | `uuid` | not null, FK → `rutta.orders` on delete cascade |
| `lat`, `lng` | `double precision` | check rango |
| `heading` | `real` | null, check `0..360` |
| `speed_mps` | `real` | null, check `>= 0` |
| `accuracy_m` | `real` | null |
| `recorded_at` | `timestamptz` | not null, default `now()` |

### 7.2 RLS (activado en las 4 tablas; cada política comentada en la migración)

Funciones auxiliares `security definer` con `search_path` fijo para evitar recursión de RLS:
`rutta.current_role()` (rol del usuario actual) y `rutta.is_order_customer(order_id)`.

| Tabla | Política | Operación | Qué protege |
|---|---|---|---|
| `profiles` | `profiles_select_own` | select | Cada usuario lee su propio perfil. |
| `profiles` | `profiles_select_counterpart` | select | El cliente lee el perfil del repartidor de sus pedidos; el repartidor lee el del cliente de sus pedidos asignados. Nadie lista perfiles ajenos. |
| `profiles` | `profiles_update_own` | update | Solo `full_name`/`phone` de sí mismo; `with check` impide cambiar `role` (se compara con el valor actual vía `current_role()`). |
| `profiles` | — | insert/delete | Sin políticas: el perfil solo se crea con la RPC `ensure_profile()` (`security definer`). |
| `orders` | `orders_select_customer` | select | `customer_id = auth.uid()`. |
| `orders` | `orders_select_courier` | select | `courier_id = auth.uid()`. |
| `orders` | — | insert/update/delete | **Sin políticas**: nadie modifica pedidos directamente; los cambios pasan por RPCs. |
| `order_status_events` | `events_select_participants` | select | Solo cliente o repartidor del pedido. Sin insert/update/delete (los escribe el trigger). |
| `courier_locations` | `locations_select_own` | select | El repartidor lee su propia fila. |
| `courier_locations` | `locations_select_customer_active` | select | El cliente ve la fila solo si `order_id` es un pedido suyo **en curso** (`picked_up`/`in_transit`). Terminado el pedido, deja de verla. |
| `courier_locations` | `locations_upsert_courier` | insert/update | `courier_id = auth.uid()`, rol `courier`, y `order_id` es un pedido asignado a él y en curso (`with check`). Impide publicar ubicación ajena o sin pedido activo. |
| `courier_locations` | — | delete | Sin política: el borrado lo hace el trigger al terminar el pedido. |

Grants: `usage` en el schema `rutta` y los privilegios mínimos por tabla para `authenticated`; `anon` sin acceso a tablas.

### 7.3 Lógica en BD

| Objeto | Tipo | Qué hace |
|---|---|---|
| `rutta.ensure_profile(p_full_name text)` | RPC `security definer`, idempotente | Crea `rutta.profiles` para `auth.uid()` con rol `customer` si no existe; si existe, lo devuelve sin cambios. Único camino para crear perfiles: **no** hay trigger sobre `auth.users` (compartido entre las apps; convención del `CLAUDE.md`). |
| `rutta.is_valid_transition(from, to)` | función `immutable` | Tabla de transiciones de la sección 6.2. |
| `rutta.advance_order_status(p_order_id uuid, p_next text)` | RPC `security definer` | Verifica rol `courier`, que el pedido le pertenece y que la transición es válida; actualiza `status`. Errores: `RUTTA_NOT_FOUND`, `RUTTA_NOT_ASSIGNED`, `RUTTA_INVALID_TRANSITION`, `RUTTA_COURIER_BUSY` (violación del índice único parcial). Devuelve el pedido actualizado. |
| `rutta.admin_assign_order(p_order_id, p_courier_id)` | RPC, `execute` revocado a `anon`/`authenticated` | `created → assigned`. Solo con secret key / SQL editor. |
| `rutta.orders_guard_status()` | trigger `before update on orders` | Defensa en profundidad: rechaza cualquier cambio de `status` inválido aunque venga de otra ruta; actualiza `updated_at`. |
| `rutta.orders_log_status()` | trigger `after insert or update of status on orders` | Inserta en `order_status_events` (`changed_by = auth.uid()`). |
| `rutta.orders_clear_location()` | trigger `after update of status on orders` | Al pasar a `delivered`/`cancelled`, borra la fila de `courier_locations` de ese repartidor. |

### 7.4 Auth, perfiles y roles

- Método (convención común de las 4 apps): **email + código OTP de 6 dígitos** — `signInWithOtp(email: …, shouldCreateUser: true)`
  y `verifyOTP(type: OtpType.email, …)`. Sin contraseñas ni magic link: no hay deep links de auth.
- Configuración compartida del proyecto: "Confirm email" activado, plantilla de email genérica con `{{ .Token }}`,
  SMTP por defecto de Supabase (solo entrega a miembros del equipo; ver `CLAUDE.md`). En local los correos llegan a la bandeja de Supabase (Inbucket/Mailpit).
- Tras verificar, se lee `rutta.profiles`; si no existe (usuario nuevo o que viene de otra app del portafolio),
  el router lleva a `/onboarding`, que pide el nombre y llama a `rutta.ensure_profile(full_name)` → perfil `customer`.
- Promover a `courier`: `update rutta.profiles set role = 'courier' where id = ...` desde SQL editor.

### 7.5 Realtime, Storage y Edge Functions

| Servicio | ¿Se usa? | Detalle |
|---|---|---|
| **Realtime `postgres_changes`** | Sí | Publicación `supabase_realtime` incluye `rutta.courier_locations`, `rutta.orders` y `rutta.order_status_events`. El cliente se suscribe con `filter` por `courier_id`/`order_id`/`customer_id`, en canales con prefijo de la app (`rutta:order:<order_id>`, `rutta:location:<order_id>`) porque los nombres de canal son globales al proyecto compartido. Realtime respeta RLS, por lo que la política de la sección 7.2 limita quién recibe posiciones. |
| Realtime Broadcast / Presence | No | Se prefiere `postgres_changes` porque persiste la última posición (al abrir el detalle hay valor inicial sin esperar al siguiente envío) y reutiliza RLS. Broadcast queda como optimización futura si el volumen creciera. |
| Storage | No | No hay imágenes en el MVP (sin avatares ni prueba de entrega). |
| Edge Functions | No | Ninguna operación necesita clave secreta: rutas precalculadas y sin push. Cumple la regla "Edge Functions solo cuando se necesita una clave secreta". |

Carga estimada: 1 escritura cada 5 s por repartidor activo; con pocos repartidores de prueba está muy por debajo de los límites del plan gratuito.

### 7.6 Migraciones, seed y entornos

- `supabase/migrations/<timestamp>_rutta_init.sql`: schema, tablas, índices, funciones, triggers, RLS, grants y publicación Realtime. Solo toca el schema `rutta` .
- `supabase/seed.sql` (local): 1 cliente y 2 repartidores de prueba en `auth.users` con su perfil (entran por OTP; el código llega a la bandeja local), 8 pedidos en Ciudad de México (CDMX) cubriendo todos los estados, con rutas reales precalculadas.
- `supabase/scripts/create_sample_orders.sql`: para remoto; recibe los UUID del cliente y repartidor (creados manualmente en el proyecto compartido) y crea/asigna pedidos de muestra.
- `tool/fetch_routes.dart`: script de desarrollo que llama **una vez** a OSRM por cada par origen/destino del seed y escribe las polilíneas en un JSON que se pega en `seed.sql` y en los fixtures del mock. No se ejecuta en la app ni en CI.
- **Local:** `supabase start` + `supabase db reset` (aplica migraciones + seed).
- **Remoto:** `psql "$SUPABASE_DB_URL" -f supabase/migrations/<archivo>.sql`, luego el script de pedidos de muestra. **Nunca `supabase db push`** (historial de migraciones compartido entre repos).
- Exponer `rutta` en *API settings → Exposed schemas* del proyecto remoto y en `supabase/config.toml` (`[api] schemas`) en local.

---

## 8. Arquitectura

### 8.1 Capas y reglas de dependencia

- `domain/`: entidades freezed, interfaces de repositorio, casos de uso, errores tipados. Solo depende de Dart y de
  `freezed_annotation`. No importa `supabase_flutter`, `flutter_map`, `latlong2`, `geolocator` ni Flutter.
- `data/`: `supabase_*_repository.dart`, `mock_*_repository.dart`, DTOs/mappers **solo** donde el formato difiere
  (fila plana de `orders` → `Order` con `Place` anidados y `route` `[lng,lat]` → `List<GeoPoint>`).
- `presentation/`: pantallas, widgets y providers de Riverpod. Nunca llama a Supabase: usa repositorios vía providers.
- Dependencias apuntan hacia `domain`. `core/` es compartido y no depende de features.

### 8.2 Árbol de archivos (ejemplo)

```
Rutta/
├── lib/
│   ├── main.dart
│   ├── app.dart                         # MaterialApp.router, tema
│   ├── core/
│   │   ├── config/env.dart              # lee String.fromEnvironment
│   │   ├── supabase/supabase_client.dart# init + supabase.schema('rutta')
│   │   ├── router/app_router.dart       # go_router + redirect por rol/demo
│   │   ├── theme/                       # app_theme.dart, colors.dart
│   │   ├── map/
│   │   │   ├── rutta_map.dart           # widget abstracto + RuttaMapController
│   │   │   ├── map_models.dart          # MapMarker, MapPolyline (usan GeoPoint)
│   │   │   └── flutter_map/flutter_map_rutta_map.dart  # única implementación en el MVP
│   │   ├── app_mode.dart                # AppMode { live, demo } + provider
│   │   ├── errors/domain_error.dart   # sealed class DomainError
│   │   └── utils/geo.dart               # haversine, proyección a segmento
│   └── features/
│       ├── auth/{domain,data,presentation}/
│       ├── orders/
│       │   ├── domain/  order.dart, order_status.dart, orders_repository.dart,
│       │   │            available_order_actions.dart
│       │   ├── data/    supabase_orders_repository.dart, mock_orders_repository.dart,
│       │   │            order_dto.dart, demo_fixtures.dart
│       │   └── presentation/ customer_orders_screen.dart, courier_orders_screen.dart,
│       │                     order_detail_screen.dart, widgets/status_timeline.dart, providers.dart
│       ├── tracking/
│       │   ├── domain/  courier_location.dart, tracking_repository.dart,
│       │   │            device_location_repository.dart, compute_route_progress.dart,
│       │   │            should_send_location.dart
│       │   ├── data/    supabase_tracking_repository.dart, mock_tracking_repository.dart,
│       │   │            geolocator_device_location_repository.dart, demo_courier_simulator.dart
│       │   └── presentation/ tracking_map.dart, animated_courier_marker.dart,
│       │                     tracking_panel.dart, location_publisher.dart (provider)
│       ├── location_permission/presentation/location_permission_sheet.dart
│       └── settings/presentation/settings_screen.dart
├── test/                                # espejo de lib/features/*
├── integration_test/                    # (opcional)
├── .maestro/
│   ├── customer_demo_tracking.yaml
│   └── courier_demo_delivery.yaml
├── supabase/
│   ├── config.toml
│   ├── migrations/<ts>_rutta_init.sql
│   ├── seed.sql
│   └── scripts/create_sample_orders.sql
├── tool/fetch_routes.dart
├── assets/{icon,splash,fonts}/
├── docs/definicion.md
├── .github/workflows/{ci.yaml,release.yaml}
├── .env.example
├── analysis_options.yaml
└── README.md
```

### 8.3 Repositorios intercambiables y modo demo

- Cada interfaz tiene `Supabase*Repository` y `Mock*Repository` (más `GeolocatorDeviceLocationRepository` / `MockDeviceLocationRepository`).
- `appModeProvider` (`AppMode.live | AppMode.demo(role)`) es un `Notifier`. Cada provider de repositorio lo observa:

```dart
@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) => switch (ref.watch(appModeProvider)) {
  AppModeLive() => SupabaseOrdersRepository(ref.watch(supabaseClientProvider)),
  AppModeDemo() => ref.watch(mockOrdersRepositoryProvider),
};
```

- *Explore demo* → `appModeProvider.enterDemo(role)`; los providers dependientes se reconstruyen y el router redirige. *Exit demo* vuelve a `live` y descarta el estado mock.
- **Simulación sin backend:** `DemoCourierSimulator` recorre la polilínea del pedido activo emitiendo una posición por segundo a ~30 km/h (acelerado para que el recorrido dure ~60 s). `MockTrackingRepository` expone ese stream; al llegar al destino, `MockOrdersRepository` pasa el pedido a `delivered` y emite el evento. En rol repartidor, `MockDeviceLocationRepository` usa el mismo simulador en lugar del GPS y el permiso se reporta como concedido.
- En tests se usan los mismos mocks (o `mocktail` cuando se necesita verificar interacciones).
- **Mapa intercambiable:** las pantallas solo conocen `RuttaMap` (props: `markers`, `polylines`, `initialBounds`, `controller`, `darkMode`) con tipos propios (`GeoPoint`). `FlutterMapRuttaMap` convierte a `LatLng` y usa `TileLayer`/`PolylineLayer`/`MarkerLayer`. Cambiar a Google Maps = añadir `GoogleRuttaMap` y cambiar un provider; el README lo explicará.

### 8.4 Gestión de estado, streams en vivo y errores

- Riverpod con `riverpod_generator` (`@riverpod`). Streams del repositorio → providers `Stream` (`watchOrder`, `watchCourierLocation`), consumidos con `AsyncValue.when` (carga/error/datos).
- Acciones (avanzar estado) en `AsyncNotifier` con `AsyncValue.guard`: el `DomainError` lanzado por el repositorio queda en el estado, se muestra en SnackBar y el botón vuelve a habilitarse.
- `LocationPublisher` (Notifier `keepAlive` mientras hay pedido en curso): escucha `DeviceLocationRepository.watchPosition()`, filtra con `ShouldSendLocation` y llama a `publishLocation`. Se pausa con `AppLifecycleState.paused` y se reanuda al volver (coherente con "solo primer plano"). Activa `wakelock_plus` durante la entrega.
- `AnimatedCourierMarker`: `AnimationController` que interpola lat/lng entre la posición anterior y la nueva (duración ≈ intervalo de envío, curva lineal) y rota según `heading`. La posición mostrada se proyecta sobre la ruta con `ComputeRouteProgress` salvo si `isOffRoute`.
- Realtime: al perder conexión se muestra un banner "Reconnecting…"; al reconectar se vuelve a leer el estado actual (fetch inicial + suscripción) para no perder eventos.
- Estado de cliente mínimo (tema) en `shared_preferences`.

---

## 9. Stack y dependencias principales

| Paquete | Para qué |
|---|---|
| `flutter_riverpod`, `riverpod_annotation` / dev: `riverpod_generator` | Estado e inyección de dependencias |
| `go_router` | Navegación y redirects por rol/demo |
| `freezed_annotation`, `json_annotation` / dev: `freezed`, `json_serializable`, `build_runner` | Modelos inmutables y DTOs |
| `supabase_flutter` | Auth, Postgrest, Realtime |
| `flutter_map`, `latlong2` | Mapa con tiles OSM (solo dentro de `core/map/` y `data/`) |
| `geolocator` | Permisos, estado del GPS y stream de posiciones (sin `permission_handler`: geolocator cubre lo necesario) |
| `wakelock_plus` | Mantener la pantalla encendida durante una entrega en curso |
| `shared_preferences` | Preferencia de tema |
| `intl` | Formato de horas, distancias y moneda |
| `flutter_native_splash` | Splash claro/oscuro |
| dev: `flutter_launcher_icons` | Ícono adaptativo |
| dev: `very_good_analysis` | Lints |
| dev: `mocktail`, `flutter_test` | Tests |

**Drift: no se usa en Rutta.** El CLAUDE.md lo lista en el stack Flutter, pero aquí no aporta: el tracking solo
tiene sentido en línea, no hay datos que el usuario cree offline, y el modo demo ya funciona sin red con mocks en
memoria. Añadirlo sumaría codegen y una tercera implementación de repositorio sin valor demostrable (Centavo ya
demuestra offline-first con Drift). La única persistencia local es la preferencia de tema.

Animación del marcador: implementación propia con `AnimationController` (sin `flutter_map_animations`) para
mantenerla independiente del proveedor de mapa.

---

## 10. Andamiaje inicial desde la CLI

> El repositorio git lo inicializa el autor manualmente. Ninguno de estos pasos ejecuta comandos git.

```bash
# 1. Crear el proyecto dentro de la carpeta existente (Flutter stable más reciente)
cd ~/Developer/MobilePorfolio/Rutta
flutter --version                    # confirmar canal stable
flutter create --org com.malpidev --project-name rutta \
  --platforms android,ios --empty .
# → applicationId / bundle id: com.malpidev.rutta (confirmado)

# 2. Dependencias
flutter pub add flutter_riverpod riverpod_annotation go_router \
  freezed_annotation json_annotation supabase_flutter \
  flutter_map latlong2 geolocator wakelock_plus shared_preferences intl \
  flutter_native_splash
flutter pub add --dev build_runner riverpod_generator freezed json_serializable \
  very_good_analysis mocktail flutter_launcher_icons

# 3. Lints: analysis_options.yaml
#    include: package:very_good_analysis/analysis_options.yaml
#    analyzer: exclude: ["**/*.g.dart", "**/*.freezed.dart"]

# 4. Generación de código
dart run build_runner build --delete-conflicting-outputs
# (durante el desarrollo: dart run build_runner watch -d)
```

**5. Permisos de ubicación**

- Android `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  ```
  `INTERNET` debe ir en el manifest **main** (la plantilla solo lo pone en debug/profile; sin él el APK release no carga tiles ni Supabase). **No** se declara `ACCESS_BACKGROUND_LOCATION`.
- iOS `ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription` = "Rutta shares your location with the customer while you deliver their order." Sin `UIBackgroundModes` de ubicación.

**6. Estructura de carpetas** según la sección 8.2 (`lib/core`, `lib/features/<feature>/{domain,data,presentation}`, `test/`, `.maestro/`, `tool/`, `assets/`).

```bash
# 7. Supabase local (Docker)
supabase init                        # crea supabase/config.toml
#   editar config.toml → [api] schemas = ["public", "graphql_public", "rutta"]
supabase migration new rutta_init    # escribir la migración (sección 7)
supabase start
supabase db reset                    # aplica migraciones + seed.sql

# 8. Variables de entorno
cp .env.example .env.json            # y convertir a JSON (ver sección 15); .env.json en .gitignore
flutter run --dart-define-from-file=.env.json

# 9. Ícono y splash (tras añadir assets y su config en pubspec.yaml)
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Añadir a `.gitignore`: `.env`, `.env.json`, `supabase/.temp/`, `supabase/.branches/`.

---

## 11. Identidad visual

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `primary` | `#FF5A1F` (naranja ruta) | `#FF7A45` | Botones, ruta restante, marcador del repartidor |
| `onPrimary` | `#FFFFFF` | `#1A0E08` | Texto sobre primary |
| `secondary` | `#1E3A5F` (azul noche) | `#8FB3E0` | Marcador de destino, encabezados |
| `success` | `#1F9D55` | `#4ADE80` | `delivered`, "Sharing location" |
| `warning` | `#D97706` | `#FBBF24` | Posición *stale*, avisos de permiso |
| `error` | `#DC2626` | `#F87171` | Errores |
| `background` | `#F7F7F5` | `#0F141A` | Fondo |
| `surface` | `#FFFFFF` | `#1A212B` | Tarjetas, panel inferior |
| `routeTraveled` | `#FF5A1F` al 35 % | `#FF7A45` al 35 % | Tramo ya recorrido |

- **Tipografía:** *Manrope* (títulos, peso 700–800) + *Inter* (texto), empaquetadas como assets (sin descarga en tiempo de ejecución).
- **Material 3** con `ColorScheme` construido desde los tokens; chips de estado con color por `OrderStatus`.
- **Ícono:** una "R" cuyo trazo es una ruta punteada que termina en un pin, blanco sobre `primary`; adaptativo en Android.
- **Splash:** fondo `primary` (claro) / `#0F141A` (oscuro) con el ícono centrado; soporte Android 12+.
- **Modo oscuro obligatorio**, incluido el mapa: OSM no ofrece tiles oscuros oficiales, así que en modo oscuro se
  aplica `darkModeTileBuilder` de `flutter_map` (filtro de color sobre los tiles). Si el resultado no convence, se
  evalúa un proveedor con estilo oscuro (decisión abierta, sección 17).

---

## 12. Estados de UI y datos de demo

### 12.1 Estados por pantalla

| Pantalla | Carga | Vacío | Error | Otros |
|---|---|---|---|---|
| Login / Verify / Onboarding | Botón con spinner, campos deshabilitados | — | Mensaje por `DomainError` bajo el formulario (código incorrecto/caducado, red) | Validación inline; reenviar código tras 60 s |
| Lista cliente | Skeleton de 3 tarjetas | "No orders yet" + ilustración (y en live, texto que sugiere *Explore demo*) | Mensaje + *Retry* | Banner "Reconnecting…" |
| Lista repartidor | Skeleton | "No deliveries assigned" | Mensaje + *Retry* | Banner "Reconnecting…" |
| Detalle (cliente) | Mapa con placeholder + panel skeleton | Pedido sin repartidor aún: "Waiting for a courier" (sin marcador) | "Order not found" / red + *Retry* | Posición *stale* (> 30 s): marcador gris + "Last updated X s ago"; pedido `created`/`assigned`: sin marcador, texto "Tracking starts when the courier picks up your order"; tiles que no cargan: fondo neutro + aviso "Map unavailable" sin bloquear el panel |
| Detalle (repartidor) | Igual | — | Error tipado en SnackBar tras acción fallida (`InvalidTransition`, `CourierBusy`, red) | **Sin permiso**: aviso "Location off — the customer can't see you" + botón *Enable*; **GPS apagado**: aviso + *Open location settings*; **denegado para siempre**: *Open app settings*; esperando primera lectura GPS: "Getting your location…" |
| Ajustes | — | — | — | En demo: botón *Exit demo* en lugar de *Sign out* |

Ninguna pantalla queda en blanco: todo `AsyncValue` se renderiza con sus tres ramas.

### 12.2 Datos de demo (mock) y seed

- **Mock (en memoria, `demo_fixtures.dart`)**:
  - Cliente demo "Alex Rivera" con 5 pedidos: 1 `in_transit` (simulación de ~60 s hasta `delivered`), 1 `assigned`, 3 en historial (`delivered` ×2, `cancelled` ×1).
  - Repartidor demo "Carlos Méndez" con 3 pedidos: 1 `assigned` (listo para *Picked up*) y 2 `delivered` (los pedidos `created` no le son visibles porque aún no tienen repartidor).
  - Comercios ficticios pero realistas ("La Esquina Café", "Farmacia Central", "Green Bowl"), direcciones reales de calle, ítems y totales.
  - Polilíneas reales (obtenidas con `tool/fetch_routes.dart`) de 1.5–4 km.
  - Latencia simulada de 300–600 ms en lecturas para que se vean los estados de carga.
- **Seed (`seed.sql`, local)**: mismos comercios y rutas; 1 cliente (`customer@rutta.test`), 2 repartidores (`courier1@rutta.test`, `courier2@rutta.test`), 8 pedidos cubriendo todos los estados, eventos de estado coherentes y una fila de `courier_locations` para el pedido en curso.

---

## 13. Estrategia de testing

| Nivel | Qué se prueba | Herramienta |
|---|---|---|
| Unit — dominio | `OrderStatus.canTransitionTo` (todas las combinaciones, tabla completa); `ComputeRouteProgress` (punto sobre la ruta, fuera de ruta, inicio, fin, ruta de 2 puntos); `ShouldSendLocation` (tiempo, distancia, latido, precisión mala); `AvailableOrderActions` por rol/estado/`CourierBusy`; haversine | `flutter_test` |
| Unit — data | Mappers `OrderDto` ↔ `Order` (incluye `[lng,lat]` → `GeoPoint`); traducción de errores Supabase → `DomainError` (con `mocktail` sobre el cliente); `MockOrdersRepository` y `DemoCourierSimulator` (emite puntos sobre la ruta, termina en destino, pasa a `delivered`) | `flutter_test` + `mocktail` |
| Unit — BD (opcional) | Consultas SQL de verificación en `supabase/tests/` (transiciones inválidas rechazadas, cliente ajeno no ve ubicación) ejecutadas manualmente contra local | `psql` |
| Widget | `StatusTimeline` (estados pasados/futuros), `OrderDetailScreen` repartidor (botón correcto por estado, error visible), `LocationPermissionSheet` (cada `LocationAccess`), listas con loading/empty/error. El mapa se sustituye por un `RuttaMap` falso en tests. | `flutter_test` + overrides de Riverpod |
| E2E | `customer_demo_tracking.yaml`: abrir → *Explore demo* → *as customer* → abrir pedido activo → ver "In transit" → esperar "Delivered". `courier_demo_delivery.yaml`: *as courier* → pedido asignado → *Picked up* → *Start delivery* → *Mark as delivered* → confirmar → ver "Delivered". | Maestro (sobre APK debug, en modo demo, sin backend) |

Los widgets clave llevan `Semantics(identifier: ...)` / `Key` estables para Maestro.

---

## 14. CI/CD y entrega

- **`.github/workflows/ci.yaml`** (en cada PR y push a `main`): `subosito/flutter-action` (canal stable, con caché) → `flutter pub get` → `dart run build_runner build -d` → `dart format --set-exit-if-changed lib test` → `flutter analyze` → `flutter test --coverage`.
- **`.github/workflows/release.yaml`** (en tag `v*`): genera `.env.json` desde GitHub Secrets (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, …) → `flutter build apk --release --dart-define-from-file=.env.json` → publica `rutta-<version>.apk` en **GitHub Releases** (`softprops/action-gh-release`).
- Firma del APK: keystore de release en secrets (base64) + `key.properties` generado en CI; si no está configurado, se publica firmado con debug como APK de demo (decisión abierta).
- Maestro se ejecuta localmente antes de cada release (en CI queda como futuro por el costo de emuladores).
- Keep-alive de Supabase: lo cubre el workflow del repo de Agendo; Rutta no añade otro.
- Versionado: `pubspec.yaml` `version: x.y.z+build`; `v1.0.0` = MVP con demo pública.

---

## 15. Variables de entorno

`.env.example` (commiteado, documentado) y `.env.json` (local, en `.gitignore`, pasado con `--dart-define-from-file`).

```bash
# .env.example — copiar los valores a .env.json (formato JSON)
# URL del proyecto Supabase (local: http://10.0.2.2:54321 en emulador Android; remoto: https://<ref>.supabase.co)
SUPABASE_URL=
# Publishable key (sb_publishable_…). NUNCA la secret key (sb_secret_…) en la app.
SUPABASE_PUBLISHABLE_KEY=
# Plantilla de tiles. Default: OSM estándar. Cambiar a un proveedor comercial si se supera la política de uso de OSM.
MAP_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
# Identificador enviado en el User-Agent de las peticiones de tiles (exigido por la política de OSM)
MAP_USER_AGENT_PACKAGE=com.malpidev.rutta
# Intervalo mínimo entre envíos de ubicación (segundos) y distancia mínima (metros)
LOCATION_MIN_INTERVAL_S=5
LOCATION_MIN_DISTANCE_M=10
```

```json
{
  "SUPABASE_URL": "http://10.0.2.2:54321",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxx",
  "MAP_TILE_URL": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  "MAP_USER_AGENT_PACKAGE": "com.malpidev.rutta",
  "LOCATION_MIN_INTERVAL_S": "5",
  "LOCATION_MIN_DISTANCE_M": "10"
}
```

- `SUPABASE_DB_URL` (para `psql`) vive solo en el shell del autor, nunca en la app ni en `.env.json`.
- Si `SUPABASE_URL` está vacío, la app arranca y solo ofrece el modo demo (útil para revisores que compilan sin backend).

---

## 16. Definición de terminado

- [ ] F1–F10 funcionan en Android, con backend local y remoto.
- [ ] El cliente ve moverse al repartidor en vivo (Realtime) con marcador animado sobre la ruta, en dos dispositivos reales o emulador + dispositivo.
- [ ] RLS verificado: un cliente no ve pedidos ni ubicaciones ajenas; un repartidor no puede avanzar pedidos que no son suyos ni saltarse estados.
- [ ] Modo demo funcionando **sin backend y en modo avión** (sin red el mapa muestra "Map unavailable" pero la simulación y el panel funcionan).
- [ ] Estados de carga, vacío y error en cada pantalla, incluidos sin permiso / sin GPS / posición *stale*.
- [ ] Tests unitarios de dominio (máquina de estados, progreso de ruta, throttling) y de repositorios + 2 flujos de Maestro en verde.
- [ ] CI en verde.
- [ ] `flutter analyze` sin errores ni warnings con `very_good_analysis`.
- [ ] Modo oscuro completo, incluido el mapa; ícono y splash propios.
- [ ] Atribución © OpenStreetMap visible en el mapa.
- [ ] README completo según la plantilla del CLAUDE.md (incluye cómo cambiar a Google Maps y las políticas de OSM/OSRM).
- [ ] Tabla de estado del `CLAUDE.md` actualizada.

Para 🚀 Publicado: APK en GitHub Releases + GIF de demo (split-screen cliente/repartidor) + repo público.

---

## 17. Riesgos, supuestos y decisiones abiertas

**Riesgos**

| Riesgo | Mitigación |
|---|---|
| **Política de uso de tiles de OSM** (`tile.openstreetmap.org`): exige User-Agent identificable, atribución visible, respetar caché y prohíbe uso intensivo / descarga masiva; pueden bloquear el acceso | `userAgentPackageName` configurado, `RichAttributionWidget`, sin precarga de tiles; URL configurable (`MAP_TILE_URL`) para cambiar a MapTiler/Stadia/etc. si el demo tuviera tráfico real. Documentado en el README. |
| **Servidor demo de OSRM** (`router.project-osrm.org`): sin SLA, límite ~1 petición/s, no apto para producción | Solo se usa en `tool/fetch_routes.dart`, una vez, en desarrollo; las rutas quedan guardadas en seed y fixtures. La app nunca depende de él. |
| GPS en emulador poco realista | Modo demo con simulador; en live, probar con dispositivo físico o con rutas GPX del emulador. |
| El SO suspende la app en segundo plano y el cliente deja de ver al repartidor | Aceptado en el MVP (solo primer plano): wakelock durante la entrega + indicador *stale* para el cliente. Documentado. |
| Realtime en schema personalizado mal configurado (publicación, grants, schema no expuesto) | Checklist en la migración y en el README; test manual con dos sesiones. |
| `auth.users` compartido entre apps | Sin trigger; perfil creado desde la app con la RPC `ensure_profile` (convención común). |
| Semana 2 compartida con Vitrina | Alcance cerrado; primero el camino del demo (mock), luego Supabase. |

**Supuestos**
- La ruta precalculada es suficiente: el repartidor sigue aproximadamente la ruta; si se desvía (> 75 m) el marcador se muestra en su posición real sin proyectar.
- Pocos repartidores simultáneos (demo), por lo que `postgres_changes` basta.
- ETA aproximada (distancia restante / velocidad) es aceptable para un demo.

**Decisiones tomadas en este documento (revisar)**
1. Sin rol admin en la app; asignación por SQL/RPC con secret key.
2. ~~Email + contraseña~~ → **resuelto:** email + código OTP y perfil vía `ensure_profile()`, convención común de las 4 apps (`CLAUDE.md`).
3. Rutas precalculadas con OSRM offline y guardadas como `jsonb`; sin llamadas de routing en tiempo de ejecución.
4. Sin PostGIS; sin Drift; sin Edge Functions ni Storage.
5. Ubicación solo en primer plano; envío cada 5 s / 10 m con latido de 30 s; solo se guarda la última posición.
6. `postgres_changes` en lugar de Broadcast.
7. Un solo pedido en curso por repartidor, impuesto por índice único parcial.
8. Modo demo con elección de rol y simulador acelerado (~60 s por recorrido).

**Decisiones cerradas (2026-09-25)**
- Datos de demo en Ciudad de México (coherente con Agendo).
- Solo Android en v1.0.0; bundle id `com.malpidev.rutta` confirmado.
- SMTP por defecto de Supabase; cuentas de prueba remotas (cliente/repartidor) vía `generateLink` con la secret key.

**Decisiones abiertas**
- Estilo de mapa oscuro: filtro sobre OSM vs. proveedor con estilo oscuro (implica API key y otra política de uso).
- Firma del APK de release (keystore propio vs. debug para demo).

---

## 18. Calendario

**Semana asignada: Semana 2 (5 – 11 oct 2026)**, en paralelo con Vitrina. Después del 11 oct: pulido, GIF y README.

Orden sugerido de construcción (alto nivel):

1. Andamiaje (sección 10), tema claro/oscuro, router, `core/map` con un mapa estático y la ruta de un fixture.
2. Dominio completo con tests: `OrderStatus`, `ComputeRouteProgress`, `ShouldSendLocation`, `AvailableOrderActions`.
3. `tool/fetch_routes.dart` + fixtures; repositorios **mock** y `DemoCourierSimulator`.
4. Flujo cliente en modo demo: lista → detalle → marcador animado → timeline → `delivered`.
5. Flujo repartidor en modo demo: lista → cambiar estados; permisos de ubicación con `geolocator`.
6. Migración Supabase (tablas, RLS, RPCs, triggers, Realtime) + `seed.sql`; repositorios **supabase** y auth.
7. Publicación de ubicación real y suscripción Realtime; prueba con dos dispositivos.
8. Estados de carga/vacío/error, ícono, splash, flujos de Maestro, CI y release `v1.0.0`.
