#!/usr/bin/env bash
# Builds the release APK (demo only: no .env.json), installs it on the connected
# device/emulator and runs the Maestro flows in .maestro/. Run it locally before
# tagging a release (E2E is not part of CI).
set -euo pipefail

cd "$(dirname "$0")/.."

command -v maestro >/dev/null || { echo "maestro not found: curl -fsSL \"https://get.maestro.mobile.dev\" | bash"; exit 1; }
command -v adb >/dev/null || { echo "adb not found"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "No device/emulator connected"; exit 1; }

flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
maestro test .maestro/ "$@"
