

# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  domain_name    = "dev.az.logsr.life"
  resource_group = "dns"
  resource       = "/subscriptions/1b0f918f-3c13-43ad-b400-436773701221/resourceGroups/dns"
  admin_email    = "ryan@dss-i.com"
}