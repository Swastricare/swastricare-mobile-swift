package com.swastricare.health.data.remote.dto.medication

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class FdaDrugResponse(
    val results: List<FdaDrugResult>? = null
)

@Serializable
data class FdaDrugResult(
    val openfda: FdaOpenFda? = null,
    @SerialName("indications_and_usage") val indicationsAndUsage: List<String>? = null,
    @SerialName("dosage_and_administration") val dosageAndAdministration: List<String>? = null,
    val warnings: List<String>? = null
)

@Serializable
data class FdaOpenFda(
    @SerialName("brand_name") val brandName: List<String>? = null,
    @SerialName("generic_name") val genericName: List<String>? = null
)
