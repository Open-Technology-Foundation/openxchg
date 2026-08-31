#!/usr/bin/env bash
# run_tests.sh - run the openxchg BATS test suite
set -euo pipefail
shopt -s inherit_errexit

#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -e -- "$0")
declare -r REPO_ROOT=${SCRIPT_PATH%/*/*}

command -v bats >/dev/null \
  || { >&2 echo 'bats required: run scripts/install_bats.sh'; exit 18; }

exec bats "$REPO_ROOT"/tests/openxchg.bats "$@"
#fin
