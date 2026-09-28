package com.example.journeysync

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

class RideModeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val enabled = context.getSharedPreferences(
            "journeysync_bike_mode",
            Context.MODE_PRIVATE,
        ).getBoolean("enabled", false)
        val hasLocation =
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        if (enabled && hasLocation) BikeModeMonitorService.start(context)
    }
}
