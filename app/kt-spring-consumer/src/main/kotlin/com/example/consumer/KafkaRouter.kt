package com.example.consumer

import com.example.consumer.avro.UserRequest
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import org.slf4j.LoggerFactory
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Service

@Service
class KafkaRouter(
    private val rateLimitClient: RateLimitClient,
    private val kafkaTemplate: KafkaTemplate<String, UserRequest>
) {

    private val logger = LoggerFactory.getLogger(KafkaRouter::class.java)
    private val validTopic = "valid-topic"
    private val refusedTopic = "refused-topic"

    @KafkaListener(topics = ["input-topic"], groupId = "kafka-router-group")
    fun listen(requests: List<UserRequest>) = runBlocking {
        logger.info("Received batch of ${requests.size} requests")
        
        requests.map { request ->
            async {
                processRequest(request)
            }
        }.awaitAll()
    }

    private suspend fun processRequest(request: UserRequest) {
        val tenantId = request.getTenantId().toString()
        val userId = request.getUserId().toString()

        if (rateLimitClient.shouldRateLimit(tenantId, userId)) {
            logger.info("Rate limit exceeded for user $userId in tenant $tenantId. Routing to refused topic.")
            kafkaTemplate.send(refusedTopic, request)
        } else {
            logger.info("Request valid for user $userId in tenant $tenantId. Routing to valid topic.")
            kafkaTemplate.send(validTopic, request)
        }
    }
}
