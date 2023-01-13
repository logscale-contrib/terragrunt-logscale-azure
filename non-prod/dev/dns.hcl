

# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  domain_name = "dev.az.logsr.life"
  resource    = "/subscriptions/1b0f918f-3c13-43ad-b400-436773701221/resourceGroups/dns/providers/Microsoft.Network/dnszones/az.logsr.life"
}