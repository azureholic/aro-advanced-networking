// Network Infrastructure Module (deployed to network resource group scope)
targetScope = 'resourceGroup'

@description('The location for all network resources')
param location string = resourceGroup().location

@description('The name of the Virtual Network')
param vnetName string

@description('The address prefix for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Service principal object ID (for role assignments)')
param servicePrincipalObjectId string

@description('ARO Resource Provider object ID (for role assignments)')
param aroResourceProviderObjectId string

@description('Tags to apply to network resources')
param tags object = {}

// Constants for ARO RBAC
var NetworkContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'

// Deploy Virtual Network with NSGs
module virtualNetwork 'modules/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    tags: tags
  }
}

// Set RBAC permissions for the service principal on VNet
module setNetworkContributorVnet 'modules/roleassignment.bicep' = {
  name: 'set-network-contributor-vnet'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    targetResourceId: virtualNetwork.outputs.vnetId
    principalType: 'ServicePrincipal'
  }
}

// Set RBAC permissions for the ARO resource provider on VNet
module setNetworkContributorAroRpVnet 'modules/roleassignment.bicep' = {
  name: 'set-network-contributor-arorp-vnet'
  dependsOn: [
    setNetworkContributorVnet
  ]
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    targetResourceId: virtualNetwork.outputs.vnetId
    principalType: 'ServicePrincipal'
  }
}

// Set RBAC permissions for the service principal on ALL NSGs
module setNetworkContributorSpMastersNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-sp-masters-nsg'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.masters
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorSpWorkersNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-sp-workers-nsg'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.workers
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorSpInfraInternalNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-sp-infra-internal-nsg'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.infraInternal
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorSpInfraExternalNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-sp-infra-external-nsg'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.infraExternal
    principalType: 'ServicePrincipal'
  }
}

// Set RBAC permissions for the ARO resource provider on ALL NSGs
module setNetworkContributorAroRpMastersNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-arorp-masters-nsg'
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.masters
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorAroRpWorkersNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-arorp-workers-nsg'
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.workers
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorAroRpInfraInternalNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-arorp-infra-internal-nsg'
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.infraInternal
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorAroRpInfraExternalNsg 'modules/roleassignment-nsg.bicep' = {
  name: 'set-network-contributor-arorp-infra-external-nsg'
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    nsgId: virtualNetwork.outputs.nsgIds.infraExternal
    principalType: 'ServicePrincipal'
  }
}

// Set RBAC permissions for the service principal on infra subnets (required for Machine API to create nodes)
module setNetworkContributorSpInfraInternalSubnet 'modules/roleassignment-subnet.bicep' = {
  name: 'set-network-contributor-sp-infra-internal-subnet'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    subnetId: virtualNetwork.outputs.subnetIds.infraInternal
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorSpInfraExternalSubnet 'modules/roleassignment-subnet.bicep' = {
  name: 'set-network-contributor-sp-infra-external-subnet'
  params: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: NetworkContributor
    subnetId: virtualNetwork.outputs.subnetIds.infraExternal
    principalType: 'ServicePrincipal'
  }
}

// Set RBAC permissions for the ARO resource provider on infra subnets
module setNetworkContributorAroRpInfraInternalSubnet 'modules/roleassignment-subnet.bicep' = {
  name: 'set-network-contributor-arorp-infra-internal-subnet'
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    subnetId: virtualNetwork.outputs.subnetIds.infraInternal
    principalType: 'ServicePrincipal'
  }
}

module setNetworkContributorAroRpInfraExternalSubnet 'modules/roleassignment-subnet.bicep' = {
  name: 'set-network-contributor-arorp-infra-external-subnet'
  params: {
    principalId: aroResourceProviderObjectId
    roleDefinitionId: NetworkContributor
    subnetId: virtualNetwork.outputs.subnetIds.infraExternal
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('The resource ID of the Virtual Network')
output vnetId string = virtualNetwork.outputs.vnetId

@description('The name of the Virtual Network')
output vnetName string = virtualNetwork.outputs.vnetName

@description('The resource IDs of all subnets')
output subnetIds object = virtualNetwork.outputs.subnetIds

@description('The subnet configuration object')
output subnets object = virtualNetwork.outputs.subnets

@description('The NSG resource IDs')
output nsgIds object = virtualNetwork.outputs.nsgIds
