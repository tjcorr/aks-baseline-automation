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
  // this is needed in case you are deploying to the same RG as ACR otherwise you will get a conflict
  dependsOn: [
    acr
  ]
}

@description('Name of the resource group')
param cluster_resourceGroupName string = 'rg-bu0001a0008'

@description('Azure AD Group in the identified tenant that will be granted the highly privileged cluster-admin role. If Azure RBAC is used, then this group will get a role assignment to Azure RBAC, else it will be assigned directly to the cluster\'s admin group.')
param cluster_clusterAdminAadGroupObjectId string

@description('Azure AD Group in the identified tenant that will be granted the read only privileges in the a0008 namespace that exists in the cluster. This is only used when Azure RBAC is used for Kubernetes RBAC.')
param cluster_a0008NamespaceReaderAadGroupObjectId string

@description('IP ranges authorized to contact the Kubernetes API server. Passing an empty array will result in no IP restrictions. If any are provided, remember to also provide the public IP of the egress Azure Firewall otherwise your nodes will not be able to talk to the API server (e.g. Flux).')
param cluster_clusterAuthorizedIPRanges array = []

param cluster_kubernetesVersion string

@description('Your cluster will be bootstrapped from this git repo.')
@minLength(9)
param cluster_gitOpsBootstrappingRepoHttpsUrl string

@description('You cluster will be bootstrapped from this branch in the identifed git repo.')
@minLength(1)
param cluster_gitOpsBootstrappingRepoBranch string

@description('The minimum number of compute nodes in the primary user pool.')
param cluster_minNodes int = 2

@description('The maximum number of compute nodes in the primary user pool.')
param cluster_maxNodes int = 5

module cluster '../rg-spoke/cluster.bicep' = {
  name: 'cluster'
  params: {
    resourceGroupName: cluster_resourceGroupName
    vNetResourceGroup: spoke_resourceGroupName
    a0008NamespaceReaderAadGroupObjectId: cluster_clusterAdminAadGroupObjectId
    clusterAdminAadGroupObjectId: cluster_a0008NamespaceReaderAadGroupObjectId
    clusterAuthorizedIPRanges: cluster_clusterAuthorizedIPRanges
    domainName: prereqs_domainName
    gitOpsBootstrappingRepoBranch: cluster_gitOpsBootstrappingRepoBranch
    gitOpsBootstrappingRepoHttpsUrl: cluster_gitOpsBootstrappingRepoHttpsUrl
    kubernetesVersion: cluster_kubernetesVersion
    location: location
    targetVnetResourceId: spoke.outputs.clusterVnetResourceId
    minNodes: cluster_minNodes
    maxNodes: cluster_maxNodes
  }
  dependsOn: [
    clusterPrereqs
    kuredImage
    traefikImage
  ]
}
