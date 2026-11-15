package com.example.mata_app

import android.app.Activity
import android.telephony.SmsManager
import org.junit.Assert.*
import org.junit.Test

class SmsSendResultsTest {
    @Test fun allSuccessAndSingleSegment() {
        assertEquals("sent", SmsSendResults(1).record(0, Activity.RESULT_OK))
        val results = SmsSendResults(2)
        assertNull(results.record(0, Activity.RESULT_OK))
        assertEquals("sent", results.record(1, Activity.RESULT_OK))
    }

    @Test fun mixedAndAllFailure() {
        val mixed = SmsSendResults(2)
        mixed.record(0, Activity.RESULT_OK)
        assertEquals("partial", mixed.record(1, SmsManager.RESULT_ERROR_GENERIC_FAILURE))
        val failed = SmsSendResults(2)
        failed.record(0, SmsManager.RESULT_ERROR_GENERIC_FAILURE)
        assertEquals("failed", failed.record(1, SmsManager.RESULT_ERROR_LIMIT_EXCEEDED))
    }

    @Test fun duplicateAndConflictingDuplicateKeepFirstResult() {
        val results = SmsSendResults(2)
        results.record(0, Activity.RESULT_OK)
        assertNull(results.record(0, Activity.RESULT_OK))
        assertNull(results.record(0, SmsManager.RESULT_ERROR_GENERIC_FAILURE))
        assertEquals("sent", results.record(1, Activity.RESULT_OK))
        assertNull(results.record(1, Activity.RESULT_OK))
        val failureFirst = SmsSendResults(2)
        failureFirst.record(0, SmsManager.RESULT_ERROR_GENERIC_FAILURE)
        assertNull(failureFirst.record(0, Activity.RESULT_OK))
        assertEquals("partial", failureFirst.record(1, Activity.RESULT_OK))
    }

    @Test fun outOfOrderAndInvalidIndices() {
        val results = SmsSendResults(2)
        assertNull(results.record(-1, Activity.RESULT_OK))
        assertNull(results.record(2, Activity.RESULT_OK))
        assertNull(results.record(1, Activity.RESULT_OK))
        assertEquals("sent", results.record(0, Activity.RESULT_OK))
    }

    @Test fun missingCallbacksRemainUnknown() {
        val results = SmsSendResults(2)
        assertEquals("unknown", results.outcomeOrUnknown())
        results.record(0, Activity.RESULT_OK)
        assertEquals("unknown", results.outcomeOrUnknown())
    }

    @Test fun existingServiceAndSimFailuresRetainTheirMapping() {
        for (code in listOf(SmsManager.RESULT_ERROR_NO_SERVICE,
            SmsManager.RESULT_ERROR_RADIO_OFF, SmsManager.RESULT_RADIO_NOT_AVAILABLE)) {
            assertEquals("no_service", SmsSendResults(1).record(0, code))
        }
        assertEquals("no_sim", SmsSendResults(1).record(0, SmsManager.RESULT_RIL_SIM_ABSENT))
    }
}
