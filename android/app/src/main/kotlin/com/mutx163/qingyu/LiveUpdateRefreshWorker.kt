package com.mutx163.qingyu

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * WorkManager-based backup for live update (super island / dynamic island).
 *
 * Same problem as widget refresh: MIUI/HyperOS blocks AlarmManager when
 * an accessibility service is enabled. This worker ensures the live update
 * scheduler can still trigger course-aware updates.
 */
class LiveUpdateRefreshWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            LiveUpdateScheduler.handleAlarm(applicationContext)
            Result.success()
        } catch (e: IllegalStateException) {
            // Android 12+ restricts starting foreground services from the
            // background.  Fall back to reschedule-only (schedules the next
            // alarm without trying to start the service immediately).
            Log.w(TAG, DiagnosticLogMessages.LOG_FGS_START_BLOCKED, e)
            try {
                LiveUpdateScheduler.reschedule(applicationContext, allowImmediateStart = false)
            } catch (_: Exception) {}
            Result.success()
        } catch (e: Exception) {
            Log.w(TAG, DiagnosticLogMessages.LOG_LIVE_UPDATE_REFRESH_WORKER_FAILED, e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "LiveUpdateRefreshWorker"
        private const val WORK_NAME = "live_update_periodic_refresh"

        fun ensureScheduled(context: Context) {
            val request = PeriodicWorkRequestBuilder<LiveUpdateRefreshWorker>(
                15, TimeUnit.MINUTES,
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
