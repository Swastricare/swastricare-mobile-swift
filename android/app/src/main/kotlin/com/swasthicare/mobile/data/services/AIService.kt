package com.swasthicare.mobile.data.services

import com.swasthicare.mobile.data.models.*
import kotlinx.coroutines.delay

class AIService {
    
    suspend fun sendChatMessage(message: String, context: List<ChatMessage>): String {
        delay(1500)
        return "I am Swastri AI (Demo Mode). I received your message: \"$message\". Since the backend is disconnected, I cannot provide a real AI response, but I'm here to help you simulate the experience!"
    }

    suspend fun analyzeHealth(metrics: HealthMetrics): HealthAnalysisResponse {
        delay(2000)
        return HealthAnalysisResponse(
            assessment = "Your health metrics look good overall based on the demo data.",
            insights = "You are maintaining a consistent activity level. Your heart rate is within normal range.",
            recommendations = listOf(
                "Continue maintaining your sleep schedule.",
                "Consider increasing water intake.",
                "Try to get 10 more minutes of active exercise daily."
            )
        )
    }
}
