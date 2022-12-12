@description('The name of the image name to copy to the Azure Container Registry')
param imageName string

@description('The name of the Azure Container Registry')
param acrName string

param location string

@description('The id of the managed identity to use for the deployment script')
param identityId string

resource addImage 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ACR-Import-${acrName}-${last(split(replace(imageName,':',''),'/'))}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.40.0'
    scriptContent: 'az acr import --source ${imageName} -n ${acrName} --force'
    retentionInterval: 'P1D'
  }
}
