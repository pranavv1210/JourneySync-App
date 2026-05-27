package com.example.journeysync

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
                else -> result.notImplemented()
            }
        }
    }
}
