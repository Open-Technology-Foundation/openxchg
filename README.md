# openxchg

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/Open-Technology-Foundation/openxchg)
[![License](https://img.shields.io/badge/license-GPL%20v3.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.2+-orange.svg)](https://www.gnu.org/software/bash/)

Multi-currency exchange rate database manager that fetches historical exchange rates from OpenExchangeRates.org and stores them in SQLite. Supports 168 currencies with simple query, update, and real-time operations. Single ~300-line BCS-compliant Bash script.

## Quick Start

```bash
# 1. Install
curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash

# 2. Set your API key (get free key at openexchangerates.org)
export OPENEXCHANGE_API_KEY='your_api_key_here'

# 3. Update database (fetches all currency rates for yesterday)
openxchg idr

# 4. Query rates
openxchg idr usd eur gbp
```

## What It Does

openxchg is a command-line tool that:
- Fetches exchange rates for **168 currencies** from the OpenExchangeRates.org API
- Stores historical rate data in a **SQLite database** (table-per-base-currency architecture)
- Provides **three modes**: UPDATE (populate database), QUERY (retrieve stored rates), LATEST (display current rates without storing)
- Supports any currency as base (IDR, USD, EUR, GBP, etc.) with automatic cross-rate conversion

## Requirements

- **Bash** 5.2+
- **sqlite3** 3.45+
- **wget**
- **jq**
- **OpenExchangeRates.org API key** (free tier: 1,000 requests/month)

## Installation

### Automated

```bash
curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash
```

Checks dependencies, installs `openxchg` to `/usr/local/bin`, and creates `/var/lib/openxchg/`.

### From a Checkout (Makefile)

```bash
git clone https://github.com/Open-Technology-Foundation/openxchg.git
cd openxchg
sudo apt-get install -y sqlite3 wget jq
sudo make install
```

| Target | Action |
|--------|--------|
| `make install` | Install to `$(PREFIX)/bin` (default `/usr/local`), create `/var/lib/openxchg/` |
| `make uninstall` | Remove the binary (keeps the database directory) |
| `make check` | Verify `openxchg` resolves in PATH |
| `make test` | Run the offline BATS suite |

Supports `PREFIX` and `DESTDIR` for custom prefixes and staged/package builds (`make DESTDIR=/tmp/pkg install`).

### Getting an API Key

1. Sign up at [openexchangerates.org](https://openexchangerates.org/signup/free)
2. Free tier provides **1,000 requests/month** with historical data access
3. Copy your App ID from the dashboard and export it (see below)

## Configuration

Environment variables cover the common cases; an optional config file adds persistence (useful for cron, which has no user environment).

| Variable | Default | Purpose |
|----------|---------|---------|
| `OPENEXCHANGE_API_KEY` | — | API key (or use `-a KEY` per invocation) |
| `DB_PATH` | `/var/lib/openxchg/xchg.db` | SQLite database file |
| `DEFAULT_BASE` | `IDR` | Base currency when none given (config file only) |
| `VERBOSE` | `1` | Default verbosity (config file only) |

```bash
# Permanent API key (add to ~/.bashrc)
echo "export OPENEXCHANGE_API_KEY='your_api_key_here'" >> ~/.bashrc

# Per-user database
DB_PATH=~/xchg.db openxchg idr usd eur
```

### Optional Config File

Plain Bash assignments, sourced from (later overrides earlier):

1. `/etc/openxchg.conf` — system-wide
2. `${XDG_CONFIG_HOME:-~/.config}/openxchg.conf` — per-user

```bash
# /etc/openxchg.conf
DEFAULT_BASE=IDR
OPENEXCHANGE_API_KEY='your_api_key_here'
```

Precedence: CLI options > environment variables > user conf > system conf > built-in defaults.

▲ Config files are **sourced as Bash** — keep them owned by root (system) or the user (personal) and never world-writable. `chmod 600` any file containing an API key.

## Basic Usage

### Command Syntax

```bash
openxchg [OPTIONS] [base_currency] [target_currencies...]
```

### UPDATE Mode: Populate Database

No target currencies given — fetch all rates for the base currency and date:

```bash
openxchg idr                  # IDR table, yesterday's rates (default date)
openxchg -d 2025-01-01 eur    # EUR table, specific date
openxchg -q usd               # quiet (for cron)
```

**Important**: UPDATE a base currency table before you can QUERY it.

### QUERY Mode: Retrieve Stored Rates

```bash
openxchg idr usd eur gbp            # IDR table: latest stored USD, EUR, GBP
openxchg aud usd sgd                # AUD table
openxchg -d 2025-01-01 eur usd gbp  # specific date (most recent at or before)
openxchg eur -d 2025-01-15 usd gbp  # options can appear anywhere (GNU-style)

# In scripts
read -r currency value date < <(openxchg -q idr eur)
```

### LATEST Mode: Real-Time Rates

Fetch current rates from the API without storing them:

```bash
openxchg --latest idr usd eur gbp
openxchg -lq aud usd sgd            # quiet, bundled options
openxchg -l eur                     # all currencies for EUR base
```

### Example Output

```
Currency    Xchg            Date (UTC)
----------  --------------  ----------
USD         16712           2025-11-14
EUR         19426.865616    2025-11-14
GBP         21989.647286    2025-11-14
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-d, --date DATE` | Date for query/update (default: yesterday UTC) |
| `-a, --apikey KEY` | API key (overrides `OPENEXCHANGE_API_KEY`) |
| `-l, --latest` | Fetch real-time rates (display only, not stored) |
| `-q, --quiet` | Suppress informational output |
| `-v, --verbose` | Verbose output (default) |
| `-V, --version` | Display version |
| `-h, --help` | Display help message |

Short options bundle (`-lq`, `-qd DATE`) and may appear anywhere on the command line.

## Database Structure

SQLite database with a **table-per-base-currency architecture**. Each base currency (IDR, USD, EUR, ...) maintains its own table, created automatically on first update.

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

- `UNIQUE(Date, Currency)` prevents duplicates; re-running an update for the same date replaces rows
- All dates and timestamps are UTC (matching API convention)
- Every currency operand is validated (`^[A-Z]{3}$` + supported-list membership) before reaching SQL

### Exchange Rate Calculation

The API provides all rates relative to USD. Cross rates are computed as:

```
exchange_rate = base_currency_rate / target_currency_rate
```

**Example**: IDR base, EUR target — API gives USD/IDR = 16712, USD/EUR = 0.86; stored rate = 16712 / 0.86 = 19432.55...

### Maintenance

Use sqlite3 directly:

```bash
sqlite3 /var/lib/openxchg/xchg.db .schema
sqlite3 /var/lib/openxchg/xchg.db "SELECT name FROM sqlite_master WHERE type='table'"
sqlite3 /var/lib/openxchg/xchg.db "VACUUM"
sqlite3 /var/lib/openxchg/xchg.db "PRAGMA integrity_check"

sqlite3 /var/lib/openxchg/xchg.db -header -column \
  "SELECT * FROM IDR WHERE Currency='USD' ORDER BY Date DESC LIMIT 10"
```

## Currency Aliases

Common names resolve to ISO codes:

| Alias | Maps To |
|-------|---------|
| DOLLAR, GREENBACK | USD |
| STERLING, POUND | GBP |
| YEN | JPY |
| YUAN, RENMINBI, RMB | CNY |
| RUPIAH | IDR |
| FRANC, SWISSY | CHF |
| AUSSIE | AUD |
| KIWI | NZD |
| LOONIE | CAD |

```bash
openxchg idr dollar yen yuan     # same as: openxchg idr usd jpy cny
```

## Troubleshooting

**Query returns nothing / "No table"** — UPDATE the base table first:

```bash
openxchg idr && openxchg idr usd eur
```

**API key errors**:

```bash
echo $OPENEXCHANGE_API_KEY              # verify key is set
openxchg -a YOUR_API_KEY -l idr usd     # test with explicit key
```

**Database permission issues** — `/var/lib/openxchg/` must be writable by the updating user, or point `DB_PATH` at a location you own:

```bash
DB_PATH=~/xchg.db openxchg idr
```

## Supported Currencies

**168 currencies**:

AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND BOB BRL BSD BTC BTN BWP BYN BZD CAD CDF CHF CLF CLP CNH CNY COP CRC CUC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GGP GHS GIP GMD GNF GTQ GYD HKD HNL HRK HTG HUF IDR ILS IMP INR IQD IRR ISK JEP JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLL SOS SRD SSP STD STN SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYU UZS VND VUV WST XAF XAG XAU XCD XDR XOF XPD XPF XPT YER ZAR ZMW ZWL

## Testing

BATS test suite, 33 tests, fully offline (mock `wget` + scratch databases + isolated config):

```bash
make test          # or: ./scripts/run_tests.sh
```

See [`tests/README.md`](tests/README.md) for details.

## Notes

- **Default date**: yesterday UTC (API provides End-of-Day rates for completed UTC days)
- **Case insensitive**: currency codes and aliases are normalized to uppercase
- **Precision**: rates displayed to 6 decimal places, trailing zeros trimmed
- **Rate limits**: free tier API key provides 1,000 requests/month
- **Historical data**: available from 1999-01-01 onwards (API dependent)

## Contributing

Contributions welcome — submit a Pull Request.

### Development Setup

```bash
git clone https://github.com/Open-Technology-Foundation/openxchg.git
cd openxchg
sudo apt-get install sqlite3 wget jq
./openxchg --help
./scripts/run_tests.sh
```

### Coding Standards

Follows the [Bash Coding Standard (BCS)](https://github.com/Open-Technology-Foundation/bash-coding-standard):

- 2-space indentation (strictly enforced)
- `set -euo pipefail` and `shopt -s inherit_errexit` at start
- Typed declarations (`declare`/`local` with `-i`/`-a`/`-A`/`--`)
- Prefer `[[` over `[` for conditionals
- `var+=1` for increments, never `((var++))`
- Scripts end with `#fin` marker
- Verify with `shellcheck -x` and `bcscheck`

## License

GNU General Public License v3.0 - see [LICENSE](LICENSE) for details.

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

**Version**: 2.0.0 | **License**: GPL v3.0 | **Status**: Production Ready
