#!/bin/bash
#==============================================================================
# install.sh - openxchg installation script
#
# Installs openxchg multi-currency exchange rate database manager
#
# Usage: curl -sSL https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main/install.sh | bash
#        or: bash install.sh
#
# Author: Gary Dean, Biksu Okusi
# License: GNU GPL v3.0
#==============================================================================
set -euo pipefail
shopt -s inherit_errexit extglob nullglob

# Installation configuration
declare -r INSTALL_DIR=/usr/local/bin
declare -r CONFIG_DIR="$HOME"/.config/openxchg
declare -r REPO_URL='https://raw.githubusercontent.com/Open-Technology-Foundation/openxchg/main'
declare -r VERSION='1.0.0'

declare -r SCRIPT_NAME=openxchg
# Color definitions
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
# Utility functions
_log() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    print)   : ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}▲${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}
print() { _log "$@"; }
info() { >&2 _log "$@"; }
warn() { >&2 _log "$@"; }
success() { _log "$@"; }
error() { >&2 _log "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }


#------------------------------------------------------------------------------
# Check if command exists
#------------------------------------------------------------------------------
command_exists() { command -v "$1" >/dev/null 2>&1; }

#------------------------------------------------------------------------------
# Get version of command
#------------------------------------------------------------------------------
get_version() {
  case $1 in
    bash)
      bash --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1
      ;;
    sqlite3)
      sqlite3 --version | grep -oP '^\d+\.\d+\.\d+' | head -n1
      ;;
    *)
      echo '0.0.0'
      ;;
  esac
}

#------------------------------------------------------------------------------
# Compare versions (returns 0 if $1 >= $2)
#------------------------------------------------------------------------------
version_gte() {
  local -r version1=$1 version2=$2
  printf '%s\n%s\n' "$version2" "$version1" | sort -V -C 2>/dev/null
}

#------------------------------------------------------------------------------
# Check system requirements
#------------------------------------------------------------------------------
check_requirements() {
  info 'Checking system requirements...'

  local -i missing=0

  # Check Bash version
  if command_exists bash; then
    local -r bash_version="$(get_version bash)"
    if version_gte "$bash_version" '5.2.0'; then
      success "Bash $bash_version (required: 5.2+)"
    else
      warn "Bash $bash_version found (required: 5.2+)"
      missing+=1
    fi
  else
    warn 'Bash not found (required: 5.2+)'
    missing+=1
  fi

  # Check sqlite3 version
  if command_exists sqlite3; then
    local -r sqlite_version="$(get_version sqlite3)"
    if version_gte "$sqlite_version" '3.45.0'; then
      success "sqlite3 $sqlite_version (required: 3.45+)"
    else
      warn "sqlite3 $sqlite_version found (required: 3.45+)"
      missing+=1
    fi
  else
    warn 'sqlite3 not found (required: 3.45+)'
    missing+=1
  fi

  # Check other dependencies
  local -r deps=(wget jq bc)
  local dep
  for dep in "${deps[@]}"; do
    if command_exists "$dep"; then
      success "$dep found"
    else
      warn "$dep not found (required)"
      missing+=1
    fi
  done

  return $missing
}

#------------------------------------------------------------------------------
# Install dependencies (Ubuntu/Debian)
#------------------------------------------------------------------------------
install_dependencies() {
  command_exists apt-get ||  die 1 'apt-get not found. Cannot auto-install dependencies.' \
                                   'Please install manually: bash sqlite3 wget jq bc'

  info 'Installing missing dependencies...'

  if ((EUID)); then
    if command_exists sudo; then
      sudo apt-get update -qq
      sudo apt-get install -y bash sqlite3 wget jq bc
    else
      die 1 'sudo not available. Please run as root or install dependencies manually.'
    fi
  else
    apt-get update -qq
    apt-get install -y bash sqlite3 wget jq bc
  fi

  success 'Dependencies installed'
}

#------------------------------------------------------------------------------
# Download and install openxchg
#------------------------------------------------------------------------------
install_openxchg() {
  info "Installing openxchg to ${INSTALL_DIR@Q}"

  local -r temp_file="/tmp/openxchg.$$"

  # Download script
  if command_exists wget; then
    wget -q -O "$temp_file" "$REPO_URL"/openxchg || die $? 'Failed to download openxchg'
  elif command_exists curl; then
    curl -sSL -o "$temp_file" "$REPO_URL"/openxchg || die $? 'Failed to download openxchg'
  else
    die 1 'Neither wget nor curl available for download'
  fi

  # Verify download
  [[ -s "$temp_file" ]] || die 1 'Downloaded file is empty'

  # Install to bin directory
  if [[ -w "$INSTALL_DIR" ]]; then
    mv "$temp_file" "$INSTALL_DIR"/openxchg
    chmod +x "$INSTALL_DIR"/openxchg
  elif command_exists sudo; then
    sudo mv "$temp_file" "$INSTALL_DIR"/openxchg
    sudo chmod +x "$INSTALL_DIR"/openxchg
  else
    die 1 "Cannot write to ${INSTALL_DIR@Q}. Please run with sudo or choose different location."
  fi

  success "openxchg installed to $INSTALL_DIR/openxchg"
}

#------------------------------------------------------------------------------
# Setup database directory
#------------------------------------------------------------------------------
setup_database() {
  info 'Setting up database directory...'

  local -r db_dir=/var/lib/openxchg

  # Create database directory
  if [[ -d "$db_dir" ]]; then
    success "Database directory already exists: $db_dir"
  elif [[ -w /var/lib ]]; then
    mkdir -p "$db_dir"
    success "Database directory created: $db_dir"
  elif command_exists sudo; then
    sudo mkdir -p "$db_dir"
    sudo chown "$USER":"$USER" "$db_dir"
    success "Database directory created: $db_dir"
  else
    warn "Cannot create $db_dir. Database will be created in user directory."
    return 1
  fi

  return 0
}

#------------------------------------------------------------------------------
# Setup configuration
#------------------------------------------------------------------------------
setup_config() {
  info 'Setting up configuration...'

  # Create config directory
  [[ -d "$CONFIG_DIR" ]] || mkdir -p "$CONFIG_DIR"

  local -r config_file="$CONFIG_DIR"/config

  # Check if config already exists
  if [[ -f "$config_file" ]]; then
    warn "Configuration file already exists ${config_file@Q}"
    read -rp 'Overwrite? (y/N): ' response
    [[ "$response" =~ ^[Yy]$ ]] || return 0
  fi

  # Prompt for API key
  echo
  info 'OpenExchangeRates.org API Key Setup'
  print '  Get your free API key at: https://openexchangerates.org/signup/free' \
        '  (Free tier: 1,000 requests/month with historical data)' ''
  read -rp 'Enter your API key (or press Enter to skip): ' api_key

  # Create config file
  cat > "$config_file" <<'EOF'
# openxchg configuration file
# See: openxchg --help for details

[General]
# Default base currency (default: IDR)
DEFAULT_BASE_CURRENCY=IDR

# Verbose output by default (0=quiet, 1=verbose)
DEFAULT_VERBOSE=1

# Default date for queries (yesterday, today, or YYYY-MM-DD)
DEFAULT_DATE=yesterday

# Auto-update currency list from API (true/false)
AUTO_UPDATE_CURRENCY_LIST=true

# Which currencies to update (ALL, CONFIGURED, or path to file)
UPDATE_CURRENCIES=ALL

[API]
# OpenExchangeRates.org API key
# WARNING: Storing API key in config file is less secure than using
# environment variable OPENEXCHANGE_API_KEY
EOF
  if [[ -n "$api_key" ]]; then
    echo "API_KEY=${api_key}" >> "$config_file"
  else
    echo "# API_KEY=your_api_key_here" >> "$config_file"
  fi

  cat >> "$config_file" <<'EOF'

[Database]
# Database file location
# Must be an absolute path (relative paths are not allowed)
# Default: /var/lib/openxchg/xchg.db
DB_PATH=/var/lib/openxchg/xchg.db

# Usage examples:
#   DB_PATH=/var/lib/openxchg/xchg.db           # System-wide location
#   DB_PATH=~/.local/share/openxchg/xchg.db     # User-specific location
#   DB_PATH=/ai/scripts/openxchg/xchg.db        # Script directory location
EOF

  chmod 600 "$config_file"
  success "Configuration created ${config_file@Q}"

  # Create environment variable suggestion
  if [[ -z "$api_key" ]]; then
    echo
    warn 'No API key configured. To set it later, either:'
    print "  1. Edit ${config_file@Q}" \
          "  2. Or set environment variable: export OPENEXCHANGE_API_KEY='your_key'"
  fi
}

#------------------------------------------------------------------------------
# Test installation
#------------------------------------------------------------------------------
test_installation() {
  info 'Testing installation...'

  command_exists openxchg || die 1 'openxchg command not found. Installation may have failed.'

  # Test help output
  if openxchg --version &>/dev/null; then
    success 'openxchg is working correctly'
  else
    warn 'openxchg installed but may not be fully functional'
  fi

  # Check for API key
  if [[ -f "${CONFIG_DIR}/config" ]] && grep -q "^API_KEY=" "${CONFIG_DIR}/config"; then
    echo
    info 'You can now use openxchg'
    print '  Try: openxchg --help' \
          '  Or:  openxchg idr usd eur gbp'
  else
    echo
    warn 'API key not configured. Set it to use openxchg:'
    print "  export OPENEXCHANGE_API_KEY='your_api_key_here'" \
          "  Or edit: ${CONFIG_DIR}/config"
  fi
}

#------------------------------------------------------------------------------
# Main installation process
#------------------------------------------------------------------------------
main() {
  print '═══════════════════════════════════════════════════' \
        "  openxchg Installer ${VERSION}" \
        '  Multi-currency Exchange Rate Database Manager' \
        '═══════════════════════════════════════════════════' ''

  # Check requirements
  if ! check_requirements; then
    echo
    read -rp 'Install missing dependencies? (y/N): ' response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      install_dependencies
    else
      die 1 'Missing required dependencies. Please install them manually.'
    fi
  fi

  # Install openxchg
  install_openxchg

  # Setup database directory
  setup_database

  # Setup configuration
  setup_config

  # Test installation
  test_installation

  success 'Installation complete'
}

main "$@"
#fin
