# openxchg

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Open-Technology-Foundation/openxchg)
[![License](https://img.shields.io/badge/license-GPL%20v3.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.2+-orange.svg)](https://www.gnu.org/software/bash/)

Multi-currency exchange rate database manager that fetches historical exchange rates from the OpenExchangeRates.org API and stores them in a SQLite database.

## Quick Start

### One-Liner Install

```bash
curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash
```

### Basic Usage

```bash
# Set your API key (get free key at openexchangerates.org)
export OPENEXCHANGE_API_KEY='your_api_key_here'

# Query exchange rates (IDR to USD, EUR, GBP)
openxchg idr usd eur gbp

# Update database with latest rates
openxchg idr

# Get real-time rates without storing
openxchg --latest idr usd eur
```

## Features

- **173 currencies supported** - Fetches exchange rates from OpenExchangeRates.org API
- **SQLite database** - Stores historical rate data with table-per-base-currency architecture
- **Multiple base currencies** - Supports any currency as base (IDR, USD, EUR, GBP, etc.)
- **Three operational modes**:
  - **UPDATE**: Fetch from API and populate database
  - **QUERY**: Retrieve stored rates from database
  - **LATEST**: Real-time rates (display only, not stored)
- **Flexible configuration** - INI-style config files with precedence system
- **Currency aliases** - Use common names (RUPIAH→IDR, YEN→JPY, DOLLAR→USD, etc.)
- **Selective updates** - Update all currencies or specific lists only
- **Database tools** - Built-in info, vacuum, and integrity check commands
- **GNU-style parsing** - Options can appear anywhere in command line
- **Case-insensitive** - Currency codes normalized automatically
- **Auto-validation** - Built-in data validation and error handling
- **Comprehensive testing** - BATS test suite with ~85% target coverage

## Requirements

- **Bash** 5.2+ (uses advanced features like `inherit_errexit`)
- **sqlite3** 3.45+ (SQLite database engine)
- **wget** (HTTP client for API calls)
- **jq** (JSON processor)
- **bc** (arbitrary precision calculator)
- **OpenExchangeRates.org API key** (free tier available: 1,000 requests/month)

## Installation

### Automated Installation

The quick one-liner installation:

```bash
curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash
```

This will:
1. Check system requirements (Bash 5.2+, sqlite3 3.45+, wget, jq, bc)
2. Install missing dependencies (on Ubuntu/Debian systems)
3. Download `openxchg` to `/usr/local/bin`
4. Create configuration directory and default config file
5. Prompt for your OpenExchangeRates.org API key
6. Test the installation

### Manual Installation

1. **Clone or download the repository:**
   ```bash
   git clone https://github.com/Open-Technology-Foundation/openxchg.git
   cd openxchg
   ```

2. **Install dependencies** (Ubuntu/Debian):
   ```bash
   sudo apt-get update
   sudo apt-get install -y bash sqlite3 wget jq bc
   ```

3. **Make the script executable:**
   ```bash
   chmod +x openxchg
   ```

4. **Optional: Install to system path:**
   ```bash
   sudo cp openxchg /usr/local/bin/
   ```

5. **Set up your API key** (see [Configuration](#configuration))

### Getting an API Key

1. Sign up at [openexchangerates.org](https://openexchangerates.org/signup/free)
2. Free tier provides **1,000 requests/month** with historical data access
3. Copy your App ID from the dashboard
4. Set it via environment variable or config file (see [Configuration](#configuration))

## Configuration

openxchg supports a flexible configuration system with multiple precedence levels:

**Precedence order**: CLI options > User config > Environment variables > System config > Defaults

### Configuration Files

- **System config**: `/etc/openxchg/config`
- **User config**: `~/.config/openxchg/config`
- **Custom config**: Specify with `-C/--config` option

### Initialize Configuration

Create a default configuration file with examples:

```bash
openxchg --init-config
```

This creates `~/.config/openxchg/config` with all available settings and examples.

### Configuration Options

#### General Settings

```ini
[general]
# Default base currency (default: IDR)
DEFAULT_BASE_CURRENCY=IDR

# Verbose output by default (0=quiet, 1=verbose)
DEFAULT_VERBOSE=1

# Default date for queries (yesterday, today, or YYYY-MM-DD)
DEFAULT_DATE=yesterday
```

#### API Settings

```ini
[api]
# OpenExchangeRates.org API key
# WARNING: Storing API key in config file is less secure than using
# environment variable OPENEXCHANGE_API_KEY
API_KEY=your_api_key_here
```

**Recommended**: Use environment variable instead:

```bash
export OPENEXCHANGE_API_KEY='your_api_key_here'
```

Add to `~/.bashrc` or `~/.profile` for persistence.

#### Update Settings

```ini
[update]
# Auto-update currency list from API (true/false)
AUTO_UPDATE_CURRENCY_LIST=true

# Which currencies to update (ALL, CONFIGURED, or path to file)
UPDATE_CURRENCIES=ALL
```

**Selective Update Options**:
- `ALL` - Update all 173 currencies (default)
- `CONFIGURED` - Update only currencies specified in `update-currencies.list`
- `/path/to/file` - Custom currency list (one currency per line)

Example custom currency list (`~/.config/openxchg/update-currencies.list`):
```
# Major currencies only
USD
EUR
GBP
JPY
CNY
AUD
```

#### Database Settings

```ini
[database]
# Custom database path (optional, default: ./xchg.db)
DB_PATH=/custom/path/to/xchg.db
```

### Configuration Management Commands

```bash
# Display effective configuration (showing all sources)
openxchg --show-config

# Validate configuration file
openxchg --check-config

# Use custom config file
openxchg -C /path/to/config idr usd
```

### Security Best Practices

- **File permissions**: Config files should be readable only by owner (`chmod 600`)
- **API key storage**: Prefer environment variable over config file
- **System config**: Use `/etc/openxchg/config` for system-wide defaults only

## Usage

### Basic Syntax

```bash
openxchg [OPTIONS] [base_currency] [CurrencyCode]...
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Display comprehensive help message |
| `-V, --version` | Display version information (1.0.0) |
| `-v, --verbose` | Enable verbose output (default) |
| `-q, --quiet` | Disable verbose output |
| `-d, --date DATE` | Specify date for query/update (default: yesterday) |
| `-a, --apikey KEY` | Use custom API key (overrides env and config) |
| `-l, --latest` | Fetch real-time rates (display only, not stored) |
| `-A, --all` | Update all currencies (overrides config) |
| `-C, --config FILE` | Use alternative config file |
| `--init-config` | Create default config file with examples |
| `--show-config` | Display effective configuration from all sources |
| `--check-config` | Validate configuration file |
| `--db-info` | Display database statistics and information |
| `--db-vacuum` | Optimize and compact database |
| `--db-check` | Verify database integrity |
| `-U, --update-currencies` | Fetch latest currency list from API |

### UPDATE Mode

Fetch all currency rates from the API and populate the database for a specific base currency:

```bash
# Update IDR table with yesterday's rates (all 173 currencies)
openxchg idr

# Update EUR table for a specific date
openxchg -d 2025-01-01 eur

# Update USD table quietly (no progress output)
openxchg -q usd

# Update GBP table with custom API key
openxchg -a YOUR_API_KEY gbp

# Force update all currencies (ignore selective update config)
openxchg --all idr
```

### QUERY Mode

Retrieve stored exchange rates from the database:

```bash
# Query latest rates for USD, EUR, GBP from IDR table
openxchg idr usd eur gbp

# Query AUD rates for USD and SGD
openxchg aud usd sgd

# Query specific date rates
openxchg -d 2025-01-01 eur usd gbp

# Options can appear anywhere (GNU-style)
openxchg eur -d 2025-11-14 usd gbp aud

# Use currency aliases
openxchg idr dollar yen yuan  # USD, JPY, CNY
```

### LATEST Mode (Real-Time)

Fetch current rates from API without storing in database:

```bash
# Get real-time rates
openxchg --latest idr usd eur gbp

# Combine with other options
openxchg -q --latest aud usd sgd
```

> **Note**: LATEST mode displays current rates but does not store them in the database. Use UPDATE mode to save historical data.

### Example Output

```
Currency    Xchg            Date
----------  --------------  ----------
USD         16712           2025-11-14
EUR         19426.865616    2025-11-14
GBP         21989.647286    2025-11-14
```

## Database Structure

The system uses a SQLite database (`xchg.db`) with a **table-per-base-currency architecture**.

### Table Schema

Each currency table (IDR, USD, EUR, etc.) has the following structure:

```sql
CREATE TABLE {CURRENCY} (
  id INTEGER PRIMARY KEY,
  Date DATE NOT NULL,
  Currency TEXT NOT NULL DEFAULT 'USD',
  Unit INTEGER NOT NULL DEFAULT 1,
  Xchg REAL NOT NULL DEFAULT 0.0,
  Updated TIMESTAMP NOT NULL,
  UNIQUE(Date, Currency)
);
CREATE INDEX idx_{CURRENCY}_currency ON {CURRENCY}(Currency);
CREATE INDEX idx_{CURRENCY}_updated ON {CURRENCY}(Updated);
```

**Key Features**:
- `UNIQUE(Date, Currency)` constraint prevents duplicate entries
- Indexes on `Currency` and `Updated` columns for efficient queries
- Automatic table creation for new base currencies
- All timestamps in UTC (matching API convention)

### Exchange Rate Calculation

The OpenExchangeRates API provides all rates relative to USD. The script calculates rates for other base currencies using:

```
exchange_rate = base_currency_rate / target_currency_rate
```

**Example**: To get IDR/EUR rate:
- API provides: USD/IDR = 16712, USD/EUR = 0.86
- Calculation: EUR rate from IDR = 16712 / 0.86 = 19426.865616

### Database Management

```bash
# Display database statistics
openxchg --db-info
# Shows: tables, record counts, date ranges, database size

# Optimize database (reclaim space, defragment, rebuild indexes)
openxchg --db-vacuum

# Verify database integrity
openxchg --db-check
# Runs: integrity check, schema verification, foreign key checks
```

### Direct Database Queries

You can query the database directly using sqlite3:

```bash
# View database schema
sqlite3 xchg.db ".schema"

# List all currency tables
sqlite3 xchg.db "SELECT name FROM sqlite_master WHERE type='table'"

# Query specific currency with formatting
sqlite3 xchg.db -header -column \
  "SELECT * FROM IDR WHERE Currency='USD' ORDER BY Date DESC LIMIT 10"

# Get latest rates for multiple currencies
sqlite3 xchg.db \
  "SELECT Currency, Xchg, Date FROM IDR
   WHERE Currency IN ('USD','EUR','GBP')
   ORDER BY Date DESC, Currency"

# Calculate date range for a table
sqlite3 xchg.db \
  "SELECT MIN(Date) as earliest, MAX(Date) as latest, COUNT(*) as records
   FROM IDR WHERE Currency='USD'"
```

## Advanced Features

### Currency Aliases

openxchg supports common currency name aliases for convenience:

| Alias | Maps To | Full Name |
|-------|---------|-----------|
| DOLLAR, GREENBACK | USD | United States Dollar |
| EURO | EUR | Euro |
| STERLING, POUND | GBP | British Pound Sterling |
| YEN | JPY | Japanese Yen |
| YUAN, RENMINBI, RMB | CNY | Chinese Yuan |
| RUPIAH | IDR | Indonesian Rupiah |
| RUPEE | INR | Indian Rupee |
| FRANC | CHF | Swiss Franc |
| BITCOIN | BTC | Bitcoin |
| GOLD | XAU | Gold (troy ounce) |
| SILVER | XAG | Silver (troy ounce) |

**Usage**:
```bash
openxchg idr dollar yen yuan
# Equivalent to: openxchg idr usd jpy cny

openxchg --latest aud rupiah bitcoin gold
# Equivalent to: openxchg --latest aud idr btc xau
```

### Selective Currency Updates

Control which currencies are updated to reduce API calls and database size:

#### Update All Currencies (Default)

```bash
openxchg idr  # Updates all 173 currencies
```

#### Configure Selective Updates

1. **Create currency list file**:
   ```bash
   cat > ~/.config/openxchg/update-currencies.list <<EOF
   # Major currencies
   USD
   EUR
   GBP
   JPY
   CNY
   AUD
   SGD
   EOF
   ```

2. **Update config file** (`~/.config/openxchg/config`):
   ```ini
   [update]
   UPDATE_CURRENCIES=/home/user/.config/openxchg/update-currencies.list
   ```

3. **Update with selective list**:
   ```bash
   openxchg idr  # Updates only currencies in list
   ```

#### Temporarily Override

```bash
# Force update all currencies (ignore selective config)
openxchg --all idr
```

### Dynamic Currency List Management

openxchg can fetch the current list of supported currencies from the API:

```bash
# Fetch and cache latest currency list
openxchg -U

# Auto-update once per day (configurable)
AUTO_UPDATE_CURRENCY_LIST=true  # in config file
```

**Fallback**: If API is unavailable, uses hardcoded list of 169 currencies.

## Supported Currencies

The system currently supports **173 currencies** (as of API v6):

AED, AFN, ALL, AMD, ANG, AOA, ARS, AUD, AWG, AZN, BAM, BBD, BDT, BGN, BHD, BIF, BMD, BND, BOB, BRL, BSD, BTC, BTN, BWP, BYN, BZD, CAD, CDF, CHF, CLF, CLP, CNH, CNY, COP, CRC, CUC, CUP, CVE, CZK, DJF, DKK, DOP, DZD, EGP, ERN, ETB, EUR, FJD, FKP, GBP, GEL, GGP, GHS, GIP, GMD, GNF, GTQ, GYD, HKD, HNL, HRK, HTG, HUF, IDR, ILS, IMP, INR, IQD, IRR, ISK, JEP, JMD, JOD, JPY, KES, KGS, KHR, KMF, KPW, KRW, KWD, KYD, KZT, LAK, LBP, LKR, LRD, LSL, LYD, MAD, MDL, MGA, MKD, MMK, MNT, MOP, MRU, MUR, MVR, MWK, MXN, MYR, MZN, NAD, NGN, NIO, NOK, NPR, NZD, OMR, PAB, PEN, PGK, PHP, PKR, PLN, PYG, QAR, RON, RSD, RUB, RWF, SAR, SBD, SCR, SDG, SEK, SGD, SHP, SLL, SOS, SRD, SSP, STD, STN, SVC, SYP, SZL, THB, TJS, TMT, TND, TOP, TRY, TTD, TWD, TZS, UAH, UGX, USD, UYU, UZS, VND, VUV, WST, XAF, XAG, XAU, XCD, XDR, XOF, XPD, XPF, XPT, YER, ZAR, ZMW, ZWL

> **Note**: Use `openxchg -U` to fetch the most current list from the API

## Testing

The project includes a comprehensive test suite using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

### Quick Start

```bash
# Install BATS framework and dependencies
./scripts/install_bats.sh

# Run all tests
./scripts/run_tests.sh

# Run specific test suites
./scripts/run_tests.sh --unit         # Unit tests only (fast)
./scripts/run_tests.sh --features     # Feature tests
./scripts/run_tests.sh --integration  # Integration tests (requires API key)
./scripts/run_tests.sh --e2e          # End-to-end tests
```

### Test Organization

- **Unit Tests** (`tests/unit/`) - Fast, isolated tests with mocked dependencies
- **Integration Tests** (`tests/integration/`) - Real API calls and database operations
- **Feature Tests** (`tests/features/`) - Organized by feature area:
  - Config loading and validation
  - Currency aliases
  - Selective updates
  - Database tools
  - Latest mode
- **E2E Tests** (`tests/e2e/`) - Complete user workflows

### Test Coverage

- **Target**: ~85% code coverage
- **Mock API**: Offline testing using fixture data in `tests/fixtures/`
- **CI/CD**: Automated testing via GitHub Actions (`.github/workflows/tests.yml`)
- **Documentation**: See [`tests/README.md`](tests/README.md) for detailed information

### Writing Tests

```bash
#!/usr/bin/env bats

load '../test_helper.bash'

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "currency alias: yuan normalizes to CNY" {
  run_openxchg -q -l IDR yuan
  assert_success
  assert_output --partial "CNY"
}

@test "selective update: uses configured currency list" {
  create_update_list USD EUR GBP
  run_openxchg -q IDR
  assert_success
  assert_db_has_currencies IDR USD EUR GBP
  refute_db_has_currency IDR JPY
}
```

For more information on writing and running tests, see the [Test Suite Documentation](tests/README.md).

## Notes

- **Default date**: Yesterday (API requires historical dates, not current day)
- **Case insensitive**: Currency codes automatically converted to uppercase
- **Duplicate prevention**: UNIQUE constraint on (Date, Currency) prevents duplicate entries
- **Precision**: Exchange rates stored with 6 decimal places
- **Table structure**: Each base currency maintains its own complete table of exchange rates
- **Timezone**: All dates and timestamps use UTC (matching API convention)
- **Rate limits**: Free tier API key provides 1,000 requests/month
- **Historical data**: Available from 1999-01-01 onwards (API dependent)

## Troubleshooting

### API Key Issues

```bash
# Verify API key is set
echo $OPENEXCHANGE_API_KEY

# Check config file
openxchg --show-config | grep API_KEY

# Test with explicit key
openxchg -a YOUR_API_KEY --latest idr usd
```

### Database Issues

```bash
# Check database integrity
openxchg --db-check

# View database info
openxchg --db-info

# Optimize database
openxchg --db-vacuum
```

### Permission Issues

```bash
# Fix config file permissions
chmod 600 ~/.config/openxchg/config

# Fix database permissions
chmod 644 xchg.db
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```bash
# Clone repository
git clone https://github.com/Open-Technology-Foundation/openxchg.git
cd openxchg

# Install dependencies
sudo apt-get install bash sqlite3 wget jq bc

# Install test framework
./scripts/install_bats.sh

# Run tests
./scripts/run_tests.sh
```

### Coding Standards

This project follows the [Bash Coding Standard (BCS)](https://github.com/Open-Technology-Foundation/bash-coding-standard):

- 2-space indentation (strictly enforced)
- Always `set -euo pipefail` at start
- Use `declare` or `local` for all variables
- Prefer `[[` over `[` for conditionals
- Use `((var+=1))` instead of `((var++))`
- End scripts with `#fin` marker
- Comprehensive error handling and exit codes

### Testing Requirements

- All new features must include tests
- Maintain ~85% code coverage target
- Use BATS test framework
- Include both unit and integration tests

## License

GNU General Public License v3.0 - see [LICENSE](LICENSE) for details.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## Authors

**Gary Dean** (Biksu Okusi)

- Website: [garydean.id](https://garydean.id)
- Founder/Chairman: Okusi Group
- Location: Bali, Indonesia

## Acknowledgments

- Exchange rate data provided by [OpenExchangeRates.org](https://openexchangerates.org)
- Testing framework: [BATS](https://github.com/bats-core/bats-core)
- Follows [Bash Coding Standard](https://github.com/Open-Technology-Foundation/bash-coding-standard)

## Links

- **Documentation**: [GitHub Repository](https://github.com/Open-Technology-Foundation/openxchg)
- **Issues**: [Report bugs](https://github.com/Open-Technology-Foundation/openxchg/issues)
- **API Documentation**: [OpenExchangeRates API](https://docs.openexchangerates.org)

---

**Version**: 1.0.0 | **License**: GPL v3.0 | **Status**: Production Ready
