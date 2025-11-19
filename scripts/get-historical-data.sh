#!/bin/bash
set -euo pipefail

# Change currencies here
declare -a CURRENCIES=(USD EUR AUD SGD IDR MYR)

# Specify number of days to update
declare -i num_days=100

declare -- currency
declare -i days
for currency in "${CURRENCIES[@]}"; do
  echo "$currency"
  for ((days=num_days; days>0; days+=-1)); do
    openxchg "$currency" -d "$days days ago"
  done
done

#fin
