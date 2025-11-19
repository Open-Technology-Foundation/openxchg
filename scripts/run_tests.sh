#!/bin/bash
#
# run_tests.sh - Test runner for openxchg test suite
#
# Runs BATS tests with various filtering and reporting options.
#
# Usage: ./run_tests.sh [OPTIONS] [TEST_PATH]
#
# Options:
#   --unit          Run only unit tests
#   --integration   Run only integration tests
#   --e2e           Run only end-to-end tests
#   --features      Run only feature tests
#   --all           Run all tests (default)
#   --coverage      Generate coverage report
#   --verbose       Verbose test output
#   --help          Show this help message
#
# Examples:
#   ./run_tests.sh                    # Run all tests
#   ./run_tests.sh --unit             # Run unit tests only
#   ./run_tests.sh --features         # Run feature tests only
#   ./run_tests.sh tests/unit/test_config.bats  # Run specific file

set -euo pipefail

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
declare -r TESTS_DIR="${REPO_ROOT}/tests"

# Test suite selection
declare -i RUN_UNIT=0
declare -i RUN_INTEGRATION=0
declare -i RUN_E2E=0
declare -i RUN_FEATURES=0
declare -i RUN_ALL=1
declare -i GENERATE_COVERAGE=0
declare -i VERBOSE=0

# Test paths
declare -a test_paths=()

#
# usage - Display help message
#
usage() {
  cat <<'EOF'
Test Runner for openxchg

Usage: ./run_tests.sh [OPTIONS] [TEST_PATH]

Options:
  --unit          Run only unit tests
  --integration   Run only integration tests (requires API key)
  --e2e           Run only end-to-end tests
  --features      Run only feature tests
  --all           Run all tests (default)
  --coverage      Generate coverage report
  --verbose       Verbose test output
  --help          Show this help message

Examples:
  ./run_tests.sh                    # Run all tests
  ./run_tests.sh --unit             # Run unit tests only
  ./run_tests.sh --features         # Run feature tests only
  ./run_tests.sh --integration      # Run integration tests
  ./run_tests.sh tests/unit/test_config.bats  # Run specific file

Environment Variables:
  OPENEXCHANGE_API_KEY    API key for integration tests (optional)
  BATS_VERBOSE            Enable verbose output (set to any value)

Exit Codes:
  0    All tests passed
  1    One or more tests failed
  2    Invalid arguments or setup error
EOF
}

#
# check_bats_installed - Verify BATS is installed
#
check_bats_installed() {
  if ! command -v bats &>/dev/null; then
    echo "ERROR: BATS not found" >&2
    echo "Install with: ./scripts/install_bats.sh" >&2
    return 1
  fi

  echo "Using $(bats --version)"
}

#
# parse_arguments - Parse command-line arguments
#
parse_arguments() {
  while (($#)); do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --unit)
        RUN_UNIT=1
        RUN_ALL=0
        ;;
      --integration)
        RUN_INTEGRATION=1
        RUN_ALL=0
        ;;
      --e2e)
        RUN_E2E=1
        RUN_ALL=0
        ;;
      --features)
        RUN_FEATURES=1
        RUN_ALL=0
        ;;
      --all)
        RUN_ALL=1
        ;;
      --coverage)
        GENERATE_COVERAGE=1
        ;;
      --verbose)
        VERBOSE=1
        ;;
      -*)
        echo "ERROR: Unknown option: $1" >&2
        usage
        exit 2
        ;;
      *)
        # Assume it's a test path
        test_paths+=("$1")
        ;;
    esac
    shift
  done
}

#
# build_test_paths - Build array of test paths to run
#
build_test_paths() {
  # If specific paths provided, use those
  if ((${#test_paths[@]} > 0)); then
    return 0
  fi

  # Otherwise, build paths based on options
  if ((RUN_ALL)); then
    test_paths=("${TESTS_DIR}")
  else
    ((RUN_UNIT)) && test_paths+=("${TESTS_DIR}/unit")
    ((RUN_INTEGRATION)) && test_paths+=("${TESTS_DIR}/integration")
    ((RUN_E2E)) && test_paths+=("${TESTS_DIR}/e2e")
    ((RUN_FEATURES)) && test_paths+=("${TESTS_DIR}/features")
  fi

  if ((${#test_paths[@]} == 0)); then
    echo "ERROR: No test paths specified" >&2
    return 1
  fi
}

#
# run_tests - Execute BATS tests
#
run_tests() {
  local -a bats_args=()

  # Add verbose flag if requested
  if ((VERBOSE)) || [[ -n "${BATS_VERBOSE:-}" ]]; then
    bats_args+=(--verbose-run)
  fi

  # Add test paths
  bats_args+=("${test_paths[@]}")

  echo ""
  echo "Running tests..."
  echo "Test paths: ${test_paths[*]}"
  echo ""

  # Run BATS with recursive flag to find all .bats files
  if bats --recursive "${bats_args[@]}"; then
    echo ""
    echo "✓ All tests passed!"
    return 0
  else
    echo ""
    echo "✗ Some tests failed"
    return 1
  fi
}

#
# generate_coverage_report - Generate test coverage report
#
generate_coverage_report() {
  echo ""
  echo "Coverage reporting not yet implemented"
  echo "TODO: Integrate kcov or bashcov for coverage analysis"
  echo ""
}

#
# main - Main execution
#
main() {
  cd "$REPO_ROOT"

  echo "openxchg Test Runner"
  echo "===================="
  echo ""

  # Parse arguments
  parse_arguments "$@"

  # Check BATS installation
  check_bats_installed || exit 2

  # Build test paths
  build_test_paths || exit 2

  # Run tests
  local -i exit_code=0
  run_tests || exit_code=$?

  # Generate coverage if requested
  if ((GENERATE_COVERAGE)); then
    generate_coverage_report
  fi

  exit $exit_code
}

main "$@"

#fin
