#!/bin/bash

# Automated Git Management for k3s DevOps Pipeline
# Commits and pushes phase completion changes with proper documentation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
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

PHASE_NAME="$1"
PHASE_DESCRIPTION="$2"

cd "$PROJECT_ROOT"

echo "🔄 Git Management - Phase Completion"
echo "====================================="
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_warning "Not in a git repository"
    exit 1
fi

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
git add .

# Commit with proper message format
COMMIT_MESSAGE="feat: $PHASE_DESCRIPTION

$(git diff --cached --name-only | while IFS= read -r file; do
    case "$file" in
        *.tf) echo "- Add Terraform configuration: $file" ;;
        *.yaml|*.yml) echo "- Add Kubernetes manifest: $file" ;;
        *.sh) echo "- Add automation script: $file" ;;
        *.md) echo "- Add documentation: $file" ;;
        *) echo "- Update: $file" ;;
    esac
done)

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

log_info "Creating commit..."
if git commit -m "$COMMIT_MESSAGE"; then
    log_success "Commit created successfully"
    
    # Get commit hash for reference
    COMMIT_HASH=$(git rev-parse --short HEAD)
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
    REMOTE_URL=$(git remote get-url origin)
    log_info "Repository: $REMOTE_URL"
else
    log_warning "Push failed - you may need to push manually"
    exit 1
fi

echo ""
log_success "🎉 Phase '$PHASE_NAME' changes committed and pushed successfully!"

# Create git tag for major phases
if [[ "$PHASE_NAME" =~ ^phase[0-9]+$ ]]; then
    TAG_NAME="v1.0-$PHASE_NAME"
    
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
echo "  Commit: $COMMIT_HASH"
echo "  Branch: $(git branch --show-current)"
echo "  Remote: $REMOTE_URL"
if [[ -n "$TAG_NAME" ]]; then
    echo "  Tag:    $TAG_NAME"
fi

echo ""
log_success "Git operations completed successfully!"