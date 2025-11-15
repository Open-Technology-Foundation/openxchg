# openxchg

Multi-currency exchange rate database manager that fetches historical exchange rates from the OpenExchangeRates.org API and stores them in a SQLite database.

## Features

- Fetches exchange rates for 169 currencies from OpenExchangeRates.org API
- Stores historical rate data in SQLite database with table-per-base-currency architecture
- Supports multiple base currencies (IDR, USD, EUR, GBP, etc.)
- Case-insensitive currency code handling
- GNU-style argument parsing (options can appear anywhere)
- Two operational modes: UPDATE (fetch from API) and QUERY (retrieve from database)
- Automatic table creation for new base currencies
- Built-in data validation and error handling

## Requirements

- Bash 5.2+
- sqlite3 3.45+
- wget
- jq (JSON processor)
- bc (arbitrary precision calculator)
- OpenExchangeRates.org API key (free tier available)

## Installation

1. Clone or download the `openxchg` script to your preferred location
2. Make the script executable:
   ```bash
   chmod +x openxchg
   ```
3. Set your API key (see [API Configuration](#api-configuration))

## Usage

### Basic Syntax

```bash
openxchg [OPTIONS] [base_currency] [CurrencyCode]...
```

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Display help message |
| `--version` | Display version information |
| `-v, --verbose` | Enable verbose output (default) |
| `-q, --quiet` | Disable verbose output |
| `-d, --date DATE` | Specify date for query/update (default: yesterday) |
| `-a, --apikey KEY` | Use custom API key (overrides OPENEXCHANGE_API_KEY env) |

### UPDATE Mode

Fetch all 169 currency rates from the API and populate the database for a specific base currency:

```bash
# Update IDR table with yesterday's rates
./openxchg idr

# Update EUR table for a specific date
./openxchg -d 2025-01-01 eur

# Update USD table quietly (no progress output)
./openxchg -q usd

# Update GBP table with custom API key
./openxchg -a YOUR_API_KEY gbp
```

### QUERY Mode

Retrieve stored exchange rates from the database:

```bash
# Query latest rates for USD, EUR, GBP from IDR table
./openxchg idr usd eur gbp

# Query AUD rates for USD and SGD
./openxchg aud usd sgd

# Query specific date rates
./openxchg -d 2025-01-01 eur usd gbp

# Options can appear anywhere (GNU-style)
./openxchg eur -d 2025-11-14 usd gbp aud
```

### Example Output

```
Currency    Xchg            Date
----------  --------------  ----------
USD         16712           2025-11-14
EUR         19426.865616    2025-11-14
GBP         21989.647286    2025-11-14
```

## Database Structure

The system uses a SQLite database (`xchg.db`) with a table-per-base-currency architecture:

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

### Exchange Rate Calculation

The OpenExchangeRates API provides all rates relative to USD. The script calculates rates for other base currencies using:

```
exchange_rate = base_currency_rate / target_currency_rate
```

For example, to get IDR/EUR rate:
- API provides: USD/IDR = 16712, USD/EUR = 0.86
- Calculation: EUR rate from IDR = 16712 / 0.86 = 19426.865616

## API Configuration

### Environment Variable (Recommended)

```bash
export OPENEXCHANGE_API_KEY='your_api_key_here'
./openxchg idr
```

### Command-Line Option

```bash
./openxchg -a your_api_key_here idr
```

### Getting an API Key

1. Sign up at [openexchangerates.org](https://openexchangerates.org/)
2. Free tier provides 1,000 requests/month with historical data access
3. Copy your App ID from the dashboard

## Supported Currencies

The system supports 169 currencies:

AED, AFN, ALL, AMD, ANG, AOA, ARS, AUD, AWG, AZN, BAM, BBD, BDT, BGN, BHD, BIF, BMD, BND, BOB, BRL, BSD, BTC, BTN, BWP, BYN, BZD, CAD, CDF, CHF, CLF, CLP, CNH, CNY, COP, CRC, CUC, CUP, CVE, CZK, DJF, DKK, DOP, DZD, EGP, ERN, ETB, EUR, FJD, FKP, GBP, GEL, GGP, GHS, GIP, GMD, GNF, GTQ, GYD, HKD, HNL, HRK, HTG, HUF, IDR, ILS, IMP, INR, IQD, IRR, ISK, JEP, JMD, JOD, JPY, KES, KGS, KHR, KMF, KPW, KRW, KWD, KYD, KZT, LAK, LBP, LKR, LRD, LSL, LYD, MAD, MDL, MGA, MKD, MMK, MNT, MOP, MRU, MUR, MVR, MWK, MXN, MYR, MZN, NAD, NGN, NIO, NOK, NPR, NZD, OMR, PAB, PEN, PGK, PHP, PKR, PLN, PYG, QAR, RON, RSD, RUB, RWF, SAR, SBD, SCR, SDG, SEK, SGD, SHP, SLL, SOS, SRD, SSP, STD, STN, SVC, SYP, SZL, THB, TJS, TMT, TND, TOP, TRY, TTD, TWD, TZS, UAH, UGX, USD, UYU, UZS, VND, VUV, WST, XAF, XAG, XAU, XCD, XDR, XOF, XPD, XPF, XPT, YER, ZAR, ZMW, ZWL

## Direct Database Queries

You can query the database directly using sqlite3:

```bash
# View database schema
sqlite3 xchg.db ".schema"

# List all currency tables
sqlite3 xchg.db "SELECT name FROM sqlite_master WHERE type='table'"

# Query specific currency with formatting
sqlite3 xchg.db -header -column \
  "SELECT * FROM IDR WHERE Currency='USD' ORDER BY Date DESC LIMIT 10"

# Get latest rate for multiple currencies
sqlite3 xchg.db \
  "SELECT Currency, Xchg, Date FROM IDR
   WHERE Currency IN ('USD','EUR','GBP')
   ORDER BY Date DESC, Currency"
```

## Notes

- The script requires root privileges and will automatically elevate using `sudo`
- Default date is yesterday (API requires historical dates, not current day)
- Currency codes are case-insensitive and automatically converted to uppercase
- The UNIQUE constraint on (Date, Currency) prevents duplicate entries
- Exchange rates are stored with 6 decimal places precision
- Each base currency maintains its own complete table of exchange rates

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

GNU General Public License v3.0 - see [LICENSE](LICENSE).

## Authors

Gary Dean, Biksu Okusi
