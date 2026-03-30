package com.emihle.purplesafety

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.emihle.purplesafety.services.PowerButtonService
import com.emihle.purplesafety.services.ShakeDetectorService

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sos_trigger"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check if launched from background trigger
        if (intent.getBooleanExtra("trigger_sos", false)) {
            // We'll send the trigger status to Flutter later via method channel
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTriggerStatus" -> {
                        val triggered = intent.getBooleanExtra("trigger_sos", false)
                        result.success(triggered)
                        // Clear the flag after reading so it doesn't trigger again
                        intent.removeExtra("trigger_sos")
                    }
                    "setTriggerSettings" -> {
                        val powerButton = call.argument<Boolean>("powerButton") ?: false
                        val shake = call.argument<Boolean>("shake") ?: false

                        if (powerButton) {
                            ContextCompat.startForegroundService(this, Intent(this, PowerButtonService::class.java))
                        } else {
                            stopService(Intent(this, PowerButtonService::class.java))
                        }

                        if (shake) {
                            ContextCompat.startForegroundService(this, Intent(this, ShakeDetectorService::class.java))
                        } else {
                            stopService(Intent(this, ShakeDetectorService::class.java))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}