#!/bin/bash
#
# install_bats.sh - Install BATS (Bash Automated Testing System) and helpers
#
# Installs bats-core, bats-support, bats-assert, and bats-file for comprehensive
# Bash testing capabilities.
#
# Usage: ./install_bats.sh [install_dir]
#
# If install_dir is not provided, installs to /usr/local

set -euo pipefail
set -o inherit_errexit

declare -r SCRIPT_NAME="${0##*/}"
declare -r INSTALL_DIR="${1:-/usr/local}"

# BATS and helper library versions
declare -r BATS_VERSION="v1.11.0"
declare -r BATS_SUPPORT_VERSION="v0.3.0"
declare -r BATS_ASSERT_VERSION="v2.1.0"
declare -r BATS_FILE_VERSION="v0.4.0"

# GitHub URLs
declare -r BATS_REPO="https://github.com/bats-core/bats-core.git"
declare -r BATS_SUPPORT_REPO="https://github.com/bats-core/bats-support.git"
declare -r BATS_ASSERT_REPO="https://github.com/bats-core/bats-assert.git"
declare -r BATS_FILE_REPO="https://github.com/bats-core/bats-file.git"

# Temporary directory for cloning
declare -r TEMP_DIR="/tmp/bats-install-$$"

#
# die - Print error message and exit
#
die() {
  local -i code=$1
  shift
  echo "ERROR: $*" >&2
  exit "$code"
}

#
# check_dependencies - Verify required commands are available
#
check_dependencies() {
  local -a missing=()

  for cmd in git make; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if ((${#missing[@]} > 0)); then
    die 1 "Missing required commands: ${missing[*]}"
  fi
}

#
# install_bats_core - Install bats-core framework
#
install_bats_core() {
  echo "Installing bats-core ${BATS_VERSION}..."

  cd "$TEMP_DIR"
  git clone --depth 1 --branch "$BATS_VERSION" "$BATS_REPO" bats-core
  cd bats-core

  if [[ "$INSTALL_DIR" == "/usr/local" ]]; then
    sudo ./install.sh "$INSTALL_DIR"
  else
    ./install.sh "$INSTALL_DIR"
  fi

  echo "✓ bats-core installed to $INSTALL_DIR"
}

#
# install_bats_helper - Install a BATS helper library
#
install_bats_helper() {
  local -- name="$1"
  local -- repo="$2"
  local -- version="$3"
  local -- target_dir="${INSTALL_DIR}/lib/bats-${name}"

  echo "Installing bats-${name} ${version}..."

  cd "$TEMP_DIR"
  git clone --depth 1 --branch "$version" "$repo" "bats-${name}"

  if [[ "$INSTALL_DIR" == "/usr/local" ]]; then
    sudo mkdir -p "$target_dir"
    sudo cp -r "bats-${name}/src" "$target_dir/"
    sudo cp "bats-${name}/load.bash" "$target_dir/" 2>/dev/null || true
  else
    mkdir -p "$target_dir"
    cp -r "bats-${name}/src" "$target_dir/"
    cp "bats-${name}/load.bash" "$target_dir/" 2>/dev/null || true
  fi

  echo "✓ bats-${name} installed to $target_dir"
}

#
# verify_installation - Check that BATS and helpers are installed correctly
#
verify_installation() {
  echo ""
  echo "Verifying installation..."

  if ! command -v bats &>/dev/null; then
    die 1 "bats command not found after installation"
  fi

  local -- bats_version
  bats_version=$(bats --version)
  echo "✓ $bats_version"

  # Check helper libraries
  local -a helpers=(support assert file)
  for helper in "${helpers[@]}"; do
    if [[ -d "${INSTALL_DIR}/lib/bats-${helper}" ]]; then
      echo "✓ bats-${helper} installed"
    else
      echo "⦿ WARNING: bats-${helper} not found"
    fi
  done
}

#
# cleanup - Remove temporary directory
#
cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

#
# main - Main installation logic
#
main() {
  trap cleanup EXIT

  echo "BATS Installation Script"
  echo "========================"
  echo ""
  echo "Install directory: $INSTALL_DIR"
  echo ""

  # Check dependencies
  check_dependencies

  # Create temp directory
  mkdir -p "$TEMP_DIR"

  # Install BATS core
  install_bats_core

  # Install helper libraries
  install_bats_helper "support" "$BATS_SUPPORT_REPO" "$BATS_SUPPORT_VERSION"
  install_bats_helper "assert" "$BATS_ASSERT_REPO" "$BATS_ASSERT_VERSION"
  install_bats_helper "file" "$BATS_FILE_REPO" "$BATS_FILE_VERSION"

  # Verify installation
  verify_installation

  echo ""
  echo "✓ BATS installation complete!"
  echo ""
  echo "Usage:"
  echo "  bats tests/                    # Run all tests"
  echo "  bats tests/unit/               # Run unit tests only"
  echo "  bats tests/unit/test_config.bats  # Run specific test file"
  echo ""
}

main "$@"

#fin
