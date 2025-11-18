# openxchg Test Suite

Comprehensive test suite for the openxchg currency exchange rate database manager.

## Overview

This test suite uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) to provide comprehensive testing coverage for all openxchg features, including:

- Configuration management
- Currency handling and aliases
- Database operations
- API interactions
- Command-line interface
- Error handling

**Current Status:**
- Framework: BATS with bats-support, bats-assert, bats-file
- Coverage Target: ~85%
- Test Organization: By feature and test type
- Mock Infrastructure: Complete for offline testing
- CI/CD Integration: GitHub Actions workflows

## Quick Start

### Install BATS

```bash
# From repository root
./scripts/install_bats.sh
```

This installs BATS core and helper libraries to `/usr/local`.

### Run All Tests

```bash
# Run complete test suite
./scripts/run_tests.sh

# Or use BATS directly
bats tests/
```

### Run Specific Test Suites

```bash
# Unit tests only (fast, no API required)
./scripts/run_tests.sh --unit

# Feature tests
./scripts/run_tests.sh --features

# Integration tests (requires API key)
export OPENEXCHANGE_API_KEY="your_api_key_here"
./scripts/run_tests.sh --integration

# Specific test file
bats tests/features/config/test_config_loading.bats
```

## Directory Structure

```
tests/
├── README.md                     # This file
├── test_helper.bash              # Common test utilities
├── setup_suite.bash              # Suite-level setup
├── teardown_suite.bash           # Suite-level teardown
├── fixtures/                     # Test data files
│   ├── configs/                  # Sample config files
│   ├── api_responses/            # Mock API responses
│   ├── databases/                # Test database fixtures
│   └── currency_lists/           # Sample update lists
├── mocks/                        # Mock scripts
│   └── wget                      # Mock wget for API calls
├── unit/                         # Unit tests (isolated)
├── integration/                  # Integration tests (real API)
├── e2e/                          # End-to-end tests
└── features/                     # Feature-specific tests
    ├── config/                   # Configuration tests
    ├── database/                 # Database operation tests
    ├── modes/                    # Mode operation tests
    ├── currency/                 # Currency handling tests
    └── cli/                      # CLI parsing tests
```

## Test Types

### Unit Tests (`tests/unit/`)

Fast, isolated tests with all external dependencies mocked.

- **No network required**
- **No API key required**
- Uses mock API responses from `fixtures/api_responses/`
- Tests individual functions in isolation
- Ideal for TDD and rapid development

**Example:**
```bash
bats tests/unit/test_config.bats
```

### Integration Tests (`tests/integration/`)

Tests using real API calls and actual database operations.

- **Requires API key** (`OPENEXCHANGE_API_KEY`)
- **Requires network access**
- Tests full workflows end-to-end
- Slower than unit tests
- Run in CI/CD as nightly scheduled jobs

**Example:**
```bash
export OPENEXCHANGE_API_KEY="your_key"
bats tests/integration/test_api_integration.bats
```

### Feature Tests (`tests/features/`)

Organized by feature area, mix of mocked and real tests.

- Configuration management
- Currency handling
- Database operations
- CLI argument parsing

**Example:**
```bash
bats tests/features/config/
```

### End-to-End Tests (`tests/e2e/`)

Complete user workflows from start to finish.

- First-time setup scenarios
- Daily usage patterns
- Error recovery workflows

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

load '../test_helper.bash'

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "descriptive test name" {
  # Arrange
  create_test_config

  # Act
  run_openxchg --show-config

  # Assert
  assert_success
  assert_output --partial "expected output"
}
```

### Using Mock API

```bash
setup() {
  setup_test_env
  enable_mock_api  # Redirects wget to mock responses
}

@test "fetch currency list" {
  run_openxchg -U
  assert_success
  # Mock API returns fixtures/api_responses/currencies.json
}
```

### Testing with Real API

```bash
@test "real API integration" {
  skip_if_no_api_key
  skip_if_no_network

  disable_mock_api  # Use real wget

  run_openxchg --latest USD EUR
  assert_success
}
```

### Custom Assertions

The test suite provides custom assertions in `test_helper.bash`:

```bash
# Assert currency code is valid 3-letter format
assert_currency_valid "USD"

# Assert database contains a table
assert_db_has_table "$TEST_DB_PATH" "IDR"

# Assert file has specific permissions
assert_file_permission "$TEST_CONFIG_FILE" "600"

# Assert output contains substring
assert_output_contains "expected text"

# Assert JSON is valid
assert_json_valid "$json_string"
```

## Test Fixtures

### Configuration Files

Located in `tests/fixtures/configs/`:

- `valid_config.ini` - Valid configuration
- `invalid_config.ini` - Invalid values for testing validation
- `partial_config.ini` - Incomplete configuration

### API Responses

Located in `tests/fixtures/api_responses/`:

- `currencies.json` - Currency list endpoint response
- `latest.json` - Latest rates endpoint response
- `historical.json` - Historical rates endpoint response

Mock wget automatically serves these based on URL patterns.

### Currency Lists

Located in `tests/fixtures/currency_lists/`:

- `valid_list.txt` - Valid currency update list
- `invalid_list.txt` - List with invalid currencies
- `mixed_list.txt` - Mix of valid and invalid

## Environment Variables

### Test Execution

- `OPENEXCHANGE_API_KEY` - API key for integration tests (optional)
- `BATS_VERBOSE` - Enable verbose output (set to any value)
- `TEST_TEMP_DIR` - Temporary directory for test files (auto-created)

### Test Isolation

Each test runs in an isolated environment with:

- Temporary directory (`/tmp/openxchg-test-*`)
- Test-specific database path
- Test-specific config directory
- Isolated HOME and XDG_CONFIG_HOME

All temporary files are automatically cleaned up after each test.

## CI/CD Integration

### GitHub Actions

Two workflows are provided:

**`.github/workflows/tests.yml`** - Run on push/PR:
- Installs BATS and dependencies
- Runs unit and feature tests (no API key required)
- Generates coverage report
- Fails if coverage < 80%

**`.github/workflows/integration.yml`** - Nightly scheduled:
- Runs integration tests with real API
- Uses secret API key from repository settings
- Notifies on failures

### Running in CI

```yaml
- name: Install BATS
  run: ./scripts/install_bats.sh

- name: Run tests
  run: ./scripts/run_tests.sh --unit --features

- name: Run integration tests
  run: ./scripts/run_tests.sh --integration
  env:
    OPENEXCHANGE_API_KEY: ${{ secrets.OPENEXCHANGE_API_KEY }}
```

## Coverage Reporting

Coverage reporting is planned but not yet implemented.

Future integration options:
- **kcov** - Code coverage for Bash scripts
- **bashcov** - SimpleCov for Bash using kcov

Target coverage: ~85% overall

## Best Practices

### Test Naming

Use descriptive names that explain what is being tested:

```bash
@test "load_config: handles missing config file gracefully" { }
@test "currency alias: yuan normalizes to CNY" { }
@test "database: VACUUM reclaims space after deletes" { }
```

### Test Isolation

Always use `setup_test_env()` and `teardown_test_env()`:

```bash
setup() {
  setup_test_env  # Creates isolated environment
}

teardown() {
  teardown_test_env  # Cleans up temp files
}
```

### Mock vs Real

- **Use mocks** for unit/feature tests (fast, reliable)
- **Use real API** for integration tests (validates actual behavior)
- Mark integration tests with `skip_if_no_api_key` and `skip_if_no_network`

### Error Testing

Test both success and failure paths:

```bash
@test "valid input succeeds" {
  run_openxchg USD EUR
  assert_success
}

@test "invalid currency fails" {
  run_openxchg XYZ
  assert_failure
  assert_output --partial "not supported"
}
```

## Troubleshooting

### BATS Not Found

```bash
./scripts/install_bats.sh
# Or check PATH includes /usr/local/bin
```

### Mock API Not Working

Ensure `enable_mock_api` is called in `setup()`:

```bash
setup() {
  setup_test_env
  enable_mock_api  # Important!
}
```

### Integration Tests Failing

Check API key is set:

```bash
echo $OPENEXCHANGE_API_KEY
# Should output your API key
```

### Permission Errors

Test temp directories require write access to `/tmp`:

```bash
ls -ld /tmp
# Should be drwxrwxrwt
```

## Contributing Tests

When adding new features to openxchg:

1. **Write tests first** (TDD approach)
2. **Add unit tests** for new functions
3. **Add feature tests** for new CLI options
4. **Add integration tests** for API interactions
5. **Update this README** if adding new test categories

### Test File Template

```bash
#!/usr/bin/env bats
#
# test_new_feature.bats - Test description
#

load '../test_helper.bash'

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "feature: basic functionality" {
  # Test implementation
}
```

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [bats-assert](https://github.com/bats-core/bats-assert)
- [bats-support](https://github.com/bats-core/bats-support)
- [bats-file](https://github.com/bats-core/bats-file)
- [Bash Coding Standard](https://github.com/Open-Technology-Foundation/bash-coding-standard)

## Test Statistics

| Metric | Current | Target |
|--------|---------|--------|
| Total Test Files | 2 | 43 |
| Total Tests | 40 | 420 |
| Unit Tests | 0 | 120 |
| Integration Tests | 0 | 40 |
| Feature Tests | 40 | 180 |
| Coverage | TBD | 85% |

---

**Status**: 🚧 Test suite infrastructure complete, actively expanding test coverage.

**Next Steps**:
1. Complete unit test suite
2. Add integration tests
3. Implement coverage reporting
4. Set up CI/CD workflows

For questions or issues, see [openxchg repository](https://github.com/user/openxchg).
