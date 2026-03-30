package com.emihle.purplesafety.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.emihle.purplesafety.MainActivity
import com.emihle.purplesafety.R

class ShakeDetectorService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var lastShakeTime = 0L
    private val SHAKE_THRESHOLD = 15.0f
    private val SHAKE_COOLDOWN = 2000L

    companion object {
        private const val CHANNEL_ID = "shake_channel"
        private const val NOTIFICATION_ID = 1002
    }

    override fun onCreate() {
        super.onCreate()
        startForeground()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        Log.d("ShakeDetectorService", "Service started")
    }

    private fun startForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Shake SOS",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Purple Safety")
            .setContentText("Shake SOS active")
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            val gForce = Math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            if (gForce > SHAKE_THRESHOLD) {
                val now = System.currentTimeMillis()
                if (now - lastShakeTime > SHAKE_COOLDOWN) {
                    lastShakeTime = now
                    triggerSOS()
                }
            }
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

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}