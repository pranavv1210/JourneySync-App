package com.example.journeysync

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val foregroundChannelName = "com.example.journeysync/foreground_service"
    private val bikeModeChannelName = "com.example.journeysync/bike_mode"
    private val bikeModePreferences = "journeysync_bike_mode"
    private val callScreeningRequestCode = 4701
    private val bikePermissionsRequestCode = 4702
    private var pendingBikeModeResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundChannelName)
            .setMethodCallHandler { call, result ->
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
                            val manager = getSystemService(POWER_SERVICE) as PowerManager
                            result.success(manager.isIgnoringBatteryOptimizations(packageName))
                        } else result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        } else Intent(Settings.ACTION_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bikeModeChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBikeModeState" -> result.success(bikeModeState())
                    "prepareBikeMode" -> prepareBikeMode(result)
                    "setBikeModeState" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        val message = call.argument<String>("message")?.trim().orEmpty()
                        getSharedPreferences(bikeModePreferences, MODE_PRIVATE).edit()
                            .putBoolean("enabled", enabled)
                            .putString("message", message)
                            .apply()
                        if (enabled && hasLocationPermission()) {
                            BikeModeMonitorService.start(applicationContext)
                        } else {
                            BikeModeMonitorService.stop(applicationContext)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun prepareBikeMode(result: MethodChannel.Result) {
        if (pendingBikeModeResult != null) {
            result.error("setup_in_progress", "Bike Mode setup is already open.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(bikeModeState())
            return
        }
        pendingBikeModeResult = result
        val roleManager = getSystemService(RoleManager::class.java)
        if (!roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            startActivityForResult(
                roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING),
                callScreeningRequestCode,
            )
        } else {
            requestBikePermissionsIfNeeded()
        }
    }

    private fun requestBikePermissionsIfNeeded() {
        val missingPermissions = listOf(
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_CONTACTS,
        ).filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missingPermissions.isEmpty()) {
            finishBikeModeSetup()
        } else {
            requestPermissions(missingPermissions.toTypedArray(), bikePermissionsRequestCode)
        }
    }

    private fun finishBikeModeSetup() {
        pendingBikeModeResult?.success(bikeModeState())
        pendingBikeModeResult = null
    }

    private fun bikeModeState(): Map<String, Any> {
        val roleAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val roleGranted = roleAvailable && getSystemService(RoleManager::class.java)
            .isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        val smsGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
        val contactsGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED
        val enabled = getSharedPreferences(bikeModePreferences, MODE_PRIVATE)
            .getBoolean("enabled", false)
        return mapOf(
            "callScreeningAvailable" to roleAvailable,
            "callScreeningGranted" to roleGranted,
            "smsGranted" to smsGranted,
            "contactsGranted" to contactsGranted,
            "enabled" to enabled,
        )
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == callScreeningRequestCode) requestBikePermissionsIfNeeded()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bikePermissionsRequestCode) finishBikeModeSetup()
    }
}
