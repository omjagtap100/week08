#
# Azure Monitor Container Insights for the AKS cluster (7.3HD Section 4:
# "Reading the release in Azure Monitor"). The workspace is wired into the
# cluster via the oms_agent block on azurerm_kubernetes_cluster in
# kubernetes_serivce.tf.
#
resource "azurerm_log_analytics_workspace" "law" {
    name                = "${var.aks_cluster_name}-logs"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = "PerGB2018"
    retention_in_days   = 30

    tags = merge(
        var.tags,
        {
            Environment = var.environment
        }
    )
}
