# Raspberry Pi OS Installer - Copilot Instructions

This is a shell script-based project that creates a custom installer for Raspberry Pi systems. The installer can flash OS images to NVMe drives and perform automated setup and configuration.

## Project Structure

- `scripts/` - Build, test, and utility scripts
- `pi5_installer_work/` - Main installer files and configuration
  - `rootfs/sbin/init` - Main installer boot script
  - `os-setups/` - OS-specific setup scripts
  - `firmware/` - Raspberry Pi firmware files
- `images4rpi/` - OS images for installation (*.img.xz files)
- `qemu_test/` - QEMU testing environment
- `Makefile` - Build system for creating installer images

## Code Standards

### Required Before Each Commit
- Run `shellcheck` on all shell scripts to ensure proper syntax and best practices
- Test changes with QEMU emulation when possible
- Validate build process with `make`

### Development Flow
- Build: `make` (creates installer image)
- Test: `./scripts/test_qemu_rpi.sh` (QEMU testing)
- Docker test: `./scripts/test_docker_rpi.sh` (containerized testing)
- Validation: `./scripts/validate_tests.sh` (run all tests)

## Key Guidelines

1. **Shell Scripting Best Practices**:
   - Always use `set -e` for error handling
   - Use proper quoting for variables
   - Include descriptive error messages
   - Follow POSIX shell compatibility when possible

2. **Hardware Compatibility**:
   - Support multiple Raspberry Pi models (Pi 4, Pi 5)
   - Handle different storage devices (SD card, USB, NVMe)
   - Use appropriate device tree blobs (*.dtb files)

3. **OS Support**:
   - Each OS type should have its own setup script in `os-setups/`
   - Follow naming convention: `setup_<os-name>.sh`
   - Handle network configuration, SSH keys, and service setup

4. **Testing**:
   - Use QEMU for hardware emulation testing
   - Docker containers for isolated testing
   - Always test on actual hardware when possible

## Architecture Overview

The installer works by:
1. Booting from SD card/USB with minimal Linux environment (initramfs)
2. Mounting installer media and detecting OS images
3. Flashing OS images to NVMe drives using `dd`
4. Running OS-specific setup scripts for configuration
5. Cleaning up and rebooting to the installed system

## Environment Variables

- `TAVILY_API_KEY` - API key for Tavily service (available from secrets)

## Common Tasks

### Adding Support for New OS
1. Create setup script in `pi5_installer_work/os-setups/`
2. Follow existing patterns from other setup scripts
3. Test with QEMU and actual hardware

### Modifying Installation Process
1. Edit `pi5_installer_work/rootfs/sbin/init`
2. Maintain error handling and logging
3. Test thoroughly with different scenarios

### Build System Changes
1. Modify `Makefile` or `scripts/setup_pi5_installer.sh`
2. Ensure compatibility with existing workflow
3. Test build process end-to-end

## Testing Strategy

- **Unit Testing**: Individual script validation with shellcheck
- **Integration Testing**: QEMU emulation with different Pi models
- **Hardware Testing**: Actual Raspberry Pi devices
- **Containerized Testing**: Docker-based isolated testing

## Important Files to Understand

- `pi5_installer_work/rootfs/sbin/init` - Main installer logic and flow
- `scripts/setup_pi5_installer.sh` - Build system that creates installer
- `Makefile` - Build configuration and targets
- `scripts/test_*.sh` - Various testing approaches and environments
