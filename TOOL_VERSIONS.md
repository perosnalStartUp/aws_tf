# Terraform Tool Versions

These versions define the local/CI validation baseline for P1:

| Tool | Version |
| --- | --- |
| Terraform CLI | `1.13.3` |
| HashiCorp AWS Provider | `6.47.x` (`~> 6.47.0`) |
| TFLint | `0.64.0` |
| TFLint AWS Ruleset | `0.48.0` |
| Trivy | `0.72.0` |

Upgrade each tool through a reviewed change that records compatibility and validation results.
Do not use mutable `latest` tags in CI.
