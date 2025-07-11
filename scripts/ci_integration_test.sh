#!/bin/bash

# ci_integration_test.sh
# Integration testing script for CI pipeline

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
    echo -e "${BLUE}[INTEGRATION]${NC} $1"
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
    print_info "Installing integration test dependencies..."
    
    if [[ "${CI:-}" == "true" ]]; then
        # CI environment (Ubuntu)
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
    else
        # Local environment (macOS)
        print_info "Local environment detected - ensure dependencies are installed"
        print_info "Run: brew install make xz git cpio jq"
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

run_full_workflow() {
    print_info "Running full integration workflow..."
    cd "$PROJECT_DIR"
    
    # Test the complete workflow
    if make generate > /dev/null 2>&1; then
        print_pass "Complete workflow generation successful"
    else
        print_fail "Complete workflow generation failed"
        return 1
    fi
}

validate_generated_scripts() {
    print_info "Validating all generated scripts..."
    
    if [[ -d "$PROJECT_DIR/pi5_installer_work/os-setups" ]]; then
        print_info "Validating generated scripts with ShellCheck..."
        if find "$PROJECT_DIR/pi5_installer_work/os-setups" -name "*.sh" -type f -print0 | xargs -0 shellcheck; then
            print_pass "All generated scripts passed ShellCheck validation"
        else
            print_fail "Generated scripts failed ShellCheck validation"
            return 1
        fi
    else
        print_info "No generated scripts found to validate"
    fi
}

test_script_execution() {
    print_info "Testing script execution capabilities..."
    
    # Test that scripts can be executed (dry run)
    if [[ -d "$PROJECT_DIR/pi5_installer_work/os-setups" ]]; then
        for script in "$PROJECT_DIR/pi5_installer_work/os-setups"/*.sh; do
            if [[ -f "$script" ]]; then
                script_name=$(basename "$script")
                print_info "Testing execution of $script_name..."
                
                # Test with --help flag if available
                if bash "$script" --help > /dev/null 2>&1; then
                    print_pass "$script_name help function works"
                elif bash "$script" help > /dev/null 2>&1; then
                    print_pass "$script_name help function works"
                else
                    print_info "$script_name doesn't have help function (OK)"
                fi
            fi
        done
    fi
}

test_build_system() {
    print_info "Testing build system integration..."
    cd "$PROJECT_DIR"
    
    # Test various make targets
    targets=("help" "check-deps" "generate" "status")
    
    for target in "${targets[@]}"; do
        print_info "Testing make $target..."
        if make "$target" > /dev/null 2>&1; then
            print_pass "make $target works"
        else
            print_fail "make $target failed"
            return 1
        fi
    done
}

test_directory_structure() {
    print_info "Testing directory structure integrity..."
    
    # Expected directories
    expected_dirs=(
        "scripts"
        "pi5_installer_work"
        "images4rpi"
        "qemu_test"
    )
    
    for dir in "${expected_dirs[@]}"; do
        if [[ -d "$PROJECT_DIR/$dir" ]]; then
            print_pass "Directory $dir exists"
        else
            print_fail "Directory $dir missing"
            return 1
        fi
    done
    
    # Expected files
    expected_files=(
        "Makefile"
        "README.md"
        "TESTING.md"
        "scripts/generate_os_setup.sh"
        "scripts/setup_pi5_installer.sh"
    )
    
    for file in "${expected_files[@]}"; do
        if [[ -f "$PROJECT_DIR/$file" ]]; then
            print_pass "File $file exists"
        else
            print_fail "File $file missing"
            return 1
        fi
    done
}

main() {
    print_header "Running integration testing..."
    
    install_dependencies
    create_directories
    download_test_image
    run_full_workflow
    validate_generated_scripts
    test_script_execution
    test_build_system
    test_directory_structure
    
    print_pass "Integration testing completed successfully"
}

# Run main function
main "$@"
