#!/bin/bash
set -euo pipefail

declare -a MU=(IDR)

declare -i num_days=100

for mu in "${MU[@]}"; do
  echo "$mu"
  for ((i=num_days; i>0; i+= -1)); do
    openxchg "$mu" -d "$i days ago"
  done
done


#fin
