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
WORK_DIR="$PROJECT_DIR/pi5_installer_work"
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
# Args: <media_root> <tailscale_key_content> <wifi_ssid> <wifi_password>

set -euo pipefail

MEDIA_ROOT="$1"
TAILSCALE_KEY_CONTENT="$2"
WIFI_SSID="$3"
WIFI_PASSWORD="$4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[HAOS-SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[HAOS-SETUP]${NC} $1"
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

# Create additional data partition for user data if space available
print_status "Checking for additional disk space..."
DISK_SIZE=$(parted /dev/nvme0n1 unit MB print | grep "Disk /dev/nvme0n1:" | awk '{print $3}' | sed 's/MB//')
LAST_PARTITION_END=$(parted /dev/nvme0n1 unit MB print | tail -n 1 | awk '{print $3}' | sed 's/MB//')

# Reserve 20% or minimum 4GB for future OS versions, whichever is larger
RESERVED_MB=$((DISK_SIZE / 5))  # 20% of disk
if (( RESERVED_MB < 4096 )); then
    RESERVED_MB=4096  # Minimum 4GB
fi

AVAILABLE_MB=$((DISK_SIZE - LAST_PARTITION_END - RESERVED_MB))

if (( AVAILABLE_MB > 1024 )); then  # Only create if >1GB available
    print_status "Creating additional data partition for Home Assistant..."
    print_status "Reserving ${RESERVED_MB}MB for future OS versions"
    
    # Calculate end position (leave reserved space at end)
    END_POSITION=$((DISK_SIZE - RESERVED_MB))
    
    # Get next available partition number
    NEXT_PARTITION=$(parted /dev/nvme0n1 print | grep "^ " | tail -n 1 | awk '{print $1+1}')
    
    # Create new partition using available space (not all remaining space)
    parted /dev/nvme0n1 mkpart primary ext4 "${LAST_PARTITION_END}MB" "${END_POSITION}MB" 2>/dev/null || true
    
    # Wait for partition to be created
    sleep 2
    partprobe /dev/nvme0n1 || true
    sleep 2
    
    # Format the new partition
    NEW_PARTITION="/dev/nvme0n1p${NEXT_PARTITION}"
    if [[ -b "$NEW_PARTITION" ]]; then
        print_status "Formatting new data partition $NEW_PARTITION..."
        mkfs.ext4 -F "$NEW_PARTITION" 2>/dev/null || true
        
        # Add label for easy identification
        e2label "$NEW_PARTITION" "HAOS_DATA" 2>/dev/null || true
        
        # Mount and set up the additional data partition
        EXTRA_DATA_MOUNT="/tmp/haos_extra_data"
        mkdir -p "$EXTRA_DATA_MOUNT"
        if mount "$NEW_PARTITION" "$EXTRA_DATA_MOUNT" 2>/dev/null; then
            print_status "Created additional data partition $NEW_PARTITION ($(( AVAILABLE_MB / 1024 ))GB) for future use"
            
            # Create a README file explaining the partition (only if it doesn't exist)
            if [[ ! -f "$EXTRA_DATA_MOUNT/README.txt" ]]; then
                cat > "$EXTRA_DATA_MOUNT/README.txt" << 'EOL'
This is an additional data partition created by the Pi 5 installer.

This partition survives OS reflashing and can be used for:
- Home Assistant backups
- Additional storage
- Custom configurations

The partition is labeled 'HAOS_DATA' and can be mounted manually if needed.
EOL
            else
                print_status "Data partition already has README.txt, preserving existing content"
            fi
            
            umount "$EXTRA_DATA_MOUNT" 2>/dev/null || true
        fi
        rmdir "$EXTRA_DATA_MOUNT" 2>/dev/null || true
    fi
else
    print_status "Insufficient space for additional data partition (need >1GB, have ${AVAILABLE_MB}MB)"
fi

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
print_status "Preparing addon directory structure..."

# Clear any existing Tailscale addon (in case of reflash)
if [[ -d "$DATA_MOUNT/addons/local/tailscale" ]]; then
    print_status "Removing existing Tailscale addon..."
    rm -rf "$DATA_MOUNT/addons/local/tailscale"
fi

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

# Configure WiFi and SSH
print_status "Configuring WiFi and SSH..."

# Create network configuration for Home Assistant OS
if [[ -n "$WIFI_SSID" && -n "$WIFI_PASSWORD" ]]; then
    print_status "Setting up WiFi network: $WIFI_SSID"
    
    # Create network configuration directory
    mkdir -p "$DATA_MOUNT/network"
    
    # Create network manager configuration file
    cat > "$DATA_MOUNT/network/my-network" << EOL
[connection]
id=my-network
uuid=$(uuidgen)
type=wifi

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$WIFI_PASSWORD

[ipv4]
method=auto

[ipv6]
addr-gen-mode=stable-privacy
method=auto
EOL
    
    print_status "WiFi configuration created"
else
    print_warning "WiFi credentials not provided, skipping WiFi setup"
fi

# Enable SSH by creating authorized_keys file
print_status "Enabling SSH access..."
mkdir -p "$DATA_MOUNT/ssh"
# Create a placeholder for SSH keys - users can add their keys here
cat > "$DATA_MOUNT/ssh/README.txt" << EOL
SSH is enabled for Home Assistant OS.

To add your SSH keys:
1. Place your public key in this directory as 'authorized_keys'
2. The key will be used for the 'root' user

Example:
echo "ssh-rsa AAAA... your-email@example.com" > authorized_keys

You can also access SSH through the Home Assistant web interface
under Supervisor > System > Host system.
EOL

print_status "SSH enabled - see $DATA_MOUNT/ssh/README.txt for instructions"

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
# Args: <media_root> <tailscale_key_content> <wifi_ssid> <wifi_password>

set -euo pipefail

MEDIA_ROOT="$1"    # Reserved for future use - installer media root
TAILSCALE_KEY_CONTENT="$2"
WIFI_SSID="$3"
WIFI_PASSWORD="$4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[UBUNTU-SETUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[UBUNTU-SETUP]${NC} $1"
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

# Create additional data partition for user data if space available
print_status "Checking for additional disk space..."
DISK_SIZE=$(parted /dev/nvme0n1 unit MB print | grep "Disk /dev/nvme0n1:" | awk '{print $3}' | sed 's/MB//')
LAST_PARTITION_END=$(parted /dev/nvme0n1 unit MB print | tail -n 1 | awk '{print $3}' | sed 's/MB//')

# Reserve 20% or minimum 4GB for future OS versions, whichever is larger
RESERVED_MB=$((DISK_SIZE / 5))  # 20% of disk
if (( RESERVED_MB < 4096 )); then
    RESERVED_MB=4096  # Minimum 4GB
fi

AVAILABLE_MB=$((DISK_SIZE - LAST_PARTITION_END - RESERVED_MB))

if (( AVAILABLE_MB > 1024 )); then  # Only create if >1GB available
    print_status "Creating additional data partition for Ubuntu..."
    print_status "Reserving ${RESERVED_MB}MB for future OS versions"
    
    # Calculate end position (leave reserved space at end)
    END_POSITION=$((DISK_SIZE - RESERVED_MB))
    
    # Get next available partition number
    NEXT_PARTITION=$(parted /dev/nvme0n1 print | grep "^ " | tail -n 1 | awk '{print $1+1}')
    
    # Create new partition using available space (not all remaining space)
    parted /dev/nvme0n1 mkpart primary ext4 "${LAST_PARTITION_END}MB" "${END_POSITION}MB" 2>/dev/null || true
    
    # Wait for partition to be created
    sleep 2
    partprobe /dev/nvme0n1 || true
    sleep 2
    
    # Format the new partition
    NEW_PARTITION="/dev/nvme0n1p${NEXT_PARTITION}"
    if [[ -b "$NEW_PARTITION" ]]; then
        print_status "Formatting new data partition $NEW_PARTITION..."
        mkfs.ext4 -F "$NEW_PARTITION" 2>/dev/null || true
        
        # Add label for easy identification
        e2label "$NEW_PARTITION" "UBUNTU_HOME" 2>/dev/null || true
        
        # Mount and set up the additional data partition as /home
        EXTRA_DATA_MOUNT="/tmp/ubuntu_extra_data"
        mkdir -p "$EXTRA_DATA_MOUNT"
        if mount "$NEW_PARTITION" "$EXTRA_DATA_MOUNT" 2>/dev/null; then
            print_status "Setting up additional data partition $NEW_PARTITION ($(( AVAILABLE_MB / 1024 ))GB) as /home..."
            
            # Check if this is a fresh partition or if it has existing data
            if [[ -z "$(ls -A "$EXTRA_DATA_MOUNT" 2>/dev/null)" ]]; then
                print_status "Fresh data partition - copying existing /home data..."
                # Copy existing /home if it exists
                if [[ -d "$ROOT_MOUNT/home" ]]; then
                    print_status "Copying existing /home data to data partition..."
                    cp -a "$ROOT_MOUNT/home"/* "$EXTRA_DATA_MOUNT/" 2>/dev/null || true
                fi
            else
                print_status "Data partition has existing content - preserving user data"
            fi
            
            # Create a README file explaining the partition (only if it doesn't exist)
            if [[ ! -f "$EXTRA_DATA_MOUNT/README.txt" ]]; then
                cat > "$EXTRA_DATA_MOUNT/README.txt" << 'EOL'
This is an additional /home partition created by the Pi 5 installer.

This partition survives OS reflashing and contains user data.
It is automatically mounted as /home via /etc/fstab.

The partition is labeled 'UBUNTU_HOME' and can be identified by this label.
EOL
            else
                print_status "Data partition already has README.txt, preserving existing content"
            fi
            
            # Add to fstab for automatic mounting (use LABEL for reliability)
            echo "LABEL=UBUNTU_HOME /home ext4 defaults 0 2" >> "$ROOT_MOUNT/etc/fstab"
            
            umount "$EXTRA_DATA_MOUNT" 2>/dev/null || true
            print_status "Created additional data partition mounted at /home"
        fi
        rmdir "$EXTRA_DATA_MOUNT" 2>/dev/null || true
    fi
else
    print_status "Insufficient space for additional data partition (need >1GB, have ${AVAILABLE_MB}MB)"
fi

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
# Remove any existing key (in case of reflash)
rm -f "$ROOT_MOUNT/etc/tailscale.key" 2>/dev/null || true
echo "$TAILSCALE_KEY_CONTENT" > "$ROOT_MOUNT/etc/tailscale.key"
chmod 600 "$ROOT_MOUNT/etc/tailscale.key"

# Copy Tailscale binary
print_status "Installing Tailscale binary..."
# Remove any existing binary (in case of reflash)
rm -f "$ROOT_MOUNT/usr/bin/tailscale" 2>/dev/null || true
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
# Remove any existing service (in case of reflash)
rm -f "$ROOT_MOUNT/etc/systemd/system/tailscale.service" 2>/dev/null || true

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

# Configure WiFi and SSH
print_status "Configuring WiFi and SSH..."

# Configure WiFi using netplan
if [[ -n "$WIFI_SSID" && -n "$WIFI_PASSWORD" ]]; then
    print_status "Setting up WiFi network: $WIFI_SSID"
    
    # Create netplan configuration for WiFi
    cat > "$ROOT_MOUNT/etc/netplan/50-wifi.yaml" << EOL
network:
  version: 2
  renderer: networkd
  wifis:
    wlan0:
      dhcp4: true
      dhcp6: true
      access-points:
        "$WIFI_SSID":
          password: "$WIFI_PASSWORD"
EOL
    
    # Set proper permissions
    chmod 600 "$ROOT_MOUNT/etc/netplan/50-wifi.yaml"
    
    print_status "WiFi configuration created"
else
    print_warning "WiFi credentials not provided, skipping WiFi setup"
fi

# Enable SSH
print_status "Enabling SSH service..."
chroot "$ROOT_MOUNT" systemctl enable ssh.service

# Create default ubuntu user if it doesn't exist
if ! chroot "$ROOT_MOUNT" id ubuntu &>/dev/null; then
    print_status "Creating ubuntu user..."
    chroot "$ROOT_MOUNT" useradd -m -G sudo -s /bin/bash ubuntu
    # Set up SSH directory for ubuntu user
    mkdir -p "$ROOT_MOUNT/home/ubuntu/.ssh"
    chmod 700 "$ROOT_MOUNT/home/ubuntu/.ssh"
    chroot "$ROOT_MOUNT" chown ubuntu:ubuntu /home/ubuntu/.ssh
fi

# Create instructions for SSH access
cat > "$ROOT_MOUNT/home/ubuntu/SSH_README.txt" << EOL
SSH is enabled for Ubuntu Server.

To add your SSH keys for the ubuntu user:
1. Place your public key in ~/.ssh/authorized_keys
2. Set proper permissions: chmod 600 ~/.ssh/authorized_keys

Example:
echo "ssh-rsa AAAA... your-email@example.com" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

You can also set a password for the ubuntu user:
sudo passwd ubuntu

The ubuntu user has sudo privileges.
EOL

chroot "$ROOT_MOUNT" chown ubuntu:ubuntu /home/ubuntu/SSH_README.txt

print_status "SSH enabled - see /home/ubuntu/SSH_README.txt for instructions"

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
        local filename
        local basename
        local os_type
        
        filename="$(basename "$image_file")"
        basename="${filename%.img.xz}"
        os_type="$(detect_os_type "$filename")"
        
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
