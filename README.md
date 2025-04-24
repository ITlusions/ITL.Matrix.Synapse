### README for `synapse-tenant` Helm Chart

---

#### Overview
The `synapse-tenant` Helm chart is designed to deploy and manage multiple Synapse Matrix tenants. Synapse is an open-source Matrix homeserver used for real-time communication, including chat, messaging, and collaboration.

Repository: [ITL.Matrix.Synapse](https://github.com/itlusions/ITL.Matrix.Synapse)

---

#### Features
- Deploy multiple Synapse Matrix tenants.
- Configure ingress rules for each tenant.
- Manage PostgreSQL database creation for tenants.
- Customize homeserver settings for each tenant.

---

#### Prerequisites
- Kubernetes 1.19+
- Helm 3.0+
- A working ingress controller (e.g., Traefik, NGINX).
- Optional: Cert-Manager for TLS certificates.

---

#### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/itlusions/ITL.Matrix.Synapse.git
   cd ITL.Matrix.Synapse
   ```

2. Install the chart:
   ```bash
   helm install my-synapse-tenant ./ -f values.yaml
   ```

---

#### Configuration

The chart uses a values.yaml file to define tenant-specific configurations. Below is an example:

```yaml
tenants:
  - name: tenant1
    createNewPostgreSQL: true
    homeserver:
      values:
        reportStats: true
        serverName: matrix.tenant1.com
    ingress:
      matrix:
        enabled: true
        ingressClassName: "traefik"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-issuer"
        tls:
          - secretName: tenant1-tls
            hosts:
              - matrix.tenant1.com
        hosts:
          - host: matrix.tenant1.com
            path: /
            pathType: Prefix
```

---

#### Values

| Key                              | Description                                   | Default              |
|----------------------------------|-----------------------------------------------|----------------------|
| `tenants[].name`                 | Name of the tenant                           | `nil`                |
| `tenants[].createNewPostgreSQL`  | Whether to create a new PostgreSQL instance  | `false`              |
| `tenants[].homeserver.values`    | Configuration for the Synapse homeserver     | See values.yaml    |
| `tenants[].ingress.matrix`       | Ingress configuration for the tenant         | See values.yaml    |

---

#### Uninstallation

To uninstall the chart:
```bash
helm uninstall my-synapse-tenant
```

---

#### License
This chart is licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).

---# ITL.Matrix.Synapse
