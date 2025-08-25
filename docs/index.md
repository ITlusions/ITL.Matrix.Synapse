# ITL Matrix Synapse Helm Chart

Welcome to the ITL Matrix Synapse Helm Chart documentation. This chart enables deployment and management of Matrix Synapse homeserver instances with multi-tenant support.

## Overview

The `synapse-tenant` Helm chart is designed to deploy and manage multiple Synapse Matrix tenants in a Kubernetes environment. Matrix Synapse is an open-source homeserver implementation for the Matrix communication protocol, used for real-time communication including chat, messaging, and collaboration.

## Key Features

- **Multi-tenant Support**: Deploy and manage multiple isolated Synapse instances
- **Kubernetes Native**: Built specifically for Kubernetes environments using modern practices
- **Ingress Management**: Automated ingress configuration for each tenant
- **Database Support**: PostgreSQL database creation and management per tenant
- **Security**: Built-in security configurations and secrets management
- **Scalability**: Configurable resource allocation and scaling options

## Quick Start

```bash
# Clone the repository
git clone https://github.com/itlusions/ITL.Matrix.Synapse.git
cd ITL.Matrix.Synapse

# Install with default values
helm install my-synapse-tenant ./chart

# Install with custom values
helm install my-synapse-tenant ./chart -f custom-values.yaml
```

## Documentation Structure

- [Installation Guide](installation.md) - Step-by-step installation instructions
- [Configuration Reference](configuration.md) - Complete configuration options
- [Security Guide](security.md) - Security best practices and configuration
- [Deployment Guide](deployment.md) - Production deployment recommendations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Architecture](architecture.md) - System architecture and components
- [Recommendations](recommendations.md) - Code review findings and improvements

## Repository Information

- **Repository**: [ITL.Matrix.Synapse](https://github.com/ITlusions/ITL.Matrix.Synapse)
- **Chart Version**: 1.0.0
- **App Version**: v1.0.0
- **Maintainer**: ITlusions (info@itlusions.com)

## License

This chart is licensed under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).