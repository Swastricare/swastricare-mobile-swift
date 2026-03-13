package com.swastricare.health.core.base

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.logger.Logger
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Base ViewModel with error handling.
 */
abstract class BaseViewModel : ViewModel() {

    protected val tag: String = this::class.java.simpleName

    private val exceptionHandler = CoroutineExceptionHandler { _, throwable ->
        Logger.e(tag, "Unhandled exception in ViewModel", throwable)
        handleError(throwable)
    }

    /**
     * Launch coroutine with error handling.
     */
    protected fun launchSafe(block: suspend CoroutineScope.() -> Unit) {
        viewModelScope.launch(exceptionHandler) {
            block()
        }
    }

    /**
     * Override to handle errors in subclasses.
     */
    protected open fun handleError(throwable: Throwable) {
        // Default implementation - can be overridden
        Logger.e(tag, "Error in ViewModel", throwable)
    }
}
