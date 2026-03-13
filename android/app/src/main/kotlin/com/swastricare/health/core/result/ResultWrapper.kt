package com.swastricare.health.core.result

/**
 * Generic wrapper for operation results.
 * Encapsulates success and error states.
 */
sealed class ResultWrapper<out T> {
    /**
     * Success state with data.
     */
    data class Success<T>(val data: T) : ResultWrapper<T>()

    /**
     * Error state with exception.
     */
    data class Error(val exception: AppException) : ResultWrapper<Nothing>()

    /**
     * Loading state (optional, for UI progress).
     */
    data object Loading : ResultWrapper<Nothing>()

    /**
     * Returns true if this is a Success state.
     */
    val isSuccess: Boolean
        get() = this is Success

    /**
     * Returns true if this is an Error state.
     */
    val isError: Boolean
        get() = this is Error

    /**
     * Returns data if Success, null otherwise.
     */
    fun getOrNull(): T? = when (this) {
        is Success -> data
        else -> null
    }

    /**
     * Returns data if Success, throws exception if Error.
     */
    fun getOrThrow(): T = when (this) {
        is Success -> data
        is Error -> throw exception
        is Loading -> throw IllegalStateException("Cannot get data from Loading state")
    }

    /**
     * Maps Success data to another type.
     */
    inline fun <R> map(transform: (T) -> R): ResultWrapper<R> = when (this) {
        is Success -> Success(transform(data))
        is Error -> this
        is Loading -> this
    }

    /**
     * Executes block on Success.
     */
    inline fun onSuccess(block: (T) -> Unit): ResultWrapper<T> {
        if (this is Success) block(data)
        return this
    }

    /**
     * Executes block on Error.
     */
    inline fun onError(block: (AppException) -> Unit): ResultWrapper<T> {
        if (this is Error) block(exception)
        return this
    }
}
