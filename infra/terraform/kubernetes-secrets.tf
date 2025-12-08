resource "kubernetes_secret" "ratelimit_redis_creds" {
  count = var.enable_elasticache_redis ? 1 : 0

  metadata {
    name      = "ratelimit-redis-creds"
    namespace = "envoy-gateway-system"
  }

  data = {
    # Authentication for Envoy Rate Limit Service (username:password format)
    # Used with REDIS_AUTH environment variable
    REDIS_PASSWORD = "${aws_elasticache_user.password_user[0].user_name}:${random_password.ratelimit_password[0].result}"
    # Redis endpoint URL (without credentials)
    REDIS_URL = "${aws_elasticache_serverless_cache.redis[0].endpoint[0].address}:${aws_elasticache_serverless_cache.redis[0].endpoint[0].port}"
  }

  type = "Opaque"

  depends_on = [
    aws_elasticache_serverless_cache.redis,
    random_password.ratelimit_password
  ]
}

resource "kubernetes_secret" "ratelimit_redis_creds_default" {
  count = var.enable_elasticache_redis ? 1 : 0

  metadata {
    name      = "ratelimit-redis-creds"
    namespace = "default"
  }

  data = {
    # Authentication for Envoy Rate Limit Service (username:password format)
    # Used with REDIS_AUTH environment variable
    REDIS_PASSWORD = "${aws_elasticache_user.password_user[0].user_name}:${random_password.ratelimit_password[0].result}"
    # Redis endpoint URL (without credentials)
    REDIS_URL = "${aws_elasticache_serverless_cache.redis[0].endpoint[0].address}:${aws_elasticache_serverless_cache.redis[0].endpoint[0].port}"
  }

  type = "Opaque"

  depends_on = [
    aws_elasticache_serverless_cache.redis,
    random_password.ratelimit_password
  ]
}

resource "kubernetes_secret" "ratelimit_redis_creds_envoy_ratelimit" {
  count = var.enable_elasticache_redis ? 1 : 0

  metadata {
    name      = "ratelimit-redis-creds"
    namespace = "envoy-ratelimit"
  }

  data = {
    # Authentication for Envoy Rate Limit Service (username:password format)
    # Used with REDIS_AUTH environment variable
    REDIS_PASSWORD = "${aws_elasticache_user.password_user[0].user_name}:${random_password.ratelimit_password[0].result}"
    # Redis endpoint URL (without credentials)
    REDIS_URL = "${aws_elasticache_serverless_cache.redis[0].endpoint[0].address}:${aws_elasticache_serverless_cache.redis[0].endpoint[0].port}"
  }

  type = "Opaque"

  depends_on = [
    aws_elasticache_serverless_cache.redis,
    random_password.ratelimit_password
  ]
}
