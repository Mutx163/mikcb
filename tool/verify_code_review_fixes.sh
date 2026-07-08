#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> dart analyze lib"
dart analyze lib

echo "==> regression tests (code review fixes)"
flutter test \
  test/providers/import_dedup_test.dart \
  test/providers/timetable_provider_profiles_test.dart \
  test/services/ics_import_service_test.dart \
  test/services/spreadsheet_import_service_test.dart \
  test/services/statistics_service_test.dart \
  test/services/webdav_sync_service_test.dart \
  test/services/webdav_error_message_test.dart \
  test/services/sync_operation_gate_test.dart \
  test/utils/async_utils_test.dart \
  test/utils/import_result_message_test.dart

echo "==> all tests"
flutter test

echo "OK: code review fix verification passed"
