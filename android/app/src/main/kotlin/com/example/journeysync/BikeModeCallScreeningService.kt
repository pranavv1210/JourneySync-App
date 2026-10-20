package com.example.journeysync

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.CallScreeningService
import android.telephony.SmsManager
import androidx.core.content.ContextCompat

class BikeModeCallScreeningService : CallScreeningService() {
    override fun onScreenCall(details: Call.Details) {
        val receivedAt = System.currentTimeMillis()
        val incoming = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            details.callDirection == Call.Details.DIRECTION_INCOMING
        val preferences = getSharedPreferences("journeysync_bike_mode", MODE_PRIVATE)
        if (!incoming || !preferences.getBoolean("enabled", false)) {
            recordDecision(preferences, receivedAt, "not_rejected", if (incoming) "ride_mode_off" else "outgoing_call")
            respondToCall(details, CallResponse.Builder().build())
            return
        }

        val number = details.handle?.schemeSpecificPart?.trim().orEmpty()
        val normalized = normalizeNumber(number)
        val now = System.currentTimeMillis()
        val allowEmergency = preferences.getBoolean("allow_emergency", false) &&
            matchesAny(normalized, preferences.getStringSet("emergency_numbers", emptySet()).orEmpty())
        val allowRideMember = preferences.getBoolean("allow_ride_members", false) &&
            matchesAny(normalized, preferences.getStringSet("ride_member_numbers", emptySet()).orEmpty())
        val allowFavorite = preferences.getBoolean("allow_favorites", false) &&
            number.isNotEmpty() && isFavoriteContact(number)
        val previousNumber = preferences.getString("last_incoming_number", "").orEmpty()
        val previousAt = preferences.getLong("last_incoming_at", 0L)
        val allowRepeat = preferences.getBoolean("allow_repeat", false) &&
            normalized.isNotEmpty() && normalizeNumber(previousNumber) == normalized &&
            now - previousAt <= 3 * 60 * 1000L

        preferences.edit()
            .putString("last_incoming_number", number)
            .putLong("last_incoming_at", now)
            .apply()

        if (allowEmergency || allowRideMember || allowFavorite || allowRepeat) {
            val reason = when {
                allowEmergency -> "emergency_contact"
                allowRideMember -> "ride_member"
                allowFavorite -> "favorite_contact"
                else -> "repeat_caller"
            }
            recordDecision(preferences, receivedAt, "allowed", reason)
            respondToCall(details, CallResponse.Builder().build())
            return
        }

        // Record the decision before responding. The UI can now distinguish a
        // call that Android delivered to JourneySync from one the OEM dialer
        // never sent to the screening service.
        recordDecision(preferences, receivedAt, "rejected", "ride_mode")
        respondToCall(
            details,
            CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build(),
        )

        if (!BuildConfig.BIKE_AUTO_SMS_ENABLED ||
            !preferences.getBoolean("send_sms", true) || number.isEmpty() ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        val lastNumber = preferences.getString("last_sms_number", "").orEmpty()
        val lastSentAt = preferences.getLong("last_sms_at", 0L)
        if (lastNumber == number && now - lastSentAt < 120_000L) return

        val message = preferences.getString("message", null)?.trim()?.takeIf { it.isNotEmpty() }
            ?: "I'm currently riding and can't take your call. I'll get back to you when I stop. Sent by JourneySync Ride Mode."
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

    private fun recordDecision(
        preferences: android.content.SharedPreferences,
        at: Long,
        action: String,
        reason: String,
    ) {
        preferences.edit()
            .putLong("last_screened_at", at)
            .putString("last_screened_action", action)
            .putString("last_screened_reason", reason)
            .apply()
    }

    private fun normalizeNumber(number: String): String {
        val digits = number.filter(Char::isDigit)
        return if (digits.length > 10) digits.takeLast(10) else digits
    }

    private fun matchesAny(number: String, candidates: Set<String>): Boolean {
        if (number.isEmpty()) return false
        return candidates.any { normalizeNumber(it) == number }
    }

    private fun isFavoriteContact(number: String): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        val uri = android.net.Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            android.net.Uri.encode(number),
        )
        return runCatching {
            contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup.STARRED),
                null,
                null,
                null,
            )?.use { cursor ->
                cursor.moveToFirst() && cursor.getInt(0) == 1
            } == true
        }.getOrDefault(false)
    }
}
