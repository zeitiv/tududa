#!/usr/bin/env bash
# Regenerates the CI golden images (test/goldens/**/ci/*.png).
#
# Only CI goldens exist (alchemist font-blocks, Ahem): platform goldens are
# disabled in test/goldens/flutter_test_config.dart because they differ per OS.
# Review the image diff and commit the result.
#
#   flutter test --exclude-tags golden           # everyday run, skips goldens
#   flutter test --tags golden                   # compare
#   flutter test --tags golden --update-goldens  # this script
set -euo pipefail
cd "$(dirname "$0")/../.."
flutter test --tags golden --update-goldens test/goldens
