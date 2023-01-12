param domainName string
param cn string
param location string

param identityName string = 'mi-bicep-cert-generation'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

resource generateCerts 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'Generate-AGW-Certificate'
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
      {
        name: 'CN'
        value: cn
      }
    ]
    scriptContent: '''
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=${CN}.${DOMAIN_NAME}/O=Contoso Bicycle" -addext "subjectAltName = DNS:${CN}.${DOMAIN_NAME}" -addext "keyUsage = digitalSignature" -addext "extendedKeyUsage = serverAuth"
      openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
      
      export AGL_CERT=$(cat appgw.pfx | base64 | tr -d '\n')
      
      echo {\"APP_GATEWAY_LISTENER_CERTIFICATE\": \"$AGL_CERT\"} > $AZ_SCRIPTS_OUTPUT_PATH
    '''
    retentionInterval: 'P1D'
  }
}

output certificate string = generateCerts.properties.outputs.APP_GATEWAY_LISTENER_CERTIFICATE
