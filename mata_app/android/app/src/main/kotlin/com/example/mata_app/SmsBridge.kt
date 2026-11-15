package com.example.mata_app

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** Shared dispatch and duplicate protection for SOS and the debug experiment. */
class SmsBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "mata/sms_poc")
    private val productionChannel = MethodChannel(messenger, "mata/sms")
    private val handler = Handler(Looper.getMainLooper())
    private val records = activity.getSharedPreferences("sms_poc_attempts", Context.MODE_PRIVATE)
    private var permissionResult: MethodChannel.Result? = null
    private var pendingResult: MethodChannel.Result? = null
    private var receiver: BroadcastReceiver? = null
    private var activeId: String? = null
    private val intents = mutableListOf<PendingIntent>()
    private val timeout = Runnable { finish("unknown") }

    init {
        listOf(channel, productionChannel).forEach { registeredChannel ->
            registeredChannel.setMethodCallHandler { call, result ->
                if (registeredChannel === channel && activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
                    result.error("debug_only", "SMS proof of concept requires a debug build.", null)
                } else when (call.method) {
                    "requestPermission" -> {
                        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) result.success("unsupported_device")
                        else if (granted()) result.success("granted")
                        else if (permissionResult != null) result.success("busy")
                        else {
                            permissionResult = result
                            activity.requestPermissions(arrayOf(Manifest.permission.SEND_SMS), PERMISSION_REQUEST)
                        }
                    }
                    "prepare" -> {
                        try {
                            val subscription = SubscriptionManager.getDefaultSmsSubscriptionId()
                            val status = readiness(subscription)
                            result.success(mapOf("status" to (status ?: "ready"), "subscriptionId" to subscription))
                        } catch (_: Exception) {
                            result.success(mapOf("status" to "unsupported_device"))
                        }
                    }
                    "send" -> {
                        val subscription = call.argument<Int>("subscriptionId")
                        if (registeredChannel === productionChannel && subscription == null) result.success("invalid_arguments")
                        else send(call.argument("attemptId"), call.argument("recipient"), call.argument("message"), subscription, result)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun readiness(subscription: Int): String? {
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) return "unsupported_device"
        if (!granted()) return "permission_denied"
        if (subscription < 0 || subscription == Int.MAX_VALUE) return "no_default_sim"
        val telephony = activity.getSystemService(TelephonyManager::class.java)
            .createForSubscriptionId(subscription)
        if (telephony.simState != TelephonyManager.SIM_STATE_READY) return "sim_not_ready"
        return null
    }

    private fun granted() = activity.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED

    fun onPermissionResult(requestCode: Int) {
        if (requestCode != PERMISSION_REQUEST) return
        permissionResult?.success(if (granted()) "granted" else "denied")
        permissionResult = null
    }

    @Suppress("DEPRECATION")
    private fun send(id: String?, recipient: String?, message: String?, selectedSubscription: Int?, result: MethodChannel.Result) {
        if (id == null || !Regex("^[A-Za-z0-9-]{1,80}$").matches(id) ||
            recipient == null || !Regex("^\\+[1-9][0-9]{7,14}$").matches(recipient) ||
            message.isNullOrBlank() || message.length > 2000) {
            result.success("invalid_arguments")
            return
        }
        // A persisted ID is never dispatched twice, including after process death.
        if (records.contains(id)) {
            result.success(records.getString(id, "unknown"))
            return
        }
        if (activeId != null) { result.success("busy"); return }
        if (!granted()) { result.success("permission_denied"); return }
        if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
            result.success("unsupported_device"); return
        }
        val subscription = SubscriptionManager.getDefaultSmsSubscriptionId()
        // isValidSubscriptionId is API 29; retain API 24 support without it.
        if (subscription < 0 || subscription == Int.MAX_VALUE) {
            result.success("no_default_sim"); return
        }
        try {
            if (selectedSubscription != null && selectedSubscription != subscription) {
                result.success("sim_changed"); return
            }
            val readiness = readiness(subscription)
            if (readiness != null) { result.success(readiness); return }
            val manager = if (Build.VERSION.SDK_INT >= 31) {
                activity.getSystemService(SmsManager::class.java).createForSubscriptionId(subscription)
            } else SmsManager.getSmsManagerForSubscriptionId(subscription)
            val parts = manager.divideMessage(message)
            val outcomes = arrayOfNulls<Int>(parts.size)
            val action = "${activity.packageName}.SMS_POC.${UUID.randomUUID()}"
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val index = intent.getIntExtra("part", -1)
                    if (index !in outcomes.indices || outcomes[index] != null) return
                    outcomes[index] = resultCode
                    if (outcomes.all { it != null }) {
                        finish(when {
                            outcomes.all { it == Activity.RESULT_OK } -> "sent"
                            outcomes.any { it == Activity.RESULT_OK } -> "partial"
                            outcomes.any { it == SmsManager.RESULT_RIL_SIM_ABSENT } -> "no_sim"
                            outcomes.any { it == SmsManager.RESULT_ERROR_NO_SERVICE || it == SmsManager.RESULT_ERROR_RADIO_OFF || it == SmsManager.RESULT_RADIO_NOT_AVAILABLE } -> "no_service"
                            else -> "failed"
                        })
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= 33) {
                activity.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_NOT_EXPORTED)
            } else activity.registerReceiver(receiver, IntentFilter(action))
            parts.indices.forEach { index ->
                intents.add(PendingIntent.getBroadcast(activity, index,
                    Intent(action).setPackage(activity.packageName).putExtra("part", index),
                    PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE))
            }
            activeId = id
            pendingResult = result
            // Commit before dispatch; a crash in this window conservatively becomes unknown.
            if (!records.edit().putString(id, "unknown").commit()) {
                finish("storage_error"); return
            }
            handler.postDelayed(timeout, 60_000)
            if (parts.size == 1) manager.sendTextMessage(recipient, null, parts[0], intents[0], null)
            else manager.sendMultipartTextMessage(recipient, null, parts, ArrayList(intents), null)
        } catch (_: SecurityException) {
            if (pendingResult != null) finish("unknown") else { cleanup(); result.success("permission_denied") }
        } catch (_: UnsupportedOperationException) {
            if (pendingResult != null) finish("unknown") else { cleanup(); result.success("unsupported_device") }
        } catch (_: Exception) {
            // Never infer that an exception after dispatch means no message went out.
            if (pendingResult != null) finish("unknown") else { cleanup(); result.success("failed") }
        }
    }

    private fun finish(status: String) {
        activeId?.let { records.edit().putString(it, status).commit() }
        val result = pendingResult
        pendingResult = null
        activeId = null
        cleanup()
        result?.success(status)
    }

    private fun cleanup() {
        handler.removeCallbacks(timeout)
        receiver?.let { activity.unregisterReceiver(it) }
        receiver = null
        intents.forEach { it.cancel() }
        intents.clear()
    }

    fun dispose() {
        if (pendingResult != null) finish("unknown") else cleanup()
        permissionResult?.success("denied")
        permissionResult = null
        channel.setMethodCallHandler(null)
        productionChannel.setMethodCallHandler(null)
    }

    companion object { private const val PERMISSION_REQUEST = 8301 }
}
