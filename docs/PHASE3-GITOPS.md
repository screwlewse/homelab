# Phase 3: GitOps & CI/CD Pipeline

## Overview

Phase 3 implements a complete GitOps workflow using ArgoCD for declarative application deployment and GitHub Actions for CI/CD automation.

## Components Deployed

| Component | Technology | Port | Purpose |
|-----------|------------|------|---------|
| **ArgoCD** | GitOps Engine | 30808 | Declarative application deployment |
| **Sample App** | Guestbook | N/A | GitOps workflow demonstration |
| **CI/CD Workflows** | GitHub Actions | N/A | Automated build & deployment |

## ArgoCD Access

### Web Interface
- **URL**: http://10.0.0.88:30808
- **Username**: admin  
- **Password**: `dxdTdk5soq-0mVS4`

### CLI Access
```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login to ArgoCD
argocd login 10.0.0.88:30808 --username admin --password dxdTdk5soq-0mVS4 --insecure
```

## GitOps Workflow

### Repository Structure
```
gitops/
├── apps/                          # ArgoCD Applications
│   ├── app-of-apps.yaml          # Application of Applications
│   └── sample-nginx.yaml         # Sample application
├── environments/                  # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── prod/
└── infrastructure/                # Infrastructure as Code
    ├── networking/
    ├── security/
    └── monitoring/
```

### Application Deployment Flow

1. **Code Commit** → Push to GitHub repository
2. **CI Pipeline** → Build, test, and push images to Harbor
3. **GitOps Update** → Update image tags in GitOps repository
4. **ArgoCD Sync** → Automatically deploy to Kubernetes
5. **Health Check** → Monitor application health and status

## Sample Application

The deployed guestbook application demonstrates the complete GitOps workflow:

```bash
# Check application status
kubectl get applications -n argocd

# View deployed resources
kubectl get all -n sample-apps

# Check application logs
kubectl logs -n sample-apps -l app=guestbook-ui
```

## CI/CD Pipelines

### Application Pipeline (`.github/workflows/ci-cd-pipeline.yaml`)

**Triggers**: Push to main/develop, Pull Requests
**Stages**:
1. **Build** → Docker image build and push to Harbor
2. **Test** → Automated testing and security scans
3. **Deploy Dev** → Auto-deploy to development (develop branch)
4. **Deploy Prod** → Manual approval for production (main branch)

### Infrastructure Pipeline (`.github/workflows/infrastructure.yaml`)

**Triggers**: Changes to manifests/, workflow_dispatch
**Stages**:
1. **Validate** → YAML linting and kubectl dry-run
2. **Deploy** → Infrastructure deployment via Makefile
3. **Verify** → Service accessibility checks

## ArgoCD Applications Management

### Create New Application
```bash
# Via CLI
argocd app create my-app \
  --repo https://github.com/your-org/your-repo \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace my-namespace

# Via YAML
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

### Application Sync Operations
```bash
# Manual sync
argocd app sync my-app

# Refresh application state
argocd app refresh my-app

# View application details
argocd app get my-app

# View sync history
argocd app history my-app
```

## GitOps Best Practices

### Repository Structure
- **Separation of Concerns**: Separate app code from manifests
- **Environment Promotion**: Use branches or directories for environments  
- **Declarative Configuration**: All resources defined as YAML
- **Version Control**: All changes tracked through Git commits

### Application Configuration
- **Automated Sync**: Enable for non-production environments
- **Manual Approval**: Require for production deployments
- **Health Checks**: Monitor application health continuously
- **Rollback Strategy**: Quick rollback via Git revert

## Troubleshooting

### ArgoCD Issues
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# View ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Application Sync Issues
```bash
# Check application status
argocd app get my-app

# View application events
kubectl describe application my-app -n argocd

# Force refresh and sync
argocd app refresh my-app --hard
argocd app sync my-app --force
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Sync Status: OutOfSync | Resource drift | `argocd app sync my-app` |
| Health Status: Degraded | Pod failures | Check pod logs and resource limits |
| Unknown Health | Missing health checks | Add readiness/liveness probes |
| Permission Denied | RBAC issues | Check ArgoCD RBAC configuration |

## Security Considerations

### Current Configuration
- **Insecure Mode**: Enabled for development (HTTP access)
- **Default RBAC**: ArgoCD has cluster-admin permissions
- **No Authentication**: Basic admin/password authentication

### Production Hardening
- **Enable TLS**: Configure HTTPS with valid certificates
- **RBAC**: Implement fine-grained role-based access control
- **SSO Integration**: Connect to corporate identity provider
- **Network Policies**: Restrict ArgoCD network access
- **Secret Management**: Use sealed secrets or external secret stores

## Monitoring & Observability

### ArgoCD Metrics
```bash
# View ArgoCD metrics
kubectl port-forward svc/argocd-metrics 8082:8082 -n argocd
curl http://localhost:8082/metrics
```

### Application Health
- **Health Status**: ArgoCD continuously monitors resource health
- **Sync Status**: Tracks drift between Git and cluster state  
- **History**: Maintains deployment history and rollback capability

## Next Steps (Phase 4)

1. **Prometheus Integration**: Metrics collection and alerting
2. **Grafana Dashboards**: Visual monitoring and observability
3. **Log Aggregation**: Centralized logging with Loki
4. **Advanced GitOps**: ApplicationSets and multi-cluster support
5. **Security Scanning**: Image vulnerability scanning integration

---

**Phase 3 Status**: ✅ Complete  
**GitOps Engine**: ArgoCD deployed and configured  
**Sample Application**: Guestbook app deployed via GitOps  
**CI/CD Pipelines**: GitHub Actions workflows created