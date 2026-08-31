#!/usr/bin/env bats
# openxchg.bats - test suite for openxchg 2.x
#
# All API traffic is served by tests/mocks/wget from generated fixtures;
# no network access and no writes outside the per-test temp directory.

load 'test_helper'

setup() { setup_test_env; }
teardown() { teardown_test_env; }

# --- CLI basics ---

@test "version output" {
  run "$OPENXCHG_BIN" -V
  assert_success
  assert_output --regexp '^openxchg [0-9]+\.[0-9]+\.[0-9]+$'
}

@test "help output" {
  run "$OPENXCHG_BIN" --help
  assert_success
  assert_output --partial 'Usage:'
  assert_output --partial 'openexchangerates.org'
}

@test "invalid option exits 22" {
  run "$OPENXCHG_BIN" -Z
  assert_failure 22
  assert_output --partial 'Invalid option'
}

@test "invalid currency code exits 22" {
  run "$OPENXCHG_BIN" idr 'US'
  assert_failure 22
  assert_output --partial 'Invalid currency code'
}

@test "unsupported currency exits 22" {
  run "$OPENXCHG_BIN" idr xxx
  assert_failure 22
  assert_output --partial 'not supported'
}

@test "invalid date exits 22" {
  run "$OPENXCHG_BIN" -d 2025-13-45 idr
  assert_failure 22
  assert_output --partial 'Invalid date'
}

@test "latest and date are mutually exclusive" {
  run "$OPENXCHG_BIN" -l -d 2025-01-01 idr
  assert_failure 22
  assert_output --partial 'mutually exclusive'
}

@test "option requiring argument exits 22 when missing" {
  run "$OPENXCHG_BIN" -d
  assert_failure 22
  assert_output --partial 'requires an argument'
}

@test "SQL injection attempt is rejected" {
  run "$OPENXCHG_BIN" idr "USD'; DROP TABLE IDR;--"
  assert_failure 22
}

# --- UPDATE mode ---

@test "update creates database and stores rates" {
  run "$OPENXCHG_BIN" idr
  assert_success
  assert_output --partial 'Update complete'
  [[ -f $DB_PATH ]]
  run sqlite3 "$DB_PATH" "SELECT Xchg FROM IDR WHERE Currency='USD'"
  assert_output '16500.5'
}

@test "update stores base currency at rate 1" {
  "$OPENXCHG_BIN" -q idr
  run sqlite3 "$DB_PATH" "SELECT Xchg FROM IDR WHERE Currency='IDR'"
  assert_output '1.0'
}

@test "update with no arguments defaults to IDR base" {
  run "$OPENXCHG_BIN" -q
  assert_success
  run sqlite3 "$DB_PATH" "SELECT count(*) FROM IDR"
  refute_output '0'
}

@test "quiet update produces no output" {
  run "$OPENXCHG_BIN" -q usd
  assert_success
  assert_output ''
}

@test "update is idempotent for same date" {
  "$OPENXCHG_BIN" -q idr
  "$OPENXCHG_BIN" -q idr
  run sqlite3 "$DB_PATH" \
    "SELECT count(*) FROM IDR WHERE Currency='USD'"
  assert_output '1'
}

@test "update reports API error from response body" {
  MOCK_API_ERROR=1 run "$OPENXCHG_BIN" idr
  assert_failure 1
  assert_output --partial 'API error: Invalid App ID provided.'
}

# --- QUERY mode ---

@test "query returns stored rates" {
  "$OPENXCHG_BIN" -q idr
  run "$OPENXCHG_BIN" idr usd eur
  assert_success
  assert_output --partial 'USD'
  assert_output --partial '16500.5'
}

@test "query resolves currency aliases" {
  "$OPENXCHG_BIN" -q idr
  run "$OPENXCHG_BIN" idr rupiah yen
  assert_success
  assert_output --partial 'IDR'
  assert_output --partial 'JPY'
}

@test "query without database exits 3" {
  run "$OPENXCHG_BIN" idr usd
  assert_failure 3
  assert_output --partial 'Database not found'
}

@test "query on missing base table exits 3" {
  "$OPENXCHG_BIN" -q idr
  run "$OPENXCHG_BIN" eur usd
  assert_failure 3
  assert_output --partial 'table in database'
}

@test "explicit date round-trips between update and query" {
  "$OPENXCHG_BIN" -q -d 2025-01-01 idr
  run "$OPENXCHG_BIN" -d 2025-01-01 idr usd
  assert_success
  assert_output --partial '2025-01-01'
}

@test "double-dash ends option parsing" {
  "$OPENXCHG_BIN" -q idr
  run "$OPENXCHG_BIN" -- idr usd
  assert_success
  assert_output --partial 'USD'
}

# --- LATEST mode ---

@test "latest displays requested currencies" {
  run "$OPENXCHG_BIN" -l idr usd eur
  assert_success
  assert_output --partial 'Latest real-time rates'
  assert_output --partial '16512.25'
}

@test "latest warns on requested currency missing from response" {
  run "$OPENXCHG_BIN" -l idr aud
  assert_success
  assert_output --partial 'AUD not in API response'
}

@test "latest does not touch the database" {
  run "$OPENXCHG_BIN" -l idr usd
  assert_success
  [[ ! -f $DB_PATH ]]
}

# --- option ergonomics ---

@test "bundled short options work" {
  run "$OPENXCHG_BIN" -qd 2025-01-01 idr
  assert_success
  assert_output ''
  run sqlite3 "$DB_PATH" "SELECT Date FROM IDR WHERE Currency='USD'"
  assert_output '2025-01-01'
}

@test "options can appear after positional arguments" {
  "$OPENXCHG_BIN" -q idr
  run "$OPENXCHG_BIN" idr usd -q
  assert_success
}
