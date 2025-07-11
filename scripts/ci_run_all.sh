#!/bin/bash

# ci_run_all.sh
# Master CI script that runs all checks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "${BLUE}[CI]${NC} $1"
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

print_summary() {
    echo -e "${BLUE}[SUMMARY]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run CI pipeline checks"
    echo ""
    echo "Options:"
    echo "  --check CHECK_NAME    Run specific check (shellcheck, build, security, testing, integration, docs)"
    echo "  --skip CHECK_NAME     Skip specific check"
    echo "  --parallel            Run checks in parallel (experimental)"
    echo "  --help                Show this help message"
    echo ""
    echo "Available checks:"
    echo "  shellcheck           Run ShellCheck validation"
    echo "  build                Run build process validation"
    echo "  security             Run security scanning"
    echo "  testing              Run testing framework validation"
    echo "  integration          Run integration testing"
    echo "  docs                 Run documentation validation"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run all checks"
    echo "  $0 --check shellcheck        # Run only ShellCheck"
    echo "  $0 --skip integration        # Skip integration tests"
}

# Default settings
RUN_SHELLCHECK=true
RUN_BUILD=true
RUN_SECURITY=true
RUN_TESTING=true
RUN_INTEGRATION=true
RUN_DOCS=true
PARALLEL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            # Run only specific check
            RUN_SHELLCHECK=false
            RUN_BUILD=false
            RUN_SECURITY=false
            RUN_TESTING=false
            RUN_INTEGRATION=false
            RUN_DOCS=false
            
            case $2 in
                shellcheck) RUN_SHELLCHECK=true ;;
                build) RUN_BUILD=true ;;
                security) RUN_SECURITY=true ;;
                testing) RUN_TESTING=true ;;
                integration) RUN_INTEGRATION=true ;;
                docs) RUN_DOCS=true ;;
                *) echo "Unknown check: $2"; usage; exit 1 ;;
            esac
            shift 2
            ;;
        --skip)
            case $2 in
                shellcheck) RUN_SHELLCHECK=false ;;
                build) RUN_BUILD=false ;;
                security) RUN_SECURITY=false ;;
                testing) RUN_TESTING=false ;;
                integration) RUN_INTEGRATION=false ;;
                docs) RUN_DOCS=false ;;
                *) echo "Unknown check: $2"; usage; exit 1 ;;
            esac
            shift 2
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Function to run a check
run_check() {
    local script_name=${1:-}
    local description=${2:-}
    
    if [[ -z "$script_name" || -z "$description" ]]; then
        print_fail "Invalid parameters to run_check"
        return 1
    fi
    
    print_header "Running $description..."
    
    if [[ -x "$SCRIPT_DIR/$script_name" ]]; then
        if "$SCRIPT_DIR/$script_name"; then
            print_pass "$description completed successfully"
            return 0
        else
            print_fail "$description failed"
            return 1
        fi
    else
        print_fail "$script_name not found or not executable"
        return 1
    fi
}

# Make scripts executable
make_scripts_executable() {
    print_info "Making CI scripts executable..."
    chmod +x "$SCRIPT_DIR"/ci_*.sh
}

# Main execution
main() {
    print_header "Starting CI Pipeline"
    echo "===================="
    
    # Make sure scripts are executable
    make_scripts_executable
    
    # Track results using simple variables
    shellcheck_result=0
    build_result=0
    security_result=0
    testing_result=0
    integration_result=0
    docs_result=0
    
    # Run checks
    if [[ "$PARALLEL" == "true" ]]; then
        print_info "Running checks in parallel..."
        pids=()
        
        # Start background processes
        if [[ "$RUN_SHELLCHECK" == "true" ]]; then
            (run_check "ci_shellcheck.sh" "ShellCheck validation"; echo $? > /tmp/ci_shellcheck_result) &
            pids+=($!)
        fi
        
        if [[ "$RUN_BUILD" == "true" ]]; then
            (run_check "ci_build_validation.sh" "Build process validation"; echo $? > /tmp/ci_build_result) &
            pids+=($!)
        fi
        
        if [[ "$RUN_SECURITY" == "true" ]]; then
            (run_check "ci_security_scan.sh" "Security scanning"; echo $? > /tmp/ci_security_result) &
            pids+=($!)
        fi
        
        if [[ "$RUN_TESTING" == "true" ]]; then
            (run_check "ci_testing_framework.sh" "Testing framework validation"; echo $? > /tmp/ci_testing_result) &
            pids+=($!)
        fi
        
        if [[ "$RUN_DOCS" == "true" ]]; then
            (run_check "ci_documentation_check.sh" "Documentation validation"; echo $? > /tmp/ci_docs_result) &
            pids+=($!)
        fi
        
        # Wait for all parallel processes
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        
        # Collect results
        [[ -f /tmp/ci_shellcheck_result ]] && shellcheck_result=$(cat /tmp/ci_shellcheck_result)
        [[ -f /tmp/ci_build_result ]] && build_result=$(cat /tmp/ci_build_result)
        [[ -f /tmp/ci_security_result ]] && security_result=$(cat /tmp/ci_security_result)
        [[ -f /tmp/ci_testing_result ]] && testing_result=$(cat /tmp/ci_testing_result)
        [[ -f /tmp/ci_docs_result ]] && docs_result=$(cat /tmp/ci_docs_result)
        
        # Clean up temp files
        rm -f /tmp/ci_*_result
        
        # Run integration test last (needs other checks to pass)
        if [[ "$RUN_INTEGRATION" == "true" ]]; then
            run_check "ci_integration_test.sh" "Integration testing"
            integration_result=$?
        fi
        
    else
        # Sequential execution
        if [[ "$RUN_SHELLCHECK" == "true" ]]; then
            run_check "ci_shellcheck.sh" "ShellCheck validation"
            shellcheck_result=$?
        fi
        
        if [[ "$RUN_BUILD" == "true" ]]; then
            run_check "ci_build_validation.sh" "Build process validation"
            build_result=$?
        fi
        
        if [[ "$RUN_SECURITY" == "true" ]]; then
            run_check "ci_security_scan.sh" "Security scanning"
            security_result=$?
        fi
        
        if [[ "$RUN_TESTING" == "true" ]]; then
            run_check "ci_testing_framework.sh" "Testing framework validation"
            testing_result=$?
        fi
        
        if [[ "$RUN_INTEGRATION" == "true" ]]; then
            run_check "ci_integration_test.sh" "Integration testing"
            integration_result=$?
        fi
        
        if [[ "$RUN_DOCS" == "true" ]]; then
            run_check "ci_documentation_check.sh" "Documentation validation"
            docs_result=$?
        fi
    fi
    
    # Print summary
    echo ""
    print_summary "CI Pipeline Summary"
    echo "==================="
    
    total_checks=0
    passed_checks=0
    
    if [[ "$RUN_SHELLCHECK" == "true" ]]; then
        if [[ "$shellcheck_result" -eq 0 ]]; then
            print_pass "shellcheck validation: PASSED"
            ((passed_checks++))
        else
            print_fail "shellcheck validation: FAILED"
        fi
        ((total_checks++))
    fi
    
    if [[ "$RUN_BUILD" == "true" ]]; then
        if [[ "$build_result" -eq 0 ]]; then
            print_pass "build validation: PASSED"
            ((passed_checks++))
        else
            print_fail "build validation: FAILED"
        fi
        ((total_checks++))
    fi
    
    if [[ "$RUN_SECURITY" == "true" ]]; then
        if [[ "$security_result" -eq 0 ]]; then
            print_pass "security validation: PASSED"
            ((passed_checks++))
        else
            print_fail "security validation: FAILED"
        fi
        ((total_checks++))
    fi
    
    if [[ "$RUN_TESTING" == "true" ]]; then
        if [[ "$testing_result" -eq 0 ]]; then
            print_pass "testing validation: PASSED"
            ((passed_checks++))
        else
            print_fail "testing validation: FAILED"
        fi
        ((total_checks++))
    fi
    
    if [[ "$RUN_INTEGRATION" == "true" ]]; then
        if [[ "$integration_result" -eq 0 ]]; then
            print_pass "integration validation: PASSED"
            ((passed_checks++))
        else
            print_fail "integration validation: FAILED"
        fi
        ((total_checks++))
    fi
    
    if [[ "$RUN_DOCS" == "true" ]]; then
        if [[ "$docs_result" -eq 0 ]]; then
            print_pass "docs validation: PASSED"
            ((passed_checks++))
        else
            print_fail "docs validation: FAILED"
        fi
        ((total_checks++))
    fi
    
    echo ""
    if [[ "$passed_checks" -eq "$total_checks" ]]; then
        print_pass "🎉 All CI checks passed! ($passed_checks/$total_checks)"
        exit 0
    else
        print_fail "❌ Some CI checks failed ($passed_checks/$total_checks passed)"
        exit 1
    fi
}

# Run main function
main "$@"
