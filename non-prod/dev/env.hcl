# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
  environment         = "dev"
  location_ops        = "West US 3"
  location_tenants    = "East US 2"
  location_tenants_dr = "West US 3"
}