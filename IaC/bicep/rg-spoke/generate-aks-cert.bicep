param domainName string
param location string

param identityName string = 'mi-bicep-cert-generation'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource generateCerts 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'Generate-AKS-Certificate'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.40.0'
    environmentVariables: [
      {
        name: 'DOMAIN_NAME'
        value: domainName
      }
    ]
    scriptContent: '''
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-tls.crt -keyout traefik-ingress-internal-aks-ingress-tls.key -subj "/CN=*.aks-ingress.${DOMAIN_NAME}/O=Contoso AKS Ingress"
      export AKS_CERT=$(cat traefik-ingress-internal-aks-ingress-tls.crt | base64 | tr -d '\n')
      
      echo {\"AKS_INGRESS_CONTROLLER_CERTIFICATE\": \"$AKS_CERT\"} > $AZ_SCRIPTS_OUTPUT_PATH
    '''
    retentionInterval: 'P1D'
  }
}

output certificate string = generateCerts.properties.outputs.AKS_INGRESS_CONTROLLER_CERTIFICATE
