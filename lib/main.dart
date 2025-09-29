// main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart'; 
import 'package:googlemap/pages/splashpage.dart';
import 'package:googlemap/services/locatin_srv.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background task dispatcher
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background task executed: $task");

    try {
      // Your background location tracking logic here
      final locationService = LocationService();
      await locationService.getCurrentLocation();
    } catch (e) {
      print("Error in background task: $e");
    }

    return Future.value(true);
  });
}

// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialize notification plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('setAsForeground').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService;
    }
  });

  service.on('setAsBackground').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService;
    }
  });

  // Periodic location updates
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Show notification
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
              'location_channel',
              'Location Updates',
              channelDescription: 'Background location tracking',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: false,
            );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        await flutterLocalNotificationsPlugin.show(
          888,
          'Location Tracking',
          'App is tracking location in background - ${DateTime.now().toString().substring(11, 16)}',
          platformChannelSpecifics,
        );
      }
    }

    // Update location
    try {
      final locationService = LocationService();
      await locationService.getCurrentLocation();
      print('Background service location update: ${DateTime.now()}');
    } catch (e) {
      print('Background service error: $e');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background service
  await initializeService();

  // Initialize Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_channel',
    'Location Updates',
    description: 'This channel is used for location tracking notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'location_channel',
      initialNotificationTitle: 'Location Tracking',
      initialNotificationContent: 'Initializing background location service',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Test Drive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const Splashpage(),
    );
  }
}
