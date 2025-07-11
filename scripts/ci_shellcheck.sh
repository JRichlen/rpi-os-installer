#!/bin/bash

# ci_shellcheck.sh
# ShellCheck validation script for CI pipeline

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "${BLUE}[SHELLCHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

main() {
    print_header "Running ShellCheck validation..."
    
    # Check if shellcheck is available
    if ! command -v shellcheck > /dev/null 2>&1; then
        print_fail "ShellCheck is not installed"
        print_info "Install with: brew install shellcheck (macOS) or apt-get install shellcheck (Ubuntu)"
        exit 1
    fi
    
    # Find all shell scripts (excluding generated/dist files)
    print_info "Finding shell scripts..."
    script_count=$(find "$PROJECT_DIR" -name "*.sh" -type f \
        -not -path "*/dist/*" \
        -not -path "*/pi5_installer_work/*" | wc -l)
    print_info "Found $script_count shell scripts"
    
    # Run ShellCheck on all shell scripts
    print_info "Running ShellCheck validation..."
    if find "$PROJECT_DIR" -name "*.sh" -type f \
        -not -path "*/dist/*" \
        -not -path "*/pi5_installer_work/*" \
        -print0 | xargs -0 shellcheck; then
        print_pass "All shell scripts passed ShellCheck validation"
        return 0
    else
        print_fail "ShellCheck validation failed"
        return 1
    fi
}

# Run main function
main "$@"
