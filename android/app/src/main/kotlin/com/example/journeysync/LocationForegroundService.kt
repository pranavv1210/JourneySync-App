package com.example.journeysync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * JourneySync Location Foreground Service
 *
 * Keeps the app process alive when backgrounded (e.g. when the user switches
 * to Google Maps for turn-by-turn navigation), ensuring:
 *  - The geolocator GPS stream continues to emit positions
 *  - The Supabase sync timer keeps firing
 *  - SOS remains active
 *
 * Started/stopped from Dart via a MethodChannel in MainActivity.
 *
 * The service shows a persistent notification as required by Android OS.
 * The notification is minimal and non-intrusive.
 */
class LocationForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val CHANNEL_ID = "journeysync_location"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "ACTION_START_LOCATION"
        const val ACTION_STOP = "ACTION_STOP_LOCATION"

        /** Convenience: start the service from Dart/MainActivity. */
        fun start(context: Context) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Convenience: stop the service from Dart/MainActivity. */
        fun stop(context: Context) {
            val intent = Intent(context, LocationForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                releaseWakeLock()
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Default: start foreground with location notification
                acquireWakeLock()
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        }
        // Restart if killed by OS — important for background tracking
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App was swiped away — restart the service to keep tracking alive.
        // The GPS stream managed by the Flutter engine will resume when the
        // service restarts and keeps the Dart isolate warm.
        val restartIntent = Intent(applicationContext, LocationForegroundService::class.java).apply {
            action = ACTION_START
            setPackage(packageName)
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_ONE_SHOT

        // Schedule a restart via alarm — not used here for simplicity; START_STICKY handles it.
        super.onTaskRemoved(rootIntent)
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "JourneySync:LiveRideWakeLock"
        ).apply {
            setReferenceCounted(false)
            acquire(30 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: RuntimeException) {
        } finally {
            wakeLock = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "JourneySync Live Ride",
                NotificationManager.IMPORTANCE_LOW // silent, no sound
            ).apply {
                description = "Keeps your GPS active during a group ride"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        // Tap notification → reopen the app
        val tapIntent = packageManager.getLaunchIntentForPackage(packageName)
        val tapPending = PendingIntent.getActivity(
            this, 0, tapIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("JourneySync — Ride Active")
            .setContentText("GPS tracking your group ride")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(tapPending)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
