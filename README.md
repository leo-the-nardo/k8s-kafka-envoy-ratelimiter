# Using Envoy Distributed Ratelimiter as Kafka Middleware
This is the Kafka-Middleware version of [k8s-gateway-api-envoy-ratelimit](https://github.com/leo-the-nardo/k8s-gateway-api-envoy-ratelimit)
<img alt="kafka-ratelimiter-sidecar" src="https://github.com/user-attachments/assets/f2c47d77-ae3d-4e0e-aa54-601382a9cc5c" />

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
- **Architecture**: The `ratelimit-service` is deployed as a **standalone Deployment** within the Kubernetes cluster. The Kafka consumer communicates with it via **gRPC** using the Kubernetes Service DNS (e.g., `envoy-ratelimit.envoy-ratelimit.svc.cluster.local`).
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
              cpu: "500m"
              memory: "0.5Gi"
            limits:
              cpu: "1500m"
              memory: "1Gi"
```

<img alt="image" src="https://github.com/user-attachments/assets/5ca9f701-f7fe-4d65-972c-7bdabfb4f705" />


## Acknowledgments
- [envoyproxy/ratelimit](https://github.com/envoyproxy/ratelimit) - The rate limit service container used on this project.
