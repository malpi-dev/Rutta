# Fase 12 · Ajustes e identidad

**Rama:** `feat/fase-12-ajustes-e-identidad`
**Objetivo:** pantalla de ajustes definitiva (tema claro/oscuro/sistema, cuenta, cerrar sesión o salir del demo,
créditos de mapas y rutas, licencias) e identidad visual propia: ícono adaptativo y splash claro/oscuro con
soporte Android 12+, y logo en el login.
**Referencias:** definición §3.1 F10, §11 (identidad visual), §12.1 (ajustes), §17 (atribuciones OSM/OSRM) ·
Centavo `docs/implementation/fase-13-pulido-y-e2e.md` paso 1 (mismo proceso de ícono y splash).
**Requisitos previos:** fase 11 terminada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Abrir enlaces de forma testeable

`lib/core/presentation/external_links.dart`:

```dart
typedef ExternalLinkOpener = Future<void> Function(Uri uri);

/// Opens https links in the browser. Overridden in tests. Failures are swallowed (a SnackBar is optional).
@Riverpod(keepAlive: true)
ExternalLinkOpener externalLinkOpener(Ref ref) =>
    (uri) async { await launchUrl(uri, mode: LaunchMode.externalApplication); };

abstract final class ExternalLinks {
  static final osmCopyright = Uri.parse('https://www.openstreetmap.org/copyright');
  static final osmTilePolicy = Uri.parse('https://operations.osmfoundation.org/policies/tiles/');
  static final osrm = Uri.parse('https://project-osrm.org/');
}
```

Usa `externalLinkOpenerProvider` también en la atribución del mapa (fase 04) en lugar de llamar a `launchUrl`
directamente (la implementación del mapa recibe el opener por parámetro o lo lee con `ref` si es `Consumer`).

## Paso 2 · `SettingsScreen` definitiva (`lib/features/settings/presentation/settings_screen.dart`)

`Scaffold` + `AppBar(title: l10n.settings)` + `ListView` con secciones (`SectionHeader` de la fase 06):

1. **Appearance** (`appearanceSection`): `SegmentedButton<ThemePreference>` con *System* / *Light* / *Dark*
   (`themeSystem`, `themeLight`, `themeDark`; keys e identifiers `settings-theme-system`, `settings-theme-light`,
   `settings-theme-dark`) → `themeControllerProvider.notifier.change(...)`. Se persiste (fase 02) y el mapa cambia a
   estilo oscuro al instante (lee el brillo del tema).
2. **Account** (`accountSection`):
   - Live (`SessionSignedIn`): `ListTile` con avatar de iniciales, `fullName`, email y el rol (`roleCustomer`
     "Customer" / `roleCourier` "Courier"); botón `signOut` (key e identifier `settings-sign-out`) con diálogo de
     confirmación (`signOutConfirm` "Sign out of Rutta?") → `authRepository.signOut()`.
   - Demo: texto `demoExploringAs` "Exploring the demo as {role}" y botón `exitDemo` (key e identifier
     `settings-exit-demo`) → `exitDemo()` (sin confirmación).
   - Si un courier está compartiendo ubicación, cerrar sesión detiene el envío (el motor se reconstruye al cambiar de
     usuario; compruébalo en el test).
3. **Map & routes** (`creditsSection`): tres `ListTile` con ícono `open_in_new` que abren:
   `creditsOsm` "Map data © OpenStreetMap contributors" → `osmCopyright`;
   `creditsTiles` "Map tiles follow the OSM tile usage policy" → `osmTilePolicy`;
   `creditsOsrm` "Routes computed with OSRM" → `osrm`.
4. **About** (`aboutSection`): `ListTile` `licenses` "Open-source licenses" → `showLicensePage(context: context,
   applicationName: 'Rutta', applicationIcon: logo)`. (Las licencias de las fuentes ya están registradas desde la fase 02.)

Sin estados de carga/vacío/error propios (§12.1), salvo que la sesión esté cargando: en ese caso la sección *Account*
muestra un `SkeletonBox`.

## Paso 3 · Ícono y splash

### 3.1 Fuentes SVG (`assets/icon/`)

Concepto (§11): una "R" cuyo trazo vertical es una **ruta punteada** y cuya pierna termina en un **pin**, en blanco
sobre `primary` (`#FF5A1F`). Dibujado con trazos (sin fuentes).

`icon.svg` (1024×1024, punto de partida; ajústalo si al renderizar no queda equilibrado):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#FF5A1F"/>
  <g id="mark">
    <g fill="none" stroke="#FFFFFF" stroke-linecap="round" stroke-linejoin="round" stroke-width="64">
      <!-- stem: dotted route -->
      <path d="M 340 780 L 340 250" stroke-dasharray="0 106"/>
      <!-- bowl -->
      <path d="M 340 250 L 520 250 A 145 145 0 0 1 520 540 L 400 540"/>
      <!-- leg -->
      <path d="M 500 540 L 590 660"/>
    </g>
    <!-- pin at the end of the leg -->
    <g transform="translate(650 700)">
      <path d="M 0 -118 C -64 -118 -106 -70 -106 -12 C -106 58 0 146 0 146 C 0 146 106 58 106 -12 C 106 -70 64 -118 0 -118 Z" fill="#FFFFFF"/>
      <circle cx="0" cy="-14" r="38" fill="#FF5A1F"/>
    </g>
  </g>
</svg>
```

Deriva de él (igual que en Centavo):
- `icon_foreground.svg`: sin el `<rect>` y con `#mark` escalado al 62 % alrededor del centro
  (`<g transform="translate(512 512) scale(0.62) translate(-512 -512)">…</g>`) para la zona segura del ícono adaptativo.
  **Atención:** el círculo interior del pin es `#FF5A1F`; sobre fondo transparente sigue siendo correcto porque el
  fondo del ícono adaptativo es el mismo color.
- `splash_logo.svg`: fondo transparente, `#mark` al 100 %.
- `splash_android12.svg`: `viewBox="0 0 960 960"`, fondo transparente, `#mark` centrado en (480, 480) al 70 %
  (Android 12 recorta el ícono del splash a un círculo de 640 px).

### 3.2 Renderizar a PNG

```bash
brew install librsvg        # si no está instalado
cd assets/icon
rsvg-convert -w 1024 -h 1024 icon.svg -o icon.png
rsvg-convert -w 1024 -h 1024 icon_foreground.svg -o icon_foreground.png
rsvg-convert -w 768 -h 768 splash_logo.svg -o splash_logo.png
rsvg-convert -w 960 -h 960 splash_android12.svg -o splash_android12.png
cd ../..
```

Revisa los PNG abriéndolos (herramienta Read). Si no puedes instalar `librsvg` o el resultado no es correcto:
**🙋 Acción del autor** → exportar esos cuatro PNG desde un editor con esos nombres y tamaños.

### 3.3 Configuración (`pubspec.yaml`, al final)

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/icon/icon.png
  adaptive_icon_background: "#FF5A1F"
  adaptive_icon_foreground: assets/icon/icon_foreground.png
  remove_alpha_ios: true

flutter_native_splash:
  color: "#FF5A1F"
  image: assets/icon/splash_logo.png
  color_dark: "#0F141A"
  image_dark: assets/icon/splash_logo.png
  android_12:
    color: "#FF5A1F"
    image: assets/icon/splash_android12.png
    color_dark: "#0F141A"
    image_dark: assets/icon/splash_android12.png
```

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Commitea los recursos generados en `android/` e `ios/`. Declara `assets/icon/splash_logo.png` en `flutter: assets:`
y sustituye el ícono provisional del login (`Icons.route`) por `Image.asset('assets/icon/splash_logo.png', height: 96)`
dentro de un círculo `primary` (el logo es blanco).

## Paso 4 · Tests

Override de test: `externalLinkOpenerProvider` → función que guarda las URIs abiertas.

| Archivo | Qué comprueba |
|---|---|
| `test/features/settings/presentation/settings_screen_test.dart` | cambiar a *Dark* actualiza `themeControllerProvider` y lo guarda en el repositorio en memoria; en live se ven nombre, email y rol, y *Sign out* (tras confirmar) llama a `signOut`; en demo se ve "Exploring the demo as courier" y *Exit demo* sale del demo; cada crédito abre su URI. |
| `test/features/settings/presentation/theme_applied_test.dart` | app completa: con preferencia `dark` el `MaterialApp` usa `ThemeMode.dark` y el `RuttaMap` recibe `darkMode: true` (vía `FakeRuttaMap.lastProps`). |
| `test/features/auth/presentation/login_screen_test.dart` (ampliar) | el logo (`Image` con `splash_logo.png`) está presente. |

## Paso 5 · Verificación manual

- Ícono en el launcher del emulador (forma adaptativa redonda y cuadrada si el launcher lo permite) y splash en claro
  y oscuro (`adb shell cmd uimode night yes|no`, cerrando la app entre pruebas). Capturas revisadas.
- Ajustes: cambiar tema con un pedido abierto detrás → el mapa cambia de estilo; créditos abren el navegador;
  *Sign out* en live y *Exit demo* en demo.

## Paso 6 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] Ajustes con tema persistido, cuenta (live) o salida del demo, créditos OSM/OSRM enlazados y licencias.
- [ ] Ícono adaptativo y splash claro/oscuro (Android 12+) generados desde SVG propios; logo en el login.
- [ ] Ids para Maestro: `settings-theme-*`, `settings-sign-out`, `settings-exit-demo`.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
