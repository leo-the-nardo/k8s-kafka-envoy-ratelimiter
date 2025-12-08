package com.example.ratelimit

import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean

@SpringBootApplication
class RateLimitApplication {

    @Bean
    fun rateLimitClient(
        @Value("\${ratelimit.host:localhost}") host: String,
        @Value("\${ratelimit.port:8081}") port: Int,
        @Value("\${ratelimit.timeout:20}") timeout: Long,
        @Value("\${ratelimit.fail-open:false}") failOpen: Boolean,
        @Value("\${ratelimit.increment-silver:true}") incrementSilver: Boolean,
        @Value("\${ratelimit.increment-gold:true}") incrementGold: Boolean
    ): RateLimitClient {
        return RateLimitClient(
            host,
            port,
            timeout = timeout,
            failOpen = failOpen,
            incrementSilver = incrementSilver,
            incrementGold = incrementGold
        )
    }
}

fun main(args: Array<String>) {
    runApplication<RateLimitApplication>(*args)
}
