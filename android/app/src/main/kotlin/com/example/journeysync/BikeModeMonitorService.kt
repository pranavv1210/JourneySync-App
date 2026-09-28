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
        private const val actionDisable = "journeysync.RIDE_MODE_DISABLE"

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
        if (intent?.action == actionDisable) {
            disableRideMode("Ride Mode turned off. Calls will ring normally.")
            return START_NOT_STICKY
        }
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
        } else if (!reminderShown && isStationaryLongEnough()) {
            reminderShown = true
            val preferences = getSharedPreferences("journeysync_bike_mode", MODE_PRIVATE)
            if (preferences.getBoolean("auto_turn_off", false)) {
                disableRideMode(
                    "Ride Mode turned off after you stayed stopped. Calls will ring normally.",
                )
            } else if (preferences.getBoolean("remind_when_stopped", true)) {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(reminderId, stationaryNotification())
            }
        }
    }

    private fun isStationaryLongEnough(): Boolean {
        val preferences = getSharedPreferences("journeysync_bike_mode", MODE_PRIVATE)
        val minutes = preferences.getInt("stationary_minutes", 10).coerceIn(5, 30)
        return System.currentTimeMillis() - lastMovementAt >= minutes * 60_000L
    }

    private fun disableRideMode(message: String) {
        getSharedPreferences("journeysync_bike_mode", MODE_PRIVATE).edit()
            .putBoolean("enabled", false)
            .putLong("activated_at", 0L)
            .apply()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(reminderId, disabledNotification(message))
        stopForeground(true)
        stopSelf()
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
            NotificationChannel(channelId, "Ride Mode", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows when Ride Mode is handling calls"
                setShowBadge(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                reminderChannelId,
                "Ride Mode reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Reminds you to review Ride Mode after you stop"
            },
        )
    }

    private fun disablePendingIntent(): PendingIntent = PendingIntent.getService(
        this,
        22,
        Intent(this, BikeModeMonitorService::class.java).setAction(actionDisable),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

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
        .setContentTitle("Ride Mode active")
        .setContentText("Incoming calls will be declined. Tap to review.")
        .setOngoing(true)
        .setSilent(true)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .addAction(0, "Turn off", disablePendingIntent())
        .setContentIntent(appPendingIntent())
        .build()

    private fun stationaryNotification() = NotificationCompat.Builder(this, reminderChannelId)
        .setSmallIcon(android.R.drawable.ic_menu_mylocation)
        .setContentTitle("Still parked?")
        .setContentText("Turn off Ride Mode when you're ready to receive calls again.")
        .setAutoCancel(true)
        .setContentIntent(appPendingIntent())
        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        .build()

    private fun disabledNotification(message: String) =
        NotificationCompat.Builder(this, reminderChannelId)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Ride Mode is off")
            .setContentText(message)
            .setAutoCancel(true)
            .setContentIntent(appPendingIntent())
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
}
