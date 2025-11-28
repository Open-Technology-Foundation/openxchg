#!/usr/bin/env bats
#
# test_cli_options.bats - Test command-line argument parsing
#
# Tests CLI options, argument order, and help/version output

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
# Help and Version
# =============================================================================

@test "cli: --help displays usage information" {
  run_openxchg --help

  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "openxchg"
  assert_output --partial "OPTIONS"
}

@test "cli: -h displays usage information" {
  run_openxchg -h

  assert_success
  assert_output --partial "Usage:"
}

@test "cli: --version displays version" {
  run_openxchg --version

  assert_success
  assert_output --partial "openxchg"
  assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

@test "cli: -V displays version" {
  run_openxchg -V

  assert_success
  assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

# =============================================================================
# Verbose/Quiet Options
# =============================================================================

@test "cli: --verbose enables verbose output" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg --verbose idr usd

  assert_success
  assert_output --partial "Currency"
}

@test "cli: -v enables verbose output" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg -v idr usd

  assert_success
  assert_output --partial "Currency"
}

@test "cli: --quiet suppresses verbose output" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg --quiet idr usd

  assert_success
  # Should not have header line in quiet mode
  refute_output --partial "Currency    Xchg"
}

@test "cli: -q suppresses verbose output" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg -q idr usd

  assert_success
  refute_output --partial "Currency    Xchg"
}

# =============================================================================
# Date Option
# =============================================================================

@test "cli: --date accepts YYYY-MM-DD format" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg --date 2025-01-01 idr usd

  assert_success
}

@test "cli: -d accepts YYYY-MM-DD format" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg -d 2025-01-01 idr usd

  assert_success
}

@test "cli: --date accepts 'yesterday'" {
  run_openxchg --date yesterday idr

  assert_success
}

@test "cli: --date accepts 'today'" {
  run_openxchg --date today idr

  assert_success
}

@test "cli: --date rejects invalid date format" {
  run_openxchg --date 01-01-2025 idr

  assert_failure
  assert_output --partial "Invalid date"
}

@test "cli: --date rejects nonsense date" {
  run_openxchg --date foobar idr

  assert_failure
  assert_output --partial "Invalid date"
}

# =============================================================================
# API Key Option
# =============================================================================

@test "cli: --apikey sets API key" {
  run_openxchg --apikey test123 -l idr usd

  assert_success
}

@test "cli: -a sets API key" {
  run_openxchg -a test123 -l idr usd

  assert_success
}

# =============================================================================
# GNU-Style Argument Order
# =============================================================================

@test "cli: options can appear before arguments" {
  run_openxchg -l -q idr usd

  assert_success
}

@test "cli: options can appear after arguments" {
  run_openxchg idr usd -l -q

  assert_success
}

@test "cli: options can appear mixed with arguments" {
  run_openxchg idr -l usd -q

  assert_success
}

@test "cli: date option can appear anywhere" {
  run_openxchg idr -d yesterday usd -l

  assert_success
}

# =============================================================================
# Currency Code Handling
# =============================================================================

@test "cli: currency codes are case-insensitive" {
  run_openxchg -l idr USD Eur gbp

  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"
  assert_output --partial "GBP"
}

@test "cli: lowercase base currency is accepted" {
  run_openxchg -l idr usd

  assert_success
}

@test "cli: mixed case currencies are normalized" {
  run_openxchg -l IdR UsD

  assert_success
  assert_output --partial "USD"
}

# =============================================================================
# Multiple Target Currencies
# =============================================================================

@test "cli: accepts multiple target currencies" {
  run_openxchg -l idr usd eur gbp jpy

  assert_success
  assert_output --partial "USD"
  assert_output --partial "EUR"
  assert_output --partial "GBP"
  assert_output --partial "JPY"
}

@test "cli: single target currency works" {
  run_openxchg -l idr usd

  assert_success
  assert_output --partial "USD"
}

# =============================================================================
# Show Config Option
# =============================================================================

@test "cli: --show-config displays configuration" {
  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY"
  assert_output --partial "DB_PATH"
}

# =============================================================================
# Check Config Option
# =============================================================================

@test "cli: --check-config validates configuration" {
  run_openxchg --check-config

  assert_success
  assert_output --partial "passed"
}

# =============================================================================
# Database Options
# =============================================================================

@test "cli: --db-info displays database information" {
  create_test_database "$TEST_DB_PATH" 2
  run_openxchg --db-info

  assert_success
  assert_output --partial "Database"
}

@test "cli: --db-vacuum optimizes database" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg --db-vacuum

  assert_success
  assert_output --partial "VACUUM"
}

@test "cli: --db-check verifies database integrity" {
  create_test_database "$TEST_DB_PATH" 1
  run_openxchg --db-check

  assert_success
  assert_output --partial "ok"
}

# =============================================================================
# Latest Mode Option
# =============================================================================

@test "cli: --latest fetches current rates" {
  run_openxchg --latest idr usd

  assert_success
  assert_output --partial "USD"
}

@test "cli: -l fetches current rates" {
  run_openxchg -l idr usd

  assert_success
  assert_output --partial "USD"
}

# =============================================================================
# Update Currencies Option
# =============================================================================

@test "cli: -U updates currency list" {
  run_openxchg -U

  assert_success
}

@test "cli: --update-currencies updates currency list" {
  run_openxchg --update-currencies

  assert_success
}

# =============================================================================
# All Currencies Option
# =============================================================================

@test "cli: --all forces all currencies in update mode" {
  run_openxchg --all -l idr usd

  assert_success
}

#fin
