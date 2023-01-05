targetScope = 'subscription'

@description('The primary location to deploy all resources. The network team maintains this approved regional list which is a subset of zones with Availability Zone support.')
@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
param location string


@description('Name of the resource group')
param hub_resourceGroupName string

@description('Subnet address prefixes for all AKS clusters nodepools in all attached spokes to allow necessary outbound traffic through the firewall.')
@minLength(1)
param hub_subnetIpAddressSpace array

@description('Optional. Array of Security Rules to deploy to the Network Security Group. When not provided, an NSG including only the built-in roles will be deployed.')
param hub_networkSecurityGroupSecurityRules array

@description('A /24 to contain the regional firewall, management, and gateway subnet')
@minLength(10)
@maxLength(18)
param hub_hubVnetAddressSpace string

@description('A /26 under the VNet Address Space for the regional Azure Firewall')
@minLength(10)
@maxLength(18)
param hub_azureFirewallSubnetAddressSpace string

@description('A /27 under the VNet Address Space for our regional On-Prem Gateway')
@minLength(10)
@maxLength(18)
param hub_azureGatewaySubnetAddressSpace string

@description('A /27 under the VNet Address Space for regional Azure Bastion')
@minLength(10)
@maxLength(18)
param hub_azureBastionSubnetAddressSpace string

module hub '../rg-hub/hub-default.bicep' = {
  name: 'hub'
  params: {
    resourceGroupName: hub_resourceGroupName
    location: location
    subnetIpAddressSpace: hub_subnetIpAddressSpace
    networkSecurityGroupSecurityRules: hub_networkSecurityGroupSecurityRules
    hubVnetAddressSpace: hub_hubVnetAddressSpace
    azureFirewallSubnetAddressSpace: hub_azureFirewallSubnetAddressSpace
    azureGatewaySubnetAddressSpace: hub_azureGatewaySubnetAddressSpace
    azureBastionSubnetAddressSpace: hub_azureBastionSubnetAddressSpace
  }
}

@description('Name of the resource group')
param spoke_resourceGroupName string

@description('A /16 to contain the cluster')
@minLength(10)
@maxLength(18)
param spoke_clusterVnetAddressSpace string

module spoke '../rg-spoke/spoke.bicep' = {
  name: 'spoke'
  params: {
    resourceGroupName: spoke_resourceGroupName
    location: location
    clusterVnetAddressSpace: spoke_clusterVnetAddressSpace
    hubLaWorkspaceResourceId: hub.outputs.hubLaWorkspaceResourceId
    hubFwResourceId: hub.outputs.hubFwResourceId
    hubVnetResourceId: hub.outputs.hubVnetId
  }
}

// type acrRegionsType = 'australiaeast'|'australiasoutheast'|'canadacentral'|'canadaeast'|'centralus'|'eastasia'|'eastus'|'eastus2'|'francecentral'|'francesouth'|'germanynorth'|'germanywestcentral'|'japanwest'|'northcentralus'|'northeurope'|'southafricanorth'|'southafricawest'|'southcentralus'|'southeastasia'|'uksouth'|'ukwest'|'westcentralus'|'westeurope'|'westus'|'westus2'


@description('Name of the resource group')
param acr_resourceGroupName string

@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
@allowed([
  'australiaeast'
  'australiasoutheast'
  'canadacentral'
  'canadaeast'
  'centralus'
  'eastasia'
  'eastus'
  'eastus2'
  'francecentral'
  'francesouth'
  'germanynorth'
  'germanywestcentral'
  'japanwest'
  'northcentralus'
  'northeurope'
  'southafricanorth'
  'southafricawest'
  'southcentralus'
  'southeastasia'
  'uksouth'
  'ukwest'
  'westcentralus'
  'westeurope'
  'westus'
  'westus2'
])
param acr_geoRedundancyLocation string

module acr '../rg-spoke/acr.bicep' = {
  name: 'acr'
  params: {
    targetVnetResourceId: spoke.outputs.clusterVnetResourceId
    resourceGroupName: acr_resourceGroupName
    location: location
    geoRedundancyLocation: acr_geoRedundancyLocation
  }
}

module mi '../single-deploy/identityForDeployment.bicep' = {
  name: 'mi'
  scope: resourceGroup(acr_resourceGroupName)
  params: {
    location: location
    acrName: acr.outputs.containerRegistryName
  }
}

module kuredImage '../single-deploy/copy-image.bicep' = {
  name: 'kuredImage'
  scope: resourceGroup(acr_resourceGroupName)
  params: {
    imageName: 'docker.io/weaveworks/kured:1.10.1'
    acrName: acr.outputs.containerRegistryName
    location: location
    identityId: mi.outputs.identityId
  }
}

module traefikImage '../single-deploy/copy-image.bicep' = {
  name: 'traefikImage'
  scope: resourceGroup(acr_resourceGroupName)
  params: {
    imageName: 'docker.io/library/traefik:v2.8.1'
    acrName: acr.outputs.containerRegistryName
    location: location
    identityId: mi.outputs.identityId
  }
}

param prereqs_resourceGroupName string

@description('Key Vault public network access.')
param prereqs_keyVaultPublicNetworkAccess string

@description('Domain name to use for App Gateway and AKS ingress.')
param prereqs_domainName string

@description('The CN to be used along with the domain name (ie: bicycle will result in fqdn of bicycle.contoso.com)')
param prereqs_cn string

@description('The certificate to use for the App Gateway listener. If blank a certificate will be auto-generated.')
param prereqs_appGatewayListenerCertificate string = ''

@description('The certificate to use for the AKS Ingress Controller. If blank a certificate will be auto-generated.')
param prereqs_aksIngressControllerCertificate string = ''


module clusterPrereqs '../rg-spoke/clusterprereq.bicep' = {
  name: 'cluster-prereqs'
  params: {
    resourceGroupName: prereqs_resourceGroupName
    vNetResourceGroup: spoke_resourceGroupName
    location: location
    keyVaultPublicNetworkAccess: prereqs_keyVaultPublicNetworkAccess
    domainName: prereqs_domainName
    cn: prereqs_cn
    targetVnetResourceId: spoke.outputs.clusterVnetResourceId
    appGatewayListenerCertificate: prereqs_appGatewayListenerCertificate
    aksIngressControllerCertificate: prereqs_aksIngressControllerCertificate
  }
}
