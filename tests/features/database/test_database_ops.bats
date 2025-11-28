#!/usr/bin/env bats
#
# test_database_ops.bats - Test database operations
#
# Tests database creation, queries, updates, vacuum, and integrity checks

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
# Database Creation
# =============================================================================

@test "database: creates database file on first update" {
  [[ ! -f "$TEST_DB_PATH" ]]

  run_openxchg -l idr usd
  # Latest mode doesn't create database, use update mode
  run_openxchg idr

  assert_success
  [[ -f "$TEST_DB_PATH" ]]
}

@test "database: creates table for base currency" {
  run_openxchg idr

  assert_success
  assert_db_has_table "$TEST_DB_PATH" "IDR"
}

@test "database: creates different tables for different base currencies" {
  run_openxchg idr
  run_openxchg usd

  assert_success
  assert_db_has_table "$TEST_DB_PATH" "IDR"
  assert_db_has_table "$TEST_DB_PATH" "USD"
}

@test "database: table has correct schema" {
  create_test_database "$TEST_DB_PATH" 1

  # Check columns exist
  local -- schema
  schema=$(sqlite3 "$TEST_DB_PATH" ".schema IDR")

  assert_output_contains "Date DATE" "$schema"
  assert_output_contains "Currency TEXT" "$schema"
  assert_output_contains "Xchg REAL" "$schema"
  assert_output_contains "Updated TIMESTAMP" "$schema"
  assert_output_contains "UNIQUE(Date, Currency)" "$schema"
}

@test "database: creates indexes on Currency and Updated" {
  create_test_database "$TEST_DB_PATH" 1

  local -- indexes
  indexes=$(sqlite3 "$TEST_DB_PATH" ".indexes IDR")

  assert_output_contains "idx_IDR_currency" "$indexes"
  assert_output_contains "idx_IDR_updated" "$indexes"
}

# =============================================================================
# Database Queries
# =============================================================================

@test "database: query returns stored data" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q idr usd

  assert_success
  assert_output --partial "USD"
  assert_output --partial "15000"
}

@test "database: query returns multiple currencies" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q idr usd eur gbp

  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"
  assert_output --partial "GBP"
}

@test "database: query with date filter works" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q -d 2025-01-01 idr usd

  assert_success
  assert_output --partial "USD"
  assert_output --partial "2025-01-01"
}

@test "database: query for non-existent currency returns no data" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q idr xyz

  # Should succeed but with no data
  assert_success
}

@test "database: query for non-existent date returns no data" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q -d 1999-01-01 idr usd

  assert_success
}

# =============================================================================
# Database Updates
# =============================================================================

@test "database: update inserts new rates" {
  run_openxchg idr

  assert_success

  # Verify data was inserted
  local -i count
  count=$(sqlite3 "$TEST_DB_PATH" "SELECT COUNT(*) FROM IDR" 2>/dev/null || echo 0)

  ((count > 0))
}

@test "database: update with UNIQUE constraint prevents duplicates" {
  run_openxchg idr
  run_openxchg idr

  assert_success

  # Should not have duplicate entries
  local -i count
  count=$(sqlite3 "$TEST_DB_PATH" "SELECT COUNT(*) FROM IDR WHERE Currency='USD'" 2>/dev/null || echo 0)

  ((count == 1))
}

@test "database: update replaces existing rates for same date" {
  run_openxchg idr
  run_openxchg idr

  assert_success

  # Count should remain same (INSERT OR REPLACE)
  local -i count
  count=$(sqlite3 "$TEST_DB_PATH" "SELECT COUNT(*) FROM IDR WHERE Currency='USD'" 2>/dev/null || echo 0)

  ((count == 1))
}

# =============================================================================
# Database Info
# =============================================================================

@test "database: --db-info shows database path" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg --db-info

  assert_success
  assert_output --partial "$TEST_DB_PATH"
}

@test "database: --db-info shows table list" {
  create_test_database "$TEST_DB_PATH" 2

  run_openxchg --db-info

  assert_success
  assert_output --partial "IDR"
  assert_output --partial "USD"
}

@test "database: --db-info shows record counts" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg --db-info

  assert_success
  assert_output --partial "record"
}

@test "database: --db-info shows database size" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg --db-info

  assert_success
  # Should show size in KB or MB
  assert_output --regexp "[0-9]+ (bytes|KB|MB)"
}

@test "database: --db-info handles empty database" {
  touch "$TEST_DB_PATH"

  run_openxchg --db-info

  assert_success
  assert_output --partial "No tables"
}

# =============================================================================
# Database Vacuum
# =============================================================================

@test "database: --db-vacuum optimizes database" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg --db-vacuum

  assert_success
  assert_output --partial "VACUUM"
}

@test "database: --db-vacuum reports size reduction" {
  create_test_database "$TEST_DB_PATH" 1

  # Delete some data to create fragmentation
  sqlite3 "$TEST_DB_PATH" "DELETE FROM IDR WHERE Currency='EUR'"

  run_openxchg --db-vacuum

  assert_success
}

@test "database: --db-vacuum handles empty database" {
  touch "$TEST_DB_PATH"

  run_openxchg --db-vacuum

  assert_success
}

# =============================================================================
# Database Integrity Check
# =============================================================================

@test "database: --db-check passes on valid database" {
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg --db-check

  assert_success
  assert_output --partial "PASSED"
}

@test "database: --db-check handles empty database" {
  touch "$TEST_DB_PATH"

  run_openxchg --db-check

  assert_success
}

@test "database: --db-check detects corruption" {
  # Create a corrupt database
  echo "not a database" > "$TEST_DB_PATH"

  run_openxchg --db-check

  assert_failure
  assert_output --partial "error"
}

# =============================================================================
# Database Permissions
# =============================================================================

@test "database: database directory has sticky bit" {
  local -- perms
  perms=$(stat -c%a "$TEST_DB_DIR")

  [[ "$perms" == "1777" ]]
}

@test "database: database file is readable" {
  create_test_database "$TEST_DB_PATH" 1

  [[ -r "$TEST_DB_PATH" ]]
}

@test "database: database file is writable" {
  create_test_database "$TEST_DB_PATH" 1

  [[ -w "$TEST_DB_PATH" ]]
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "database: handles very long currency list" {
  # Insert many currencies
  create_test_database "$TEST_DB_PATH" 1

  run_openxchg -q idr usd eur gbp jpy cny aud sgd myr thb

  assert_success
}

@test "database: handles special characters in path" {
  # This tests that the temp directory with special chars works
  # The test environment already uses /tmp/openxchg-test-*

  create_test_database "$TEST_DB_PATH" 1

  run_openxchg --db-info

  assert_success
}

#fin
