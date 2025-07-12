#!/bin/bash

# ci_security_scan.sh
# Security scanning script for CI pipeline

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_header() {
    echo -e "${BLUE}[SECURITY]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

scan_hardcoded_secrets() {
    print_info "Scanning for potential hardcoded secrets..."
    
    cd "$PROJECT_DIR"
    
    # Create a temporary file with the search results
    grep -r -i -E "(password|secret|key|token|api)" --include="*.sh" . > /tmp/security_scan.tmp 2>/dev/null || true
    
    # Filter out acceptable patterns
    if grep -v -E "(PASSWORD|SECRET|KEY|TOKEN|API).*=.*\$" /tmp/security_scan.tmp | \
       grep -E "=.*['\"][^$][^{].*['\"]" | \
       grep -v -E "(TAILSCALE_KEY_CONTENT|auth_key.*\$|tailscale\.key|authorized_keys)" | \
       grep -v -E "api_url.*github\.com" | \
       grep -v -E "# TODO.*token" | \
       grep -v -E "local.*=.*\$" | \
       grep -v -E "=.*\$\(.*\)" | \
       grep -v -E "ci_security_scan\.sh" | \
       grep -v -E "grep.*-E.*password|secret|key|token|api"; then
        print_fail "Potential hardcoded secrets found"
        rm -f /tmp/security_scan.tmp
        return 1
    else
        print_pass "No hardcoded secrets detected"
        rm -f /tmp/security_scan.tmp
    fi
}

check_dangerous_commands() {
    print_info "Scanning for dangerous command patterns..."
    
    cd "$PROJECT_DIR"
    dangerous_found=false
    
    # Check for rm -rf without proper protection (excluding generated files and safe patterns)
    if grep -r "rm -rf" --include="*.sh" . | \
       grep -v -E "\${.*:?\}" | \
       grep -v -E "\$\(" | \
       grep -v -E "# Safe" | \
       grep -v -E "ci_security_scan\.sh" | \
       grep -v -E "dist/" | \
       grep -v -E "pi5_installer_work/" | \
       grep -v -E "rm -rf.*\"/.*\"" | \
       grep -v -E "rm -rf.*'\$.*'" | \
       grep -v -E "rm -rf.*\".*\$.*\"" | \
       grep -v -E "2>/dev/null.*true"; then
        print_warning "Found potentially unsafe rm -rf commands"
        dangerous_found=true
    fi
    
    # Check for hardcoded device paths (excluding generated files)
    if grep -r "/dev/.*" --include="*.sh" . | \
       grep -v "detect_target_device" | \
       grep -v "\$" | \
       grep -v "#" | \
       grep -v "ci_security_scan\.sh" | \
       grep -v "dist/" | \
       grep -v "pi5_installer_work/"; then
        print_warning "Found potentially hardcoded device paths"
        dangerous_found=true
    fi
    
    if [[ "$dangerous_found" == "true" ]]; then
        print_info "Security warnings found - please review manually"
        # Don't fail on warnings, just report them
    else
        print_pass "No dangerous command patterns found"
    fi
}

validate_file_permissions() {
    print_info "Checking file permissions..."
    
    cd "$PROJECT_DIR"
    
    # Check that shell scripts are executable
    if find . -name "*.sh" -type f ! -perm -u+x -print > /tmp/non_executable.txt && [[ -s /tmp/non_executable.txt ]]; then
        print_fail "Found non-executable shell scripts:"
        cat /tmp/non_executable.txt
        rm -f /tmp/non_executable.txt
        return 1
    else
        print_pass "All shell scripts have proper permissions"
        rm -f /tmp/non_executable.txt
    fi
}

check_sensitive_files() {
    print_info "Checking for sensitive files..."
    
    cd "$PROJECT_DIR"
    
    # Check for common sensitive file patterns
    sensitive_patterns=(
        "*.key"
        "*.pem"
        "*.p12"
        "*.pfx"
        "*password*"
        "*secret*"
        ".env"
        "id_rsa"
        "id_dsa"
        "id_ecdsa"
        "id_ed25519"
    )
    
    sensitive_found=false
    for pattern in "${sensitive_patterns[@]}"; do
        if find . -name "$pattern" -type f | grep -v -E "(tailscale\.key|\.gitignore|\.md$)"; then
            sensitive_found=true
        fi
    done
    
    if [[ "$sensitive_found" == "true" ]]; then
        print_warning "Found potentially sensitive files - review carefully"
    else
        print_pass "No sensitive files found"
    fi
}

main() {
    print_header "Running security scanning..."
    
    scan_hardcoded_secrets
    check_dangerous_commands
    validate_file_permissions
    check_sensitive_files
    
    print_pass "Security scan completed successfully"
}

# Run main function
main "$@"
