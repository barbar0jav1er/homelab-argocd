# Homelab GitOps with ArgoCD

A complete Kubernetes homelab setup using ArgoCD for GitOps-based infrastructure and application management.

## 🏗️ Architecture

This repository implements an "App of Apps" pattern where:
- **Root App** (`root-app.yaml`) deploys two main applications
- **Infrastructure App** manages core cluster services
- **Applications App** manages user-facing applications

```
root-app.yaml
├── infrastructure/infrastructure-app.yaml
│   ├── sealed-secrets/
│   ├── cert-manager/
│   ├── traefik/
│   ├── metallb/
│   ├── authentik/
│   ├── kube-prometheus-stack/
│   ├── pihole/
│   └── node-setup/
└── apps/apps-app.yaml
    ├── actual-budget/
    ├── media-stack/
    └── nginx/
```

## 📦 Infrastructure Components

### Core Services
- **ArgoCD** - GitOps continuous deployment
- **SealedSecrets** - Encrypted secrets management
- **Cert-Manager** - Automatic SSL certificates via Cloudflare
- **Traefik** - Ingress controller and load balancer
- **MetalLB** - Load balancer for bare metal
- **Authentik** - Identity provider and SSO

### Monitoring & Observability
- **kube-prometheus-stack** - Prometheus, Grafana, Alertmanager
- **Pi-hole** - DNS filtering and ad blocking

### Storage Strategy
Four StorageClasses for different performance needs:

| StorageClass | Type | Capacity | Use Case |
|--------------|------|----------|----------|
| `fast-ssd-critical` | Local SSD | 589GB | Redis, Prometheus TSDB |
| `nfs-ssd-fast` | NFS SSD | 4TB | PostgreSQL, app configs |
| `nfs-hdd-bulk` (default) | NFS HDD | 8TB | Backups, logs, documents |
| `nfs-media-direct` | NFS Direct | ∞ | Media server files |

## 🚀 Applications

### Productivity
- **Actual Budget** - Personal finance management with OIDC
- **Nginx** - Static web hosting

### Media Stack
Complete media management suite:
- **Jellyfin** - Media server
- **Radarr** - Movie collection manager
- **Sonarr** - TV show collection manager
- **Jellyseerr** - Request management
- **Prowlarr** - Indexer manager
- **qBittorrent** - Download client

## 🛠️ Prerequisites

### Cluster Requirements
- Kubernetes cluster (K3s recommended)
- ArgoCD installed and configured
- NFS server for shared storage
- Domain with Cloudflare DNS

### Required Provisioners
```bash
# Local Path Provisioner (usually included in K3s)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# NFS CSI Driver
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace kube-system
```

### NAS Configuration
Configure NFS exports on your NAS:
```bash
/volume1/k3s-ssd    192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/volume2/k3s-hdd    192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/volume2/media      192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```

## 📋 Deployment

### 1. Clone and Configure
```bash
git clone <your-repo>
cd homelab-argocd
```

### 2. Update Configuration
- Edit server IPs in StorageClass manifests (`infrastructure/node-setup/manifests/`)
- Configure your domain in ingress values
- Update Cloudflare API tokens in SealedSecrets

### 3. Create Secrets
Follow the [SealedSecrets guide](docs/sealed-secrets.md):
```bash
# Example: Create Cloudflare API token
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=your-token \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system \
  -o yaml > infrastructure/cert-manager/config/cloudflare-api-token-sealedsecret.yaml
```

### 4. Deploy Root App
```bash
kubectl apply -f root-app.yaml
```

### 5. Monitor Deployment
```bash
# Watch ArgoCD applications
kubectl get applications -n argocd -w

# Check application status
argocd app list
```

## 🔧 Management

### Common Commands
```bash
# Sync all applications
argocd app sync -l app.kubernetes.io/instance=homelab-root

# Check sealed-secrets controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Backup sealed-secrets keys
./bootstrap/backup-sealed-secrets-keys.sh

# View storage classes
kubectl get storageclass
```

### Adding New Applications
1. Create directory under `apps/<app-name>/`
2. Create `application.yaml` following existing patterns
3. Add configuration files and SealedSecrets as needed
4. Use custom charts in `charts/` for complex applications

## 📖 Documentation

- [SealedSecrets Usage Guide](docs/sealed-secrets.md) - Complete guide for managing encrypted secrets
- [Observability Components Guide](docs/observability-components-guide.md) - Future monitoring components
- [Bootstrap Scripts](bootstrap/README.md) - Cluster maintenance scripts

## 🔐 Security Features

- **Encrypted Secrets** - All secrets encrypted with SealedSecrets
- **OIDC Authentication** - Single sign-on via Authentik
- **Automatic SSL** - Let's Encrypt certificates via cert-manager
- **Network Security** - Traefik ingress with proper TLS termination

## 🏠 Homelab Infrastructure

### Compute Nodes

#### Primary Node - cubancodelab3 (10.2.0.22)
- **CPU**: Intel Core i5-1250P (12th Gen) - 16 cores
- **RAM**: 32GB (25GB available)
- **Storage**: 477GB NVMe SSD (100GB allocated to system)
- **Role**: Control plane + Worker node
- **OS**: Ubuntu Server with K3s

#### Secondary Node - cubancodelab2 (10.2.0.21)
- **CPU**: Intel Core i5-6260U @ 1.80GHz - 4 cores
- **RAM**: 24GB (21GB available)
- **Storage**: 112GB SSD
- **Role**: Worker node
- **OS**: Ubuntu Server with K3s

### Storage Infrastructure
- **NAS**: Synology with SSD + HDD tiers
  - `/volume1/k3s-ssd` - 4TB SSD tier for fast storage
  - `/volume2/k3s-hdd` - 8TB HDD tier for bulk storage
  - `/volume2/media` - Direct media access for streaming
- **Local SSD**: 589GB total across nodes for critical workloads

### Network Configuration
- **Cluster Network**: 10.2.0.0/24 VLAN
- **Primary Node**: 10.2.0.22/24
- **Secondary Node**: 10.2.0.21/24
- **NAS**: 10.2.0.20
- **Load Balancing**: MetalLB for bare metal deployments

## 🤝 Contributing

This is a personal homelab setup, but feel free to:
- Open issues for questions
- Submit PRs for improvements
- Use as inspiration for your own setup

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.