variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"
}

variable "msk_cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
  default     = "datapoc-msk-cluster"
}

variable "kafka_version" {
  description = "Kafka version for MSK cluster"
  type        = string
  default     = "3.7.x"
}

variable "msk_instance_type" {
  description = "Instance type for MSK brokers"
  type        = string
  default     = "kafka.t3.small"
}

variable "msk_storage_size" {
  description = "Storage size in GB for MSK brokers"
  type        = number
  default     = 50
}


variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "data-lab"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "access_entries" {
  description = "EKS access entries configuration"
  type = map(object({
    # Access entry
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})

    # Access policy association
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

variable "fargate_profiles" {
  description = "Fargate profiles configuration"
  type = map(object({
    name       = optional(string)
    subnet_ids = optional(list(string))
    selectors = list(object({
      labels    = optional(map(string))
      namespace = string
    }))
    tags = optional(map(string))
  }))
  default = {}
}

variable "enable_msk" {
  description = "Enable MSK cluster creation"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "producer-account"
  }
}

variable "enable_api_gateway" {
  description = "Enable API Gateway v2 creation"
  type        = bool
  default     = true
}

variable "nlb_service_name" {
  description = "Name of the NLB service created by Kubernetes"
  type        = string
  default     = "nlb-svc-simulacaoconvivencia"
}

variable "nlb_dns_name" {
  description = "DNS name of the NLB service (set this after NLB is created)"
  type        = string
  default     = ""
}

variable "enable_elasticache_redis" {
  description = "Enable ElastiCache Redis for Envoy Gateway rate limiting"
  type        = bool
  default     = true
}

variable "elasticache_redis_cluster_id" {
  description = "ElastiCache Redis cluster identifier"
  type        = string
  default     = "envoy-ratelimit-redis"
}



variable "ratelimit_auth_method" {
  description = "Authentication method for Envoy Rate Limit Service (irsa or pod_identity)"
  type        = string
  default     = "irsa"
  validation {
    condition     = contains(["irsa", "pod_identity"], var.ratelimit_auth_method)
    error_message = "ratelimit_auth_method must be either 'irsa' or 'pod_identity'."
  }
}



variable "elasticache_redis_serverless_max_storage" {
  description = "Maximum storage in GB for ElastiCache Serverless"
  type        = number
  default     = 10
}

variable "elasticache_redis_serverless_max_ecpu" {
  description = "Maximum ECPU per second for ElastiCache Serverless"
  type        = number
  default     = 30000
}

variable "elasticache_redis_serverless_min_ecpu" {
  description = "Minimum ECPU per second for ElastiCache Serverless"
  type        = number
  default     = 10000
}

variable "elasticache_redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "elasticache_redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "create_spot_service_linked_role" {
  description = "Whether to create the EC2 Spot service-linked role. Set to false if the role already exists in your AWS account (check with: aws iam get-role --role-name AWSServiceRoleForEC2Spot)"
  type        = bool
  default     = true
}

variable "elasticache_redis_username" {
  description = "Username for password-protected ElastiCache Redis user"
  type        = string
  default     = "envoy-ratelimit-password"
}

variable "elasticache_redis_default_access_string" {
  description = "Access string for the default (disabled) ElastiCache Redis user"
  type        = string
  default     = "off -@all"
}

variable "elasticache_redis_password_access_string" {
  description = "Access string for the password-protected ElastiCache Redis user"
  type        = string
  default     = "on ~* +@all"
}

variable "ratelimit_config_file" {
  description = "Path to the Envoy Rate Limit configuration YAML file"
  type        = string
  default     = "ratelimit_simplest_config.yaml"
}

# VPC Flow Logs Variables
variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for the VPC from infra-network"
  type        = bool
  default     = true
}

variable "vpc_flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch"
  type        = number
  default     = 14
}

variable "vpc_flow_logs_traffic_type" {
  description = "Type of traffic to capture (ACCEPT, REJECT, or ALL)"
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.vpc_flow_logs_traffic_type)
    error_message = "vpc_flow_logs_traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "vpc_flow_logs_aggregation_interval" {
  description = "Maximum interval of time (in seconds) during which a flow of packets is captured. Valid values: 60 or 600."
  type        = number
  default     = 600
  validation {
    condition     = contains([60, 600], var.vpc_flow_logs_aggregation_interval)
    error_message = "vpc_flow_logs_aggregation_interval must be 60 or 600."
  }
}
