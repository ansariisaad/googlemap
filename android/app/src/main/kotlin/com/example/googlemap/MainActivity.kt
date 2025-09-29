package com.example.googlemap

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.example.googlemap/notification"
    private val NATIVE_CHANNEL = "com.example.googlemap/native"
    
    private val CHANNEL_ID = "location_tracking_channel"
    private val CHANNEL_NAME = "Location Tracking"
    private val CHANNEL_DESCRIPTION = "Notifications for location tracking service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Notification channel method
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createNotificationChannel" -> {
                        createNotificationChannel()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // Native utilities method
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }
                    "checkBatteryOptimization" -> {
                        val isOptimized = checkBatteryOptimization()
                        result.success(isOptimized)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create notification channel immediately on app start
        createNotificationChannel()
        
        // Request battery optimization exemption
        requestIgnoreBatteryOptimizations()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = CHANNEL_DESCRIPTION
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                enableVibration(false)
                setSound(null, null)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            android.util.Log.d("MainActivity", "✓ Notification channel created: $CHANNEL_ID")
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                try {
                    startActivity(intent)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error requesting battery optimization: $e")
                }
            }
        }
    }

    private fun checkBatteryOptimization(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }
}
// package com.example.googlemap 
// import io.flutter.embedding.android.FlutterActivity
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel
// import android.content.Intent
// import android.os.Bundle
// import android.provider.Settings
// import android.net.Uri
// import android.os.PowerManager
// import android.content.Context

// class MainActivity: FlutterActivity() {
//     private val CHANNEL = "com.example.googlemap/native"

//     override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//         super.configureFlutterEngine(flutterEngine)
        
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "requestIgnoreBatteryOptimizations" -> {
//                     requestIgnoreBatteryOptimizations()
//                     result.success(null)
//                 }
//                 "checkBatteryOptimization" -> {
//                     val isOptimized = checkBatteryOptimization()
//                     result.success(isOptimized)
//                 }
//                 else -> {
//                     result.notImplemented()
//                 }
//             }
//         }
//     }

//     override fun onCreate(savedInstanceState: Bundle?) {
//         super.onCreate(savedInstanceState)
        
//         // Request to ignore battery optimizations
//         requestIgnoreBatteryOptimizations()
//     }

//     private fun requestIgnoreBatteryOptimizations() {
//         val intent = Intent()
//         val packageName = packageName
//         val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        
//         if (!pm.isIgnoringBatteryOptimizations(packageName)) {
//             intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
//             intent.data = Uri.parse("package:$packageName")
//             startActivity(intent)
//         }
//     }

//     private fun checkBatteryOptimization(): Boolean {
//         val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
//         return pm.isIgnoringBatteryOptimizations(packageName)
//     }
// }
