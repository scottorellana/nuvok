package com.prepperpad.prepper_pad

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // UDP multicast (Prepper Mesh) requires a MulticastLock on Android;
        // without it most devices silently drop multicast datagrams.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        if (multicastLock == null) {
                            val wifi = applicationContext
                                .getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wifi.createMulticastLock("prepper-mesh").apply {
                                setReferenceCounted(false)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(true)
                    }
                    "release" -> {
                        multicastLock?.release()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
