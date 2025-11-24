# Using Envoy Distributed Ratelimiter as Kafka Middleware
<img alt="kafka-envoy-ratelimit-architecture" src="https://github.com/user-attachments/assets/0b5753f8-032a-45c3-b7d1-ebf5791528b2" />


## Rate Limiting Logic
The core rate limiting logic resides in the `shouldRateLimit` function within `RateLimitClient.kt`. It utilizes **gRPC** to communicate with the Envoy Rate Limit Service.

```kotlin
suspend fun shouldRateLimit(tenantId: String, userId: String): Boolean {
    val request = RateLimitRequest.newBuilder()
        .setDomain("kafka-consumer")
        .addDescriptors(
            io.envoyproxy.envoy.extensions.common.ratelimit.v3.RateLimitDescriptor.newBuilder()
                .addEntries(
                    io.envoyproxy.envoy.extensions.common.ratelimit.v3.RateLimitDescriptor.Entry.newBuilder()
                        .setKey("tenant_id")
                        .setValue(tenantId)
                        .build()
                )
                .addEntries(
                    io.envoyproxy.envoy.extensions.common.ratelimit.v3.RateLimitDescriptor.Entry.newBuilder()
                        .setKey("user_id")
                        .setValue(userId)
                        .build()
                )
                .build()
        )
        .setHitsAddend(1)
        .build()

    return try {
        // 20ms timeout
        val response = futureStub
            .withDeadlineAfter(20, TimeUnit.MILLISECONDS)
            .shouldRateLimit(request)
            .await() // Non-blocking await
        
        response.overallCode == RateLimitResponse.Code.OVER_LIMIT
    } catch (e: Exception) {
        logger.warn("Rate Limit Service error or timeout. Failing open.", e)
        false // Fail open
    }
}
```

### Usage
The `shouldRateLimit` function is used within the Kafka consumer flow to validate requests before processing.

```kotlin
private suspend fun processRequest(request: UserRequest) {
    val tenantId = request.getTenantId().toString()
    val userId = request.getUserId().toString()

    if (rateLimitClient.shouldRateLimit(tenantId, userId)) {
        logger.info("Rate limit exceeded for user $userId in tenant $tenantId. Routing to refused topic.")
        kafka.send(refusedTopic, request)
        return
    }
    logger.info("Request valid for user $userId in tenant $tenantId. Routing to valid topic.")
    kafka.send(validTopic, request)
}
```

- **Request Structure**: The request targets the `kafka-consumer` domain with descriptors for `tenant_id` and `user_id`.
- **Fail-Open Policy**: The client implements a **20ms timeout**. If the service is unreachable or times out, the system fails open (allows the request) to ensure consumer throughput is not blocked.

## Deployment & Configuration
- **Service**: The `ratelimit-service` is deployed using the `envoyproxy/ratelimit:v1.5.0` image.
- **Configuration**: The `ratelimit-config` ConfigMap defines the rules, currently set to **40 requests per second** for both `tenant_id` and `user_id`.

```yaml
domain: kafka-consumer
descriptors:
  - key: tenant_id
    rate_limit:
      unit: second
      requests_per_unit: 40
  - key: user_id
    rate_limit:
      unit: second
      requests_per_unit: 40
```

## Dependencies
Key libraries used for Envoy integration and gRPC communication include:

```kotlin
dependencies {
    implementation("io.envoyproxy.controlplane:api:0.1.35")
    implementation("net.devh:grpc-client-spring-boot-starter:2.15.0.RELEASE")
    implementation("io.grpc:grpc-stub:1.58.0")
    implementation("io.grpc:grpc-protobuf:1.58.0")
}
```
