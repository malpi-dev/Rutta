# Fase 01 · Andamiaje

**Rama:** `feat/fase-01-andamiaje`
**Objetivo:** proyecto Flutter creado con la CLI oficial, dependencias instaladas, lints `very_good_analysis`,
l10n, permisos de Android (internet y ubicación), estructura de carpetas, scripts de verificación y CI en verde.
**Referencias:** definición §8.2, §9, §10, §14, §15 · `CLAUDE.md` del portafolio (Stack, Seguridad).
**Requisitos previos:** Flutter stable (≥ 3.44), Android SDK + un emulador (o teléfono) Android, `gh` autenticado.
Docker **no** es necesario todavía.

> Esta fase no contiene lógica de negocio. Al terminarla, la app abre una pantalla con el texto "Rutta",
> `./tool/check.sh` pasa y el CI del PR está en verde.

---

## Paso 0 · Inicio de fase

Sigue `00-guia-general.md` §3.1. Además:

- El repo ya existe (`origin = git@github.com:malpi-dev/Rutta.git`, rama `main` con solo `docs/`).
- Hay cambios sin commitear en `docs/` (`docs/definicion.md` modificado y este plan nuevo). Commitéalos como primer
  commit de la rama: `git add docs && git commit -m "docs: add product definition updates and implementation plan"`.
- En `../CLAUDE.md` y `../README.md` (carpeta del portafolio, **no** es un repo, no se commitea) cambia el estado de
  Rutta a `🚧 En progreso`.

## Paso 1 · Crear el proyecto Flutter

`flutter create` funciona sobre una carpeta que ya tiene `.git` y `docs/` (no los toca):

```bash
cd ~/Developer/MobilePorfolio/Rutta
flutter --version                     # anota la versión en la bitácora
flutter create --org com.malpidev --project-name rutta --platforms android,ios --empty .
```

- `--empty` genera un `main.dart` mínimo sin el contador de ejemplo.
- Verifica: `android/app/build.gradle.kts` tiene `applicationId = "com.malpidev.rutta"` y
  `namespace = "com.malpidev.rutta"`. En iOS el bundle id es `com.malpidev.rutta`.
- Borra `test/widget_test.dart` si se generó (se crea uno propio en el paso 10).
- En `pubspec.yaml`: `description: "Delivery tracking with the courier's live location on the map."` y
  `version: 0.1.0+1`. Deja `publish_to: 'none'`.

## Paso 2 · Dependencias

```bash
flutter pub add flutter_riverpod riverpod_annotation go_router freezed_annotation json_annotation \
  supabase_flutter flutter_map latlong2 geolocator wakelock_plus shared_preferences url_launcher \
  collection meta
flutter pub add intl:any                         # 'any' para que coincida con la versión que fija flutter_localizations
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev build_runner riverpod_generator freezed json_serializable \
  very_good_analysis mocktail flutter_launcher_icons flutter_native_splash
flutter pub get
```

- Quita `flutter_lints` de `dev_dependencies` (lo reemplaza `very_good_analysis`).
- `flutter_native_splash` y `flutter_launcher_icons` van en `dev_dependencies` (solo generan recursos).
- **No** se instala Drift (ver `CLAUDE.md` del repo, paso 11) ni `permission_handler` (geolocator cubre los permisos).
- Si `flutter pub add` informa un conflicto de versiones (típico entre `riverpod_generator`, `freezed` y
  `build_runner` por la versión de `analyzer`), deja que pub resuelva con la versión compatible más reciente
  (`flutter pub add <paquete>` sin versión) y anota el resultado en la bitácora. En Centavo, `freezed` estable exigía
  un Dart más nuevo y quedó `freezed: ^4.0.0-dev.3`: si te pasa lo mismo, usa esa versión. **No** fijes versiones a
  mano salvo que sea imprescindible.
- Ordena las dependencias alfabéticamente (lint `sort_pub_dependencies`).
- No añadas `riverpod_lint`/`custom_lint`.

## Paso 3 · Lints (`analysis_options.yaml`)

Reemplaza el contenido completo:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/l10n/app_localizations*.dart"
    - "build/**"
  errors:
    invalid_annotation_target: ignore   # needed by freezed + json_serializable on constructor params

linter:
  rules:
    public_member_api_docs: false       # app, not a published package (see implementation log)
```

## Paso 4 · Generación de código (`build.yaml`)

Crea `build.yaml` en la raíz:

```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          field_rename: snake
          explicit_to_json: true
```

## Paso 5 · Localización

1. En `pubspec.yaml`, dentro de `flutter:` añade `generate: true` (mantén `uses-material-design: true`).
2. Crea `l10n.yaml`:
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   output-class: AppLocalizations
   nullable-getter: false
   ```
3. Crea `lib/l10n/app_en.arb`:
   ```json
   {
     "@@locale": "en",
     "appTitle": "Rutta"
   }
   ```
4. Ejecuta `flutter gen-l10n`. Debe generar `lib/l10n/app_localizations.dart` y `app_localizations_en.dart`
   (si tu versión de Flutter los genera en otra carpeta, ajusta `output-dir`/imports y anótalo en la bitácora).

## Paso 6 · Android e iOS

1. `android/app/src/main/AndroidManifest.xml`, antes de `<application>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```
   - `INTERNET` **debe** ir en el manifest `main` (la plantilla solo lo pone en debug/profile; sin él el APK release no
     carga tiles ni Supabase).
   - **No** declares `ACCESS_BACKGROUND_LOCATION` (definición §3.2: sin ubicación en segundo plano).
   - En `<application>`: `android:label="Rutta"`.
   - Dentro de `<queries>` (créalo como hijo de `<manifest>` si no existe; la plantilla trae uno para `PROCESS_TEXT`),
     añade lo que `url_launcher` necesita para abrir enlaces https:
     ```xml
     <intent>
       <action android:name="android.intent.action.VIEW"/>
       <data android:scheme="https"/>
     </intent>
     ```
2. `android/app/src/debug/AndroidManifest.xml`: añade `android:usesCleartextTraffic="true"` a un elemento
   `<application>` (créalo si no existe dentro de `<manifest>`). Solo en **debug**: permite hablar con Supabase local
   por HTTP desde el emulador (`http://10.0.2.2:54321`).
3. En `android/app/build.gradle.kts`, confirma que `minSdk` es ≥ 23 (si usa `flutter.minSdkVersion` y este es menor,
   pon `minSdk = 23`). Si al compilar `geolocator` exige un `compileSdk` mayor, súbelo y anótalo.
4. iOS (no se verifica, pero se deja compatible), en `ios/Runner/Info.plist`:
   - `NSLocationWhenInUseUsageDescription` = `Rutta shares your location with the customer while you deliver their order.`
   - `CFBundleDisplayName` = `Rutta`.
   - **Sin** `UIBackgroundModes` de ubicación.

## Paso 7 · Estructura de carpetas

Crea (con un `.gitkeep` en las vacías):

```
lib/core/{config,di,domain,errors,map,presentation,router,supabase,theme}
lib/features/{auth,orders,tracking,settings}/{domain,data,presentation}
lib/features/demo/{data,presentation}
lib/features/location_permission/presentation
test/core/  test/features/  test/helpers/
assets/fonts/  assets/icon/
supabase/  tool/  .maestro/  .github/workflows/
```

## Paso 8 · Entorno y `.gitignore`

1. `.env.example` (se commitea; documenta cada variable, definición §15):
   ```bash
   # Copy .env.example.json to .env.json and fill it in (flutter run --dart-define-from-file=.env.json).
   # Supabase project URL. Local: http://10.0.2.2:54321 from the Android emulator (your machine's LAN IP from a phone).
   # Remote: https://<ref>.supabase.co
   SUPABASE_URL=
   # Publishable key (sb_publishable_...). NEVER the secret key (sb_secret_...) in the app.
   SUPABASE_PUBLISHABLE_KEY=
   # Tile URL template. Default: standard OSM tiles. Switch to a commercial provider if you exceed the OSM usage policy.
   MAP_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
   # Package id sent in the tile requests' User-Agent (required by the OSM tile usage policy).
   MAP_USER_AGENT_PACKAGE=com.malpidev.rutta
   # Courier location throttling: minimum seconds between sends and minimum meters moved.
   LOCATION_MIN_INTERVAL_S=5
   LOCATION_MIN_DISTANCE_M=10
   # Without SUPABASE_URL the app starts in demo-only mode.
   ```
2. `.env.example.json` (se commitea; copia lista para `.env.json`):
   ```json
   {
     "SUPABASE_URL": "http://10.0.2.2:54321",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxxxxxxxxxxxxxxxxxxx",
     "MAP_TILE_URL": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
     "MAP_USER_AGENT_PACKAGE": "com.malpidev.rutta",
     "LOCATION_MIN_INTERVAL_S": "5",
     "LOCATION_MIN_DISTANCE_M": "10"
   }
   ```
3. Añade al `.gitignore` (al final, con un comentario `# Rutta`):
   ```
   .env
   .env.json
   *.g.dart
   *.freezed.dart
   lib/l10n/app_localizations*.dart
   coverage/
   supabase/.temp/
   supabase/.branches/
   android/key.properties
   *.jks
   *.keystore
   *.apk
   *.aab
   ```
   Verifica con `git check-ignore -v .env.example .env.example.json` que los ejemplos **no** quedan ignorados
   (el comando no debe imprimir nada para ellos).

## Paso 9 · Scripts de verificación

`tool/check_architecture.sh`:

```bash
#!/usr/bin/env bash
# Fails when a layer imports something it must not (docs/implementation/00-guia-general.md §4.1).
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
dart_grep() { grep -rEn --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' "$@"; }

domain_dirs=$(find lib -type d -name domain)
domain_forbidden="^import '(package:flutter/|package:flutter_riverpod|package:riverpod|package:supabase|package:supabase_flutter|package:flutter_map|package:latlong2|package:geolocator|package:wakelock_plus|package:shared_preferences|package:url_launcher|package:intl|dart:io|dart:ui)|^import '.*(/|^)(data|presentation)/"
if [ -n "$domain_dirs" ] && dart_grep "$domain_forbidden" $domain_dirs; then
  echo "ERROR: domain/ must not import frameworks, backend/device libraries, data/ or presentation/."
  status=1
fi

presentation_dirs=$(find lib -type d -name presentation)
presentation_forbidden="^import '(package:supabase|package:supabase_flutter|package:geolocator|package:rutta/features/[a-z_]+/data/)|^import '(\.\./)+data/"
if [ -n "$presentation_dirs" ] && dart_grep "$presentation_forbidden" $presentation_dirs; then
  echo "ERROR: presentation/ must not import Supabase, geolocator or data/ (use lib/core/di/repository_providers.dart)."
  status=1
fi

# flutter_map / latlong2 only inside lib/core/map (the map is swappable).
if dart_grep "^import 'package:(flutter_map|latlong2)/" lib | grep -v '^lib/core/map/'; then
  echo "ERROR: flutter_map/latlong2 may only be imported inside lib/core/map/."
  status=1
fi

# geolocator only inside lib/features/tracking/data.
if dart_grep "^import 'package:geolocator/" lib | grep -v '^lib/features/tracking/data/'; then
  echo "ERROR: geolocator may only be imported inside lib/features/tracking/data/."
  status=1
fi

[ $status -eq 0 ] && echo "Architecture check passed."
exit $status
```

`tool/check.sh`:

```bash
#!/usr/bin/env bash
# Full local verification. Same steps as CI.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
# Only tracked + new (non-ignored) files: generated code is ignored by git and is not formatted.
dart format --output=none --set-exit-if-changed $(git ls-files --cached --others --exclude-standard '*.dart')
./tool/check_architecture.sh
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
```

```bash
chmod +x tool/check.sh tool/check_architecture.sh
```

## Paso 10 · App mínima y test de humo

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutta/app.dart';

void main() {
  runApp(const ProviderScope(child: RuttaApp()));
}
```

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:rutta/l10n/app_localizations.dart';

class RuttaApp extends StatelessWidget {
  const RuttaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: Text(AppLocalizations.of(context).appTitle)),
        ),
      ),
    );
  }
}
```

`test/app_smoke_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rutta/app.dart';

void main() {
  testWidgets('shows the app name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RuttaApp()));
    await tester.pumpAndSettle();
    expect(find.text('Rutta'), findsOneWidget);
  });
}
```

(Este test se reemplaza en la fase 02.) Ejecuta `./tool/check.sh`: debe pasar completo. Si el analyzer se queja del
orden de imports, obedece al lint (`directives_ordering`).

## Paso 11 · `CLAUDE.md` y `README.md` del repo

1. `CLAUDE.md` en la raíz del repo (**en inglés**). Contenido mínimo:
   - Una línea: qué es Rutta (delivery tracking app, Flutter) y que las reglas globales están en `../CLAUDE.md`
     (portfolio) y el plan en `docs/implementation/` (leer primero `00-guia-general.md` y `bitacora.md`).
   - **Documented exceptions to portfolio rules:**
     - *No Drift.* Tracking only makes sense online, users create no offline data and demo mode already works offline
       with in-memory mocks (definition §9). The only local persistence is the theme preference (`shared_preferences`).
     - *Rule 4 (supabase + mock):* `DeviceLocationRepository` is a device service, so its implementations are
       `geolocator_*` + `mock_*`; `SettingsRepository` is `prefs_*` + `in_memory_*`. Every backend repository
       (`AuthRepository`, `OrdersRepository`, `TrackingRepository`, `ConnectionMonitor`) has `supabase_*` + `mock_*`.
     - *No Edge Functions, no Storage:* nothing needs a secret key (routes are precomputed, no push).
   - Comandos: `./tool/check.sh`, `dart run build_runner watch -d`, `flutter run` (demo only) y
     `flutter run --dart-define-from-file=.env.json` (with Supabase).
   - Reglas cortas: `flutter_map`/`latlong2` only in `lib/core/map/`; `geolocator` only in `lib/features/tracking/data/`;
     domain uses `GeoPoint`, the DB uses `[lng, lat]`; timestamps UTC via `Clock`; money is `int` cents (MXN);
     UI strings in `app_en.arb`; generated files are not committed.
2. `README.md`: reemplaza el que generó Flutter por un borrador en inglés con el título, la tagline
   (*Know exactly where your order is.*) y la línea "🚧 Work in progress". El README completo es de la fase 14.

## Paso 12 · CI (`.github/workflows/ci.yaml`)

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  flutter:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: <VERSIÓN LOCAL, p. ej. 3.44.6>
          cache: true
      - run: ./tool/check.sh
```

- Fija `flutter-version` a la misma versión que tienes en local (así `dart format` y el analyzer se comportan igual).
- Usa la versión mayor más reciente de cada action si hay otra disponible (Centavo usa `actions/checkout@v7`).

## Paso 13 · Probar en Android

```bash
flutter devices                      # confirma que hay un emulador/teléfono Android
flutter run -d <id-android>
```

- Debe verse "Rutta" en el centro. Si no hay emulador ni teléfono disponible: **🙋 Acción del autor** → pedir que
  abra uno y confirme.
- Compila también en release para comprobar que los permisos no rompen nada: `flutter build apk --debug`.
- Opcional para comprobarlo tú: `adb exec-out screencap -p > /tmp/rutta-shot.png` y revisa la imagen.

## Paso 14 · Bitácora y cierre

- Rellena la tabla "Versiones clave instaladas" de `bitacora.md` (lee `pubspec.lock`, `flutter --version`,
  `supabase --version`).
- Cierra la fase según `00-guia-general.md` §3.3. El CI del PR debe pasar.

---

## Criterios de terminado

- [ ] Proyecto creado con `flutter create` (`com.malpidev.rutta`), `pubspec.yaml` con `version: 0.1.0+1`.
- [ ] Dependencias de la definición §9 + las anotadas en la bitácora instaladas; `flutter_lints` eliminado; sin Drift.
- [ ] `analysis_options.yaml`, `build.yaml`, `l10n.yaml` y `app_en.arb` creados; `flutter gen-l10n` funciona.
- [ ] Manifest `main` con `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` (sin background); cleartext solo en debug; `Info.plist` con `NSLocationWhenInUseUsageDescription`.
- [ ] Estructura de carpetas creada; `.env.example` y `.env.example.json` commiteados; `.env.json` y código generado ignorados.
- [ ] `./tool/check.sh` pasa en local (incluido el chequeo de arquitectura).
- [ ] La app abre en Android mostrando "Rutta".
- [ ] `CLAUDE.md` del repo documenta las excepciones (sin Drift, geolocator + mock, sin Edge Functions).
- [ ] CI en verde en el PR; PR mergeado con squash; bitácora actualizada (versiones incluidas).
- [ ] Estado de Rutta `🚧 En progreso` en `../CLAUDE.md` y `../README.md`.
