#!/bin/bash
set -euo pipefail

#==============================================================================
# install.sh - openxchg installation script
#
# Installs openxchg multi-currency exchange rate database manager
#
# Usage: curl -sSL https://raw.githubusercontent.com/USERNAME/openxchg/main/install.sh | bash
#        or: bash install.sh
#
# Author: Gary Dean, Biksu Okusi
# License: GNU GPL v3.0
#==============================================================================

# Color codes for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m' # No Color

# Installation configuration
declare -r INSTALL_DIR="/usr/local/bin"
declare -r CONFIG_DIR="${HOME}/.config/openxchg"
declare -r REPO_URL="https://raw.githubusercontent.com/USERNAME/openxchg/main"
declare -r VERSION="1.0.0"

#------------------------------------------------------------------------------
# Print colored message
#------------------------------------------------------------------------------
print_message() {
  local -r color="$1"
  local -r message="$2"
  echo -e "${color}${message}${NC}"
}

#------------------------------------------------------------------------------
# Print info message
#------------------------------------------------------------------------------
info() {
  print_message "${BLUE}" "◉ $1"
}

#------------------------------------------------------------------------------
# Print success message
#------------------------------------------------------------------------------
success() {
  print_message "${GREEN}" "✓ $1"
}

#------------------------------------------------------------------------------
# Print warning message
#------------------------------------------------------------------------------
warning() {
  print_message "${YELLOW}" "▲ $1"
}

#------------------------------------------------------------------------------
# Print error message and exit
#------------------------------------------------------------------------------
error() {
  print_message "${RED}" "✗ $1" >&2
  exit 1
}

#------------------------------------------------------------------------------
# Check if command exists
#------------------------------------------------------------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#------------------------------------------------------------------------------
# Get version of command
#------------------------------------------------------------------------------
get_version() {
  local -r cmd="$1"
  case "$cmd" in
    bash)
      bash --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1
      ;;
    sqlite3)
      sqlite3 --version | grep -oP '^\d+\.\d+\.\d+' | head -n1
      ;;
    *)
      echo "0.0.0"
      ;;
  esac
}

#------------------------------------------------------------------------------
# Compare versions (returns 0 if $1 >= $2)
#------------------------------------------------------------------------------
version_gte() {
  local -r version1="$1"
  local -r version2="$2"
  printf '%s\n%s\n' "$version2" "$version1" | sort -V -C 2>/dev/null
}

#------------------------------------------------------------------------------
# Check system requirements
#------------------------------------------------------------------------------
check_requirements() {
  info "Checking system requirements..."

  local -i missing=0

  # Check Bash version
  if command_exists bash; then
    local -r bash_version="$(get_version bash)"
    if version_gte "$bash_version" "5.2.0"; then
      success "Bash $bash_version (required: 5.2+)"
    else
      warning "Bash $bash_version found (required: 5.2+)"
      ((missing+=1))
    fi
  else
    warning "Bash not found (required: 5.2+)"
    ((missing+=1))
  fi

  # Check sqlite3 version
  if command_exists sqlite3; then
    local -r sqlite_version="$(get_version sqlite3)"
    if version_gte "$sqlite_version" "3.45.0"; then
      success "sqlite3 $sqlite_version (required: 3.45+)"
    else
      warning "sqlite3 $sqlite_version found (required: 3.45+)"
      ((missing+=1))
    fi
  else
    warning "sqlite3 not found (required: 3.45+)"
    ((missing+=1))
  fi

  # Check other dependencies
  local -r deps=(wget jq bc)
  local dep
  for dep in "${deps[@]}"; do
    if command_exists "$dep"; then
      success "$dep found"
    else
      warning "$dep not found (required)"
      ((missing+=1))
    fi
  done

  return $missing
}

#------------------------------------------------------------------------------
# Install dependencies (Ubuntu/Debian)
#------------------------------------------------------------------------------
install_dependencies() {
  if ! command_exists apt-get; then
    warning "apt-get not found. Cannot auto-install dependencies."
    warning "Please install manually: bash sqlite3 wget jq bc"
    return 1
  fi

  info "Installing missing dependencies..."

  if [[ $EUID -ne 0 ]]; then
    if command_exists sudo; then
      sudo apt-get update -qq
      sudo apt-get install -y bash sqlite3 wget jq bc
    else
      error "sudo not available. Please run as root or install dependencies manually."
    fi
  else
    apt-get update -qq
    apt-get install -y bash sqlite3 wget jq bc
  fi

  success "Dependencies installed"
}

#------------------------------------------------------------------------------
# Download and install openxchg
#------------------------------------------------------------------------------
install_openxchg() {
  info "Installing openxchg to ${INSTALL_DIR}..."

  local -r temp_file="/tmp/openxchg.$$"

  # Download script
  if command_exists wget; then
    wget -q -O "$temp_file" "${REPO_URL}/openxchg" || error "Failed to download openxchg"
  elif command_exists curl; then
    curl -sSL -o "$temp_file" "${REPO_URL}/openxchg" || error "Failed to download openxchg"
  else
    error "Neither wget nor curl available for download"
  fi

  # Verify download
  [[ -s "$temp_file" ]] || error "Downloaded file is empty"

  # Install to bin directory
  if [[ -w "$INSTALL_DIR" ]]; then
    mv "$temp_file" "${INSTALL_DIR}/openxchg"
    chmod +x "${INSTALL_DIR}/openxchg"
  elif command_exists sudo; then
    sudo mv "$temp_file" "${INSTALL_DIR}/openxchg"
    sudo chmod +x "${INSTALL_DIR}/openxchg"
  else
    error "Cannot write to ${INSTALL_DIR}. Please run with sudo or choose different location."
  fi

  success "openxchg installed to ${INSTALL_DIR}/openxchg"
}

#------------------------------------------------------------------------------
# Setup configuration
#------------------------------------------------------------------------------
setup_config() {
  info "Setting up configuration..."

  # Create config directory
  [[ -d "$CONFIG_DIR" ]] || mkdir -p "$CONFIG_DIR"

  local -r config_file="${CONFIG_DIR}/config"

  # Check if config already exists
  if [[ -f "$config_file" ]]; then
    warning "Configuration file already exists: $config_file"
    read -rp "Overwrite? (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]] || return 0
  fi

  # Prompt for API key
  echo
  info "OpenExchangeRates.org API Key Setup"
  echo "  Get your free API key at: https://openexchangerates.org/signup/free"
  echo "  (Free tier: 1,000 requests/month with historical data)"
  echo
  read -rp "Enter your API key (or press Enter to skip): " api_key

  # Create config file
  cat > "$config_file" <<'EOF'
# openxchg configuration file
# See: openxchg --help for details

[general]
# Default base currency (default: IDR)
DEFAULT_BASE_CURRENCY=IDR

# Verbose output by default (0=quiet, 1=verbose)
DEFAULT_VERBOSE=1

# Default date for queries (yesterday, today, or YYYY-MM-DD)
DEFAULT_DATE=yesterday

[api]
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

[update]
# Auto-update currency list from API (true/false)
AUTO_UPDATE_CURRENCY_LIST=true

# Which currencies to update (ALL, CONFIGURED, or path to file)
UPDATE_CURRENCIES=ALL

[database]
# Custom database path (optional)
# DB_PATH=/custom/path/to/xchg.db
EOF

  chmod 600 "$config_file"
  success "Configuration created: $config_file"

  # Create environment variable suggestion
  if [[ -z "$api_key" ]]; then
    echo
    warning "No API key configured. To set it later, either:"
    echo "  1. Edit ${config_file}"
    echo "  2. Or set environment variable: export OPENEXCHANGE_API_KEY='your_key'"
  fi
}

#------------------------------------------------------------------------------
# Test installation
#------------------------------------------------------------------------------
test_installation() {
  info "Testing installation..."

  if ! command_exists openxchg; then
    error "openxchg command not found. Installation may have failed."
  fi

  # Test help output
  if openxchg --version &>/dev/null; then
    success "openxchg is working correctly"
  else
    warning "openxchg installed but may not be fully functional"
  fi

  # Check for API key
  if [[ -f "${CONFIG_DIR}/config" ]] && grep -q "^API_KEY=" "${CONFIG_DIR}/config"; then
    echo
    info "You can now use openxchg!"
    echo "  Try: openxchg --help"
    echo "  Or:  openxchg idr usd eur gbp"
  else
    echo
    warning "API key not configured. Set it to use openxchg:"
    echo "  export OPENEXCHANGE_API_KEY='your_api_key_here'"
    echo "  Or edit: ${CONFIG_DIR}/config"
  fi
}

#------------------------------------------------------------------------------
# Main installation process
#------------------------------------------------------------------------------
main() {
  echo
  print_message "${BLUE}" "═══════════════════════════════════════════════════"
  print_message "${BLUE}" "  openxchg Installer v${VERSION}"
  print_message "${BLUE}" "  Multi-currency Exchange Rate Database Manager"
  print_message "${BLUE}" "═══════════════════════════════════════════════════"
  echo

  # Check requirements
  if ! check_requirements; then
    echo
    read -rp "Install missing dependencies? (y/N): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      install_dependencies
    else
      error "Missing required dependencies. Please install them manually."
    fi
  fi

  echo

  # Install openxchg
  install_openxchg

  echo

  # Setup configuration
  setup_config

  echo

  # Test installation
  test_installation

  echo
  success "Installation complete!"
  echo
  print_message "${GREEN}" "═══════════════════════════════════════════════════"
  echo
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

#fin
