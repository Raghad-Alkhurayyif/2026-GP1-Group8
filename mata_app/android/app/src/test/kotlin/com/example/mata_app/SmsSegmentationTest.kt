package com.example.mata_app

import android.telephony.SmsManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Android API simulation only: no sending methods or recipient numbers. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class SmsSegmentationTest {
    @Suppress("DEPRECATION")
    private fun parts(message: String) = SmsManager.getDefault().divideMessage(message)

    @Test fun asciiTemplatesFitOneSegmentAndReconstructExactly() {
        val prefix = "MATA SOS: I need help. Please contact me immediately.\n"
        for (suffix in listOf("My location is unavailable.",
            "My location: https://maps.google.com/?q=-90.000000,-180.000000")) {
            val message = prefix + suffix
            val segments = parts(message)
            assertEquals(1, segments.size)
            assertEquals(message, segments.joinToString(""))
        }
    }

    @Test fun gsmAndUnicodeSegmentationBoundaries() {
        assertEquals(1, parts("A".repeat(160)).size)
        assertEquals(2, parts("A".repeat(161)).size)
        assertEquals(1, parts("\u2019".repeat(70)).size)
        assertEquals(2, parts("\u2019".repeat(71)).size)
        val previous = "Ma\u2019ta SOS: I need help. Please contact me immediately.\nMy location is unavailable."
        assertEquals(2, parts(previous).size)
    }
}
