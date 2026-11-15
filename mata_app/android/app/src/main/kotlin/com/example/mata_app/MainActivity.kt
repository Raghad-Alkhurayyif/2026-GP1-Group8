package com.example.mata_app

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var smsBridge: SmsBridge? = null
    // SOS: the country of the mobile network and of the SIM card, so the
    // app can offer the right emergency number. Neither needs a permission.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = SmsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mata/telephony")
            .setMethodCallHandler { call, result ->
                val telephony =
                    getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager?
                when (call.method) {
                    "networkCountryIso" -> result.success(telephony?.networkCountryIso)
                    "simCountryIso" -> result.success(telephony?.simCountryIso)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsBridge?.onPermissionResult(requestCode)
    }

    override fun onDestroy() {
        smsBridge?.dispose()
        super.onDestroy()
    }
}
