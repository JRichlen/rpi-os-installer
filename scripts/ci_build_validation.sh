#!/bin/bash

# ci_build_validation.sh
# Build process validation script for CI pipeline

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
    echo -e "${BLUE}[BUILD]${NC} $1"
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
    print_info "Installing system dependencies..."
    
    if [[ "${CI:-}" == "true" ]]; then
        # Detect OS in CI environment
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux CI environment (Ubuntu)
            print_info "Detected Linux CI environment"
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                make \
                parted \
                dosfstools \
                e2fsprogs \
                xz-utils \
                unzip \
                wget \
                curl \
                git \
                cpio \
                gzip \
                rsync \
                fdisk \
                util-linux \
                kpartx \
                jq
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
                wget \
                curl \
                gzip \
                rsync || true
        else
            print_info "Unknown CI environment OS: $OSTYPE"
        fi
    else
        # Local environment
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "Local macOS environment detected - ensure dependencies are installed"
            print_info "Run: brew install make xz git cpio jq"
        else
            print_info "Local Linux environment detected - ensure dependencies are installed"
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

validate_makefile() {
    print_info "Validating Makefile targets..."
    cd "$PROJECT_DIR"
    
    # Test help target
    if make help > /dev/null 2>&1; then
        print_pass "Makefile help target works"
    else
        print_fail "Makefile help target failed"
        return 1
    fi
    
    # Test check-deps target
    if make check-deps > /dev/null 2>&1; then
        print_pass "Makefile check-deps target works"
    else
        print_fail "Makefile check-deps target failed"
        return 1
    fi
    
    print_pass "Makefile validation completed"
}

test_script_generation() {
    print_info "Testing OS setup script generation..."
    cd "$PROJECT_DIR"
    
    if make generate > /dev/null 2>&1; then
        print_pass "Script generation completed successfully"
    else
        print_fail "Script generation failed"
        return 1
    fi
}

validate_generated_scripts() {
    print_info "Validating generated scripts..."
    
    if [[ -d "$PROJECT_DIR/pi5_installer_work/os-setups" ]]; then
        if find "$PROJECT_DIR/pi5_installer_work/os-setups" -name "*.sh" -type f -print0 | xargs -0 shellcheck; then
            print_pass "Generated scripts passed ShellCheck validation"
        else
            print_fail "Generated scripts failed ShellCheck validation"
            return 1
        fi
    else
        print_info "No generated scripts found to validate"
    fi
}

main() {
    print_header "Running build process validation..."
    
    install_dependencies
    create_directories
    download_test_image
    validate_makefile
    test_script_generation
    validate_generated_scripts
    
    print_pass "Build process validation completed successfully"
}

# Run main function
main "$@"
