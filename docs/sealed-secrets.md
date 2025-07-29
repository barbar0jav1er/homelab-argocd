# SealedSecrets Usage Guide

This guide explains how to use SealedSecrets for managing encrypted secrets in the homelab GitOps workflow.

## Overview

SealedSecrets allows you to encrypt Kubernetes secrets that can be safely stored in Git repositories. The sealed-secrets controller running in your cluster can decrypt these secrets.

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

### Method 1: From existing Secret YAML
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
kubeseal -f my-secret.yaml -w my-sealedsecret.yaml

# Clean up the plain secret file
rm my-secret.yaml
```

### Method 2: Direct from literals
```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=password \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > my-sealedsecret.yaml
```

### Method 3: From files
```bash
kubectl create secret generic my-secret \
  --from-file=config.json \
  --from-file=api-key.txt \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > my-sealedsecret.yaml
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
kubectl get pods -n kube-system -l name=sealed-secrets-controller
```

### Check controller logs
```bash
kubectl logs -n kube-system -l name=sealed-secrets-controller
```

### Fetch public certificate
```bash
kubeseal --fetch-cert > public.pem
```

### Encrypt with specific certificate
```bash
kubeseal --cert public.pem -f secret.yaml -w sealedsecret.yaml
```

### Validate SealedSecret format
```bash
kubeseal --validate -f sealedsecret.yaml
```

## Scopes and Security

SealedSecrets supports three scopes:

1. **strict** (default): Secret must be sealed with the same name and namespace
2. **namespace-wide**: Secret can be unsealed in the same namespace with any name
3. **cluster-wide**: Secret can be unsealed anywhere in the cluster

```bash
# Namespace-wide scope
kubeseal --scope namespace-wide -f secret.yaml -w sealedsecret.yaml

# Cluster-wide scope
kubeseal --scope cluster-wide -f secret.yaml -w sealedsecret.yaml
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

## Best Practices

1. **Never commit plain secrets** to Git
2. **Use appropriate scopes** for your security requirements
3. **Backup your encryption keys** regularly
4. **Monitor controller logs** for any decryption issues
5. **Use different secrets for different environments**
6. **Regularly rotate sensitive credentials**