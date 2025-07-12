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

# Function to get latest Home Assistant OS release for RPi5
get_latest_haos_release() {
    local api_url="https://api.github.com/repos/home-assistant/operating-system/releases/latest"
    
    print_status "Fetching latest Home Assistant OS release..." >&2
    
    local release_data
    if ! release_data=$(curl -s "$api_url"); then
        print_error "Failed to fetch Home Assistant OS release information" >&2
        print_error "Falling back to known version..." >&2
        # Fallback to a known working version
        printf "https://github.com/home-assistant/operating-system/releases/download/16.0/haos_rpi5-64-16.0.img.xz|haos_rpi5-64-16.0.img.xz"
        return 0
    fi
    
    # Check if release_data is valid JSON and not empty
    if ! echo "$release_data" | jq -e . > /dev/null 2>&1; then
        print_error "Invalid JSON response from GitHub API" >&2
        print_error "Response: $release_data" >&2
        print_error "Falling back to known version..." >&2
        # Fallback to a known working version
        printf "https://github.com/home-assistant/operating-system/releases/download/16.0/haos_rpi5-64-16.0.img.xz|haos_rpi5-64-16.0.img.xz"
        return 0
    fi
    
    # Check if assets array exists and is not empty
    local assets_count
    assets_count=$(echo "$release_data" | jq '.assets | length // 0')
    if [[ "$assets_count" -eq 0 ]]; then
        print_error "No assets found in latest release" >&2
        print_error "Falling back to known version..." >&2
        # Fallback to a known working version
        printf "https://github.com/home-assistant/operating-system/releases/download/16.0/haos_rpi5-64-16.0.img.xz|haos_rpi5-64-16.0.img.xz"
        return 0
    fi
    
    local download_url
    download_url=$(echo "$release_data" | jq -r '.assets[] | select(.name | test("haos_rpi5-64-.*\\.img\\.xz$")) | .browser_download_url')
    
    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        print_error "Could not find RPi5 image in latest release" >&2
        print_error "Available assets:" >&2
        echo "$release_data" | jq -r '.assets[].name' >&2
        print_error "Falling back to known version..." >&2
        # Fallback to a known working version
        printf "https://github.com/home-assistant/operating-system/releases/download/16.0/haos_rpi5-64-16.0.img.xz|haos_rpi5-64-16.0.img.xz"
        return 0
    fi
    
    local filename
    filename=$(basename "$download_url")
    
    printf "%s|%s" "$download_url" "$filename"
}

# Function to get latest Ubuntu Server release for RPi
get_latest_ubuntu_release() {
    # Ubuntu releases follow a predictable pattern for current/latest versions
    local ubuntu_base_url="https://cdimage.ubuntu.com/releases/25.04/release"
    local filename_pattern="ubuntu-25.04-preinstalled-server-arm64+raspi.img.xz"
    
    print_status "Checking for Ubuntu Server 25.04 release..." >&2
    
    # Check if the file exists at the expected URL
    local download_url="$ubuntu_base_url/$filename_pattern"
    
    # Test if URL is accessible
    if curl -s --head "$download_url" | head -n 1 | grep -q "200 OK"; then
        printf "%s|%s" "$download_url" "$filename_pattern"
        return 0
    else
        print_warning "Ubuntu 25.04 not found, trying 24.04 LTS..." >&2
        # Fallback to 24.04 LTS
        local lts_url="https://cdimage.ubuntu.com/releases/24.04/release"
        local lts_filename="ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz"
        local lts_download_url="$lts_url/$lts_filename"
        
        if curl -s --head "$lts_download_url" | head -n 1 | grep -q "200 OK"; then
            printf "%s|%s" "$lts_download_url" "$lts_filename"
            return 0
        else
            print_error "Could not find Ubuntu Server image" >&2
            return 1
        fi
    fi
}

# Function to download Home Assistant OS
download_haos() {
    local release_info
    if ! release_info=$(get_latest_haos_release); then
        print_error "Failed to get Home Assistant OS release information"
        return 1
    fi
    
    local download_url
    local filename
    IFS='|' read -r download_url filename <<< "$release_info"
    
    if [[ -z "$download_url" || -z "$filename" ]]; then
        print_error "Failed to parse Home Assistant OS release information"
        print_error "Release info: $release_info"
        return 1
    fi
    
    print_status "Found Home Assistant OS: $filename"
    
    if download_file "$download_url" "$filename"; then
        print_status "Home Assistant OS downloaded successfully"
        return 0
    else
        return 1
    fi
}

# Function to download Ubuntu Server
download_ubuntu() {
    local release_info
    if ! release_info=$(get_latest_ubuntu_release); then
        print_error "Failed to get Ubuntu Server release information"
        return 1
    fi
    
    local download_url
    local filename
    IFS='|' read -r download_url filename <<< "$release_info"
    
    if [[ -z "$download_url" || -z "$filename" ]]; then
        print_error "Failed to parse Ubuntu Server release information"
        print_error "Release info: $release_info"
        return 1
    fi
    
    print_status "Found Ubuntu Server: $filename"
    
    if download_file "$download_url" "$filename"; then
        print_status "Ubuntu Server downloaded successfully"
        return 0
    else
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
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install it first."
        print_error "Install with: brew install jq"
        exit 1
    fi
    
    print_status "Available download options:"
    echo "  - Home Assistant OS: https://github.com/home-assistant/operating-system/releases"
    echo "  - Ubuntu Server: https://ubuntu.com/download/raspberry-pi"
    echo ""
    
    # Parse command line arguments
    local download_haos=false
    local download_ubuntu=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --haos)
                download_haos=true
                shift
                ;;
            --ubuntu)
                download_ubuntu=true
                shift
                ;;
            --all)
                download_haos=true
                download_ubuntu=true
                shift
                ;;
            --auto)
                download_haos=true
                download_ubuntu=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Usage: $0 [--haos] [--ubuntu] [--all] [--auto]"
                echo "  --haos    Download Home Assistant OS only"
                echo "  --ubuntu  Download Ubuntu Server only"
                echo "  --all     Download both images"
                echo "  --auto    Download both images automatically (no prompts)"
                exit 1
                ;;
        esac
    done
    
    # If no specific downloads requested, show manual instructions
    if [[ "$download_haos" == false && "$download_ubuntu" == false ]]; then
        print_warning "No automatic downloads requested."
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
        echo "Or run with options:"
        echo "  $0 --haos      # Download Home Assistant OS only"
        echo "  $0 --ubuntu    # Download Ubuntu Server only"
        echo "  $0 --all       # Download both images"
        echo "  $0 --auto      # Download both images automatically"
    else
        # Perform automatic downloads
        local download_success=true
        
        if [[ "$download_haos" == true ]]; then
            if ! download_haos; then
                download_success=false
            fi
        fi
        
        if [[ "$download_ubuntu" == true ]]; then
            if ! download_ubuntu; then
                download_success=false
            fi
        fi
        
        if [[ "$download_success" == false ]]; then
            print_error "Some downloads failed. Please check the errors above."
            exit 1
        fi
    fi
    
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
