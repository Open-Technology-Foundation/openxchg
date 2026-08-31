# test_helper.bash - shared setup for openxchg BATS tests
#
# Sourced (not executed) by tests/openxchg.bats. Provides an isolated
# environment per test: scratch DB via DB_PATH, and a mock wget on PATH
# that serves generated JSON fixtures instead of hitting the live API.

load '/usr/local/lib/bats-support/load.bash' 2>/dev/null || true
load '/usr/local/lib/bats-assert/load.bash' 2>/dev/null || true

OPENXCHG_ROOT=$(cd "${BATS_TEST_DIRNAME}/.." && pwd)
export OPENXCHG_ROOT
export OPENXCHG_BIN="${OPENXCHG_ROOT}/openxchg"

setup_test_env() {
  TEST_TEMP_DIR=$(mktemp -d)
  export TEST_TEMP_DIR
  export DB_PATH="${TEST_TEMP_DIR}/xchg.db"
  export MOCK_FIXTURES="${TEST_TEMP_DIR}/fixtures"
  export MOCK_API_ENABLED=true
  export MOCK_API_ERROR=0
  # Isolate user config so a real ~/.config/openxchg.conf cannot leak in
  export XDG_CONFIG_HOME="${TEST_TEMP_DIR}/xdg"
  mkdir -p "$MOCK_FIXTURES" "$XDG_CONFIG_HOME"
  write_fixtures
  export PATH="${OPENXCHG_ROOT}/tests/mocks:${PATH}"
}

teardown_test_env() {
  [[ -z ${TEST_TEMP_DIR:-} ]] || rm -rf "$TEST_TEMP_DIR"
}

# Small USD-based rate sets mirroring the live API response shape
write_fixtures() {
  cat > "${MOCK_FIXTURES}/historical.json" <<'JSON'
{
  "timestamp": 1756684799,
  "base": "USD",
  "rates": {
    "USD": 1, "IDR": 16500.5, "EUR": 0.92, "GBP": 0.79,
    "JPY": 148.7, "AUD": 1.52, "SGD": 1.34, "BTC": 0.0000091
  }
}
JSON
  cat > "${MOCK_FIXTURES}/latest.json" <<'JSON'
{
  "timestamp": 1756713600,
  "base": "USD",
  "rates": { "USD": 1, "IDR": 16512.25, "EUR": 0.921, "GBP": 0.791, "JPY": 148.9 }
}
JSON
  cat > "${MOCK_FIXTURES}/error.json" <<'JSON'
{
  "error": true,
  "status": 401,
  "message": "invalid_app_id",
  "description": "Invalid App ID provided."
}
JSON
}
