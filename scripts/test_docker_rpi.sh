#!/bin/bash

# test_docker_rpi.sh
# Docker-based Raspberry Pi simulation for testing installer scripts

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

print_status() {
    echo -e "${GREEN}[DOCKER-TEST]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[DOCKER-TEST]${NC} $1"
}

print_error() {
    echo -e "${RED}[DOCKER-TEST]${NC} $1" >&2
}

print_step() {
    echo -e "${BLUE}[DOCKER-TEST]${NC} $1"
}

# Function to check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker Desktop"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon not running. Please start Docker Desktop"
        exit 1
    fi
    
    print_status "Docker is available"
}

# Function to create Dockerfile for ARM64 testing
create_dockerfile() {
    local dockerfile_path="$PROJECT_DIR/Dockerfile.test"
    
    print_step "Creating ARM64 test Dockerfile..."
    
    cat > "$dockerfile_path" << 'EOF'
# Multi-platform Docker image for testing Pi installer
FROM --platform=linux/arm64 ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    xz-utils \
    cpio \
    git \
    fdisk \
    parted \
    dosfstools \
    e2fsprogs \
    mount \
    util-linux \
    file \
    sudo \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Create a test user
RUN useradd -m -s /bin/bash pi && \
    echo "pi:raspberry" | chpasswd && \
    usermod -aG sudo pi && \
    echo "pi ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create necessary directories
RUN mkdir -p /mnt/usb /mnt/sd /tmp/installer

# Set working directory
WORKDIR /home/pi

# Copy project files
COPY . /home/pi/rpi-os-installer/
RUN chown -R pi:pi /home/pi/rpi-os-installer

# Switch to pi user
USER pi

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/home/pi/rpi-os-installer/scripts:$PATH"

# Default command
CMD ["/bin/bash"]
EOF

    print_status "Dockerfile created: $dockerfile_path"
}

# Function to build Docker image
build_docker_image() {
    print_step "Building ARM64 test Docker image..."
    
    cd "$PROJECT_DIR"
    docker build --platform linux/arm64 -t rpi-installer-test -f Dockerfile.test .
    
    print_status "Docker image built successfully"
}

# Function to run Docker container
run_docker_container() {
    local mode="${1:-interactive}"
    
    print_step "Starting Docker container for Pi simulation..."
    
    case "$mode" in
        "interactive")
            print_status "Starting interactive container..."
            docker run --rm -it \
                --platform linux/arm64 \
                --privileged \
                -v "$PROJECT_DIR:/home/pi/rpi-os-installer" \
                rpi-installer-test
            ;;
        
        "test")
            print_status "Running automated tests..."
            docker run --rm \
                --platform linux/arm64 \
                --privileged \
                -v "$PROJECT_DIR:/home/pi/rpi-os-installer" \
                rpi-installer-test \
                bash -c "cd /home/pi/rpi-os-installer && make test-setup"
            ;;
        
        "shell")
            print_status "Starting shell in container..."
            docker run --rm -it \
                --platform linux/arm64 \
                --privileged \
                -v "$PROJECT_DIR:/home/pi/rpi-os-installer" \
                rpi-installer-test \
                bash
            ;;
        
        *)
            print_error "Unknown mode: $mode"
            print_error "Available modes: interactive, test, shell"
            exit 1
            ;;
    esac
}

# Function to clean up Docker resources
clean_docker() {
    print_step "Cleaning up Docker resources..."
    
    # Remove test image
    if docker image inspect rpi-installer-test &> /dev/null; then
        docker rmi rpi-installer-test
        print_status "Removed test image"
    fi
    
    # Remove Dockerfile
    if [[ -f "$PROJECT_DIR/Dockerfile.test" ]]; then
        rm "$PROJECT_DIR/Dockerfile.test"
        print_status "Removed test Dockerfile"
    fi
    
    print_status "Docker cleanup complete"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup              - Create Dockerfile and build test image"
    echo "  run                - Run interactive container"
    echo "  test               - Run automated tests in container"
    echo "  shell              - Start shell in container"
    echo "  clean              - Clean up Docker resources"
    echo ""
    echo "Examples:"
    echo "  $0 setup           # Build ARM64 test environment"
    echo "  $0 run             # Start interactive testing"
    echo "  $0 test            # Run automated tests"
    echo "  $0 shell           # Get shell access"
    echo ""
    echo "Note: This creates an ARM64 container to simulate Pi architecture"
}

# Function to show Docker testing instructions
show_testing_instructions() {
    echo ""
    print_status "Docker Pi Simulation Testing Instructions:"
    echo ""
    echo "Inside the container, you can:"
    echo "  • Test your installer scripts in ARM64 environment"
    echo "  • Simulate disk operations (with --privileged)"
    echo "  • Run your OS setup scripts"
    echo "  • Test Tailscale installation"
    echo ""
    echo "Example commands inside container:"
    echo "  cd /home/pi/rpi-os-installer"
    echo "  make check-deps"
    echo "  make generate"
    echo "  ls -la images4rpi/           # Check your OS images"
    echo "  ls -la pi5_installer_work/   # Check generated files"
    echo ""
    echo "To exit the container: type 'exit'"
}

# Main script logic
main() {
    local command="${1:-help}"
    
    case "$command" in
        "setup")
            check_docker
            create_dockerfile
            build_docker_image
            print_status "Docker test environment ready!"
            print_status "Run '$0 run' to start testing"
            ;;
        
        "run")
            check_docker
            run_docker_container "interactive"
            ;;
        
        "test")
            check_docker
            run_docker_container "test"
            ;;
        
        "shell")
            check_docker
            run_docker_container "shell"
            ;;
        
        "clean")
            clean_docker
            ;;
        
        "help"|"-h"|"--help")
            show_usage
            show_testing_instructions
            ;;
        
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
