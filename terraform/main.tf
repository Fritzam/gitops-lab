resource "azurerm_resource_group" "rg" {
  name     = "aks_resource_group_gitops"
  location = "polandcentral"
}

resource "azurerm_container_registry" "acr" {
  name                = "acrgitopsfritzam"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                      = "maincluster"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  sku_tier                  = "Free"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  dns_prefix                = "gitopslab"

  default_node_pool {
    name       = "workerpool"
    node_count = 1
    vm_size    = "Standard_B2ls_v2"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "arc_image_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}