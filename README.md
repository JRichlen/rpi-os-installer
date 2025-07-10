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

## Supported OS Images

- Home Assistant OS (haos_rpi5-64-*.img.xz)
- Ubuntu Server (ubuntu-*-preinstalled-server-arm64+raspi.img.xz)

## Features

- Automatic external disk detection
- Interactive OS image selection
- Tailscale key management
- Automatic initramfs building
- OS-specific post-install configuration
- Idempotent operation (safe to run multiple times)

## Security

- Tailscale keys are stored with restricted permissions (chmod 600)
- Keys are never echoed to the console
- All sensitive files are excluded from git

## Troubleshooting

- Ensure only one external disk is connected
- Verify the external disk has a FAT32 partition
- Check that required tools are installed via Homebrew
- Confirm OS images are valid *.img.xz files
