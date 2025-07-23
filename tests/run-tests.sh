#!/bin/bash

# Run all tests for k8s-devops-pipeline
# This script orchestrates running unit, integration, and e2e tests

set -euo pipefail
IFS=$'\n\t'

# Enable debug mode if DEBUG is set
[[ "${DEBUG:-}" == "true" ]] && set -x

# Script metadata
readonly SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Logging functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $*"; }
error() { log "ERROR: $*" >&2; exit 1; }
warn() { log "WARNING: $*" >&2; }
info() { log "INFO: $*"; }
success() { log "SUCCESS: $*"; }

# Test configuration
TEST_TYPE="${1:-all}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

# Trap errors
trap 'error "Script failed on line $LINENO"' ERR

# Initialize test results directory
init_test_results() {
    info "Initializing test results directory..."
    mkdir -p "$TEST_RESULTS_DIR"/{unit,integration,e2e,bats}
}

# Run BATS tests for shell scripts
run_bats_tests() {
    info "Running BATS tests for shell scripts..."
    
    if ! command -v bats &> /dev/null; then
        warn "BATS not installed. Skipping shell script tests."
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Run BATS tests
    if bats tests/bats/*.bats --formatter tap > "$TEST_RESULTS_DIR/bats/results.tap"; then
        success "BATS tests passed"
        return 0
    else
        warn "Some BATS tests failed"
        return 1
    fi
}

# Run Terraform unit tests
run_terraform_tests() {
    info "Running Terraform unit tests..."
    
    if ! command -v go &> /dev/null; then
        warn "Go not installed. Skipping Terraform unit tests."
        return 0
    fi
    
    cd "$PROJECT_ROOT/tests/unit"
    
    # Initialize Go modules if needed
    if [[ ! -f "go.mod" ]]; then
        info "Initializing Go modules..."
        go mod init github.com/screwlewse/k8s-devops-pipeline/tests
        go get github.com/gruntwork-io/terratest/modules/terraform
        go get github.com/stretchr/testify/assert
        go get github.com/stretchr/testify/require
    fi
    
    # Run tests
    if go test -v -timeout 30m -parallel 4 | tee "$TEST_RESULTS_DIR/unit/terraform.log"; then
        success "Terraform unit tests passed"
        return 0
    else
        warn "Some Terraform unit tests failed"
        return 1
    fi
}

# Run Python integration tests
run_integration_tests() {
    info "Running integration tests..."
    
    if ! command -v python3 &> /dev/null; then
        warn "Python3 not installed. Skipping integration tests."
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Install requirements
    if [[ ! -f "tests/requirements.txt" ]]; then
        cat > tests/requirements.txt << EOF
requests>=2.31.0
pyyaml>=6.0
kubernetes>=29.0.0
pytest>=7.4.0
pytest-timeout>=2.2.0
pytest-xdist>=3.5.0
EOF
    fi
    
    # Create virtual environment if needed
    if [[ ! -d "tests/.venv" ]]; then
        info "Creating Python virtual environment..."
        python3 -m venv tests/.venv
    fi
    
    # Activate virtual environment and install dependencies
    source tests/.venv/bin/activate
    pip install -q -r tests/requirements.txt
    
    # Run integration tests
    if python -m pytest tests/integration/k8s_test.py -v --tb=short \
        --junit-xml="$TEST_RESULTS_DIR/integration/pytest-results.xml"; then
        success "Integration tests passed"
        deactivate
        return 0
    else
        warn "Some integration tests failed"
        deactivate
        return 1
    fi
}

# Run infrastructure validation
run_infrastructure_validation() {
    info "Running infrastructure validation..."
    
    if [[ -x "$PROJECT_ROOT/terraform/tests/validate-infrastructure.sh" ]]; then
        if "$PROJECT_ROOT/terraform/tests/validate-infrastructure.sh" > "$TEST_RESULTS_DIR/infrastructure-validation.log" 2>&1; then
            success "Infrastructure validation passed"
            return 0
        else
            warn "Infrastructure validation failed"
            return 1
        fi
    else
        warn "Infrastructure validation script not found or not executable"
        return 1
    fi
}

# Run security tests
run_security_tests() {
    info "Running security tests..."
    
    local security_issues=0
    
    # Check for hardcoded secrets
    info "Checking for hardcoded secrets..."
    if grep -r -i -E "password.*=.*['\"].*['\"]|secret.*=.*['\"].*['\"]|api[_-]?key.*=.*['\"].*['\"]" \
        --include="*.yaml" --include="*.yml" --include="*.tf" --include="*.sh" \
        --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir=".terraform" \
        "$PROJECT_ROOT" 2>/dev/null | grep -v -E "(example|sample|test|spec|variable|tfvars)"; then
        warn "Found potential hardcoded secrets"
        ((security_issues++))
    else
        success "No hardcoded secrets found"
    fi
    
    # Run tfsec if available
    if command -v tfsec &> /dev/null; then
        info "Running tfsec security scan..."
        if tfsec "$PROJECT_ROOT/terraform" --format json --soft-fail > "$TEST_RESULTS_DIR/tfsec-results.json"; then
            success "tfsec scan completed"
        else
            warn "tfsec found security issues"
            ((security_issues++))
        fi
    fi
    
    return $security_issues
}

# Generate test report
generate_test_report() {
    info "Generating test report..."
    
    cat > "$TEST_RESULTS_DIR/test-report.md" << EOF
# Test Report

**Date**: $(date)
**Project**: k8s-devops-pipeline

## Test Summary

| Test Type | Status | Details |
|-----------|--------|---------|
| BATS (Shell Scripts) | ${BATS_STATUS:-N/A} | [View Results](bats/results.tap) |
| Terraform Unit Tests | ${TERRAFORM_STATUS:-N/A} | [View Log](unit/terraform.log) |
| Integration Tests | ${INTEGRATION_STATUS:-N/A} | [View Results](integration/pytest-results.xml) |
| Infrastructure Validation | ${INFRA_STATUS:-N/A} | [View Log](infrastructure-validation.log) |
| Security Tests | ${SECURITY_STATUS:-N/A} | [View Results](tfsec-results.json) |

## Overall Status: ${OVERALL_STATUS:-UNKNOWN}

### Test Execution Time
- Start: $TEST_START_TIME
- End: $(date)
- Duration: $SECONDS seconds

### Environment
- Kubernetes: $(kubectl version --short 2>/dev/null | grep Server || echo "Not available")
- Go: $(go version 2>/dev/null || echo "Not installed")
- Python: $(python3 --version 2>/dev/null || echo "Not installed")
- Terraform: $(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo "Not installed")

### Recommendations
EOF

    if [[ "$OVERALL_STATUS" == "FAILED" ]]; then
        echo "- Review failed tests and fix issues before deployment" >> "$TEST_RESULTS_DIR/test-report.md"
        echo "- Check individual test logs for detailed error messages" >> "$TEST_RESULTS_DIR/test-report.md"
    else
        echo "- All tests passed successfully" >> "$TEST_RESULTS_DIR/test-report.md"
        echo "- Code is ready for deployment" >> "$TEST_RESULTS_DIR/test-report.md"
    fi
    
    success "Test report generated: $TEST_RESULTS_DIR/test-report.md"
}

# Main execution
main() {
    TEST_START_TIME=$(date)
    OVERALL_STATUS="PASSED"
    
    info "🧪 Starting test suite for k8s-devops-pipeline"
    info "Test type: $TEST_TYPE"
    
    # Initialize test results
    init_test_results
    
    # Run tests based on type
    case "$TEST_TYPE" in
        bats|shell)
            if run_bats_tests; then
                BATS_STATUS="✅ PASSED"
            else
                BATS_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            ;;
        terraform|unit)
            if run_terraform_tests; then
                TERRAFORM_STATUS="✅ PASSED"
            else
                TERRAFORM_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            ;;
        integration)
            if run_integration_tests; then
                INTEGRATION_STATUS="✅ PASSED"
            else
                INTEGRATION_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            ;;
        infrastructure|infra)
            if run_infrastructure_validation; then
                INFRA_STATUS="✅ PASSED"
            else
                INFRA_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            ;;
        security)
            if run_security_tests; then
                SECURITY_STATUS="✅ PASSED"
            else
                SECURITY_STATUS="⚠️ WARNINGS"
            fi
            ;;
        all)
            # Run all tests
            if run_bats_tests; then
                BATS_STATUS="✅ PASSED"
            else
                BATS_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            
            if run_terraform_tests; then
                TERRAFORM_STATUS="✅ PASSED"
            else
                TERRAFORM_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            
            if run_integration_tests; then
                INTEGRATION_STATUS="✅ PASSED"
            else
                INTEGRATION_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            
            if run_infrastructure_validation; then
                INFRA_STATUS="✅ PASSED"
            else
                INFRA_STATUS="❌ FAILED"
                OVERALL_STATUS="FAILED"
            fi
            
            if run_security_tests; then
                SECURITY_STATUS="✅ PASSED"
            else
                SECURITY_STATUS="⚠️ WARNINGS"
            fi
            ;;
        *)
            error "Unknown test type: $TEST_TYPE"
            ;;
    esac
    
    # Generate test report
    generate_test_report
    
    # Summary
    info ""
    info "📊 Test Summary"
    info "=============="
    info "Overall Status: $OVERALL_STATUS"
    info "Test Results: $TEST_RESULTS_DIR/"
    info "Report: $TEST_RESULTS_DIR/test-report.md"
    
    if [[ "$OVERALL_STATUS" == "FAILED" ]]; then
        error "Some tests failed. Please review the results."
    else
        success "All tests passed! 🎉"
    fi
}

# Show usage
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [test-type]"
    echo ""
    echo "Test types:"
    echo "  all          - Run all tests (default)"
    echo "  bats|shell   - Run BATS tests for shell scripts"
    echo "  terraform|unit - Run Terraform unit tests"
    echo "  integration  - Run integration tests"
    echo "  infrastructure|infra - Run infrastructure validation"
    echo "  security     - Run security tests"
    echo ""
    echo "Environment variables:"
    echo "  DEBUG=true   - Enable debug output"
    echo "  SKIP_CLEANUP=true - Skip cleanup after tests"
    echo ""
    exit 0
fi

# Run main function
main "$@"