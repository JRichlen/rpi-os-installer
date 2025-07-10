# Pi 5 Installer Testing Guide

This guide explains how to test your Pi 5 installer locally without needing physical Raspberry Pi hardware.

## Testing Options

### 1. QEMU ARM64 Emulation (Recommended)
QEMU provides the most realistic simulation of Raspberry Pi hardware.

**Setup:**
```bash
# Install QEMU
brew install qemu

# Setup QEMU test environment
make test-qemu
```

**Testing Commands:**
```bash
# Test your installer interactively
make test-qemu-interactive

# Or use the script directly
./scripts/test_qemu_rpi.sh setup
./scripts/test_qemu_rpi.sh interactive
./scripts/test_qemu_rpi.sh test-os haos_rpi5-64-16.0.img.xz
```

**Features:**
- ✅ Full ARM64 emulation
- ✅ Simulates Pi 5 hardware
- ✅ Tests actual OS images
- ✅ Network connectivity
- ✅ USB/SD card simulation
- ❌ Slower than native testing
- ❌ Requires more setup

### 2. Docker ARM64 Testing
Docker provides a faster ARM64 environment for testing scripts.

**Setup:**
```bash
# Setup Docker ARM64 environment
make test-docker
```

**Testing Commands:**
```bash
# Interactive testing
make test-docker-interactive

# Run automated tests
./scripts/test_docker_rpi.sh test

# Get shell access
./scripts/test_docker_rpi.sh shell
```

**Features:**
- ✅ Fast ARM64 environment
- ✅ Easy to set up
- ✅ Good for script testing
- ✅ Privileged mode for disk operations
- ❌ Not true Pi hardware simulation
- ❌ Limited hardware emulation

### 3. Native macOS Testing
Test installer scripts on your Mac (with limitations).

**Setup:**
```bash
# Run existing test suite
make test-setup
```

**Features:**
- ✅ Fastest testing
- ✅ Direct debugging
- ✅ Good for script logic
- ❌ x86_64 architecture differences
- ❌ No hardware simulation

## Testing Workflows

### 1. Development Testing
For rapid development and debugging:

```bash
# Quick script testing
make test-setup

# ARM64 script testing
make test-docker-interactive
```

### 2. Integration Testing
For testing complete installer workflow:

```bash
# Full QEMU simulation
make test-qemu
make test-qemu-interactive

# Test specific OS image
./scripts/test_qemu_rpi.sh test-os haos_rpi5-64-16.0.img.xz
```

### 3. Pre-deployment Testing
Before creating real installer media:

```bash
# Generate installer
make generate

# Test in ARM64 environment
make test-docker-interactive
cd /home/pi/rpi-os-installer
make install

# Test with QEMU
make test-qemu-interactive
```

## What Each Test Environment Provides

### QEMU Environment
- **Hardware**: Simulated Pi 5 (ARM Cortex-A72)
- **Memory**: 4GB RAM
- **Storage**: Virtual SD card + USB drive
- **Network**: User-mode networking with port forwarding
- **OS**: Can boot actual Pi OS images
- **Use cases**: Full integration testing, OS image validation

### Docker Environment
- **Hardware**: ARM64 container
- **Memory**: Host memory
- **Storage**: Bind-mounted project directory
- **Network**: Host networking
- **OS**: Ubuntu 22.04 ARM64
- **Use cases**: Script testing, dependency validation

### Native Environment
- **Hardware**: Your Mac
- **Memory**: Host memory
- **Storage**: Local filesystem
- **Network**: Host networking
- **OS**: macOS
- **Use cases**: Development, quick testing

## Testing Checklist

Before deploying your installer:

- [ ] **Script Logic**: Test with `make test-setup`
- [ ] **ARM64 Compatibility**: Test with `make test-docker-interactive`
- [ ] **OS Image Handling**: Test with QEMU
- [ ] **Dependencies**: Verify all tools are available
- [ ] **Error Handling**: Test failure scenarios
- [ ] **Network Configuration**: Test Tailscale setup
- [ ] **File Permissions**: Verify security settings

## Common Testing Scenarios

### Testing OS Image Extraction
```bash
# In Docker environment
make test-docker-interactive
cd /home/pi/rpi-os-installer
ls -la images4rpi/
xz -t images4rpi/*.img.xz  # Verify integrity
```

### Testing Tailscale Integration
```bash
# In QEMU environment
make test-qemu-interactive
# Boot into installer
# Test Tailscale key input
# Verify network configuration
```

### Testing Hardware Detection
```bash
# In Docker environment (privileged mode)
make test-docker-interactive
sudo fdisk -l  # Check disk detection
lsblk          # Check block devices
```

## Troubleshooting

### QEMU Issues
- **Slow boot**: Normal for emulation
- **No network**: Check QEMU networking setup
- **Boot fails**: Verify firmware files

### Docker Issues
- **ARM64 not supported**: Enable experimental features
- **Permission denied**: Use --privileged flag
- **Build fails**: Check Docker daemon

### Common Problems
- **Missing dependencies**: Run `make check-deps`
- **Invalid images**: Verify .img.xz files
- **Permission errors**: Check file permissions

## Performance Tips

### For QEMU
- Use KVM if available (Linux hosts)
- Allocate sufficient RAM
- Use raw disk images for better performance

### For Docker
- Use multi-stage builds
- Cache dependencies
- Use .dockerignore

### For Development
- Use native testing for quick iteration
- Only use full simulation for final validation
- Test incrementally

## Security Considerations

When testing:
- Use test Tailscale keys only
- Don't commit sensitive data
- Test in isolated environments
- Verify file permissions are correct

## Cleanup

After testing:
```bash
# Clean QEMU environment
make test-qemu-clean

# Clean Docker environment
make test-docker-clean

# Clean work directory
make clean
```

## Next Steps

1. **Start with native testing** for quick development
2. **Use Docker for ARM64 validation**
3. **Use QEMU for full integration testing**
4. **Test on real Pi hardware** before production use

This multi-layered approach ensures your installer works correctly across different environments and catches issues early in the development process.
