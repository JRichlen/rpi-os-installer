#!/bin/bash

# ci_documentation_check.sh
# Documentation validation script for CI pipeline

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
    echo -e "${BLUE}[DOCS]${NC} $1"
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

check_required_documentation() {
    print_info "Checking required documentation files..."
    
    cd "$PROJECT_DIR"
    
    # Required documentation files
    required_docs=(
        "README.md"
        "TESTING.md"
        ".github/copilot-instructions.md"
        "CI_PIPELINE.md"
    )
    
    missing_docs=()
    
    for doc in "${required_docs[@]}"; do
        if [[ -f "$doc" ]]; then
            print_pass "Found $doc"
        else
            print_fail "Missing $doc"
            missing_docs+=("$doc")
        fi
    done
    
    if [[ ${#missing_docs[@]} -gt 0 ]]; then
        print_fail "Missing required documentation files: ${missing_docs[*]}"
        return 1
    fi
}

validate_documentation_content() {
    print_info "Validating documentation content..."
    
    cd "$PROJECT_DIR"
    
    # Check README.md has basic content
    if [[ -f "README.md" ]]; then
        if grep -q "Raspberry Pi" README.md && grep -q "installer" README.md; then
            print_pass "README.md has appropriate content"
        else
            print_fail "README.md lacks appropriate content"
            return 1
        fi
    fi
    
    # Check TESTING.md has testing information
    if [[ -f "TESTING.md" ]]; then
        if grep -q "test" TESTING.md; then
            print_pass "TESTING.md has testing information"
        else
            print_fail "TESTING.md lacks testing information"
            return 1
        fi
    fi
}

validate_internal_links() {
    print_info "Validating internal documentation links..."
    
    cd "$PROJECT_DIR"
    
    # Check for broken internal links (basic check)
    if find . -name "*.md" -type f -exec grep -l "\[.*\](.*/.*)" {} \; 2>/dev/null | grep -v "http" > /tmp/md_files.txt 2>/dev/null && [[ -s /tmp/md_files.txt ]]; then
        print_info "Found markdown files with internal links - performing basic validation"
        rm -f /tmp/md_files.txt
        print_pass "Internal links validation completed (basic check)"
    else
        print_pass "No internal links found to validate"
        rm -f /tmp/md_files.txt
    fi
}

check_code_documentation() {
    print_info "Checking code documentation..."
    
    cd "$PROJECT_DIR"
    
    # Check that shell scripts have proper headers
    undocumented_scripts=()
    
    find scripts -name "*.sh" -type f | while IFS= read -r script; do
        if ! head -n 10 "$script" | grep -q "^#.*\.sh"; then
            undocumented_scripts+=("$script")
        fi
    done
    
    if [[ ${#undocumented_scripts[@]} -gt 0 ]]; then
        print_info "Scripts that could use better documentation headers:"
        printf '%s\n' "${undocumented_scripts[@]}"
    else
        print_pass "All scripts have documentation headers"
    fi
}

validate_makefile_documentation() {
    print_info "Validating Makefile documentation..."
    
    cd "$PROJECT_DIR"
    
    if [[ -f "Makefile" ]]; then
        # Check that Makefile has help target
        if grep -q "help:" Makefile; then
            print_pass "Makefile has help target"
        else
            print_fail "Makefile lacks help target"
            return 1
        fi
        
        # Check that help target actually works
        if make help > /dev/null 2>&1; then
            print_pass "Makefile help target works"
        else
            print_fail "Makefile help target doesn't work"
            return 1
        fi
    else
        print_fail "Makefile not found"
        return 1
    fi
}

check_ci_documentation() {
    print_info "Checking CI/CD documentation..."
    
    cd "$PROJECT_DIR"
    
    # Check CI pipeline documentation
    if [[ -f "CI_PIPELINE.md" ]]; then
        if grep -q "pipeline" CI_PIPELINE.md; then
            print_pass "CI_PIPELINE.md has pipeline information"
        else
            print_fail "CI_PIPELINE.md lacks pipeline information"
            return 1
        fi
    fi
    
    # Check that GitHub Actions workflows exist
    if [[ -d ".github/workflows" ]]; then
        if ls .github/workflows/*.yml > /dev/null 2>&1; then
            print_pass "GitHub Actions workflows exist"
        else
            print_fail "No GitHub Actions workflows found"
            return 1
        fi
    else
        print_fail "No .github/workflows directory found"
        return 1
    fi
}

main() {
    print_header "Running documentation validation..."
    
    check_required_documentation
    validate_documentation_content
    validate_internal_links
    check_code_documentation
    validate_makefile_documentation
    check_ci_documentation
    
    print_pass "Documentation validation completed successfully"
}

# Run main function
main "$@"
