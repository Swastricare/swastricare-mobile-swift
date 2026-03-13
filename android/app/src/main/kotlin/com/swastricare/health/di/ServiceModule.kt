package com.swastricare.health.di

import com.swastricare.health.data.services.AIService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for service dependencies.
 * Provides singleton instances of service classes.
 */
@Module
@InstallIn(SingletonComponent::class)
object ServiceModule {

    /**
     * Provides AIService singleton.
     * Used for AI-powered features like chat, food analysis, health insights.
     */
    @Provides
    @Singleton
    fun provideAIService(
        supabaseClient: SupabaseClient
    ): AIService {
        return AIService(supabaseClient)
    }
}
