package com.swasthicare.mobile.data.services

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import java.util.Locale

class SpeechService(private val context: Context) : RecognitionListener, TextToSpeech.OnInitListener {

    private val speechRecognizer: SpeechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
    private var textToSpeech: TextToSpeech? = null
    
    // Using a callback for recognition results
    private var onResult: ((String) -> Unit)? = null
    private var onError: ((String) -> Unit)? = null
    private var onPartialResult: ((String) -> Unit)? = null
    
    // State
    var isRecording = false
        private set
    var isSpeaking = false
        private set

    init {
        speechRecognizer.setRecognitionListener(this)
        textToSpeech = TextToSpeech(context, this)
    }

    // MARK: - Speech Recognition

    fun startRecording(
        onResult: (String) -> Unit, 
        onPartialResult: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        if (isRecording) {
            stopRecording()
            return
        }

        this.onResult = onResult
        this.onPartialResult = onPartialResult
        this.onError = onError

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }

        try {
            speechRecognizer.startListening(intent)
            isRecording = true
        } catch (e: Exception) {
            onError("Failed to start recording: ${e.message}")
            isRecording = false
        }
    }

    fun stopRecording() {
        if (isRecording) {
            speechRecognizer.stopListening()
            isRecording = false
        }
    }
    
    fun cleanup() {
        speechRecognizer.destroy()
        textToSpeech?.shutdown()
    }

    // RecognitionListener Implementation
    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {
        isRecording = false
    }

    override fun onError(error: Int) {
        isRecording = false
        val message = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
            SpeechRecognizer.ERROR_CLIENT -> "Client side error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
            SpeechRecognizer.ERROR_NETWORK -> "Network error"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "No match found"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
            SpeechRecognizer.ERROR_SERVER -> "Server error"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input"
            else -> "Unknown error"
        }
        onError?.invoke(message)
    }

    override fun onResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            onResult?.invoke(matches[0])
        }
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            onPartialResult?.invoke(matches[0])
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}

    // MARK: - Text to Speech

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            textToSpeech?.language = Locale.US
        }
    }

    fun speak(text: String) {
        textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "UtteranceId")
        isSpeaking = true
    }

    fun stopSpeaking() {
        textToSpeech?.stop()
        isSpeaking = false
    }
}
