package com.example.ratelimit

import io.envoyproxy.envoy.extensions.common.ratelimit.v3.RateLimitDescriptor
import io.envoyproxy.envoy.service.ratelimit.v3.RateLimitRequest
import io.envoyproxy.envoy.service.ratelimit.v3.RateLimitResponse
import io.envoyproxy.envoy.service.ratelimit.v3.RateLimitServiceGrpcKt
import io.grpc.ManagedChannel
import io.grpc.netty.NettyChannelBuilder

import java.io.Closeable

import java.util.concurrent.TimeUnit

class RateLimitClient(
    host: String,
    port: Int,
    private val domain: String = "spring",
    private val timeout: Long = 20,
    private val failOpen: Boolean = false,
    private val incrementSilver: Boolean = true,
    private val incrementGold: Boolean = true
) : Closeable {

    private val channel: ManagedChannel = NettyChannelBuilder.forAddress(host, port)
        .usePlaintext()
        .defaultLoadBalancingPolicy("round_robin")
        .directExecutor() // Execute callbacks on Netty event loop to reduce context switching
        .maxInboundMessageSize(4 * 1024 * 1024) // refuses if bigger than 4MB
        .keepAliveTime(30, TimeUnit.SECONDS)
        .keepAliveTimeout(10, TimeUnit.SECONDS)
        .keepAliveWithoutCalls(true)
        .build()

    private val stub = RateLimitServiceGrpcKt.RateLimitServiceCoroutineStub(channel)

    suspend fun shouldRateLimit(key: String): RateLimitResult {
        return try {
            val requestBuilder = RateLimitRequest.newBuilder()
                .setDomain(domain)
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

            // Find the most restrictive status (OVER_LIMIT) or the first one
            val worstStatus = response.statusesList.find { it.code == io.envoyproxy.envoy.service.ratelimit.v3.RateLimitResponse.DescriptorStatus.Code.OVER_LIMIT }
                ?: response.statusesList.firstOrNull()

            val isRateLimited = response.overallCode == io.envoyproxy.envoy.service.ratelimit.v3.RateLimitResponse.Code.OVER_LIMIT

            RateLimitResult(
                isRateLimited = isRateLimited,
                remaining = worstStatus?.limitRemaining?.toLong() ?: -1,
                resetInMs = worstStatus?.durationUntilReset?.seconds?.times(1000) ?: 0, // Approximate conversion, ignoring nanos for simplicity
                limit = worstStatus?.currentLimit?.requestsPerUnit?.toLong() ?: -1,
                isFailOpen = false,
                unit = worstStatus?.currentLimit?.unit?.name
            )
        } catch (e: Exception) {
            if (failOpen) {
                RateLimitResult(
                    isRateLimited = false,
                    remaining = -1,
                    resetInMs = 0,
                    limit = -1,
                    isFailOpen = true,
                    unit = null
                )
            } else {
                throw e
            }
        }
    }

    override fun close() {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS)
    }
}
