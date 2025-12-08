# Development Environment Configuration

# AWS Configuration
aws_region = "us-east-1"

# EKS Configuration
cluster_name       = "dev-eks-cluster"
kubernetes_version = "1.34"

# Fargate Profiles Configuration
fargate_profiles = {
  main = {
    name = "main"
    selectors = [
      {
        namespace = "envoy-ratelimit"
        labels = {
          "compute-type" = "fargate"
        }
      }
    ]
  }
}

# MSK Configuration
msk_cluster_name  = "dev-msk-cluster"
kafka_version     = "3.7.x"
msk_instance_type = "kafka.t3.small"
msk_storage_size  = 20
enable_msk        = false


# ElastiCache Serverless Redis Configuration for Envoy Gateway Rate Limiting
enable_elasticache_redis                 = true
elasticache_redis_cluster_id             = "envoy-ratelimit-redis"
elasticache_redis_engine_version         = "7.1" # Serverless requires Redis 7.1+
elasticache_redis_port                   = 6379
elasticache_redis_serverless_max_storage = 10    # Maximum storage in GB
elasticache_redis_serverless_max_ecpu    = 10000 # Maximum ECPU per second
elasticache_redis_serverless_min_ecpu    = 1000  # Minimum ECPU per second

# Disable API Gateway and External Secrets
enable_api_gateway = false

# EKS Access Entries
# Note: admin_user entry removed because enable_cluster_creator_admin_permissions = true
# already grants admin access to the Terraform identity (producer-admin user)
# If you need to grant access to additional users, add them here
access_entries = {
  github_actions = {
    principal_arn = "arn:aws:iam::068064050187:role/github-actions-terraform-dev"
    type          = "STANDARD"
    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}

# Tags
tags = {
  Environment = "dev"
  Project     = "data-lab"
  Owner       = "data-team"
  CostCenter  = "engineering"
}
elasticache_redis_username               = "envoy-ratelimit-user"
elasticache_redis_password_access_string = "on ~* +@all"
elasticache_redis_default_access_string  = "off -@all"
# ratelimit_config_file                    = "ratelimit_shared_way_config_critical_app.yaml"
ratelimit_config_file = "ratelimit_simplest_config.yaml"

