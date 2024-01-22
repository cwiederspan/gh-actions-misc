@description('Location for all resources.')
param location string = resourceGroup().location

param namePrefix string = 'gh'
param nameBase string = 'actions'
param nameSuffix string = '20240121'

param vmUsername string = 'vmadmin001'

@secure()
param vmPassword string

param sqlUsername string = 'sqladmin001'

@secure()
param sqlPassword string

@secure()
param kvSecretReaderSpAppObjId string

var baseName = '${namePrefix}-${nameBase}-${nameSuffix}'
var vmSubnetName = 'vm-subnet'

var roleIdMapping = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Certificates Officer': 'a4417e6f-fecd-4de8-b567-7b0420556985'
  'Key Vault Crypto Officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  'Key Vault Crypto Service Encryption User': 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
  'Key Vault Crypto User': '12338af0-0e69-4776-bea7-57ae8d297424'
  'Key Vault Reader': '21090545-7ca7-4776-b22c-e363652d74d2'
  'Key Vault Secrets Officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
}

// resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
//   name: 'examplestorage'
// }

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: '${namePrefix}${nameBase}${nameSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${baseName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${baseName}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    /*
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
    */
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${baseName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, vmSubnetName)
          }
        }
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${baseName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-3389-rdp'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-1433-sql'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '1433'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: '${baseName}-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4ds_v5'
    }
    osProfile: {
      computerName: 'SQLVM001'
      adminUsername: vmUsername
      adminPassword: vmPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftsqlserver'
        offer: 'sql2022-ws2022'
        sku: 'sqldev-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        osType: 'Windows'
        caching: 'ReadOnly'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diffDiskSettings: {
          option: 'Local'
          placement: 'ResourceDisk'
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      /*
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
      */
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id 
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        //storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
    licenseType: 'Windows_Server'
  }
}

resource sqlVm 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2023-01-01-preview' = {
  name: '${baseName}-vm'
  location: location
  properties: {
    virtualMachineResourceId: vm.id
    sqlManagement: 'Full'
    sqlImageOffer: 'SQL2022-WS2022'
    sqlServerLicenseType: 'PAYG'    // AHUB not valid for Developer Edition
    sqlImageSku: 'Developer'
    serverConfigurationsManagementSettings: {
      sqlConnectivityUpdateSettings: {
        connectivityType: 'LOCAL'
        sqlAuthUpdateUserName: sqlUsername
        sqlAuthUpdatePassword: sqlPassword
      }
    }
    /*
    storageConfigurationSettings: {
      diskConfigurationType: diskConfigurationType
      storageWorkloadType: storageWorkloadType
      sqlDataSettings: {
        luns: dataDisksLuns
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLuns
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDbPath
      }
    }*/
  }
}

resource kv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${baseName}-kv'
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    tenantId: subscription().tenantId
    enableSoftDelete: false
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: kv
  name: 'something'
  properties: {
    value: 'Hello, World!'
  }
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleIdMapping['Key Vault Secrets User'], kvSecretReaderSpAppObjId, kv.id)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping['Key Vault Secrets User'])
    principalId: kvSecretReaderSpAppObjId
    principalType: 'ServicePrincipal'
  }
}
