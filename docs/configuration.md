# Configuration Reference

This document provides a comprehensive reference for all configuration options available in the ITL Matrix Synapse Helm chart.

## Top-Level Configuration

### Service Account

```yaml
name: itl-syn01-sa
serviceAccount:
  create: true
  name: custom-sa-name
```

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `name` | Global name for the deployment | `itl-syn01-sa` | No |
| `serviceAccount.create` | Create a service account | `true` | No |
| `serviceAccount.name` | Name of the service account | `custom-sa-name` | No |

## Matrix Configuration

### Server Settings

```yaml
matrix:
  serverName: "example.com"
  telemetry: false
  hostname: "matrix.example.com"
  presence: true
  blockNonAdminInvites: false
  search: true
  encryptByDefault: invite
  adminEmail: "admin@example.com"
```

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `matrix.serverName` | Domain name of the Matrix server | `"example.com"` | Any valid domain |
| `matrix.telemetry` | Enable anonymous telemetry to matrix.org | `false` | `true`, `false` |
| `matrix.hostname` | Hostname where Synapse is reachable | Optional | Any valid hostname |
| `matrix.presence` | Enable presence indicators | `true` | `true`, `false` |
| `matrix.blockNonAdminInvites` | Block non-admin invites | `false` | `true`, `false` |
| `matrix.search` | Enable message searching | `true` | `true`, `false` |
| `matrix.encryptByDefault` | Default encryption setting | `invite` | `off`, `invite`, `all` |
| `matrix.adminEmail` | Administrator email address | `"admin@example.com"` | Any valid email |

### Upload Settings

```yaml
matrix:
  uploads:
    maxSize: 10M
    maxPixels: 32M
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `matrix.uploads.maxSize` | Maximum upload size | `10M` |
| `matrix.uploads.maxPixels` | Maximum image pixels | `32M` |

### Federation Settings

```yaml
matrix:
  federation:
    enabled: true
    allowPublicRooms: true
    blacklist:
      - '127.0.0.0/8'
      - '10.0.0.0/8'
      - '172.16.0.0/12'
      - '192.168.0.0/16'
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `matrix.federation.enabled` | Enable federation | `true` |
| `matrix.federation.allowPublicRooms` | Allow fetching public rooms | `true` |
| `matrix.federation.blacklist` | IP ranges to blacklist | See example |
| `matrix.federation.whitelist` | Domains to federate with | `[]` |

### Registration Settings

```yaml
matrix:
  registration:
    enabled: false
    allowGuests: false
    autoJoinRooms: []
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `matrix.registration.enabled` | Allow new user registration | `false` |
| `matrix.registration.allowGuests` | Allow guest access | `false` |
| `matrix.registration.sharedSecret` | Registration shared secret | Optional |
| `matrix.registration.autoJoinRooms` | Rooms to auto-join | `[]` |

## Storage Configuration

### Persistent Volumes

```yaml
volumes:
  media:
    capacity: 10Gi
    storageClass: ""
  signingKey:
    capacity: 1Mi
    storageClass: ""
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumes.media.capacity` | Media storage size | `10Gi` |
| `volumes.media.storageClass` | Storage class for media | `""` |
| `volumes.signingKey.capacity` | Signing key storage size | `1Mi` |
| `volumes.signingKey.storageClass` | Storage class for keys | `""` |

## Ingress Configuration

```yaml
ingress:
  enabled: true
  federation: true
  tls: []
  hosts:
    synapse: matrix.chart-example.local
    riot: element.chart-example.local
    federation: matrix-fed.chart-example.local
  annotations: {}
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.federation` | Expose federation API | `true` |
| `ingress.tls` | TLS configuration | `[]` |
| `ingress.hosts.*` | Host configurations | See example |
| `ingress.annotations` | Ingress annotations | `{}` |

## Database Configuration

### PostgreSQL Settings

```yaml
postgresql:
  enabled: true
  postgresqlPassword: ChangeMe!
  username: matrix
  password: matrix
  database: matrix
  hostname: ""
  port: 5432
  ssl: false
  sslMode: prefer
```

| Parameter | Description | Default | Security Note |
|-----------|-------------|---------|---------------|
| `postgresql.enabled` | Deploy PostgreSQL | `true` | - |
| `postgresql.postgresqlPassword` | PostgreSQL password | `ChangeMe!` | ⚠️ Change in production |
| `postgresql.username` | Database username | `matrix` | - |
| `postgresql.password` | Database password | `matrix` | ⚠️ Change in production |
| `postgresql.database` | Database name | `matrix` | - |
| `postgresql.ssl` | Enable SSL | `false` | Recommended for production |

## Synapse Service Configuration

```yaml
synapse:
  image:
    repository: "matrixdotorg/synapse"
    tag: v1.35.1
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 80
  replicaCount: 1
  resources: {}
```

| Parameter | Description | Default | Recommendation |
|-----------|-------------|---------|----------------|
| `synapse.image.repository` | Container image | `matrixdotorg/synapse` | - |
| `synapse.image.tag` | Image tag | `v1.35.1` | Use latest stable |
| `synapse.replicaCount` | Number of replicas | `1` | Scale based on load |
| `synapse.resources` | Resource limits | `{}` | ⚠️ Set limits in production |

### Health Probes

```yaml
synapse:
  probes:
    readiness:
      timeoutSeconds: 5
      periodSeconds: 10
    startup:
      timeoutSeconds: 5
      periodSeconds: 5
      failureThreshold: 6
    liveness:
      timeoutSeconds: 5
      periodSeconds: 10
```

### Metrics Configuration

```yaml
synapse:
  metrics:
    enabled: true
    port: 9092
    annotations: true
```

## Tenant-Specific Configuration

```yaml
tenant:
  name: itl-syn01
  registrationSharedSecret:
    name: itl-syn01-secret
    existingSecret: false
  servicename: itl-syn01-matrix
  createNewPostgreSQL: false
  homeserver:
    values:
      reportStats: false
      serverName: matrix.dev.itlusions.com
  ingress:
    enabled: true
    className: "traefik"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-issuer"
    tls:
      - secretName: matrix-tls
        hosts:
          - matrix.dev.itlusions.com
    hosts:
      - host: matrix.dev.itlusions.com
        paths:
          - path: /
            pathType: Prefix
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tenant.name` | Tenant identifier | `itl-syn01` |
| `tenant.createNewPostgreSQL` | Create dedicated DB | `false` |
| `tenant.homeserver.values.serverName` | Server domain | Required |
| `tenant.ingress.className` | Ingress class | `"traefik"` |

## Security Configuration

### Secrets Management

The chart automatically generates secrets for:
- Registration shared secret
- Macaroon secret key
- Signing keys

### TLS Configuration

```yaml
tenant:
  ingress:
    tls:
      - secretName: matrix-tls
        hosts:
          - matrix.example.com
```

## Environment-Specific Settings

### OpenShift

```yaml
isOpenshift: true
```

### Network Policies

```yaml
networkPolicies:
  enabled: true
```

## Resource Recommendations

### Production Values

```yaml
synapse:
  replicaCount: 2
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

postgresql:
  persistence:
    size: 20Gi
  ssl: true

volumes:
  media:
    capacity: 50Gi
```

For detailed security configuration, see the [Security Guide](security.md).