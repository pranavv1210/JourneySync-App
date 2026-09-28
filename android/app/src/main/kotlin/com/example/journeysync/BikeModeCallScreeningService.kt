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
        val incoming = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            details.callDirection == Call.Details.DIRECTION_INCOMING
        val preferences = getSharedPreferences("journeysync_bike_mode", MODE_PRIVATE)
        if (!incoming || !preferences.getBoolean("enabled", false)) {
            respondToCall(details, CallResponse.Builder().build())
            return
        }

        val number = details.handle?.schemeSpecificPart?.trim().orEmpty()
        val normalized = normalizeNumber(number)
        val now = System.currentTimeMillis()
        val allowEmergency = preferences.getBoolean("allow_emergency", true) &&
            matchesAny(normalized, preferences.getStringSet("emergency_numbers", emptySet()).orEmpty())
        val allowRideMember = preferences.getBoolean("allow_ride_members", true) &&
            matchesAny(normalized, preferences.getStringSet("ride_member_numbers", emptySet()).orEmpty())
        val allowFavorite = preferences.getBoolean("allow_favorites", true) &&
            number.isNotEmpty() && isFavoriteContact(number)
        val previousNumber = preferences.getString("last_incoming_number", "").orEmpty()
        val previousAt = preferences.getLong("last_incoming_at", 0L)
        val allowRepeat = preferences.getBoolean("allow_repeat", true) &&
            normalized.isNotEmpty() && normalizeNumber(previousNumber) == normalized &&
            now - previousAt <= 3 * 60 * 1000L

        preferences.edit()
            .putString("last_incoming_number", number)
            .putLong("last_incoming_at", now)
            .apply()

        if (allowEmergency || allowRideMember || allowFavorite || allowRepeat) {
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

        if (!BuildConfig.BIKE_AUTO_SMS_ENABLED ||
            !preferences.getBoolean("send_sms", true) || number.isEmpty() ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

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
