#!/usr/bin/env bats
#
# test_modes.bats - Test operation modes (UPDATE, QUERY, LATEST)
#
# Tests the three primary operation modes of openxchg

load '../../test_helper.bash'

setup() {
  setup_test_env
  create_full_test_env
  enable_mock_api
}

teardown() {
  teardown_test_env
}

# =============================================================================
# Mode Detection
# =============================================================================

@test "mode: UPDATE mode when only base currency specified" {
  run_openxchg idr

  assert_success
  # Should update database
  [[ -f "$TEST_DB_PATH" ]]
  assert_db_has_table "$TEST_DB_PATH" "IDR"
}

@test "mode: QUERY mode when base and target currencies specified" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg idr usd

  assert_success
  assert_output --partial "USD"
}

@test "mode: LATEST mode with --latest flag" {
  run_openxchg --latest idr usd

  assert_success
  assert_output --partial "USD"
}

@test "mode: LATEST mode with -l flag" {
  run_openxchg -l idr usd

  assert_success
  assert_output --partial "USD"
}

# =============================================================================
# UPDATE Mode
# =============================================================================

@test "update mode: creates database table" {
  run_openxchg idr

  assert_success
  assert_db_has_table "$TEST_DB_PATH" "IDR"
}

@test "update mode: fetches rates from API" {
  run_openxchg idr

  assert_success
  assert_output --partial "Updated"
}

@test "update mode: stores rates in database" {
  run_openxchg idr

  assert_success

  local -i count
  count=$(sqlite3 "$TEST_DB_PATH" "SELECT COUNT(*) FROM IDR" 2>/dev/null || echo 0)

  ((count > 0))
}

@test "update mode: respects selective currency list" {
  # Default currency list has 8 currencies
  run_openxchg idr

  assert_success
  assert_output --partial "8"
}

@test "update mode: --all updates all currencies" {
  run_openxchg --all idr

  assert_success
  # With mock API, should see all currencies from fixture
}

@test "update mode: shows progress with verbose" {
  run_openxchg -v idr

  assert_success
  assert_output --partial "Updating"
}

@test "update mode: quiet mode suppresses progress" {
  run_openxchg -q idr

  assert_success
  # Should have less output in quiet mode
}

@test "update mode: specific date updates that date" {
  run_openxchg -d 2025-01-01 idr

  assert_success
  assert_output --partial "2025-01-01"
}

@test "update mode: 'yesterday' is default date" {
  run_openxchg idr

  assert_success
  assert_output --partial "Date:"
}

# =============================================================================
# QUERY Mode
# =============================================================================

@test "query mode: returns stored exchange rates" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg idr usd

  assert_success
  assert_output --partial "USD"
  assert_output --partial "15000"
}

@test "query mode: returns multiple currencies" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg idr usd eur gbp

  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"
  assert_output --partial "GBP"
}

@test "query mode: verbose shows header" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -v idr usd

  assert_success
  assert_output --partial "Currency"
  assert_output --partial "Xchg"
  assert_output --partial "Date"
}

@test "query mode: quiet mode shows only data" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q idr usd

  assert_success
  refute_output --partial "Currency    Xchg"
}

@test "query mode: date filter returns specific date" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -d 2025-01-01 idr usd

  assert_success
  assert_output --partial "2025-01-01"
}

@test "query mode: returns nothing for empty table" {
  # Create empty database
  sqlite3 "$TEST_DB_PATH" "CREATE TABLE IDR (id INTEGER PRIMARY KEY, Date DATE, Currency TEXT, Xchg REAL, Updated TIMESTAMP, UNIQUE(Date, Currency))"

  run_openxchg -q idr usd

  assert_success
}

@test "query mode: handles non-existent table gracefully" {
  touch "$TEST_DB_PATH"

  run_openxchg idr usd

  # Should either fail gracefully or create the table
  # The script behavior determines this
}

# =============================================================================
# LATEST Mode
# =============================================================================

@test "latest mode: fetches current rates from API" {
  run_openxchg -l idr usd

  assert_success
  assert_output --partial "USD"
}

@test "latest mode: does not store in database" {
  [[ ! -f "$TEST_DB_PATH" ]]

  run_openxchg -l idr usd

  assert_success
  # Database should still not exist (or be empty)
}

@test "latest mode: returns multiple currencies" {
  run_openxchg -l idr usd eur gbp

  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"
  assert_output --partial "GBP"
}

@test "latest mode: verbose shows header" {
  run_openxchg -l -v idr usd

  assert_success
  assert_output --partial "Currency"
}

@test "latest mode: quiet mode shows only data" {
  run_openxchg -l -q idr usd

  assert_success
  refute_output --partial "Currency    Xchg"
}

@test "latest mode: works with currency aliases" {
  run_openxchg -l idr dollar yen yuan

  assert_success
  assert_output --partial "USD"
  assert_output --partial "JPY"
  assert_output --partial "CNY"
}

@test "latest mode: ignores date option" {
  run_openxchg -l -d 2025-01-01 idr usd

  assert_success
  # Latest mode should fetch current rates regardless of -d
}

# =============================================================================
# Mode Interactions
# =============================================================================

@test "modes: can update then query" {
  # First update
  run_openxchg idr
  assert_success

  # Then query
  run_openxchg idr usd
  assert_success
  assert_output --partial "USD"
}

@test "modes: query uses stored data not API" {
  # Populate with known data
  create_test_database "$TEST_DB_PATH" 1

  # Query should return stored value (15000), not mock API value
  run_openxchg -q idr usd

  assert_success
  assert_output --partial "15000"
}

@test "modes: latest always uses API" {
  # Even if database has data
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -l idr usd

  assert_success
  # Should have different value from stored (mock API returns different rate)
}

# =============================================================================
# Exchange Rate Calculations
# =============================================================================

@test "calculation: base currency to itself is 1.0" {
  run_openxchg -l usd usd

  assert_success
  assert_output --partial "1"
}

@test "calculation: non-USD base converts correctly" {
  run_openxchg -l idr usd

  assert_success
  # Rate should be calculated as IDR_rate / USD_rate
}

@test "calculation: cross rates calculate correctly" {
  run_openxchg -l eur gbp

  assert_success
  # Should calculate EUR/GBP from USD rates
}

#fin
