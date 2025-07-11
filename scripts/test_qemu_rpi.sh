#!/bin/bash

# test_qemu_rpi.sh
# Test script to simulate Raspberry Pi using QEMU for installer testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_DIR/images4rpi"
QEMU_DIR="$PROJECT_DIR/qemu_test"

print_status() {
    echo -e "${GREEN}[QEMU-TEST]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[QEMU-TEST]${NC} $1"
}

print_error() {
    echo -e "${RED}[QEMU-TEST]${NC} $1" >&2
}

print_step() {
    echo -e "${BLUE}[QEMU-TEST]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if QEMU is installed
    if ! command -v qemu-system-aarch64 &> /dev/null; then
        print_error "QEMU ARM64 not found. Please install: brew install qemu"
        exit 1
    fi
    
    # Check if we have any OS images
    if [[ ! -d "$IMAGES_DIR" ]] || [[ -z "$(ls -A "$IMAGES_DIR"/*.img.xz 2>/dev/null || true)" ]]; then
        print_error "No OS images found in $IMAGES_DIR"
        print_error "Please add some .img.xz files to test with"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Function to create QEMU test environment
setup_qemu_environment() {
    print_step "Setting up QEMU test environment..."
    
    # Create QEMU test directory
    mkdir -p "$QEMU_DIR"
    
    # Download Raspberry Pi firmware if needed
    if [[ ! -f "$QEMU_DIR/RPI_EFI.fd" ]]; then
        print_status "Downloading Raspberry Pi UEFI firmware for QEMU..."
        cd "$QEMU_DIR"
        curl -L -o RPi4_UEFI_Firmware_v1.35.zip https://github.com/pftf/RPi4/releases/download/v1.35/RPi4_UEFI_Firmware_v1.35.zip
        if [[ -f "RPi4_UEFI_Firmware_v1.35.zip" ]]; then
            unzip -q RPi4_UEFI_Firmware_v1.35.zip
            rm -f RPi4_UEFI_Firmware_v1.35.zip
        fi
        cd - > /dev/null
    fi
    
    # Create a virtual SD card image
    if [[ ! -f "$QEMU_DIR/sdcard.img" ]]; then
        print_status "Creating virtual SD card image (8GB)..."
        qemu-img create -f raw "$QEMU_DIR/sdcard.img" 8G
    fi
    
    # Create a virtual USB drive for installer
    if [[ ! -f "$QEMU_DIR/usb_installer.img" ]]; then
        print_status "Creating virtual USB installer drive (2GB)..."
        qemu-img create -f raw "$QEMU_DIR/usb_installer.img" 2G
        
        # Format as FAT32 (this requires additional tools)
        if command -v mkfs.fat &> /dev/null; then
            mkfs.fat -F 32 "$QEMU_DIR/usb_installer.img"
        else
            print_warning "mkfs.fat not found. USB drive will be unformatted."
            print_warning "You may need to format it manually in the VM"
        fi
    fi
    
    print_status "QEMU environment setup complete"
}

# Function to extract and prepare OS image for testing
prepare_test_image() {
    local image_file="$1"
    local image_name
    image_name=$(basename "$image_file" .img.xz)
    
    print_step "Preparing test image: $image_name"
    
    # Extract image if needed
    if [[ ! -f "$QEMU_DIR/${image_name}.img" ]]; then
        print_status "Extracting $image_file..."
        xz -d -c "$image_file" > "$QEMU_DIR/${image_name}.img"
    fi
    
    # Resize image for testing (optional)
    print_status "Resizing image to 8GB for testing..."
    qemu-img resize "$QEMU_DIR/${image_name}.img" 8G
    
    echo "$QEMU_DIR/${image_name}.img"
}

# Function to run QEMU with Raspberry Pi simulation
run_qemu_simulation() {
    local test_mode="$1"
    local image_path="${2:-}"
    
    print_step "Starting QEMU Raspberry Pi simulation..."
    
    case "$test_mode" in
        "installer")
            print_status "Running installer simulation..."
            print_status "This will boot your installer environment"
            
            # Boot from USB installer
            qemu-system-aarch64 \
                -M raspi4b \
                -cpu cortex-a72 \
                -m 4G \
                -smp 4 \
                -bios "$QEMU_DIR/RPI_EFI.fd" \
                -drive file="$QEMU_DIR/usb_installer.img",if=none,id=usb0,format=raw \
                -device usb-storage,drive=usb0 \
                -drive file="$QEMU_DIR/sdcard.img",if=sd,format=raw \
                -netdev user,id=net0 \
                -device usb-net,netdev=net0 \
                -nographic -serial stdio
            ;;
            
        "os-test")
            if [[ -z "$image_path" ]]; then
                print_error "Image path required for OS testing"
                exit 1
            fi
            
            print_status "Running OS image test..."
            print_status "Booting: $(basename "$image_path")"
            
            # Boot from OS image
            qemu-system-aarch64 \
                -M raspi4b \
                -cpu cortex-a72 \
                -m 4G \
                -smp 4 \
                -bios "$QEMU_DIR/RPI_EFI.fd" \
                -drive file="$image_path",if=sd,format=raw \
                -netdev user,id=net0 \
                -device usb-net,netdev=net0 \
                -nographic -serial stdio
            ;;
            
        "interactive")
            print_status "Running interactive mode..."
            print_status "You can test both installer and OS images"
            
            # Boot with both drives available
            qemu-system-aarch64 \
                -M raspi4b \
                -cpu cortex-a72 \
                -m 4G \
                -smp 4 \
                -bios "$QEMU_DIR/RPI_EFI.fd" \
                -drive file="$QEMU_DIR/usb_installer.img",if=none,id=usb0,format=raw \
                -device usb-storage,drive=usb0 \
                -drive file="$QEMU_DIR/sdcard.img",if=sd,format=raw \
                -netdev user,id=net0,hostfwd=tcp::2222-:22 \
                -device usb-net,netdev=net0 \
                -nographic -serial stdio
            ;;
            
        *)
            print_error "Unknown test mode: $test_mode"
            print_error "Available modes: installer, os-test, interactive"
            exit 1
            ;;
    esac
}

# Function to show available OS images
show_available_images() {
    print_step "Available OS images for testing:"
    local count=0
    
    for img in "$IMAGES_DIR"/*.img.xz; do
        if [[ -f "$img" ]]; then
            count=$((count + 1))
            echo "  $count. $(basename "$img")"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_warning "No OS images found in $IMAGES_DIR"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  setup              - Setup QEMU test environment"
    echo "  test-installer     - Test your installer in QEMU"
    echo "  test-os [IMAGE]    - Test a specific OS image"
    echo "  interactive        - Run interactive mode with both drives"
    echo "  list-images        - Show available OS images"
    echo "  clean              - Clean up QEMU test environment"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 test-installer"
    echo "  $0 test-os haos_rpi5-64-16.0.img.xz"
    echo "  $0 interactive"
    echo ""
    echo "Note: This requires QEMU to be installed (brew install qemu)"
}

# Function to clean up QEMU environment
clean_qemu() {
    print_step "Cleaning up QEMU test environment..."
    
    if [[ -d "$QEMU_DIR" ]]; then
        rm -rf "$QEMU_DIR"
        print_status "QEMU test environment cleaned"
    else
        print_status "QEMU test environment already clean"
    fi
}

# Main script logic
main() {
    local command="${1:-help}"
    
    case "$command" in
        "setup")
            check_prerequisites
            setup_qemu_environment
            print_status "QEMU test environment ready!"
            print_status "Run '$0 test-installer' to test your installer"
            ;;
            
        "test-installer")
            check_prerequisites
            setup_qemu_environment
            run_qemu_simulation "installer"
            ;;
            
        "test-os")
            local image_name="${2:-}"
            if [[ -z "$image_name" ]]; then
                print_error "Please specify an OS image to test"
                show_available_images
                exit 1
            fi
            
            local image_path="$IMAGES_DIR/$image_name"
            if [[ ! -f "$image_path" ]]; then
                print_error "Image not found: $image_path"
                show_available_images
                exit 1
            fi
            
            check_prerequisites
            setup_qemu_environment
            local prepared_image
            prepared_image=$(prepare_test_image "$image_path")
            run_qemu_simulation "os-test" "$prepared_image"
            ;;
            
        "interactive")
            check_prerequisites
            setup_qemu_environment
            print_status "Starting interactive mode..."
            print_status "SSH forwarding: localhost:2222 -> VM:22"
            run_qemu_simulation "interactive"
            ;;
            
        "list-images")
            show_available_images
            ;;
            
        "clean")
            clean_qemu
            ;;
            
        "help"|"-h"|"--help")
            show_usage
            ;;
            
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
