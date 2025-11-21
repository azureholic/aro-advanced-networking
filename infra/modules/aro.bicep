@description('The location for the ARO cluster')
param location string = resourceGroup().location

@description('The name of the Azure Red Hat OpenShift cluster')
param clusterName string

@description('The OpenShift version to deploy')
param aroVersion string

@description('The size of the master VMs')
param masterVmSize string = 'Standard_D8s_v3'

@description('The size of the worker VMs')
param workerVmSize string = 'Standard_D4s_v3'

@description('The number of worker nodes')
param workerNodeCount int = 3

@description('The domain for the cluster')
param domain string

@description('Service principal client ID')
@secure()
param servicePrincipalClientId string

@description('Service principal client secret')
@secure()
param servicePrincipalClientSecret string

@description('The pull secret for the cluster (base64 encoded)')
@secure()
param pullSecret string

@description('Resource ID of the master subnet')
param masterSubnetId string

@description('Resource ID of the worker subnet') 
param workerSubnetId string

@description('API server visibility (Public or Private)')
@allowed(['Public', 'Private'])
param apiServerVisibility string = 'Public'

@description('Default ingress visibility (Public or Private)')
@allowed(['Public', 'Private'])
param ingressVisibility string = 'Private'

@description('Tags to apply to the ARO cluster')
param tags object = {}

@description('The resource group name for managed resources of the cluster. If not provided, a default name will be used.')
param clusterResourcesResourceGroupName string = ''

// Generate resource group name for ARO managed resources
var rgName = clusterResourcesResourceGroupName == '' ? 'aro-${clusterName}-${location}' : clusterResourcesResourceGroupName
var resourceGroupId = subscriptionResourceId('Microsoft.Resources/resourceGroups', rgName)

// Create the Azure Red Hat OpenShift cluster
resource openShiftCluster 'Microsoft.RedHatOpenShift/openShiftClusters@2024-08-12-preview' = {
  name: clusterName
  location: location
  tags: tags
  properties: {
    clusterProfile: {
      domain: domain
      version: aroVersion
      resourceGroupId: resourceGroupId
      pullSecret: pullSecret
      fipsValidatedModules: 'Disabled'
    }
    networkProfile: {
      podCidr: '10.128.0.0/14'
      serviceCidr: '172.30.0.0/16'
      outboundType: 'Loadbalancer'
      preconfiguredNSG: 'Enabled'
    }
    servicePrincipalProfile: {
      clientId: servicePrincipalClientId
      clientSecret: servicePrincipalClientSecret
    }
    masterProfile: {
      vmSize: masterVmSize
      subnetId: masterSubnetId
      encryptionAtHost: 'Disabled'
    }
    workerProfiles: [
      {
        name: 'worker'
        vmSize: workerVmSize
        diskSizeGB: 128
        subnetId: workerSubnetId
        count: workerNodeCount
        encryptionAtHost: 'Disabled'
      }
    ]
    apiserverProfile: {
      visibility: apiServerVisibility
    }
    ingressProfiles: [
      {
        name: 'default'
        visibility: ingressVisibility
      }
    ]
  }
}

// Outputs
@description('The resource ID of the ARO cluster')
output clusterId string = openShiftCluster.id

@description('The ARO cluster name')
output clusterName string = openShiftCluster.name

@description('The ARO API server URL')
output apiServerUrl string = openShiftCluster.properties.apiserverProfile.url

@description('The ARO console URL')
output consoleUrl string = openShiftCluster.properties.consoleProfile.url

@description('The cluster domain')
output clusterDomain string = domain

@description('The cluster resource group ID')
output clusterResourceGroupId string = openShiftCluster.properties.clusterProfile.resourceGroupId
