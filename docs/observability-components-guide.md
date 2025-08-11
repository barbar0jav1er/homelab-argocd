# Observability Stack - Homelab Implementation

This document covers the current observability implementation and future expansion plans for the homelab cluster.

## ✅ Currently Implemented

### kube-prometheus-stack
**Deployed via ArgoCD** - Complete monitoring foundation

**Components:**
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards  
- **Alertmanager** - Alert routing and notification
- **Node Exporter** - Node-level system metrics
- **Kube State Metrics** - Kubernetes cluster metrics
- **Prometheus Operator** - CRD-based configuration

**Namespace:** `monitoring`  
**Access:** Grafana available via ingress with Authentik SSO

**Current Capabilities:**
- ✅ Cluster resource monitoring (CPU, Memory, Storage)
- ✅ Pod and container metrics
- ✅ Infrastructure component health
- ✅ Custom dashboards for homelab services
- ✅ Persistent storage for metrics data
- ✅ Alert rules for critical issues

## 🔄 Planned Components

### 1. Loki - Log Aggregation

#### What is it?
Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus. It's often described as "Prometheus but for logs".

#### Key Features
- **Efficient indexing**: Only indexes metadata (labels), not full log content
- **Compression**: Excellent compression for similar logs
- **Grafana integration**: Native log visualization alongside metrics
- **Query Language**: LogQL similar to PromQL for log queries
- **Multi-tenancy**: Native support for multiple tenants

#### Practical Use Cases

**Application Debugging:**
```
# Search for errors in actual-budget service
{app="actual-budget"} |= "error" | json | error_level="critical"

# View logs from all media-stack pods in the last 5 minutes
{namespace="media-stack"} [5m]

# Correlate logs with metrics using the same timestamp
```

**Performance Analysis:**
```
# Find slow requests in Traefik
{app="traefik"} | json | response_time > 1000

# Analyze Jellyfin access patterns
{app="jellyfin"} |= "GET" | logfmt | status_code="200"
```

**Security Auditing:**
```
# Detect failed login attempts in Authentik
{app="authentik"} |= "authentication_failed" | json | count_over_time(5m) > 5

# Monitor ArgoCD configuration changes
{app="argocd-server"} |= "configuration_changed"
```

#### Why is it Important?
- **Complete debugging**: Metrics tell you WHAT is happening, logs tell you WHY
- **Troubleshooting**: Essential for resolving complex microservices issues
- **Compliance**: System event auditing and traceability
- **Correlation**: Connect metrics with specific events

#### When to Implement
- When you need advanced application debugging
- When having recurring issues that are hard to diagnose
- For compliance and security auditing
- When the homelab grows to 10+ services

---

### 2. Promtail - Log Collector

#### What is it?
Promtail is the official agent for sending local logs to Loki. It's similar to how node_exporter sends metrics to Prometheus.

#### Key Features
- **Auto-discovery**: Automatically finds logs in Kubernetes
- **Parsing**: Extracts labels and structures from unstructured logs
- **Pipelines**: Log processing and filtering before sending
- **Position tracking**: Doesn't lose logs during restarts

#### Practical Use Cases

**Automatic Collection:**
```yaml
# Configuration to collect logs from all pods
- job_name: kubernetes-pods
  kubernetes_sd_configs:
    - role: pod
  pipeline_stages:
    - docker: {}  # Parser for Docker/containerd logs
```

**Structured Log Parsing:**
```yaml
# For JSON logs from modern applications
- match:
    selector: '{app="actual-budget"}'
  stages:
  - json:
      expressions:
        level: level
        message: message
        timestamp: timestamp
```

**Filtering and Enrichment:**
```yaml
# Add Kubernetes metadata
- match:
    selector: '{job="kubernetes-pods"}'
  stages:
  - labeldrop:
    - filename  # Remove unnecessary labels
  - labelallow:
    - app
    - namespace
    - pod
```

#### Why is it Important?
- **Automation**: Collection without manual configuration per service
- **Efficiency**: Optimized for sending to Loki without duplication
- **Flexibility**: Parsing and transformation of complex logs
- **Reliability**: Ensures critical logs are not lost

---

### 3. Grafana Tempo - Distributed Tracing

#### What is it?
Tempo is a high-volume, low-cost distributed tracing backend. It allows tracing requests across multiple microservices.

#### Key Features
- **Distributed tracing**: Follows a request through multiple services
- **Low cost**: Object storage backend (S3, GCS)
- **No sampling**: Stores 100% of traces
- **Integration**: Works with OpenTelemetry, Jaeger, Zipkin

#### Practical Use Cases

**Microservices Debugging:**
```
User -> Traefik -> Authentik -> Actual Budget -> PostgreSQL

# See exactly where a login slows down:
1. Request hits Traefik (2ms)
2. Authentik validates OIDC (250ms) <- PROBLEM HERE
3. Redirect to Actual Budget (5ms)
4. Database query (15ms)
```

**Performance Analysis:**
```
# Typical Jellyfin request:
User -> Traefik -> Jellyfin -> NFS Storage

# Identify if the problem is:
- Network (latency to NFS)
- CPU (transcoding)
- Memory (metadata cache)
```

**Dependency Mapping:**
```
# Automatically visualize how services connect:
Traefik -----> Authentik
  |              |
  v              v
Media Stack -> PostgreSQL
  |
  v
NFS Storage
```

#### Why is it Important?
- **Complex troubleshooting**: Issues that cross multiple services
- **Optimization**: Identify exact bottlenecks in the chain
- **Architecture**: Understand real vs documented dependencies
- **SLA**: Measure real end-to-end user performance

#### When to Implement
- When you have intermittent performance issues
- When implementing complex microservices
- For advanced stack optimization
- When you need precise SLAs

---

### 4. Node Exporter - System Metrics

#### What is it?
Exports hardware and OS metrics from Linux/Unix servers. Already included in kube-prometheus-stack.

#### Use Cases
- CPU, memory, disk, network at node level
- Hardware temperature, voltage
- Filesystem and mount points
- System processes and services

---

### 5. Blackbox Exporter - External Monitoring

#### What is it?
Allows monitoring of external endpoints via HTTP, HTTPS, DNS, TCP, ICMP.

#### Practical Use Cases
```yaml
# Monitor external service availability
- targets:
  - https://your-actual-budget.domain.com
  - https://your-jellyfin.domain.com
  - https://your-authentik.domain.com

# Check SSL certificates nearing expiration
# Measure latency from user perspective
# Verify DNS and connectivity
```

---

## Implementation Roadmap

### ✅ Phase 1 (Completed)
- ✅ **kube-prometheus-stack** - Full monitoring foundation
- ✅ **Basic dashboards** - Cluster and node overview
- ✅ **Critical alerts** - Infrastructure health monitoring
- ✅ **Persistent storage** - Metrics retention with NFS
- ✅ **Secure access** - Grafana with Authentik SSO integration

### 🔄 Phase 2 (Next: 1-2 months)
- **Loki + Promtail** for centralized log aggregation
- **Blackbox exporter** for external service monitoring
- **Custom dashboards** for homelab applications
- **Enhanced alerting** rules for application-specific issues

### 📋 Phase 3 (Future: 3-6 months)
- **Grafana Tempo** for distributed tracing
- **OpenTelemetry** instrumentation for applications
- **SLI/SLO definitions** for service reliability
- **Advanced alerting** with escalation policies

### 🚀 Phase 4 (Advanced: 6+ months)
- **Custom application metrics** for business logic
- **Anomaly detection** for proactive monitoring
- **Chaos engineering** with observability feedback
- **Cross-cluster monitoring** if expanding infrastructure

---

## Benefits of Gradual Implementation

1. **Learning**: Master each component before the next
2. **Resources**: Don't overload the cluster initially
3. **Complexity**: Easier debugging with fewer components
4. **Value**: Immediate ROI with basic metrics
5. **Experience**: Real use cases guide expansion

## Next Steps

We start with kube-prometheus-stack because it provides:
- **80% of the value** with 20% of the complexity
- **Solid foundation** for future components
- **Practical experience** with observability
- **Immediate ROI** in homelab visibility

Once the basic stack is mastered, each additional component will be a natural extension based on real observed needs.