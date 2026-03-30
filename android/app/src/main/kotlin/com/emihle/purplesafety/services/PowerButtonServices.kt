package com.emihle.purplesafety.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.emihle.purplesafety.MainActivity
import com.emihle.purplesafety.R

class PowerButtonService : Service() {
    private var pressCount = 0
    private var lastPressTime = 0L
    private var screenOffReceiver: BroadcastReceiver? = null

    companion object {
        private const val CHANNEL_ID = "power_button_channel"
        private const val NOTIFICATION_ID = 1001
        private const val TRIGGER_COUNT = 5
        private const val TIMEOUT_MS = 3000
    }

    override fun onCreate() {
        super.onCreate()
        startForeground()
        registerScreenOffReceiver()
        Log.d("PowerButtonService", "Service started")
    }

    private fun startForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Power Button SOS",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Purple Safety")
            .setContentText("Power button SOS active")
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun registerScreenOffReceiver() {
        screenOffReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_SCREEN_OFF) {
                    // Screen turned off – we'll detect power button via a separate method
                    Log.d("PowerButtonService", "Screen off")
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)
    }

    // This would be called from a system broadcast or accessibility event.
    // For simplicity, we'll simulate with a button press from a test activity.
    fun onPowerButtonPressed() {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastPressTime > TIMEOUT_MS) {
            pressCount = 0
        }
        pressCount++
        lastPressTime = currentTime
        if (pressCount >= TRIGGER_COUNT) {
            triggerSOS()
            pressCount = 0
        }
    }

    private fun triggerSOS() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("trigger_sos", true)
        }
        startActivity(intent)
        sendBroadcast(Intent("SOS_TRIGGERED"))
    }

    override fun onDestroy() {
        screenOffReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}