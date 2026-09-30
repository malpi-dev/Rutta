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
