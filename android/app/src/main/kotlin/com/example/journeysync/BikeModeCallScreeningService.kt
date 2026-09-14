package com.example.journeysync

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telephony.SmsManager
import androidx.core.content.ContextCompat

class BikeModeCallScreeningService : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        val incoming = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            details.callDirection == Call.Details.DIRECTION_INCOMING
        val preferences = getSharedPreferences("journeysync_bike_mode", MODE_PRIVATE)
        if (!incoming || !preferences.getBoolean("enabled", false)) {
            respondToCall(details, CallResponse.Builder().build())
            return
        }

        respondToCall(
            details,
            CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build(),
        )

        val number = details.handle?.schemeSpecificPart?.trim().orEmpty()
        if (!BuildConfig.BIKE_AUTO_SMS_ENABLED || number.isEmpty() ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        val now = System.currentTimeMillis()
        val lastNumber = preferences.getString("last_sms_number", "").orEmpty()
        val lastSentAt = preferences.getLong("last_sms_at", 0L)
        if (lastNumber == number && now - lastSentAt < 120_000L) return

        val message = preferences.getString("message", null)?.trim()?.takeIf { it.isNotEmpty() }
            ?: "I'm currently riding and can't take your call. I'll get back to you when I stop. Sent by JourneySync Bike Mode."
        runCatching {
            @Suppress("DEPRECATION")
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(number, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(number, null, message, null, null)
            }
            preferences.edit()
                .putString("last_sms_number", number)
                .putLong("last_sms_at", now)
                .apply()
        }
    }
}
