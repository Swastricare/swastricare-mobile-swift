package com.swastricare.health.core.result

/**
 * Base sealed class for all app exceptions.
 * Provides centralized error handling.
 */
sealed class AppException(
    message: String? = null,
    cause: Throwable? = null
) : Exception(message, cause) {

    /**
     * Network-related errors (no internet, timeout, etc.)
     */
    sealed class NetworkException(message: String?, cause: Throwable? = null) :
        AppException(message, cause) {

        class NoInternet : NetworkException("No internet connection")
        class Timeout : NetworkException("Request timed out")
        class ServerUnreachable : NetworkException("Cannot reach server")
        class Unknown(cause: Throwable?) : NetworkException("Network error occurred", cause)
    }

    /**
     * API-related errors (4xx, 5xx responses)
     */
    sealed class ApiException(
        val code: Int,
        message: String?,
        cause: Throwable? = null
    ) : AppException(message, cause) {

        class BadRequest(message: String?) : ApiException(400, message)
        class Unauthorized : ApiException(401, "Unauthorized - please login again")
        class Forbidden : ApiException(403, "You don't have permission")
        class NotFound(message: String?) : ApiException(404, message)
        class Conflict(message: String?) : ApiException(409, message)
        class ServerError(message: String?) : ApiException(500, message)
        class ServiceUnavailable : ApiException(503, "Service temporarily unavailable")
        class Unknown(code: Int, message: String?) : ApiException(code, message)
    }

    /**
     * Database-related errors
     */
    sealed class DatabaseException(message: String?, cause: Throwable? = null) :
        AppException(message, cause) {

        class NotFound(entity: String) : DatabaseException("$entity not found in database")
        class InsertFailed(entity: String) : DatabaseException("Failed to insert $entity")
        class UpdateFailed(entity: String) : DatabaseException("Failed to update $entity")
        class DeleteFailed(entity: String) : DatabaseException("Failed to delete $entity")
        class Unknown(cause: Throwable?) : DatabaseException("Database error", cause)
    }

    /**
     * Validation errors (form inputs, business rules)
     */
    sealed class ValidationException(message: String) : AppException(message) {
        class InvalidEmail : ValidationException("Invalid email address")
        class InvalidPassword : ValidationException("Password must be at least 8 characters")
        class InvalidPhone : ValidationException("Invalid phone number")
        class Required(field: String) : ValidationException("$field is required")
        class Custom(message: String) : ValidationException(message)
    }

    /**
     * Unknown/unexpected errors
     */
    class UnknownException(message: String? = "An unexpected error occurred", cause: Throwable? = null) :
        AppException(message, cause)

    /**
     * User-friendly error message.
     */
    fun getUserMessage(): String = when (this) {
        is NetworkException.NoInternet -> "Please check your internet connection"
        is NetworkException.Timeout -> "Request took too long. Please try again"
        is NetworkException.ServerUnreachable -> "Cannot connect to server"
        is ApiException.Unauthorized -> "Your session has expired. Please login again"
        is ApiException.Forbidden -> "You don't have permission to perform this action"
        is ApiException.NotFound -> message ?: "Resource not found"
        is ApiException.ServerError -> "Server error. Please try again later"
        is ApiException.ServiceUnavailable -> "Service is temporarily unavailable"
        is ValidationException -> message ?: "Validation error"
        else -> message ?: "Something went wrong. Please try again"
    }
}
