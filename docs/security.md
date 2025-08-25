# Security Guide

This guide covers security best practices and configurations for the ITL Matrix Synapse Helm chart deployment.

## Security Overview

Matrix Synapse handles sensitive communication data and user information, making security a critical consideration. This guide addresses key security areas including secrets management, network security, access control, and monitoring.

## Secrets Management

### ⚠️ Critical Security Issues Found

The current chart implementation has several security vulnerabilities that must be addressed:

#### 1. Hardcoded Secrets in Templates

**Issue**: The `_helpers.tpl` file contains hardcoded secrets:

```yaml
# SECURITY VIOLATION - DO NOT USE IN PRODUCTION
macaroon_secret_key: "uLJ62kwNWO_DLcKAmbzqYkFwlDQWjNl5@G#SKT*i9~bZrZy~_@"
client_secret: "uLJ62kwNWO_DLcKAmbzqYkFwlDQWjNl5@G#SKT*i9~bZrZy~_@"
form_secret: "2iTjom-bIq5Yh6:afKjUed^2Eokx8cd_kzdUN,A#0MFAn.tSrC"
```

**Risk**: These secrets are exposed in:
- Git repository
- Helm chart packages
- Kubernetes manifests
- Container environments

**Recommended Fix**: Use Kubernetes secrets with randomly generated values or external secret management systems.

#### 2. Default Passwords

**Issue**: Default passwords in `values.yaml`:

```yaml
postgresql:
  postgresqlPassword: ChangeMe!
  password: matrix
coturn:
  sharedSecret: "ChangeMe"
```

**Recommended Solution**:

```yaml
# Use external secrets or generated values
postgresql:
  auth:
    existingSecret: "postgresql-secret"
    secretKeys:
      adminPasswordKey: "postgres-password"
      userPasswordKey: "user-password"

# Or use randomly generated secrets
coturn:
  sharedSecret: "" # Will be auto-generated if empty
```

### Proper Secrets Management

#### 1. External Secrets Operator (Recommended)

Install External Secrets Operator:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
```

Example SecretStore configuration:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "synapse-role"
```

#### 2. Sealed Secrets

```bash
# Install sealed-secrets controller
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system
```

Create sealed secrets:

```bash
# Create secret file
echo -n 'your-secure-password' | kubectl create secret generic synapse-secrets \
  --dry-run=client --from-file=password=/dev/stdin -o yaml > secret.yaml

# Seal the secret
kubeseal -f secret.yaml -w sealed-secret.yaml
```

#### 3. Generated Secrets

Improve the chart to generate secure secrets:

```yaml
# In values.yaml
secrets:
  autoGenerate: true
  registrationSharedSecret: ""  # Auto-generated if empty
  macaroonSecretKey: ""         # Auto-generated if empty
  formSecret: ""                # Auto-generated if empty
```

## TLS/SSL Configuration

### 1. TLS Certificates

**Enable TLS everywhere:**

```yaml
tenant:
  ingress:
    enabled: true
    className: "traefik"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      traefik.ingress.kubernetes.io/router.tls: "true"
    tls:
      - secretName: matrix-tls
        hosts:
          - matrix.example.com

postgresql:
  ssl: true
  sslMode: require
```

### 2. Certificate Management

Install cert-manager for automatic certificate management:

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

Create a ClusterIssuer:

```yaml
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
```

## Network Security

### 1. Network Policies

Enable network policies to restrict traffic:

```yaml
networkPolicies:
  enabled: true
```

Example network policy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: synapse-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: synapse
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-system
    ports:
    - protocol: TCP
      port: 8008
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### 2. Pod Security Standards

Configure Pod Security Standards:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: matrix
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Service Mesh (Optional)

Consider implementing Istio for advanced traffic management:

```yaml
# Enable Istio sidecar injection
apiVersion: v1
kind: Namespace
metadata:
  name: matrix
  labels:
    istio-injection: enabled
```

## Access Control

### 1. RBAC Configuration

The chart should implement proper RBAC:

```yaml
rbac:
  create: true
  rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

### 2. Service Account Security

```yaml
serviceAccount:
  create: true
  automountServiceAccountToken: false  # Disable if not needed
  annotations:
    iam.gke.io/gcp-service-account: matrix-sa@project.iam.gserviceaccount.com
```

### 3. Pod Security Context

```yaml
synapse:
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
```

## Authentication and Authorization

### 1. OIDC Integration

Configure secure OIDC authentication:

```yaml
matrix:
  oidc:
    enabled: true
    issuer: "https://keycloak.example.com/realms/matrix"
    client_id: "synapse"
    client_secret_path: "/secrets/oidc-secret"
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        localpart_template: "{{ user.preferred_username }}"
        display_name_template: "{{ user.name }}"
```

### 2. Registration Controls

```yaml
matrix:
  registration:
    enabled: false  # Disable open registration
    require_3pid_for_registration: true
    allowed_3pid_types:
      - email
    registration_requires_token: true
```

## Database Security

### 1. PostgreSQL Security

```yaml
postgresql:
  auth:
    enablePostgresUser: false
    postgresPassword: ""  # Use external secret
    username: "synapse"
    database: "synapse"
    existingSecret: "postgresql-secret"
  
  primary:
    initdb:
      args: "--auth-host=md5"
    
    persistence:
      enabled: true
      size: 20Gi
      storageClass: "encrypted-ssd"
    
    podSecurityContext:
      fsGroup: 1001
      runAsUser: 1001
```

### 2. Database Encryption

Enable encryption at rest:

```yaml
postgresql:
  primary:
    extraEnvVars:
    - name: POSTGRESQL_INITDB_ARGS
      value: "--auth-host=md5 --auth-local=md5"
    - name: PGCRYPTO_EXTENSION
      value: "true"
```

## Monitoring and Auditing

### 1. Security Monitoring

Enable Prometheus metrics for security monitoring:

```yaml
synapse:
  metrics:
    enabled: true
    port: 9092
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "9092"
```

### 2. Audit Logging

Configure comprehensive logging:

```yaml
matrix:
  logging:
    rootLogLevel: INFO
    sqlLogLevel: WARNING
    synapseLogLevel: INFO
    handlers:
      file:
        class: logging.handlers.RotatingFileHandler
        filename: /data/logs/synapse.log
        maxBytes: 104857600
        backupCount: 3
      security:
        class: logging.handlers.SysLogHandler
        address: ['rsyslog.example.com', 514]
        facility: 'local0'
```

### 3. Security Scanning

Implement container security scanning:

```yaml
# Example with Trivy operator
apiVersion: v1
kind: ConfigMap
metadata:
  name: trivy-operator-config
data:
  scanJob.compressLogs: "true"
  vulnerabilityReports.scanner: "Trivy"
  compliance.failEntriesLimit: "10"
```

## Security Checklist

### Pre-Deployment Security Checklist

- [ ] Remove all hardcoded secrets from templates
- [ ] Configure external secrets management
- [ ] Enable TLS/SSL for all communications
- [ ] Set up certificate management with cert-manager
- [ ] Configure network policies
- [ ] Implement Pod Security Standards
- [ ] Set proper RBAC permissions
- [ ] Enable audit logging
- [ ] Configure resource limits and quotas
- [ ] Set up monitoring and alerting
- [ ] Perform security scanning

### Post-Deployment Security Checklist

- [ ] Verify all secrets are properly managed
- [ ] Test TLS certificate renewal
- [ ] Validate network policies are working
- [ ] Check RBAC permissions are minimal
- [ ] Review audit logs
- [ ] Perform penetration testing
- [ ] Set up security monitoring dashboards
- [ ] Document incident response procedures

## Incident Response

### 1. Security Incident Procedures

1. **Immediate Response**:
   - Isolate affected components
   - Preserve evidence
   - Notify security team

2. **Investigation**:
   - Review audit logs
   - Check for lateral movement
   - Identify attack vectors

3. **Recovery**:
   - Rotate compromised secrets
   - Update security policies
   - Apply security patches

### 2. Regular Security Maintenance

- **Weekly**: Review security logs and alerts
- **Monthly**: Update container images and dependencies
- **Quarterly**: Perform security assessments and penetration testing
- **Annually**: Review and update security policies

## Compliance Considerations

For organizations requiring compliance (GDPR, HIPAA, SOC2):

1. **Data Encryption**: Enable encryption at rest and in transit
2. **Access Logging**: Comprehensive audit trails
3. **Data Retention**: Configure appropriate retention policies
4. **Access Controls**: Implement least privilege access
5. **Regular Audits**: Schedule security assessments

This security guide should be reviewed and updated regularly as new security threats and best practices emerge.