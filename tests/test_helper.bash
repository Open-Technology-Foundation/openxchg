#
# test_helper.bash - Common test utilities and assertions for BATS tests
#
# This file is loaded by all test files and provides:
# - Common setup and teardown functions
# - Custom assertions
# - Test environment configuration
# - Mock helpers
#

# Load BATS helper libraries
load '/usr/local/lib/bats-support/load.bash' 2>/dev/null || true
load '/usr/local/lib/bats-assert/load.bash' 2>/dev/null || true
load '/usr/local/lib/bats-file/load.bash' 2>/dev/null || true

# Test configuration
export BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# Find repository root by looking for the openxchg script
export OPENXCHG_ROOT="$(cd "${BATS_TEST_DIRNAME}" && while [[ ! -f "openxchg" ]] && [[ "$PWD" != "/" ]]; do cd ..; done && pwd)"
export OPENXCHG_BIN="${OPENXCHG_ROOT}/openxchg"
export TEST_FIXTURES="${OPENXCHG_ROOT}/tests/fixtures"
export TEST_MOCKS="${OPENXCHG_ROOT}/tests/mocks"

# Test environment variables
export TEST_TEMP_DIR=""
export TEST_DB_PATH=""
export TEST_DB_DIR=""
export TEST_CONFIG_DIR=""
export TEST_CONFIG_FILE=""
export TEST_CURRENCY_LIST=""
export MOCK_API_ENABLED="false"

# Save original paths
declare -g ORIG_PATH="${PATH}"
declare -g ORIG_HOME="${HOME:-}"

#
# setup_test_env - Create isolated test environment
#
# Creates temporary directories, test database, and config files for testing.
# The test environment mimics the system-wide configuration structure:
#   - /etc/openxchg/config -> TEST_TEMP_DIR/etc/openxchg/config
#   - /var/lib/openxchg/   -> TEST_TEMP_DIR/var/lib/openxchg/
#
# Call this in setup() function of test files.
#
setup_test_env() {
  # Create temporary directory for this test
  TEST_TEMP_DIR="$(mktemp -d "/tmp/openxchg-test-${BATS_TEST_NUMBER:-0}-XXXXXX")"

  # Create mock system directory structure
  TEST_CONFIG_DIR="${TEST_TEMP_DIR}/etc/openxchg"
  TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/config"
  TEST_CURRENCY_LIST="${TEST_CONFIG_DIR}/update-currencies.list"
  TEST_DB_DIR="${TEST_TEMP_DIR}/var/lib/openxchg"
  TEST_DB_PATH="${TEST_DB_DIR}/xchg.db"

  # Create directories
  mkdir -p "$TEST_CONFIG_DIR"
  mkdir -p "$TEST_DB_DIR"
  chmod 1777 "$TEST_DB_DIR"

  # Create a wrapper script that overrides the paths
  cat > "${TEST_TEMP_DIR}/openxchg-wrapper" <<EOF
#!/bin/bash
# Test wrapper - overrides system paths for isolated testing
export CONFIG_FILE="${TEST_CONFIG_FILE}"
export CONFIG_DIR="${TEST_CONFIG_DIR}"
export DB_PATH="${TEST_DB_PATH}"
export CURRENCIES_FILE="${TEST_DB_DIR}/currencies.json"
# Pass through mock API environment
export MOCK_API_ENABLED="\${MOCK_API_ENABLED:-false}"
export TEST_FIXTURES="${TEST_FIXTURES}"
export TEST_MOCKS="${TEST_MOCKS}"
# Add mock directory to PATH if mock is enabled
if [[ "\$MOCK_API_ENABLED" == "true" ]]; then
  export PATH="${TEST_MOCKS}:\$PATH"
fi
exec "${OPENXCHG_BIN}" "\$@"
EOF
  chmod +x "${TEST_TEMP_DIR}/openxchg-wrapper"

  # Export for direct use
  export TEST_OPENXCHG="${TEST_TEMP_DIR}/openxchg-wrapper"
  export HOME="$TEST_TEMP_DIR"
}

#
# teardown_test_env - Cleanup test environment
#
# Removes all temporary files and directories created during testing.
# Call this in teardown() function of test files.
#
teardown_test_env() {
  if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi

  # Restore original values
  export PATH="${ORIG_PATH}"
  export HOME="${ORIG_HOME}"

  # Unset test-specific variables
  unset TEST_TEMP_DIR TEST_DB_PATH TEST_DB_DIR TEST_CONFIG_DIR TEST_CONFIG_FILE
  unset TEST_CURRENCY_LIST TEST_OPENXCHG
}

#
# enable_mock_api - Enable mock API mode
#
# Redirects wget calls to use mock API responses from fixtures.
# Should be called in setup() before running tests that make API calls.
#
enable_mock_api() {
  export MOCK_API_ENABLED="true"
  export PATH="${TEST_MOCKS}:${PATH}"
}

#
# disable_mock_api - Disable mock API mode
#
# Restores normal wget behavior for integration tests.
#
disable_mock_api() {
  export MOCK_API_ENABLED="false"
  # Remove mock directory from PATH
  export PATH="${PATH//${TEST_MOCKS}:/}"
}

#
# create_test_config - Create a test configuration file
#
# Arguments:
#   $1 - Config file path (defaults to TEST_CONFIG_FILE)
#   $2 - Content (optional, uses default if not provided)
#
create_test_config() {
  local -- config_path="${1:-$TEST_CONFIG_FILE}"
  local -- content="${2:-}"

  if [[ -z "$content" ]]; then
    # Create default test config
    content="[General]
DEFAULT_BASE_CURRENCY=IDR
DEFAULT_VERBOSE=1
DEFAULT_DATE=yesterday
AUTO_UPDATE_CURRENCY_LIST=false
UPDATE_CURRENCIES=${TEST_CURRENCY_LIST}

[API]
API_KEY=test_api_key_123

[Database]
DB_PATH=${TEST_DB_PATH}
"
  fi

  mkdir -p "$(dirname "$config_path")"
  echo "$content" > "$config_path"
  chmod 644 "$config_path"
}

#
# create_test_currency_list - Create a test currency update list
#
# Arguments:
#   $1 - Currency list file path (defaults to TEST_CURRENCY_LIST)
#   $2 - Content (optional, uses default if not provided)
#
create_test_currency_list() {
  local -- list_path="${1:-$TEST_CURRENCY_LIST}"
  local -- content="${2:-}"

  if [[ -z "$content" ]]; then
    # Create default currency list
    content="# Test currency list
USD
EUR
GBP
JPY
CNY
IDR
AUD
SGD
"
  fi

  mkdir -p "$(dirname "$list_path")"
  echo "$content" > "$list_path"
  chmod 644 "$list_path"
}

#
# create_full_test_env - Create config file and currency list together
#
create_full_test_env() {
  create_test_config
  create_test_currency_list
}

#
# create_test_database - Create a test database with sample data
#
# Arguments:
#   $1 - Database path (defaults to TEST_DB_PATH)
#   $2 - Number of tables to create (defaults to 1)
#
create_test_database() {
  local -- db_path="${1:-$TEST_DB_PATH}"
  local -i num_tables="${2:-1}"

  local -a currencies=(IDR USD EUR GBP JPY AUD)

  for ((i=0; i<num_tables && i<${#currencies[@]}; i+=1)); do
    local -- currency="${currencies[i]}"

    sqlite3 "$db_path" <<EOF
CREATE TABLE IF NOT EXISTS $currency (
  id INTEGER PRIMARY KEY,
  Date DATE NOT NULL,
  Currency TEXT NOT NULL DEFAULT 'USD',
  Unit INTEGER NOT NULL DEFAULT 1,
  Xchg REAL NOT NULL DEFAULT 0.0,
  Updated TIMESTAMP NOT NULL,
  UNIQUE(Date, Currency)
);
CREATE INDEX IF NOT EXISTS idx_${currency}_currency ON $currency(Currency);
CREATE INDEX IF NOT EXISTS idx_${currency}_updated ON $currency(Updated);

-- Insert sample data
INSERT OR REPLACE INTO $currency (Date, Currency, Unit, Xchg, Updated)
VALUES
  ('2025-01-01', 'USD', 1, 15000.0, '2025-01-01 12:00:00'),
  ('2025-01-01', 'EUR', 1, 16500.0, '2025-01-01 12:00:00'),
  ('2025-01-01', 'GBP', 1, 19000.0, '2025-01-01 12:00:00');
EOF
  done
}

#
# assert_currency_valid - Assert that a currency code is valid
#
# Arguments:
#   $1 - Currency code to validate
#
assert_currency_valid() {
  local -- currency="${1^^}"

  if [[ ! "$currency" =~ ^[A-Z]{3}$ ]]; then
    fail "Currency code '$currency' is not a valid 3-letter code"
  fi
}

#
# assert_config_loaded - Assert that configuration was loaded correctly
#
# Arguments:
#   $1 - Config variable name (e.g., "DEFAULT_BASE_CURRENCY")
#   $2 - Expected value
#
assert_config_loaded() {
  local -- var_name="$1"
  local -- expected="$2"
  local -- actual

  # Source openxchg to load config
  actual=$(grep "^${var_name}=" "$TEST_CONFIG_FILE" | cut -d= -f2-)

  if [[ "$actual" != "$expected" ]]; then
    fail "Config variable '$var_name' expected '$expected' but got '$actual'"
  fi
}

#
# assert_db_has_table - Assert that database contains a specific table
#
# Arguments:
#   $1 - Database path
#   $2 - Table name
#
assert_db_has_table() {
  local -- db_path="$1"
  local -- table="$2"

  if [[ ! -f "$db_path" ]]; then
    fail "Database file does not exist: $db_path"
  fi

  local -i count
  count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table'" 2>/dev/null || echo 0)

  if ((count == 0)); then
    fail "Table '$table' not found in database"
  fi
}

#
# assert_file_permission - Assert that file has specific permissions
#
# Arguments:
#   $1 - File path
#   $2 - Expected permissions (e.g., "600")
#
assert_file_permission() {
  local -- file="$1"
  local -- expected_perms="$2"

  if [[ ! -f "$file" ]]; then
    fail "File does not exist: $file"
  fi

  local -- actual_perms
  actual_perms=$(stat -c%a "$file")

  if [[ "$actual_perms" != "$expected_perms" ]]; then
    fail "File '$file' has permissions '$actual_perms', expected '$expected_perms'"
  fi
}

#
# assert_output_contains - Assert that output contains a substring
#
# Arguments:
#   $1 - Substring to search for
#   $2 - Output to search in (defaults to $output)
#
assert_output_contains() {
  local -- substring="$1"
  local -- haystack="${2:-${output:-}}"

  if [[ ! "$haystack" =~ $substring ]]; then
    fail "Output does not contain '$substring'\nActual output:\n$haystack"
  fi
}

#
# assert_json_valid - Assert that string is valid JSON
#
# Arguments:
#   $1 - JSON string to validate
#
assert_json_valid() {
  local -- json="$1"

  if ! echo "$json" | jq empty 2>/dev/null; then
    fail "Invalid JSON:\n$json"
  fi
}

#
# run_openxchg - Run openxchg command in test environment
#
# Arguments:
#   $@ - Arguments to pass to openxchg
#
# Sets $status and $output variables like 'run' command
#
run_openxchg() {
  run "$TEST_OPENXCHG" "$@"
}

#
# run_openxchg_raw - Run openxchg directly (without wrapper)
#
# Use this for tests that need to test auto-initialization
#
run_openxchg_raw() {
  run "$OPENXCHG_BIN" "$@"
}

#
# skip_if_no_api_key - Skip test if API key is not available
#
# Use this in integration tests that require real API access.
#
skip_if_no_api_key() {
  if [[ -z "${OPENEXCHANGE_API_KEY:-}" ]]; then
    skip "API key not available (set OPENEXCHANGE_API_KEY environment variable)"
  fi
}

#
# skip_if_no_network - Skip test if network is not available
#
# Use this in integration tests that require network access.
#
skip_if_no_network() {
  if ! ping -c 1 -W 2 openexchangerates.org &>/dev/null; then
    skip "Network not available or openexchangerates.org unreachable"
  fi
}

#fin
