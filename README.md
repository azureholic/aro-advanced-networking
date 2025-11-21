# Azure Red Hat OpenShift (ARO) Infrastructure

This repository contains infrastructure-as-code and deployment scripts for deploying Azure Red Hat OpenShift clusters with a split resource group architecture and dedicated infrastructure nodes.

## Architecture

The deployment creates:
- **Split Resource Groups**: Separate network and cluster resource groups for better management
- **Network Infrastructure**: VNet with 8 subnets including master, worker, infra (internal/external), ADC (internal/external), WAF, and private endpoints
- **Infrastructure Nodes**: Dedicated nodes for ingress controllers across 3 availability zones
  - 3 internal infra nodes for internal traffic
  - 3 external infra nodes for external traffic
- **Ingress Controllers**: Default, internal, and external ingress controllers for routing traffic

## Prerequisites

- Azure CLI installed and configured
- OpenShift CLI (oc) installed
- Azure subscription with permissions to create resources
- Service Principal with Network Contributor role
- Red Hat pull secret (save to `pullsecret.txt`)

## Quick Start

1. **Configure environment variables**
   ```bash
   cp .env.sample .env
   # Edit .env with your Azure subscription and configuration
   ```

2. **Deploy infrastructure and cluster**
   ```powershell
   .\deploy.ps1
   ```

3. **Deploy infrastructure nodes**
   ```bash
   kubectl apply -f manifests/infra-nodes-internal-zone1.yaml
   kubectl apply -f manifests/infra-nodes-internal-zone2.yaml
   kubectl apply -f manifests/infra-nodes-internal-zone3.yaml
   kubectl apply -f manifests/infra-nodes-external-zone1.yaml
   kubectl apply -f manifests/infra-nodes-external-zone2.yaml
   kubectl apply -f manifests/infra-nodes-external-zone3.yaml
   ```

4. **Configure ingress controllers**
   ```bash
   kubectl apply -f manifests/default-ingress-to-infra.yaml
   kubectl apply -f manifests/ingress-controller-internal.yaml
   kubectl apply -f manifests/ingress-controller-external.yaml
   ```

## Repository Structure

```
├── infra/                    # Bicep templates for infrastructure
│   ├── main.bicep           # Main deployment template
│   ├── network-module.bicep # Network resources and RBAC
│   ├── cluster-module.bicep # ARO cluster configuration
│   └── modules/             # Reusable Bicep modules
├── manifest-templates/       # OpenShift manifest templates with placeholders
├── manifests/               # Processed manifests ready for deployment
├── docs/                    # Documentation
├── architecture/            # Architecture diagrams
├── deploy.ps1              # Main deployment script
└── .env                    # Configuration (not in git)
```

## Configuration

Key settings in `.env`:
- **CLIENT_ID / CLIENT_SECRET**: Service Principal credentials
- **SUBSCRIPTION_ID**: Target Azure subscription
- **LOCATION**: Azure region (default: uksouth)
- **ARO_CLUSTER_NAME**: Name for your ARO cluster
- **VNET_NAME**: Virtual network name
- **MASTER_VM_SIZE / WORKER_VM_SIZE**: VM sizes for nodes

## Network Subnets

| Subnet | Address | Purpose |
|--------|---------|---------|
| snet-masters | 10.0.1.0/24 | Control plane nodes |
| snet-workers | 10.0.2.0/24 | Worker nodes |
| snet-infra-internal | 10.0.3.0/24 | Internal infra nodes |
| snet-infra-external | 10.0.4.0/24 | External infra nodes |
| snet-adc-internal | 10.0.5.0/24 | Internal load balancer |
| snet-adc-external | 10.0.6.0/24 | External load balancer |
| snet-waf | 10.0.7.0/24 | Web Application Firewall |
| snet-private-endpoints | 10.0.8.0/24 | Private endpoints |

## Troubleshooting

### RBAC Permissions
If infrastructure nodes fail to provision due to subnet read permissions:
```powershell
.\fix-infra-subnet-rbac.ps1
```

### View Cluster Info
```bash
kubectl get nodes
kubectl get machinesets -n openshift-machine-api
kubectl get ingresscontrollers -n openshift-ingress-operator
```


