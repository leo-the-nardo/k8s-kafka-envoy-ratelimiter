package com.example.ratelimit



data class RateLimitResult(
    val isRateLimited: Boolean,
    val remaining: Long,
    val resetInMs: Long,
    val limit: Long,
    val isFailOpen: Boolean = false,
    val unit: String? = null
)
