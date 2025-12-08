# Envoy Rate Limit Client (Kotlin)

This is a high-performance, non-blocking gRPC client for the Envoy Rate Limit Service, written in Kotlin using Coroutines and Netty.

## Prerequisites

- Java 17+
- Gradle (or use the provided wrapper if generated)

## Build

```bash
gradle build
```

## Run

To run the Spring Boot application:

```bash
export RATELIMIT_HOST=localhost
export RATELIMIT_PORT=8081
gradle bootRun
```

The application will start on port 8080 (default).

## API Endpoint

### Check Rate Limit

`GET /ratelimit`

**Parameters:**
- `domain`: (Optional) Rate limit domain (default: "spring")
- `user_id`: The user ID to check against `silver_filter` and `gold_filter`

**Example:**
```bash
curl "http://localhost:8080/ratelimit?user_id=123"
```

## Deployment

### Docker

Build the image (targeting ARM64 nodes):
```bash
docker build --platform linux/arm64 -t leothenardo/kt-backend:2.0.1 .
docker push leothenardo/kt-backend:2.0.1
```

### Kubernetes

Deploy to the cluster:
```bash
kubectl apply -f ../infra/kubernetes-manifests/kt-backend/
```

The service will be available at `kt-backend.envoy-ratelimit.svc.cluster.local:80`.

## Configuration

The client is optimized for low resource usage (0.5 CPU, 256MB RAM) and high throughput (10k TPS).
- **Spring Boot WebFlux**: Non-blocking HTTP server (Netty).
- **Netty gRPC**: Uses `directExecutor` to minimize context switching.
- **Coroutines**: Uses `grpc-kotlin-stub` for non-blocking I/O.
- **Memory**: Tuned for minimal allocation.

## Project Structure

- `src/main/proto`: Contains the Envoy Rate Limit Service proto definitions.
- `src/main/kotlin`: Contains the `RateLimitClient` and `Main` entry point.
