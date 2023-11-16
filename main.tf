###############################################
# OpenAI Service                              #
###############################################
### Create OpenAI Service ###
# 1.) Create an Azure Key Vault to store the OpenAI account details.
# 2.) Create an OpenAI service account.
# 3.) Create an OpenAI language model deployments. (GPT-3, GPT-4, etc.)
# 4.) Store the OpenAI account and model details in the key vault.
module "openai" {
  source  = "app.terraform.io/msccde/openai-service/azurerm"

  #common
  location = var.location
  tags     = var.tags

  #key vault (To store OpenAI Account and model details)
  keyvault_resource_group_name                 = var.keyvault_resource_group_name
  kv_config                                    = var.kv_config
  keyvault_firewall_default_action             = var.keyvault_firewall_default_action
  keyvault_firewall_bypass                     = var.keyvault_firewall_bypass
  keyvault_firewall_allowed_ips                = var.keyvault_firewall_allowed_ips
  keyvault_firewall_virtual_network_subnet_ids = var.keyvault_firewall_virtual_network_subnet_ids

  #Create OpenAI Service
  create_openai_service                     = var.create_openai_service
  openai_resource_group_name                = var.openai_resource_group_name
  openai_account_name                       = var.openai_account_name
  openai_custom_subdomain_name              = var.openai_custom_subdomain_name
  openai_sku_name                           = var.openai_sku_name
  openai_local_auth_enabled                 = var.openai_local_auth_enabled
  openai_outbound_network_access_restricted = var.openai_outbound_network_access_restricted
  openai_public_network_access_enabled      = var.openai_public_network_access_enabled
  openai_identity                           = var.openai_identity

  #Create Model Deployment
  create_model_deployment = var.create_model_deployment
  model_deployment        = var.model_deployment
}

### Create a container app ChatBot UI linked with OpenAI service hosted in Azure ###
# 5.) Create a container app log analytics workspace.
# 6.) Create a container app environment.
# 7.) Create a container app instance.
# 8.) grant the container app access a the key vault (optional).
module "privategpt_chatbot_container_apps" {
  source = "./modules/container_app"

  #common
  ca_resource_group_name = var.ca_resource_group_name
  location               = var.location
  tags                   = var.tags

  #log analytics workspace
  laws_name              = var.laws_name
  laws_sku               = var.laws_sku
  laws_retention_in_days = var.laws_retention_in_days

  #container app environment
  cae_name = var.cae_name

  #container app
  ca_name             = var.ca_name
  ca_revision_mode    = var.ca_revision_mode
  ca_identity         = var.ca_identity
  ca_ingress          = var.ca_ingress
  ca_container_config = var.ca_container_config
  ca_secrets          = var.ca_secrets

  #key vault access
  key_vault_access_permission = var.key_vault_access_permission #Set to `null` if no Key Vault access is needed on CA identity.
  key_vault_id                = var.key_vault_id                #Provide the key vault id if key_vault_access_permission is not null.

  depends_on = [module.openai]
}

### Front solution with an Azure front door (optional) ###
# 9.) Deploy Azure Front Door.
# 10.) Setup a custom domain with AFD managed certificate.
# 11.) Optionally create an Azure DNS Zone or use an existing one for the custom domain. (e.g PrivateGPT.mydomain.com)
# 12.) Create a CNAME and TXT record in the custom DNS zone.
# 13.) Setup and apply AFD WAF policy for the front door with allowed IPs custom rule. (Optional)
module "azure_frontdoor_cdn" {
  count  = var.create_front_door_cdn ? 1 : 0
  source = "./modules/cdn_frontdoor"

  #create_dns_zone
  create_dns_zone         = var.create_dns_zone
  dns_resource_group_name = var.dns_resource_group_name
  custom_domain_config    = var.custom_domain_config

  #deploy front door
  cdn_resource_group_name = var.cdn_resource_group_name
  cdn_profile_name        = var.cdn_profile_name
  cdn_sku_name            = var.cdn_sku_name
  cdn_endpoint            = var.cdn_endpoint
  cdn_origin_groups       = var.cdn_origin_groups
  cdn_gpt_origin          = local.cdn_gpt_origin
  cdn_route               = var.cdn_route

  #deploy firewall policy
  cdn_firewall_policy = var.cdn_firewall_policy
  cdn_security_policy = var.cdn_security_policy
  tags                = var.tags
  depends_on          = [module.privategpt_chatbot_container_apps]
}