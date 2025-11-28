# openxchg

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Open-Technology-Foundation/openxchg)
[![License](https://img.shields.io/badge/license-GPL%20v3.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.2+-orange.svg)](https://www.gnu.org/software/bash/)

Multi-currency exchange rate database manager that fetches historical exchange rates from OpenExchangeRates.org and stores them in SQLite. Supports 169 currencies with simple query and update operations.

## Quick Start

```bash
# 1. Install
curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash

# 2. Set your API key (get free key at openexchangerates.org)
export OPENEXCHANGE_API_KEY='your_api_key_here'

# 3. Update database (fetches all 169 currency rates for yesterday)
openxchg idr

# 4. Query rates
openxchg idr usd eur gbp
```

**That's it!** You're ready to use openxchg for currency exchange queries.

## What It Does

openxchg is a command-line tool that:
- Fetches exchange rates for **169 currencies** from the OpenExchangeRates.org API
- Stores historical rate data in a **SQLite database** (table-per-base-currency architecture)
- Provides **two operation modes**: UPDATE (populate database from API) and QUERY (retrieve stored rates)
- Supports any currency as base (IDR, USD, EUR, GBP, etc.) with automatic rate conversion

## Requirements

- **Bash** 5.2+ (uses advanced features like `inherit_errexit`)
- **sqlite3** 3.45+ (SQLite database engine)
- **wget** (HTTP client for API calls)
- **jq** (JSON processor)
- **bc** (arbitrary precision calculator)
- **OpenExchangeRates.org API key** (free tier: 1,000 requests/month)

## Installation

### Automated Installation (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash
```

This will:
1. Check system requirements and install missing dependencies (Ubuntu/Debian)
2. Download `openxchg` to `/usr/local/bin`
3. Create system configuration at `/etc/openxchg/config`
4. Create database directory at `/var/lib/openxchg/` (world-writable with sticky bit)
5. Prompt for your OpenExchangeRates.org API key (recommended: use environment variable)

### Manual Installation

```bash
# 1. Clone repository
git clone https://github.com/Open-Technology-Foundation/openxchg.git
cd openxchg

# 2. Install dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y bash sqlite3 wget jq bc

# 3. Make executable
chmod +x openxchg

# 4. Optional: Install to system path
sudo cp openxchg /usr/local/bin/

# 5. Set API key (see Configuration section below)

```

### Getting an API Key

1. Sign up at [openexchangerates.org](https://openexchangerates.org/signup/free)
2. Free tier provides **1,000 requests/month** with historical data access
3. Copy your App ID from the dashboard
4. Set it via environment variable or config file

## Configuration

### Quick Setup: API Key

The simplest way to configure openxchg is to set an environment variable:

```bash
# Temporary (current session)
export OPENEXCHANGE_API_KEY='your_api_key_here'

# Permanent (add to ~/.bashrc or ~/.profile)
echo "export OPENEXCHANGE_API_KEY='your_api_key_here'" >> ~/.bashrc
```

### System Configuration

openxchg uses a system-wide configuration approach:

**Precedence order**: CLI options > Environment variables > System config > Defaults

**Configuration locations**:
- **System config**: `/etc/openxchg/config` (INI format)
- **Database**: `/var/lib/openxchg/xchg.db` (world-writable with sticky bit)
- **Currency list**: `/etc/openxchg/update-currencies.list`

Configuration is **automatically created** on first run. System administrator can edit `/etc/openxchg/config` to adjust system-wide settings.

### Essential Configuration Options

```ini
[General]
# Default base currency (default: IDR)
DEFAULT_BASE_CURRENCY=IDR

# Verbose output by default (0=quiet, 1=verbose)
DEFAULT_VERBOSE=1

# Default date for queries (yesterday, today, or YYYY-MM-DD)
DEFAULT_DATE=yesterday

# Which currencies to update (ALL, CONFIGURED, or path to file)
UPDATE_CURRENCIES=/etc/openxchg/update-currencies.list

[API]
# RECOMMENDED: Use environment variable instead
#   export OPENEXCHANGE_API_KEY='your_key'
#   Add to ~/.bashrc for persistence
API_KEY=

[Database]
# Database path (default: /var/lib/openxchg/xchg.db)
DB_PATH=/var/lib/openxchg/xchg.db
```

### Configuration Management

```bash
# Display effective configuration
openxchg --show-config

# Validate configuration file
openxchg --check-config
```

## Basic Usage

### Command Syntax

```bash
openxchg [OPTIONS] [base_currency] [target_currencies...]
```

### UPDATE Mode: Populate Database

Fetch all 169 currency rates from the API for a specific base currency and date:

```bash
# Update IDR table with yesterday's rates (default date)
openxchg idr

# Update EUR table for a specific date
openxchg -d 2025-01-01 eur

# Update USD table quietly (no progress messages)
openxchg -q usd
```

**Important**: You must UPDATE a base currency table before you can QUERY it. If you get "no data" errors, run an update first.

### QUERY Mode: Retrieve Stored Rates

Query stored exchange rates from the database:

```bash
# Query IDR table for USD, EUR, GBP rates (latest available)
openxchg idr usd eur gbp

# Query AUD table for USD and SGD rates
openxchg aud usd sgd

# Query specific date
openxchg -d 2025-01-01 eur usd gbp jpy

# Options can appear anywhere (GNU-style)
openxchg eur -d 2025-01-15 usd gbp

# Usage in scripts
read -r currency value date < <(openxchg -q -d 2025-11-10 idr eur)
```

### LATEST Mode: Real-Time Rates

Fetch current rates from API without storing in database:

```bash
# Get real-time rates (not stored)
openxchg --latest idr usd eur gbp

# Quiet mode
openxchg -lq aud usd sgd
```

**Note**: LATEST mode queries the API directly and does not store data. Use UPDATE mode to save historical rates.

### Example Output

```
Currency    Xchg            Date
----------  --------------  ----------
USD         16712           2025-11-14
EUR         19426.865616    2025-11-14
GBP         21989.647286    2025-11-14
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Display help message |
| `-V, --version` | Display version (1.0.0) |
| `-v, --verbose` | Enable verbose output (default) |
| `-q, --quiet` | Disable verbose output |
| `-d, --date DATE` | Specify date (default: yesterday) |
| `-a, --apikey KEY` | Use custom API key |
| `-l, --latest` | Fetch real-time rates (not stored) |
| `--show-config` | Display effective configuration |
| `--check-config` | Validate configuration file |

## Database Structure

The system uses a SQLite database with a **table-per-base-currency architecture**. Each base currency (IDR, USD, EUR, etc.) maintains its own table of exchange rates.

### Table Schema

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

**Key features**:
- `UNIQUE(Date, Currency)` constraint prevents duplicate entries
- Indexes on `Currency` and `Updated` for efficient queries
- Automatic table creation for new base currencies
- All timestamps in UTC (matching API convention)

### Exchange Rate Calculation

The OpenExchangeRates API provides all rates relative to USD. For other base currencies, rates are calculated using:

```
exchange_rate = base_currency_rate / target_currency_rate
```

**Example**: To get IDR/EUR rate:
- API provides: USD/IDR = 16712, USD/EUR = 0.86
- Calculation: EUR from IDR = 16712 / 0.86 = 19426.865616

### Database Location

- **Default (automated install)**: `/var/lib/openxchg/xchg.db`
- **Default (manual install)**: `./xchg.db` (current directory)
- **Custom**: Set `DB_PATH` in configuration file (must be absolute path)

## Troubleshooting

### No Data Returned

**Problem**: Query returns no results

**Solution**: You must UPDATE the base currency table before querying:

```bash
# First update the table
openxchg idr

# Then query
openxchg idr usd eur
```

### API Key Errors

```bash
# Verify API key is set
echo $OPENEXCHANGE_API_KEY

# Check configuration
openxchg --show-config | grep API_KEY

# Test with explicit key
openxchg -a YOUR_API_KEY --latest idr usd
```

### Database Permission Issues

```bash
# Check database file permissions
ls -l /var/lib/openxchg/xchg.db

# Fix permissions if needed
sudo chmod 644 /var/lib/openxchg/xchg.db
sudo chown $USER:$USER /var/lib/openxchg/xchg.db
```

### Configuration File Permissions

```bash
# Fix config file permissions (security best practice)
chmod 600 ~/.config/openxchg/config
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
| AUSSIE | AUD | Australian Dollar |
| KIWI | NZD | New Zealand Dollar |
| LOONIE | CAD | Canadian Dollar |
| SWISSY | CHF | Swiss Franc |
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

By default, UPDATE mode fetches all 169 currencies. You can configure selective updates to reduce API calls and database size.

#### Create Custom Currency List

```bash
# Create list file
cat > ~/.config/openxchg/update-currencies.list <<EOF
# Major currencies only
USD
EUR
GBP
JPY
CNY
AUD
SGD
EOF
```

#### Configure Selective Updates

Edit `~/.config/openxchg/config`:

```ini
[update]
# Use custom currency list
UPDATE_CURRENCIES=/home/user/.config/openxchg/update-currencies.list
```

Or use predefined options:
- `ALL` - Update all 169 currencies (default)
- `CONFIGURED` - Update currencies in `~/.config/openxchg/update-currencies.list`
- `/path/to/file` - Custom currency list file path

#### Override Selective Updates

```bash
# Force update all currencies (ignore config)
openxchg --all idr
```

### Database Management

```bash
# Display database statistics and information
openxchg --db-info

# Optimize and compact database
openxchg --db-vacuum

# Verify database integrity
openxchg --db-check
```

### Direct Database Queries

Query the database directly using sqlite3:

```bash
# View schema
sqlite3 /var/lib/openxchg/xchg.db .schema

# List all currency tables
sqlite3 /var/lib/openxchg/xchg.db "SELECT name FROM sqlite_master WHERE type='table'"

# Query specific currency
sqlite3 /var/lib/openxchg/xchg.db -header -column \
  "SELECT * FROM IDR WHERE Currency='USD' ORDER BY Date DESC LIMIT 10"

# Get latest rates for multiple currencies
sqlite3 /var/lib/openxchg/xchg.db \
  "SELECT Currency, Xchg, Date FROM IDR
   WHERE Currency IN ('USD','EUR','GBP')
   ORDER BY Date DESC, Currency"
```

### Dynamic Currency List Management

Fetch the current list of supported currencies from the API:

```bash
# Fetch and cache latest currency list
openxchg --update-currencies
# or
openxchg -U
```

Enable auto-update in config:

```ini
[update]
AUTO_UPDATE_CURRENCY_LIST=true
```

**Fallback**: If API is unavailable, uses hardcoded list of 169 currencies.

## Supported Currencies

The system supports **169 currencies**:

AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND BOB BRL BSD BTC BTN BWP BYN BZD CAD CDF CHF CLF CLP CNH CNY COP CRC CUC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GGP GHS GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS IMP INR IQD IRR ISK JEP JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLL SOS SRD SSP STD STN SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYU UZS VND VUV WST XAF XAG XAU XCD XDR XOF XPD XPF XPT YER ZAR ZMW ZWL

Use `openxchg -U` to fetch the most current list from the API.

## Testing

The project includes a test suite using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core). See [`tests/README.md`](tests/README.md) for detailed information.

## Notes

- **Default date**: Yesterday (API requires historical dates, not current day)
- **Case insensitive**: Currency codes automatically converted to uppercase
- **Duplicate prevention**: UNIQUE constraint prevents duplicate entries
- **Precision**: Exchange rates stored with 6 decimal places
- **Timezone**: All dates and timestamps use UTC
- **Rate limits**: Free tier API key provides 1,000 requests/month
- **Historical data**: Available from 1999-01-01 onwards (API dependent)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

```bash
# Clone repository
git clone https://github.com/Open-Technology-Foundation/openxchg.git
cd openxchg

# Install dependencies
sudo apt-get install bash sqlite3 wget jq bc

# Run the script
./openxchg --help
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
