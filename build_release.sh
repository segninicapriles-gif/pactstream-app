#!/bin/bash
# Build release APK and App Bundle with obfuscation and compile-time env vars.
# Usage: ./build_release.sh
set -euo pipefail

DEFINES="dart_defines.env"
DEBUG_INFO="build/debug-info"

if [ ! -f "$DEFINES" ]; then
  echo "ERROR: $DEFINES not found. Copy dart_defines.env.example and fill values."
  exit 1
fi

echo "=== Building APK ==="
flutter build apk --release \
  --obfuscate \
  --split-debug-info="$DEBUG_INFO" \
  --dart-define-from-file="$DEFINES"

echo "=== Building App Bundle ==="
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info="$DEBUG_INFO" \
  --dart-define-from-file="$DEFINES"

echo "=== Done. Debug symbols in $DEBUG_INFO ==="
