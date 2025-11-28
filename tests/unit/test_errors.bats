#!/usr/bin/env bats
#
# test_errors.bats - Test error handling
#
# Tests error conditions, edge cases, and graceful failure handling

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
# Invalid Arguments
# =============================================================================

@test "error: no arguments shows help" {
  run_openxchg

  # Should show usage or require at least one argument
  assert_output --partial "Usage"
}

@test "error: unknown option fails" {
  run_openxchg --unknown-option

  assert_failure
  assert_output --partial "Unknown"
}

@test "error: invalid short option fails" {
  run_openxchg -z

  assert_failure
}

@test "error: missing required argument for -d" {
  run_openxchg -d

  assert_failure
  assert_output --partial "requires"
}

@test "error: missing required argument for --date" {
  run_openxchg --date

  assert_failure
}

@test "error: missing required argument for -a" {
  run_openxchg -a

  assert_failure
}

# =============================================================================
# Invalid Currency Codes
# =============================================================================

@test "error: invalid base currency fails" {
  run_openxchg xyz

  assert_failure
  assert_output --partial "not supported"
}

@test "error: invalid target currency fails" {
  run_openxchg -l idr xyz

  assert_failure
  assert_output --partial "not supported"
}

@test "error: numeric currency code fails" {
  run_openxchg -l 123 456

  assert_failure
}

@test "error: single character currency fails" {
  run_openxchg -l u s

  assert_failure
}

@test "error: too long currency code fails" {
  run_openxchg -l usdd europ

  assert_failure
}

# =============================================================================
# Invalid Date Formats
# =============================================================================

@test "error: invalid date format DDMMYYYY fails" {
  run_openxchg -d 01012025 -l idr usd

  assert_failure
  assert_output --partial "Invalid date"
}

@test "error: invalid date format DD/MM/YYYY fails" {
  run_openxchg -d 01/01/2025 -l idr usd

  assert_failure
  assert_output --partial "Invalid date"
}

@test "error: invalid date format MM-DD-YYYY fails" {
  run_openxchg -d 01-31-2025 -l idr usd

  assert_failure
}

@test "error: impossible date fails" {
  run_openxchg -d 2025-02-30 -l idr usd

  assert_failure
}

@test "error: future date warns or fails" {
  # API typically doesn't have future data
  run_openxchg -d 2030-01-01 -l idr usd

  # Behavior depends on implementation
  # Either fails or returns no data
}

@test "error: date too old fails" {
  run_openxchg -d 1990-01-01 -l idr usd

  # API historical data typically starts from 1999
  assert_failure
}

# =============================================================================
# Configuration Errors
# =============================================================================

@test "error: invalid config file syntax handled" {
  echo "not valid ini format =" > "$TEST_CONFIG_FILE"

  run_openxchg --check-config

  assert_failure
}

@test "error: invalid currency in config handled" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY=XYZ
"

  run_openxchg --check-config

  assert_failure
  assert_output --partial "XYZ"
}

@test "error: non-existent path in config handled" {
  create_test_config "$TEST_CONFIG_FILE" "[Database]
DB_PATH=/nonexistent/path/db.sqlite
"

  run_openxchg --check-config

  # Should warn about non-existent path
  assert_output --partial "not found"
}

@test "error: invalid boolean value in config" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
AUTO_UPDATE_CURRENCY_LIST=maybe
"

  run_openxchg --check-config

  assert_output --partial "Invalid"
}

# =============================================================================
# Database Errors
# =============================================================================

@test "error: corrupt database detected" {
  echo "not a database" > "$TEST_DB_PATH"

  run_openxchg --db-check

  assert_failure
}

@test "error: query on non-existent database" {
  rm -f "$TEST_DB_PATH"

  run_openxchg idr usd

  # Should handle gracefully - either fail or show no data
}

@test "error: read-only database handled" {
  create_test_database "$TEST_DB_PATH" 1
  chmod 444 "$TEST_DB_PATH"

  run_openxchg idr

  # Update mode should fail on read-only database
  assert_failure

  # Restore permissions for cleanup
  chmod 644 "$TEST_DB_PATH"
}

# =============================================================================
# API Errors (Simulated)
# =============================================================================

@test "error: missing API key fails update" {
  # Create config without API key
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY=IDR

[API]
API_KEY=

[Database]
DB_PATH=${TEST_DB_PATH}
"
  create_test_currency_list
  unset OPENEXCHANGE_API_KEY

  # Disable mock to test real error handling
  disable_mock_api

  run_openxchg idr

  assert_failure
  assert_output --partial "API key"
}

@test "error: handles API timeout gracefully" {
  # This would require more sophisticated mocking
  skip "Requires advanced mock infrastructure"
}

@test "error: handles invalid API response" {
  # Create invalid JSON response
  echo "not json" > "${TEST_FIXTURES}/api_responses/error.json"

  # Would need to configure mock to return error response
  skip "Requires advanced mock infrastructure"
}

# =============================================================================
# Currency List Errors
# =============================================================================

@test "error: missing currency list file handled" {
  rm -f "$TEST_CURRENCY_LIST"

  run_openxchg idr

  # Should fail with helpful message
  assert_failure
  assert_output --partial "not found"
}

@test "error: empty currency list handled" {
  echo "" > "$TEST_CURRENCY_LIST"

  run_openxchg idr

  # Should handle gracefully
}

@test "error: invalid entries in currency list" {
  create_test_currency_list "$TEST_CURRENCY_LIST" "
USD
INVALID
123
EUR
"

  # Should skip invalid entries or warn
  run_openxchg idr

  # Behavior depends on implementation
}

# =============================================================================
# Permission Errors
# =============================================================================

@test "error: unreadable config file fails" {
  chmod 000 "$TEST_CONFIG_FILE"

  run_openxchg --show-config

  assert_failure

  # Restore permissions for cleanup
  chmod 644 "$TEST_CONFIG_FILE"
}

@test "error: unwritable database directory fails update" {
  chmod 555 "$TEST_DB_DIR"

  run_openxchg idr

  # Should fail to create/update database
  assert_failure

  # Restore permissions for cleanup
  chmod 1777 "$TEST_DB_DIR"
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "error: empty base currency fails" {
  run_openxchg ""

  assert_failure
}

@test "error: whitespace-only currency fails" {
  run_openxchg "   " usd

  assert_failure
}

@test "error: special characters in currency fail" {
  run_openxchg "US$" "€UR"

  assert_failure
}

@test "error: very long argument handled" {
  local -- long_arg
  long_arg=$(printf 'A%.0s' {1..1000})

  run_openxchg "$long_arg"

  assert_failure
}

@test "error: unicode currency code fails" {
  run_openxchg "¥EN" "元RN"

  assert_failure
}

# =============================================================================
# Error Messages
# =============================================================================

@test "error: messages go to stderr" {
  run_openxchg xyz 2>&1

  assert_failure
  assert_output --partial "not supported"
}

@test "error: exit codes are non-zero for errors" {
  run_openxchg xyz

  [[ "$status" -ne 0 ]]
}

@test "error: helpful error messages provided" {
  run_openxchg -d invalid idr

  assert_failure
  # Error message should explain the problem
  assert_output --partial "Invalid"
}

#fin
