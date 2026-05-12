package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.DietMapper.toDomain
import com.swastricare.health.data.mapper.DietMapper.toDto
import com.swastricare.health.data.mapper.DietMapper.toLocalDto
import com.swastricare.health.data.mapper.DietMapper.toRemoteDto
import com.swastricare.health.data.remote.dto.diet.AnalyzedFoodDto
import com.swastricare.health.data.remote.dto.diet.DietGoalsDto
import com.swastricare.health.data.remote.dto.diet.DietLogDto
import com.swastricare.health.data.remote.dto.diet.FoodItemDto
import com.swastricare.health.data.remote.dto.diet.LocalFoodEntryDto
import com.swastricare.health.data.services.AIService
import com.swastricare.health.domain.model.AnalyzedFood
import com.swastricare.health.domain.model.DietGoal
import com.swastricare.health.domain.model.FoodEntry
import com.swastricare.health.domain.model.FoodItem
import com.swastricare.health.domain.repository.DietRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of DietRepository.
 * Handles data operations for diet feature using Supabase and local storage.
 */
@Singleton
class DietRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences,
    private val aiService: AIService,
    private val json: Json
) : DietRepository {

    companion object {
        private const val KEY_FOOD_CACHE = "diet_food_cache"
        private const val KEY_DIET_LOGS = "diet_logs"
        private const val KEY_DIET_GOALS = "diet_goals"
        private const val KEY_FAVORITE_IDS = "diet_favorite_ids"
    }

    // ─────────────────────────────────────
    // MARK: - Food Items
    // ─────────────────────────────────────

    override suspend fun fetchFoodItems(limit: Int): ResultWrapper<List<FoodItem>> =
        withContext(Dispatchers.IO) {
            try {
                val items = supabaseClient.from("food_items")
                    .select()
                    .decodeList<FoodItemDto>()

                val domainItems = items.map { it.toDomain() }

                // Cache the results
                cacheFoodItems(domainItems)

                ResultWrapper.Success(domainItems)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.NetworkException.Unknown(e)
                )
            }
        }

    override suspend fun getCachedFoodItems(): ResultWrapper<List<FoodItem>> =
        withContext(Dispatchers.IO) {
            try {
                val raw = prefs.getString(KEY_FOOD_CACHE, null)
                    ?: return@withContext ResultWrapper.Success(emptyList())

                val items = json.decodeFromString<List<FoodItemDto>>(raw)
                ResultWrapper.Success(items.map { it.toDomain() })
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.Unknown(e)
                )
            }
        }

    override suspend fun searchFoodItems(query: String): ResultWrapper<List<FoodItem>> =
        withContext(Dispatchers.IO) {
            try {
                val cachedResult = getCachedFoodItems()
                if (cachedResult !is ResultWrapper.Success) {
                    return@withContext cachedResult
                }

                val lower = query.lowercase()
                val filtered = cachedResult.data.filter { item ->
                    item.name.lowercase().contains(lower) ||
                    item.brand?.lowercase()?.contains(lower) == true
                }

                ResultWrapper.Success(filtered)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.UnknownException(cause = e)
                )
            }
        }

    private fun cacheFoodItems(items: List<FoodItem>) {
        try {
            val dtos = items.map { item ->
                FoodItemDto(
                    id = item.id,
                    name = item.name,
                    brand = item.brand,
                    servingSize = item.servingSize,
                    servingUnit = when (item.servingUnit) {
                        com.swastricare.health.domain.model.ServingUnit.G -> "g"
                        com.swastricare.health.domain.model.ServingUnit.ML -> "ml"
                        com.swastricare.health.domain.model.ServingUnit.PIECE -> "piece"
                        com.swastricare.health.domain.model.ServingUnit.CUP -> "cup"
                        com.swastricare.health.domain.model.ServingUnit.TBSP -> "tbsp"
                        com.swastricare.health.domain.model.ServingUnit.TSP -> "tsp"
                        com.swastricare.health.domain.model.ServingUnit.OZ -> "oz"
                        com.swastricare.health.domain.model.ServingUnit.BOWL -> "bowl"
                        com.swastricare.health.domain.model.ServingUnit.PLATE -> "plate"
                    },
                    calories = item.nutritionInfo.calories,
                    proteinG = item.nutritionInfo.proteinG,
                    carbsG = item.nutritionInfo.carbsG,
                    fatG = item.nutritionInfo.fatG,
                    fiberG = item.nutritionInfo.fiberG,
                    isVegetarian = item.isVegetarian,
                    isVegan = item.isVegan,
                    category = when (item.category) {
                        com.swastricare.health.domain.model.FoodCategory.FRUITS -> "fruits"
                        com.swastricare.health.domain.model.FoodCategory.VEGETABLES -> "vegetables"
                        com.swastricare.health.domain.model.FoodCategory.GRAINS -> "grains"
                        com.swastricare.health.domain.model.FoodCategory.PROTEIN -> "protein"
                        com.swastricare.health.domain.model.FoodCategory.DAIRY -> "dairy"
                        com.swastricare.health.domain.model.FoodCategory.BEVERAGES -> "beverages"
                        com.swastricare.health.domain.model.FoodCategory.SNACKS -> "snacks"
                        com.swastricare.health.domain.model.FoodCategory.SWEETS -> "sweets"
                        com.swastricare.health.domain.model.FoodCategory.OTHER -> "other"
                    }
                )
            }
            prefs.edit().putString(KEY_FOOD_CACHE, json.encodeToString(dtos)).apply()
        } catch (_: Exception) {
            // Silent fail for caching
        }
    }

    // ─────────────────────────────────────
    // MARK: - Food Entries
    // ─────────────────────────────────────

    override suspend fun getFoodEntriesForDate(date: LocalDate): ResultWrapper<List<FoodEntry>> =
        withContext(Dispatchers.IO) {
            try {
                val allEntries = loadLocalEntries()
                val dateStr = date.toString()
                val filtered = allEntries.filter {
                    it.loggedAt.toLocalDate() == date
                }

                ResultWrapper.Success(filtered)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.Unknown(e)
                )
            }
        }

    override suspend fun getAllFoodEntries(): ResultWrapper<List<FoodEntry>> =
        withContext(Dispatchers.IO) {
            try {
                val entries = loadLocalEntries()
                ResultWrapper.Success(entries)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.Unknown(e)
                )
            }
        }

    override suspend fun addFoodEntry(entry: FoodEntry): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                // Add to local storage
                val current = loadLocalEntries().toMutableList()
                current.add(entry)
                saveLocalEntries(current)

                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.InsertFailed("food entry")
                )
            }
        }

    override suspend fun deleteFoodEntry(entryId: String): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                // Delete from local storage
                val current = loadLocalEntries().filter { it.id != entryId }
                saveLocalEntries(current)

                // Delete from cloud
                try {
                    supabaseClient.from("diet_logs").delete {
                        filter { eq("id", entryId) }
                    }
                } catch (_: Exception) {
                    // Silent fail for cloud deletion - entry already removed locally
                }

                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.DeleteFailed("food entry")
                )
            }
        }

    override suspend fun syncEntries(): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val entries = loadLocalEntries()
                val unsynced = entries.filter { !it.synced }

                if (unsynced.isEmpty()) {
                    return@withContext ResultWrapper.Success(Unit)
                }

                // Get health profile ID
                val profileId = resolveHealthProfileId()
                    ?: return@withContext ResultWrapper.Error(
                        AppException.ApiException.Unauthorized()
                    )

                // Upload to Supabase
                val dtos = unsynced.map { it.toRemoteDto(profileId) }
                supabaseClient.from("diet_logs").upsert(dtos)

                // Mark as synced locally
                val updated = entries.map { entry ->
                    if (unsynced.any { it.id == entry.id }) {
                        entry.copy(synced = true)
                    } else {
                        entry
                    }
                }
                saveLocalEntries(updated)

                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.NetworkException.Unknown(e)
                )
            }
        }

    private fun loadLocalEntries(): List<FoodEntry> {
        return try {
            val raw = prefs.getString(KEY_DIET_LOGS, null) ?: return emptyList()
            val dtos = json.decodeFromString<List<LocalFoodEntryDto>>(raw)
            dtos.map { it.toDomain() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveLocalEntries(entries: List<FoodEntry>) {
        try {
            val dtos = entries.map { it.toLocalDto() }
            prefs.edit().putString(KEY_DIET_LOGS, json.encodeToString(dtos)).apply()
        } catch (_: Exception) {
            // Silent fail
        }
    }

    // ─────────────────────────────────────
    // MARK: - Goals
    // ─────────────────────────────────────

    override suspend fun getDietGoals(): ResultWrapper<DietGoal> =
        withContext(Dispatchers.IO) {
            try {
                val raw = prefs.getString(KEY_DIET_GOALS, null)
                val goals = if (raw != null) {
                    json.decodeFromString<DietGoalsDto>(raw).toDomain()
                } else {
                    DietGoal.Default
                }
                ResultWrapper.Success(goals)
            } catch (e: Exception) {
                ResultWrapper.Success(DietGoal.Default)
            }
        }

    override suspend fun updateDietGoals(goals: DietGoal): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val dto = goals.toDto()
                prefs.edit().putString(KEY_DIET_GOALS, json.encodeToString(dto)).apply()
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.UpdateFailed("diet goals")
                )
            }
        }

    // ─────────────────────────────────────
    // MARK: - Favorites
    // ─────────────────────────────────────

    override suspend fun getFavoriteFoodIds(): ResultWrapper<Set<String>> =
        withContext(Dispatchers.IO) {
            try {
                val ids = prefs.getStringSet(KEY_FAVORITE_IDS, emptySet()) ?: emptySet()
                ResultWrapper.Success(ids)
            } catch (e: Exception) {
                ResultWrapper.Success(emptySet())
            }
        }

    override suspend fun toggleFavorite(foodItemId: String): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val current = prefs.getStringSet(KEY_FAVORITE_IDS, emptySet())?.toMutableSet()
                    ?: mutableSetOf()

                if (current.contains(foodItemId)) {
                    current.remove(foodItemId)
                } else {
                    current.add(foodItemId)
                }

                prefs.edit().putStringSet(KEY_FAVORITE_IDS, current).apply()
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.DatabaseException.UpdateFailed("favorites")
                )
            }
        }

    override suspend fun getFavoriteFoods(): ResultWrapper<List<FoodItem>> =
        withContext(Dispatchers.IO) {
            try {
                val idsResult = getFavoriteFoodIds()
                if (idsResult !is ResultWrapper.Success) {
                    return@withContext idsResult as ResultWrapper.Error
                }

                val cachedResult = getCachedFoodItems()
                if (cachedResult !is ResultWrapper.Success) {
                    return@withContext cachedResult as ResultWrapper.Error
                }

                val ids = idsResult.data
                val favorites = cachedResult.data.filter { ids.contains(it.id) }

                ResultWrapper.Success(favorites)
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.UnknownException(cause = e)
                )
            }
        }

    // ─────────────────────────────────────
    // MARK: - AI Food Analysis
    // ─────────────────────────────────────

    override suspend fun analyzeFoodImage(imageBase64: String): ResultWrapper<AnalyzedFood> =
        withContext(Dispatchers.IO) {
            try {
                val result = aiService.analyzeFoodImage(imageBase64)
                val dto = AnalyzedFoodDto(
                    name = result.name,
                    calories = result.calories,
                    proteinG = result.proteinG,
                    carbsG = result.carbsG,
                    fatG = result.fatG,
                    fiberG = result.fiberG,
                    servingSize = result.servingSize,
                    servingUnit = result.servingUnit,
                    category = result.category
                )
                ResultWrapper.Success(dto.toDomain())
            } catch (e: Exception) {
                ResultWrapper.Error(
                    AppException.ApiException.Unknown(500, "AI analysis failed: ${e.message}")
                )
            }
        }

    // ─────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────

    @kotlinx.serialization.Serializable
    private data class HealthProfileIdRow(val id: String)

    @Serializable
    private data class CaloriesRow(val calories: Double)

    override suspend fun getDayCalories(
        profileId: String,
        date: LocalDate
    ): ResultWrapper<Int> = withContext(Dispatchers.IO) {
        try {
            val start = date.atStartOfDay().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            val end = date.plusDays(1)
                .atStartOfDay().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

            val rows = supabaseClient.from("diet_logs").select(
                columns = io.github.jan.supabase.postgrest.query.Columns.raw("calories")
            ) {
                filter {
                    eq("health_profile_id", profileId)
                    gte("logged_at", start)
                    lt("logged_at", end)
                }
            }.decodeList<CaloriesRow>()

            val total = rows.sumOf { it.calories }.toInt()
            ResultWrapper.Success(total)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.NetworkException.Unknown(e))
        }
    }

    private suspend fun resolveHealthProfileId(): String? {
        return try {
            val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return null
            supabaseClient.from("health_profiles")
                .select { filter { eq("user_id", userId) } }
                .decodeSingleOrNull<HealthProfileIdRow>()?.id
        } catch (_: Exception) {
            null
        }
    }
}
