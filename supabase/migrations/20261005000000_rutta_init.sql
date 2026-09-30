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

-- Policies (all `to authenticated`; (select auth.uid()) is evaluated once per query).

-- profiles: a user always sees their own profile.
create policy profiles_select_own on rutta.profiles
  for select to authenticated
  using (id = (select auth.uid()));
comment on policy profiles_select_own on rutta.profiles is 'A user can read their own profile.';

-- profiles: customer and courier of the same order see each other (name, phone).
create policy profiles_select_counterpart on rutta.profiles
  for select to authenticated
  using (exists (
    select 1 from rutta.orders o
    where (o.customer_id = (select auth.uid()) and o.courier_id = profiles.id)
       or (o.courier_id = (select auth.uid()) and o.customer_id = profiles.id)
  ));
comment on policy profiles_select_counterpart on rutta.profiles is
  'A customer and the courier of one of their orders can read each other''s profile.';

-- profiles: users edit only their own row; the column grant (full_name, phone) keeps role immutable.
create policy profiles_update_own on rutta.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
comment on policy profiles_update_own on rutta.profiles is
  'A user can update their own profile; the column-level grant prevents changing role.';

-- orders: customers read their own orders.
create policy orders_select_customer on rutta.orders
  for select to authenticated
  using (customer_id = (select auth.uid()));
comment on policy orders_select_customer on rutta.orders is 'A customer can read their own orders.';

-- orders: couriers read the orders assigned to them.
create policy orders_select_courier on rutta.orders
  for select to authenticated
  using (courier_id = (select auth.uid()));
comment on policy orders_select_courier on rutta.orders is 'A courier can read the orders assigned to them.';

-- order_status_events: only the customer and the courier of the order read its history.
create policy events_select_participants on rutta.order_status_events
  for select to authenticated
  using (exists (
    select 1 from rutta.orders o
    where o.id = order_status_events.order_id
      and (o.customer_id = (select auth.uid()) or o.courier_id = (select auth.uid()))
  ));
comment on policy events_select_participants on rutta.order_status_events is
  'Only the customer and the courier of an order can read its status history.';

-- courier_locations: a courier reads their own row.
create policy locations_select_own on rutta.courier_locations
  for select to authenticated
  using (courier_id = (select auth.uid()));
comment on policy locations_select_own on rutta.courier_locations is 'A courier can read their own last position.';

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

-- courier_locations: a courier publishes only their own position, only for their own order in progress.
create policy locations_insert_courier on rutta.courier_locations
  for insert to authenticated
  with check (
    courier_id = (select auth.uid())
    and rutta.my_role() = 'courier'
    and exists (
      select 1 from rutta.orders o
      where o.id = courier_locations.order_id
        and o.courier_id = (select auth.uid())
        and o.status in ('picked_up', 'in_transit')
    )
  );
comment on policy locations_insert_courier on rutta.courier_locations is
  'A courier can insert their own position for their own order while it is picked_up or in_transit.';

-- courier_locations: same rule for the update half of an upsert.
create policy locations_update_courier on rutta.courier_locations
  for update to authenticated
  using (courier_id = (select auth.uid()))
  with check (
    courier_id = (select auth.uid())
    and rutta.my_role() = 'courier'
    and exists (
      select 1 from rutta.orders o
      where o.id = courier_locations.order_id
        and o.courier_id = (select auth.uid())
        and o.status in ('picked_up', 'in_transit')
    )
  );
comment on policy locations_update_courier on rutta.courier_locations is
  'A courier can update their own position for their own order while it is picked_up or in_transit.';

-- ---------------------------------------------------------------- realtime
-- Realtime respects RLS: each client only receives rows it can read.
alter publication supabase_realtime add table rutta.orders, rutta.order_status_events, rutta.courier_locations;
