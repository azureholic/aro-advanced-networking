@description('The principal ID to assign the role to')
param principalId string

@description('The role definition ID to assign')
param roleDefinitionId string

@description('The resource ID to assign the role to')
param targetResourceId string

@description('The type of principal (ServicePrincipal, User, Group)')
param principalType string = 'ServicePrincipal'

// Get reference to the target resource for scoping
resource targetResource 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: split(targetResourceId, '/')[8] // Extract VNet name from resource ID
}

// Create the role assignment as an extension resource at the VNet scope
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(targetResourceId, principalId, roleDefinitionId)
  scope: targetResource
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
