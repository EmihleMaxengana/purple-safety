package com.emihle.purplesafety.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("flutter_shared_preferences", Context.MODE_PRIVATE)
            val powerEnabled = prefs.getBoolean("flutter.power_button_trigger", false)
            val shakeEnabled = prefs.getBoolean("flutter.shake_trigger", false)

            if (powerEnabled) {
                ContextCompat.startForegroundService(context, Intent(context, PowerButtonService::class.java))
            }
            if (shakeEnabled) {
                ContextCompat.startForegroundService(context, Intent(context, ShakeDetectorService::class.java))
            }
            Log.d("BootReceiver", "Services restarted")
        }
    }
}