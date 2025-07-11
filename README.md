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

   During setup, you'll be prompted for:
   - **OS Image Selection**: Choose which OS image to install
   - **Tailscale Key**: Enter your Tailscale authentication key
   - **WiFi Credentials**: Configure network access for the Pi
   - **SSH Key Setup**: Option to enable SSH access with your existing keys

4. **Deploy:**
   - Unmount the installer media
   - Connect to Pi 5
   - Power on for hands-free installation

### SSH Key Setup Examples

**For users with existing SSH keys:**
```bash
# The installer will automatically detect keys like:
# ~/.ssh/id_ed25519.pub
# ~/.ssh/id_rsa.pub

# If you have multiple keys, you'll be prompted to select one
```

**For users without SSH keys:**
```bash
# The installer can generate a new key pair for you
# When prompted, choose "y" to generate new keys
```

**For users with passphrase-protected keys:**
```bash
# Ensure your key is loaded in ssh-agent:
ssh-add ~/.ssh/id_ed25519

# Or use macOS Keychain to store the passphrase
# The installer will verify key accessibility
```

## Supported OS Images

- Home Assistant OS (haos_rpi5-64-*.img.xz)
- Ubuntu Server (ubuntu-*-preinstalled-server-arm64+raspi.img.xz)

## Features

- Automatic external disk detection
- Interactive OS image selection
- Tailscale key management
- **SSH key management with user consent**
- Automatic initramfs building
- OS-specific post-install configuration
- Idempotent operation (safe to run multiple times)

### SSH Key Management

The installer can automatically detect and configure SSH keys for secure access to your Pi:

- **Automatic Detection**: Scans `~/.ssh/` directory for public keys (`id_rsa.pub`, `id_ed25519.pub`, etc.)
- **User Consent**: Prompts for explicit permission before using any SSH keys
- **Key Selection**: Allows selection when multiple keys are available
- **Passphrase Support**: Works with both passphrase-protected and unprotected keys
- **Secure Copy**: Only copies public keys (never private keys) to the target device
- **Key Generation**: Option to generate new SSH key pairs if none exist
- **Cross-Platform**: Supports macOS Keychain and ssh-agent integration

#### SSH Key Workflow

1. **Detection**: The installer scans your `~/.ssh/` directory for public keys
2. **Consent**: You're asked if you want to enable SSH key access
3. **Selection**: If multiple keys exist, you can choose which one to use
4. **Validation**: The installer checks if the key is passphrase-protected
5. **Authentication**: For passphrase-protected keys, it verifies accessibility via ssh-agent/Keychain
6. **Installation**: Only the public key is copied to the Pi's `authorized_keys` file
7. **Service Setup**: SSH service is automatically enabled on the target device

#### Supported Key Types

- RSA (`id_rsa.pub`)
- Ed25519 (`id_ed25519.pub`) - Recommended
- ECDSA (`id_ecdsa.pub`)
- DSA (`id_dsa.pub`)
- Any other `.pub` files in `~/.ssh/`

## Security

- Tailscale keys are stored with restricted permissions (chmod 600)
- Keys are never echoed to the console
- All sensitive files are excluded from git
- **Comprehensive CI/CD pipeline** validates all code changes
- **Automated security scanning** prevents vulnerabilities
- **ShellCheck validation** ensures script quality and safety

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

## CI/CD Pipeline

This project includes a comprehensive CI/CD pipeline that automatically validates all code changes:

### Automated Validation
- **ShellCheck** validation for all shell scripts
- **Security scanning** for hardcoded secrets and dangerous patterns
- **Build process** validation and testing
- **Integration testing** with QEMU and Docker
- **Documentation** completeness checks

### Pipeline Triggers
- Pull requests to `main` or `develop` branches
- Push events to protected branches
- Manual workflow dispatch

### Quality Gates
All changes must pass:
- ✅ Zero ShellCheck issues
- ✅ Successful build process
- ✅ Security compliance
- ✅ Integration tests
- ✅ Documentation validation

See [CI_PIPELINE.md](CI_PIPELINE.md) for detailed pipeline documentation.

## Contributing

When contributing to this project:

1. **Run local validation** before pushing:
   ```bash
   # Quick validation
   make validate
   
   # ShellCheck all scripts
   find . -name "*.sh" -type f -print0 | xargs -0 shellcheck
   ```

2. **Follow security best practices**:
   - No hardcoded secrets or credentials
   - Use safe command patterns
   - Validate all user inputs

3. **Test your changes**:
   ```bash
   make test-setup
   make generate
   ```

4. **Monitor CI pipeline** status after pushing changes
