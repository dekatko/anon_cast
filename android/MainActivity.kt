package com.example.anon_cast

import android.os.Bundle
import io.flutter.app.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.security.SecureRandom

class MainActivity : FlutterActivity() {
    private val channel: MethodChannel by lazy {
        val channelName = "com.example.anon_cast/secure_random"
        MethodChannel(this, channelName)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GeneratedPluginRegistrant.registerWith(this)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "generateSecureBytes") {
                val count = call.argument<Int>("count") ?: return@setMethodCallHandler
                val randomBytes = ByteArray(count)
                SecureRandom().nextBytes(randomBytes)
                result.success(randomBytes.toList())
            }
        }
    }
}