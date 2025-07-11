#!/bin/bash

# ci_testing_framework.sh
# Testing framework validation script for CI pipeline

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
    echo -e "${BLUE}[TESTING]${NC} $1"
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

install_dependencies() {
    print_info "Installing testing dependencies..."
    
    if [[ "${CI:-}" == "true" ]]; then
        # Detect OS in CI environment
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux CI environment (Ubuntu)
            print_info "Detected Linux CI environment"
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                make \
                qemu-system-arm \
                qemu-user-static \
                binfmt-support \
                parted \
                dosfstools \
                e2fsprogs \
                xz-utils \
                unzip \
                wget \
                curl \
                git \
                shellcheck \
                cpio \
                gzip \
                rsync \
                fdisk \
                util-linux \
                kpartx \
                jq
                
            # Install Docker
            if ! command -v docker > /dev/null 2>&1; then
                print_info "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker "$USER"
                rm -f get-docker.sh
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS CI environment
            print_info "Detected macOS CI environment"
            
            # Install Homebrew if not present
            if ! command -v brew > /dev/null 2>&1; then
                print_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            
            # Install required packages
            brew install \
                make \
                xz \
                git \
                cpio \
                jq \
                shellcheck \
                qemu || true
                
            # Docker for Mac is usually pre-installed in GitHub Actions macOS runners
            if ! command -v docker > /dev/null 2>&1; then
                print_info "Docker not found - may not be available in this macOS runner"
            fi
        else
            print_info "Unknown CI environment OS: $OSTYPE"
        fi
    else
        # Local environment
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Local macOS environment detected - ensure testing dependencies are installed"
            print_info "Run: brew install make xz git cpio jq shellcheck qemu"
        else
            print_info "Local Linux environment detected - ensure testing dependencies are installed"
            print_info "Install required packages with your package manager"
        fi
    fi
}

create_directories() {
    print_info "Creating required directories..."
    mkdir -p "$PROJECT_DIR/images4rpi"
    mkdir -p "$PROJECT_DIR/pi5_installer_work"
    mkdir -p "$PROJECT_DIR/qemu_test"
    print_pass "Required directories created"
}

download_test_image() {
    print_info "Downloading test image..."
    if [[ "${CI:-}" == "true" ]]; then
        # Only download in CI to avoid slow local builds
        cd "$PROJECT_DIR"
        ./scripts/download_images.sh --haos
        print_pass "Test image downloaded"
    else
        print_info "Skipping image download in local environment"
    fi
}

validate_testing_framework() {
    print_info "Running testing framework validation..."
    cd "$PROJECT_DIR"
    
    if make validate > /dev/null 2>&1; then
        print_pass "Testing framework validation completed"
    else
        print_fail "Testing framework validation failed"
        return 1
    fi
}

run_setup_tests() {
    print_info "Running setup tests..."
    cd "$PROJECT_DIR"
    
    if make test-setup; then
        print_pass "Setup tests completed successfully"
    else
        print_fail "Setup tests failed"
        return 1
    fi
}

check_qemu_availability() {
    print_info "Checking QEMU availability..."
    
    if command -v qemu-system-aarch64 > /dev/null 2>&1; then
        print_pass "QEMU ARM64 is available"
        qemu_version=$(qemu-system-aarch64 --version | head -n1)
        print_info "Version: $qemu_version"
    else
        print_info "QEMU ARM64 not available (not required for basic testing)"
    fi
}

check_docker_availability() {
    print_info "Checking Docker availability..."
    
    if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
        print_pass "Docker is available and running"
        docker_version=$(docker --version)
        print_info "Version: $docker_version"
    else
        print_info "Docker not available (not required for basic testing)"
    fi
}

test_script_functionality() {
    print_info "Testing script functionality..."
    cd "$PROJECT_DIR"
    
    # Test QEMU script if available
    if [[ -x "scripts/test_qemu_rpi.sh" ]]; then
        if ./scripts/test_qemu_rpi.sh list-images > /dev/null 2>&1; then
            print_pass "QEMU script basic functions work"
        else
            print_info "QEMU script has issues (non-critical)"
        fi
    fi
    
    # Test Docker script if available
    if [[ -x "scripts/test_docker_rpi.sh" ]]; then
        if ./scripts/test_docker_rpi.sh help > /dev/null 2>&1; then
            print_pass "Docker script basic functions work"
        else
            print_info "Docker script has issues (non-critical)"
        fi
    fi
}

main() {
    print_header "Running testing framework validation..."
    
    install_dependencies
    create_directories
    download_test_image
    validate_testing_framework
    run_setup_tests
    check_qemu_availability
    check_docker_availability
    test_script_functionality
    
    print_pass "Testing framework validation completed successfully"
}

# Run main function
main "$@"
