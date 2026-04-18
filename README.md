# aws-genai-demo-platform

USING AWS Identity Provider

I use an OIDC-based federated IAM role. GitHub Actions obtains a JWT token, which AWS validates using the configured identity provider. Based on the trust policy, AWS issues temporary credentials via STS, which are then used by Terraform to provision infrastructure.
