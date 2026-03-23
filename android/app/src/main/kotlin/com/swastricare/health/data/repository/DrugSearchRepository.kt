package com.swastricare.health.data.repository

import com.swastricare.health.data.remote.api.OpenFdaApi
import javax.inject.Inject
import javax.inject.Singleton

data class DrugSearchResult(
    val brandName: String,
    val genericName: String?,
    val dosage: String?,
    val dosageUnit: String?,
    val displayName: String
)

data class DrugDetails(
    val description: String?,
    val warnings: String?,
    val dosageInfo: String?
)

@Singleton
class DrugSearchRepository @Inject constructor(
    private val openFdaApi: OpenFdaApi
) {
    private val dosageRegex = Regex("""(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|IU)""", RegexOption.IGNORE_CASE)

    suspend fun searchDrugs(query: String): Result<List<DrugSearchResult>> = runCatching {
        val response = openFdaApi.searchDrug(query)
        val results = response.results ?: return@runCatching emptyList()

        results.mapNotNull { result ->
            val brand = result.openfda?.brandName?.firstOrNull() ?: return@mapNotNull null
            val generic = result.openfda.genericName?.firstOrNull()
            val rawDosage = result.dosageAndAdministration?.firstOrNull()

            val match = rawDosage?.let { dosageRegex.find(it) }
            val dosageValue = match?.groupValues?.getOrNull(1)
            val dosageUnit = match?.groupValues?.getOrNull(2)

            val displayName = buildString {
                append(brand)
                if (dosageValue != null && dosageUnit != null) {
                    append(" $dosageValue$dosageUnit")
                }
            }

            DrugSearchResult(
                brandName = brand,
                genericName = generic,
                dosage = dosageValue,
                dosageUnit = dosageUnit,
                displayName = displayName
            )
        }.distinctBy { it.displayName }
    }

    suspend fun getDrugDetails(brandName: String): Result<DrugDetails> = runCatching {
        val response = openFdaApi.getDrugDetails(brandName)
        val result = response.results?.firstOrNull()

        DrugDetails(
            description = result?.indicationsAndUsage?.firstOrNull(),
            warnings = result?.warnings?.firstOrNull(),
            dosageInfo = result?.dosageAndAdministration?.firstOrNull()
        )
    }
}
