package com.example.ratelimit

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity

@RestController
class RateLimitController(private val rateLimitClient: RateLimitClient) {

    @GetMapping("/ratelimit")
    suspend fun checkRateLimit(
        @RequestParam("user_id") userId: String
    ): ResponseEntity<RateLimitResult> {
        
        val result = rateLimitClient.shouldRateLimit(userId)
        
        if (result.isRateLimited) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(result)
        }
        return ResponseEntity.ok(result)
    }
}
