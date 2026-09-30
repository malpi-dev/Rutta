# Fase 04 · Mapa y rutas

**Rama:** `feat/fase-04-mapa-y-rutas`
**Objetivo:** abstracción de mapa propia (`RuttaMap` + `RuttaMapController`, con tipos del dominio) y su única
implementación con `flutter_map` + tiles de OpenStreetMap (User-Agent, atribución, modo oscuro, aviso "Map
unavailable"); script `tool/fetch_routes.dart` que obtiene **una vez** las rutas reales de CDMX con OSRM y genera los
datos de demo; pantalla de vista previa solo para desarrollo.
**Referencias:** definición §1 (Mapas sin costo y portables), §7.6 (`fetch_routes`), §8.2 (`core/map`), §8.3
(mapa intercambiable), §11 (modo oscuro del mapa), §12.2 (rutas del demo), §17 (políticas OSM y OSRM).
**Requisitos previos:** fase 03 terminada. Conexión a internet (OSRM y tiles).

> Regla clave: `flutter_map` y `latlong2` **solo** se importan dentro de `lib/core/map/`. El chequeo de arquitectura
> lo verifica. Las pantallas solo conocen `RuttaMap`, `MapMarker`, `MapPolyline` y `GeoPoint`.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Modelos del mapa (`lib/core/map/map_models.dart`)

```dart
@immutable
class MapMarker {
  const MapMarker({required this.id, required this.point, required this.child,
      this.width = 44, this.height = 44, this.alignment = Alignment.center});
  final String id;                 // stable id ('pickup', 'dropoff', 'courier')
  final GeoPoint point;
  final Widget child;              // already rotated/styled by the caller
  final double width;
  final double height;
  final Alignment alignment;       // pins use Alignment.topCenter so the tip touches the point
}

@immutable
class MapPolyline {
  const MapPolyline({required this.id, required this.points, required this.color, this.width = 6, this.dotted = false});
  final String id;
  final List<GeoPoint> points;
  final Color color;
  final double width;
  final bool dotted;
}
```

## Paso 2 · Controlador y widget abstracto (`lib/core/map/rutta_map.dart`)

```dart
/// What a concrete map implementation must offer to the controller.
abstract interface class RuttaMapDelegate {
  void fitPoints(List<GeoPoint> points, {EdgeInsets padding});
  void centerOn(GeoPoint point, {double? zoom});
}

/// Created by screens before the map exists; the implementation attaches itself when built.
/// Calls made while detached are ignored.
class RuttaMapController {
  RuttaMapDelegate? _delegate;
  void attach(RuttaMapDelegate delegate) => _delegate = delegate;
  void detach(RuttaMapDelegate delegate) { if (identical(_delegate, delegate)) _delegate = null; }
  bool get isAttached => _delegate != null;
  void fitPoints(List<GeoPoint> points, {EdgeInsets padding = const EdgeInsets.all(48)}) =>
      _delegate?.fitPoints(points, padding: padding);
  void centerOn(GeoPoint point, {double? zoom}) => _delegate?.centerOn(point, zoom: zoom);
}

@immutable
class RuttaMapProps {
  const RuttaMapProps({
    required this.initialFit,            // points the camera frames on first build (>= 1)
    this.markers = const [],
    this.polylines = const [],
    this.controller,
    this.darkMode = false,
    this.padding = const EdgeInsets.all(48),
  });
  final List<GeoPoint> initialFit;
  final List<MapMarker> markers;
  final List<MapPolyline> polylines;
  final RuttaMapController? controller;
  final bool darkMode;
  final EdgeInsets padding;
}

typedef RuttaMapBuilder = Widget Function(RuttaMapProps props);

/// The only map widget screens use. The concrete implementation comes from [ruttaMapBuilderProvider],
/// so switching to Google Maps = a new builder + changing that provider. Tests override it with a fake.
class RuttaMap extends ConsumerWidget {
  const RuttaMap({required this.props, super.key});
  final RuttaMapProps props;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(ruttaMapBuilderProvider)(props);
}
```

`lib/core/map/rutta_map_provider.dart`:

```dart
@Riverpod(keepAlive: true)
RuttaMapBuilder ruttaMapBuilder(Ref ref) => (props) => FlutterMapRuttaMap(props: props);
```

## Paso 3 · Implementación `flutter_map` (`lib/core/map/flutter_map/`)

### 3.1 `lat_lng_mapper.dart`

```dart
LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);
GeoPoint toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);
```

### 3.2 `flutter_map_rutta_map.dart`

`StatefulWidget` que implementa `RuttaMapDelegate`:

- `initState`: crea `MapController`; `widget.props.controller?.attach(this)`. `didUpdateWidget`: si cambió el
  controller, `detach` del viejo y `attach` del nuevo. `dispose`: `detach` y `mapController.dispose()`.
- `fitPoints`: `mapController.fitCamera(CameraFit.coordinates(coordinates: …, padding: padding, maxZoom: 17))`
  (con un solo punto usa `move(point, 16)`).
- `centerOn`: `mapController.move(toLatLng(point), zoom ?? mapController.camera.zoom)`.
- `build`:
  ```dart
  Stack(children: [
    FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: /* CameraFit.coordinates of props.initialFit with props.padding, maxZoom 17 */,
        backgroundColor: /* colorScheme.surfaceContainerHighest: neutral background when tiles fail */,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: Env.mapTileUrl,
          userAgentPackageName: Env.mapUserAgentPackage,       // required by the OSM tile usage policy
          tileBuilder: props.darkMode ? darkModeTileBuilder : null,
          errorTileCallback: (tile, error, stackTrace) => _onTileError(),
        ),
        PolylineLayer(polylines: [/* MapPolyline → Polyline(points, color, strokeWidth: width,
                                     pattern: dotted ? const StrokePattern.dotted() : const StrokePattern.solid()) */]),
        MarkerLayer(markers: [/* MapMarker → Marker(key: ValueKey(id), point, width, height, alignment, child) */]),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(context.l10n.mapAttributionOsm,
                onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'))),
          ],
        ),
      ],
    ),
    if (_showUnavailable) /* top chip, see below */,
  ])
  ```
- **Aviso "Map unavailable"** (§12.1, §16): cuenta errores de tiles; al llegar a 3 muestra arriba un `Material`
  redondeado (key `map-unavailable`) con ícono `cloud_off`, el texto `mapUnavailable` y un botón `close` que lo oculta.
  **No** bloquea el resto de la pantalla. `_onTileError` usa `addPostFrameCallback` antes de `setState` (el callback
  puede llegar durante el build).
- **Política de OSM** (§17): no precargues tiles, no cambies el User-Agent, deja la atribución siempre visible.
- **Verifica la API instalada** (`~/.pub-cache/hosted/pub.dev/flutter_map-<versión>/`): nombres como
  `CameraFit.coordinates`, `StrokePattern`, `errorTileCallback`, `darkModeTileBuilder` o `RichAttributionWidget`
  pueden variar entre versiones mayores. Anota las diferencias.

Textos nuevos en `app_en.arb`: `mapAttributionOsm` "OpenStreetMap contributors", `mapUnavailable`
"Map unavailable — check your connection", `close` "Close".

## Paso 4 · Pines del mapa (`lib/features/tracking/presentation/widgets/map_pins.dart`)

Widgets de presentación reutilizados en las fases 06–08:

| Widget | Aspecto |
|---|---|
| `PlacePin(icon, color, {semanticLabel})` | Gota/pin: `Icon(Icons.location_on, size: 44, color: color)` con un ícono blanco pequeño encima (`storefront` para el origen, `home` para el destino). Se usa con `alignment: Alignment.topCenter`. |
| `CourierPin({required double headingDegrees, required bool stale})` | Círculo de 36 dp con borde blanco de 3 dp, color `colors.courierMarker` (o `colors.courierStale` si `stale`), con `Icons.navigation` blanco rotado `headingDegrees` (`Transform.rotate(angle: heading * π / 180)`). Sombra suave. |

Colores desde `context.colors`; `Semantics(label: …)` con textos de l10n: `pickupPinLabel` "Pickup",
`dropoffPinLabel` "Drop-off", `courierPinLabel` "Courier".

## Paso 5 · Rutas reales con OSRM (`tool/fetch_routes.dart`)

Script de desarrollo (definición §7.6): se ejecuta **a mano**, nunca en la app ni en CI. Usa solo `dart:io` y
`dart:convert` (sin dependencias nuevas). Escribe mensajes con `stdout.writeln` (lint `avoid_print`).

### 5.1 Entrada: lugares de CDMX (constantes en el script)

| key | Origen (nombre · dirección · lat, lng) | Destino (dirección · lat, lng) |
|---|---|---|
| `r1` | La Esquina Café · Av. Álvaro Obregón 130, Roma Norte · 19.41932, −99.16235 | Ámsterdam 240, Hipódromo Condesa · 19.41070, −99.16960 |
| `r2` | Farmacia Central · Av. Cuauhtémoc 180, Roma Norte · 19.42060, −99.15490 | Enrique Rébsamen 900, Narvarte Poniente · 19.39330, −99.15710 |
| `r3` | Green Bowl · Av. Michoacán 78, Hipódromo Condesa · 19.41150, −99.17290 | Río Lerma 150, Cuauhtémoc · 19.42880, −99.16690 |
| `r4` | Panadería San Miguel · Colima 179, Roma Norte · 19.41890, −99.15980 | Luz Saviñón 800, Narvarte Poniente · 19.39400, −99.15300 |
| `r5` | Farmacia Central · Av. Cuauhtémoc 180, Roma Norte · 19.42060, −99.15490 | Durango 280, Roma Norte · 19.41940, −99.16880 |
| `r6` | Green Bowl · Av. Michoacán 78, Hipódromo Condesa · 19.41150, −99.17290 | Liverpool 120, Juárez · 19.42540, −99.16150 |

### 5.2 Proceso

1. Por cada ruta: `GET https://router.project-osrm.org/route/v1/driving/{lngO},{latO};{lngD},{latD}?overview=full&geometries=geojson`
   con cabecera `User-Agent: rutta-dev-script (com.malpidev.rutta)`. Espera **1.5 s** entre peticiones (el servidor
   demo admite ~1 req/s). Reintenta hasta 3 veces con 3 s de espera; si sigue fallando, termina con código 1 y un
   mensaje claro (**🙋 Acción del autor**: reintentar más tarde).
2. De la respuesta toma `routes[0].geometry.coordinates` (lista de `[lng, lat]`), `routes[0].distance` y
   `routes[0].duration`. Redondea coordenadas a 5 decimales, distancia y duración a enteros.
3. Si la distancia está fuera de **1500–4000 m** (§12.2), imprime un **aviso** (no falla). Si pasa, ajusta la
   coordenada de destino en la tabla del script, vuelve a ejecutarlo y anota el cambio en la bitácora.
4. Guarda todo en `tool/routes/routes.json` (caché commiteada: lugares + rutas).
5. Genera `lib/features/orders/data/demo_routes.dart` (ver 5.3) y ejecuta `dart format` sobre él
   (`Process.run('dart', ['format', path])`), porque `check.sh` exige formato.
6. Reemplaza el contenido entre los marcadores SQL (ver 5.4) en `supabase/seed.sql` y
   `supabase/scripts/create_sample_orders.sql` **si esos archivos existen** (se crean en la fase 09); si no existen,
   lo indica y sigue.

Opción `--from-cache`: no llama a OSRM; regenera los pasos 5 y 6 desde `tool/routes/routes.json` (se usa en la fase 09).

### 5.3 Salida Dart

`lib/features/orders/data/demo_route.dart` (escrito a mano, una vez):

```dart
@immutable
class DemoRoute {
  const DemoRoute({required this.key, required this.pickupName, required this.pickupAddress, required this.pickup,
      required this.dropoffAddress, required this.dropoff, required this.points,
      required this.distanceMeters, required this.durationSeconds});
  final String key;
  final String pickupName;
  final String pickupAddress;
  final GeoPoint pickup;
  final String dropoffAddress;
  final GeoPoint dropoff;
  final List<GeoPoint> points;
  final int distanceMeters;
  final int durationSeconds;
}
```

`lib/features/orders/data/demo_routes.dart` (**generado**, commiteado; nombre sin `.g` porque los `.g.dart` están
ignorados por git):

```dart
// GENERATED by tool/fetch_routes.dart. Do not edit by hand.
// Route geometry © OpenStreetMap contributors (ODbL), computed with OSRM.
import 'package:rutta/core/domain/geo_point.dart';
import 'package:rutta/features/orders/data/demo_route.dart';

const demoRoutes = <String, DemoRoute>{
  'r1': DemoRoute(
    key: 'r1',
    pickupName: 'La Esquina Café',
    // …
    points: [GeoPoint(19.41932, -99.16235), /* … */],
    distanceMeters: 1620,
    durationSeconds: 290,
  ),
  // r2 … r6
};
```

Nota: el constructor de `GeoPoint` debe ser `const` (tiene `assert`s, que se permiten en constructores `const`).

### 5.4 Salida SQL

Bloque entre marcadores (el script lo reemplaza entero; todo lo demás del archivo no se toca):

```sql
-- BEGIN GENERATED ROUTES (tool/fetch_routes.dart)
create temporary table seed_routes (
  key text primary key, pickup_name text, pickup_address text, pickup_lat double precision,
  pickup_lng double precision, dropoff_address text, dropoff_lat double precision, dropoff_lng double precision,
  route jsonb, distance_m integer, duration_s integer
);
insert into seed_routes values
  ('r1', 'La Esquina Café', 'Av. Álvaro Obregón 130, Roma Norte', 19.41932, -99.16235,
   'Ámsterdam 240, Hipódromo Condesa', 19.4107, -99.1696, '[[-99.16235,19.41932],…]'::jsonb, 1620, 290),
  …;
-- END GENERATED ROUTES
```

Escapa comillas simples en textos (`'` → `''`). La tabla temporal vive durante la sesión del script SQL; quien la usa
la borra al final con `drop table seed_routes;` (fase 09).

### 5.5 Ejecutar

```bash
dart run tool/fetch_routes.dart
git diff --stat              # tool/routes/routes.json y lib/features/orders/data/demo_routes.dart
```

## Paso 6 · Vista previa de desarrollo

`lib/features/tracking/presentation/dev_map_preview_screen.dart` (**temporal: se borra en la fase 06**):
`Scaffold` con `RuttaMap` que muestra `demoRoutes['r1']`: polilínea `routeRemaining`, `PlacePin` de origen y destino,
un `CourierPin` en el punto medio de la ruta (usa `pointAlongRoute`), `darkMode` según el brillo del tema, y un
`FloatingActionButton` que llama a `controller.fitPoints(route)`.

- Ruta `/dev/map` registrada en el router **solo si `kDebugMode`**; en el login provisional, un `TextButton`
  "Map preview" (también solo en debug; texto en l10n `devMapPreview`) navega a ella.
- **Excepción temporal a la arquitectura:** esta pantalla importa `demo_routes.dart` (de `data/`). Para que el chequeo
  de arquitectura pase, recibe la ruta por parámetro desde el router (que es composition root y sí puede importar
  `data/`): `DevMapPreviewScreen(route: demoRoutes['r1']!.points, pickup: …, dropoff: …)`.

## Paso 7 · Tests

`test/helpers/fake_rutta_map.dart`:

```dart
/// Test double: no network, no timers. Renders one Text per marker/polyline id so tests can assert on them.
class FakeRuttaMap extends StatelessWidget {
  const FakeRuttaMap(this.props, {super.key});
  final RuttaMapProps props;
  static RuttaMapProps? lastProps;
  @override
  Widget build(BuildContext context) {
    lastProps = props;
    return ColoredBox(
      key: const Key('fake-map'),
      color: Colors.grey,
      child: Column(children: [
        for (final m in props.markers) KeyedSubtree(key: Key('marker-${m.id}'), child: m.child),
        for (final p in props.polylines) Text('polyline:${p.id}:${p.points.length}'),
      ]),
    );
  }
}

// override: ruttaMapBuilderProvider.overrideWithValue((props) => FakeRuttaMap(props))
```

Añade ese override a la lista base de `test/helpers/test_overrides.dart` (ningún test de widgets debe pedir tiles).

| Archivo | Qué comprueba |
|---|---|
| `test/core/map/lat_lng_mapper_test.dart` | ida y vuelta `GeoPoint` ↔ `LatLng` sin pérdida. |
| `test/core/map/rutta_map_controller_test.dart` | sin delegate las llamadas no fallan; con un delegate falso recibe `fitPoints`/`centerOn` con los argumentos; `detach` de otro delegate no lo quita. |
| `test/core/map/rutta_map_test.dart` | `RuttaMap` con el override usa `FakeRuttaMap` y le pasa las props (markers visibles por key). |
| `test/features/orders/data/demo_routes_test.dart` | hay 6 rutas `r1`…`r6`; cada una con ≥ 2 puntos, primer punto a < 150 m del origen y último a < 150 m del destino (`haversineMeters`), `distanceMeters` entre 1000 y 5000, y `routeLengthMeters(points)` a ±15 % de `distanceMeters`. |

## Paso 8 · Verificación manual

`flutter run` en el emulador (con internet) → *Map preview*:
- Se ven los tiles de CDMX, la ruta naranja, los pines y el repartidor; la atribución "© OpenStreetMap contributors"
  es visible y al tocarla abre el navegador.
- Modo oscuro del sistema (`adb shell cmd uimode night yes`): los tiles se ven oscuros (filtro) y la ruta sigue legible.
- Modo avión: aparece "Map unavailable" sin bloquear la pantalla, fondo neutro.
- Haz una captura en claro y otra en oscuro (`adb exec-out screencap -p > /tmp/rutta-map-light.png`) y revísalas.
  Si el filtro oscuro no se ve bien, anótalo en la bitácora (decisión abierta de §17) pero **no** cambies de proveedor.

## Paso 9 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] `RuttaMap`, `RuttaMapController`, `RuttaMapProps`, `MapMarker`, `MapPolyline` con tipos propios (`GeoPoint`).
- [ ] `FlutterMapRuttaMap` con User-Agent, atribución enlazada, `darkModeTileBuilder` en oscuro y aviso "Map unavailable".
- [ ] `flutter_map`/`latlong2` solo en `lib/core/map/` (chequeo de arquitectura en verde).
- [ ] `tool/fetch_routes.dart` ejecutado: `tool/routes/routes.json` y `demo_routes.dart` generados con 6 rutas reales de CDMX.
- [ ] `FakeRuttaMap` en los overrides de test; tests del paso 7 en verde.
- [ ] Vista previa verificada a mano en claro, oscuro y modo avión.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
