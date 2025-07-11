#!/bin/bash

# test_setup.sh
# Test script to verify the Pi 5 installer setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test functions
test_project_structure() {
    print_test "Testing project structure..."
    
    local required_files=(
        "README.md"
        ".gitignore"
        "Makefile"
        "scripts/download_images.sh"
        "scripts/generate_os_setup.sh"
        "scripts/setup_pi5_installer.sh"
        "images4rpi"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -e "$PROJECT_DIR/$file" ]]; then
            print_pass "Found $file"
        else
            print_fail "Missing $file"
            return 1
        fi
    done
    
    return 0
}

test_script_permissions() {
    print_test "Testing script permissions..."
    
    local scripts=(
        "scripts/download_images.sh"
        "scripts/generate_os_setup.sh"
        "scripts/setup_pi5_installer.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$PROJECT_DIR/$script" ]]; then
            print_pass "$script is executable"
        else
            print_fail "$script is not executable"
            return 1
        fi
    done
    
    return 0
}

test_images_directory() {
    print_test "Testing images directory..."
    
    if [[ ! -d "$PROJECT_DIR/images4rpi" ]]; then
        print_fail "images4rpi directory not found"
        return 1
    fi
    
    local image_count
    image_count=$(find "$PROJECT_DIR/images4rpi" -name "*.img.xz" -type f | wc -l)
    
    if [[ "$image_count" -gt 0 ]]; then
        print_pass "Found $image_count OS image(s)"
    else
        print_fail "No OS images found in images4rpi/"
        return 1
    fi
    
    return 0
}

test_dependencies() {
    print_test "Testing dependencies..."
    
    # Check if running in CI environment
    if [[ "${CI:-}" == "true" ]]; then
        print_test "Running in CI environment - checking for Linux Homebrew..."
        
        # Check for Linux Homebrew
        if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
            print_pass "Homebrew is installed (Linux)"
            # Set up Homebrew environment
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        else
            print_fail "Homebrew is not installed in CI"
            return 1
        fi
    else
        # Check for macOS Homebrew
        if command -v brew &> /dev/null; then
            print_pass "Homebrew is installed"
        else
            print_fail "Homebrew is not installed"
            return 1
        fi
    fi
    
    # Check for required tools
    local tools=(git xz cpio)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_pass "$tool is available"
        else
            print_fail "$tool is not available"
        fi
    done
    
    # Check for Tailscale (optional in CI)
    if [[ "${CI:-}" == "true" ]]; then
        print_test "Skipping Tailscale check in CI environment"
    else
        # Check for Tailscale
        if [[ -f "/usr/local/bin/tailscale" ]] || [[ -f "/opt/homebrew/bin/tailscale" ]]; then
            print_pass "Tailscale binary found"
        else
            print_fail "Tailscale binary not found"
        fi
    fi
    
    return 0
}

test_generate_script() {
    print_test "Testing generate script (dry run)..."
    
    # This would normally run the script, but we'll just check syntax
    if bash -n "$PROJECT_DIR/scripts/generate_os_setup.sh"; then
        print_pass "generate_os_setup.sh syntax is valid"
    else
        print_fail "generate_os_setup.sh has syntax errors"
        return 1
    fi
    
    return 0
}

test_installer_script() {
    print_test "Testing installer script (dry run)..."
    
    # This would normally run the script, but we'll just check syntax
    if bash -n "$PROJECT_DIR/scripts/setup_pi5_installer.sh"; then
        print_pass "setup_pi5_installer.sh syntax is valid"
    else
        print_fail "setup_pi5_installer.sh has syntax errors"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    echo "Pi 5 Installer Test Suite"
    echo "========================="
    
    local test_results=()
    
    # Run tests
    test_project_structure && test_results+=("PASS") || test_results+=("FAIL")
    test_script_permissions && test_results+=("PASS") || test_results+=("FAIL")
    test_images_directory && test_results+=("PASS") || test_results+=("FAIL")
    test_dependencies && test_results+=("PASS") || test_results+=("FAIL")
    test_generate_script && test_results+=("PASS") || test_results+=("FAIL")
    test_installer_script && test_results+=("PASS") || test_results+=("FAIL")
    
    # Summary
    echo
    echo "Test Summary:"
    echo "============"
    
    local pass_count=0
    local fail_count=0
    
    for result in "${test_results[@]}"; do
        if [[ "$result" == "PASS" ]]; then
            ((pass_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo "Tests passed: $pass_count"
    echo "Tests failed: $fail_count"
    
    if [[ "$fail_count" -eq 0 ]]; then
        print_pass "All tests passed!"
        return 0
    else
        print_fail "Some tests failed"
        return 1
    fi
}

# Run main function
main "$@"
