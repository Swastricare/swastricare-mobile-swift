package com.swastricare.health.core.extensions

import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart

/**
 * Flow extensions for ResultWrapper.
 * Provides convenient operators for handling flows with Result types.
 */

/**
 * Wraps Flow emissions in ResultWrapper.Success and errors in ResultWrapper.Error.
 */
fun <T> Flow<T>.asResultWrapper(): Flow<ResultWrapper<T>> {
    return this
        .map<T, ResultWrapper<T>> { ResultWrapper.Success(it) }
        .onStart { emit(ResultWrapper.Loading) }
        .catch { exception ->
            val appException = when (exception) {
                is AppException -> exception
                else -> AppException.UnknownException(cause = exception)
            }
            emit(ResultWrapper.Error(appException))
        }
}

/**
 * Maps the success value of a ResultWrapper flow.
 */
fun <T, R> Flow<ResultWrapper<T>>.mapSuccess(transform: (T) -> R): Flow<ResultWrapper<R>> {
    return map { result ->
        when (result) {
            is ResultWrapper.Success -> ResultWrapper.Success(transform(result.data))
            is ResultWrapper.Error -> result
            is ResultWrapper.Loading -> result
        }
    }
}

/**
 * Filters only successful results from a flow.
 */
fun <T> Flow<ResultWrapper<T>>.onlySuccess(): Flow<T> {
    return map { result ->
        when (result) {
            is ResultWrapper.Success -> result.data
            is ResultWrapper.Error -> throw result.exception
            is ResultWrapper.Loading -> throw IllegalStateException("Cannot get data from Loading state")
        }
    }
}

/**
 * Executes an action when the flow emits a success result.
 */
fun <T> Flow<ResultWrapper<T>>.onSuccess(action: suspend (T) -> Unit): Flow<ResultWrapper<T>> {
    return map { result ->
        if (result is ResultWrapper.Success) {
            action(result.data)
        }
        result
    }
}

/**
 * Executes an action when the flow emits an error result.
 */
fun <T> Flow<ResultWrapper<T>>.onError(action: suspend (AppException) -> Unit): Flow<ResultWrapper<T>> {
    return map { result ->
        if (result is ResultWrapper.Error) {
            action(result.exception)
        }
        result
    }
}

/**
 * Executes an action when the flow emits a loading result.
 */
fun <T> Flow<ResultWrapper<T>>.onLoading(action: suspend () -> Unit): Flow<ResultWrapper<T>> {
    return map { result ->
        if (result is ResultWrapper.Loading) {
            action()
        }
        result
    }
}
