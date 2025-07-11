# Pi 5 Installer

A set of scripts for creating a Raspberry Pi 5 installer that automatically flashes OS images and configures Tailscale.

## Overview

This project provides two main scripts:

1. **`generate_os_setup.sh`** - Scans for OS images and generates OS-specific setup scripts
2. **`setup_pi5_installer.sh`** - Main installer script that creates a bootable installer media

## Prerequisites

- macOS with Homebrew
- Required tools: `git`, `xz`, `cpio` (install via `brew install git xz cpio`)
- Tailscale binary (install via `brew install tailscale`)
- OS images in `images4rpi/` directory (*.img.xz files)
- External USB/M.2 disk formatted with FAT32 partition

## Directory Structure

```
rpi-os-installer/
├── scripts/
│   ├── generate_os_setup.sh      # OS setup script generator
│   ├── setup_pi5_installer.sh    # Main installer script
│   └── download_images.sh        # Image download script
├── images4rpi/                   # OS images directory (gitignored)
└── pi5_installer_work/           # Work directory (gitignored)
```

## Quick Start

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd rpi-os-installer
   ```

2. **Install dependencies:**
   ```bash
   brew install git xz cpio tailscale
   ```

3. **Copy OS images:**
   ```bash
   # Copy existing images from home directory
   cp ~/images4rpi/*.img.xz ./images4rpi/
   
   # Or download new images
   ./scripts/download_images.sh
   ```

4. **Generate and create installer:**
   ```bash
   make all
   ```

   Or run steps individually:
   ```bash
   make generate  # Generate OS setup scripts
   make install   # Create installer media
   ```

5. **Deploy:**
   - Connect external USB/M.2 disk (FAT32 formatted)
   - Run the installer creation process
   - Safely unmount the device
   - Connect to Pi 5 and power on

## Usage

1. **Download or copy OS images:**
   ```bash
   # Copy existing images from home directory
   cp ~/images4rpi/*.img.xz ./images4rpi/
   
   # Or use the download script (future implementation)
   ./scripts/download_images.sh
   ```

2. **Generate OS-specific setup scripts:**
   ```bash
   chmod +x scripts/generate_os_setup.sh
   ./scripts/generate_os_setup.sh
   ```

3. **Create installer media:**
   ```bash
   chmod +x scripts/setup_pi5_installer.sh
   ./scripts/setup_pi5_installer.sh
   ```

4. **Deploy:**
   - Unmount the installer media
   - Connect to Pi 5
   - Power on for hands-free installation
   - SSH access will be automatically configured with your Mac keys

## SSH Access After Installation

After successful installation, you can SSH into your Pi using:

```bash
# For Ubuntu installations
ssh ubuntu@<pi-ip-address>

# For Home Assistant OS installations
ssh root@<pi-ip-address>
```

Your existing Mac SSH keys will work automatically if you selected them during setup.

## Supported OS Images

- Home Assistant OS (haos_rpi5-64-*.img.xz)
- Ubuntu Server (ubuntu-*-preinstalled-server-arm64+raspi.img.xz)

## Features

- Automatic external disk detection
- Interactive OS image selection
- SSH key reuse from Mac ~/.ssh/ directory (with user consent)
- Tailscale key management
- Automatic initramfs building
- OS-specific post-install configuration
- Idempotent operation (safe to run multiple times)

## SSH Key Setup

The installer can automatically configure SSH access using your existing Mac SSH keys:

### How It Works

1. **Detection**: The installer scans your `~/.ssh/` directory for public keys
2. **User Consent**: You're prompted to approve SSH key usage
3. **Key Selection**: Choose which keys to use (or select all available keys)
4. **Automatic Installation**: Public keys are copied to the Pi's authorized_keys

### Supported Key Types

- RSA keys (`id_rsa.pub`)
- Ed25519 keys (`id_ed25519.pub`)
- ECDSA keys (`id_ecdsa.pub`)
- DSA keys (`id_dsa.pub`)
- Custom named keys (any `.pub` file)

### Passphrase-Protected Keys

- **Unprotected keys**: Work automatically with no additional setup
- **Passphrase-protected keys**: You may need to unlock them first:
  ```bash
  ssh-add ~/.ssh/id_rsa  # Add key to ssh-agent
  # or unlock via macOS Keychain if configured
  ```

### Security Notes

- Only public keys are ever copied (never private keys)
- SSH keys are stored with restricted permissions (600)
- User consent is required before any SSH keys are used
- Keys are installed into the appropriate user account (ubuntu for Ubuntu, root for HAOS)

## Security

- Tailscale keys are stored with restricted permissions (chmod 600)
- Keys are never echoed to the console
- All sensitive files are excluded from git

## Troubleshooting

- Ensure only one external disk is connected
- Verify the external disk has a FAT32 partition
- Check that required tools are installed via Homebrew
- Confirm OS images are valid *.img.xz files

## Testing

You can test your installer locally without physical Pi hardware using several methods:

### Quick Testing (Recommended for Development)
```bash
# Test project setup and scripts
make test-setup
```

### QEMU Pi Simulation (Most Realistic)
```bash
# Setup QEMU Pi 5 emulation
make test-qemu

# Run interactive Pi simulation
make test-qemu-interactive

# Test specific OS image
./scripts/test_qemu_rpi.sh test-os haos_rpi5-64-16.0.img.xz
```

### Docker ARM64 Testing (Fast ARM64 Environment)
```bash
# Setup Docker ARM64 environment
make test-docker

# Run interactive ARM64 testing
make test-docker-interactive
```

See [TESTING.md](TESTING.md) for detailed testing instructions and workflows.
