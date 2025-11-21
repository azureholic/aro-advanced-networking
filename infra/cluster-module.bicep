// ARO Cluster Module (deployed to cluster resource group scope)
targetScope = 'resourceGroup'

@description('The location for the ARO cluster')
param location string = resourceGroup().location

@description('The name of the Azure Red Hat OpenShift cluster')
param aroClusterName string

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

@description('The pull secret for the cluster (base64 encoded)')
@secure()
param pullSecret string

@description('Resource ID of the master subnet in the network resource group')
param masterSubnetId string

@description('Resource ID of the worker subnet in the network resource group')
param workerSubnetId string

@description('The resource group name for managed ARO cluster resources. If not provided, a default name will be used.')
param clusterResourcesResourceGroupName string = ''

@description('Tags to apply to the ARO cluster')
param tags object = {}

// Deploy Azure Red Hat OpenShift cluster
module aroCluster 'modules/aro.bicep' = {
  name: 'deploy-aro'
  params: {
    location: location
    clusterName: aroClusterName
    aroVersion: aroVersion
    masterVmSize: masterVmSize
    workerVmSize: workerVmSize
    workerNodeCount: workerNodeCount
    domain: domain
    servicePrincipalClientId: servicePrincipalClientId
    servicePrincipalClientSecret: servicePrincipalClientSecret
    pullSecret: pullSecret
    masterSubnetId: masterSubnetId
    workerSubnetId: workerSubnetId
    apiServerVisibility: apiServerVisibility
    ingressVisibility: ingressVisibility
    clusterResourcesResourceGroupName: clusterResourcesResourceGroupName
    tags: tags
  }
}

// Outputs
@description('The resource ID of the ARO cluster')
output aroClusterId string = aroCluster.outputs.clusterId

@description('The ARO cluster name')
output aroClusterName string = aroCluster.outputs.clusterName

@description('The ARO API server URL')
output aroApiServerUrl string = aroCluster.outputs.apiServerUrl

@description('The ARO console URL')
output aroConsoleUrl string = aroCluster.outputs.consoleUrl

@description('Domain name used for the cluster')
output aroDomain string = aroCluster.outputs.clusterDomain

@description('The cluster resource group ID')
output aroClusterResourceGroupId string = aroCluster.outputs.clusterResourceGroupId
