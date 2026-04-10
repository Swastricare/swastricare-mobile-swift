package com.swastricare.health.data.workers

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Background worker that syncs local menstrual cycle data (cycles, daily logs,
 * settings) to Supabase.  Runs periodically and can also be triggered as a
 * one-shot request when the app returns to the foreground.
 */
@HiltWorker
class CycleSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val menstrualCycleRepository: MenstrualCycleRepository
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val result = menstrualCycleRepository.syncData()
            if (result.isSuccess) {
                Log.d(TAG, "Cycle data synced successfully")
                Result.success()
            } else {
                Log.w(TAG, "Cycle sync returned error, will retry")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Cycle sync failed", e)
            if (runAttemptCount < MAX_RETRIES) Result.retry() else Result.failure()
        }
    }

    companion object {
        private const val TAG = "CycleSyncWorker"
        private const val MAX_RETRIES = 3
        private const val UNIQUE_PERIODIC_WORK = "cycle_periodic_sync"
        private const val UNIQUE_ONE_SHOT_WORK = "cycle_one_shot_sync"

        /**
         * Enqueue a periodic sync that runs every 6 hours when the device
         * has network connectivity.  Uses KEEP policy so it won't duplicate.
         */
        fun enqueuePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<CycleSyncWorker>(6, TimeUnit.HOURS)
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_PERIODIC_WORK,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }

        /**
         * Trigger a one-shot sync (e.g. when the cycle screen opens or the
         * app comes back to the foreground). Replaces any pending one-shot.
         */
        fun enqueueOneTimeSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<CycleSyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_ONE_SHOT_WORK,
                ExistingWorkPolicy.REPLACE,
                request
            )
        }
    }
}
