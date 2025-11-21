// Main deployment template for ARO with split resource groups
// This template deploys to subscription scope and creates resources in two separate RGs

targetScope = 'subscription'

@description('The location for all resources')
param location string = 'uksouth'

@description('The name of the network resource group')
param networkResourceGroupName string = 'rg-cluster-network'

@description('The name of the cluster resource group')
param clusterResourceGroupName string = 'rg-cluster-cluster'

@description('The name of the Virtual Network')
param vnetName string = 'vnet-aro-cluster'

@description('The address prefix for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('The name of the Azure Red Hat OpenShift cluster')
param aroClusterName string = 'aro-cluster'

@description('The OpenShift version to deploy')
param aroVersion string

@description('The size of the master VMs')
param masterVmSize string = 'Standard_D8s_v3'

@description('The size of the worker VMs')
param workerVmSize string = 'Standard_D4s_v3'

@description('The number of worker nodes')
param workerNodeCount int = 3

@description('The domain for the cluster')
param domain string = '${aroClusterName}.${location}.aroapp.io'

@description('API server visibility - Public for testing, Private for production')
@allowed(['Public', 'Private'])
param apiServerVisibility string = 'Public'

@description('Default ingress visibility')
@allowed(['Public', 'Private'])
param ingressVisibility string = 'Public'

@description('Service principal client ID')
@secure()
param servicePrincipalClientId string

@description('Service principal client secret')
@secure()
param servicePrincipalClientSecret string

@description('Service principal object ID (for role assignments)')
param servicePrincipalObjectId string

@description('ARO Resource Provider object ID (for role assignments)')
param aroResourceProviderObjectId string

@description('The resource group name for managed ARO cluster resources. If not provided, a default name will be used.')
param clusterResourcesResourceGroupName string = ''

// Load pull secret directly from file
var pullSecret = loadTextContent('../pullsecret.txt')

// Common tags for all resources
var commonTags = {
  Purpose: 'Azure Red Hat OpenShift'
  Environment: 'Production'
}

// Create network resource group
resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: networkResourceGroupName
  location: location
  tags: commonTags
}

// Create cluster resource group
resource clusterResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: clusterResourceGroupName
  location: location
  tags: commonTags
}

// Deploy network infrastructure to network resource group
module networkInfrastructure 'network-module.bicep' = {
  name: 'deploy-network-infrastructure'
  scope: networkResourceGroup
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    servicePrincipalObjectId: servicePrincipalObjectId
    aroResourceProviderObjectId: aroResourceProviderObjectId
    tags: commonTags
  }
}

// Deploy ARO cluster to cluster resource group
module aroClusterInfrastructure 'cluster-module.bicep' = {
  name: 'deploy-aro-cluster'
  scope: clusterResourceGroup
  params: {
    location: location
    aroClusterName: aroClusterName
    aroVersion: aroVersion
    masterVmSize: masterVmSize
    workerVmSize: workerVmSize
    workerNodeCount: workerNodeCount
    domain: domain
    servicePrincipalClientId: servicePrincipalClientId
    servicePrincipalClientSecret: servicePrincipalClientSecret
    pullSecret: pullSecret
    masterSubnetId: networkInfrastructure.outputs.subnetIds.masters
    workerSubnetId: networkInfrastructure.outputs.subnetIds.workers
    apiServerVisibility: apiServerVisibility
    ingressVisibility: ingressVisibility
    clusterResourcesResourceGroupName: clusterResourcesResourceGroupName
    tags: commonTags
  }
}

// Outputs
@description('The network resource group name')
output networkResourceGroupName string = networkResourceGroup.name

@description('The cluster resource group name')
output clusterResourceGroupName string = clusterResourceGroup.name

@description('The resource ID of the Virtual Network')
output vnetId string = networkInfrastructure.outputs.vnetId

@description('The name of the Virtual Network')
output vnetName string = networkInfrastructure.outputs.vnetName

@description('The resource IDs of all subnets')
output subnetIds object = networkInfrastructure.outputs.subnetIds

@description('The NSG resource IDs')
output nsgIds object = networkInfrastructure.outputs.nsgIds

@description('The resource ID of the ARO cluster')
output aroClusterId string = aroClusterInfrastructure.outputs.aroClusterId

@description('The ARO cluster name')
output aroClusterName string = aroClusterInfrastructure.outputs.aroClusterName

@description('The ARO API server URL')
output aroApiServerUrl string = aroClusterInfrastructure.outputs.aroApiServerUrl

@description('The ARO console URL')
output aroConsoleUrl string = aroClusterInfrastructure.outputs.aroConsoleUrl

@description('Domain name used for the cluster')
output aroDomain string = aroClusterInfrastructure.outputs.aroDomain

@description('The cluster resource group ID')
output aroClusterResourceGroupId string = aroClusterInfrastructure.outputs.aroClusterResourceGroupId
