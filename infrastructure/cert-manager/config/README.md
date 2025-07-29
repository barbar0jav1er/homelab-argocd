# cert-manager Configuration

This directory contains cert-manager ClusterIssuers and related configuration.

## Prerequisites

Before the ClusterIssuers can work, you need to create the Cloudflare API token secret.

### 1. Get Cloudflare API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use "Custom token" template
4. Configure:
   - **Token name**: `cert-manager-dns`
   - **Permissions**: 
     - Zone:Zone:Read
     - Zone:DNS:Edit
   - **Zone Resources**: 
     - Include All zones (or specific zones you want)

### 2. Create the Secret using SealedSecrets

```bash
# Create the secret (replace YOUR_API_TOKEN with actual token)
kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=YOUR_API_TOKEN \
  --namespace=cert-manager \
  --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system -o yaml > cloudflare-api-token-sealedsecret.yaml

# Apply the SealedSecret
kubectl apply -f cloudflare-api-token-sealedsecret.yaml
```

### 3. Verify ClusterIssuers

After cert-manager and the secret are deployed:

```bash
# Check ClusterIssuers status
kubectl get clusterissuer

# Check specific issuer details
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-prod
```

## Available ClusterIssuers

### letsencrypt-staging
- **Purpose**: Testing certificates
- **Server**: Let's Encrypt Staging
- **Certificates**: Not trusted by browsers (for testing only)
- **Rate Limits**: Very permissive

### letsencrypt-prod  
- **Purpose**: Production certificates
- **Server**: Let's Encrypt Production
- **Certificates**: Trusted by browsers
- **Rate Limits**: Strict (50 certs/week per domain)

### selfsigned-issuer
- **Purpose**: Self-signed certificates for internal use
- **Use case**: Internal services, development

## Example Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls
  issuerRef:
    name: letsencrypt-staging  # Use letsencrypt-prod for production
    kind: ClusterIssuer
  dnsNames:
  - example.cubancodelab.net
  - "*.example.cubancodelab.net"  # Wildcard certificate
```

## Testing Flow

1. **First**: Test with `letsencrypt-staging`
2. **Verify**: Certificate is issued (even if not trusted)
3. **Then**: Switch to `letsencrypt-prod` for trusted certificates

## Troubleshooting

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Check certificate status
kubectl describe certificate your-certificate-name

# Check certificate request
kubectl get certificaterequest
kubectl describe certificaterequest your-cert-request

# Check challenges (for debugging)
kubectl get challenge
kubectl describe challenge your-challenge
```