package com.swastricare.health.domain.repository

import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.stress.StressEntry
import java.time.LocalDate

interface StressRepository {

    // ── Local storage ──

    suspend fun loadLocalEntries(): List<StressEntry>

    suspend fun loadEntriesForDate(date: LocalDate): List<StressEntry>

    suspend fun loadEntriesForDateRange(startDate: LocalDate, endDate: LocalDate): List<StressEntry>

    suspend fun addEntry(entry: StressEntry): ResultWrapper<Unit>

    suspend fun deleteEntry(id: String): ResultWrapper<Unit>

    suspend fun getLatestEntry(): StressEntry?

    suspend fun getTodayEntry(): StressEntry?

    // ── Cloud sync ──

    suspend fun fetchFromCloud(profileId: String): ResultWrapper<List<StressEntry>>

    suspend fun syncToCloud(entries: List<StressEntry>, profileId: String): ResultWrapper<Unit>
}
