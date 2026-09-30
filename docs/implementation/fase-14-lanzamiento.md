# Fase 14 · Lanzamiento

**Rama:** `feat/fase-14-lanzamiento`
**Objetivo:** migración aplicada en el Supabase remoto compartido, cuentas de prueba (cliente y repartidor) con
pedidos de muestra, prueba en vivo en remoto con dos dispositivos, APK de release firmado y publicado en GitHub
Releases por el workflow de tags, README completo con GIF split-screen y capturas, versión `1.0.0` y tag `v1.0.0`.
**Referencias:** definición §7.4, §7.6 (remoto), §14, §15, §16 · `CLAUDE.md` del portafolio (Backend, Convenciones
del proyecto compartido, Seguridad, Definición de terminado, Plantilla de README) · Centavo
`docs/implementation/fase-14-lanzamiento.md` (mismo proceso de firma y release).
**Requisitos previos:** fase 13 terminada; flujos de Maestro en verde.

> Esta fase tiene varias **🙋 Acciones del autor** (credenciales, secret key, keystore, secretos, teléfono,
> visibilidad del repo). Detente en cada una y espera confirmación. Nunca pidas que te pegue contraseñas ni la
> secret key en el chat: pídele que ejecute él los comandos (prefijo `!` o su terminal).

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Supabase remoto (proyecto compartido)

1. **🙋 Acción del autor:** confirmar que las convenciones globales ya están configuradas (las dejaron Agendo/Centavo):
   Auth por email con "Confirm email", OTP de 6 dígitos, plantilla "Your verification code: {{ .Token }}" para
   *Confirm signup* y *Magic link*, SMTP por defecto. Si no, que las configure según el `CLAUDE.md` del portafolio.
2. **🙋 Acción del autor:** exportar en su terminal `SUPABASE_DB_URL` (cadena de conexión de Postgres; **nunca** en el repo).
3. Comprobar que el schema no existe y aplicar la migración (**nunca** `supabase db push`):
   ```bash
   psql "$SUPABASE_DB_URL" -c "select to_regclass('rutta.orders');"          # debe devolver vacío
   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20261005000000_rutta_init.sql
   ```
   Si ya existe, **no** la vuelvas a aplicar: compara con `\d rutta.*` y avisa al autor. **No** se aplica `seed.sql`.
4. Verificación:
   ```bash
   psql "$SUPABASE_DB_URL" -c "select tablename, rowsecurity from pg_tables where schemaname = 'rutta';"              # 4 filas, todas true
   psql "$SUPABASE_DB_URL" -c "select tablename, policyname from pg_policies where schemaname = 'rutta' order by 1, 2;" # 10 políticas
   psql "$SUPABASE_DB_URL" -c "select tablename from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'rutta';"  # 3 filas
   ```
5. **🙋 Acción del autor:** en *Project Settings → Data API → Exposed schemas*, añadir `rutta` (sin quitar los de las
   otras apps).
6. **🙋 Acción del autor:** facilitar la URL del proyecto y la **publishable key** para el `.env.json` de producción
   local (no se commitea). `MAP_*` y `LOCATION_*` con los valores por defecto.

## Paso 2 · Cuentas de prueba y pedidos de muestra

El SMTP por defecto solo entrega a miembros del equipo, así que el código de las cuentas de prueba se obtiene con la
secret key (convención del portafolio), sin enviar correo.

1. Crea `tool/get_otp.sh` (inglés, `set -euo pipefail`, requiere `curl` y `jq`):
   ```bash
   # Usage (author's shell only; the secret key never goes into the repo or the app):
   #   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SECRET_KEY=sb_secret_... ./tool/get_otp.sh courier@example.com
   ```
   - `POST $SUPABASE_URL/auth/v1/admin/generate_link` con `{"type":"magiclink","email":"<email>"}` y cabeceras
     `apikey: $SUPABASE_SECRET_KEY`, `Authorization: Bearer $SUPABASE_SECRET_KEY`, `Content-Type: application/json`.
   - Si responde que el usuario no existe, créalo con `POST /auth/v1/admin/users` `{"email":"…","email_confirm":true}`
     y repite.
   - Imprime solo el código: `jq -r '.email_otp // .properties.email_otp'`.
   - Verifica en la documentación actual de Supabase Auth (admin API y claves `sb_secret_…`) las cabeceras exactas; si
     `Authorization: Bearer` con la secret key da 401, prueba solo con `apikey` y anota el resultado.
2. **🙋 Acción del autor** (en su terminal): elegir dos emails de prueba (p. ej. `rutta.customer@<su dominio>` y
   `rutta.courier@<su dominio>`, o alias `+` de su correo) y, con la app release apuntando al remoto, para cada uno:
   *Send code* en la app → `./tool/get_otp.sh <email>` → introducir el código → onboarding con nombre.
   (Pedir el código en la app y luego generarlo con el script es válido: el último código generado es el que vale;
   si falla, repetir el script y usar el nuevo.)
3. Promover al repartidor y obtener los UUID:
   ```bash
   psql "$SUPABASE_DB_URL" -c "update rutta.profiles set role = 'courier' where id = (select id from auth.users where email = '<courier email>');"
   psql "$SUPABASE_DB_URL" -At -c "select id from auth.users where email in ('<customer email>', '<courier email>');"
   ```
4. Pedidos de muestra:
   ```bash
   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -v customer_id=<uuid cliente> -v courier_id=<uuid repartidor> \
     -f supabase/scripts/create_sample_orders.sql
   ```
5. Guarda los emails de prueba (no los códigos) en la bitácora para futuras demos.

## Paso 3 · Prueba en vivo en remoto (§16)

**🙋 Acción del autor** (necesita su teléfono o dos emuladores): instala el APK release con el `.env.json` remoto en
dos dispositivos, uno como cliente y otro como repartidor:
1. Repartidor: RT-9001 → *Picked up* (acepta el permiso) → *Start delivery* → camina/conduce (o, en emulador,
   `dart run tool/emulator_drive.dart r2 --serial <id>`).
2. Cliente: RT-9001 → ve el marcador moverse en vivo, la ETA bajar y la línea de tiempo actualizarse.
3. Asigna RT-9002 en vivo (`select rutta.admin_assign_order(…)`) → aparece en la lista del repartidor sin refrescar.
4. Repartidor: *Mark as delivered* → el cliente ve *Delivered* y el marcador desaparece.
5. RLS: con una tercera cuenta cliente (o la del autor) no se ven esos pedidos.
Anota el resultado en la bitácora. Vuelve a ejecutar el script de pedidos de muestra para dejar datos frescos.

## Paso 4 · Firma de release

Igual que Centavo (fase 14, paso 2), con alias `rutta`:
1. **🙋 Acción del autor:** `keytool -genkey -v -keystore ~/keys/rutta-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rutta`
   (fuera del repo; contraseñas en su gestor).
2. **🙋 Acción del autor:** `android/key.properties` (ignorado; verifícalo con `git check-ignore -v android/key.properties`).
3. `android/app/build.gradle.kts`: firma con el keystore si existe `key.properties`, si no con la clave de debug
   (copia el bloque de Centavo).
4. `flutter build apk --release --dart-define-from-file=.env.json` y comprueba la firma con `apksigner verify --print-certs`
   (el certificado no debe ser "Android Debug").

## Paso 5 · Secretos de GitHub

**🙋 Acción del autor** (en su terminal):

```bash
gh secret set ANDROID_KEYSTORE_BASE64 --repo malpi-dev/Rutta < <(base64 -i ~/keys/rutta-release.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD --repo malpi-dev/Rutta
gh secret set ANDROID_KEY_PASSWORD --repo malpi-dev/Rutta
gh secret set ANDROID_KEY_ALIAS --repo malpi-dev/Rutta --body rutta
gh secret set SUPABASE_URL --repo malpi-dev/Rutta
gh secret set SUPABASE_PUBLISHABLE_KEY --repo malpi-dev/Rutta
```

Después verifica con `gh secret list --repo malpi-dev/Rutta` que existen los seis.

## Paso 6 · Workflow de release (`.github/workflows/release.yaml`)

Copia el de Centavo (`../Centavo/.github/workflows/release.yaml`) con estos cambios:
- Sin el paso de `libsqlite3-dev` (Rutta no usa Drift).
- `.env.json` generado con `jq` incluye las 6 claves de `.env.example.json` (`SUPABASE_URL` y
  `SUPABASE_PUBLISHABLE_KEY` desde secretos; `MAP_TILE_URL`, `MAP_USER_AGENT_PACKAGE`, `LOCATION_MIN_INTERVAL_S`,
  `LOCATION_MIN_DISTANCE_M` con sus valores por defecto).
- APK renombrado a `rutta-${GITHUB_REF_NAME}.apk`.
- Misma `flutter-version` que `ci.yaml`.

**Prueba antes de mergear:** desde la rama, `git tag v1.0.0-rc.1 && git push origin v1.0.0-rc.1`. Debe crear un
*pre-release* con `rutta-v1.0.0-rc.1.apk`. Descárgalo (`gh release download v1.0.0-rc.1`), instálalo y haz una prueba
de humo (demo + login remoto). Luego: `gh release delete v1.0.0-rc.1 --cleanup-tag --yes`.

## Paso 7 · Versión

`pubspec.yaml` → `version: 1.0.0+1`.

## Paso 8 · GIF y capturas

1. Capturas (demo, emulador tipo Pixel): lista del cliente, detalle en curso (claro), detalle en curso (oscuro),
   detalle del repartidor con "Sharing location". `adb exec-out screencap -p > docs/media/<nombre>.png`
   (`customer-list.png`, `tracking-light.png`, `tracking-dark.png`, `courier.png`).
2. **GIF split-screen** cliente/repartidor (§16, 15–30 s). Con dos emuladores en demo no hay datos compartidos, así que
   se graba en **live contra Supabase local** (`supabase db reset`): emulador A como `customer@rutta.test` en RT-1044,
   emulador B como `courier1@rutta.test`. Antes, entrega RT-1042 (`update rutta.orders set status = 'delivered' where code = 'RT-1042';`)
   para que courier1 quede libre. Graba ambos a la vez mientras B hace *Picked up* → *Start delivery* (con
   `dart run tool/emulator_drive.dart r3 --serial <B>`) → *Mark as delivered*:
   ```bash
   adb -s <A> shell screenrecord --time-limit 30 /sdcard/a.mp4 & adb -s <B> shell screenrecord --time-limit 30 /sdcard/b.mp4 & wait
   adb -s <A> pull /sdcard/a.mp4 /tmp/ && adb -s <B> pull /sdcard/b.mp4 /tmp/
   ffmpeg -i /tmp/a.mp4 -i /tmp/b.mp4 -filter_complex \
     "[0:v]scale=360:-2[a];[1:v]scale=360:-2[b];[a][b]hstack,fps=12,split[x][y];[x]palettegen[p];[y][p]paletteuse" \
     -loop 0 docs/media/demo.gif
   ```
   El GIF debe pesar < 10 MB (baja `fps` o la escala si no). Si no puedes interactuar con los emuladores mientras
   grabas: **🙋 Acción del autor**. Alternativa aceptable si falla el split-screen: GIF del demo como cliente.

## Paso 9 · README completo (inglés, plantilla del portafolio)

1. **Rutta** + tagline *Know exactly where your order is.* + badges: CI
   (`https://github.com/malpi-dev/Rutta/actions/workflows/ci.yaml/badge.svg`), versión
   (`https://img.shields.io/github/v/release/malpi-dev/Rutta`), plataforma Android, Flutter.
2. GIF + 4 capturas en una tabla.
3. **Try it:** `https://github.com/malpi-dev/Rutta/releases/latest` + "Tap **Explore demo** and pick *customer* or
   *courier* — no account, no internet needed."
4. **Features:** tracking en vivo con marcador animado sobre la ruta, dos roles, máquina de estados validada en la BD,
   flujo de permisos de ubicación, throttling de envío, modo oscuro (también el mapa), demo con repartidor simulado.
5. **Tech stack:** Flutter, Riverpod (generator), go_router, freezed, Supabase (Postgres, Auth OTP, Realtime),
   flutter_map + OpenStreetMap, geolocator, wakelock_plus, Maestro, GitHub Actions.
6. **Architecture:** diagrama Mermaid de capas (`presentation → domain ← data`, `core`), por qué los repositorios son
   intercambiables (`supabase` / `mock` / `geolocator`) y cómo el modo demo cambia de implementación; diagrama de la
   máquina de estados (Mermaid `stateDiagram-v2`).
7. **Swapping the map provider:** pasos para Google Maps (añadir `google_maps_flutter`, implementar `GoogleRuttaMap`
   en `lib/core/map/google/` con `RuttaMapDelegate`, cambiar `ruttaMapBuilderProvider`, API key en el manifest) —
   "screens don't change".
8. **Backend:** tablas del schema `rutta`, tabla de políticas RLS (qué protege cada una), triggers, RPCs
   (`ensure_profile`, `advance_order_status`, `admin_assign_order`), Realtime (`postgres_changes` + RLS, canales
   `rutta:*`), "No Edge Functions: nothing needs a secret key".
9. **Map & routing policies:** OSM tile usage policy (User-Agent, atribución, sin precarga, `MAP_TILE_URL`
   configurable), rutas precalculadas una vez con el servidor demo de OSRM (`tool/fetch_routes.dart`), datos © OSM (ODbL).
10. **Getting started:** requisitos; `flutter pub get` + `dart run build_runner build -d`; **sin** Supabase
    (`flutter run` → solo demo); **con** Supabase local (`supabase start`, `supabase db reset`, `.env.json` desde
    `.env.example.json`, `flutter run --dart-define-from-file=.env.json`; códigos OTP en Mailpit
    `http://127.0.0.1:54324`; usuarios del seed; `./tool/simulate_courier.sh RT-1042`); crear pedidos en remoto
    (`create_sample_orders.sql`, `admin_assign_order`, `tool/get_otp.sh`).
11. **Testing:** `./tool/check.sh`, `supabase test db`, tests de integración (`RUTTA_IT=1 … --tags supabase`),
    `./tool/e2e.sh` (Maestro).
12. **Roadmap:** §3.3 de la definición + "Ideas para el roadmap" de la bitácora.

Añade una sección breve **Privacy** (solo se guarda la última posición del repartidor, solo durante una entrega en
curso y solo con la app abierta; se borra al terminar) y la licencia (MIT, archivo `LICENSE`, si el autor está de
acuerdo — **🙋** confirmar).

## Paso 10 · Verificación final (definición §16)

Recorre la checklist de §16 y márcala en la entrada de la bitácora con evidencia breve por punto (test, captura,
comando o prueba manual): F1–F10 en Android con backend local y remoto; tracking en vivo con dos dispositivos; RLS
(pgTAP + prueba manual); demo sin backend y en modo avión; estados de UI (incluidos sin permiso / sin GPS / *stale*);
tests de dominio y repositorios + 2 flujos de Maestro; CI verde; analyzer limpio; modo oscuro completo con mapa; ícono
y splash; atribución OSM visible; README completo; tabla de estado del `CLAUDE.md` actualizada.

## Paso 11 · Cierre, merge y tag

1. Actualiza la bitácora (fase 14 ✅, `██████████████` 14/14 = 100 %) y, en `docs/definicion.md`, el **Estado** a
   `✅ MVP listo`.
2. Cierra la fase según `00-guia-general.md` §3.3 (PR + CI verde + squash merge).
3. Tag en `main`:
   ```bash
   git checkout main && git pull origin main
   git tag -a v1.0.0 -m "Rutta v1.0.0"
   git push origin v1.0.0
   gh run watch        # espera al workflow Release
   gh release view v1.0.0
   ```
   Descarga el APK del release, instálalo en un emulador limpio y repite la prueba de humo (demo + login remoto).
4. **🙋 Acción del autor:** hacer el repo público (`gh repo edit malpi-dev/Rutta --visibility public
   --accept-visibility-change-consequences`), descripción y topics (`flutter`, `riverpod`, `supabase`, `realtime`,
   `openstreetmap`, `delivery-tracking`). Opcional: renombrarlo a `rutta` en minúsculas (convención del portafolio)
   con `gh repo rename rutta` y actualizar `origin` y los enlaces del README.
5. En la carpeta del portafolio (no es repo): `../CLAUDE.md` y `../README.md` → estado de Rutta `🚀 Publicado` (si hay
   APK + GIF + repo público; si falta algo, `✅ MVP listo`), con enlaces a repo y release.
6. Registra el resultado del release (URL del APK) en la bitácora mediante un PR corto desde la rama
   `docs/release-v1.0.0` (`docs: record v1.0.0 release`), squash merge.

---

## Criterios de terminado

- [ ] Migración aplicada en remoto con `psql`; `rutta` expuesto; RLS (4 tablas), 10 políticas y 3 tablas en la publicación verificadas; seed **no** aplicado.
- [ ] Cuentas de prueba (cliente y repartidor) creadas con `tool/get_otp.sh`; pedidos de muestra en remoto.
- [ ] Prueba en vivo en remoto con dos dispositivos registrada.
- [ ] APK firmado con el keystore de release; secretos en GitHub; workflow `Release` probado con un `-rc` y luego con `v1.0.0`.
- [ ] README completo según la plantilla (GIF, capturas, arquitectura, cambio de mapa, backend, políticas OSM/OSRM, testing).
- [ ] Checklist §16 verificada y registrada en la bitácora.
- [ ] Tag `v1.0.0` con `rutta-v1.0.0.apk` en GitHub Releases; estado del portafolio actualizado.
