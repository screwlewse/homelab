#!/usr/bin/env bats

# BATS tests for shell scripts in k8s-devops-pipeline

# Test helper functions
setup() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PATH="$PROJECT_ROOT/scripts:$PATH"
}

# Test deploy-monitoring.sh
@test "deploy-monitoring.sh exists and is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy-monitoring.sh" ]
}

@test "deploy-monitoring.sh has proper error handling" {
    grep -q "set -euo pipefail" "$PROJECT_ROOT/scripts/deploy-monitoring.sh"
}

@test "deploy-monitoring.sh has logging functions" {
    grep -q "^log()" "$PROJECT_ROOT/scripts/deploy-monitoring.sh"
    grep -q "^error()" "$PROJECT_ROOT/scripts/deploy-monitoring.sh"
    grep -q "^warn()" "$PROJECT_ROOT/scripts/deploy-monitoring.sh"
    grep -q "^info()" "$PROJECT_ROOT/scripts/deploy-monitoring.sh"
}

@test "deploy-monitoring.sh validates prerequisites" {
    grep -q "command -v kubectl" "$PROJECT_ROOT/scripts/deploy-monitoring.sh"
}

# Test verify-monitoring.sh
@test "verify-monitoring.sh exists and is executable" {
    [ -x "$PROJECT_ROOT/scripts/verify-monitoring.sh" ]
}

@test "verify-monitoring.sh has proper error handling" {
    grep -q "set -euo pipefail" "$PROJECT_ROOT/scripts/verify-monitoring.sh"
}

@test "verify-monitoring.sh has check_url function" {
    grep -q "^check_url()" "$PROJECT_ROOT/scripts/verify-monitoring.sh"
}

# Test commit-phase.sh
@test "commit-phase.sh exists and is executable" {
    [ -x "$PROJECT_ROOT/scripts/commit-phase.sh" ]
}

@test "commit-phase.sh validates arguments" {
    run "$PROJECT_ROOT/scripts/commit-phase.sh"
    [ "$status" -eq 1 ]
}

@test "commit-phase.sh has color support detection" {
    grep -q "if \[\[ -t 1 \]\]" "$PROJECT_ROOT/scripts/commit-phase.sh"
}

# Test validate-infrastructure.sh
@test "validate-infrastructure.sh exists and is executable" {
    [ -x "$PROJECT_ROOT/terraform/tests/validate-infrastructure.sh" ]
}

@test "validate-infrastructure.sh has proper error handling" {
    grep -q "set -euo pipefail" "$PROJECT_ROOT/terraform/tests/validate-infrastructure.sh"
}

# Test all scripts for common patterns
@test "all shell scripts have shebangs" {
    for script in "$PROJECT_ROOT"/scripts/*.sh "$PROJECT_ROOT"/terraform/tests/*.sh; do
        [ -f "$script" ] || continue
        head -n1 "$script" | grep -q "^#!/bin/bash"
    done
}

@test "all shell scripts use proper variable quoting" {
    # Check for unquoted variable usage (basic check)
    for script in "$PROJECT_ROOT"/scripts/*.sh; do
        [ -f "$script" ] || continue
        # This is a simplified check - look for obvious unquoted variables
        ! grep -E '\$[A-Za-z_][A-Za-z0-9_]*[[:space:]]' "$script" || {
            echo "Found potentially unquoted variables in $script"
            false
        }
    done
}

@test "no hardcoded passwords in shell scripts" {
    for script in "$PROJECT_ROOT"/scripts/*.sh; do
        [ -f "$script" ] || continue
        ! grep -i "password.*=" "$script" | grep -v "example\|sample\|PASSWORD_VARIABLE" || {
            echo "Found potential hardcoded password in $script"
            false
        }
    done
}

# Test Makefile
@test "Makefile exists" {
    [ -f "$PROJECT_ROOT/Makefile" ]
}

@test "Makefile has help target" {
    cd "$PROJECT_ROOT" && make -n help
}

@test "Makefile has all critical targets" {
    local targets=("tf-init" "tf-plan" "tf-apply" "tf-test" "deploy-all" "verify" "status")
    for target in "${targets[@]}"; do
        grep -q "^${target}:" "$PROJECT_ROOT/Makefile" || {
            echo "Missing target: $target"
            false
        }
    done
}