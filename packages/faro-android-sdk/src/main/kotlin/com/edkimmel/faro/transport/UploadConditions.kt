package com.edkimmel.faro.transport

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.PowerManager

/**
 * Checks system conditions before attempting network uploads.
 * Modeled after Datadog's approach: battery level, charging state, power-save mode.
 */
internal object UploadConditions {

    private const val LOW_BATTERY_THRESHOLD = 0.10f

    enum class Blocker(val reason: String) {
        LOW_BATTERY("Battery level below threshold"),
        POWER_SAVE_MODE("Power save mode enabled")
    }

    /**
     * Returns a list of conditions currently blocking uploads.
     * Empty list means uploads are allowed.
     */
    fun currentBlockers(context: Context): List<Blocker> {
        val blockers = mutableListOf<Blocker>()

        checkBattery(context, blockers)
        checkPowerSaveMode(context, blockers)

        return blockers
    }

    private fun checkBattery(context: Context, blockers: MutableList<Blocker>) {
        try {
            val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
                context.registerReceiver(null, filter)
            }
            if (batteryStatus == null) return

            val status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING
                    || status == BatteryManager.BATTERY_STATUS_FULL

            if (isCharging) return

            val level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1)

            if (level >= 0 && scale > 0) {
                val batteryPct = level.toFloat() / scale.toFloat()
                if (batteryPct < LOW_BATTERY_THRESHOLD) {
                    blockers.add(Blocker.LOW_BATTERY)
                }
            }
        } catch (_: Exception) {
            // If we can't read battery state, allow uploads
        }
    }

    private fun checkPowerSaveMode(context: Context, blockers: MutableList<Blocker>) {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager?.isPowerSaveMode == true) {
                blockers.add(Blocker.POWER_SAVE_MODE)
            }
        } catch (_: Exception) {
            // If we can't read power state, allow uploads
        }
    }
}
