# Troubleshooting Guide

This guide helps diagnose and resolve common issues with the ITL Matrix Synapse Helm chart deployment.

## General Troubleshooting Approach

### 1. Initial Diagnosis Steps

```bash
# Check overall pod status
kubectl get pods -n <namespace> -l app.kubernetes.io/name=synapse

# Get detailed pod information
kubectl describe pod -n <namespace> <pod-name>

# Check recent events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top pods -n <namespace>
kubectl top nodes
```

### 2. Log Analysis

```bash
# View Synapse logs
kubectl logs -f -n <namespace> deployment/synapse --tail=100

# View previous container logs (if pod restarted)
kubectl logs -n <namespace> <pod-name> --previous

# View PostgreSQL logs
kubectl logs -f -n <namespace> statefulset/postgresql

# View all logs with timestamps
kubectl logs -f -n <namespace> deployment/synapse --timestamps
```

## Common Issues and Solutions

### 1. Pod Startup Issues

#### Issue: Pods Stuck in Pending State

**Symptoms:**
```bash
$ kubectl get pods
NAME                       READY   STATUS    RESTARTS   AGE
synapse-7d8f9b4c5d-xyz     0/1     Pending   0          5m
```

**Common Causes:**
1. **Insufficient Resources**
2. **Storage Issues**
3. **Node Affinity/Anti-affinity Rules**
4. **Image Pull Issues**

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod synapse-7d8f9b4c5d-xyz

# Check node resources
kubectl describe nodes

# Check storage classes
kubectl get storageclass

# Check PVC status
kubectl get pvc
```

**Solutions:**

1. **Resource Constraints:**
```yaml
# Reduce resource requests in values.yaml
synapse:
  resources:
    requests:
      memory: "256Mi"  # Reduced from 1Gi
      cpu: "100m"      # Reduced from 500m
```

2. **Storage Issues:**
```bash
# Check available storage
kubectl get pv

# Create missing storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
EOF
```

3. **Image Pull Problems:**
```bash
# Check image pull secrets
kubectl get pods synapse-xxx -o yaml | grep imagePullSecrets

# Manually pull image to verify
docker pull matrixdotorg/synapse:v1.94.0
```

#### Issue: Pods Crash Looping

**Symptoms:**
```bash
$ kubectl get pods
NAME                       READY   STATUS             RESTARTS   AGE
synapse-7d8f9b4c5d-xyz     0/1     CrashLoopBackOff   5          10m
```

**Diagnosis:**
```bash
# Check logs for errors
kubectl logs synapse-7d8f9b4c5d-xyz

# Check previous logs
kubectl logs synapse-7d8f9b4c5d-xyz --previous

# Check container exit code
kubectl describe pod synapse-7d8f9b4c5d-xyz | grep "Exit Code"
```

**Common Exit Codes:**
- **Exit Code 1**: General application error
- **Exit Code 125**: Docker daemon error
- **Exit Code 126**: Container command not executable
- **Exit Code 137**: Container killed (OOMKilled)

**Solutions:**

1. **Memory Issues (Exit Code 137):**
```yaml
# Increase memory limits
synapse:
  resources:
    limits:
      memory: "4Gi"  # Increased from 2Gi
```

2. **Configuration Errors:**
```bash
# Check configmap
kubectl get configmap synapse-config -o yaml

# Validate homeserver.yaml syntax
kubectl exec -it synapse-pod -- python -m synapse.config.homeserver --help
```

### 2. Database Connection Issues

#### Issue: Cannot Connect to PostgreSQL

**Symptoms:**
```
psycopg2.OperationalError: could not connect to server: Connection refused
```

**Diagnosis:**
```bash
# Check PostgreSQL pod status
kubectl get pods -l app.kubernetes.io/name=postgresql

# Check PostgreSQL service
kubectl get svc postgresql

# Test database connectivity
kubectl exec -it synapse-pod -- nc -zv postgresql 5432

# Check database logs
kubectl logs postgresql-0
```

**Solutions:**

1. **PostgreSQL Not Running:**
```bash
# Check PostgreSQL pod events
kubectl describe pod postgresql-0

# Restart PostgreSQL if needed
kubectl delete pod postgresql-0
```

2. **Wrong Connection Parameters:**
```yaml
# Verify connection settings in values.yaml
postgresql:
  auth:
    database: "synapse"
    username: "synapse"
    postgresPassword: "correct-password"
```

3. **Network Policy Issues:**
```bash
# Check network policies
kubectl get networkpolicy

# Temporarily disable to test
kubectl delete networkpolicy --all
```

#### Issue: Database Authentication Failed

**Symptoms:**
```
FATAL: password authentication failed for user "synapse"
```

**Solutions:**

1. **Check Secret Values:**
```bash
# Verify secret exists
kubectl get secret postgresql-credentials

# Check secret values (base64 encoded)
kubectl get secret postgresql-credentials -o yaml

# Decode password
kubectl get secret postgresql-credentials -o jsonpath='{.data.user-password}' | base64 -d
```

2. **Reset Database Password:**
```bash
# Connect as postgres user
kubectl exec -it postgresql-0 -- psql -U postgres

# Reset password
ALTER USER synapse PASSWORD 'new-password';

# Update secret
kubectl patch secret postgresql-credentials \
  -p '{"data":{"user-password":"'$(echo -n 'new-password' | base64)'"}}'
```

### 3. Ingress and Networking Issues

#### Issue: Ingress Not Accessible

**Symptoms:**
- External access to Matrix fails
- DNS resolution issues
- TLS certificate problems

**Diagnosis:**
```bash
# Check ingress status
kubectl get ingress

# Check ingress controller pods
kubectl get pods -n ingress-system

# Check ingress controller logs
kubectl logs -n ingress-system deployment/traefik

# Test internal connectivity
kubectl exec -it synapse-pod -- curl http://localhost:8008/_matrix/client/r0/versions
```

**Solutions:**

1. **Ingress Controller Issues:**
```bash
# Restart ingress controller
kubectl rollout restart deployment/traefik -n ingress-system

# Check ingress controller service
kubectl get svc -n ingress-system
```

2. **DNS Issues:**
```bash
# Verify DNS resolution
nslookup matrix.example.com

# Check DNS configuration
kubectl get configmap coredns -n kube-system -o yaml
```

3. **TLS Certificate Issues:**
```bash
# Check certificate status
kubectl get certificates

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Manually create certificate
kubectl delete certificate matrix-tls
helm upgrade matrix-prod ./chart --values production-values.yaml
```

#### Issue: Federation Not Working

**Symptoms:**
- Cannot federate with other Matrix servers
- `.well-known` not accessible

**Diagnosis:**
```bash
# Test federation endpoint
curl https://matrix.example.com:8448/_matrix/federation/v1/version

# Check well-known delegation
curl https://example.com/.well-known/matrix/server

# Test from external federation tester
# Visit: https://federationtester.matrix.org/
```

**Solutions:**

1. **Configure Federation Properly:**
```yaml
ingress:
  federation: true
  annotations:
    traefik.ingress.kubernetes.io/router.rule: |
      Host(`matrix.example.com`) || (Host(`example.com`) && Path(`/.well-known/matrix/server`))
```

2. **Add Well-Known Configuration:**
```bash
# Create well-known configmap
kubectl create configmap matrix-wellknown --from-literal=server='{"m.server": "matrix.example.com:443"}'
```

### 4. Storage Issues

#### Issue: Persistent Volume Claims Not Bound

**Symptoms:**
```bash
$ kubectl get pvc
NAME                STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
media-storage       Pending                                       ssd           10m
```

**Diagnosis:**
```bash
# Check PVC events
kubectl describe pvc media-storage

# Check available PVs
kubectl get pv

# Check storage class
kubectl describe storageclass ssd
```

**Solutions:**

1. **No Storage Class:**
```bash
# Create storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: none
EOF
```

2. **Insufficient Storage:**
```bash
# Check node disk space
kubectl describe nodes | grep -A5 "Allocated resources"

# Reduce PVC size temporarily
kubectl patch pvc media-storage -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
```

#### Issue: Data Corruption or Loss

**Symptoms:**
- Matrix reports database errors
- Media files not accessible
- Signing key errors

**Recovery Steps:**

1. **Database Recovery:**
```bash
# Stop Synapse pods
kubectl scale deployment synapse --replicas=0

# Restore from backup
kubectl exec -it postgresql-0 -- psql -U postgres -d synapse < backup.sql

# Restart Synapse
kubectl scale deployment synapse --replicas=2
```

2. **Media Recovery:**
```bash
# Check media volume mount
kubectl exec -it synapse-pod -- ls -la /data/media_store/

# Restore from backup storage
kubectl cp backup-media/ synapse-pod:/data/media_store/
```

### 5. Performance Issues

#### Issue: Slow Response Times

**Symptoms:**
- Long page load times
- API timeouts
- High resource usage

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods
kubectl top nodes

# Check Synapse metrics
kubectl port-forward svc/synapse-metrics 9092:9092
curl http://localhost:9092/_synapse/metrics

# Analyze database performance
kubectl exec -it postgresql-0 -- psql -U postgres -d synapse -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;"
```

**Solutions:**

1. **Scale Up Resources:**
```yaml
synapse:
  replicaCount: 3
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"
```

2. **Database Optimization:**
```sql
-- Connect to PostgreSQL
kubectl exec -it postgresql-0 -- psql -U postgres -d synapse

-- Vacuum and analyze
VACUUM ANALYZE;

-- Check database size
SELECT pg_size_pretty(pg_database_size('synapse'));

-- Optimize queries
REINDEX DATABASE synapse;
```

3. **Add Read Replicas:**
```yaml
postgresql:
  architecture: replication
  replication:
    enabled: true
    readReplicas: 2
```

#### Issue: High Memory Usage

**Symptoms:**
- Pods getting OOMKilled
- Slow garbage collection
- Memory leaks

**Solutions:**

1. **Tune Synapse Cache:**
```yaml
matrix:
  caches:
    global_factor: 0.5  # Reduce cache size
    expire_caches: true
    cache_autotuning:
      max_cache_memory_usage: "512M"
```

2. **Configure Garbage Collection:**
```yaml
synapse:
  extraEnv:
  - name: SYNAPSE_CACHE_FACTOR
    value: "0.5"
  - name: GC_THRESHOLD
    value: "10"
```

### 6. Security Issues

#### Issue: Secrets Not Loading

**Symptoms:**
- Authentication failures
- Missing signing keys
- Configuration errors

**Diagnosis:**
```bash
# Check secret existence
kubectl get secrets

# Verify secret content
kubectl get secret matrix-secrets -o yaml

# Check secret permissions
kubectl describe secret matrix-secrets
```

**Solutions:**

1. **Recreate Secrets:**
```bash
# Delete existing secret
kubectl delete secret matrix-secrets

# Create new secret with proper values
kubectl create secret generic matrix-secrets \
  --from-literal=registration-shared-secret=$(openssl rand -base64 64) \
  --from-literal=macaroon-secret-key=$(openssl rand -base64 64)
```

2. **Fix Secret Permissions:**
```bash
# Check service account permissions
kubectl auth can-i get secrets --as=system:serviceaccount:default:matrix-synapse-sa

# Update RBAC if needed
kubectl apply -f rbac.yaml
```

## Debugging Tools and Techniques

### 1. Debug Pod for Network Testing

```bash
# Create debug pod
kubectl run debug --image=nicolaka/netshoot --rm -it --restart=Never -- /bin/bash

# Test connectivity from debug pod
nslookup postgresql
nc -zv postgresql 5432
curl http://synapse:8008/_matrix/client/r0/versions
```

### 2. Port Forwarding for Local Testing

```bash
# Forward Synapse port
kubectl port-forward svc/synapse 8008:8008

# Forward PostgreSQL port
kubectl port-forward svc/postgresql 5432:5432

# Forward metrics port
kubectl port-forward svc/synapse-metrics 9092:9092

# Test locally
curl http://localhost:8008/_matrix/client/r0/versions
psql -h localhost -U synapse -d synapse
curl http://localhost:9092/_synapse/metrics
```

### 3. Exec into Containers

```bash
# Access Synapse container
kubectl exec -it deployment/synapse -- /bin/bash

# Access PostgreSQL container
kubectl exec -it postgresql-0 -- /bin/bash

# Run Synapse commands
kubectl exec -it deployment/synapse -- python -m synapse.app.homeserver --help
```

### 4. Monitoring and Alerting

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# View Grafana dashboards
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Visit http://localhost:3000

# Check logs aggregation
kubectl logs -n logging fluentd-xxx
```

## Emergency Procedures

### 1. Complete Service Outage

```bash
# Check all components
kubectl get all -n matrix-prod

# Emergency restart
kubectl delete pods --all -n matrix-prod

# Scale down and up
kubectl scale deployment synapse --replicas=0
kubectl scale deployment synapse --replicas=2

# Check ingress controller
kubectl get pods -n ingress-system
```

### 2. Data Recovery

```bash
# Stop all Matrix components
kubectl scale deployment synapse --replicas=0
kubectl scale statefulset postgresql --replicas=0

# Restore from backup
# (Restore procedures depend on your backup solution)

# Restart components
kubectl scale statefulset postgresql --replicas=1
# Wait for PostgreSQL to be ready
kubectl scale deployment synapse --replicas=2
```

### 3. Security Incident Response

```bash
# Immediately scale down
kubectl scale deployment synapse --replicas=0

# Rotate all secrets
kubectl delete secret matrix-secrets
kubectl delete secret postgresql-credentials

# Recreate with new values
# (Use proper secret generation)

# Update passwords in PostgreSQL
kubectl exec -it postgresql-0 -- psql -U postgres
ALTER USER synapse PASSWORD 'new-secure-password';

# Restart with new secrets
kubectl scale deployment synapse --replicas=2
```

## Preventive Measures

### 1. Health Monitoring

```yaml
# Comprehensive health checks
synapse:
  probes:
    readiness:
      httpGet:
        path: /_matrix/client/r0/versions
        port: 8008
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    
    liveness:
      httpGet:
        path: /_matrix/client/r0/versions
        port: 8008
      initialDelaySeconds: 60
      periodSeconds: 30
      timeoutSeconds: 10
      failureThreshold: 3
    
    startup:
      httpGet:
        path: /_matrix/client/r0/versions
        port: 8008
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 5
      failureThreshold: 12
```

### 2. Resource Monitoring

```yaml
# Set appropriate resource limits
synapse:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

# Enable HPA
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### 3. Automated Backups

```yaml
# PostgreSQL backup job
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-backup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:13
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h postgresql -U postgres synapse | \
              gzip > /backup/synapse-$(date +%Y%m%d-%H%M%S).sql.gz
              # Upload to S3 or other storage
```

This troubleshooting guide covers the most common issues and provides systematic approaches to diagnosis and resolution. Regular monitoring and preventive measures will help avoid many of these issues.