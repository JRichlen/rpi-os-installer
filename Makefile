# Pi 5 Installer Makefile

.PHONY: help setup generate install clean download-images check-deps test-setup test-qemu test-qemu-interactive test-qemu-clean test-docker test-docker-interactive test-docker-clean validate ci-all ci-shellcheck ci-build ci-security ci-testing ci-integration ci-docs

# Default target
help:
	@echo "Pi 5 Installer Commands:"
	@echo "  help           - Show this help message"
	@echo "  check-deps     - Check and install dependencies"
	@echo "  download-images - Download/copy OS images"
	@echo "  generate       - Generate OS-specific setup scripts"
	@echo "  setup          - Generate setup scripts (alias for generate)"
	@echo "  install        - Create installer media"
	@echo "  clean          - Clean work directory"
	@echo "  all            - Run complete workflow (generate + install)"
	@echo ""
	@echo "Testing Commands:"
	@echo "  test-setup     - Run project setup tests"
	@echo "  validate       - Validate testing setup and capabilities"
	@echo "  test-qemu      - Setup QEMU for Pi simulation testing"
	@echo "  test-qemu-interactive - Run interactive QEMU Pi simulation"
	@echo "  test-qemu-clean - Clean QEMU test environment"
	@echo "  test-docker    - Setup Docker ARM64 testing environment"
	@echo "  test-docker-interactive - Run interactive Docker Pi simulation"
	@echo "  test-docker-clean - Clean Docker test environment"
	@echo ""
	@echo "CI Commands:"
	@echo "  ci-all         - Run all CI checks"
	@echo "  ci-shellcheck  - Run ShellCheck validation"
	@echo "  ci-build       - Run build process validation"
	@echo "  ci-security    - Run security scanning"
	@echo "  ci-testing     - Run testing framework validation"
	@echo "  ci-integration - Run integration testing"
	@echo "  ci-docs        - Run documentation validation"
	@echo ""
	@echo "CI Commands:"
	@echo "  ci-all         - Run all CI checks"
	@echo "  ci-shellcheck  - Run ShellCheck validation"
	@echo "  ci-build       - Run build process validation"
	@echo "  ci-security    - Run security scanning"
	@echo "  ci-testing     - Run testing framework validation"
	@echo "  ci-integration - Run integration testing"
	@echo "  ci-docs        - Run documentation validation"

# Check dependencies
check-deps:
	@echo "Checking dependencies..."
	@scripts/setup_pi5_installer.sh --check-deps-only || echo "Run 'brew install git xz cpio tailscale' if missing"

# Download or copy OS images
download-images:
	@echo "Downloading/copying OS images..."
	@scripts/download_images.sh

# Generate OS setup scripts
generate:
	@echo "Generating OS setup scripts..."
	@scripts/generate_os_setup.sh

# Alias for generate
setup: generate

# Create installer media
install:
	@echo "Creating installer media..."
	@scripts/setup_pi5_installer.sh

# Complete workflow
all: generate install

# Clean work directory
clean:
	@echo "Cleaning work directory..."
	@rm -rf ~/pi5_installer_work
	@echo "Work directory cleaned"

# Show project status
status:
	@echo "Project Status:"
	@echo "=============="
	@echo "Images directory: $(shell ls -1 images4rpi/*.img.xz 2>/dev/null | wc -l) image(s)"
	@echo "Work directory: $(shell if [ -d ~/pi5_installer_work ]; then echo 'exists'; else echo 'missing'; fi)"
	@echo "OS setups: $(shell ls -1 ~/pi5_installer_work/os-setups/*.sh 2>/dev/null | wc -l) script(s)"
	@echo ""
	@echo "Available images:"
	@ls -1 images4rpi/*.img.xz 2>/dev/null || echo "  No images found"

# Testing targets
test-setup:
	@echo "Running setup tests..."
	@scripts/test_setup.sh

# QEMU testing targets
test-qemu:
	@echo "Setting up QEMU Pi simulation environment..."
	@scripts/test_qemu_rpi.sh setup

test-qemu-interactive:
	@echo "Running interactive QEMU Pi simulation..."
	@scripts/test_qemu_rpi.sh interactive

test-qemu-clean:
	@echo "Cleaning QEMU test environment..."
	@scripts/test_qemu_rpi.sh clean

# Docker testing targets
test-docker:
	@echo "Setting up Docker ARM64 testing environment..."
	@scripts/test_docker_rpi.sh setup

test-docker-interactive:
	@echo "Running interactive Docker Pi simulation..."
	@scripts/test_docker_rpi.sh run

test-docker-clean:
	@echo "Cleaning Docker test environment..."
	@scripts/test_docker_rpi.sh clean

# Test validation
validate:
	@echo "Validating testing setup..."
	@scripts/validate_tests.sh

# CI checks
ci-all:
	@echo "Running all CI checks..."
	@scripts/ci_run_all.sh

ci-shellcheck:
	@echo "Running ShellCheck validation..."
	@scripts/ci_shellcheck.sh

ci-build:
	@echo "Running build process validation..."
	@scripts/ci_build_validation.sh

ci-security:
	@echo "Running security scanning..."
	@scripts/ci_security_scan.sh

ci-testing:
	@echo "Running testing framework validation..."
	@scripts/ci_testing_framework.sh

ci-integration:
	@echo "Running integration testing..."
	@scripts/ci_integration_test.sh

ci-docs:
	@echo "Running documentation validation..."
	@scripts/ci_documentation_check.sh
