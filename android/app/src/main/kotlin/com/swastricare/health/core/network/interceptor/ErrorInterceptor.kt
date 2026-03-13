package com.swastricare.health.core.network.interceptor

import com.swastricare.health.core.logger.Logger
import okhttp3.Interceptor

/**
 * Intercepts and parses API errors.
 */
class ErrorInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): okhttp3.Response {
        val response = chain.proceed(chain.request())

        // If response is not successful, parse error
        if (!response.isSuccessful) {
            val errorBody = response.body?.string()
            Logger.e("API_ERROR", "Code: ${response.code}, Body: $errorBody")
            // You can parse errorBody to extract error details
        }

        return response
    }
}
