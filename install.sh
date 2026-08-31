#!/usr/bin/env bash
# install.sh - openxchg installer
#
# Installs openxchg to /usr/local/bin and creates the database directory.
# Usage: bash install.sh
#    or: curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash
set -euo pipefail
shopt -s inherit_errexit

declare -r BIN_DIR=/usr/local/bin
declare -r DATA_DIR=/var/lib/openxchg
declare -r REPO_URL='https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main'
declare -r SCRIPT_NAME=openxchg

#shellcheck disable=SC2059
_msg() { >&2 printf "install: $1 %s\n" "${@:2}"; }
info() { _msg '◉' "$@"; }
error() { _msg '✗' "$@"; }
die() { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

(( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 2) )) \
  || die 2 "Bash 5.2+ required (have ${BASH_VERSION})"

declare -- cmd
for cmd in sqlite3 wget jq; do
  command -v "$cmd" >/dev/null || die 18 "Required: ${cmd@Q} (apt install $cmd)"
done

declare -a sudo_cmd=()
if [[ ! -w $BIN_DIR ]]; then
  command -v sudo >/dev/null || die 13 "No write access to ${BIN_DIR@Q} and sudo not available"
  sudo_cmd=(sudo)
fi

# Use the repo copy when run from a checkout, otherwise download
declare -- src tmp=''
declare -- src_dir
src_dir=$(dirname -- "${BASH_SOURCE[0]:-.}")
if [[ -f $src_dir/$SCRIPT_NAME ]]; then
  src=$src_dir/$SCRIPT_NAME
else
  tmp=$(mktemp) || die 1 'Failed to create temp file'
  trap '[[ -z $tmp ]] || rm -f "$tmp"' EXIT
  wget -qO "$tmp" "$REPO_URL/$SCRIPT_NAME" || die 1 "Download failed from ${REPO_URL@Q}"
  src=$tmp
fi

"${sudo_cmd[@]}" install -m 755 "$src" "$BIN_DIR/$SCRIPT_NAME"
info "Installed $BIN_DIR/$SCRIPT_NAME"

if [[ ! -d $DATA_DIR ]]; then
  "${sudo_cmd[@]}" mkdir -p -- "$DATA_DIR"
  ((${#sudo_cmd[@]} == 0)) || "${sudo_cmd[@]}" chown "$USER": "$DATA_DIR"
fi
info "Database directory: $DATA_DIR"

info 'Done. Next steps:' \
     "  export OPENEXCHANGE_API_KEY='your_key'   # openexchangerates.org/signup/free" \
     "  $SCRIPT_NAME idr                          # populate IDR table" \
     "  $SCRIPT_NAME idr usd eur                  # query rates"
#fin
