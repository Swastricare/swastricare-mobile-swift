package com.swastricare.health.domain.model

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * Unit tests for domain model validation and business logic.
 */
class ValidationTest {

    @Test
    fun `email validation accepts valid email addresses`() {
        // Valid email formats
        val validEmails = listOf(
            "user@example.com",
            "test.user@example.co.in",
            "user+tag@example.com",
            "user123@sub.example.com"
        )

        validEmails.forEach { email ->
            assertTrue("$email should be valid", isValidEmail(email))
        }
    }

    @Test
    fun `email validation rejects invalid email addresses`() {
        // Invalid email formats
        val invalidEmails = listOf(
            "invalid-email",
            "@example.com",
            "user@",
            "user space@example.com",
            ""
        )

        invalidEmails.forEach { email ->
            assertFalse("$email should be invalid", isValidEmail(email))
        }
    }

    @Test
    fun `password validation requires minimum strength`() {
        // Valid passwords (8+ chars, upper, lower, number, special)
        val validPasswords = listOf(
            "Pass123!",
            "MyP@ssw0rd",
            "Secure#Pass1"
        )

        validPasswords.forEach { password ->
            assertTrue("$password should be valid", isValidPassword(password))
        }
    }

    @Test
    fun `password validation rejects weak passwords`() {
        // Invalid passwords
        val invalidPasswords = listOf(
            "weak",           // Too short
            "password",       // No uppercase, number, special
            "PASSWORD",       // No lowercase, number, special
            "Password",       // No number, special
            "Password1"       // No special char
        )

        invalidPasswords.forEach { password ->
            assertFalse("$password should be invalid", isValidPassword(password))
        }
    }

    @Test
    fun `phone number sanitization removes formatting`() {
        val phoneNumber = "+91 98765 43210"
        val sanitized = sanitizePhoneNumber(phoneNumber)

        assertEquals("+919876543210", sanitized)
        assertFalse(sanitized.contains(" "))
        assertFalse(sanitized.contains("-"))
    }

    @Test
    fun `date range validation checks chronological order`() {
        val startDate = LocalDate.of(2024, 1, 1)
        val endDate = LocalDate.of(2024, 12, 31)

        assertTrue(isValidDateRange(startDate, endDate))
        assertFalse(isValidDateRange(endDate, startDate))
    }

    @Test
    fun `datetime range validation for workout sessions`() {
        val startTime = LocalDateTime.of(2024, 1, 1, 10, 0)
        val endTime = LocalDateTime.of(2024, 1, 1, 11, 0)

        assertTrue(isValidDateTimeRange(startTime, endTime))
        assertFalse(isValidDateTimeRange(endTime, startTime))
    }

    @Test
    fun `age calculation from date of birth`() {
        val birthDate = LocalDate.now().minusYears(30)
        val age = calculateAge(birthDate)

        assertEquals(30, age)
    }

    @Test
    fun `BMI calculation from height and weight`() {
        val heightCm = 175.0
        val weightKg = 70.0
        val bmi = calculateBMI(heightCm, weightKg)

        // BMI = 70 / (1.75 * 1.75) = 22.86
        assertEquals(22.86, bmi, 0.01)
    }

    @Test
    fun `workout pace calculation`() {
        val durationSeconds = 1800L // 30 minutes
        val distanceMeters = 5000.0  // 5 km
        val paceSecondsPerKm = calculatePace(durationSeconds, distanceMeters)

        // Pace = 1800 / 5 = 360 seconds per km = 6:00 min/km
        assertEquals(360L, paceSecondsPerKm)
    }

    @Test
    fun `calorie calculation from distance and weight`() {
        val distanceKm = 5.0
        val weightKg = 70.0
        val calories = calculateCalories(distanceKm, weightKg)

        // Approximate: 1 kcal per kg per km
        assertTrue(calories > 0)
        assertTrue(calories in 300..400) // Rough estimate
    }

    // Helper functions (these would typically be in a validation utility class)

    private fun isValidEmail(email: String): Boolean {
        val emailRegex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return email.matches(emailRegex.toRegex())
    }

    private fun isValidPassword(password: String): Boolean {
        if (password.length < 8) return false

        val hasUppercase = password.any { it.isUpperCase() }
        val hasLowercase = password.any { it.isLowerCase() }
        val hasDigit = password.any { it.isDigit() }
        val hasSpecial = password.any { !it.isLetterOrDigit() }

        return hasUppercase && hasLowercase && hasDigit && hasSpecial
    }

    private fun sanitizePhoneNumber(phone: String): String {
        return phone.replace(Regex("[\\s-()]"), "")
    }

    private fun isValidDateRange(start: LocalDate, end: LocalDate): Boolean {
        return !end.isBefore(start)
    }

    private fun isValidDateTimeRange(start: LocalDateTime, end: LocalDateTime): Boolean {
        return !end.isBefore(start)
    }

    private fun calculateAge(birthDate: LocalDate): Int {
        return LocalDate.now().year - birthDate.year
    }

    private fun calculateBMI(heightCm: Double, weightKg: Double): Double {
        val heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    private fun calculatePace(durationSeconds: Long, distanceMeters: Double): Long {
        if (distanceMeters <= 0) return 0
        val distanceKm = distanceMeters / 1000.0
        return (durationSeconds / distanceKm).toLong()
    }

    private fun calculateCalories(distanceKm: Double, weightKg: Double): Int {
        // Simple approximation: ~1 kcal per kg per km for running
        return (distanceKm * weightKg).toInt()
    }
}
