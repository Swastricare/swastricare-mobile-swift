package com.swastricare.health.data.remote.api

import com.swastricare.health.data.remote.dto.medication.FdaDrugResponse
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OpenFdaApi @Inject constructor(
    private val httpClient: HttpClient
) {
    companion object {
        private const val BASE_URL = "https://api.fda.gov/drug/label.json"
    }

    suspend fun searchDrug(query: String, limit: Int = 5): FdaDrugResponse {
        return httpClient.get(BASE_URL) {
            parameter("search", "openfda.brand_name:$query*")
            parameter("limit", limit)
        }.body()
    }

    suspend fun getDrugDetails(brandName: String): FdaDrugResponse {
        return httpClient.get(BASE_URL) {
            parameter("search", "openfda.brand_name:\"$brandName\"")
            parameter("limit", 1)
        }.body()
    }
}
