resource "azurerm_role_definition" "ccm_csi" {
  name        = format("CCM and CSI role for %s", local.vcluster_name)
  scope       = local.resource_group_id
  description = "Custom role for Kubernetes Azure CCM and CSI (LoadBalancers, PIPs, NSG rules, routes, disks, snapshots, storage)."

  permissions {
    actions = [
      // Required to create, delete or update LoadBalancer for LoadBalancer service
      "Microsoft.Network/loadBalancers/delete",
      "Microsoft.Network/loadBalancers/read",
      "Microsoft.Network/loadBalancers/write",
      "Microsoft.Network/loadBalancers/backendAddressPools/read",
      "Microsoft.Network/loadBalancers/backendAddressPools/write",
      "Microsoft.Network/loadBalancers/backendAddressPools/delete",
      "Microsoft.Network/loadBalancers/inboundNatRules/join/action",

      // Required to allow query, create or delete public IPs for LoadBalancer service
      "Microsoft.Network/publicIPAddresses/delete",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/write",

      // Required if public IPs from another resource group are used for LoadBalancer service
      // This is because of the linked access check when adding the public IP to LB frontendIPConfiguration
      "Microsoft.Network/publicIPAddresses/join/action",

      // Required if a public IP Prefix from another resource group is used for LoadBalancer service
      // This is because of the linked access check when adding the public IP of a public IP
      // prefix to a LB frontendIPConfiguration
      "Microsoft.Network/publicIPPrefixes/join/action",

      // Required to create or delete security rules for LoadBalancer service
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/networkSecurityGroups/join/action",

      // Required to read application security group IDs while writing security rules
      "Microsoft.Network/applicationSecurityGroups/joinNetworkSecurityRule/action",

      // Required to create, delete or update AzureDisks
      "Microsoft.Compute/disks/delete",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/locations/DiskOperations/read",

      // Required to create, update or delete storage accounts for AzureFile or AzureDisk
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.Storage/storageAccounts/listKeys/action",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/write",
      "Microsoft.Storage/operations/read",

      // Required to create, delete or update routeTables and routes for nodes
      "Microsoft.Network/routeTables/read",
      "Microsoft.Network/routeTables/routes/delete",
      "Microsoft.Network/routeTables/routes/read",
      "Microsoft.Network/routeTables/routes/write",
      "Microsoft.Network/routeTables/write",

      // Required to query information for VM (e.g. zones, faultdomain, size and data disks)
      "Microsoft.Compute/virtualMachines/read",

      // Required to attach AzureDisks to VM
      "Microsoft.Compute/virtualMachines/write",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",

      // Required to query information for vmssVM (e.g. zones, faultdomain, size and data disks)
      "Microsoft.Compute/virtualMachineScaleSets/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read",
      "Microsoft.Compute/virtualMachineScaleSets/virtualmachines/instanceView/read",

      // Required to add VM to LoadBalancer backendAddressPools
      "Microsoft.Network/networkInterfaces/write",
      // Required to add vmss to LoadBalancer backendAddressPools
      "Microsoft.Compute/virtualMachineScaleSets/write",
      // Required to attach AzureDisks and add vmssVM to LB
      "Microsoft.Compute/virtualMachineScaleSets/virtualmachines/write",

      // Required to query internal IPs and loadBalancerBackendAddressPools for VM
      "Microsoft.Network/networkInterfaces/read",
      // Required to query internal IPs and loadBalancerBackendAddressPools for vmssVM
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces/read",
      // Required to get public IPs for vmssVM
      "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces/ipconfigurations/publicipaddresses/read",

      // Required to check whether subnet existing for ILB in another resource group
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",

      // Required to create, update or delete snapshots for AzureDisk
      "Microsoft.Compute/snapshots/delete",
      "Microsoft.Compute/snapshots/read",
      "Microsoft.Compute/snapshots/write",

      // Required to get vm sizes for getting AzureDisk volume limit
      "Microsoft.Compute/locations/vmSizes/read",
      "Microsoft.Compute/locations/operations/read",

      // Required to create, update or delete PrivateLinkService for Service
      "Microsoft.Network/privatelinkservices/delete",
      "Microsoft.Network/privatelinkservices/privateEndpointConnections/delete",
      "Microsoft.Network/privatelinkservices/read",
      "Microsoft.Network/privatelinkservices/write",
      "Microsoft.Network/virtualNetworks/subnets/write",

      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",

      "Microsoft.Network/loadBalancers/backendAddressPools/join/action"
    ]

    not_actions  = []
    data_actions = []
  }

  assignable_scopes = [local.resource_group_id]
}

resource "azurerm_user_assigned_identity" "ccm_csi" {
  name                = format("%s-ccm-csi-identity", local.vcluster_name)
  location            = local.location
  resource_group_name = local.resource_group_name
}

resource "azurerm_role_assignment" "ccm_csi" {
  scope              = local.resource_group_id
  role_definition_id = split("|", azurerm_role_definition.ccm_csi.id)[0]    #unbeliveable
  principal_id       = azurerm_user_assigned_identity.ccm_csi.principal_id
  principal_type     = "ServicePrincipal"

  depends_on = [azurerm_role_definition.ccm_csi, azurerm_user_assigned_identity.ccm_csi]
}
