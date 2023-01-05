targetScope = 'subscription'

param location string

param resourceGroupName string = 'rg-test'

module rg '../CARML/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: resourceGroupName
  params: {
    name: resourceGroupName
    location: location
  }
}

module cert '../single-deploy/generate-cert.bicep' = {
  name: 'cert'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    cn: 'bicycle'
    domainName: 'contoso.com'
  }
}

output aksCert string = cert.outputs.aksIngressCertificate
output aglCert string = cert.outputs.appGatewayCertificate
