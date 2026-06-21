package com.example.journeysync

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * JourneySync MainActivity
 *
 * Registers a MethodChannel so Flutter Dart code can start/stop the
 * [LocationForegroundService] to keep GPS alive during background tracking.
 *
 * Channel name: "com.example.journeysync/foreground_service"
 * Methods:
 *   - "startLocationService"  → starts the foreground service
 *   - "stopLocationService"   → stops the foreground service
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.example.journeysync/foreground_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    LocationForegroundService.start(applicationContext)
                    result.success(true)
                }
                "stopLocationService" -> {
                    LocationForegroundService.stop(applicationContext)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    val intent =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        } else {
                            Intent(Settings.ACTION_SETTINGS)
                        }
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
