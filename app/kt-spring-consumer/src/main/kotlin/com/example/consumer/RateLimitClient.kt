package com.example.consumer

import io.envoyproxy.envoy.service.ratelimit.v3.RateLimitServiceGrpc
import io.envoyproxy.envoy.service.ratelimit.v3.RateLimitRequest
import io.envoyproxy.envoy.service.ratelimit.v3.RateLimitResponse
import io.grpc.ManagedChannel
import io.grpc.ManagedChannelBuilder
import kotlinx.coroutines.guava.await
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.util.concurrent.TimeUnit
import javax.annotation.PreDestroy

@Service
class RateLimitClient(
    @Value("\${ratelimit.service.url}") private val rateLimitServiceUrl: String
) {

    private val logger = LoggerFactory.getLogger(RateLimitClient::class.java)
    private val channel: ManagedChannel
    private val futureStub: RateLimitServiceGrpc.RateLimitServiceFutureStub

    init {
        val parts = rateLimitServiceUrl.split(":")
        val host = parts[0]
        val port = parts.getOrElse(1) { "8081" }.toInt()
        
        channel = ManagedChannelBuilder.forAddress(host, port)
            .usePlaintext()
            .build()
        futureStub = RateLimitServiceGrpc.newFutureStub(channel)
    }

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

    @PreDestroy
    fun shutdown() {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS)
    }
}
