package com.swastricare.health.core.base

import com.swastricare.health.core.result.ResultWrapper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Base class for use cases.
 * Provides common functionality for all use cases.
 */
abstract class BaseUseCase<in Params, out T> {

    /**
     * Execute the use case.
     */
    suspend operator fun invoke(params: Params): ResultWrapper<T> {
        return withContext(Dispatchers.IO) {
            execute(params)
        }
    }


    /**
     * Implement this method in subclasses.
     */
    protected abstract suspend fun execute(params: Params): ResultWrapper<T>
}

/**
 * Base class for use cases with no parameters.
 */
abstract class BaseUseCaseNoParams<out T> {

    /**
     * Execute the use case (no parameters).
     */
    suspend operator fun invoke(): ResultWrapper<T> {
        return withContext(Dispatchers.IO) {
            execute()
        }
    }

    /**
     * Implement this method in subclasses.
     */
    protected abstract suspend fun execute(): ResultWrapper<T>
}
