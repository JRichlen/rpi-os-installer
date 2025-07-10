# Pi 5 Installer Makefile

.PHONY: help setup generate install clean download-images check-deps

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
