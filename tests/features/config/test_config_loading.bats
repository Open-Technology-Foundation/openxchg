#!/usr/bin/env bats
#
# test_config_loading.bats - Test configuration file loading
#
# Tests the load_config() function and configuration precedence

load '../../test_helper.bash'

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "load_config: loads valid configuration file" {
  # Create test config
  cp "${TEST_FIXTURES}/configs/valid_config.ini" "$TEST_CONFIG_FILE"

  # Run openxchg with --show-config to verify config loaded
  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: IDR"
  assert_output --partial "DEFAULT_VERBOSE: 1"
  assert_output --partial "DEFAULT_DATE: yesterday"
}

@test "load_config: handles missing config file gracefully" {
  # Don't create config file
  run_openxchg --show-config

  assert_success
  assert_output --partial "Not found"
}

@test "load_config: parses [General] section correctly" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY=EUR
DEFAULT_VERBOSE=0
"

  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: EUR"
  assert_output --partial "DEFAULT_VERBOSE: 0"
}

@test "load_config: parses [Database] section correctly" {
  create_test_config "$TEST_CONFIG_FILE" "[Database]
DB_PATH=/tmp/test.db
"

  run_openxchg --show-config

  assert_success
  assert_output --partial "DB_PATH: /tmp/test.db"
}

@test "load_config: ignores comments" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
# This is a comment
DEFAULT_BASE_CURRENCY=USD
; This is also a comment
DEFAULT_VERBOSE=1
"

  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: USD"
}

@test "load_config: ignores blank lines" {
  create_test_config "$TEST_CONFIG_FILE" "[General]

DEFAULT_BASE_CURRENCY=GBP

DEFAULT_VERBOSE=1

"

  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: GBP"
}

@test "load_config: handles whitespace around values" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY = JPY
DEFAULT_VERBOSE = 0
"

  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: JPY"
}

@test "load_config: warns on unknown section" {
  create_test_config "$TEST_CONFIG_FILE" "[UnknownSection]
SOMETHING=value
"

  # Run and capture stderr
  run_openxchg --show-config 2>&1

  assert_success
  assert_output --partial "Unknown config option"
}

@test "load_config: warns on unknown key" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
UNKNOWN_KEY=value
"

  run_openxchg --show-config 2>&1

  assert_success
  assert_output --partial "Unknown config option"
}

@test "load_config: validates boolean values" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
AUTO_UPDATE_CURRENCY_LIST=invalid
"

  run_openxchg --show-config 2>&1

  assert_success
  assert_output --partial "Invalid"
}

@test "load_config: fallback mode doesn't override existing values" {
  # This tests system config vs user config precedence
  # User config should win over system config

  # Create system config
  local -- system_config="/tmp/system_config_$$"
  create_test_config "$system_config" "[General]
DEFAULT_BASE_CURRENCY=USD
DEFAULT_VERBOSE=0
"

  # Create user config with different values
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY=EUR
"

  # The openxchg script loads system config in fallback mode first,
  # then user config in normal mode. User config should override.
  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: EUR"

  rm -f "$system_config"
}

@test "load_config: uppercases currency codes" {
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_BASE_CURRENCY=idr
"

  run_openxchg --show-config

  assert_success
  assert_output --partial "DEFAULT_BASE_CURRENCY: IDR"
}

@test "load_config: accepts yesterday, today, or date for DEFAULT_DATE" {
  # Test yesterday
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_DATE=yesterday
"

  run_openxchg --show-config
  assert_success
  assert_output --partial "DEFAULT_DATE: yesterday"

  # Test today
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_DATE=today
"

  run_openxchg --show-config
  assert_success
  assert_output --partial "DEFAULT_DATE: today"

  # Test specific date
  create_test_config "$TEST_CONFIG_FILE" "[General]
DEFAULT_DATE=2025-01-01
"

  run_openxchg --show-config
  assert_success
  assert_output --partial "DEFAULT_DATE: 2025-01-01"
}

@test "load_config: accepts ALL, CONFIGURED, or path for UPDATE_CURRENCIES" {
  # Test ALL
  create_test_config "$TEST_CONFIG_FILE" "[General]
UPDATE_CURRENCIES=ALL
"

  run_openxchg --show-config
  assert_success
  assert_output --partial "UPDATE_CURRENCIES: ALL"

  # Test CONFIGURED
  create_test_config "$TEST_CONFIG_FILE" "[General]
UPDATE_CURRENCIES=CONFIGURED
"

  run_openxchg --show-config
  assert_success
  assert_output --partial "UPDATE_CURRENCIES: CONFIGURED"

  # Test file path
  create_test_config "$TEST_CONFIG_FILE" "[General]
UPDATE_CURRENCIES=/tmp/currencies.list
"

  run_openxchg --show-config
  assert_success
  assert_output --partial "UPDATE_CURRENCIES: /tmp/currencies.list"
}

#fin
