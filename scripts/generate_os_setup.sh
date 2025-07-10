#!/bin/bash

# generate_os_setup.sh
# Scans for OS images and generates OS-specific setup scripts

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
WORK_DIR="$HOME/pi5_installer_work"
OS_SETUPS_DIR="$WORK_DIR/os-setups"

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

# Function to detect OS type from filename
detect_os_type() {
    local filename="$1"
    local basename="${filename%.img.xz}"
    
    if [[ "$basename" == haos_* ]]; then
        echo "haos"
    elif [[ "$basename" == ubuntu-* ]]; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

# Function to generate HAOS setup script
generate_haos_setup() {
    local basename="$1"
    local setup_file="$OS_SETUPS_DIR/setup_${basename}.sh"
    
    print_status "Generating HAOS setup script: $setup_file"
    
    cat > "$setup_file" << 'EOF'
#!/bin/bash

# Auto-generated HAOS setup script
# Args: <media_root> <tailscale_key_content>

set -euo pipefail

MEDIA_ROOT="$1"
TAILSCALE_KEY_CONTENT="$2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[HAOS-SETUP]${NC} $1"
}

print_error() {
    echo -e "${RED}[HAOS-SETUP]${NC} $1" >&2
}

print_status "Starting Home Assistant OS setup..."

# Mount points
BOOT_MOUNT="/tmp/haos_boot"
DATA_MOUNT="/tmp/haos_data"

# Create mount points
mkdir -p "$BOOT_MOUNT" "$DATA_MOUNT"

# Function to cleanup on exit
cleanup() {
    print_status "Cleaning up mount points..."
    umount "$BOOT_MOUNT" 2>/dev/null || true
    umount "$DATA_MOUNT" 2>/dev/null || true
    rmdir "$BOOT_MOUNT" "$DATA_MOUNT" 2>/dev/null || true
}

trap cleanup EXIT

# Mount the flashed partitions
print_status "Mounting HAOS partitions..."
if ! mount /dev/nvme0n1p1 "$BOOT_MOUNT"; then
    print_error "Failed to mount HAOS boot partition"
    exit 1
fi

if ! mount /dev/nvme0n1p8 "$DATA_MOUNT"; then
    print_error "Failed to mount HAOS data partition"
    exit 1
fi

# Create addon directory structure
ADDON_DIR="$DATA_MOUNT/addons/local/tailscale"
mkdir -p "$ADDON_DIR"

# Copy Tailscale addon files
print_status "Installing Tailscale addon..."
if [[ -d "$MEDIA_ROOT/haos-tailscale-addon" ]]; then
    cp -r "$MEDIA_ROOT/haos-tailscale-addon"/* "$ADDON_DIR/"
    
    # Create options.json with the auth key
    cat > "$ADDON_DIR/options.json" << EOL
{
  "auth_key": "$TAILSCALE_KEY_CONTENT"
}
EOL
    
    chmod 600 "$ADDON_DIR/options.json"
    print_status "Tailscale addon installed successfully"
else
    print_error "Tailscale addon source not found at $MEDIA_ROOT/haos-tailscale-addon"
    exit 1
fi

print_status "Home Assistant OS setup completed successfully"
EOF

    chmod +x "$setup_file"
}

# Function to generate Ubuntu setup script
generate_ubuntu_setup() {
    local basename="$1"
    local setup_file="$OS_SETUPS_DIR/setup_${basename}.sh"
    
    print_status "Generating Ubuntu setup script: $setup_file"
    
    cat > "$setup_file" << 'EOF'
#!/bin/bash

# Auto-generated Ubuntu setup script
# Args: <media_root> <tailscale_key_content>

set -euo pipefail

MEDIA_ROOT="$1"
TAILSCALE_KEY_CONTENT="$2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[UBUNTU-SETUP]${NC} $1"
}

print_error() {
    echo -e "${RED}[UBUNTU-SETUP]${NC} $1" >&2
}

print_status "Starting Ubuntu Server setup..."

# Mount points
BOOT_MOUNT="/tmp/ubuntu_boot"
ROOT_MOUNT="/tmp/ubuntu_root"

# Create mount points
mkdir -p "$BOOT_MOUNT" "$ROOT_MOUNT"

# Function to cleanup on exit
cleanup() {
    print_status "Cleaning up mount points..."
    umount "$ROOT_MOUNT" 2>/dev/null || true
    umount "$BOOT_MOUNT" 2>/dev/null || true
    rmdir "$BOOT_MOUNT" "$ROOT_MOUNT" 2>/dev/null || true
}

trap cleanup EXIT

# Mount the flashed partitions
print_status "Mounting Ubuntu partitions..."
if ! mount /dev/nvme0n1p1 "$BOOT_MOUNT"; then
    print_error "Failed to mount Ubuntu boot partition"
    exit 1
fi

if ! mount /dev/nvme0n1p2 "$ROOT_MOUNT"; then
    print_error "Failed to mount Ubuntu root partition"
    exit 1
fi

# Install Tailscale key
print_status "Installing Tailscale key..."
echo "$TAILSCALE_KEY_CONTENT" > "$ROOT_MOUNT/etc/tailscale.key"
chmod 600 "$ROOT_MOUNT/etc/tailscale.key"

# Copy Tailscale binary
print_status "Installing Tailscale binary..."
TAILSCALE_PATH=""
if [[ -f "/usr/local/bin/tailscale" ]]; then
    TAILSCALE_PATH="/usr/local/bin/tailscale"
elif [[ -f "/opt/homebrew/bin/tailscale" ]]; then
    TAILSCALE_PATH="/opt/homebrew/bin/tailscale"
else
    print_error "Tailscale binary not found"
    exit 1
fi

cp "$TAILSCALE_PATH" "$ROOT_MOUNT/usr/bin/tailscale"
chmod +x "$ROOT_MOUNT/usr/bin/tailscale"

# Create systemd service
print_status "Creating Tailscale systemd service..."
cat > "$ROOT_MOUNT/etc/systemd/system/tailscale.service" << 'EOL'
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
EnvironmentFile=/etc/default/tailscaled
ExecStartPre=/usr/bin/tailscale up --auth-key-file=/etc/tailscale.key
ExecStart=/usr/bin/tailscale up --auth-key-file=/etc/tailscale.key
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Enable the service
print_status "Enabling Tailscale service..."
chroot "$ROOT_MOUNT" systemctl enable tailscale.service

print_status "Ubuntu Server setup completed successfully"
EOF

    chmod +x "$setup_file"
}

# Function to generate unknown OS setup script
generate_unknown_setup() {
    local basename="$1"
    local setup_file="$OS_SETUPS_DIR/setup_${basename}.sh"
    
    print_status "Generating generic setup script: $setup_file"
    
    cat > "$setup_file" << 'EOF'
#!/bin/bash

# Auto-generated generic setup script
# Args: <media_root> <tailscale_key_content>

set -euo pipefail

MEDIA_ROOT="$1"
TAILSCALE_KEY_CONTENT="$2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[GENERIC-SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[GENERIC-SETUP]${NC} $1"
}

print_error() {
    echo -e "${RED}[GENERIC-SETUP]${NC} $1" >&2
}

print_warning "Unknown OS type detected - no specific setup will be performed"
print_status "Tailscale key is available for manual configuration"
print_status "Generic setup completed"
EOF

    chmod +x "$setup_file"
}

# Main function
main() {
    print_status "Pi 5 OS Setup Generator"
    print_status "======================="
    
    # Create work directory and os-setups subdirectory
    mkdir -p "$OS_SETUPS_DIR"
    
    # Check if images directory exists
    if [[ ! -d "$IMAGES_DIR" ]]; then
        print_error "Images directory not found: $IMAGES_DIR"
        print_error "Please create the directory and add *.img.xz files"
        exit 1
    fi
    
    # Find all *.img.xz files
    local image_files=()
    while IFS= read -r -d '' file; do
        image_files+=("$file")
    done < <(find "$IMAGES_DIR" -name "*.img.xz" -type f -print0)
    
    if [[ ${#image_files[@]} -eq 0 ]]; then
        print_error "No *.img.xz files found in $IMAGES_DIR"
        print_error "Please add OS images to the directory"
        exit 1
    fi
    
    print_status "Found ${#image_files[@]} OS image(s)"
    
    # Process each image file
    for image_file in "${image_files[@]}"; do
        local filename="$(basename "$image_file")"
        local basename="${filename%.img.xz}"
        local os_type="$(detect_os_type "$filename")"
        
        print_status "Processing $filename (detected as: $os_type)"
        
        case "$os_type" in
            "haos")
                generate_haos_setup "$basename"
                ;;
            "ubuntu")
                generate_ubuntu_setup "$basename"
                ;;
            *)
                print_warning "Unknown OS type for $filename"
                generate_unknown_setup "$basename"
                ;;
        esac
    done
    
    print_status "Generated setup scripts in: $OS_SETUPS_DIR"
    print_status "Setup script generation completed successfully"
}

# Run main function
main "$@"
