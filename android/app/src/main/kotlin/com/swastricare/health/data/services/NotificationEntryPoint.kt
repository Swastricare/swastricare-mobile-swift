package com.swastricare.health.data.services

import android.content.SharedPreferences
import com.swastricare.health.data.repository.SupabaseMedicationRepository
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@EntryPoint
@InstallIn(SingletonComponent::class)
interface NotificationEntryPoint {
    fun sharedPreferences(): SharedPreferences
    fun medicationRepository(): SupabaseMedicationRepository
}
