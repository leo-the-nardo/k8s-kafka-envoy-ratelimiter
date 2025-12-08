resource "aws_appconfig_application" "ratelimit" {
  name        = "envoy-ratelimit"
  description = "Configuration for Envoy Rate Limit Service"
}

resource "aws_appconfig_environment" "production" {
  name           = "production"
  application_id = aws_appconfig_application.ratelimit.id
}

resource "aws_appconfig_configuration_profile" "ratelimit_config" {
  application_id = aws_appconfig_application.ratelimit.id
  name           = "ratelimit-config"
  location_uri   = "hosted"
}

resource "aws_appconfig_hosted_configuration_version" "v1" {
  application_id           = aws_appconfig_application.ratelimit.id
  configuration_profile_id = aws_appconfig_configuration_profile.ratelimit_config.configuration_profile_id
  content_type             = "application/x-yaml"

  content = file("${path.module}/${var.ratelimit_config_file}")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_appconfig_deployment" "initial" {
  application_id           = aws_appconfig_application.ratelimit.id
  configuration_profile_id = aws_appconfig_configuration_profile.ratelimit_config.configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.v1.version_number
  deployment_strategy_id   = "AppConfig.AllAtOnce"
  environment_id           = aws_appconfig_environment.production.environment_id
}

# IAM Role for Service Account (IRSA)
module "ratelimit_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role = true
  role_name   = "RateLimitAppConfigRole"

  provider_url = module.eks.oidc_provider

  role_policy_arns = [
    aws_iam_policy.appconfig_access.arn
  ]

  oidc_fully_qualified_subjects = ["system:serviceaccount:envoy-ratelimit:envoy-ratelimit"]
}

resource "aws_iam_policy" "appconfig_access" {
  name        = "RateLimitAppConfigAccess"
  description = "Allow access to AppConfig for Rate Limit Service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appconfig:GetLatestConfiguration",
          "appconfig:StartConfigurationSession"
        ]
        Resource = "*"
      }
    ]
  })
}

output "ratelimit_irsa_role_arn" {
  description = "ARN of the IAM role for Rate Limit Service"
  value       = module.ratelimit_irsa_role.iam_role_arn
}
