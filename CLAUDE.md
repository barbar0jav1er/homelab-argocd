# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an ArgoCD-based GitOps repository for managing a homelab Kubernetes infrastructure. The repository follows a three-tier "App of Apps" pattern for comprehensive application lifecycle management, from core infrastructure to user applications.

## Architecture

### Three-Tier App of Apps Structure
- **`root-app.yaml`**: Root ArgoCD Application managing infrastructure and application tiers
- **`infrastructure/infrastructure-app.yaml`**: Core platform services (MetalLB, Traefik, Cert-Manager, Authentik, etc.)
- **`apps/apps-app.yaml`**: User applications (Actual Budget, Media Stack, etc.)
- Uses automated sync with prune, self-heal, and proper sync wave ordering

### Current Infrastructure Stack

#### Core Platform Services
- **MetalLB** (v0.14.5): Load balancer with L2 advertisement (IP range: 10.2.0.50-10.2.0.85)
- **Traefik** (v32.1.0): Ingress controller at 10.2.0.80 with TLS termination
- **Cert-Manager** (v1.16.2): Automated TLS certificates via Let's Encrypt + Cloudflare DNS
- **Sealed Secrets** (v2.16.2): Encrypted secrets management in kube-system namespace
- **Authentik** (v2025.6.4): Identity provider with PostgreSQL/Redis backend
- **Node Setup**: Cluster prerequisites via DaemonSet (sync-wave: -1)

#### User Applications
- **Actual Budget**: Personal finance app with Authentik OpenID Connect integration
- **Media Stack**: Complete media management (Jellyfin, Radarr, Sonarr, Jellyseerr, Prowlarr, qBittorrent)
- **Development Services**: Nginx for testing homelab-app chart patterns

### Security and Secret Management

#### Sealed Secrets Implementation
- **Controller**: Bitnami Sealed Secrets in kube-system namespace
- **Backup/Restore**: Comprehensive scripts in `/bootstrap/` directory
- **Current Secrets**: Authentik, Actual Budget OpenID, Media Stack, Cert-Manager Cloudflare
- **Documentation**: Complete guide with examples in `/bootstrap/sealed-secrets/`

#### TLS and Certificate Management
- **Automated TLS**: All services use Let's Encrypt certificates
- **DNS Challenge**: Cloudflare DNS01 solver for wildcard certificates
- **Domain Strategy**: Primary domain `cubancodelab.net` with service subdomains

### Storage and Network Configuration

#### Network Setup
- **Load Balancer**: MetalLB L2 advertisement (10.2.0.50-10.2.0.85)
- **Ingress**: Traefik at 10.2.0.80 with automated TLS
- **DNS**: Cloudflare integration for certificate challenges

#### Storage Patterns
- **NFS**: Media stack using external NFS server (10.2.0.20:/volume2/media, 10Ti)
- **HostPath**: Actual Budget local storage (/opt/actual-budget)
- **PVC**: Database persistence for PostgreSQL and Redis

### Authentication and Identity Management

#### Authentik Integration
- **Identity Provider**: Centralized authentication at auth.cubancodelab.net
- **OpenID Connect**: Integrated with Actual Budget for multi-user support
- **Backend**: PostgreSQL database with Redis caching
- **Recent Upgrade**: Updated from 2024.8.3 to 2025.6.4 with values restructuring

### Observability and Monitoring

#### Monitoring Stack
- **kube-prometheus-stack**: Prometheus, Grafana, Alertmanager with automated monitoring
- **Metrics Collection**: Node exporter, Kube-state-metrics, service monitors
- **Dashboards**: Comprehensive Kubernetes monitoring via Grafana at monitoring.cubancodelab.net
- **Alerting**: Alertmanager for notifications at alertmanager.cubancodelab.net
- **Storage**: 30-day retention with 50GB storage for Prometheus metrics

#### DNS and Network Services
- **Pi-hole**: DNS sinkhole and ad-blocking at pihole.cubancodelab.net (IP: 10.2.0.53)
- **dnscrypt-proxy**: Secure upstream DNS via Cloudflare DoH/DoT sidecar
- **Custom Helm Chart**: Fully integrated Pi-hole with monitoring and TLS

### GitOps Patterns and Best Practices

#### Deployment Strategies
- **Sync Waves**: Proper ordering (-1: prerequisites, 1: core infra, 2: applications)
- **Multi-source Applications**: Helm charts with Git-based custom values
- **Directory Filtering**: Selective deployment using `include` patterns
- **Automated Sync**: Self-healing with prune enabled across all applications

#### Repository Organization
- **Infrastructure**: `/infrastructure/[service]/application.yaml` pattern
- **User Apps**: `/apps/[service]/application.yaml` pattern  
- **Custom Charts**: `/charts/[service]/` for custom Helm charts
- **Configuration**: `config/` subdirectories for additional manifests
- **Documentation**: Service-specific docs and operational guides

## Common Operations

### Deploying New Infrastructure Services
1. Create `/infrastructure/[service-name]/application.yaml`
2. Add Helm `values.yaml` if using external charts
3. Create `config/` subdirectory for additional Kubernetes manifests
4. Use appropriate sync waves for deployment ordering
5. Configure sealed secrets if credentials are required

### Deploying New User Applications
1. Create `/apps/[service-name]/application.yaml`
2. For custom apps, develop Helm chart in `/charts/[service-name]/`
3. Configure ingress with TLS and appropriate subdomain
4. Set up authentication integration with Authentik if needed
5. Configure persistent storage (NFS, hostPath, or PVC)

### Secret Management Workflow
1. Create secrets using kubeseal with proper controller configuration
2. Place sealed secrets in `config/` subdirectories
3. Reference secrets in deployment templates or values files
4. Use backup scripts in `/bootstrap/sealed-secrets/` for disaster recovery

### Certificate and TLS Management
- All services automatically get TLS certificates via cert-manager
- Use `cert-manager.io/cluster-issuer: "letsencrypt-prod"` annotation
- Wildcard certificates managed via Cloudflare DNS challenges
- TLS secrets automatically created and renewed

### Media Stack Management
- Uses custom Helm chart combining multiple media applications
- NFS storage backend for media files (10Ti capacity)
- All services integrated with common authentication
- Automated updates via image tag management

## Claude Code Rules

- **NEVER commit CLAUDE.md**: This file should remain local and not be committed to the repository
- **NEVER add CLAUDE.md to git stage**: Use `git add` only on specific files, never `git add .` or include CLAUDE.md
- **NO AI references in commits**: NEVER mention "Claude", "Claude Code", "AI", "Generated", or any AI-related terms in commit messages
- **Use standard commit format**: Write professional commit messages without AI footers or signatures
- **Generic commit messages**: Use terms like "update configuration", "improve setup", "refactor structure", etc.

## Git Repository Configuration

- **Repository URL Format**: This repository uses SSH authentication for Git operations
- **SSH URL**: `git@github.com:barbar0jav1er/homelab-argocd.git`
- **HTTPS URL**: `https://github.com/barbar0jav1er/homelab-argocd.git`
- **ArgoCD Applications**: ALWAYS use the SSH format (`git@github.com:barbar0jav1er/homelab-argocd.git`) in ArgoCD application source configurations
- **Multi-source Applications**: When using multi-source applications, ensure the values source also uses SSH format

