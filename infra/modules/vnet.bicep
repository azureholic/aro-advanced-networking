@description('The location for all network resources')
param location string = resourceGroup().location

@description('The name of the Virtual Network')
param vnetName string

@description('The address prefix for the Virtual Network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Tags to apply to network resources')
param tags object = {}

// Define subnet configurations
var subnets = {
  masters: {
    name: 'snet-masters'
    addressPrefix: '10.0.1.0/24'
    nsgName: '${vnetName}-masters-nsg'
    subnetType: 'masters'
  }
  workers: {
    name: 'snet-workers'
    addressPrefix: '10.0.2.0/24'
    nsgName: '${vnetName}-workers-nsg'
    subnetType: 'workers'
  }
  infraInternal: {
    name: 'snet-infra-internal'
    addressPrefix: '10.0.3.0/24'
    nsgName: '${vnetName}-infra-internal-nsg'
    subnetType: 'infra-internal'
  }
  infraExternal: {
    name: 'snet-infra-external'
    addressPrefix: '10.0.4.0/24'
    nsgName: '${vnetName}-infra-external-nsg'
    subnetType: 'infra-external'
  }
  adcInternal: {
    name: 'snet-adc-internal'
    addressPrefix: '10.0.5.0/24'
    nsgName: '${vnetName}-adc-internal-nsg'
    subnetType: 'adc-internal'
  }
  adcExternal: {
    name: 'snet-adc-external'
    addressPrefix: '10.0.6.0/24'
    nsgName: '${vnetName}-adc-external-nsg'
    subnetType: 'adc-external'
  }
  waf: {
    name: 'snet-waf'
    addressPrefix: '10.0.7.0/24'
    nsgName: '${vnetName}-waf-nsg'
    subnetType: 'waf'
  }
  privateEndpoints: {
    name: 'snet-private-endpoints'
    addressPrefix: '10.0.8.0/24'
    nsgName: '${vnetName}-private-endpoints-nsg'
    subnetType: 'private-endpoints'
  }
}

// Create NSGs for all subnets including ARO master/worker subnets (bringing your own NSGs)

module mastersNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.masters.nsgName}'
  params: {
    location: location
    nsgName: subnets.masters.nsgName
    subnetType: subnets.masters.subnetType
    tags: tags
  }
}

module workersNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.workers.nsgName}'
  params: {
    location: location
    nsgName: subnets.workers.nsgName
    subnetType: subnets.workers.subnetType
    tags: tags
  }
}

module infraInternalNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.infraInternal.nsgName}'
  params: {
    location: location
    nsgName: subnets.infraInternal.nsgName
    subnetType: subnets.infraInternal.subnetType
    tags: tags
  }
}

module infraExternalNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.infraExternal.nsgName}'
  params: {
    location: location
    nsgName: subnets.infraExternal.nsgName
    subnetType: subnets.infraExternal.subnetType
    tags: tags
  }
}

module adcInternalNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.adcInternal.nsgName}'
  params: {
    location: location
    nsgName: subnets.adcInternal.nsgName
    subnetType: subnets.adcInternal.subnetType
    tags: tags
  }
}

module adcExternalNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.adcExternal.nsgName}'
  params: {
    location: location
    nsgName: subnets.adcExternal.nsgName
    subnetType: subnets.adcExternal.subnetType
    tags: tags
  }
}

module wafNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.waf.nsgName}'
  params: {
    location: location
    nsgName: subnets.waf.nsgName
    subnetType: subnets.waf.subnetType
    tags: tags
  }
}

module privateEndpointsNsg 'nsg.bicep' = {
  name: 'deploy-${subnets.privateEndpoints.nsgName}'
  params: {
    location: location
    nsgName: subnets.privateEndpoints.nsgName
    subnetType: subnets.privateEndpoints.subnetType
    tags: tags
  }
}

// Create Virtual Network with all subnets and NSG associations
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnets.masters.name
        properties: {
          addressPrefix: subnets.masters.addressPrefix
          privateLinkServiceNetworkPolicies: 'Disabled'
          privateEndpointNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: mastersNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.workers.name
        properties: {
          addressPrefix: subnets.workers.addressPrefix
          networkSecurityGroup: {
            id: workersNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.infraInternal.name
        properties: {
          addressPrefix: subnets.infraInternal.addressPrefix
          networkSecurityGroup: {
            id: infraInternalNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.infraExternal.name
        properties: {
          addressPrefix: subnets.infraExternal.addressPrefix
          networkSecurityGroup: {
            id: infraExternalNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.adcInternal.name
        properties: {
          addressPrefix: subnets.adcInternal.addressPrefix
          networkSecurityGroup: {
            id: adcInternalNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.adcExternal.name
        properties: {
          addressPrefix: subnets.adcExternal.addressPrefix
          networkSecurityGroup: {
            id: adcExternalNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.waf.name
        properties: {
          addressPrefix: subnets.waf.addressPrefix
          networkSecurityGroup: {
            id: wafNsg.outputs.nsgId
          }
        }
      }
      {
        name: subnets.privateEndpoints.name
        properties: {
          addressPrefix: subnets.privateEndpoints.addressPrefix
          networkSecurityGroup: {
            id: privateEndpointsNsg.outputs.nsgId
          }
        }
      }
    ]
  }
}

// Output important information
@description('The resource ID of the Virtual Network')
output vnetId string = virtualNetwork.id

@description('The name of the Virtual Network')
output vnetName string = virtualNetwork.name

@description('The resource IDs of all subnets')
output subnetIds object = {
  masters: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.masters.name)
  workers: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.workers.name)
  infraInternal: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.infraInternal.name)
  infraExternal: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.infraExternal.name)
  adcInternal: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.adcInternal.name)
  adcExternal: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.adcExternal.name)
  waf: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.waf.name)
  privateEndpoints: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnets.privateEndpoints.name)
}

@description('The subnet configuration object')
output subnets object = subnets

@description('The NSG resource IDs')
output nsgIds object = {
  masters: mastersNsg.outputs.nsgId
  workers: workersNsg.outputs.nsgId
  infraInternal: infraInternalNsg.outputs.nsgId
  infraExternal: infraExternalNsg.outputs.nsgId
  adcInternal: adcInternalNsg.outputs.nsgId
  adcExternal: adcExternalNsg.outputs.nsgId
  waf: wafNsg.outputs.nsgId
  privateEndpoints: privateEndpointsNsg.outputs.nsgId
}
