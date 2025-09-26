// package com.example.googlemap

// import android.content.BroadcastReceiver
// import android.content.Context
// import android.content.Intent
// import androidx.work.OneTimeWorkRequest
// import androidx.work.WorkManager
// import id.flutter.flutter_background_service.FlutterBackgroundService

// class BootReceiver : BroadcastReceiver() {
//     override fun onReceive(context: Context, intent: Intent) {
//         when (intent.action) {
//             Intent.ACTION_BOOT_COMPLETED,
//             Intent.ACTION_MY_PACKAGE_REPLACED,
//             Intent.ACTION_PACKAGE_REPLACED -> {
//                 // Restart background service after boot
//                 try {
//                     val serviceIntent = Intent(context, FlutterBackgroundService::class.java)
//                     context.startForegroundService(serviceIntent)
//                 } catch (e: Exception) {
//                     e.printStackTrace()
//                 }
//             }
//         }
//     }
// }


package com.example.googlemap

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                // For now, do nothing
                // Later, you can trigger your Flutter background service from Dart side
            }
        }
    }
}
