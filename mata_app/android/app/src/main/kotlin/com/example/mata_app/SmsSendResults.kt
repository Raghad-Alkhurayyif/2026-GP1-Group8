package com.example.mata_app

import android.app.Activity
import android.telephony.SmsManager

/** First callback per segment wins; only complete results are aggregated. */
internal class SmsSendResults(segmentCount: Int) {
    init { require(segmentCount > 0) }
    private val results = arrayOfNulls<Int>(segmentCount)
    private var completed = false

    fun record(index: Int, code: Int): String? {
        if (completed || index !in results.indices || results[index] != null) return null
        results[index] = code
        if (results.any { it == null }) return null
        completed = true
        return outcomeOrUnknown()
    }

    fun outcomeOrUnknown(): String = when {
        results.any { it == null } -> "unknown"
        results.all { it == Activity.RESULT_OK } -> "sent"
        results.any { it == Activity.RESULT_OK } -> "partial"
        results.any { it == SmsManager.RESULT_RIL_SIM_ABSENT } -> "no_sim"
        results.any { it == SmsManager.RESULT_ERROR_NO_SERVICE ||
            it == SmsManager.RESULT_ERROR_RADIO_OFF || it == SmsManager.RESULT_RADIO_NOT_AVAILABLE } -> "no_service"
        else -> "failed"
    }
}
