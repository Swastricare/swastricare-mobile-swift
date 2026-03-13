package com.swastricare.health.core.result

/**
 * Generic sealed class for operation results used in domain layer.
 * Mirrors Kotlin's stdlib Result but with typed error handling.
 */
sealed class Result<out T> {
    /**
     * Success state with data.
     */
    data class Success<T>(val data: T) : Result<T>()

    /**
     * Error state with a throwable cause.
     */
    data class Error(val exception: Throwable) : Result<Nothing>()

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
        is Error -> null
    }

    /**
     * Returns data if Success, throws the exception if Error.
     */
    fun getOrThrow(): T = when (this) {
        is Success -> data
        is Error -> throw exception
    }
}

/**
 * Maps a Result<T> to a Result<R> by applying [transform] on Success data.
 */
inline fun <T, R> Result<T>.map(transform: (T) -> R): Result<R> = when (this) {
    is Result.Success -> Result.Success(transform(data))
    is Result.Error -> this
}

/**
 * Executes [block] if this is a Success, returning the original Result.
 */
inline fun <T> Result<T>.onSuccess(block: (T) -> Unit): Result<T> {
    if (this is Result.Success) block(data)
    return this
}

/**
 * Executes [block] if this is an Error, returning the original Result.
 */
inline fun <T> Result<T>.onError(block: (Throwable) -> Unit): Result<T> {
    if (this is Result.Error) block(exception)
    return this
}
