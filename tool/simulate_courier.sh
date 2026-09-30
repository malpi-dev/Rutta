#!/usr/bin/env bash
# Moves the courier of an in-progress order along its route in LOCAL Supabase.
# Writes to rutta.courier_locations as `postgres` (no RLS); Realtime delivers it
# to the customer client with the customer's own policies.
#
# Usage: ./tool/simulate_courier.sh RT-1042 [seconds-between-points]
set -euo pipefail

CODE="${1:?Usage: $0 <order-code> [seconds between points, default 2]}"
INTERVAL="${2:-2}"
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

case "$DB_URL" in
  *@127.0.0.1[:/]*|*@localhost[:/]*) ;;
  *) echo "Refusing to run: DB_URL must point to 127.0.0.1/localhost (local Supabase only)." >&2; exit 1 ;;
esac
if ! [[ "$CODE" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "Invalid order code: $CODE" >&2
  exit 1
fi

run_sql() { psql "$DB_URL" -v ON_ERROR_STOP=1 -At -c "$1"; }

status="$(run_sql "select status from rutta.orders where code = '$CODE';")"
if [[ "$status" != "picked_up" && "$status" != "in_transit" ]]; then
  echo "Order $CODE is not in progress (status: ${status:-not found}). Nothing to simulate." >&2
  exit 1
fi

points=()
while IFS= read -r line; do points+=("$line"); done < <(run_sql \
  "select (p->>1) || ' ' || (p->>0) from rutta.orders o, jsonb_array_elements(o.route) with ordinality t(p, i) where o.code = '$CODE' order by i;")

total=${#points[@]}
step=$(( (total + 59) / 60 ))
echo "Simulating $CODE: $total route points, sending every ${step}th, one every ${INTERVAL}s. Ctrl+C to stop."

sent=0
for ((i = 0; i < total; i += step)); do
  read -r lat lng <<<"${points[$i]}"
  run_sql "insert into rutta.courier_locations (courier_id, order_id, lat, lng, speed_mps) select courier_id, id, $lat, $lng, 8.3 from rutta.orders where code = '$CODE' and status in ('picked_up','in_transit') on conflict (courier_id) do update set order_id = excluded.order_id, lat = excluded.lat, lng = excluded.lng, speed_mps = excluded.speed_mps;" >/dev/null
  sent=$((sent + 1))
  echo "[$sent] $lat, $lng"
  sleep "$INTERVAL"
done
echo "Done: route finished."
