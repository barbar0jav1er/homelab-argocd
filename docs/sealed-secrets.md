# SealedSecrets Usage Guide

This guide explains how to use SealedSecrets for managing encrypted secrets in the homelab GitOps workflow.

## Overview

SealedSecrets allows you to encrypt Kubernetes secrets that can be safely stored in Git repositories. The sealed-secrets controller running in your cluster can decrypt these secrets.

## Homelab Configuration Note

⚠️ **Important**: This homelab uses a custom SealedSecrets deployment via Helm. When using `kubeseal` commands, you must specify:
- `--controller-name=sealed-secrets`
- `--controller-namespace=kube-system`

All examples in this guide include these parameters for this specific setup.

## Installing kubeseal CLI

### macOS (Homebrew)
```bash
brew install kubeseal
```

### Linux
```bash
KUBESEAL_VERSION='0.24.0'
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

## Creating SealedSecrets

**Important**: When using this homelab setup, you must specify the controller name and namespace:

### Method 1: Direct from literals (Recommended)
```bash
# Database credentials example
kubectl create secret generic database-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret123 \
  --from-literal=host=postgres.homelab.local \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > database-sealedsecret.yaml

# Apply the SealedSecret
kubectl apply -f database-sealedsecret.yaml
```

### Method 2: API Keys and Tokens
```bash
# API keys example
kubectl create secret generic api-secrets \
  --from-literal=github-token=ghp_xxxxxxxxxxxx \
  --from-literal=slack-webhook=https://hooks.slack.com/services/xxx \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > api-sealedsecret.yaml
```

### Method 3: From files
```bash
# Configuration files example
kubectl create secret generic app-config \
  --from-file=config.json \
  --from-file=.env \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > config-sealedsecret.yaml
```

### Method 4: TLS Certificates
```bash
# TLS certificate example
kubectl create secret tls tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > tls-sealedsecret.yaml
```

### Method 5: From existing Secret YAML
```bash
# Create a regular secret file first
cat <<EOF > my-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
data:
  username: YWRtaW4=  # admin in base64
  password: cGFzc3dvcmQ=  # password in base64
EOF

# Convert to SealedSecret
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -f my-secret.yaml -w my-sealedsecret.yaml

# Clean up the plain secret file
rm my-secret.yaml
```

## Example SealedSecrets

### Database Credentials
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  encryptedData:
    username: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    password: AiBhjGFjbVmkiCUyCY4PKjPgFjDEQAx...
  template:
    metadata:
      name: database-credentials
      namespace: production
    type: Opaque
```

### API Keys
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: api-keys
  namespace: default
spec:
  encryptedData:
    github-token: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    slack-webhook: AiBhjGFjbVmkiCUyCY4PKjPgFjDEQAx...
  template:
    metadata:
      name: api-keys
      namespace: default
    type: Opaque
```

### TLS Certificate
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: tls-secret
  namespace: ingress-nginx
spec:
  encryptedData:
    tls.crt: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    tls.key: AiBhjGFjbVmkiCUyCY4PKjPgFjDEQAx...
  template:
    metadata:
      name: tls-secret
      namespace: ingress-nginx
    type: kubernetes.io/tls
```

## Useful Commands

### Verify controller is running
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### Check controller logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### Fetch public certificate
```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --fetch-cert > public.pem
```

### Encrypt with specific certificate
```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --cert public.pem -f secret.yaml -w sealedsecret.yaml
```

### Validate SealedSecret format
```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --validate -f sealedsecret.yaml
```

## Scopes and Security

SealedSecrets supports three scopes:

1. **strict** (default): Secret must be sealed with the same name and namespace
2. **namespace-wide**: Secret can be unsealed in the same namespace with any name
3. **cluster-wide**: Secret can be unsealed anywhere in the cluster

```bash
# Namespace-wide scope
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --scope namespace-wide -f secret.yaml -w sealedsecret.yaml

# Cluster-wide scope  
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --scope cluster-wide -f secret.yaml -w sealedsecret.yaml
```

## Key Management

### Key Rotation
Keys are automatically rotated every 30 days. Old keys are kept for decryption of existing secrets.

### Manual Key Rotation (Emergency)
```bash
kubectl delete secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

### Backup Keys
```bash
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-keys.yaml
```

## Key Backup and Restore

### Automated Backup Script
Use the provided bootstrap script to backup your SealedSecrets keys:

```bash
# Backup keys to default location
./bootstrap/backup-sealed-secrets-keys.sh

# Backup to custom directory
BACKUP_DIR=/secure/backup ./bootstrap/backup-sealed-secrets-keys.sh
```

### Automated Restore Script
Restore keys from backup when recovering a cluster:

```bash
# Interactive restore
./bootstrap/restore-sealed-secrets-keys.sh ./sealed-secrets-backup/sealed-secrets-keys-latest.yaml

# Force restore (skip confirmations)
./bootstrap/restore-sealed-secrets-keys.sh ./sealed-secrets-backup/sealed-secrets-keys-20240129-143022.yaml --force
```

### Manual Key Management
```bash
# Manual backup
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-keys.yaml

# Manual restore
kubectl apply -f sealed-secrets-keys.yaml
kubectl rollout restart deployment/sealed-secrets-controller -n kube-system
```

## Best Practices

1. **Never commit plain secrets** to Git
2. **Use appropriate scopes** for your security requirements
3. **Backup your encryption keys** regularly using the provided scripts
4. **Store key backups securely** outside the cluster
5. **Test restore procedures** periodically
6. **Monitor controller logs** for any decryption issues
7. **Use different secrets for different environments**
8. **Regularly rotate sensitive credentials**