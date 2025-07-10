#!/bin/bash

# download_images.sh
# Script to download OS images from their original sources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_DIR/images4rpi"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to download file with progress
download_file() {
    local url="$1"
    local filename="$2"
    local filepath="$IMAGES_DIR/$filename"
    
    print_status "Downloading $filename..."
    
    if [[ -f "$filepath" ]]; then
        print_warning "$filename already exists. Skipping download."
        return 0
    fi
    
    # Use curl with progress bar
    if curl -L --progress-bar -o "$filepath" "$url"; then
        print_status "Successfully downloaded $filename"
        return 0
    else
        print_error "Failed to download $filename"
        rm -f "$filepath"
        return 1
    fi
}

# Function to verify file integrity (if checksums are available)
verify_file() {
    local filename="$1"
    local expected_checksum="$2"
    local filepath="$IMAGES_DIR/$filename"
    
    if [[ -z "$expected_checksum" ]]; then
        print_warning "No checksum provided for $filename - skipping verification"
        return 0
    fi
    
    print_status "Verifying $filename..."
    
    local actual_checksum
    actual_checksum=$(shasum -a 256 "$filepath" | cut -d' ' -f1)
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        print_status "$filename verified successfully"
        return 0
    else
        print_error "$filename verification failed!"
        print_error "Expected: $expected_checksum"
        print_error "Actual:   $actual_checksum"
        return 1
    fi
}

# Main function
main() {
    print_status "Pi 5 OS Image Downloader"
    print_status "========================"
    
    # Create images directory if it doesn't exist
    mkdir -p "$IMAGES_DIR"
    
    # Check for required tools
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v shasum &> /dev/null; then
        print_error "shasum is required but not installed. Please install it first."
        exit 1
    fi
    
    # Copy existing images from home directory if they exist
    if [[ -d "$HOME/images4rpi" ]]; then
        print_status "Copying existing images from ~/images4rpi..."
        cp -n "$HOME/images4rpi"/*.img.xz "$IMAGES_DIR/" 2>/dev/null || true
    fi
    
    print_status "Image download locations:"
    echo "  - Home Assistant OS: https://github.com/home-assistant/operating-system/releases"
    echo "  - Ubuntu Server: https://ubuntu.com/download/raspberry-pi"
    echo ""
    print_warning "Automatic downloads not yet implemented."
    print_warning "Please manually download the following files to $IMAGES_DIR:"
    echo ""
    echo "Home Assistant OS:"
    echo "  - haos_rpi5-64-16.0.img.xz (or latest version)"
    echo "  - Download from: https://github.com/home-assistant/operating-system/releases"
    echo ""
    echo "Ubuntu Server:"
    echo "  - ubuntu-25.04-preinstalled-server-arm64+raspi.img.xz (or latest version)"
    echo "  - Download from: https://ubuntu.com/download/raspberry-pi"
    echo ""
    
    # TODO: Implement automatic downloads
    # This would require:
    # 1. Parsing GitHub API for latest Home Assistant OS releases
    # 2. Parsing Ubuntu's download page for latest image URLs
    # 3. Handling version selection and checksums
    
    # For now, just show what's already available
    print_status "Currently available images:"
    if [[ -n "$(ls -A "$IMAGES_DIR"/*.img.xz 2>/dev/null)" ]]; then
        ls -lh "$IMAGES_DIR"/*.img.xz
    else
        print_warning "No images found in $IMAGES_DIR"
    fi
    
    print_status "Download script completed."
}

# Run main function
main "$@"
