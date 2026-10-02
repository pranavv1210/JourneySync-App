package com.example.journeysync

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
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
                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
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
                    "openCallerIdSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
                        } else {
                            Intent(Settings.ACTION_SETTINGS)
                        }
                        runCatching { startActivity(intent) }
                            .onSuccess { result.success(true) }
                            .onFailure {
                                runCatching { startActivity(Intent(Settings.ACTION_SETTINGS)) }
                                    .onSuccess { result.success(true) }
                                    .onFailure { error ->
                                        result.error(
                                            "settings_unavailable",
                                            error.message ?: "Android default-app settings are unavailable.",
                                            null,
                                        )
                                    }
                            }
                    }
                    "setBikeModeState" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        val message = call.argument<String>("message")?.trim().orEmpty()
                        getSharedPreferences(bikeModePreferences, MODE_PRIVATE).edit()
                            .putBoolean("enabled", enabled)
                            .putString("message", message)
                            .putBoolean("send_sms", call.argument<Boolean>("sendSms") == true)
                            .putBoolean("allow_emergency", call.argument<Boolean>("allowEmergencyContacts") != false)
                            .putBoolean("allow_favorites", call.argument<Boolean>("allowFavorites") != false)
                            .putBoolean("allow_repeat", call.argument<Boolean>("allowRepeatCallers") != false)
                            .putBoolean("allow_ride_members", call.argument<Boolean>("allowRideMembers") != false)
                            .putBoolean("remind_when_stopped", call.argument<Boolean>("remindWhenStopped") != false)
                            .putBoolean("auto_turn_off", call.argument<Boolean>("autoTurnOff") == true)
                            .putInt("stationary_minutes", call.argument<Int>("stationaryMinutes") ?: 10)
                            .putLong("activated_at", call.argument<Number>("activatedAt")?.toLong() ?: 0L)
                            .putStringSet(
                                "emergency_numbers",
                                call.argument<List<String>>("emergencyNumbers")?.toSet() ?: emptySet(),
                            )
                            .putStringSet(
                                "ride_member_numbers",
                                call.argument<List<String>>("rideMemberNumbers")?.toSet() ?: emptySet(),
                            )
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
            result.error("setup_in_progress", "Ride Mode setup is already open.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(bikeModeState())
            return
        }
        pendingBikeModeResult = result
        val roleManager = getSystemService(RoleManager::class.java)
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            finishBikeModeSetup()
            return
        }
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
        val requestedPermissions = mutableListOf(Manifest.permission.READ_CONTACTS)
        if (BuildConfig.BIKE_AUTO_SMS_ENABLED) {
            requestedPermissions.add(Manifest.permission.SEND_SMS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestedPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val missingPermissions = requestedPermissions.filter {
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
        val roleManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSystemService(RoleManager::class.java)
        } else null
        val roleAvailable = roleManager?.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) == true
        val roleGranted = roleAvailable &&
            roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) == true
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
            "directSmsSupported" to BuildConfig.BIKE_AUTO_SMS_ENABLED,
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
        if (requestCode == callScreeningRequestCode) {
            val roleGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                getSystemService(RoleManager::class.java)
                    .isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
            } else false
            if (roleGranted) requestBikePermissionsIfNeeded() else finishBikeModeSetup()
        }
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
