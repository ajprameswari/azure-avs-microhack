// Sample deployment command :
// az deployment group create -n Deploy -g azure-avs-microhack-rg --template-file 1-main.bicep 
// with "--parameter .\param\main.param.json" if parameters are used

// VPN Shared key intentionaly left in clear text. This is just an ephemeral lab

// Location to deploy the below resources
param location string = 'canadacentral'

// If you want to deploy the Express Route (ER) gateway : true. Otherwise : false
param deployGateway bool = true

// User number to pick the correct IP ranges
@allowed([
  1
  2
  3
  4
  5
  6
  7
  8
  9
  10
  11
  12
])
param userId int

// Default to 1 as it is the only supported ID for real microhack deployment
param proctorId int = 1

// Change the scope to be able to create the resource group before resources
// then we specify scope at resourceGroup level for all others resources
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'azure-avs-microhack-user-${userId}-rg'
  location: location
}


// Create base virtual network to host the Jumpbox and the Express Route gateway
module adminVnet '../_modules/vnet.bicep' = {
  name: 'adminVnet'
  scope: rg
  params: {
    location: location
    name: 'adminVnet'
    userId: userId
    proctorId: proctorId
  }
}

// Create the VPN gateway in the base virtual network
module vpnGw '../_modules/vpngw.bicep' = if(deployGateway) {
  name: 'vpn-gw'
  scope: rg
  params: {
    gwSubnetId: adminVnet.outputs.subnets[0].id
    location: location
    name: 'vpn-gw'
    userId: userId
    usersIpRanges: adminVnet.outputs.usersIpRanges
  }
}

// LNG to Hub
module lngToHub '../_modules/lng.bicep' = {
  scope: rg
  name: 'lngToHub'
  params: {
    location: location
    name: 'lngToHub'
    userId: userId
    usersIpRanges: adminVnet.outputs.usersIpRanges
  }
}

// connection
module vpnToHubConnection '../_modules/vpnConnection.bicep' = {
  scope: rg
  name: 'connectionToHub'
  params: {
    location: location
    name: 'connectionToHub'
    remoteLngId: lngToHub.outputs.lngId
    vpnGwId: vpnGw.outputs.vpnGwId
    vpnPreSharedKey: 'MicrosoftMicroHack@1234$'
  } 
}

// Create the jumpbox VM

module jumpboxVm '../_modules/vm.bicep' = {
  name: 'jumpbox'
  dependsOn: [
    vpnToHubConnection
  ]
  scope: rg
  params: {
    location: location
    subnetId: adminVnet.outputs.subnets[1].id
    vmName: 'jumpbox'
    osType: 'desktop'
  }
}

// Azure Bastion to admin the jumpbox if required

module bastionHost '../_modules/bastion.bicep' = {
  name: 'bastion'
  scope: rg
  params: {
    location: location
    name: 'bastion'
    subnetId: adminVnet.outputs.subnets[2].id
  } 
}
