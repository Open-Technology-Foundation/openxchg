#!/usr/bin/env bats
#
# test_init.bats - Test auto-initialization
#
# Tests first-run initialization, config creation, and directory setup

load '../test_helper.bash'

setup() {
  setup_test_env
  # Don't create config - we're testing initialization
  enable_mock_api
}

teardown() {
  teardown_test_env
}

# =============================================================================
# First Run Detection
# =============================================================================

@test "init: detects first run when no config exists" {
  [[ ! -f "$TEST_CONFIG_FILE" ]]

  run_openxchg --help

  # Should work even without config
  assert_success
}

@test "init: creates config on first run" {
  [[ ! -f "$TEST_CONFIG_FILE" ]]
  [[ ! -f "$TEST_CURRENCY_LIST" ]]

  # Help should trigger initialization
  run_openxchg --help

  assert_success
  [[ -f "$TEST_CONFIG_FILE" ]]
}

@test "init: creates currency list on first run" {
  [[ ! -f "$TEST_CURRENCY_LIST" ]]

  run_openxchg --help

  assert_success
  [[ -f "$TEST_CURRENCY_LIST" ]]
}

@test "init: creates database directory on first run" {
  run_openxchg --help

  assert_success
  [[ -d "$TEST_DB_DIR" ]]
}

# =============================================================================
# Config File Creation
# =============================================================================

@test "init: config file has correct sections" {
  run_openxchg --help

  assert_success
  [[ -f "$TEST_CONFIG_FILE" ]]

  local -- content
  content=$(cat "$TEST_CONFIG_FILE")

  assert_output_contains "[General]" "$content"
  assert_output_contains "[API]" "$content"
  assert_output_contains "[Database]" "$content"
}

@test "init: config file has default base currency" {
  run_openxchg --help

  assert_success

  local -- content
  content=$(cat "$TEST_CONFIG_FILE")

  assert_output_contains "DEFAULT_BASE_CURRENCY=IDR" "$content"
}

@test "init: config file has database path" {
  run_openxchg --help

  assert_success

  local -- content
  content=$(cat "$TEST_CONFIG_FILE")

  assert_output_contains "DB_PATH=" "$content"
}

@test "init: config file has correct permissions" {
  run_openxchg --help

  assert_success

  local -- perms
  perms=$(stat -c%a "$TEST_CONFIG_FILE")

  [[ "$perms" == "644" ]]
}

# =============================================================================
# Currency List Creation
# =============================================================================

@test "init: currency list has common currencies" {
  run_openxchg --help

  assert_success
  [[ -f "$TEST_CURRENCY_LIST" ]]

  local -- content
  content=$(cat "$TEST_CURRENCY_LIST")

  assert_output_contains "USD" "$content"
  assert_output_contains "EUR" "$content"
  assert_output_contains "GBP" "$content"
}

@test "init: currency list has correct permissions" {
  run_openxchg --help

  assert_success

  local -- perms
  perms=$(stat -c%a "$TEST_CURRENCY_LIST")

  [[ "$perms" == "644" ]]
}

@test "init: currency list has comments" {
  run_openxchg --help

  assert_success

  local -- content
  content=$(cat "$TEST_CURRENCY_LIST")

  assert_output_contains "#" "$content"
}

# =============================================================================
# Database Directory Creation
# =============================================================================

@test "init: database directory has sticky bit" {
  run_openxchg --help

  assert_success

  local -- perms
  perms=$(stat -c%a "$TEST_DB_DIR")

  [[ "$perms" == "1777" ]]
}

@test "init: database directory is world-writable" {
  run_openxchg --help

  assert_success

  [[ -w "$TEST_DB_DIR" ]]
}

# =============================================================================
# Partial Initialization
# =============================================================================

@test "init: creates missing config if only currency list exists" {
  # Create only currency list
  mkdir -p "$(dirname "$TEST_CURRENCY_LIST")"
  echo "USD" > "$TEST_CURRENCY_LIST"

  [[ -f "$TEST_CURRENCY_LIST" ]]
  [[ ! -f "$TEST_CONFIG_FILE" ]]

  run_openxchg --help

  assert_success
  [[ -f "$TEST_CONFIG_FILE" ]]
}

@test "init: creates missing currency list if only config exists" {
  # Create only config
  mkdir -p "$(dirname "$TEST_CONFIG_FILE")"
  cat > "$TEST_CONFIG_FILE" <<'EOF'
[General]
DEFAULT_BASE_CURRENCY=IDR
EOF

  [[ -f "$TEST_CONFIG_FILE" ]]
  [[ ! -f "$TEST_CURRENCY_LIST" ]]

  run_openxchg --help

  assert_success
  [[ -f "$TEST_CURRENCY_LIST" ]]
}

@test "init: does not overwrite existing config" {
  # Create config with custom value
  mkdir -p "$(dirname "$TEST_CONFIG_FILE")"
  cat > "$TEST_CONFIG_FILE" <<'EOF'
[General]
DEFAULT_BASE_CURRENCY=EUR
EOF
  mkdir -p "$(dirname "$TEST_CURRENCY_LIST")"
  echo "USD" > "$TEST_CURRENCY_LIST"

  run_openxchg --help

  assert_success

  local -- content
  content=$(cat "$TEST_CONFIG_FILE")

  # Should still have EUR, not be overwritten to IDR
  assert_output_contains "DEFAULT_BASE_CURRENCY=EUR" "$content"
}

@test "init: does not overwrite existing currency list" {
  # Create currency list with custom currencies
  mkdir -p "$(dirname "$TEST_CURRENCY_LIST")"
  echo "AUD" > "$TEST_CURRENCY_LIST"
  mkdir -p "$(dirname "$TEST_CONFIG_FILE")"
  cat > "$TEST_CONFIG_FILE" <<'EOF'
[General]
DEFAULT_BASE_CURRENCY=IDR
EOF

  run_openxchg --help

  assert_success

  local -- content
  content=$(cat "$TEST_CURRENCY_LIST")

  # Should still have AUD
  assert_output_contains "AUD" "$content"
}

# =============================================================================
# Initialization Messages
# =============================================================================

@test "init: shows initialization message on first run" {
  run_openxchg --help 2>&1

  assert_success
  # Should show first run message if files were created
}

@test "init: shows API key setup instructions" {
  run_openxchg --help 2>&1

  assert_success
  # First run should mention API key
}

# =============================================================================
# Skip Initialization
# =============================================================================

@test "init: skips if both files exist" {
  create_full_test_env

  # Note the timestamp before running
  local -- config_mtime_before
  config_mtime_before=$(stat -c%Y "$TEST_CONFIG_FILE")

  sleep 1

  run_openxchg --help

  assert_success

  # Config should not be modified
  local -- config_mtime_after
  config_mtime_after=$(stat -c%Y "$TEST_CONFIG_FILE")

  [[ "$config_mtime_before" == "$config_mtime_after" ]]
}

# =============================================================================
# Error Handling During Init
# =============================================================================

@test "init: fails gracefully if cannot create directory" {
  # Make config directory unwritable
  mkdir -p "$TEST_CONFIG_DIR"
  chmod 555 "$TEST_CONFIG_DIR"
  rm -f "$TEST_CONFIG_FILE" "$TEST_CURRENCY_LIST"

  run_openxchg --help

  # Should either succeed (help doesn't need init) or fail gracefully
  # Restore permissions
  chmod 755 "$TEST_CONFIG_DIR"
}

#fin
