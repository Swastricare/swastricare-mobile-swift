package com.swastricare.health.ui.screens.ai

/**
 * Lightweight singleton that carries document context from the Vault screen
 * to the AI chat screen when the user taps "Continue in AI Chat".
 *
 * The AI screen consumes and clears the pending data on arrival.
 */
object PendingAIContext {
    var documentTitle: String? = null
        private set
    var analysisResult: String? = null
        private set
    var imageBase64: String? = null
        private set

    fun set(title: String, analysis: String, base64: String? = null) {
        documentTitle = title
        analysisResult = analysis
        imageBase64 = base64
    }

    fun consume(): Triple<String, String, String?>? {
        val title = documentTitle ?: return null
        val analysis = analysisResult ?: return null
        val img = imageBase64
        clear()
        return Triple(title, analysis, img)
    }

    fun clear() {
        documentTitle = null
        analysisResult = null
        imageBase64 = null
    }
}
