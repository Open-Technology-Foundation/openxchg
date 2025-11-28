#!/usr/bin/env bats
#
# test_workflows.bats - End-to-end workflow tests
#
# Tests complete user workflows from start to finish

load '../test_helper.bash'

setup() {
  setup_test_env
  create_full_test_env
  enable_mock_api
}

teardown() {
  teardown_test_env
}

# =============================================================================
# First-Time User Workflow
# =============================================================================

@test "e2e: new user can check help" {
  run_openxchg --help

  assert_success
  assert_output --partial "Usage"
  assert_output --partial "openxchg"
}

@test "e2e: new user can check version" {
  run_openxchg --version

  assert_success
  assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

@test "e2e: new user can view configuration" {
  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY"
}

@test "e2e: new user can validate configuration" {
  run_openxchg --check-config

  assert_success
  assert_output --partial "passed"
}

# =============================================================================
# Daily Usage Workflow
# =============================================================================

@test "e2e: update database then query" {
  # Step 1: Update database
  run_openxchg idr
  assert_success
  assert_output --partial "Updated"

  # Step 2: Query stored rates
  run_openxchg idr usd eur gbp
  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"
  assert_output --partial "GBP"
}

@test "e2e: multiple updates for different dates" {
  # Update for specific dates
  run_openxchg -d 2025-01-01 idr
  assert_success

  run_openxchg -d 2025-01-02 idr
  assert_success

  # Query each date
  run_openxchg -d 2025-01-01 idr usd
  assert_success
  assert_output --partial "2025-01-01"

  run_openxchg -d 2025-01-02 idr usd
  assert_success
}

@test "e2e: query current rates without storing" {
  # Check latest rates (not stored)
  run_openxchg --latest idr usd eur
  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"

  # Database should not have data from latest query
  # (or may not exist at all)
}

@test "e2e: update multiple base currencies" {
  # Update IDR table
  run_openxchg idr
  assert_success

  # Update USD table
  run_openxchg usd
  assert_success

  # Both tables should exist
  assert_db_has_table "$TEST_DB_PATH" "IDR"
  assert_db_has_table "$TEST_DB_PATH" "USD"
}

# =============================================================================
# Currency Alias Workflow
# =============================================================================

@test "e2e: use aliases in queries" {
  run_openxchg --latest idr dollar yen yuan sterling

  assert_success
  assert_output --partial "USD"
  assert_output --partial "JPY"
  assert_output --partial "CNY"
  assert_output --partial "GBP"
}

@test "e2e: mix aliases and codes" {
  run_openxchg --latest idr USD yen EUR yuan

  assert_success
  assert_output --partial "USD"
  assert_output --partial "JPY"
  assert_output --partial "EUR"
  assert_output --partial "CNY"
}

# =============================================================================
# Database Management Workflow
# =============================================================================

@test "e2e: check database info after updates" {
  # Populate database
  run_openxchg idr
  assert_success

  # Check database info
  run_openxchg --db-info
  assert_success
  assert_output --partial "IDR"
  assert_output --partial "record"
}

@test "e2e: vacuum database after many operations" {
  # Populate database
  run_openxchg idr
  run_openxchg usd

  # Vacuum
  run_openxchg --db-vacuum
  assert_success
  assert_output --partial "VACUUM"
}

@test "e2e: check database integrity" {
  # Populate database
  run_openxchg idr

  # Check integrity
  run_openxchg --db-check
  assert_success
  assert_output --partial "PASSED"
}

# =============================================================================
# Script Integration Workflow
# =============================================================================

@test "e2e: quiet mode for scripting" {
  # Update quietly
  run_openxchg -q idr
  assert_success

  # Query quietly
  run_openxchg -q idr usd
  assert_success

  # Output should be parseable (no headers)
  refute_output --partial "Currency    Xchg"
}

@test "e2e: output can be captured in variable" {
  # Populate database
  run_openxchg idr

  # Capture output
  run_openxchg -q idr usd

  assert_success

  # Output should have currency and value
  local -- output_line="$output"
  [[ "$output_line" =~ USD ]]
}

@test "e2e: multiple currencies in single query for scripting" {
  run_openxchg -l -q idr usd eur gbp jpy cny

  assert_success

  # Should have all currencies on separate lines
  local -i line_count
  line_count=$(echo "$output" | wc -l)

  ((line_count >= 6))
}

# =============================================================================
# Error Recovery Workflow
# =============================================================================

@test "e2e: recover from corrupt database" {
  # Create corrupt database
  echo "corrupt" > "$TEST_DB_PATH"

  # Check should fail
  run_openxchg --db-check
  assert_failure

  # Remove corrupt database
  rm -f "$TEST_DB_PATH"

  # Fresh update should work
  run_openxchg idr
  assert_success

  # Database should be valid now
  run_openxchg --db-check
  assert_success
}

@test "e2e: update missing currency list" {
  rm -f "$TEST_CURRENCY_LIST"

  # Should fail with helpful message
  run_openxchg idr
  assert_failure

  # Recreate currency list
  create_test_currency_list

  # Now should work
  run_openxchg idr
  assert_success
}

# =============================================================================
# Configuration Workflow
# =============================================================================

@test "e2e: custom base currency in config" {
  # Set EUR as default
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY=EUR
DEFAULT_VERBOSE=1
DEFAULT_DATE=yesterday
AUTO_UPDATE_CURRENCY_LIST=false
UPDATE_CURRENCIES=${TEST_CURRENCY_LIST}

[API]
API_KEY=test_api_key

[Database]
DB_PATH=${TEST_DB_PATH}
"
  create_test_currency_list

  # Verify config loaded
  run_openxchg --show-config
  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: EUR"
}

@test "e2e: custom currency list" {
  # Create minimal currency list
  create_test_currency_list "$TEST_CURRENCY_LIST" "USD
EUR
"

  # Update should only process 2 currencies
  run_openxchg -v idr
  assert_success
  assert_output --partial "2"
}

# =============================================================================
# Historical Data Workflow
# =============================================================================

@test "e2e: fetch and query historical data" {
  # Fetch historical data
  run_openxchg -d 2025-01-01 idr
  assert_success

  # Query that specific date
  run_openxchg -d 2025-01-01 idr usd eur
  assert_success
  assert_output --partial "2025-01-01"
  assert_output --partial "USD"
  assert_output --partial "EUR"
}

@test "e2e: compare rates across dates" {
  # Fetch two dates
  run_openxchg -d 2025-01-01 idr
  run_openxchg -d 2025-01-02 idr

  # Query both dates
  run_openxchg -d 2025-01-01 idr usd
  local -- rate1="$output"

  run_openxchg -d 2025-01-02 idr usd
  local -- rate2="$output"

  # Both should have data (may be same due to mock)
  [[ -n "$rate1" ]]
  [[ -n "$rate2" ]]
}

# =============================================================================
# Complete User Journey
# =============================================================================

@test "e2e: complete new user journey" {
  # 1. Check help
  run_openxchg --help
  assert_success

  # 2. View config
  run_openxchg --show-config
  assert_success

  # 3. Validate config
  run_openxchg --check-config
  assert_success

  # 4. Check latest rates (no commitment)
  run_openxchg --latest idr usd eur
  assert_success

  # 5. Populate database
  run_openxchg idr
  assert_success

  # 6. Query stored rates
  run_openxchg idr usd eur gbp
  assert_success

  # 7. Check database info
  run_openxchg --db-info
  assert_success

  # 8. Optimize database
  run_openxchg --db-vacuum
  assert_success

  # 9. Verify integrity
  run_openxchg --db-check
  assert_success
}

#fin
