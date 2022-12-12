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

type hubParamType = {
  @description('Name of the resource group')
  resourceGroupName?: string

  @description('Subnet address prefixes for all AKS clusters nodepools in all attached spokes to allow necessary outbound traffic through the firewall.')
  @minLength(1)
  subnetIpAddressSpace: array

  @description('Optional. Array of Security Rules to deploy to the Network Security Group. When not provided, an NSG including only the built-in roles will be deployed.')
  networkSecurityGroupSecurityRules: array

  @description('A /24 to contain the regional firewall, management, and gateway subnet')
  @minLength(10)
  @maxLength(18)
  hubVnetAddressSpace: string

  @description('A /26 under the VNet Address Space for the regional Azure Firewall')
  @minLength(10)
  @maxLength(18)
  azureFirewallSubnetAddressSpace: string

  @description('A /27 under the VNet Address Space for our regional On-Prem Gateway')
  @minLength(10)
  @maxLength(18)
  azureGatewaySubnetAddressSpace: string

  @description('A /27 under the VNet Address Space for regional Azure Bastion')
  @minLength(10)
  @maxLength(18)
  azureBastionSubnetAddressSpace: string
}

param hubParams hubParamType

// module hub '../rg-hub/hub-default.bicep' = {
//   name: 'hub'
//   params: {
//     resourceGroupName: hubParams.resourceGroupName
//     location: location
//     subnetIpAddressSpace: hubParams.subnetIpAddressSpace
//     networkSecurityGroupSecurityRules: hubParams.networkSecurityGroupSecurityRules
//     hubVnetAddressSpace: hubParams.hubVnetAddressSpace
//     azureFirewallSubnetAddressSpace: hubParams.azureFirewallSubnetAddressSpace
//     azureGatewaySubnetAddressSpace: hubParams.azureGatewaySubnetAddressSpace
//     azureBastionSubnetAddressSpace: hubParams.azureBastionSubnetAddressSpace
//   }
// }

type spokeParamType = {
  @description('Name of the resource group')
  resourceGroupName: string

  @description('A /16 to contain the cluster')
  @minLength(10)
  @maxLength(18)
  clusterVnetAddressSpace: string
}

param spokeParams spokeParamType

// module spoke '../rg-spoke/spoke.bicep' = {
//   name: 'spoke'
//   params: {
//     resourceGroupName: spokeParams.resourceGroupName
//     location: location
//     clusterVnetAddressSpace: spokeParams.clusterVnetAddressSpace
//     hubLaWorkspaceResourceId: hub.outputs.hubLaWorkspaceResourceId
//     hubFwResourceId: hub.outputs.hubFwResourceId
//     hubVnetResourceId: hub.outputs.hubVnetId
//   }
// }

// type acrRegionsType = 'australiaeast'|'australiasoutheast'|'canadacentral'|'canadaeast'|'centralus'|'eastasia'|'eastus'|'eastus2'|'francecentral'|'francesouth'|'germanynorth'|'germanywestcentral'|'japanwest'|'northcentralus'|'northeurope'|'southafricanorth'|'southafricawest'|'southcentralus'|'southeastasia'|'uksouth'|'ukwest'|'westcentralus'|'westeurope'|'westus'|'westus2'

type acrParamType = {
  @description('Name of the resource group')
  resourceGroupName: string

  @description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
  geoRedundancyLocation: 'australiaeast'|'australiasoutheast'|'canadacentral'|'canadaeast'|'centralus'|'eastasia'|'eastus'|'eastus2'|'francecentral'|'francesouth'|'germanynorth'|'germanywestcentral'|'japanwest'|'northcentralus'|'northeurope'|'southafricanorth'|'southafricawest'|'southcentralus'|'southeastasia'|'uksouth'|'ukwest'|'westcentralus'|'westeurope'|'westus'|'westus2'
}

param acrParams acrParamType

module acr '../rg-spoke/acr.bicep' = {
  name: 'acr'
  params: {
    targetVnetResourceId: '/subscriptions/909cb1f4-a3f2-4db6-8482-23ceb7e81eb0/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00'
    //spoke.outputs.clusterVnetResourceId
    resourceGroupName: acrParams.resourceGroupName
    location: location
    geoRedundancyLocation: acrParams.geoRedundancyLocation
  }
}

module mi 'identityForDeployment.bicep' = {
  name: 'mi'
  scope: resourceGroup(acrParams.resourceGroupName)
  params: {
    location: location
    acrName: acr.outputs.containerRegistryName
  }
}

module kuredImage 'copy-image.bicep' = {
  name: 'kuredImage'
  scope: resourceGroup(acrParams.resourceGroupName)
  params: {
    imageName: 'docker.io/weaveworks/kured:1.10.1'
    acrName: acr.outputs.containerRegistryName
    location: location
    identityId: mi.outputs.identityId
  }
}

module traefikImage 'copy-image.bicep' = {
  name: 'traefikImage'
  scope: resourceGroup(acrParams.resourceGroupName)
  params: {
    imageName: 'docker.io/library/traefik:v2.8.1'
    acrName: acr.outputs.containerRegistryName
    location: location
    identityId: mi.outputs.identityId
  }
}
