@description('Username for the virtual machines')
param adminUsername string

@description('Password for the virtual machines')
@minLength(12)
@secure()
param adminPassword string

@description('Unique DNS Name for the Public IP used to access the load balancer.')
param dnsLabelPrefix string = toLower('adc-${uniqueString(resourceGroup().id)}')

@description('Name for the Public IP used to access the load balancer.')
param publicIpName string = 'myPublicIP'

@description('Allocation method for the Public IP used to access the load balancer.')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Dynamic'

@description('SKU for the Public IP used to access the load balancer.')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Basic'

@description('The Windows version for the load balanced VMs. This will pick a fully patched image of this given Windows version.')
@allowed([
  '2016-datacenter-gensecond'
  '2016-datacenter-server-core-g2'
  '2016-datacenter-server-core-smalldisk-g2'
  '2016-datacenter-smalldisk-g2'
  '2016-datacenter-with-containers-g2'
  '2016-datacenter-zhcn-g2'
  '2019-datacenter-core-g2'
  '2019-datacenter-core-smalldisk-g2'
  '2019-datacenter-core-with-containers-g2'
  '2019-datacenter-core-with-containers-smalldisk-g2'
  '2019-datacenter-gensecond'
  '2019-datacenter-smalldisk-g2'
  '2019-datacenter-with-containers-g2'
  '2019-datacenter-with-containers-smalldisk-g2'
  '2019-datacenter-zhcn-g2'
  '2022-datacenter-azure-edition'
  '2022-datacenter-azure-edition-core'
  '2022-datacenter-azure-edition-core-smalldisk'
  '2022-datacenter-azure-edition-smalldisk'
  '2022-datacenter-core-g2'
  '2022-datacenter-core-smalldisk-g2'
  '2022-datacenter-g2'
  '2022-datacenter-smalldisk-g2'
])
param OSVersion string = '2022-datacenter-azure-edition'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_D2s_v5'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the first virtual machine.')
param firstVmName string = 'first-vm'

@description('Name of the second virtual machine that we load balance to')
param secondVmName string = 'second-vm'

@description('Name of the HAProxy vm')
param haProxyVmName string = 'havm'

@description('Security Type of the Virtual Machines.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'TrustedLaunch'

var storageAccountName = 'bootdiags${uniqueString(resourceGroup().id)}'
var firstNicName = 'firstVMNic'
var secondNicName = 'secondVMNic'
var externalNicName = 'haVMNic'
var internalServerAccessNicName = 'isVMNic'

var frontEndSubnetName = 'NSFrontEnd'
var frontEndAddressPrefix = '22.22.0.0/16'
var frontEndSubnetPrefix = '22.22.1.0/24'
var backEndSubnetName = 'NSBackEnd'
var backEndSubnetPrefix = '22.22.2.0/24'

var virtualNetworkName = 'MyVNET'
var frontendNetworkSecurityGroupName = 'frontend-NSG'
var backendNetworkSecurityGroupName = 'backend-NSG'
var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}
var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.WindowsAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'
var maaEndpoint = substring('emptyString', 0, 0)

module storageModule 'storage.bicep' = {
  name: 'storageTemplate'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

// Allow ssh access from the complete outside to port 22
// Allow HTTP 80
resource frontendNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: frontendNetworkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-80'
        properties: {
          priority: 1001
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'default-allow-443'
        properties: {
          priority: 1002
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'default-allow-22'
        properties: {
          priority: 1003
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource backendNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: backendNetworkSecurityGroupName
  location: location
  properties: {
    securityRules: [
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        frontEndAddressPrefix
      ]
    }
    subnets: [
      {
        name: frontEndSubnetName
        properties: {
          addressPrefix: frontEndSubnetPrefix
          networkSecurityGroup: {
            id: frontendNetworkSecurityGroup.id
          }
        }
      }
      {
        name: backEndSubnetName
        properties: {
          addressPrefix: backEndSubnetPrefix
          networkSecurityGroup: {
            id: backendNetworkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource firstNic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: firstNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '22.22.2.10'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, backEndSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource secondNic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: secondNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig2'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '22.22.2.11'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, backEndSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource firstVm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: firstVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: firstVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: firstNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageModule.outputs.storageURI
      }
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfileJson : null)
  }
}

resource firstVmExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if ((securityType == 'TrustedLaunch') && ((securityProfileJson.uefiSettings.secureBootEnabled == true) && (securityProfileJson.uefiSettings.vTpmEnabled == true))) {
  parent: firstVm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}

resource firstVmPostCreationScript 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  parent: firstVm
  name: 'WebServerPrerequisites'
  location: location
  properties: {
    source: {
      scriptUri: 'https://raw.githubusercontent.com/sebug/ha-phang/main/firstVM.ps1'
    }
  }
}

resource secondVm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: secondVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: secondVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: secondNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageModule.outputs.storageURI
      }
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfileJson : null)
  }
}

resource secondVmExtension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if ((securityType == 'TrustedLaunch') && ((securityProfileJson.uefiSettings.secureBootEnabled == true) && (securityProfileJson.uefiSettings.vTpmEnabled == true))) {
  parent: secondVm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}

resource secondVmPostCreationScript 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  parent: secondVm
  name: 'WebServerPrerequisites'
  location: location
  properties: {
    source: {
      scriptUri: 'https://raw.githubusercontent.com/sebug/ha-phang/main/secondVM.ps1'
    }
  }
}

resource externalNic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: externalNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig3'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '22.22.1.50'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, frontEndSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource internalServerAccessNic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: internalServerAccessNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig4'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '22.22.2.50'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, backEndSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource haProxyVM 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: haProxyVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: haProxyVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        patchSettings: {
          patchMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'almalinux'
        offer: 'almalinux'
        sku: '8-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 1023
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: externalNic.id
          properties: {
            primary: false
          }
        }
        {
          id: internalServerAccessNic.id
          properties: {
            primary: false
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageModule.outputs.storageURI
      }
    }
  }
  plan: {
    name: '8-gen2'
    publisher: 'almalinux'
    product: 'almalinux'
  }
}




