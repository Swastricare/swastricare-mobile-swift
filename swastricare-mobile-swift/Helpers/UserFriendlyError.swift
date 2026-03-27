import Foundation

enum UserFriendlyError {
    static func message(from error: Error) -> String {
        let desc = error.localizedDescription.lowercased()

        if desc.contains("network") || desc.contains("connection") || desc.contains("offline") || desc.contains("internet") {
            return "No internet connection. Please check your network and try again."
        }
        if desc.contains("timeout") || desc.contains("timed out") {
            return "Request timed out. Please try again."
        }
        if desc.contains("unauthorized") || desc.contains("not authenticated") || desc.contains("401") {
            return "Your session has expired. Please sign in again."
        }
        if desc.contains("permission") || desc.contains("denied") || desc.contains("403") {
            return "You don't have permission for this action."
        }
        if desc.contains("not found") || desc.contains("404") {
            return "The requested data could not be found."
        }
        if desc.contains("rate limit") || desc.contains("too many") {
            return "Too many requests. Please wait a moment and try again."
        }
        if desc.contains("server") || desc.contains("500") || desc.contains("503") {
            return "Our servers are temporarily unavailable. Please try again later."
        }
        if desc.contains("cancelled") || desc.contains("canceled") {
            return "The operation was cancelled."
        }
        if desc.contains("storage") || desc.contains("disk") || desc.contains("space") {
            return "Not enough storage space. Please free up some space and try again."
        }

        // Default friendly message
        return "Something went wrong. Please try again."
    }
}
