#!/bin/sh
# android/gradlew is gitignored (Flutter generates it). Make sure it exists.
# Run after `flutter pub get` (which writes android/local.properties).
set -eu

if [ -x android/gradlew ]; then
  exit 0
fi

echo "android/gradlew missing; asking Flutter to generate it"
flutter build apk --config-only --debug >/dev/null 2>&1 || true

if [ -f android/gradlew ] && [ ! -x android/gradlew ]; then
  chmod +x android/gradlew
fi

if [ ! -x android/gradlew ]; then
  echo "falling back to the runner's system gradle to generate the wrapper"
  ver=$(sed -n 's#.*gradle-\([0-9][0-9.]*\)-\(bin\|all\)\.zip.*#\1#p' android/gradle/wrapper/gradle-wrapper.properties | head -n1)
  (cd android && gradle wrapper ${ver:+--gradle-version "$ver"})
fi

if [ ! -x android/gradlew ]; then
  echo "::error::could not create android/gradlew"
  exit 1
fi
