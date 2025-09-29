// main.dart - Proper Background Service with Notification Channel
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:googlemap/pages/splashpage.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Method channel for native Android code
const platform = MethodChannel('com.example.googlemap/notification');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create notification channel from native side FIRST
  await createNotificationChannel();

  // Then initialize service
  await initializeService();

  runApp(const MyApp());
}

// Create notification channel using native Android code
Future<void> createNotificationChannel() async {
  try {
    await platform.invokeMethod('createNotificationChannel');
    print('✓ Notification channel created');
  } catch (e) {
    print('Error creating notification channel: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: false,
      onStart: onStart,
      isForegroundMode: true,
      autoStartOnBoot: false,
      notificationChannelId: 'location_tracking_channel',
      initialNotificationTitle: 'Location Tracker',
      initialNotificationContent: 'Ready to track',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
  );

  print('✓ Background service configured');
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  // Location tracking
  final location = Location();
  Timer? timer;
  int pointsCollected = 0;

  // Check tracking state
  final prefs = await SharedPreferences.getInstance();
  final isTracking = prefs.getBool('is_tracking') ?? false;

  if (!isTracking) {
    print('Not tracking, stopping service');
    service.stopSelf();
    return;
  }

  print('Starting location tracking...');

  // Set initial notification
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Location Tracker",
      content: "Starting GPS tracking...",
    );
  }

  // Small delay to ensure notification is set
  await Future.delayed(const Duration(milliseconds: 300));

  timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isTracking = prefs.getBool('is_tracking') ?? false;

      if (!isTracking) {
        print('Tracking stopped by user');
        timer.cancel();
        service.stopSelf();
        return;
      }

      final locationData = await location.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        pointsCollected++;

        // Save location
        await prefs.setDouble('last_lat', locationData.latitude!);
        await prefs.setDouble('last_lng', locationData.longitude!);
        await prefs.setString('last_update', DateTime.now().toIso8601String());
        await prefs.setInt('points_collected', pointsCollected);

        // Update notification
        if (service is AndroidServiceInstance) {
          final now = DateTime.now();
          final timeStr =
              '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
          service.setForegroundNotificationInfo(
            title: "Tracking Active",
            content: "Points: $pointsCollected | $timeStr",
          );
        }

        print(
          'Point $pointsCollected: ${locationData.latitude}, ${locationData.longitude}',
        );
      }
    } catch (e) {
      print('Error in background tracking: $e');

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Location Tracker",
          content: "Error: Unable to get location",
        );
      }
    }
  });
}

// // main.dart - Fixed Background Service Setup
// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:googlemap/pages/splashpage.dart';
// import 'package:location/location.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// // Initialize notification plugin
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await initializeNotifications();
//   await initializeService();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Location Tracker',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//         useMaterial3: true,
//       ),
//       home: const SplashScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// Future<void> initializeNotifications() async {
//   const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');

//   const InitializationSettings initializationSettings = InitializationSettings(
//     android: initializationSettingsAndroid,
//   );

//   await flutterLocalNotificationsPlugin.initialize(initializationSettings);

//   // Create notification channel for Android 8.0+
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'location_tracking_channel', // id
//     'Location Tracking', // title
//     description: 'This channel is used for location tracking notifications',
//     importance: Importance.low,
//     playSound: false,
//     enableVibration: false,
//   );

//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(channel);
// }

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();

//   // Create notification channel
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'location_tracking_channel',
//     'Location Tracking',
//     description: 'This channel is used for location tracking notifications',
//     importance: Importance.low,
//   );

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(channel);

//   await service.configure(
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//     androidConfiguration: AndroidConfiguration(
//       autoStart: false,
//       onStart: onStart,
//       isForegroundMode: true,
//       autoStartOnBoot: false, // Changed to false, will handle manually
//       notificationChannelId: 'location_tracking_channel',
//       initialNotificationTitle: 'Location Tracker',
//       initialNotificationContent: 'Initializing tracking...',
//       foregroundServiceNotificationId: 888,
//       foregroundServiceTypes: [AndroidForegroundType.location],
//     ),
//   );
// }

// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   return true;
// }

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   if (service is AndroidServiceInstance) {
//     service.on('setAsForeground').listen((event) {
//       service.setAsForegroundService();
//     });

//     service.on('setAsBackground').listen((event) {
//       service.setAsBackgroundService();
//     });

//     service.on('stopService').listen((event) {
//       service.stopSelf();
//     });

//     // Set up proper foreground notification
//     service.setForegroundNotificationInfo(
//       title: "Location Tracker",
//       content: "Tracking your location...",
//     );
//   }

//   // Location tracking logic
//   final location = Location();
//   Timer? timer;
//   int pointsCollected = 0;

//   // Check if we should be tracking
//   final prefs = await SharedPreferences.getInstance();
//   final isTracking = prefs.getBool('is_tracking') ?? false;

//   if (!isTracking) {
//     service.stopSelf();
//     return;
//   }

//   timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final isTracking = prefs.getBool('is_tracking') ?? false;

//       if (!isTracking) {
//         timer.cancel();
//         service.stopSelf();
//         return;
//       }

//       final locationData = await location.getLocation();

//       if (locationData.latitude != null && locationData.longitude != null) {
//         pointsCollected++;

//         // Save location
//         await prefs.setDouble('last_lat', locationData.latitude!);
//         await prefs.setDouble('last_lng', locationData.longitude!);
//         await prefs.setString('last_update', DateTime.now().toIso8601String());

//         // Update notification with tracking info
//         if (service is AndroidServiceInstance) {
//           service.setForegroundNotificationInfo(
//             title: "Location Tracker Active",
//             content:
//                 "Points collected: $pointsCollected | ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
//           );
//         }

//         print(
//           'Background location updated: ${locationData.latitude}, ${locationData.longitude}',
//         );
//       }
//     } catch (e) {
//       print('Background service error: $e');

//       // Update notification on error
//       if (service is AndroidServiceInstance) {
//         service.setForegroundNotificationInfo(
//           title: "Location Tracker",
//           content: "Error: $e",
//         );
//       }
//     }
//   });
// }

// // main.dart - Background Service Setup
// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// import 'package:googlemap/pages/splashpage.dart';
// import 'package:location/location.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await initializeService();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Location Tracker',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//         useMaterial3: true,
//       ),
//       home: const SplashScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();

//   await service.configure(
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//     androidConfiguration: AndroidConfiguration(
//       autoStart: false,
//       onStart: onStart,
//       isForegroundMode: true,
//       autoStartOnBoot: true,
//       notificationChannelId: 'location_tracking_channel',
//       initialNotificationTitle: 'Location Tracker',
//       initialNotificationContent: 'Tracking your location',
//       foregroundServiceNotificationId: 888,
//     ),
//   );
// }

// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   return true;
// }

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();

//   if (service is AndroidServiceInstance) {
//     service.on('setAsForeground').listen((event) {
//       service.setAsForegroundService();
//     });

//     service.on('setAsBackground').listen((event) {
//       service.setAsBackgroundService();
//     });
//   }

//   service.on('stopService').listen((event) {
//     service.stopSelf();
//   });

//   // Location tracking logic
//   final location = Location();
//   Timer? timer;

//   timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final isTracking = prefs.getBool('is_tracking') ?? false;

//       if (!isTracking) {
//         timer.cancel();
//         return;
//       }

//       final locationData = await location.getLocation();

//       if (locationData.latitude != null && locationData.longitude != null) {
//         // Save location
//         await prefs.setDouble('last_lat', locationData.latitude!);
//         await prefs.setDouble('last_lng', locationData.longitude!);
//         await prefs.setString('last_update', DateTime.now().toIso8601String());

//         // Update notification
//         if (service is AndroidServiceInstance) {
//           if (await service.isForegroundService()) {
//             service.setForegroundNotificationInfo(
//               title: "Location Tracker",
//               content:
//                   "Tracking active - ${DateTime.now().hour}:${DateTime.now().minute}",
//             );
//           }
//         }

//         print(
//           'Background location updated: ${locationData.latitude}, ${locationData.longitude}',
//         );
//       }
//     } catch (e) {
//       print('Background service error: $e');
//     }
//   });
// }
