#!/usr/bin/env bash
# Prints a 6-digit login code for a test account on the REMOTE Supabase project, without sending any email
# (the default SMTP only delivers to organization members). Creates the user if it does not exist yet.
#
# Usage (author's shell only; the secret key never goes into the repo or the app):
#   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SECRET_KEY=sb_secret_... ./tool/get_otp.sh courier@example.com
#
# Requires: curl, jq.
set -euo pipefail

EMAIL="${1:?Usage: $0 <email>}"
: "${SUPABASE_URL:?Set SUPABASE_URL (https://<ref>.supabase.co)}"
: "${SUPABASE_SECRET_KEY:?Set SUPABASE_SECRET_KEY (sb_secret_...)}"
for bin in curl jq; do
  command -v "$bin" >/dev/null || { echo "Missing dependency: $bin" >&2; exit 1; }
done
if [[ "$SUPABASE_SECRET_KEY" != sb_secret_* ]]; then
  echo "SUPABASE_SECRET_KEY must be a secret key (sb_secret_...)." >&2
  exit 1
fi
BASE="${SUPABASE_URL%/}/auth/v1/admin"

# Prints the response body on stdout and the HTTP status on the last line.
call() {
  local path="$1" body="$2"
  curl -sS -X POST "$BASE/$path" \
    -H "apikey: $SUPABASE_SECRET_KEY" \
    -H "Content-Type: application/json" \
    -d "$body" -w '\n%{http_code}'
}

generate() { call generate_link "$(jq -n --arg e "$EMAIL" '{type: "magiclink", email: $e}')"; }

out="$(generate)"
status="${out##*$'\n'}"
body="${out%$'\n'*}"

if [[ "$status" != 2* ]]; then
  # Unknown user: create it (already confirmed) and retry once.
  echo "generate_link returned HTTP $status; creating the user and retrying..." >&2
  created="$(call users "$(jq -n --arg e "$EMAIL" '{email: $e, email_confirm: true}')")"
  cstatus="${created##*$'\n'}"
  if [[ "$cstatus" != 2* ]]; then
    echo "Could not create the user (HTTP $cstatus): ${created%$'\n'*}" >&2
    exit 1
  fi
  out="$(generate)"
  status="${out##*$'\n'}"
  body="${out%$'\n'*}"
  if [[ "$status" != 2* ]]; then
    echo "generate_link failed (HTTP $status): $body" >&2
    exit 1
  fi
fi

code="$(jq -r '.email_otp // .properties.email_otp // empty' <<<"$body")"
[[ -n "$code" ]] || { echo "No email_otp in the response." >&2; exit 1; }
echo "$code"
