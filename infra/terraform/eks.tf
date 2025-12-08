# EKS Cluster using terraform-aws-modules/eks/aws
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.3.1"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # Gives Terraform identity admin access to cluster which will
  # allow deploying resources (Karpenter) into the cluster
  enable_cluster_creator_admin_permissions = true
  endpoint_private_access                  = true
  endpoint_public_access                   = true

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnets

  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        # Used to ensure Karpenter runs on nodes that it does not manage
        "karpenter.sh/controller" = "true"
      }
      taints = {
        # The pods that do not tolerate this taint should run on nodes
        # created by Karpenter
        karpenter = {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  node_security_group_tags = merge(var.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.cluster_name
  })

  access_entries = var.access_entries

  fargate_profiles = var.fargate_profiles

  # Additional security group rules for webhooks
  node_security_group_additional_rules = {
    datadog_webhook = {
      description                   = "Datadog Admission Controller webhook"
      protocol                      = "tcp"
      from_port                     = 8000
      to_port                       = 8000
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  tags = merge(var.tags, {
    Terraform   = "true"
    Environment = var.environment
  })
}

# =============================================================================
# Security Group Rules for Fargate <-> EC2 Node Communication
# 
# The EKS module doesn't support adding rules to the EKS-managed cluster SG
# (cluster_primary_security_group), so we add them outside the module.
# =============================================================================

# Allow Fargate pods to reach EC2 nodes (CoreDNS, webhooks, any services)
resource "aws_security_group_rule" "fargate_to_nodes" {
  description              = "Allow all traffic from Fargate pods (EKS-managed SG) to EC2 nodes"
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}

# Allow EC2 nodes to send responses back to Fargate pods
resource "aws_security_group_rule" "nodes_to_fargate" {
  description              = "Allow all traffic from EC2 nodes to Fargate pods (EKS-managed SG)"
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  security_group_id        = module.eks.cluster_primary_security_group_id
  source_security_group_id = module.eks.node_security_group_id
}

# Tag subnets for Karpenter discovery
resource "aws_ec2_tag" "karpenter_subnet_tags" {
  for_each    = toset(data.terraform_remote_state.network.outputs.private_subnets)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

locals {
  namespace = "karpenter"
}

################################################################################
# EC2 Spot Service-Linked Role
################################################################################
# Create the service-linked role for EC2 Spot Instances
# This is required for Karpenter to launch spot instances
# Note: Neither the Karpenter nor EKS modules create this - it's account-level
resource "aws_iam_service_linked_role" "spot" {
  count            = var.create_spot_service_linked_role ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
  description      = "Service-linked role for EC2 Spot Instances (required by Karpenter)"
}

################################################################################
# Controller & Node IAM roles, SQS Queue, Eventbridge Rules
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.3.2"

  cluster_name = module.eks.cluster_name
  # enable_v1_permissions = true
  namespace = local.namespace

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = var.cluster_name
  create_pod_identity_association = true

  tags = var.tags

}

################################################################################
# Helm charts
################################################################################
# Data source for ECR public authorization token (required for Karpenter Helm chart)
resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = local.namespace
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.2"
  wait             = false

  depends_on = [aws_ec2_tag.karpenter_subnet_tags]

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: karpenter.sh/controller
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
    EOT
  ]

}

################################################################################
# Metrics Server Patch
################################################################################
# Patch metrics-server deployment to add --kubelet-insecure-tls flag
# This fixes the "Metrics API not available" error
resource "null_resource" "metrics_server_patch" {
  depends_on = [aws_eks_addon.metrics_server]

  triggers = {
    cluster_endpoint = module.eks.cluster_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
      kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
        {
          "op": "add",
          "path": "/spec/template/spec/containers/0/args/-",
          "value": "--kubelet-insecure-tls"
        }
      ]'
      kubectl rollout restart deployment/metrics-server -n kube-system
    EOT
  }
}
