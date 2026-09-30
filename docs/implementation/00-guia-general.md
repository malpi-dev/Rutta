# Rutta — Guía general de implementación

> **Lee este archivo completo antes de empezar cualquier fase.** Después lee `bitacora.md` para saber en qué
> fase vas y, por último, el archivo de la fase que toca (`fase-NN-<nombre>.md`).
> Cada fase está escrita para poder ejecutarse sin contexto previo: sigue los pasos en orden y no te saltes ninguno.

## 1. Documentos de referencia (orden de prioridad)

1. `../../../CLAUDE.md` (carpeta del portafolio): reglas globales. **Prevalece** sobre todo lo demás.
2. `../../CLAUDE.md` (raíz del repo Rutta, se crea en la fase 01): excepciones propias de Rutta.
3. `../definicion.md`: **qué** se construye (alcance, modelo, backend, UI). Cada fase cita las secciones (§) que necesita.
4. Archivo de la fase actual: **cómo** se construye, paso a paso.
5. `bitacora.md`: estado, decisiones tomadas durante la implementación y bloqueos.

Si encuentras una contradicción entre documentos, sigue el de mayor prioridad y **anótala en la bitácora**
(sección "Decisiones y desviaciones"). Las decisiones tomadas al escribir este plan ya están en esa tabla:
**léelas antes de empezar**, porque algunas corrigen detalles de la definición (por ejemplo: el perfil se crea con
`ensure_profile()` y no con un trigger, y la función `current_role()` se llama `my_role()`).

Proyecto hermano de referencia: `../../../Centavo/` (Flutter, mismo stack, ya implementado con este mismo formato de
plan). Cuando una fase diga "igual que en Centavo", abre el archivo indicado en ese repo y adáptalo (cambia
`centavo` → `rutta`). **Nunca modifiques archivos de Centavo.**

## 2. Idiomas (obligatorio)

| Qué | Idioma |
|---|---|
| Código (nombres de variables, clases, funciones, archivos), comentarios en el código | **Inglés** |
| Textos de la UI (botones, mensajes, errores visibles) — viven en `lib/l10n/app_en.arb` | **Inglés** |
| Mensajes de commit, títulos y descripciones de PR, nombres de rama | **Inglés** |
| SQL (nombres, comentarios, `comment on policy`) | **Inglés** |
| `README.md`, `CLAUDE.md` del repo, scripts de `tool/` | **Inglés** |
| Documentos en `docs/` (incluida la bitácora) | **Español** |

## 3. Protocolo de cada fase (ramas y merge a `main`)

Cada fase es **una rama nueva** creada desde `main` y termina **integrada en `main`**. Sigue estos pasos siempre.

### 3.1 Al empezar la fase

```bash
cd ~/Developer/MobilePorfolio/Rutta
git status                               # debe estar limpio; si no, ver nota abajo
git checkout main
git pull origin main
git checkout -b feat/fase-NN-<nombre>    # ej.: feat/fase-03-dominio
```

- El nombre de la rama es exactamente el del archivo de la fase sin `.md`, con prefijo `feat/`
  (`fase-01-andamiaje.md` → `feat/fase-01-andamiaje`).
- Si `git status` no está limpio: **no borres nada**. Si los cambios son solo de `docs/`, se commitean como primer
  commit de la rama de la fase (`docs: ...`). Si son de código y no sabes de dónde salen, detente y pregunta al autor.
- Actualiza `bitacora.md`: estado de la fase → `🚧 En progreso`, fecha de inicio, "Fase actual" y barra de progreso
  (ver §5). Commit: `docs: start phase NN`.

### 3.2 Durante la fase

- Commits pequeños con **Conventional Commits** en inglés: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`, `ci:`.
  Ejemplo: `feat(tracking): add ComputeRouteProgress use case`.
- No hagas nada que no pida la fase. Si ves algo útil fuera de alcance, anótalo en la bitácora ("Ideas para el roadmap").
- Pasos marcados con **🙋 Acción del autor** requieren que el humano haga algo (login, crear cuentas, secretos,
  probar en un teléfono…). **Detente, explica exactamente qué debe hacer y espera** su confirmación. No inventes
  credenciales ni te saltes el paso. Nunca pidas que pegue contraseñas o la secret key en el chat: pídele que ejecute
  él los comandos (con el prefijo `!` en Claude Code o en su terminal).
- Tras modificar cualquier archivo con anotaciones (`@freezed`, `@riverpod`, `@JsonSerializable`) ejecuta
  `dart run build_runner build --delete-conflicting-outputs`.

### 3.3 Al terminar la fase

1. Ejecuta la verificación completa (el script existe desde la fase 01):
   ```bash
   ./tool/check.sh
   ```
   Hace: `pub get` → `gen-l10n` → `build_runner` → `dart format` (sin cambios) → chequeo de arquitectura →
   `flutter analyze` (sin infos, warnings ni errores) → `flutter test`. Todo debe pasar.
   Si la fase toca la base de datos (desde la fase 09), además: `supabase db reset` y `supabase test db`.
2. Revisa la **checklist de "Criterios de terminado"** del archivo de la fase. Cada casilla debe cumplirse de verdad.
3. Actualiza `bitacora.md`: estado `✅ Terminada`, fecha de fin, barra de progreso, entrada en el "Registro" con lo
   hecho, decisiones y pendientes. Commit: `docs: update implementation log for phase NN`.
4. Integra en `main` con **squash merge** vía Pull Request:
   ```bash
   git push -u origin feat/fase-NN-<nombre>
   gh pr create --base main --title "feat: phase NN - <short english title>" \
     --body "<english summary of what was done + the phase checklist>"
   gh pr checks --watch                     # espera a que el CI termine (existe desde la fase 01)
   gh pr merge --squash --delete-branch
   git checkout main && git pull origin main
   ```
   - Si el CI falla: corrige en la misma rama, `git push` y vuelve a esperar. **Nunca** hagas merge con CI en rojo.
   - Si `gh` no está autenticado (`gh auth status` falla): **🙋 Acción del autor** → pedir que ejecute `gh auth login`.
   - Solo si el autor lo autoriza explícitamente, alternativa local:
     `git checkout main && git merge --squash feat/fase-NN-<nombre> && git commit -m "feat: phase NN - ..." && git push origin main && git branch -D feat/fase-NN-<nombre>`.
5. No empieces la fase siguiente en la misma rama. Cada fase arranca desde `main` actualizado.

## 4. Reglas técnicas que aplican a todas las fases

### 4.1 Arquitectura (definición §8)

```
lib/
  main.dart · app.dart
  core/            # domain/ (Clock, UserRole, AppMode), errors/, config/, supabase/, theme/, router/,
                   # di/ (composition root), map/ (abstracción del mapa), presentation/ (widgets comunes)
  l10n/            # app_en.arb (+ archivos generados, ignorados por git)
  features/
    auth/{domain,data,presentation}
    orders/{domain,data,presentation}
    tracking/{domain,data,presentation}
    demo/{data,presentation}                 # DemoStore, simulador y selector de rol
    location_permission/presentation/
    settings/{domain,data,presentation}
```

- `domain/` (incluido `core/domain/`) **no importa**: `package:flutter/*`, Riverpod, Supabase, `flutter_map`,
  `latlong2`, `geolocator`, `wakelock_plus`, `shared_preferences`, `url_launcher`, `intl`, `dart:io`, `dart:ui`,
  ni nada de `data/` o `presentation/`. Sí puede importar: `dart:core`/`dart:async`/`dart:math`, `package:meta`,
  `package:collection`, `package:freezed_annotation`, `core/domain/`, `core/errors/` y otros `domain/`.
- `presentation/` **nunca** importa Supabase, `geolocator` ni archivos `data/`. Obtiene los repositorios de
  `lib/core/di/repository_providers.dart` (el único "composition root" que importa implementaciones de `data/`).
- `flutter_map` y `latlong2` **solo** se importan dentro de `lib/core/map/`. Las pantallas usan `RuttaMap` y
  `GeoPoint` (fase 04). Así cambiar a Google Maps solo toca `lib/core/map/`.
- `geolocator` solo se importa en `lib/features/tracking/data/`.
- Cada repositorio tiene una implementación real y una `mock_*`:
  `supabase_*` + `mock_*` para `AuthRepository`, `OrdersRepository`, `TrackingRepository`, `ConnectionMonitor`;
  `geolocator_*` + `mock_*` para `DeviceLocationRepository` (es un servicio del dispositivo, no del backend);
  `prefs_*` + `in_memory_*` para `SettingsRepository`. Documentado en el `CLAUDE.md` del repo.
- Los repositorios **lanzan** subclases de `DomainError` (`lib/core/errors/domain_error.dart`). Nunca dejan escapar
  `PostgrestException`, `AuthException`, `RealtimeSubscribeException`, `SocketException`, `PlatformException` ni
  excepciones de `geolocator`.
- Casos de uso **solo** donde la definición §6.4 los lista (más los anotados en la bitácora). Listar u obtener
  pedidos va directo al repositorio desde un provider.
- `tool/check_architecture.sh` (fase 01) verifica estas reglas con `grep`; debe pasar siempre.

### 4.2 Código Dart / Flutter

- **Nombres de archivo** en `snake_case` (`compute_route_progress.dart`). Clases en `PascalCase`, miembros en `camelCase`.
- Lints: `very_good_analysis`. `flutter analyze` debe quedar en **0 issues**. `// ignore:` solo con justificación
  en la misma línea y nunca para esconder un error real.
- Imports: `package:rutta/...`.
- **Dinero:** `totalCents` es `int` (centavos de **MXN**). Prohibido `double` para montos (solo al formatear).
- **Coordenadas:** `double` en grados. En el dominio se usa `GeoPoint(lat, lng)`; en la BD y en la ruta `jsonb` el orden
  es **`[lng, lat]`** (GeoJSON). Cada conversión está en un mapper con test.
- **Distancias** en metros (`double`), **velocidades** en m/s, **tiempos** con `Duration`.
- **Fechas:** los instantes son `DateTime` en **UTC**. Usa `clock.nowUtc()` (fase 02); nunca `DateTime.now()` fuera de
  `SystemClock`. Se convierten a hora local solo al mostrarlos.
- **Modelos:** `freezed`. En freezed 3.x/4.x la clase se declara `abstract class X with _$X` (o `sealed class` para uniones).
- **Riverpod 3:** con `riverpod_generator` (`@riverpod` / `@Riverpod(keepAlive: true)`). Providers de repositorio
  `keepAlive`; providers de pantalla autoDispose (el valor por defecto de `@riverpod`). Los nombres generados se
  comprueban en los `.g.dart`.
- **Código generado** (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) **no se commitea**: está en
  `.gitignore` y el CI lo genera. **Ojo:** por eso ningún archivo escrito a mano puede terminar en `.g.dart`.
- **Textos de UI:** nunca literales en widgets. Van en `lib/l10n/app_en.arb` y se leen con `context.l10n.<key>`.
- **Colores:** siempre desde el tema (`Theme.of(context).colorScheme` o la extensión `RuttaColors`). Nada de
  `Color(0x…)` ni `Colors.xxx` sueltos fuera de `lib/core/theme/` (salvo `Colors.transparent`).
- **Claves para tests y Maestro:** los elementos interactivos importantes llevan `key: const Key('kebab-case-id')`.
  Los que usa Maestro llevan además `Semantics(identifier: 'kebab-case-id', ...)` (se ve como `id` en Maestro).
  Cada fase lista los ids que debe crear; **usa exactamente esos nombres**.
- **Estados de UI:** toda pantalla que carga datos usa `AsyncStateView` (fase 02) con carga, vacío y error con *Retry*
  (definición §12.1). Nada de pantallas en blanco.
- **Streams y timers:** todo `StreamSubscription`, `Timer`, `AnimationController` y canal de Realtime se cancela en
  `dispose`/`onCancel`/`ref.onDispose`. En tests de widgets un timer vivo hace fallar el test
  ("A Timer is still pending"): desmonta el árbol al final (`await tester.pumpWidget(const SizedBox())`).
- **No adivines APIs.** Si dudas de la firma de una librería (Riverpod 3, go_router, flutter_map, geolocator,
  supabase_flutter…), revisa el código fuente en `~/.pub-cache/hosted/pub.dev/<paquete>-<versión>/` o su
  documentación oficial de la **versión instalada** (mira `pubspec.lock`). Anota en la bitácora cualquier diferencia
  con lo que dice la fase.
- **Dependencias:** solo las de la definición §9 más las anotadas en la bitácora (`flutter_localizations`, `collection`,
  `meta`, `http`, `url_launcher`). Añadir otra requiere justificarla en la bitácora.

### 4.3 Secretos

- Nunca commitees `.env.json`, `android/key.properties`, keystores (`*.jks`, `*.keystore`) ni claves.
- En el cliente solo va la **publishable key** (`sb_publishable_…`). La secret key (`sb_secret_…`) jamás: solo vive en
  el shell del autor para scripts de desarrollo (fase 14).

### 4.4 Lecciones aprendidas en Centavo (evitan horas perdidas)

| Situación | Qué hacer |
|---|---|
| `freezed` estable exige un Dart más nuevo que el instalado | Deja que `flutter pub add` resuelva (en Centavo quedó `freezed ^4.0.0-dev.3`). Anótalo. |
| `flutter create` añade `flutter_lints` | Quítalo del `pubspec.yaml`: lo reemplaza `very_good_analysis`. |
| `build_runner` avisa que `--delete-conflicting-outputs` ya no existe | Inofensivo; se deja en `check.sh`. |
| Riverpod 3 reintenta providers fallidos con backoff y la pantalla se queda en "loading" | `ProviderScope(retry: noAutomaticRetry, …)` en `main.dart` **y** en los tests (fase 02). |
| Lint `prefer_initializing_formals` en constructores con campos privados | Usa parámetros nombrados privados: `Foo({required this._repo})` (Dart 3.12 lo permite). |
| Lints `always_put_required_named_parameters_first`, `sort_pub_dependencies`, `avoid_catching_errors`, `one_member_abstracts` | Obedece (reordena, ordena, valida sin capturar `Error`); `one_member_abstracts` se puede ignorar con justificación en interfaces-puerto. |
| Lint `depend_on_referenced_packages` al importar un paquete transitivo (p. ej. `http`) | Decláralo como dependencia directa. |
| Un método `update` en un `AsyncNotifier` | Choca con `AsyncNotifier.update`: usa otro nombre (`advance`, `edit`…). |
| Streams de mocks | Usa `StreamController` con `onListen` (no `async*`) para no perder cambios entre el valor inicial y la suscripción. |
| `SnackBar` con `action` | Persiste por defecto; usa `persist: false`. Todos los SnackBars pasan por un `rootScaffoldMessengerKey`. |
| `mapSupabaseError` | Un `PostgrestException.code` de **3** caracteres es HTTP (≥ 500 = backend caído/pausado); los SQLSTATE tienen **5** (`23505`). GoTrue usa `otp_expired` tanto para código incorrecto como caducado. |
| `Supabase.initialize` | En supabase_flutter 2.17 acepta `publishableKey:` (`anonKey` está deprecado). Verifica en la versión instalada. |
| Banner de demo invisible para Maestro | Una ruta opaca tapa la semántica de lo pintado antes: el banner se pinta **después** del Navigator (`Column(verticalDirection: VerticalDirection.up)`). |
| Supabase local no arranca por puertos ocupados | Agendo y Centavo usan los mismos puertos (54321–54324): `supabase stop --project-id centavo` / `agendo` antes. |
| Seed de `auth.users` | Las columnas de token deben ser `''`, no `NULL`, o GoTrue falla al iniciar sesión. |
| pgTAP con `update … returning` | La CTE con DML debe ir a nivel superior: `with u as (update … returning 1) select is(count(*)::int, 0, '…') from u;` |
| plpgsql | No hace cortocircuito en `and`/`or`: separa las comprobaciones con `if` anidados. |

## 5. Cómo actualizar la barra de progreso

La barra tiene **un bloque por fase** (14 en total):

- `█` = fase terminada · `▒` = fase en progreso · `░` = fase pendiente.
- Formato: `` `█████▒░░░░░░░░` 5/14 fases terminadas (36 %) `` — el porcentaje es `terminadas / 14 × 100`,
  redondeado al entero.
- Tabla de referencia del porcentaje: 0→0 %, 1→7 %, 2→14 %, 3→21 %, 4→29 %, 5→36 %, 6→43 %, 7→50 %, 8→57 %,
  9→64 %, 10→71 %, 11→79 %, 12→86 %, 13→93 %, 14→100 %.
- Actualiza también "Fase actual" y "Última actualización" en la cabecera de la bitácora.

## 6. Cuando algo no sale

1. Lee el error completo. Busca la causa, no el parche.
2. Si una instrucción de la fase no funciona con la versión instalada de una librería, adapta siguiendo la
   documentación oficial y **anota la desviación** en la bitácora.
3. Si tras 2–3 intentos razonables sigues bloqueado, anota el bloqueo en la bitácora ("Bloqueos") y pregunta al autor.
4. Nunca uses `--no-verify`, `git push --force` a `main`, ni desactives reglas de lint o tests para "pasar".

## 7. Comandos frecuentes

```bash
flutter run                                              # sin .env.json: solo modo demo
flutter run --dart-define-from-file=.env.json            # con Supabase (local o remoto)
dart run build_runner watch --delete-conflicting-outputs
flutter test test/features/tracking                      # una carpeta de tests
supabase start && supabase db reset && supabase test db  # desde la fase 09 (Docker encendido)
open http://127.0.0.1:54324                              # Mailpit: códigos OTP en local (desde la fase 10)
./tool/e2e.sh                                            # Maestro, desde la fase 13
```

## 8. Mapa de fases

| # | Archivo | Objetivo |
|---|---|---|
| 01 | `fase-01-andamiaje.md` | `flutter create`, dependencias, lints, l10n, permisos Android, estructura, scripts de verificación, CI |
| 02 | `fase-02-core.md` | `Clock`, `DomainError`, `Env`, `AppMode`, tema claro/oscuro con fuentes, ajustes de tema, router con redirect puro, widgets comunes |
| 03 | `fase-03-dominio.md` | Entidades, `OrderStatus`, interfaces de repositorio, geometría, `ComputeRouteProgress`, `ShouldSendLocation`, `AvailableOrderActions`, línea de tiempo |
| 04 | `fase-04-mapa-y-rutas.md` | `RuttaMap` + implementación `flutter_map`, tiles OSM, modo oscuro del mapa, `tool/fetch_routes.dart` y rutas reales de CDMX |
| 05 | `fase-05-modo-demo.md` | `DemoStore`, fixtures, simulador de repartidor, repositorios mock, cambio de repositorios por `AppMode`, selector de rol y banner |
| 06 | `fase-06-seguimiento-cliente.md` | Lista del cliente, detalle con mapa, marcador animado sobre la ruta, panel con ETA y línea de tiempo |
| 07 | `fase-07-entregas-repartidor.md` | Lista del repartidor, detalle con acción principal, avanzar estados con errores tipados |
| 08 | `fase-08-ubicacion-repartidor.md` | Permisos de ubicación, repositorio `geolocator`, `LocationPublisher` con throttling, wakelock e indicador |
| 09 | `fase-09-backend-supabase.md` | Supabase local: migración (tablas, RLS, RPCs, triggers, Realtime), seed, script de pedidos, pgTAP, job de CI |
| 10 | `fase-10-auth.md` | Supabase en la app, login OTP, verificación, onboarding con `ensure_profile`, sesión y roles en el router |
| 11 | `fase-11-supabase-y-realtime.md` | Repositorios Supabase de pedidos y tracking, Realtime, reconexión, scripts de simulación y prueba en vivo |
| 12 | `fase-12-ajustes-e-identidad.md` | Pantalla de ajustes, créditos de mapas, ícono adaptativo y splash |
| 13 | `fase-13-pulido-y-e2e.md` | Auditoría de estados, modo oscuro, accesibilidad, pantallas pequeñas y 2 flujos de Maestro |
| 14 | `fase-14-lanzamiento.md` | Supabase remoto, cuentas de prueba, firma y release, README completo, tag `v1.0.0` |

Orden pensado para la **semana 2 (5–11 oct)**: primero todo el camino del demo sin backend (fases 01–08), luego
Supabase (09–11) y al final pulido y entrega (12–14). Si el tiempo aprieta, la app ya es demostrable tras la fase 08.
