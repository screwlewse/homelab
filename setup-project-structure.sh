
#!/bin/bash
# setup-project-structure.sh
# Creates the complete directory structure for the DevOps pipeline project

set -euo pipefail

PROJECT_ROOT="$HOME/k8s-devops-pipeline"

create_directory_structure() {
    echo "Creating project directory structure at $PROJECT_ROOT"
    
    # Create main project directory
    mkdir -p "$PROJECT_ROOT"
    cd "$PROJECT_ROOT"
    
    # Create phase-specific directories
    mkdir -p {scripts,configs,backups,docs,logs}
    mkdir -p phases/{phase1,phase2,phase3,phase4,phase5,phase6,phase7}
    
    # Create infrastructure directories
    mkdir -p infrastructure/{argocd,monitoring,networking,storage}
    mkdir -p infrastructure/helm-values/{traefik,harbor,argocd,monitoring}
    
    # Create applications directory
    mkdir -p applications/{test-app,survey-platform}/{base,overlays}
    mkdir -p applications/survey-platform/{backend,frontend,database}
    
    # Create GitOps repository structure
    mkdir -p gitops-repo/{applications,infrastructure,projects}
    mkdir -p gitops-repo/{applications,infrastructure,projects}/{base,overlays}/{development,staging,production}
    mkdir -p gitops-repo/.github/workflows
    
    # Create monitoring and logging directories
    mkdir -p monitoring/{dashboards,alerts,rules}
    mkdir -p logs/{application,infrastructure,pipeline}
    
    echo "Directory structure created successfully"
}

create_initial_files() {
    echo "Creating initial configuration files"
    
    # Create README
    cat > README.md << 'EOF'
# k3s DevOps Pipeline Project

This project sets up a complete DevOps pipeline on a single k3s node with GitOps, monitoring, and automated deployments.

## Quick Start

1. Run Phase 1 foundation setup:
   ```bash
   make phase1
   ```

2. Verify installation:
   ```bash
   make verify-phase1
   ```

3. Check status:
   ```bash
   make status
   ```

## Project Structure

- `scripts/` - Automation scripts for each phase
- `configs/` - Configuration files for infrastructure components
- `infrastructure/` - Infrastructure as Code manifests
- `applications/` - Application deployments and source code
- `gitops-repo/` - GitOps repository structure
- `monitoring/` - Monitoring dashboards and alerts

## Server Details

- Server IP: 10.0.0.88
- MetalLB Range: 10.0.0.200-10.0.0.210
- Access from Mac: All services configured with LoadBalancer IPs

## Phases

1. **Phase 1**: Foundation (k3s, Helm, networking)
2. **Phase 2**: Core Infrastructure (Traefik, Harbor, storage)
3. **Phase 3**: GitOps (ArgoCD, CI/CD pipeline)
4. **Phase 4**: Monitoring (Prometheus, Grafana, logging)
5. **Phase 5**: Pipeline Testing (test application)
6. **Phase 6**: Advanced Integration (ApplicationSets, self-hosted runners)
7. **Phase 7**: Survey Application Development
EOF

    # Create .gitignore
    cat > .gitignore << 'EOF'
# Backup files
backups/
*.backup

# Log files
logs/*.log
*.log

# Temporary files
tmp/
temp/
.tmp/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Sensitive files
secrets/
*.key
*.pem
*-key.yaml

# Helm charts cache
charts/
*.tgz

# Local environment files
.env
.env.local
EOF

    # Create project configuration
    cat > project-config.sh << 'EOF'
#!/bin/bash
# project-config.sh
# Central configuration for the DevOps pipeline project

# Server configuration
export SERVER_IP="10.0.0.88"
export METALLB_IP_RANGE="10.0.0.200-10.0.0.210"

# Project paths
export PROJECT_ROOT="$HOME/k8s-devops-pipeline"
export KUBECONFIG="$HOME/.kube/config"

# Application configuration
export HARBOR_ADMIN_PASSWORD="Harbor12345"
export GRAFANA_ADMIN_PASSWORD="grafana123"
export ARGOCD_NAMESPACE="argocd"
export MONITORING_NAMESPACE="monitoring"

# GitHub configuration (update these)
export GITHUB_USERNAME="yourusername"
export GITHUB_REPO="k8s-devops-pipeline"
export GITHUB_GITOPS_REPO="gitops-repo"

# Helm configuration
export HELM_CACHE_HOME="$PROJECT_ROOT/.helm/cache"
export HELM_CONFIG_HOME="$PROJECT_ROOT/.helm/config"
export HELM_DATA_HOME="$PROJECT_ROOT/.helm/data"

echo "Project configuration loaded"
echo "Server IP: $SERVER_IP"
echo "MetalLB Range: $METALLB_IP_RANGE"
echo "Project Root: $PROJECT_ROOT"
EOF

    chmod +x project-config.sh
    
    echo "Initial files created successfully"
}

display_structure() {
    echo
    echo "Project directory structure:"
    tree "$PROJECT_ROOT" 2>/dev/null || find "$PROJECT_ROOT" -type d | sort
    echo
    echo "Project created at: $PROJECT_ROOT"
    echo "Next steps:"
    echo "1. cd $PROJECT_ROOT"
    echo "2. source project-config.sh"
    echo "3. make phase1"
}

main() {
    create_directory_structure
    create_initial_files
    display_structure
}

main "$@"
