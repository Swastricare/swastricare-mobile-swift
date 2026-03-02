package com.swasthicare.mobile.widgets

import android.content.Context
import android.content.SharedPreferences
import androidx.glance.appwidget.GlanceAppWidgetManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * WidgetDataManager reads/writes widget data from SharedPreferences.
 * Called by repositories when data changes to keep widgets fresh.
 */
object WidgetDataManager {

    private const val PREFS_NAME = "swasthicare_widget_prefs"

    // Hydration keys
    const val KEY_HYDRATION_CURRENT = "widget_hydration_current"
    const val KEY_HYDRATION_GOAL = "widget_hydration_goal"

    // Medication keys
    const val KEY_MEDICATION_NEXT_NAME = "widget_medication_next_name"
    const val KEY_MEDICATION_NEXT_TIME = "widget_medication_next_time"
    const val KEY_MEDICATION_NEXT_DOSAGE = "widget_medication_next_dosage"
    const val KEY_MEDICATION_NEXT_ID = "widget_medication_next_id"
    const val KEY_MEDICATION_NEXT_SCHEDULE_ID = "widget_medication_next_schedule_id"

    // Steps keys
    const val KEY_STEPS_CURRENT = "widget_steps_current"
    const val KEY_STEPS_GOAL = "widget_steps_goal"
    const val KEY_STEPS_DISTANCE = "widget_steps_distance"
    const val KEY_STEPS_CALORIES = "widget_steps_calories"

    // Diet keys
    const val KEY_DIET_CALORIES_CURRENT = "widget_diet_calories_current"
    const val KEY_DIET_CALORIES_GOAL = "widget_diet_calories_goal"
    const val KEY_DIET_PROTEIN = "widget_diet_protein"
    const val KEY_DIET_CARBS = "widget_diet_carbs"
    const val KEY_DIET_FAT = "widget_diet_fat"

    fun getPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // -----------------------------------------------
    // Hydration
    // -----------------------------------------------

    fun updateHydrationWidget(context: Context, currentMl: Int, goalMl: Int) {
        getPrefs(context).edit()
            .putInt(KEY_HYDRATION_CURRENT, currentMl)
            .putInt(KEY_HYDRATION_GOAL, goalMl)
            .apply()
    }

    fun getHydrationCurrent(context: Context): Int =
        getPrefs(context).getInt(KEY_HYDRATION_CURRENT, 0)

    fun getHydrationGoal(context: Context): Int =
        getPrefs(context).getInt(KEY_HYDRATION_GOAL, 2500)

    // -----------------------------------------------
    // Medication
    // -----------------------------------------------

    fun updateMedicationWidget(
        context: Context,
        nextName: String,
        nextTime: String,
        nextDosage: String,
        medicationId: String = "",
        scheduleId: String = ""
    ) {
        getPrefs(context).edit()
            .putString(KEY_MEDICATION_NEXT_NAME, nextName)
            .putString(KEY_MEDICATION_NEXT_TIME, nextTime)
            .putString(KEY_MEDICATION_NEXT_DOSAGE, nextDosage)
            .putString(KEY_MEDICATION_NEXT_ID, medicationId)
            .putString(KEY_MEDICATION_NEXT_SCHEDULE_ID, scheduleId)
            .apply()
    }

    fun getMedicationNextName(context: Context): String =
        getPrefs(context).getString(KEY_MEDICATION_NEXT_NAME, "No upcoming dose") ?: "No upcoming dose"

    fun getMedicationNextTime(context: Context): String =
        getPrefs(context).getString(KEY_MEDICATION_NEXT_TIME, "--:--") ?: "--:--"

    fun getMedicationNextDosage(context: Context): String =
        getPrefs(context).getString(KEY_MEDICATION_NEXT_DOSAGE, "") ?: ""

    // -----------------------------------------------
    // Steps
    // -----------------------------------------------

    fun updateStepsWidget(
        context: Context,
        steps: Int,
        goal: Int,
        distanceKm: Double = 0.0,
        calories: Int = 0
    ) {
        getPrefs(context).edit()
            .putInt(KEY_STEPS_CURRENT, steps)
            .putInt(KEY_STEPS_GOAL, goal)
            .putFloat(KEY_STEPS_DISTANCE, distanceKm.toFloat())
            .putInt(KEY_STEPS_CALORIES, calories)
            .apply()
    }

    fun getStepsCurrent(context: Context): Int =
        getPrefs(context).getInt(KEY_STEPS_CURRENT, 0)

    fun getStepsGoal(context: Context): Int =
        getPrefs(context).getInt(KEY_STEPS_GOAL, 10000)

    fun getStepsDistance(context: Context): Float =
        getPrefs(context).getFloat(KEY_STEPS_DISTANCE, 0f)

    fun getStepsCalories(context: Context): Int =
        getPrefs(context).getInt(KEY_STEPS_CALORIES, 0)

    // -----------------------------------------------
    // Diet
    // -----------------------------------------------

    fun updateDietWidget(
        context: Context,
        caloriesCurrent: Int,
        caloriesGoal: Int,
        proteinG: Int = 0,
        carbsG: Int = 0,
        fatG: Int = 0
    ) {
        getPrefs(context).edit()
            .putInt(KEY_DIET_CALORIES_CURRENT, caloriesCurrent)
            .putInt(KEY_DIET_CALORIES_GOAL, caloriesGoal)
            .putInt(KEY_DIET_PROTEIN, proteinG)
            .putInt(KEY_DIET_CARBS, carbsG)
            .putInt(KEY_DIET_FAT, fatG)
            .apply()
    }

    fun getDietCaloriesCurrent(context: Context): Int =
        getPrefs(context).getInt(KEY_DIET_CALORIES_CURRENT, 0)

    fun getDietCaloriesGoal(context: Context): Int =
        getPrefs(context).getInt(KEY_DIET_CALORIES_GOAL, 2000)

    fun getDietProtein(context: Context): Int =
        getPrefs(context).getInt(KEY_DIET_PROTEIN, 0)

    fun getDietCarbs(context: Context): Int =
        getPrefs(context).getInt(KEY_DIET_CARBS, 0)

    fun getDietFat(context: Context): Int =
        getPrefs(context).getInt(KEY_DIET_FAT, 0)
}
