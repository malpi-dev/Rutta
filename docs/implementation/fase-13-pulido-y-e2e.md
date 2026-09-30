# Fase 13 · Pulido y E2E

**Rama:** `feat/fase-13-pulido-y-e2e`
**Objetivo:** auditoría de estados de UI (nada de pantallas en blanco), modo oscuro completo, pantallas pequeñas y
texto grande, accesibilidad básica y los **dos flujos E2E de Maestro** en verde sobre el APK release en modo demo.
**Referencias:** definición §12.1, §13 (flujos de Maestro y `Semantics`), §16 · `CLAUDE.md` del portafolio
(Definición de terminado) · Centavo `docs/implementation/fase-13-pulido-y-e2e.md` pasos 2–5 y su bitácora (lecciones
de Maestro).
**Requisitos previos:** fase 12 terminada. Emulador Android. Java 17+ y Maestro (`maestro --version`; si no está:
`curl -fsSL "https://get.maestro.mobile.dev" | bash`).

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Auditoría de estados de UI (§12.1)

Recorre la tabla y, para cada celda, confirma que existe **y** que hay un test que la cubre (si falta, añádelo en
`test/app/ui_states_test.dart`):

| Pantalla | Carga | Vacío | Error | Otros |
|---|---|---|---|---|
| Startup | spinner | — | mensaje + *Retry* | — |
| Login / Verify / Onboarding | botón con spinner, campos deshabilitados | — | mensaje por `DomainError` bajo el campo | reenvío a los 60 s; aviso "solo demo" sin backend |
| Lista cliente | skeleton de 3 tarjetas | "No orders yet" (+ pista de demo en live) | mensaje + *Retry* | "Reconnecting…" |
| Lista repartidor | skeleton | "No deliveries assigned" | mensaje + *Retry* | "Reconnecting…" |
| Detalle cliente | placeholder de mapa + panel skeleton | `created`: "Waiting for a courier"; `assigned`: "Tracking starts…" | "This order no longer exists." / red + *Retry* | *stale* con pin gris; "Map unavailable" sin bloquear el panel |
| Detalle repartidor | igual | — | SnackBar tras acción fallida | sin permiso / GPS apagado / denegado para siempre / "Getting your location…" / en pausa |
| Ajustes | skeleton en cuenta si la sesión carga | — | — | *Exit demo* en lugar de *Sign out* |

Busca también pantallas en blanco: `grep -rn "SizedBox.shrink()" lib/features/*/presentation` y revisa cada caso
(solo se permite donde "no mostrar nada" es el estado correcto, p. ej. el banner de reconexión conectado).

## Paso 2 · Modo oscuro, pantallas pequeñas y texto grande

`test/app/screens_smoke_test.dart` (como Centavo): para Login, Verify, Onboarding, lista cliente, lista repartidor,
detalle cliente (RT-1042 en curso y RT-1038 entregado), detalle repartidor (RT-1043), hoja de permisos (los 3 estados),
hoja del demo y Ajustes, en demo o con mocks, con las combinaciones {claro, oscuro} × {360×640 dp, 411×891 dp} ×
{`textScaler` 1.0, 1.3}: se construye sin excepciones ni overflow (`tester.takeException()` es `null`). Usa
`tester.view.physicalSize`/`devicePixelRatio` y `addTearDown(tester.view.reset)`. Desmonta al final (timers).

Greps que deben devolver vacío:

```bash
grep -rnE "Color\(0x|Colors\.[a-z]" lib --include=*.dart | grep -v lib/core/theme | grep -v "Colors.transparent"
grep -rn "Text('" lib/features lib/core/presentation lib/core/router    # textos literales en widgets
```

(Las únicas excepciones aceptables en `FakeRuttaMap` viven en `test/`, no en `lib/`.)

## Paso 3 · Accesibilidad

- Botones solo-ícono con `tooltip` (ajustes, recentrar, cerrar aviso del mapa).
- Pines del mapa con `Semantics(label:)`; chips de estado legibles por lector de pantalla ("Status: In transit").
- `test/app/accessibility_test.dart`: en las pantallas principales, claro y oscuro,
  `expect(tester, meetsGuideline(androidTapTargetGuideline))` y `meetsGuideline(textContrastGuideline)`.
  El mapa falso puede excluirse si genera falsos positivos (anótalo).
- La animación del marcador respeta `MediaQuery.disableAnimations`: si está activo, coloca el marcador sin animar.

## Paso 4 · Ids para Maestro

Revisa que existen (con `Semantics(identifier: …)`) todos los ids de las fases anteriores:
`login-explore-demo`, `demo-as-customer`, `demo-as-courier`, `demo-banner`, `demo-exit`, `order-card-<code>`,
`order-status-headline`, `tracking-eta`, `tracking-recenter`, `order-action-primary`, `confirm-delivered`,
`sharing-indicator`, `settings-open`.

Lección de Centavo: un `Semantics(identifier:)` que envuelve un texto debe llevar `container: true` para que Maestro
vea el id y el texto en el **mismo** nodo. Compruébalo con `maestro hierarchy` en el emulador.

## Paso 5 · Flujos de Maestro (`.maestro/`)

Se ejecutan sobre el **APK release sin `.env.json`** (solo demo, sin red): así no dependen del backend.

`.maestro/customer_demo_tracking.yaml`:

```yaml
appId: com.malpidev.rutta
name: Customer - follow a live delivery (demo)
---
- launchApp:
    clearState: true
- tapOn:
    id: login-explore-demo
- tapOn:
    id: demo-as-customer
- assertVisible:
    id: demo-banner
- tapOn:
    id: order-card-RT-1042
- assertVisible: "In transit"
- extendedWaitUntil:
    visible:
      id: tracking-eta
    timeout: 10000
# The simulated courier needs ~60 s to arrive. "Delivered at <time>" only exists once the order is delivered
# ("Delivered" alone also appears as an upcoming step of the timeline).
- extendedWaitUntil:
    visible: "Delivered at.*"
    timeout: 120000
- back
- assertVisible: "History"
```

`.maestro/courier_demo_delivery.yaml`:

```yaml
appId: com.malpidev.rutta
name: Courier - deliver an order (demo)
---
- launchApp:
    clearState: true
- tapOn:
    id: login-explore-demo
- tapOn:
    id: demo-as-courier
- tapOn:
    id: order-card-RT-1043
- assertVisible: "Picked up"
- tapOn:
    id: order-action-primary
- extendedWaitUntil:
    visible: "Start delivery"
    timeout: 10000
- tapOn:
    id: order-action-primary
- extendedWaitUntil:
    visible:
      id: sharing-indicator
    timeout: 10000
- extendedWaitUntil:
    visible: "Mark as delivered"
    timeout: 10000
- tapOn:
    id: order-action-primary
- tapOn:
    id: confirm-delivered
- extendedWaitUntil:
    visible: "Delivered at.*"
    timeout: 10000
```

- Si un `tapOn` por id no encuentra el nodo, revisa `maestro hierarchy` (id en otro nodo, falta `container: true`,
  botón fuera de pantalla en el panel: añade `scrollUntilVisible` sobre el panel).
- El botón principal debe quedar visible sin desplazar con el panel en su tamaño inicial (0.42). Si no, ajústalo.

`tool/e2e.sh`: copia el de Centavo (`../Centavo/tool/e2e.sh`): comprueba `maestro`, `adb` y dispositivo;
`flutter build apk --release` (sin `--dart-define-from-file`); `adb install -r …`; `maestro test .maestro/ "$@"`.
`chmod +x tool/e2e.sh`.

```bash
./tool/e2e.sh
```

Ambos flujos deben pasar (anota en la bitácora el resultado literal de Maestro, p. ej. `2/2 Flows Passed in 95s`).
Maestro **no** corre en CI (decisión de la bitácora); se ejecuta en local antes de cada tag.

## Paso 6 · Revisión en dispositivo

Con el APK release instalado en el emulador (y, si el autor puede, en su teléfono — **🙋**):
- Demo completo como cliente y como repartidor, en claro y oscuro, **en modo avión** (el mapa muestra "Map
  unavailable" pero la simulación, el panel y los estados funcionan — §16).
- Rotación a horizontal: nada se rompe (no hace falta un diseño especial, solo que no haya overflow).
- Capturas revisadas (lista cliente, detalle en curso claro y oscuro, detalle repartidor, ajustes); guárdalas en
  `/tmp`, las definitivas se hacen en la fase 14.

## Paso 7 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] Cada celda de la tabla de estados existe y tiene test.
- [ ] Test de humo visual (claro/oscuro × 2 tamaños × 2 escalas de texto) sin overflow ni excepciones.
- [ ] Sin colores ni textos literales fuera de su lugar; tooltips y semántica en pines y botones de ícono.
- [ ] Tests de accesibilidad (tap targets y contraste) en verde.
- [ ] `customer_demo_tracking.yaml` y `courier_demo_delivery.yaml` en verde con `./tool/e2e.sh` (resultado en la bitácora).
- [ ] Demo verificado en modo avión con el APK release.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
