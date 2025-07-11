#!/bin/bash

# setup_pi5_installer.sh
# Main Pi 5 installer script

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
WORK_DIR="$PROJECT_DIR/pi5_installer_work"
DIST_DIR="$PROJECT_DIR/dist"
OS_SETUPS_DIR="$WORK_DIR/os-setups"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1" >&2
}

# Function to prompt user directly to terminal
prompt_user() {
    if [[ -t 0 ]]; then
        echo "$1" > /dev/tty
    else
        echo "$1" >&2
    fi
}

# Function to read user input directly from terminal
read_user_input() {
    local prompt="$1"
    local var_name="$2"
    if [[ -t 0 ]]; then
        echo -n "$prompt" > /dev/tty
        read -r "$var_name" < /dev/tty
    else
        echo -n "$prompt" >&2
        read -r "$var_name" <&0
    fi
}

# Function to check and install required tools
check_dependencies() {
    print_step "Checking dependencies..."
    
    local missing_tools=()
    
    # Check for required tools
    for tool in git xz cpio; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # Check for Tailscale binary
    local tailscale_path=""
    if [[ -f "/usr/local/bin/tailscale" ]]; then
        tailscale_path="/usr/local/bin/tailscale"
    elif [[ -f "/opt/homebrew/bin/tailscale" ]]; then
        tailscale_path="/opt/homebrew/bin/tailscale"
    else
        print_error "Tailscale binary not found"
        print_error "Please install Tailscale: brew install tailscale"
        exit 1
    fi
    
    print_status "Found Tailscale at: $tailscale_path"
    
    # Install missing tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warning "Missing tools: ${missing_tools[*]}"
        print_status "Installing missing tools with Homebrew..."
        
        if ! command -v brew &> /dev/null; then
            print_error "Homebrew is required but not installed"
            print_error "Please install Homebrew: https://brew.sh/"
            exit 1
        fi
        
        brew install "${missing_tools[@]}"
    fi
    
    print_status "All dependencies satisfied"
}

# Function to detect external disk
detect_external_disk() {
    print_step "Detecting external disk..."
    
    # Get list of external disks
    local external_disks=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^/dev/disk[0-9]+$ ]]; then
            # Check if it's external and physical
            local disk_info
            disk_info=$(diskutil info "$line" 2>/dev/null || echo "")
            
            # Check if it's an external disk (USB, Thunderbolt, etc.)
            if [[ "$disk_info" =~ Device\ Location.*External ]]; then
                external_disks+=("$line")
            fi
        fi
    done < <(diskutil list | grep "^/dev/disk" | cut -d' ' -f1)
    
    # Check result
    if [[ ${#external_disks[@]} -eq 0 ]]; then
        print_error "No external disks found"
        print_error "Please connect an external USB/M.2 disk"
        exit 1
    elif [[ ${#external_disks[@]} -gt 1 ]]; then
        print_error "Multiple external disks found: ${external_disks[*]}"
        print_error "Please connect only one external disk"
        exit 1
    fi
    
    local disk="${external_disks[0]}"
    print_status "Found external disk: $disk"
    
    # Find the first FAT32 partition
    local fat32_partition=""
    while IFS= read -r partition; do
        if [[ -n "$partition" ]]; then
            local partition_info
            partition_info=$(diskutil info "/dev/$partition" 2>/dev/null || echo "")
            
            if [[ "$partition_info" =~ File\ System\ Personality.*FAT32 ]]; then
                fat32_partition="/dev/$partition"
                break
            fi
        fi
    done < <(diskutil list "$disk" | grep "^   [0-9]" | awk '{print $NF}')
    
    if [[ -z "$fat32_partition" ]]; then
        print_error "No FAT32 partition found on $disk"
        print_error "Please format the disk with a FAT32 partition"
        exit 1
    fi
    
    print_status "Found FAT32 partition: $fat32_partition"
    # Return the partition path - this goes to stdout, status messages go to stderr
    echo "$fat32_partition"
}

# Function to mount installer partition
mount_installer_partition() {
    local partition="$1"
    local mount_point="/tmp/pi5_installer"
    
    print_step "Mounting installer partition..."
    
    # Create mount point
    mkdir -p "$mount_point"
    
    # Unmount if already mounted
    diskutil unmount "$partition" 2>/dev/null || true
    
    # Wait a moment for the unmount to complete
    sleep 1
    
    # Mount the partition
    if ! diskutil mount -mountPoint "$mount_point" "$partition"; then
        print_error "Failed to mount $partition"
        print_error "Please check if the device is accessible and try again"
        exit 1
    fi
    
    print_status "Mounted $partition at $mount_point"
    # Return the mount point
    echo "$mount_point"
}

# Function to select OS image
select_os_image() {
    print_step "Selecting OS image..."
    
    # Check if images directory exists
    if [[ ! -d "$IMAGES_DIR" ]]; then
        print_error "Images directory not found: $IMAGES_DIR"
        exit 1
    fi
    
    # Find all *.img.xz files
    local image_files=()
    while IFS= read -r -d '' file; do
        image_files+=("$file")
    done < <(find "$IMAGES_DIR" -name "*.img.xz" -type f -print0 2>/dev/null)
    
    if [[ ${#image_files[@]} -eq 0 ]]; then
        print_error "No *.img.xz files found in $IMAGES_DIR"
        print_error "Please add OS images to the directory"
        exit 1
    fi
    
    # If only one image, use it
    if [[ ${#image_files[@]} -eq 1 ]]; then
        local selected_image="${image_files[0]}"
        print_status "Using single available image: $(basename "$selected_image")"
        echo "$selected_image"
        return
    fi
    
    # Multiple images - prompt user
    prompt_user "Available OS images:"
    for i in "${!image_files[@]}"; do
        prompt_user "  $((i+1)). $(basename "${image_files[$i]}")"
    done
    
    read_user_input "Select image (1-${#image_files[@]}): " selection
    
    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#image_files[@]} ]]; then
        print_error "Invalid selection: $selection"
        exit 1
    fi
    
    local selected_image="${image_files[$((selection-1))]}"
    print_status "Selected image: $(basename "$selected_image")"
    echo "$selected_image"
}

# Function to handle Tailscale key
handle_tailscale_key() {
    print_step "Handling Tailscale key..."
    
    local key_file="$WORK_DIR/tailscale.key"
    
    # Check if key file exists
    if [[ -f "$key_file" ]]; then
        print_status "Using existing Tailscale key file"
        echo "$key_file"
        return
    fi
    
    # Prompt for key
    print_status "Tailscale key not found. Please enter your auth key:"
    if [[ -t 0 ]]; then
        echo -n "Auth key: " > /dev/tty
        read -r -s auth_key < /dev/tty
        echo > /dev/tty
    else
        echo -n "Auth key: " >&2
        read -r -s auth_key <&0
        echo >&2
    fi
    
    if [[ -z "$auth_key" ]]; then
        print_error "Auth key cannot be empty"
        exit 1
    fi
    
    # Save key securely
    mkdir -p "$WORK_DIR"
    echo "$auth_key" > "$key_file"
    chmod 600 "$key_file"
    
    print_status "Tailscale key saved securely"
    echo "$key_file"
}

# Function to setup bootloader
setup_bootloader() {
    local dist_dir="$1"
    
    print_step "Setting up bootloader..."
    
    local firmware_dir="$WORK_DIR/firmware"
    
    # Clone firmware if not exists
    if [[ ! -d "$firmware_dir" ]]; then
        print_status "Cloning Raspberry Pi firmware..."
        git clone --depth 1 https://github.com/raspberrypi/firmware.git "$firmware_dir"
    fi
    
    # Copy boot files to dist directory
    print_status "Copying boot files to dist directory..."
    cp -r "$firmware_dir/boot"/* "$dist_dir/"
    
    # Create Pi 5 specific config.txt
    print_status "Creating config.txt..."
    cat > "$dist_dir/config.txt" << 'EOF'
# Pi 5 Installer Configuration
dtparam=pciex1
dtoverlay=rpi-poe
kernel=kernel8.img
initramfs initramfs.img followkernel
EOF
    
    # Create cmdline.txt
    print_status "Creating cmdline.txt..."
    cat > "$dist_dir/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/ram0 init=/sbin/init earlyprintk
EOF
    
    print_status "Bootloader setup completed"
}

# Function to build initramfs
build_initramfs() {
    print_step "Building initramfs..."
    
    local initramfs_file="$WORK_DIR/initramfs.img"
    
    # If initramfs already exists, use it
    if [[ -f "$initramfs_file" ]]; then
        print_status "Using existing initramfs.img"
        echo "$initramfs_file"
        return
    fi
    
    print_status "Building new initramfs..."
    
    local rootfs_dir="$WORK_DIR/rootfs"
    
    # Create rootfs directory structure
    mkdir -p "$rootfs_dir"/{bin,sbin,usr/bin,usr/sbin,proc,sys,dev,tmp,media,etc,lib}
    
    # Download pre-built BusyBox for ARM64
    print_status "Downloading pre-built BusyBox for ARM64..."
    local busybox_url="https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"
    if ! curl -L "$busybox_url" -o "$rootfs_dir/bin/busybox"; then
        print_error "Failed to download BusyBox binary"
        print_warning "Trying to create a minimal initramfs without BusyBox..."
        
        # Create minimal shell script as fallback
        cat > "$rootfs_dir/bin/sh" << 'EOF'
#!/bin/sh
# Minimal shell fallback
exec /bin/busybox sh "$@"
EOF
        chmod +x "$rootfs_dir/bin/sh"
        
        # Create a basic busybox stub
        cat > "$rootfs_dir/bin/busybox" << 'EOF'
#!/bin/sh
# BusyBox stub - basic commands only
case "$1" in
    sh) exec /bin/sh ;;
    mount) exec /bin/mount "$@" ;;
    umount) exec /bin/umount "$@" ;;
    *) echo "BusyBox command not available: $1" ;;
esac
EOF
        chmod +x "$rootfs_dir/bin/busybox"
    else
        chmod +x "$rootfs_dir/bin/busybox"
        
        # Create symlinks for common commands
        cd "$rootfs_dir"
        for cmd in sh mount umount mkdir rmdir ls cat cp mv rm ln chmod chown sync sleep echo; do
            ln -sf /bin/busybox "bin/$cmd"
        done
    fi
    
    # Copy additional binaries
    print_status "Adding additional binaries..."
    local tailscale_path=""
    if [[ -f "/usr/local/bin/tailscale" ]]; then
        tailscale_path="/usr/local/bin/tailscale"
    elif [[ -f "/opt/homebrew/bin/tailscale" ]]; then
        tailscale_path="/opt/homebrew/bin/tailscale"
    else
        print_warning "Tailscale binary not found, skipping..."
    fi
    
    if [[ -n "$tailscale_path" ]]; then
        cp "$tailscale_path" "$rootfs_dir/usr/bin/" || print_warning "Failed to copy Tailscale binary"
    fi
    
    # Copy xz if available
    if command -v xz &> /dev/null; then
        cp "$(which xz)" "$rootfs_dir/bin/" || print_warning "Failed to copy xz binary"
    fi
    
    # Create init script
    print_status "Creating init script..."
    cat > "$rootfs_dir/sbin/init" << 'EOF'
#!/bin/sh

# Pi 5 Installer Init Script
set -e

echo "Pi 5 Installer starting..."

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Create device nodes
mknod /dev/null c 1 3
mknod /dev/zero c 1 5
mknod /dev/console c 5 1

# Wait for devices
sleep 2

# Mount installer media
MEDIA_MOUNT="/media"
mkdir -p "$MEDIA_MOUNT"

# Try different device paths
for device in /dev/mmcblk0p1 /dev/sda1; do
    if [ -b "$device" ]; then
        echo "Mounting installer media from $device..."
        mount -t vfat "$device" "$MEDIA_MOUNT"
        break
    fi
done

if ! mountpoint -q "$MEDIA_MOUNT"; then
    echo "ERROR: Could not mount installer media"
    /bin/sh
    exit 1
fi

# Find OS image
OS_IMAGE=""
for img in "$MEDIA_MOUNT"/*.img.xz; do
    if [ -f "$img" ]; then
        OS_IMAGE="$img"
        break
    fi
done

if [ -z "$OS_IMAGE" ]; then
    echo "ERROR: No OS image found on installer media"
    /bin/sh
    exit 1
fi

echo "Found OS image: $(basename "$OS_IMAGE")"

# Flash to NVMe
TARGET_DEVICE="/dev/nvme0n1"
if [ ! -b "$TARGET_DEVICE" ]; then
    echo "ERROR: Target device $TARGET_DEVICE not found"
    /bin/sh
    exit 1
fi

echo "Flashing OS image to $TARGET_DEVICE..."
xz -dc "$OS_IMAGE" | dd of="$TARGET_DEVICE" bs=4M status=progress

# Sync and wait
sync
sleep 2

# Probe partitions
echo "Probing partitions..."
partprobe "$TARGET_DEVICE" || true
sleep 2

# Detect OS type and run setup
OS_NAME="$(basename "$OS_IMAGE" .img.xz)"
SETUP_SCRIPT="$MEDIA_MOUNT/os-setups/setup_${OS_NAME}.sh"

if [ -f "$SETUP_SCRIPT" ]; then
    echo "Running OS-specific setup..."
    TAILSCALE_KEY_CONTENT=""
    if [ -f "$MEDIA_MOUNT/tailscale.key" ]; then
        TAILSCALE_KEY_CONTENT="$(cat "$MEDIA_MOUNT/tailscale.key")"
    fi
    
    chmod +x "$SETUP_SCRIPT"
    "$SETUP_SCRIPT" "$MEDIA_MOUNT" "$TAILSCALE_KEY_CONTENT"
else
    echo "WARNING: No setup script found for $OS_NAME"
fi

# Cleanup
umount "$MEDIA_MOUNT"
sync

echo "Installation completed successfully!"
echo "Rebooting in 5 seconds..."
sleep 5
reboot -f
EOF
    
    chmod +x "$rootfs_dir/sbin/init"
    
    # Create other necessary directories
    mkdir -p "$rootfs_dir"/{proc,sys,dev,tmp,media}
    
    # Create initramfs
    print_status "Packing initramfs..."
    cd "$rootfs_dir"
    find . | cpio -H newc -o | gzip > "$initramfs_file"
    
    print_status "Initramfs built successfully"
    echo "$initramfs_file"
}

# Function to setup HAOS addon
setup_haos_addon() {
    local dist_dir="$1"
    local tailscale_key_content="$2"
    
    print_step "Setting up HAOS Tailscale addon..."
    
    local addon_dir="$dist_dir/haos-tailscale-addon"
    
    # Clone addon if not exists
    if [[ ! -d "$WORK_DIR/hass-addons" ]]; then
        print_status "Cloning Tailscale HAOS addon..."
        git clone --depth 1 https://github.com/tsujamin/hass-addons.git "$WORK_DIR/hass-addons"
    fi
    
    # Copy addon to dist directory
    cp -r "$WORK_DIR/hass-addons/tailscale" "$addon_dir"
    
    # Create options.json
    print_status "Creating addon options..."
    cat > "$addon_dir/options.json" << EOF
{
  "auth_key": "$tailscale_key_content"
}
EOF
    
    chmod 600 "$addon_dir/options.json"
    print_status "HAOS addon setup completed"
}

# Function to prepare installer files
prepare_installer_files() {
    local dist_dir="$1"
    local selected_image="$2"
    local tailscale_key_file="$3"
    local initramfs_file="$4"
    
    print_step "Preparing installer files..."
    
    # Create dist directory
    mkdir -p "$dist_dir"
    
    # Copy OS image
    print_status "Copying OS image to dist..."
    cp "$selected_image" "$dist_dir/"
    
    # Copy Tailscale key
    print_status "Copying Tailscale key to dist..."
    cp "$tailscale_key_file" "$dist_dir/"
    
    # Copy initramfs
    print_status "Copying initramfs to dist..."
    cp "$initramfs_file" "$dist_dir/"
    
    # Copy OS setup scripts
    print_status "Copying OS setup scripts to dist..."
    if [[ -d "$OS_SETUPS_DIR" ]]; then
        cp -r "$OS_SETUPS_DIR" "$dist_dir/"
    else
        print_warning "OS setup scripts directory not found: $OS_SETUPS_DIR"
        print_warning "This may be normal if no OS-specific setup scripts were generated"
    fi
    
    # Setup HAOS addon
    local tailscale_key_content
    tailscale_key_content=$(cat "$tailscale_key_file")
    setup_haos_addon "$dist_dir" "$tailscale_key_content"
    
    print_status "Installer files prepared in dist directory"
}

# Function to copy files to external drive
copy_to_external_drive() {
    local mount_point="$1"
    local partition="$2"
    local dist_dir="$3"
    
    print_step "Copying files to external drive..."
    
    # Check if mount point still exists and is mounted
    if [[ ! -d "$mount_point" ]]; then
        print_warning "Mount point $mount_point no longer exists, trying to find new mount point..."
        # Try to find where it's mounted now
        local new_mount_point
        new_mount_point=$(diskutil info "$partition" | grep "Mount Point" | awk '{print $3}')
        if [[ -n "$new_mount_point" && "$new_mount_point" != "Not" ]]; then
            print_status "Found new mount point: $new_mount_point"
            mount_point="$new_mount_point"
        else
            print_error "Could not find mount point for $partition"
            exit 1
        fi
    fi
    
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        print_warning "Mount point $mount_point is no longer mounted, attempting to remount..."
        # Try to remount
        if ! diskutil mount -mountPoint "$mount_point" "$partition" 2>/dev/null; then
            print_error "Failed to remount partition"
            exit 1
        fi
        print_status "Successfully remounted partition"
    fi
    
    # Clear existing files from installation media to ensure clean setup
    print_status "Clearing existing files from installation media..."
    rm -rf "$mount_point"/* 2>/dev/null || true
    rm -rf "$mount_point"/.* 2>/dev/null || true
    
    # Copy all files from dist to external drive
    print_status "Copying all files from dist to external drive..."
    if ! cp -r "$dist_dir"/* "$mount_point/"; then
        print_error "Failed to copy files to $mount_point"
        print_error "Please check if the device is still mounted and accessible"
        exit 1
    fi
    
    # Sync to ensure all data is written
    print_status "Syncing data to external drive..."
    sync
    
    print_status "Successfully copied all files to external drive"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Unmount installer partition
    local mount_point="/tmp/pi5_installer"
    if mountpoint -q "$mount_point" 2>/dev/null; then
        diskutil unmount "$mount_point" || true
    fi
    
    # Remove mount point
    rmdir "$mount_point" 2>/dev/null || true
}

# Main function
main() {
    print_status "Pi 5 Installer Setup"
    print_status "===================="
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Create work and dist directories
    mkdir -p "$WORK_DIR"
    mkdir -p "$DIST_DIR"
    
    # Clean work directory if it exists (except for cached firmware and addons)
    if [[ -d "$WORK_DIR" ]]; then
        print_status "Cleaning work directory..."
        # Preserve cached downloads, user-provided keys, and generated OS setup scripts
        find "$WORK_DIR" -name "initramfs.img" -delete 2>/dev/null || true
        rm -rf "$WORK_DIR/rootfs" 2>/dev/null || true
        # Note: Preserving os-setups directory as it contains generated setup scripts
    fi
    
    # Clean dist directory if it exists
    if [[ -d "$DIST_DIR" ]]; then
        print_status "Cleaning dist directory..."
        rm -rf "$DIST_DIR"/*
    fi
    
    # Check dependencies
    check_dependencies
    
    # Select OS image
    local selected_image
    selected_image=$(select_os_image)
    
    # Handle Tailscale key
    local tailscale_key_file
    tailscale_key_file=$(handle_tailscale_key)
    
    # Setup bootloader in dist directory
    setup_bootloader "$DIST_DIR"
    
    # Build initramfs
    local initramfs_file
    initramfs_file=$(build_initramfs)
    
    # Prepare all installer files in dist directory
    prepare_installer_files "$DIST_DIR" "$selected_image" "$tailscale_key_file" "$initramfs_file"
    
    # Now detect and mount external disk
    print_status "All files prepared locally. Now setting up external drive..."
    
    # Detect external disk
    local partition
    partition=$(detect_external_disk)
    
    # Mount installer partition
    local mount_point
    mount_point=$(mount_installer_partition "$partition")
    
    # Copy everything to external drive
    copy_to_external_drive "$mount_point" "$partition" "$DIST_DIR"
    
    print_status "Pi 5 installer setup completed successfully!"
    print_status "You can now unmount the device and use it to install on a Pi 5"
    print_warning "Remember to unmount the device properly before removing it"
}

# Run main function
main "$@"
