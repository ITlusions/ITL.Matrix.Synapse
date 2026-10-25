# Deployment Guide

This guide provides comprehensive instructions for deploying the ITL Matrix Synapse Helm chart in production environments.

## Production Deployment Overview

Deploying Matrix Synapse in production requires careful consideration of security, scalability, monitoring, and operational requirements. This guide covers best practices for each aspect of the deployment.

## Pre-Deployment Planning

### 1. Infrastructure Requirements

#### Minimum Production Requirements

| Component | CPU | Memory | Storage | Notes |
|-----------|-----|--------|---------|-------|
| Synapse | 1 CPU | 2Gi RAM | 10Gi | Per 1000 users |
| PostgreSQL | 0.5 CPU | 1Gi RAM | 20Gi | SSD recommended |
| Element Web | 0.1 CPU | 128Mi | 1Gi | Static assets |
| Coturn | 0.2 CPU | 256Mi | 1Gi | For voice/video |

#### Recommended Production Requirements

| Component | CPU | Memory | Storage | Replicas |
|-----------|-----|--------|---------|----------|
| Synapse | 2 CPU | 4Gi RAM | 50Gi | 2-3 |
| PostgreSQL | 1 CPU | 2Gi RAM | 100Gi | 1 primary + 1 replica |
| Element Web | 0.2 CPU | 256Mi | 1Gi | 2 |
| Coturn | 0.5 CPU | 512Mi | 1Gi | 1 per node |

### 2. Prerequisites Checklist

- [ ] Kubernetes cluster (1.19+) with adequate resources
- [ ] Helm 3.0+ installed and configured
- [ ] Ingress controller deployed and configured
- [ ] Storage classes available (preferably SSD)
- [ ] DNS configuration prepared
- [ ] TLS certificates or cert-manager configured
- [ ] Monitoring infrastructure (Prometheus/Grafana)
- [ ] Backup solution implemented
- [ ] Security scanning tools configured

## Production Configuration

### 1. Create Production Values File

Create `production-values.yaml`:

```yaml
# Production configuration for ITL Matrix Synapse
global:
  domain: "matrix.example.com"
  environment: "production"

# Service account with minimal permissions
serviceAccount:
  create: true
  name: "matrix-synapse-sa"
  automountServiceAccountToken: false

# Matrix server configuration
matrix:
  serverName: "matrix.example.com"
  telemetry: false  # Disable for privacy
  adminEmail: "admin@example.com"
  
  # Security settings
  registration:
    enabled: false  # Disable open registration
    require3pid: true
    allowed3pidTypes:
      - email
  
  # Federation settings
  federation:
    enabled: true
    allowPublicRooms: false  # Restrict for privacy
    
  # Upload restrictions
  uploads:
    maxSize: 50M
    maxPixels: 50M
  
  # Logging configuration
  logging:
    rootLogLevel: WARNING
    sqlLogLevel: ERROR
    synapseLogLevel: INFO

# High availability Synapse configuration
synapse:
  replicaCount: 3
  
  image:
    repository: "matrixdotorg/synapse"
    tag: "v1.94.0"  # Use latest stable
    pullPolicy: IfNotPresent
  
  # Resource limits (adjust based on load)
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
  
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 991
    runAsGroup: 991
    fsGroup: 991
    seccompProfile:
      type: RuntimeDefault
  
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
  
  # Anti-affinity for HA
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - synapse
          topologyKey: kubernetes.io/hostname
  
  # Pod disruption budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
  
  # Health probes
  probes:
    readiness:
      httpGet:
        path: /_matrix/client/r0/versions
        port: 8008
      timeoutSeconds: 5
      periodSeconds: 10
    startup:
      httpGet:
        path: /_matrix/client/r0/versions
        port: 8008
      timeoutSeconds: 5
      periodSeconds: 5
      failureThreshold: 12
    liveness:
      httpGet:
        path: /_matrix/client/r0/versions
        port: 8008
      timeoutSeconds: 5
      periodSeconds: 30
  
  # Metrics for monitoring
  metrics:
    enabled: true
    port: 9092
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "9092"
      prometheus.io/path: "/_synapse/metrics"

# Production PostgreSQL configuration
postgresql:
  enabled: true
  
  auth:
    postgresPassword: ""  # Use external secret
    username: "synapse"
    database: "synapse"
    existingSecret: "postgresql-credentials"
    secretKeys:
      adminPasswordKey: "postgres-password"
      userPasswordKey: "user-password"
  
  primary:
    persistence:
      enabled: true
      size: 100Gi
      storageClass: "ssd"
    
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
    
    podSecurityContext:
      enabled: true
      fsGroup: 1001
      runAsUser: 1001
    
    containerSecurityContext:
      enabled: true
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
  
  # Enable SSL for security
  ssl: true
  sslMode: require
  
  # Backup configuration
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
    retention: "7d"

# Element Web client
element:
  enabled: true
  replicaCount: 2
  
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000

# Coturn for voice/video
coturn:
  enabled: true
  kind: DaemonSet  # One per node for best performance
  
  # Generate secure shared secret
  sharedSecret: ""  # Auto-generated
  
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  
  service:
    type: ClusterIP

# Storage configuration
volumes:
  media:
    capacity: 100Gi
    storageClass: "ssd"
  signingKey:
    capacity: 1Mi
    storageClass: "ssd"

# Ingress configuration
ingress:
  enabled: true
  className: "traefik"
  
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: "default-security-headers@kubernetescrd"
  
  tls:
    - secretName: "matrix-tls"
      hosts:
        - "matrix.example.com"
  
  hosts:
    - host: "matrix.example.com"
      paths:
        - path: "/"
          pathType: Prefix

# Network security
networkPolicies:
  enabled: true

# Enable for OpenShift
isOpenshift: false

# Tenant configuration
tenant:
  name: "production-matrix"
  createNewPostgreSQL: false  # Use the configured PostgreSQL above
  
  homeserver:
    values:
      reportStats: false
      serverName: "matrix.example.com"
  
  ingress:
    enabled: true
    className: "traefik"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      traefik.ingress.kubernetes.io/router.tls: "true"
    tls:
      - secretName: "matrix-tls"
        hosts:
          - "matrix.example.com"
    hosts:
      - host: "matrix.example.com"
        paths:
          - path: "/"
            pathType: Prefix
```

### 2. Secrets Management

Create required secrets before deployment:

```bash
# Create namespace
kubectl create namespace matrix-prod

# Create PostgreSQL credentials
kubectl create secret generic postgresql-credentials \
  --namespace matrix-prod \
  --from-literal=postgres-password=$(openssl rand -base64 32) \
  --from-literal=user-password=$(openssl rand -base64 32)

# Create Matrix secrets
kubectl create secret generic matrix-secrets \
  --namespace matrix-prod \
  --from-literal=registration-shared-secret=$(openssl rand -base64 64) \
  --from-literal=macaroon-secret-key=$(openssl rand -base64 64) \
  --from-literal=form-secret=$(openssl rand -base64 64)
```

### 3. TLS Certificate Setup

#### Option A: Cert-Manager (Recommended)

```bash
# Install cert-manager if not present
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
```

#### Option B: Manual Certificate

```bash
# Create TLS secret with your certificates
kubectl create secret tls matrix-tls \
  --namespace matrix-prod \
  --cert=matrix.example.com.crt \
  --key=matrix.example.com.key
```

## Deployment Steps

### 1. Pre-deployment Validation

```bash
# Validate Helm chart
helm lint ./chart

# Dry run to check generated manifests
helm install matrix-prod ./chart \
  --namespace matrix-prod \
  --values production-values.yaml \
  --dry-run --debug

# Check resource quotas and limits
kubectl describe namespace matrix-prod
```

### 2. Deploy the Chart

```bash
# Create namespace with labels
kubectl create namespace matrix-prod
kubectl label namespace matrix-prod \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted

# Deploy with production values
helm install matrix-prod ./chart \
  --namespace matrix-prod \
  --values production-values.yaml \
  --timeout 600s \
  --wait
```

### 3. Post-deployment Verification

```bash
# Check pod status
kubectl get pods -n matrix-prod -l app.kubernetes.io/name=matrix

# Check services
kubectl get services -n matrix-prod

# Check ingress
kubectl get ingress -n matrix-prod

# Check persistent volumes
kubectl get pv,pvc -n matrix-prod

# Verify TLS certificates
kubectl get certificates -n matrix-prod
```

### 4. Health Checks

```bash
# Test Matrix API endpoint
curl -k https://matrix.example.com/_matrix/client/r0/versions

# Test Element Web interface
curl -k https://matrix.example.com/

# Check PostgreSQL connectivity
kubectl exec -n matrix-prod deployment/postgresql -- pg_isready

# Verify metrics endpoint
kubectl port-forward -n matrix-prod svc/matrix-metrics 9092:9092
curl http://localhost:9092/_synapse/metrics
```

## Post-Deployment Configuration

### 1. Create Administrator User

```bash
# Get Synapse pod name
SYNAPSE_POD=$(kubectl get pods -n matrix-prod -l app.kubernetes.io/name=synapse -o jsonpath='{.items[0].metadata.name}')

# Register admin user
kubectl exec -n matrix-prod $SYNAPSE_POD -- \
  register_new_matrix_user \
  --user admin \
  --password "$(openssl rand -base64 32)" \
  --admin \
  --config /data/homeserver.yaml \
  http://localhost:8008
```

### 2. Configure Monitoring

#### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: synapse-metrics
  namespace: matrix-prod
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: synapse
  endpoints:
  - port: metrics
    path: /_synapse/metrics
    interval: 30s
```

#### Grafana Dashboard

Import the official Synapse Grafana dashboard (ID: 3875) or create custom dashboards for monitoring key metrics.

### 3. Set Up Backup Procedures

```bash
# Create backup job
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-backup
  namespace: matrix-prod
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:13
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: postgres-password
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h postgresql -U postgres synapse | \
              gzip > /backup/synapse-\$(date +%Y%m%d-%H%M%S).sql.gz
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
EOF
```

## High Availability Configuration

### 1. Multi-Zone Deployment

```yaml
# Add to production-values.yaml
synapse:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: synapse

postgresql:
  primary:
    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
```

### 2. Database High Availability

```yaml
postgresql:
  architecture: replication
  replication:
    enabled: true
    readReplicas: 2
    synchronousCommit: "on"
    numSynchronousReplicas: 1
```

## Scaling Configuration

### 1. Horizontal Pod Autoscaler

```yaml
# Add to production-values.yaml
synapse:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

### 2. Vertical Pod Autoscaler

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: synapse-vpa
  namespace: matrix-prod
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: synapse
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: synapse
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
```

## Maintenance Procedures

### 1. Rolling Updates

```bash
# Update image version
helm upgrade matrix-prod ./chart \
  --namespace matrix-prod \
  --values production-values.yaml \
  --set synapse.image.tag=v1.95.0 \
  --wait

# Monitor rollout
kubectl rollout status deployment/synapse -n matrix-prod
```

### 2. Database Maintenance

```bash
# Connect to database for maintenance
kubectl exec -it -n matrix-prod postgresql-0 -- psql -U postgres -d synapse

# Vacuum and analyze
VACUUM ANALYZE;

# Check database size
SELECT pg_size_pretty(pg_database_size('synapse'));
```

### 3. Log Management

```bash
# View Synapse logs
kubectl logs -f -n matrix-prod deployment/synapse

# View PostgreSQL logs
kubectl logs -f -n matrix-prod statefulset/postgresql

# Aggregate logs with timestamps
kubectl logs -f -n matrix-prod deployment/synapse --timestamps
```

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and storage availability
2. **Database connection issues**: Verify credentials and network policies
3. **TLS certificate problems**: Check cert-manager logs and DNS configuration
4. **Federation issues**: Verify DNS SRV records and firewall rules

### Debug Commands

```bash
# Check resource usage
kubectl top pods -n matrix-prod

# Describe problematic pods
kubectl describe pod -n matrix-prod <pod-name>

# Check events
kubectl get events -n matrix-prod --sort-by='.lastTimestamp'

# Port forward for debugging
kubectl port-forward -n matrix-prod svc/synapse 8008:8008
```

This deployment guide provides a comprehensive approach to production Matrix Synapse deployments with proper security, monitoring, and operational considerations.