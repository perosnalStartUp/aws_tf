config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Foundation inputs intentionally precede the domain resources that consume them.
# Remove this exception after the network and compute slices use every declaration.
rule "terraform_unused_declarations" {
  enabled = false
}
