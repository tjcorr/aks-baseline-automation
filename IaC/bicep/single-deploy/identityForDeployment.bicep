param identityName string = 'mi-bicep-deployment'
param location string

@description('The name of the ACR to which the managed identity will be granted access.')
param acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2021-09-01' existing = {
  name: acrName
}

//acrPush is not sufficient to import an image. The docs recommend using contributor or a custom role.
var contributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

//var acrPushRoleDefinitionId =  subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
//var readerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

var roleAssignmentName = guid(subscription().subscriptionId, managedIdentity.name, 'acr-push-role-assignment')

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  scope: acr
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output identityId string = managedIdentity.id
