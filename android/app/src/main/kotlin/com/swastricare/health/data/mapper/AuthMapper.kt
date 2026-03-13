package com.swastricare.health.data.mapper

import com.swastricare.health.data.model.AppUser
import com.swastricare.health.domain.model.User
import io.github.jan.supabase.gotrue.user.UserInfo
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/**
 * Mapper for converting between data layer and domain layer auth models.
 * Follows the Single Responsibility Principle: only handles mapping logic.
 */
object AuthMapper {

    /**
     * Map Supabase UserInfo to domain User model.
     * Extracts user metadata (avatar_url, picture, full_name, phone).
     */
    fun mapToDomain(userInfo: UserInfo): User {
        val metadata = userInfo.userMetadata

        val avatarUrl = metadata?.get("avatar_url")?.jsonPrimitive?.contentOrNull
            ?: metadata?.get("picture")?.jsonPrimitive?.contentOrNull

        val fullName = metadata?.get("full_name")?.jsonPrimitive?.contentOrNull
            ?: metadata?.get("name")?.jsonPrimitive?.contentOrNull

        val phone = userInfo.phone?.takeIf { it.isNotBlank() }
            ?: metadata?.get("phone")?.jsonPrimitive?.contentOrNull?.takeIf { it.isNotBlank() }

        return User(
            id = userInfo.id,
            email = userInfo.email ?: "",
            fullName = fullName,
            phone = phone,
            avatarUrl = avatarUrl,
            createdAt = userInfo.createdAt.toString()
        )
    }

    /**
     * Map domain User to legacy AppUser model.
     * Used for backward compatibility with existing code.
     * TODO: Remove once all code migrates to domain User model.
     */
    fun mapToAppUser(user: User): AppUser {
        return AppUser(
            id = user.id,
            email = user.email,
            fullName = user.fullName,
            phone = user.phone,
            avatarUrl = user.avatarUrl,
            createdAt = user.createdAt
        )
    }

    /**
     * Map legacy AppUser to domain User model.
     * Used for backward compatibility with existing code.
     * TODO: Remove once all code migrates to domain User model.
     */
    fun mapFromAppUser(appUser: AppUser): User {
        return User(
            id = appUser.id,
            email = appUser.email ?: "",
            fullName = appUser.fullName,
            phone = appUser.phone,
            avatarUrl = appUser.avatarUrl,
            createdAt = appUser.createdAt
        )
    }
}
