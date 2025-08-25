# Architecture Overview

This document describes the architecture and components of the ITL Matrix Synapse Helm chart deployment.

## System Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Internet/Users    │    │    Load Balancer    │    │   Ingress Controller│
│                     │◄──►│     (External)      │◄──►│     (Traefik)       │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
                                                                    │
                                                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes Cluster                                │
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │   Matrix Tenant │    │   PostgreSQL    │    │       Storage           │  │
│  │   (Synapse Pod) │◄──►│   Database      │    │   (PersistentVolumes)   │  │
│  │                 │    │                 │    │                         │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
│           │                                                                 │
│           ▼                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │    Element Web  │    │     Coturn      │    │       Secrets           │  │
│  │   (Web Client)  │    │   (TURN/STUN)   │    │     Management          │  │
│  │                 │    │                 │    │                         │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Matrix Synapse Homeserver

**Purpose**: Core Matrix protocol server handling federation, user management, and room operations.

**Key Features**:
- Matrix protocol implementation
- User authentication and authorization
- Room and federation management
- Media storage and processing
- API endpoints for clients

**Configuration**:
- Deployed as Kubernetes Deployment
- Configurable replica count
- Health checks and probes
- Metrics exposure for monitoring

### 2. PostgreSQL Database

**Purpose**: Primary data store for Matrix data including users, rooms, messages, and federation state.

**Key Features**:
- ACID compliance for data integrity
- Configurable with bundled chart or external instance
- SSL/TLS support for secure connections
- Automated backup capabilities

**Configuration**:
- Can be deployed via subchart or external
- Persistent storage for data durability
- Connection pooling and optimization
- Security contexts and access controls

### 3. Element Web Client

**Purpose**: Web-based Matrix client for user interface.

**Key Features**:
- Modern React-based interface
- PWA (Progressive Web App) support
- Customizable branding and themes
- Integration with homeserver

**Configuration**:
- Deployed as separate service
- Configurable integrations
- Custom themes and branding
- Security headers and CSP

### 4. Coturn (TURN/STUN Server)

**Purpose**: NAT traversal for voice and video calls.

**Key Features**:
- TURN/STUN protocol support
- UDP port range configuration
- Guest access controls
- Shared secret authentication

**Configuration**:
- DaemonSet or Deployment options
- Host networking for direct connectivity
- Port range configuration
- Integration with Synapse

### 5. Ingress Controller

**Purpose**: HTTP/HTTPS traffic routing and SSL termination.

**Key Features**:
- Multiple ingress controller support
- Automatic TLS certificate management
- Path-based routing
- Load balancing

**Supported Controllers**:
- Traefik (default)
- NGINX Ingress
- HAProxy Ingress
- Cloud provider ingresses

## Data Flow

### 1. Client Authentication Flow

```
Client ──HTTP(S)──► Ingress ──► Synapse ──► Database
   │                                           │
   │◄──────────── Auth Token ◄────────────────┘
   │
   └──────── Authenticated Requests ─────────►
```

### 2. Federation Flow

```
Remote Server ──HTTPS──► Ingress ──► Synapse ──► Database
      │                      │           │         │
      │                      │           ▼         │
      │                      │    ┌─────────────┐  │
      │                      │    │   Signing   │  │
      │                      │    │    Keys     │  │
      │                      │    └─────────────┘  │
      │                      │                     │
      │◄────── Response ─────┘◄────────────────────┘
```

### 3. Media Upload Flow

```
Client ──Upload──► Ingress ──► Synapse ──► Media Storage
                                  │              │
                                  └──────────────┘
                                   File Processing
```

## Storage Architecture

### 1. Persistent Volume Configuration

```yaml
volumes:
  media:
    capacity: 10Gi        # Media files storage
    storageClass: "ssd"   # High-performance storage
  
  signingKey:
    capacity: 1Mi         # Cryptographic keys
    storageClass: "ssd"   # Secure storage
  
  database:
    capacity: 20Gi        # Database storage
    storageClass: "ssd"   # ACID compliance needs
```

### 2. Storage Classes

- **Media Storage**: High-capacity, moderate performance
- **Database Storage**: High-performance, ACID-compliant
- **Signing Keys**: Secure, encrypted storage
- **Logs**: Fast access for debugging

## Network Architecture

### 1. Service Mesh (Optional)

When deployed with Istio:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Istio Service Mesh                      │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   Synapse   │◄──►│ PostgreSQL  │    │      Envoy Proxy    │  │
│  │   + Envoy   │    │   + Envoy   │    │     (Sidecar)       │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│         │                   │                       │          │
│         └───────────────────┼───────────────────────┘          │
│                             │                                  │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │              Istio Control Plane                          │  │
│  │         (Traffic Management, Security, Observability)     │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Network Policies

```yaml
# Example network policy structure
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
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress
    ports:
    - protocol: TCP
      port: 8008
  egress:
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: postgresql
    ports:
    - protocol: TCP
      port: 5432
```

## Security Architecture

### 1. Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                      Security Layers                           │
│                                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐  │
│  │   Network   │ │   Pod/App   │ │   Data      │ │  Secrets  │  │
│  │   Security  │ │   Security  │ │  Security   │ │  Mgmt     │  │
│  │             │ │             │ │             │ │           │  │
│  │ • Network   │ │ • Security  │ │ • TLS       │ │ • K8s     │  │
│  │   Policies  │ │   Context   │ │   Encrypt   │ │   Secrets │  │
│  │ • Ingress   │ │ • RBAC      │ │ • Encrypt   │ │ • External│  │
│  │   TLS       │ │ • Pod       │ │   at Rest   │ │   Secrets │  │
│  │ • Service   │ │   Security  │ │ • Access    │ │ • Vault   │  │
│  │   Mesh      │ │   Standards │ │   Controls  │ │   Integ   │  │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Authentication Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Client   │    │   Ingress   │    │   Synapse   │    │    OIDC     │
│             │    │             │    │             │    │  Provider   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │
       ├─── Login ────────┤                  │                  │
       │                  ├── Forward ──────┤                  │
       │                  │                  ├── OIDC Auth ────┤
       │                  │                  │◄── Token ───────┤
       │                  │◄── Response ────┤                  │
       │◄── Auth Token ───┤                  │                  │
       │                  │                  │                  │
```

## Deployment Patterns

### 1. Single Tenant Deployment

```
Namespace: matrix-prod
├── Synapse Deployment (1 replica)
├── PostgreSQL StatefulSet (1 replica)
├── Element Deployment (1 replica)
├── Coturn DaemonSet
├── Ingress (matrix.example.com)
└── Secrets and ConfigMaps
```

### 2. Multi-Tenant Deployment

```
Namespace: matrix-tenants
├── Tenant A
│   ├── Synapse Deployment (tenant-a)
│   ├── PostgreSQL (shared or dedicated)
│   └── Ingress (a.matrix.example.com)
├── Tenant B
│   ├── Synapse Deployment (tenant-b)
│   ├── PostgreSQL (shared or dedicated)
│   └── Ingress (b.matrix.example.com)
└── Shared Resources
    ├── Element Deployment
    ├── Coturn DaemonSet
    └── Cert-Manager
```

### 3. High Availability Deployment

```
Namespace: matrix-ha
├── Synapse Deployment (3 replicas)
│   ├── Anti-affinity rules
│   ├── Pod Disruption Budget
│   └── Resource requests/limits
├── PostgreSQL Primary/Replica
│   ├── Primary (1 replica)
│   ├── Read Replicas (2 replicas)
│   └── Connection pooling
├── Redis Cluster (optional)
│   └── Session/cache storage
└── Load Balancer
    └── Multiple ingress endpoints
```

## Monitoring and Observability

### 1. Metrics Collection

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Synapse    │    │ Prometheus  │    │   Grafana   │
│  Metrics    ├───►│  Server     ├───►│  Dashboard  │
│  :9092      │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ PostgreSQL  │    │  AlertManager│    │   Logs      │
│ Metrics     │    │             │    │ (ELK/Loki)  │
└─────────────┘    └─────────────┘    └─────────────┘
```

### 2. Health Check Endpoints

- **Synapse**: `/_matrix/client/r0/versions`
- **PostgreSQL**: Custom health check queries
- **Element**: HTTP 200 on root path
- **Coturn**: UDP connectivity tests

## Scaling Considerations

### 1. Horizontal Scaling

**Synapse Scaling**:
- Multiple replicas behind load balancer
- Session affinity considerations
- Database connection limits
- Media storage sharing

**Database Scaling**:
- Read replicas for query load
- Connection pooling (PgBouncer)
- Sharding strategies for large deployments

### 2. Vertical Scaling

**Resource Optimization**:
- CPU: Based on concurrent users
- Memory: Message cache and federation state
- Storage: Media growth and database size
- Network: Federation and client traffic

## Disaster Recovery

### 1. Backup Strategy

```yaml
Components to Backup:
├── PostgreSQL Database
│   ├── Full database dumps
│   ├── WAL-E/WAL-G for point-in-time recovery
│   └── Encryption at rest
├── Media Store
│   ├── Object storage replication
│   ├── Cross-region backups
│   └── Deduplication
├── Signing Keys
│   ├── Encrypted backups
│   ├── Secure key escrow
│   └── Multi-location storage
└── Configuration
    ├── Helm values
    ├── Custom configurations
    └── TLS certificates
```

### 2. Recovery Procedures

1. **Database Recovery**: Point-in-time restoration from backups
2. **Media Recovery**: Restore from object storage backups
3. **Key Recovery**: Restore signing keys from secure storage
4. **Service Recovery**: Redeploy with backed-up configurations

This architecture provides a robust, scalable, and secure foundation for Matrix Synapse deployments in Kubernetes environments.