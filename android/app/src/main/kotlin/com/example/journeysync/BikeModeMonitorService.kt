package com.example.journeysync

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class BikeModeMonitorService : Service(), LocationListener {
    private lateinit var locationManager: LocationManager
    private var anchor: Location? = null
    private var lastMovementAt = 0L
    private var reminderShown = false

    companion object {
        private const val channelId = "journeysync_bike_mode"
        private const val reminderChannelId = "journeysync_bike_mode_reminders"
        private const val notificationId = 1021
        private const val reminderId = 1022
        private const val actionStart = "journeysync.BIKE_MODE_START"
        private const val actionStop = "journeysync.BIKE_MODE_STOP"
        private const val stationaryMillis = 10 * 60 * 1000L

        fun start(context: Context) {
            val intent = Intent(context, BikeModeMonitorService::class.java).setAction(actionStart)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else context.startService(intent)
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, BikeModeMonitorService::class.java).setAction(actionStop),
            )
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannels()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == actionStop) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(notificationId, ongoingNotification())
        lastMovementAt = System.currentTimeMillis()
        beginMonitoring()
        return START_STICKY
    }

    private fun beginMonitoring() {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) return
        runCatching {
            val provider = if (fine && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                LocationManager.GPS_PROVIDER
            } else LocationManager.NETWORK_PROVIDER
            locationManager.requestLocationUpdates(provider, 60_000L, 25f, this)
        }
    }

    override fun onLocationChanged(location: Location) {
        val previous = anchor
        if (previous == null) {
            anchor = location
            lastMovementAt = System.currentTimeMillis()
            return
        }
        if (previous.distanceTo(location) >= 100f) {
            anchor = location
            lastMovementAt = System.currentTimeMillis()
            reminderShown = false
        } else if (!reminderShown &&
            System.currentTimeMillis() - lastMovementAt >= stationaryMillis
        ) {
            reminderShown = true
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(reminderId, stationaryNotification())
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
    override fun onProviderEnabled(provider: String) = Unit
    override fun onProviderDisabled(provider: String) = Unit

    override fun onDestroy() {
        runCatching { locationManager.removeUpdates(this) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(channelId, "Bike Mode", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows when Bike Mode is handling calls"
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                reminderChannelId,
                "Bike Mode reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Reminds you to review Bike Mode after you stop"
            },
        )
    }

    private fun appPendingIntent(): PendingIntent {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        return PendingIntent.getActivity(
            this,
            21,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ongoingNotification() = NotificationCompat.Builder(this, channelId)
        .setSmallIcon(android.R.drawable.ic_menu_directions)
        .setContentTitle("Bike Mode is on")
        .setContentText("Riding status active. Tap to review Bike Mode.")
        .setOngoing(true)
        .setSilent(true)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .setContentIntent(appPendingIntent())
        .build()

    private fun stationaryNotification() = NotificationCompat.Builder(this, reminderChannelId)
        .setSmallIcon(android.R.drawable.ic_menu_mylocation)
        .setContentTitle("Still parked?")
        .setContentText("Turn off Bike Mode when you're ready to receive calls again.")
        .setAutoCancel(true)
        .setContentIntent(appPendingIntent())
        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        .build()
}
