#!/bin/bash

# Automated Git Management for k3s DevOps Pipeline
# Commits and pushes phase completion changes with proper documentation

set -euo pipefail
IFS=$'\n\t'

# Enable debug mode if DEBUG is set
[[ "${DEBUG:-}" == "true" ]] && set -x

# Script metadata
readonly SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Trap errors
trap 'echo "Error on line $LINENO"' ERR

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output (only if terminal supports it)
if [[ -t 1 ]]; then
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[0;34m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m'
else
    readonly GREEN=''
    readonly BLUE=''
    readonly YELLOW=''
    readonly NC=''
fi

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

log_error() {
    echo -e "${YELLOW}❌ $*${NC}" >&2
    exit 1
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <phase_name> <phase_description>"
    echo ""
    echo "Examples:"
    echo "  $0 \"phase4\" \"Complete Phase 4 monitoring and observability implementation\""
    echo "  $0 \"automation\" \"Add complete Terraform automation and deployment scripts\""
    echo ""
    exit 1
}

# Check arguments
if [[ $# -lt 2 ]]; then
    show_usage
fi

readonly PHASE_NAME="$1"
readonly PHASE_DESCRIPTION="$2"

# Validate phase name and description
[[ -n "$PHASE_NAME" ]] || log_error "Phase name cannot be empty"
[[ -n "$PHASE_DESCRIPTION" ]] || log_error "Phase description cannot be empty"

cd "$PROJECT_ROOT" || log_error "Failed to change directory to $PROJECT_ROOT"

echo "🔄 Git Management - Phase Completion"
echo "====================================="
echo ""

# Check if we're in a git repository
git rev-parse --git-dir >/dev/null 2>&1 || log_error "Not in a git repository"

log_info "Phase: $PHASE_NAME"
log_info "Description: $PHASE_DESCRIPTION"
echo ""

# Check git status
log_info "Checking git status..."
git status --porcelain

if [[ -z "$(git status --porcelain)" ]]; then
    log_warning "No changes to commit"
    exit 0
fi

# Show changes to be committed
echo ""
log_info "Changes to be committed:"
echo "------------------------"
git diff --name-only HEAD
echo ""

# Stage all changes
log_info "Staging changes..."
git add . || log_error "Failed to stage changes"

# Generate file change summary
FILE_CHANGES=$(git diff --cached --name-only | while IFS= read -r file; do
    case "$file" in
        *.tf) echo "- Add Terraform configuration: $file" ;;
        *.yaml|*.yml) echo "- Add Kubernetes manifest: $file" ;;
        *.sh) echo "- Add automation script: $file" ;;
        *.md) echo "- Add documentation: $file" ;;
        *) echo "- Update: $file" ;;
    esac
done)

# Commit with proper message format
readonly COMMIT_MESSAGE="feat: $PHASE_DESCRIPTION

$FILE_CHANGES

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

log_info "Creating commit..."
if git commit -m "$COMMIT_MESSAGE"; then
    log_success "Commit created successfully"
    
    # Get commit hash for reference
    readonly COMMIT_HASH=$(git rev-parse --short HEAD)
    log_info "Commit hash: $COMMIT_HASH"
else
    log_warning "Commit failed"
    exit 1
fi

# Push changes
echo ""
log_info "Pushing changes to remote repository..."
if git push; then
    log_success "Changes pushed successfully"
    
    # Show remote URL for reference
    readonly REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "No remote configured")
    log_info "Repository: $REMOTE_URL"
else
    log_warning "Push failed - you may need to push manually"
    exit 1
fi

echo ""
log_success "🎉 Phase '$PHASE_NAME' changes committed and pushed successfully!"

# Create git tag for major phases
if [[ "$PHASE_NAME" =~ ^phase[0-9]+$ ]]; then
    readonly TAG_NAME="v1.0-$PHASE_NAME"
    
    echo ""
    log_info "Creating git tag: $TAG_NAME"
    
    if git tag -a "$TAG_NAME" -m "Complete $PHASE_DESCRIPTION"; then
        log_success "Tag created: $TAG_NAME"
        
        if git push origin "$TAG_NAME"; then
            log_success "Tag pushed to remote"
        else
            log_warning "Tag push failed - you may need to push tags manually"
        fi
    else
        log_warning "Tag creation failed (may already exist)"
    fi
fi

echo ""
echo "📝 Git Summary:"
echo "--------------"
echo "  Commit: ${COMMIT_HASH:-unknown}"
echo "  Branch: $(git branch --show-current 2>/dev/null || echo "unknown")"
echo "  Remote: ${REMOTE_URL:-unknown}"
if [[ -n "${TAG_NAME:-}" ]]; then
    echo "  Tag:    $TAG_NAME"
fi

echo ""
log_success "Git operations completed successfully!"