package com.swastricare.health.domain.usecase.profile

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.repository.ProfileRepository
import javax.inject.Inject

/**
 * Use case: Upload avatar image.
 */
class UploadAvatarUseCase @Inject constructor(
    private val repository: ProfileRepository
) {
    /**
     * Upload avatar image and return the public URL.
     *
     * @param userId User ID
     * @param imageData Image data as byte array
     * @param fileName File name
     * @return ResultWrapper containing the public URL
     */
    suspend operator fun invoke(
        userId: String,
        imageData: ByteArray,
        fileName: String
    ): ResultWrapper<String> {
        // Business validation: check file extension
        val allowedExtensions = listOf("jpg", "jpeg", "png", "webp")
        val extension = fileName.substringAfterLast('.', "").lowercase()

        if (extension !in allowedExtensions) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "Only image files (jpg, jpeg, png, webp) are allowed for avatars."
                )
            )
        }

        // Business validation: check file size (max 5MB)
        val maxSizeBytes = 5 * 1024 * 1024
        if (imageData.size > maxSizeBytes) {
            return ResultWrapper.Error(
                com.swastricare.health.core.result.AppException.ValidationException.Custom(
                    "Avatar image must be less than 5MB."
                )
            )
        }

        return repository.uploadAvatar(userId, imageData, fileName)
    }
}
