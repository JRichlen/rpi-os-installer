#!/bin/bash

# validate_tests.sh
# Quick validation of testing capabilities

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_test() {
    echo -e "${BLUE}[VALIDATION]${NC} $1"
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

echo "Pi 5 Installer Testing Validation"
echo "=================================="

# Test 1: Basic project tests
print_test "Running basic project tests..."
if make test-setup > /dev/null 2>&1; then
    print_pass "Basic project tests work"
else
    print_fail "Basic project tests failed"
fi

# Test 2: QEMU availability
print_test "Checking QEMU availability..."
if command -v qemu-system-aarch64 > /dev/null 2>&1; then
    print_pass "QEMU ARM64 is available"
    qemu_version=$(qemu-system-aarch64 --version | head -n1)
    print_info "Version: $qemu_version"
else
    print_fail "QEMU ARM64 not found"
fi

# Test 3: QEMU script functionality
print_test "Testing QEMU script basic functionality..."
if ./scripts/test_qemu_rpi.sh list-images > /dev/null 2>&1; then
    print_pass "QEMU script basic functions work"
    images_count=$(./scripts/test_qemu_rpi.sh list-images 2>/dev/null | grep -c "\.img\.xz" || echo "0")
    print_info "Found $images_count OS images for testing"
else
    print_fail "QEMU script has issues"
fi

# Test 4: Docker availability
print_test "Checking Docker availability..."
if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    print_pass "Docker is available and running"
    docker_version=$(docker --version)
    print_info "Version: $docker_version"
else
    print_fail "Docker not available or not running"
fi

# Test 5: Docker script functionality
print_test "Testing Docker script basic functionality..."
if ./scripts/test_docker_rpi.sh help > /dev/null 2>&1; then
    print_pass "Docker script basic functions work"
else
    print_fail "Docker script has issues"
fi

# Test 6: Required tools for testing
print_test "Checking required testing tools..."
missing_tools=()

for tool in xz git cpio; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        missing_tools+=("$tool")
    fi
done

if command -v mkfs.fat > /dev/null 2>&1; then
    print_pass "FAT32 formatting tools available"
else
    missing_tools+=("dosfstools")
fi

if [[ ${#missing_tools[@]} -eq 0 ]]; then
    print_pass "All required testing tools available"
else
    print_fail "Missing tools: ${missing_tools[*]}"
    if [[ "${CI:-}" == "true" ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_info "Install with: sudo apt-get install ${missing_tools[*]}"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Install with: brew install ${missing_tools[*]}"
        else
            print_info "Install required tools with your package manager"
        fi
    else
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Install with: brew install ${missing_tools[*]}"
        else
            print_info "Install with your package manager"
        fi
    fi
fi

# Test 7: Testing directory structure
print_test "Checking testing setup..."
test_files=(
    "scripts/test_qemu_rpi.sh"
    "scripts/test_docker_rpi.sh"
    "TESTING.md"
)

all_present=true
for file in "${test_files[@]}"; do
    if [[ -f "$PROJECT_DIR/$file" ]]; then
        if [[ -x "$PROJECT_DIR/$file" ]] || [[ "$file" == *.md ]]; then
            print_pass "Found $file"
        else
            print_fail "$file exists but is not executable"
            all_present=false
        fi
    else
        print_fail "Missing $file"
        all_present=false
    fi
done

if $all_present; then
    print_pass "Testing setup is complete"
fi

# Test 8: Quick QEMU setup test
print_test "Testing QEMU setup capability..."
if [[ -d "$PROJECT_DIR/qemu_test" ]]; then
    qemu_files=("sdcard.img" "usb_installer.img" "RPI_EFI.fd")
    qemu_ready=true
    
    for file in "${qemu_files[@]}"; do
        if [[ ! -f "$PROJECT_DIR/qemu_test/$file" ]]; then
            qemu_ready=false
            break
        fi
    done
    
    if $qemu_ready; then
        print_pass "QEMU test environment is already set up"
    else
        print_info "QEMU environment partially set up, run 'make test-qemu' to complete"
    fi
else
    print_info "QEMU environment not set up yet, run 'make test-qemu' to set up"
fi

echo ""
echo "Validation Summary:"
echo "=================="
echo "✅ Available testing methods:"

if command -v qemu-system-aarch64 > /dev/null 2>&1; then
    echo "   • QEMU Pi simulation (most realistic)"
fi

if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    echo "   • Docker ARM64 testing (fast development)"
fi

echo "   • Native macOS testing (quickest)"
echo "   • CI validation scripts (comprehensive)"

echo ""
echo "🚀 Quick start commands:"
echo "   make test-setup                    # Quick project validation"
echo "   make test-qemu                     # Setup Pi simulation"
echo "   make test-qemu-interactive         # Interactive Pi testing"
echo "   make test-docker                   # Setup ARM64 environment"
echo "   make test-docker-interactive       # Interactive ARM64 testing"

echo ""
echo "� CI validation commands:"
echo "   make ci-all                        # Run all CI checks"
echo "   make ci-shellcheck                 # ShellCheck validation"
echo "   make ci-build                      # Build process validation"
echo "   make ci-security                   # Security scanning"
echo "   make ci-testing                    # Testing framework validation"
echo "   make ci-integration                # Integration testing"
echo "   make ci-docs                       # Documentation validation"

echo ""
echo "�📖 See TESTING.md for detailed testing workflows"
