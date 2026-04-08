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
    var imageUri: String? = null
        private set

    fun set(title: String, analysis: String, imageUri: String? = null) {
        documentTitle = title
        analysisResult = analysis
        this.imageUri = imageUri
    }

    data class PendingDocument(
        val title: String,
        val analysis: String,
        val imageUri: String?
    )

    fun consume(): PendingDocument? {
        val title = documentTitle ?: return null
        val analysis = analysisResult ?: return null
        val img = imageUri
        clear()
        return PendingDocument(title, analysis, img)
    }

    fun clear() {
        documentTitle = null
        analysisResult = null
        imageUri = null
    }
}
