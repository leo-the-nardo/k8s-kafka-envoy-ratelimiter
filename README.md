# Using Envoy Distributed Ratelimiter as Kafka Middleware
<img alt="kafka-envoy-ratelimit-architecture" src="https://github.com/user-attachments/assets/0b5753f8-032a-45c3-b7d1-ebf5791528b2" />


## Rate Limiting Logic
The core rate limiting logic resides in the `shouldRateLimit` function within `RateLimitClient.kt`. It utilizes **gRPC** to communicate with the Envoy Rate Limit Sidecar.

```kotlin
    suspend fun shouldRateLimit(key: String): RateLimitResult {
        return try {
            val requestBuilder = RateLimitRequest.newBuilder()
                .setDomain("spring")
                .setHitsAddend(1)

            if (incrementSilver) {
                val silverDescriptor = RateLimitDescriptor.newBuilder()
                    .addEntries(RateLimitDescriptor.Entry.newBuilder().setKey("silver_filter").setValue(key))
                    .build()
                requestBuilder.addDescriptors(silverDescriptor)
            }

            if (incrementGold) {
                val goldDescriptor = RateLimitDescriptor.newBuilder()
                    .addEntries(RateLimitDescriptor.Entry.newBuilder().setKey("gold_filter").setValue(key))
                    .build()
                requestBuilder.addDescriptors(goldDescriptor)
            }

            val request = requestBuilder.build()

            val response = kotlinx.coroutines.withTimeout(timeout) {
                stub.shouldRateLimit(request)
            }
            
            // Logic to determine if rate limited based on response statuses
            // ...
        } catch (e: Exception) {
            // Fail open logic
        }
    }
```

### Usage
The `shouldRateLimit` function is used to validate requests against multiple descriptors (`silver_filter`, `gold_filter`).

- **Request Structure**: The request targets the `spring` domain with descriptors for `silver_filter` and `gold_filter`.
- **Fail-Open Policy**: The client implements a timeout. If the service is unreachable or times out, the system fails open.

## Deployment & Configuration
- **Architecture**: The `ratelimit-service` is deployed as a **sidecar container** within the Kafka consumer pod.
- **Configuration**: The `ratelimit-config` ConfigMap defines the rules.

```yaml
domain: spring

descriptors:

  # 60 tps (ENFORCED)
  - key: gold_filter
    detailed_metric: true
    rate_limit:
      unit: second
      requests_per_unit: 60
    
  # Global per-user bucket: 40 tps (shared between App A and App B)
  # Here it is SHADOWED for App A, so it never blocks.
  - key: silver_filter
    detailed_metric: true
    rate_limit:
      unit: second
      requests_per_unit: 40
    shadow_mode: true
```

> [!NOTE]
> The rate limiting logic applies if **any** of the defined rules are met. For example, if a specific `user_id` exceeds 40 req/s, the request is blocked even if the `tenant_id` limit has not been reached, and vice-versa.

## Dependencies
Key libraries used for Envoy integration and gRPC communication include:

```kotlin
dependencies {
    implementation("io.grpc:grpc-kotlin-stub:1.4.1")
    implementation("io.grpc:grpc-netty:1.64.0")
    implementation("io.grpc:grpc-protobuf:1.64.0")
    implementation("com.google.protobuf:protobuf-kotlin:4.27.0")
}
```

## Performance
**Throughput**: 3000 TPS
**ECPUS**: ~7.5K

**Latency (p99)**:
- **Total**: 4~4.5ms
- **Kotlin**: 4~4.5ms
- **Envoy**: 2-3ms
- **Redis**: 0.8-1.3ms

**Latency (Avg)**:
- **Total**: 2.5ms
- **Kotlin**: 2.5ms
- **Envoy**: 1.4ms
- **Redis**: 0.9ms

**Resource Usage**:
- **Resource Definitions**:
    - Kotlin: 0.6 CPU * 3 Pods
    - Envoy: 1.5 CPU * 1 Pod (or 0.5 CPU * 3 Pods)

**Reliability**:
- **Max Excess**: 0.1% during 10min 3000 TPS test.
    - *Note*: 0.1% is (excess requests) / (excess requests + denied requests). It represents the percentage of requests that should have been denied but were not.
- **Bursts**: No excesses in bursts (0 to 3000 TPS very fast).

## Infrastructure & Configuration
The project uses **AWS AppConfig** for dynamic configuration management, allowing rate limit rules to be updated without redeploying the service.

### Envoy Deployment Resources (Kubernetes)
```yaml
          resources:
            requests:
              cpu: "1500m"
              memory: "0.5Gi"
            limits:
              cpu: "1500m"
              memory: "1Gi"
```

## Acknowledgments
- [envoyproxy/ratelimit](https://github.com/envoyproxy/ratelimit) - The rate limit service container used on this project.
