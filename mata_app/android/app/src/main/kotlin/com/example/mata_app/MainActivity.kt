package com.example.mata_app

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // SOS: the country of the mobile network and of the SIM card, so the
    // app can offer the right emergency number. Neither needs a permission.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
