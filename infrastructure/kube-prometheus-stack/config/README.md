# Kube-Prometheus-Stack Configuration

## Sealed Secrets Setup

Before deploying the kube-prometheus-stack, you need to create the sealed secrets for Grafana authentication.

### 1. Grafana Admin Credentials

```bash
# Generate a strong password
GRAFANA_PASSWORD=$(openssl rand -base64 32)

# Create the sealed secret
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$GRAFANA_PASSWORD" \
  --namespace=monitoring \
  --dry-run=client -o yaml | \
  kubeseal -o yaml --controller-name=sealed-secrets-controller --controller-namespace=kube-system > grafana-admin-sealed-secret.yaml

# Save the password securely
echo "Grafana admin password: $GRAFANA_PASSWORD"
```

### 2. Authentik OAuth Integration

First, create an OAuth2/OpenID provider in Authentik:

1. **Login to Authentik**: https://auth.v2.cubancodelab.net
2. **Go to**: Applications → Providers → Create
3. **Provider Type**: OAuth2/OpenID Provider
4. **Settings**:
   - Name: `Grafana`
   - Client Type: `Confidential`
   - Client ID: `grafana`
   - Redirect URIs: `https://monitoring.v2.cubancodelab.net/login/generic_oauth`
   - Signing Key: `authentik Self-signed Certificate`

5. **Advanced Protocol Settings**:
   - Scopes: `openid profile email groups`
   - Subject mode: `Based on the User's hashed ID`

6. **Save** and copy the `Client Secret`

7. **Create Application**:
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: Select the provider created above
   - Policy Engine Mode: `any`

Then create the sealed secret:

```bash
# Replace with actual client secret from Authentik
CLIENT_SECRET="your_authentik_client_secret_here"

kubectl create secret generic grafana-oauth-secret \
  --from-literal=client_secret="$CLIENT_SECRET" \
  --namespace=monitoring \
  --dry-run=client -o yaml | \
  kubeseal -o yaml --controller-name=sealed-secrets-controller --controller-namespace=kube-system > grafana-oauth-sealed-secret.yaml
```

### 3. Deploy the Application

After creating both sealed secrets:

```bash
# Apply the sealed secrets
kubectl apply -f grafana-admin-sealed-secret.yaml
kubectl apply -f grafana-oauth-sealed-secret.yaml

# The ArgoCD application will automatically sync and deploy the stack
```

## Access Points

After deployment:

- **Grafana**: https://monitoring.v2.cubancodelab.net
- **Alertmanager**: https://alertmanager.v2.cubancodelab.net
- **Prometheus**: Accessible via Grafana datasource or port-forward for direct access

## Default Dashboards

The stack includes comprehensive dashboards for:
- Kubernetes cluster overview
- Node metrics (CPU, memory, disk, network)
- Pod and container metrics
- Persistent volume monitoring
- Kubernetes API server metrics
- etcd metrics
- CoreDNS metrics

## Service Monitors

The configuration includes ServiceMonitors for:
- All Kubernetes system components
- Traefik ingress controller
- ArgoCD (if labels match)
- Node exporter
- Kube-state-metrics
- The monitoring stack itself

## Alerts

Default alerting rules are enabled for:
- High CPU/memory usage
- Disk space warnings
- Pod crash loops
- Node not ready conditions
- Certificate expiration warnings
- Kubernetes component health

## Troubleshooting

### Check ArgoCD Application Status
```bash
kubectl get application kube-prometheus-stack -n argocd
```

### Verify Sealed Secrets
```bash
kubectl get secrets -n monitoring | grep grafana
```

### Check Pod Status
```bash
kubectl get pods -n monitoring
```

### View Logs
```bash
# Grafana logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# Prometheus logs  
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```