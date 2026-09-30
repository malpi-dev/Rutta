# Rutta

Delivery tracking app (Flutter): the customer sees the courier's live location on a map. Global rules live in
`../CLAUDE.md` (portfolio); the implementation plan is in `docs/implementation/` (read `00-guia-general.md` and
`bitacora.md` first).

## Documented exceptions to portfolio rules

- **No Drift.** Tracking only makes sense online, users create no offline data and demo mode already works offline
  with in-memory mocks (definition §9). The only local persistence is the theme preference (`shared_preferences`).
- **Rule 4 (supabase + mock):** `DeviceLocationRepository` is a device service, so its implementations are
  `geolocator_*` + `mock_*`; `SettingsRepository` is `prefs_*` + `in_memory_*`. Every backend repository
  (`AuthRepository`, `OrdersRepository`, `TrackingRepository`, `ConnectionMonitor`) has `supabase_*` + `mock_*`.
- **No Edge Functions, no Storage:** nothing needs a secret key (routes are precomputed, no push).

## Commands

- `./tool/check.sh`: full verification (pub get, l10n, build_runner, format, architecture, analyze, tests).
- `dart run build_runner watch -d`: code generation while developing.
- `flutter run`: demo mode only.
- `flutter run --dart-define-from-file=.env.json`: with Supabase.

## Rules

- `flutter_map`/`latlong2` only in `lib/core/map/`; `geolocator` only in `lib/features/tracking/data/`.
- The domain uses `GeoPoint`; the DB uses `[lng, lat]`.
- Timestamps are UTC via `Clock`; money is `int` cents (MXN).
- UI strings live in `app_en.arb`; generated files are not committed.
