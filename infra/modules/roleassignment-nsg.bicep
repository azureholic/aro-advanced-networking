@description('The principal ID to assign the role to')
param principalId string

@description('The role definition ID to assign')
param roleDefinitionId string

@description('The NSG resource ID to assign the role to')
param nsgId string

@description('The type of principal (ServicePrincipal, User, Group)')
param principalType string = 'ServicePrincipal'

// Get reference to the NSG for scoping
resource nsgResource 'Microsoft.Network/networkSecurityGroups@2023-09-01' existing = {
  name: split(nsgId, '/')[8] // Extract NSG name from resource ID
}

// Create the role assignment as an extension resource at the NSG scope
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(nsgId, principalId, roleDefinitionId)
  scope: nsgResource
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
