# Fase 09 · Backend Supabase (local)

**Rama:** `feat/fase-09-backend-supabase`
**Objetivo:** schema `rutta` en Supabase local: tablas, constraints, índice de un pedido en curso por repartidor,
funciones y triggers (máquina de estados, historial, borrado de ubicación, hora del servidor), RPCs
(`ensure_profile`, `advance_order_status`, `admin_assign_order`), RLS con cada política comentada, publicación de
Realtime, seed local con rutas reales, script de pedidos para remoto, tests pgTAP y job de CI.
Todavía **no** se toca el proyecto remoto (fase 14) ni el cliente Flutter (fases 10–11).
**Referencias:** definición §6.2, §6.3, §7 completo, §13 (BD) · `CLAUDE.md` del portafolio (Backend, Convenciones del
proyecto compartido) · bitácora (`ensure_profile`, `my_role`, grants por columna, `recorded_at`, mensajes `RUTTA_*`,
seed con historial reescrito).
**Requisitos previos:** fase 08 terminada. Docker Desktop encendido (si no: **🙋 Acción del autor**). Supabase CLI.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

**Conflicto de puertos:** Agendo y Centavo usan los mismos puertos locales (54321–54324). Antes de arrancar Rutta:
`supabase stop --project-id agendo; supabase stop --project-id centavo` (ignora errores si no estaban corriendo).

## Paso 1 · Inicializar Supabase

```bash
supabase init            # crea supabase/config.toml (responde "N" a los settings de VS Code/Deno si pregunta)
```

Edita `supabase/config.toml` (igual que Centavo, ver `../Centavo/supabase/config.toml`):

- `project_id = "rutta"`.
- `[api]`: `schemas = ["public", "graphql_public", "rutta"]`, `extra_search_path = ["public", "extensions"]`.
- `[realtime]`: `enabled = true`.
- `[auth]`: `enable_signup = true`. `[auth.email]`: `enable_signup = true`, `enable_confirmations = true`,
  `otp_length = 6`, `otp_expiry = 3600`.
- `[auth.rate_limit]`: `email_sent = 30` **solo en local** (comentario: "local only; remote uses the default SMTP limits").
- Plantillas (convención común: código de 6 dígitos, texto neutro):
  ```toml
  [auth.email.template.confirmation]
  subject = "Your verification code"
  content_path = "./supabase/templates/otp.html"

  [auth.email.template.magic_link]
  subject = "Your verification code"
  content_path = "./supabase/templates/otp.html"
  ```
  `supabase/templates/otp.html`: copia `../Centavo/supabase/templates/otp.html` (usa `{{ .Token }}`).
- `[db.seed]`: `enabled = true`, `sql_paths = ["./seed.sql"]`.

Si alguna clave no existe con ese nombre en la versión de la CLI, busca la equivalente en el `config.toml` generado y
anótalo en la bitácora.

## Paso 2 · Migración `supabase/migrations/20261005000000_rutta_init.sql`

Crea el archivo **a mano con ese nombre**. **Nunca** `supabase db push` (en remoto se aplica con `psql`, fase 14).
Contenido (inglés; ajusta solo si algo no compila y anótalo):

```sql
-- Rutta delivery tracking schema. Touches ONLY schema "rutta" (docs/definicion.md §7).
-- No PostGIS: coordinates are double precision and routes are jsonb arrays of [lng, lat] (GeoJSON order).

create schema if not exists rutta;
grant usage on schema rutta to authenticated, service_role;

-- ---------------------------------------------------------------- tables

create table rutta.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null check (char_length(full_name) between 1 and 80),
  role       text not null default 'customer' check (role in ('customer', 'courier')),
  phone      text,
  created_at timestamptz not null default now()
);

create table rutta.orders (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,
  customer_id      uuid not null,
  courier_id       uuid,
  status           text not null default 'created'
                   check (status in ('created', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
  pickup_name      text not null,
  pickup_address   text not null,
  pickup_lat       double precision not null check (pickup_lat between -90 and 90),
  pickup_lng       double precision not null check (pickup_lng between -180 and 180),
  dropoff_address  text not null,
  dropoff_lat      double precision not null check (dropoff_lat between -90 and 90),
  dropoff_lng      double precision not null check (dropoff_lng between -180 and 180),
  items            jsonb not null check (jsonb_typeof(items) = 'array'),
  total_cents      integer not null check (total_cents >= 0),
  -- CASE guarantees jsonb_array_length only runs on arrays (AND has no guaranteed evaluation order).
  route            jsonb not null
                   check (case when jsonb_typeof(route) = 'array' then jsonb_array_length(route) >= 2 else false end),
  route_distance_m integer not null check (route_distance_m > 0),
  route_duration_s integer not null check (route_duration_s > 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint orders_customer_id_fkey foreign key (customer_id) references rutta.profiles (id) on delete cascade,
  constraint orders_courier_id_fkey foreign key (courier_id) references rutta.profiles (id),
  -- No delivery states without a courier.
  constraint orders_courier_required check (status in ('created', 'cancelled') or courier_id is not null)
);

-- Business rule 2: at most one order in progress per courier.
create unique index one_active_order_per_courier on rutta.orders (courier_id)
  where status in ('picked_up', 'in_transit');
create index orders_customer_idx on rutta.orders (customer_id, created_at desc);
create index orders_courier_idx on rutta.orders (courier_id, created_at desc);

create table rutta.order_status_events (
  id         bigint generated always as identity primary key,
  order_id   uuid not null references rutta.orders (id) on delete cascade,
  status     text not null
             check (status in ('created', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
  changed_by uuid,                                   -- null = system / admin
  created_at timestamptz not null default now()
);
create index order_status_events_order_idx on rutta.order_status_events (order_id, created_at);

-- One row per courier: their last known position (no history, definition §3.2).
create table rutta.courier_locations (
  courier_id  uuid primary key references rutta.profiles (id) on delete cascade,
  order_id    uuid not null references rutta.orders (id) on delete cascade,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  heading     real check (heading is null or heading between 0 and 360),
  speed_mps   real check (speed_mps is null or speed_mps >= 0),
  accuracy_m  real check (accuracy_m is null or accuracy_m >= 0),
  recorded_at timestamptz not null default now()
);
create index courier_locations_order_idx on rutta.courier_locations (order_id);

-- ---------------------------------------------------------------- helper functions

-- Role of the caller. SECURITY DEFINER so policies can use it without RLS recursion on profiles.
create or replace function rutta.my_role() returns text
language sql stable security definer set search_path = '' as $$
  select p.role from rutta.profiles p where p.id = auth.uid();
$$;

-- Transition table of definition §6.2. Mirrored in Dart (OrderStatus.transitions); tests keep both identical.
create or replace function rutta.is_valid_transition(p_from text, p_to text) returns boolean
language sql immutable set search_path = '' as $$
  select (p_from, p_to) in (
    ('created', 'assigned'), ('created', 'cancelled'),
    ('assigned', 'picked_up'), ('assigned', 'cancelled'),
    ('picked_up', 'in_transit'),
    ('in_transit', 'delivered')
  );
$$;

-- ---------------------------------------------------------------- triggers

-- Defense in depth: rejects any invalid status change, whatever path it comes from. Keeps updated_at current.
create or replace function rutta.orders_guard_status() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status is distinct from old.status and not rutta.is_valid_transition(old.status, new.status) then
    raise exception 'RUTTA_INVALID_TRANSITION from=% to=%', old.status, new.status using errcode = 'P0001';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger orders_guard_status before update on rutta.orders
  for each row execute function rutta.orders_guard_status();

-- Status history with server time (business rule 5).
create or replace function rutta.orders_log_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into rutta.order_status_events (order_id, status, changed_by) values (new.id, new.status, auth.uid());
  end if;
  return null;
end;
$$;
create trigger orders_log_status after insert or update of status on rutta.orders
  for each row execute function rutta.orders_log_status();

-- Business rule 4: when an order ends, forget where its courier was.
create or replace function rutta.orders_clear_location() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status in ('delivered', 'cancelled') and new.status is distinct from old.status then
    delete from rutta.courier_locations where order_id = new.id;
  end if;
  return null;
end;
$$;
create trigger orders_clear_location after update of status on rutta.orders
  for each row execute function rutta.orders_clear_location();

-- recorded_at always uses the server clock (an upsert would not apply the column default on update).
create or replace function rutta.courier_locations_stamp() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.recorded_at := now();
  return new;
end;
$$;
create trigger courier_locations_stamp before insert or update on rutta.courier_locations
  for each row execute function rutta.courier_locations_stamp();

-- ---------------------------------------------------------------- RPCs

-- The ONLY way to create a Rutta profile (no trigger on the shared auth.users). Idempotent: an existing profile
-- is returned unchanged. New profiles are always 'customer' (couriers are promoted with SQL).
create or replace function rutta.ensure_profile(p_full_name text)
returns rutta.profiles
language plpgsql security definer set search_path = '' as $$
declare
  v_uid     uuid := auth.uid();
  v_name    text := btrim(coalesce(p_full_name, ''));
  v_profile rutta.profiles;
begin
  if v_uid is null then
    raise exception 'RUTTA_UNAUTHORIZED' using errcode = '28000';
  end if;
  select * into v_profile from rutta.profiles where id = v_uid;
  if found then
    return v_profile;
  end if;
  if char_length(v_name) not between 1 and 80 then
    raise exception 'RUTTA_INVALID_NAME' using errcode = '22023';
  end if;
  insert into rutta.profiles (id, full_name, role) values (v_uid, v_name, 'customer')
  on conflict (id) do nothing;
  select * into v_profile from rutta.profiles where id = v_uid;
  return v_profile;
end;
$$;

-- Courier moves their own order one step forward. Error messages have fixed prefixes that the app maps.
create or replace function rutta.advance_order_status(p_order_id uuid, p_next text)
returns rutta.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_uid   uuid := auth.uid();
  v_order rutta.orders;
begin
  if v_uid is null then
    raise exception 'RUTTA_UNAUTHORIZED' using errcode = '28000';
  end if;
  select * into v_order from rutta.orders where id = p_order_id for update;
  if not found then
    raise exception 'RUTTA_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_order.courier_id is distinct from v_uid then
    raise exception 'RUTTA_NOT_ASSIGNED' using errcode = '42501';
  end if;
  if coalesce(rutta.my_role(), '') <> 'courier' then
    raise exception 'RUTTA_NOT_COURIER' using errcode = '42501';
  end if;
  if (v_order.status, p_next) not in (('assigned', 'picked_up'), ('picked_up', 'in_transit'), ('in_transit', 'delivered')) then
    raise exception 'RUTTA_INVALID_TRANSITION from=% to=%', v_order.status, p_next using errcode = 'P0001';
  end if;
  begin
    update rutta.orders set status = p_next where id = p_order_id returning * into v_order;
  exception when unique_violation then
    raise exception 'RUTTA_COURIER_BUSY' using errcode = 'P0001';   -- one_active_order_per_courier
  end;
  return v_order;
end;
$$;

-- created -> assigned. Only with the secret key / SQL editor (execute revoked from app roles below).
create or replace function rutta.admin_assign_order(p_order_id uuid, p_courier_id uuid)
returns rutta.orders
language plpgsql security definer set search_path = '' as $$
declare
  v_order  rutta.orders;
  v_status text;
begin
  if not exists (select 1 from rutta.profiles where id = p_courier_id and role = 'courier') then
    raise exception 'RUTTA_NOT_COURIER' using errcode = 'P0001';
  end if;
  select status into v_status from rutta.orders where id = p_order_id;
  if v_status is null then
    raise exception 'RUTTA_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_status <> 'created' then
    raise exception 'RUTTA_INVALID_TRANSITION from=% to=assigned', v_status using errcode = 'P0001';
  end if;
  update rutta.orders set courier_id = p_courier_id, status = 'assigned' where id = p_order_id
  returning * into v_order;
  return v_order;
end;
$$;

comment on function rutta.ensure_profile(text) is 'Creates the caller''s Rutta profile (role customer) if missing and returns it.';
comment on function rutta.advance_order_status(uuid, text) is 'Assigned courier moves the order assigned -> picked_up -> in_transit -> delivered.';
comment on function rutta.admin_assign_order(uuid, uuid) is 'Admin only (secret key / SQL editor): assigns a created order to a courier.';

revoke execute on function rutta.ensure_profile(text) from public, anon;
revoke execute on function rutta.advance_order_status(uuid, text) from public, anon;
revoke execute on function rutta.admin_assign_order(uuid, uuid) from public, anon, authenticated;
grant execute on function rutta.ensure_profile(text) to authenticated;
grant execute on function rutta.advance_order_status(uuid, text) to authenticated;
grant execute on function rutta.admin_assign_order(uuid, uuid) to service_role;
grant execute on function rutta.my_role() to authenticated;

-- ---------------------------------------------------------------- privileges

revoke all on all tables in schema rutta from anon, authenticated;
grant select on rutta.profiles, rutta.orders, rutta.order_status_events, rutta.courier_locations to authenticated;
-- Users may edit their name/phone but never their role.
grant update (full_name, phone) on rutta.profiles to authenticated;
-- Couriers upsert their own last position (PostgREST upsert also sets courier_id in DO UPDATE).
grant insert (courier_id, order_id, lat, lng, heading, speed_mps, accuracy_m) on rutta.courier_locations to authenticated;
grant update (courier_id, order_id, lat, lng, heading, speed_mps, accuracy_m) on rutta.courier_locations to authenticated;
-- orders and order_status_events: no insert/update/delete for app users (RPCs and triggers only).
grant all on all tables in schema rutta to service_role;
grant usage, select on all sequences in schema rutta to service_role;

-- ---------------------------------------------------------------- row level security

alter table rutta.profiles            enable row level security;
alter table rutta.orders              enable row level security;
alter table rutta.order_status_events enable row level security;
alter table rutta.courier_locations   enable row level security;
-- anon has no grants and no policies: every anonymous request is denied.
```

Continúa el archivo con las **políticas**, todas `to authenticated`, cada una con un comentario SQL encima y su
`comment on policy` en inglés. Usa siempre `(select auth.uid())` (se evalúa una vez por consulta). Tabla completa:

| Tabla | Política | Operación | Condición |
|---|---|---|---|
| `profiles` | `profiles_select_own` | select | `id = (select auth.uid())` |
| `profiles` | `profiles_select_counterpart` | select | `exists (select 1 from rutta.orders o where (o.customer_id = (select auth.uid()) and o.courier_id = profiles.id) or (o.courier_id = (select auth.uid()) and o.customer_id = profiles.id))` |
| `profiles` | `profiles_update_own` | update | `using` y `with check`: `id = (select auth.uid())` (el grant por columna impide tocar `role`) |
| `orders` | `orders_select_customer` | select | `customer_id = (select auth.uid())` |
| `orders` | `orders_select_courier` | select | `courier_id = (select auth.uid())` |
| `order_status_events` | `events_select_participants` | select | `exists (select 1 from rutta.orders o where o.id = order_status_events.order_id and (o.customer_id = (select auth.uid()) or o.courier_id = (select auth.uid())))` |
| `courier_locations` | `locations_select_own` | select | `courier_id = (select auth.uid())` |
| `courier_locations` | `locations_select_customer_active` | select | `exists (select 1 from rutta.orders o where o.id = courier_locations.order_id and o.customer_id = (select auth.uid()) and o.status in ('picked_up', 'in_transit'))` |
| `courier_locations` | `locations_insert_courier` | insert | `with check`: `courier_id = (select auth.uid()) and rutta.my_role() = 'courier' and exists (select 1 from rutta.orders o where o.id = courier_locations.order_id and o.courier_id = (select auth.uid()) and o.status in ('picked_up', 'in_transit'))` |
| `courier_locations` | `locations_update_courier` | update | `using`: `courier_id = (select auth.uid())`; `with check`: la misma condición que el insert |

Ejemplo de formato:

```sql
-- courier_locations: customers only see the courier of THEIR order, and only while it is in progress.
create policy locations_select_customer_active on rutta.courier_locations
  for select to authenticated
  using (exists (
    select 1 from rutta.orders o
    where o.id = courier_locations.order_id
      and o.customer_id = (select auth.uid())
      and o.status in ('picked_up', 'in_transit')
  ));
comment on policy locations_select_customer_active on rutta.courier_locations is
  'A customer sees the courier location only for their own order while it is picked_up or in_transit.';
```

La §7.2 de la definición habla de una sola política `locations_upsert_courier` para insert/update: en Postgres cada
política es de un comando, así que son dos (`locations_insert_courier`, `locations_update_courier`). Tampoco se crea
`is_order_customer()`: las políticas usan `exists` sobre `rutta.orders` (sin recursión, porque las políticas de
`orders` no consultan otras tablas). Anota ambas cosas en la bitácora.

Termina con la publicación de Realtime (Realtime respeta RLS: cada cliente solo recibe filas que puede leer):

```sql
-- ---------------------------------------------------------------- realtime
alter publication supabase_realtime add table rutta.orders, rutta.order_status_events, rutta.courier_locations;
```

## Paso 3 · Seed local (`supabase/seed.sql`)

Solo local (§7.6: **nunca** se aplica en remoto, `auth.users` es compartido). Sin metacomandos de `psql`.
Estructura:

1. **Usuarios** (UUID fijos; columnas de token `''`, no `NULL`; copia el patrón de `../Centavo/supabase/seed.sql`
   para `auth.users` + `auth.identities`):

   | Email | UUID | Perfil |
   |---|---|---|
   | `customer@rutta.test` | `a1000000-0000-4000-8000-000000000001` | Alex Rivera · `customer` |
   | `courier1@rutta.test` | `a2000000-0000-4000-8000-000000000001` | Carlos Méndez · `courier` |
   | `courier2@rutta.test` | `a2000000-0000-4000-8000-000000000002` | María López · `courier` |

   Los perfiles se insertan directamente (como `postgres`), con su rol.
2. **Bloque de rutas** vacío con los marcadores del paso 5.4 de la fase 04:
   ```sql
   -- BEGIN GENERATED ROUTES (tool/fetch_routes.dart)
   -- END GENERATED ROUTES
   ```
   y ejecuta `dart run tool/fetch_routes.dart --from-cache` para rellenarlo.
3. **Pedidos** (todos del cliente), insertados con un `insert … select` desde una lista `values` unida a `seed_routes`
   (`created_at = now() - offset`):

   | Código | Ruta | Estado | Repartidor | Ítems · total | Eventos (minutos atrás) |
   |---|---|---|---|---|---|
   | RT-1042 | r1 | `in_transit` | courier1 | 2× Flat white, 1× Butter croissant · 18500 | created 25, assigned 22, picked_up 12, in_transit 8 |
   | RT-1043 | r2 | `picked_up` | courier2 | 1× Ibuprofen 400 mg, 2× Electrolyte drink · 24900 | created 15, assigned 12, picked_up 3 |
   | RT-1044 | r3 | `assigned` | courier1 | 1× Quinoa bowl, 1× Green juice · 21000 | created 9, assigned 5 |
   | RT-1045 | r4 | `created` | — | 6× Concha, 1× Café de olla · 13500 | created 2 |
   | RT-1038 | r5 | `delivered` | courier1 | 1× Vitamin C 1 g · 9900 | created 1490, assigned 1487, picked_up 1475, in_transit 1472, delivered 1456 |
   | RT-1036 | r6 | `delivered` | courier2 | 1× Salmon poke bowl · 23500 | created 2930, assigned 2926, picked_up 2915, in_transit 2911, delivered 2890 |
   | RT-1034 | r4 | `cancelled` | — | 2× Iced latte · 11000 | created 4330, cancelled 4325 |
   | RT-1033 | r1 | `cancelled` | courier2 | 1× Club sandwich · 15500 | created 5000, assigned 4996, cancelled 4990 |

   `items` como `jsonb` (`'[{"name":"Flat white","quantity":2},…]'`). Con esto courier1 tiene un pedido en curso
   (RT-1042) y otro asignado (RT-1044: permite probar `CourierBusy`); courier2 tiene RT-1043 en curso.
4. **Historial:** el trigger insertó un evento por pedido con `now()`. Bórralos
   (`delete from rutta.order_status_events where order_id in (select id from rutta.orders);`) e inserta los de la tabla
   con `created_at = now() - make_interval(mins => …)` y `changed_by` = el repartidor (o `null` para created/cancelled).
5. **Ubicaciones:** courier1 en RT-1042 al 40 % de la ruta
   (`route -> (jsonb_array_length(route) * 4 / 10)`, `lat = (p ->> 1)::float8`, `lng = (p ->> 0)::float8`);
   courier2 en RT-1043 en el primer punto de la ruta. `recorded_at` lo pone el trigger (`now()`): a los 30 s de
   `db reset` ya se ve como *stale*, útil para probar ese estado.
6. `drop table seed_routes;`

Comprueba: `supabase db reset` sin errores; `select code, status from rutta.orders order by code;` da los 8 pedidos;
`select count(*) from rutta.order_status_events;` = 25.

## Paso 4 · Script de pedidos para remoto (`supabase/scripts/create_sample_orders.sql`)

Para el proyecto compartido (fase 14), donde los usuarios se crean a mano. Uso (en la cabecera del archivo):

```sql
-- Creates sample orders for an existing customer and courier (both must already have a rutta.profiles row;
-- the courier with role 'courier'). Safe to re-run: deletes previous RT-9xxx orders of that customer first.
-- Usage:
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -v customer_id=<uuid> -v courier_id=<uuid> \
--     -f supabase/scripts/create_sample_orders.sql
```

Contenido: `begin;` → bloque de rutas generado (mismos marcadores) → borrar `RT-9%` del cliente → insertar:
RT-9001 (r2, `created`) y asignarlo con `select rutta.admin_assign_order(<id>, :'courier_id'::uuid);` (listo para
*Picked up*); RT-9002 (r3, `created`, sin repartidor: sirve para asignarlo en vivo y ver cómo aparece en la lista del
repartidor sin refrescar); RT-9003 (r6, `delivered`, con su historial reescrito como en el seed) → `drop table seed_routes;`
→ `commit;`. Usa `:'customer_id'::uuid` en sentencias normales (las variables de `psql` no funcionan dentro de `do $$`).
Al final imprime un recordatorio con `\echo` de cómo asignar RT-9002:
`select rutta.admin_assign_order((select id from rutta.orders where code = 'RT-9002'), '<courier uuid>');`.

Pruébalo en local contra los usuarios del seed:

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 \
  -v customer_id=a1000000-0000-4000-8000-000000000001 -v courier_id=a2000000-0000-4000-8000-000000000002 \
  -f supabase/scripts/create_sample_orders.sql
```

(Con courier2, que ya tiene RT-1043 en curso: RT-9001 queda `assigned`, sin conflicto.) Ejecútalo dos veces: la
segunda no debe fallar.

## Paso 5 · Tests pgTAP (`supabase/tests/`)

Dos archivos con la estructura de Centavo (`begin; create extension if not exists pgtap with schema extensions;
select plan(N); … select * from finish(); rollback;`). Para actuar como un usuario:

```sql
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}';
```

Fixtures (como `postgres`, al inicio de cada archivo): clientes A y B, repartidores K1 y K2 (en `auth.users` +
`rutta.profiles`), pedidos O1 (A, K1, `in_transit`), O2 (A, K2, `assigned`), O3 (B, K2, `picked_up`),
O4 (A, K1, `assigned`), O5 (A, sin repartidor, `created`), con rutas de 2 puntos cualesquiera, y ubicaciones de K1
(O1) y K2 (O3).

**`rls_test.sql`**, como mínimo:
- A ve exactamente O1, O2, O4, O5; ve eventos solo de sus pedidos; ve **1** ubicación (K1 en O1; no la de K2 en O3,
  que es de B); ve su perfil + K1 + K2 y **no** el de B.
- B ve solo O3 y la ubicación de K2.
- K1 ve O1 y O4 (no O2/O3/O5); ve el perfil de A.
- A no puede cambiar su `role` (`42501`, privilegio por columna) pero sí su `full_name` (1 fila).
- A no puede insertar/actualizar/borrar en `orders` ni en `order_status_events` (`42501`).
- A no puede insertar en `courier_locations` (`42501`).
- K1 puede hacer upsert de su ubicación en O1 (`insert … on conflict (courier_id) do update …`).
- K1 no puede publicar ubicación para O4 (`assigned`, no en curso) → `42501`; K2 no puede publicar con `courier_id` de K1 → `42501`.
- `anon`: `select` en `rutta.orders` → `42501`; `rutta.ensure_profile('x')` → `42501`.
- `authenticated`: `rutta.admin_assign_order(...)` → `42501`.
- `ensure_profile`: un usuario nuevo N obtiene perfil `customer`; una segunda llamada con otro nombre devuelve el nombre
  original; nombre vacío → `22023`; sin `sub` (sin sesión) → `28000`.

**`business_test.sql`**, como mínimo:
- Las 36 combinaciones de `is_valid_transition` coinciden con la lista esperada (`results_eq` de los pares `true`
  contra los 6 de §6.2).
- Camino feliz de K1: `advance_order_status(O1, 'delivered')` devuelve `delivered`, añade un evento con
  `changed_by = K1` y **borra** la ubicación de K1; después O4 avanza `picked_up` → `in_transit` sin errores.
  (Haz este caso **después** del de `RUTTA_COURIER_BUSY`, que necesita O1 todavía `in_transit`.)
- Saltar estados (`assigned → delivered`) → `throws_like(…, 'RUTTA_INVALID_TRANSITION from=assigned to=delivered')`.
- A (cliente) avanzando O1 → `RUTTA_NOT_ASSIGNED`; K2 avanzando O1 → `RUTTA_NOT_ASSIGNED`; id inexistente → `RUTTA_NOT_FOUND`.
- K1 con O1 `in_transit` intenta `picked_up` en O4 → `RUTTA_COURIER_BUSY`.
- Como `postgres`, `update rutta.orders set status = 'assigned'` sobre un pedido `delivered` → `RUTTA_INVALID_TRANSITION…`.
- `updated_at` cambia al actualizar; el trigger de historial registra la transición.
- `admin_assign_order` (como `postgres`): O5 `created → assigned` con evento; a un cliente → `RUTTA_NOT_COURIER`;
  sobre un pedido ya asignado → `RUTTA_INVALID_TRANSITION from=assigned to=assigned`.
- `recorded_at` lo fija el servidor: insertar con `recorded_at = '2000-01-01'` guarda `now()`.
- Constraints: estado desconocido → `23514`; `assigned` sin repartidor → `23514`; ruta de 1 punto → `23514`;
  ruta que no es array (`'{}'`) → `23514` (no un error de función); segundo pedido en curso del mismo repartidor
  insertado directamente → `23505`.

```bash
supabase db reset && supabase test db
```

## Paso 6 · Job de base de datos en CI

Añade a `.github/workflows/ci.yaml` un segundo job en paralelo (igual que Centavo):

```yaml
  database:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with:
          version: latest
      - name: Start Supabase (only the services the tests need)
        run: supabase start -x studio,imgproxy,storage-api,edge-runtime,logflare,vector,supavisor
      - run: supabase test db
```

- A diferencia de Centavo, aquí **no** se excluye `realtime` (la lista `-x` de arriba no lo incluye a propósito): la
  migración altera la publicación `supabase_realtime`.
- Comprueba los nombres válidos para `-x` con `supabase start --help`. Misma versión mayor de `actions/checkout` que el
  job de Flutter. Si el job es inestable, déjalo con `continue-on-error: true`, anótalo y avisa al autor.

## Paso 7 · Entorno local para la app

```bash
supabase status          # copia la API URL y la publishable key (sb_publishable_…) — NUNCA la secret key
```

Crea `.env.json` (ignorado por git) desde `.env.example.json` con `SUPABASE_URL = http://10.0.2.2:54321` y la
publishable key local. Verifica que `git status` **no** lo muestra.

Comprobación rápida de que `anon` no ve nada (debe responder error de permisos, nunca datos):

```bash
curl -s "http://127.0.0.1:54321/rest/v1/orders?select=code" \
  -H "apikey: <publishable key>" -H "Accept-Profile: rutta"
```

## Paso 8 · Cierre

`00-guia-general.md` §3.3 (incluye `supabase db reset` y `supabase test db`). Deja Supabase local corriendo para la
fase 10 o detenlo con `supabase stop`.

---

## Criterios de terminado

- [ ] `config.toml` expone `rutta`, OTP de 6 dígitos, plantilla con `{{ .Token }}`, Realtime activo y seed configurado.
- [ ] Migración `20261005000000_rutta_init.sql` solo toca `rutta`: tablas, índices, funciones, triggers, RPCs, grants, RLS en las 4 tablas con **todas** las políticas comentadas y publicación de Realtime.
- [ ] `supabase db reset` aplica migración + seed (8 pedidos, 25 eventos, 2 ubicaciones, rutas reales).
- [ ] `create_sample_orders.sql` funciona dos veces seguidas en local.
- [ ] `supabase test db` en verde (RLS y reglas de negocio).
- [ ] Job `database` en CI; `.env.json` local creado y fuera de git; `anon` sin acceso comprobado con `curl`.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada (incluye las desviaciones del paso 2).
