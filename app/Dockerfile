# Stage 1: Build the application
# Stage 1: Build the application
FROM gradle:8.5-jdk21 AS builder

WORKDIR /app

# Copy gradle configuration first for caching
COPY build.gradle.kts settings.gradle.kts ./
# COPY gradle ./gradle # Wrapper not present, skipping

# Download dependencies (this layer will be cached unless build.gradle.kts changes)
RUN gradle dependencies --no-daemon

# Copy source code
COPY src ./src

# Build the application
# --no-daemon to save resources in CI/CD
# -x test to speed up build (optional, remove if tests are fast)
RUN gradle build --no-daemon -x test

# Stage 2: Run the application
FROM eclipse-temurin:21-jre

# Install curl to download Datadog agent
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Download Datadog Java Agent
RUN curl -L -o /dd-java-agent.jar https://dtdg.co/latest-java-tracer

WORKDIR /app

# Copy the built jar from the builder stage
# The jar name might vary, so we use a wildcard or specific name if known.
# Gradle application plugin usually creates a distribution, but bootJar creates a runner jar.
# Spring Boot plugin creates 'app-version.jar' or similar.
# We'll assume the output is in build/libs/ and ends with .jar but not -plain.jar
COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-javaagent:/dd-java-agent.jar", "-jar", "app.jar"]
