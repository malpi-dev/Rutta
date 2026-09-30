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
