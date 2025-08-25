# Installation Guide

This guide provides step-by-step instructions for installing the ITL Matrix Synapse Helm chart.

## Prerequisites

Before installing the chart, ensure you have the following prerequisites:

### Required
- **Kubernetes**: Version 1.19 or higher
- **Helm**: Version 3.0 or higher
- **Storage Class**: A default or specified storage class for persistent volumes
- **Ingress Controller**: A working ingress controller (Traefik, NGINX, etc.)

### Optional
- **Cert-Manager**: For automatic TLS certificate management
- **PostgreSQL**: External PostgreSQL instance (if not using the bundled one)
- **Keycloak/OIDC Provider**: For single sign-on authentication

## Pre-Installation Steps

### 1. Verify Kubernetes Cluster

```bash
# Check cluster info
kubectl cluster-info

# Verify node readiness
kubectl get nodes

# Check available storage classes
kubectl get storageclass
```

### 2. Install Required Dependencies

#### Install Ingress Controller (if not present)
```bash
# For Traefik
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik

# For NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
```

#### Install Cert-Manager (optional but recommended)
```bash
# Add cert-manager repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/itlusions/ITL.Matrix.Synapse.git
cd ITL.Matrix.Synapse
```

### 2. Review and Customize Values

Copy and modify the default values file:

```bash
cp chart/values.yaml my-values.yaml
```

Edit `my-values.yaml` to configure your tenant:

```yaml
tenant:
  name: my-matrix-tenant
  homeserver:
    values:
      reportStats: false
      serverName: matrix.mydomain.com
  ingress:
    enabled: true
    className: "traefik"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: matrix-tls
        hosts:
          - matrix.mydomain.com
    hosts:
      - host: matrix.mydomain.com
        paths:
          - path: /
            pathType: Prefix
```

### 3. Install the Chart

#### Basic Installation
```bash
helm install my-synapse-tenant ./chart
```

#### Installation with Custom Values
```bash
helm install my-synapse-tenant ./chart -f my-values.yaml
```

#### Installation in Custom Namespace
```bash
# Create namespace
kubectl create namespace matrix

# Install in namespace
helm install my-synapse-tenant ./chart \
  --namespace matrix \
  -f my-values.yaml
```

## Post-Installation Steps

### 1. Verify Installation

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=my-synapse-tenant

# Check services
kubectl get services -l app.kubernetes.io/name=my-synapse-tenant

# Check ingress
kubectl get ingress
```

### 2. Access Synapse

Once the installation is complete and pods are running:

1. **Web Interface**: Access your Matrix homeserver at `https://matrix.mydomain.com`
2. **Admin Interface**: Access the admin panel at `https://matrix.mydomain.com/_synapse/admin`

### 3. Create Admin User

```bash
# Get the pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=my-synapse-tenant -o jsonpath='{.items[0].metadata.name}')

# Register admin user
kubectl exec -it $POD_NAME -- register_new_matrix_user \
  -u admin \
  -p your-secure-password \
  -a \
  -c /data/homeserver.yaml \
  http://localhost:8008
```

## Upgrade

To upgrade your installation:

```bash
# Update values if needed
vim my-values.yaml

# Upgrade the release
helm upgrade my-synapse-tenant ./chart -f my-values.yaml
```

## Uninstallation

To completely remove the installation:

```bash
# Uninstall the release
helm uninstall my-synapse-tenant

# Remove namespace (if created)
kubectl delete namespace matrix
```

⚠️ **Warning**: This will delete all data including user accounts, rooms, and media files. Ensure you have backups before proceeding.

## Troubleshooting Installation

### Common Issues

1. **Pods stuck in Pending state**
   - Check storage class availability
   - Verify node resources

2. **Ingress not accessible**
   - Verify ingress controller is running
   - Check DNS configuration
   - Validate TLS certificate issues

3. **Database connection issues**
   - Check PostgreSQL pod status
   - Verify database credentials

For detailed troubleshooting, see the [Troubleshooting Guide](troubleshooting.md).