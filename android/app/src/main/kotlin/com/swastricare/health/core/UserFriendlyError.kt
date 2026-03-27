package com.swastricare.health.core

object UserFriendlyError {
    fun from(e: Exception): String {
        val msg = e.message?.lowercase() ?: return "Something went wrong. Please try again."
        return when {
            "network" in msg || "connection" in msg || "internet" in msg || "unable to resolve" in msg ->
                "No internet connection. Please check your network and try again."
            "timeout" in msg || "timed out" in msg ->
                "Request timed out. Please try again."
            "unauthorized" in msg || "not authenticated" in msg || "401" in msg ->
                "Your session has expired. Please sign in again."
            "permission" in msg || "denied" in msg || "403" in msg ->
                "You don't have permission for this action."
            "not found" in msg || "404" in msg ->
                "The requested data could not be found."
            "rate limit" in msg || "too many" in msg ->
                "Too many requests. Please wait a moment and try again."
            "server" in msg || "500" in msg || "503" in msg ->
                "Our servers are temporarily unavailable. Please try again later."
            else -> "Something went wrong. Please try again."
        }
    }
}
