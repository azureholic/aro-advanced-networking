@description('The principal ID to assign the role to')
param principalId string

@description('The role definition ID to assign')
param roleDefinitionId string

@description('The subnet resource ID to assign the role to')
param subnetId string

@description('The type of principal (ServicePrincipal, User, Group)')
param principalType string = 'ServicePrincipal'

// Get reference to the subnet for scoping
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  name: '${split(subnetId, '/')[8]}/${split(subnetId, '/')[10]}' // Extract VNet and subnet names from resource ID
}

// Create the role assignment as an extension resource at the subnet scope
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subnetId, principalId, roleDefinitionId)
  scope: subnet
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: principalType
  }
}

// Outputs
@description('The role assignment ID')
output roleAssignmentId string = roleAssignment.id

@description('The role assignment name')
output roleAssignmentName string = roleAssignment.name
