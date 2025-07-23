#!/bin/bash

# Setup pre-commit hooks for k8s-devops-pipeline
# This script installs pre-commit and configures all hooks

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

# Trap errors
trap 'error "Script failed on line $LINENO"' ERR

# Change to project root
cd "$PROJECT_ROOT" || error "Failed to change to project root"

info "🔧 Setting up pre-commit hooks for k8s-devops-pipeline"
info "====================================================="

# Check Python version
info "Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    info "Python version: $PYTHON_VERSION"
else
    error "Python 3 is required but not found. Please install Python 3.8 or later."
fi

# Install pre-commit
info "Installing pre-commit..."
if command -v pre-commit &> /dev/null; then
    info "pre-commit is already installed: $(pre-commit --version)"
else
    pip3 install --user pre-commit || error "Failed to install pre-commit"
    info "pre-commit installed successfully"
fi

# Install additional tools required by hooks
info "Installing additional linting tools..."

# Install shellcheck if not present
if ! command -v shellcheck &> /dev/null; then
    warn "shellcheck not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install shellcheck || warn "Failed to install shellcheck via brew"
    else
        sudo apt-get update && sudo apt-get install -y shellcheck || warn "Failed to install shellcheck via apt"
    fi
fi

# Install terraform if not present
if ! command -v terraform &> /dev/null; then
    warn "Terraform not found. Please install Terraform manually."
    warn "Visit: https://www.terraform.io/downloads"
fi

# Install tflint
if ! command -v tflint &> /dev/null; then
    info "Installing tflint..."
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash || warn "Failed to install tflint"
fi

# Install tfsec
if ! command -v tfsec &> /dev/null; then
    info "Installing tfsec..."
    curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash || warn "Failed to install tfsec"
fi

# Install yamllint
info "Installing yamllint..."
pip3 install --user yamllint || warn "Failed to install yamllint"

# Install markdownlint-cli
if ! command -v markdownlint &> /dev/null; then
    info "Installing markdownlint-cli..."
    if command -v npm &> /dev/null; then
        npm install -g markdownlint-cli || warn "Failed to install markdownlint-cli"
    else
        warn "npm not found. Skipping markdownlint-cli installation."
    fi
fi

# Install gitlint
info "Installing gitlint..."
pip3 install --user gitlint || warn "Failed to install gitlint"

# Install detect-secrets
info "Installing detect-secrets..."
pip3 install --user detect-secrets || warn "Failed to install detect-secrets"

# Initialize detect-secrets baseline
if [[ ! -f ".secrets.baseline" ]]; then
    info "Creating detect-secrets baseline..."
    detect-secrets scan --baseline .secrets.baseline || warn "Failed to create secrets baseline"
fi

# Install pre-commit hooks
info "Installing pre-commit hooks..."
pre-commit install --install-hooks || error "Failed to install pre-commit hooks"

# Install additional git hooks
info "Installing additional git hooks..."
pre-commit install --hook-type commit-msg || warn "Failed to install commit-msg hooks"
pre-commit install --hook-type pre-push || warn "Failed to install pre-push hooks"

# Run pre-commit on all files (optional)
info "Running pre-commit on all files (this may take a while)..."
pre-commit run --all-files || warn "Some pre-commit checks failed. Please review and fix the issues."

info ""
info "✅ Pre-commit setup completed successfully!"
info ""
info "📝 Pre-commit hooks are now active. They will run automatically on:"
info "   - git commit (code formatting, linting, security checks)"
info "   - git push (additional validation)"
info ""
info "🔧 Manual commands:"
info "   - Run all hooks: pre-commit run --all-files"
info "   - Run specific hook: pre-commit run <hook-id>"
info "   - Update hooks: pre-commit autoupdate"
info "   - Skip hooks (emergency): git commit --no-verify"
info ""
info "📋 Installed hooks:"
info "   - Shell script linting (shellcheck)"
info "   - Terraform formatting and validation"
info "   - YAML linting"
info "   - Markdown linting"
info "   - Security scanning (tfsec, detect-secrets)"
info "   - Git commit message linting"
info ""
info "Happy coding! 🚀"