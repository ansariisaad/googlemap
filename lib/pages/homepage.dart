// // pages/homepage.dart
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:googlemap/pages/splashpage.dart';
// import 'package:googlemap/services/api_srv.dart';
// import 'package:googlemap/services/route_calculation.dart';
// import 'package:location/location.dart';
// import 'package:permission_handler/permission_handler.dart' as perm;
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../services/locatin_srv.dart';

// class Homepage extends StatefulWidget {
//   const Homepage({super.key});

//   @override
//   State<Homepage> createState() => _HomepageState();
// }

// class _HomepageState extends State<Homepage> {
//   GoogleMapController? mapController;
//   LocationData? currentLocation;
//   final Set<Marker> markers = {};
//   final Set<Polyline> polylines = {};
//   final LocationService locationService = LocationService();
//   final RouteCalculator routeCalculator = RouteCalculator();
//   final ApiService apiService = ApiService();

//   bool isServiceRunning = false;
//   List<LatLng> collectedPoints = []; // Store all GPS points during tracking
//   double totalDistance = 0.0;
//   Timer? locationUpdateTimer;
//   StreamSubscription<LocationData>? locationSubscription;

//   @override
//   void initState() {
//     super.initState();
//     _initializeApp();
//   }

//   @override
//   void dispose() {
//     locationUpdateTimer?.cancel();
//     locationSubscription?.cancel();
//     super.dispose();
//   }

//   Future<void> _initializeApp() async {
//     await _requestPermissions();
//     await _loadSavedData();
//     await _getCurrentLocation();
//     _checkServiceStatus();
//   }

//   Future<void> _loadSavedData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final isTracking = prefs.getBool('is_tracking') ?? false;

//     if (isTracking) {
//       // Load previously collected points
//       final savedPoints = prefs.getStringList('collected_points') ?? [];
//       setState(() {
//         isServiceRunning = true;
//         collectedPoints = savedPoints.map((point) {
//           final coords = point.split(',');
//           return LatLng(double.parse(coords[0]), double.parse(coords[1]));
//         }).toList();
//       });
//       _startTracking();
//     }
//   }

//   Future<void> _requestPermissions() async {
//     Map<perm.Permission, perm.PermissionStatus> permissions = await [
//       perm.Permission.location,
//       perm.Permission.locationAlways,
//       perm.Permission.notification,
//     ].request();

//     if (permissions[perm.Permission.location]!.isDenied ||
//         permissions[perm.Permission.locationAlways]!.isDenied) {
//       _showPermissionDialog();
//     }
//   }

//   void _showPermissionDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Location Permission Required'),
//           content: const Text(
//             'This app needs location permission to track your location in the background. '
//             'Please grant "Allow all the time" permission for the app to work properly.',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 perm.openAppSettings();
//               },
//               child: const Text('Open Settings'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Later'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       currentLocation = await locationService.getCurrentLocation();
//       if (currentLocation != null) {
//         final currentPos = LatLng(
//           currentLocation!.latitude!,
//           currentLocation!.longitude!,
//         );

//         setState(() {
//           markers.add(
//             Marker(
//               markerId: const MarkerId('current_location'),
//               position: currentPos,
//               infoWindow: const InfoWindow(title: 'Current Location'),
//               icon: BitmapDescriptor.defaultMarkerWithHue(
//                 BitmapDescriptor.hueBlue,
//               ),
//             ),
//           );
//         });

//         if (mapController != null) {
//           mapController!.animateCamera(
//             CameraUpdate.newLatLngZoom(currentPos, 15),
//           );
//         }
//       }
//     } catch (e) {
//       print('Error getting location: $e');
//       _showSnackBar('Error getting location: $e', Colors.red);
//     }
//   }

//   void _checkServiceStatus() async {
//     isServiceRunning = await FlutterBackgroundService().isRunning();
//     setState(() {});
//   }

//   void _startTracking() {
//     // Collect GPS points every 10 seconds
//     locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
//       _collectLocationPoint();
//     });

//     // Also listen to real-time location changes
//     locationSubscription = locationService.getLocationStream().listen((
//       LocationData newLocation,
//     ) {
//       _handleLocationUpdate(newLocation);
//     });
//   }

//   void _stopTracking() {
//     locationUpdateTimer?.cancel();
//     locationSubscription?.cancel();
//   }

//   Future<void> _collectLocationPoint() async {
//     try {
//       final newLocation = await locationService.getCurrentLocation();
//       if (newLocation != null) {
//         final newPos = LatLng(newLocation.latitude!, newLocation.longitude!);

//         setState(() {
//           collectedPoints.add(newPos);
//         });

//         // Save points to SharedPreferences
//         final prefs = await SharedPreferences.getInstance();
//         final pointStrings = collectedPoints
//             .map((p) => '${p.latitude},${p.longitude}')
//             .toList();
//         await prefs.setStringList('collected_points', pointStrings);

//         print(
//           'Collected point ${collectedPoints.length}: ${newPos.latitude}, ${newPos.longitude}',
//         );
//       }
//     } catch (e) {
//       print('Error collecting location point: $e');
//     }
//   }

//   Future<void> _handleLocationUpdate(LocationData newLocation) async {
//     final newPos = LatLng(newLocation.latitude!, newLocation.longitude!);

//     setState(() {
//       // Update current location marker
//       markers.removeWhere((m) => m.markerId.value == 'current_location');
//       markers.add(
//         Marker(
//           markerId: const MarkerId('current_location'),
//           position: newPos,
//           infoWindow: const InfoWindow(title: 'Current Location'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//         ),
//       );
//     });

//     // Center map on current location

//     if (mapController != null) {
//       mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
//     }
//   }

//   void _startBackgroundService() async {
//     final service = FlutterBackgroundService();

//     try {
//       await perm.Permission.notification.request();

//       if (await service.isRunning()) {
//         service.invoke("setAsForeground");
//       } else {
//         service.startService();
//       }

//       setState(() {
//         isServiceRunning = true;
//         collectedPoints.clear(); // Clear previous points
//         totalDistance = 0.0;
//         polylines.clear();
//       });

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('is_tracking', true);
//       await prefs.setStringList('collected_points', []);

//       _startTracking();
//       _showSnackBar('Tracking started - Collecting GPS points', Colors.green);
//     } catch (e) {
//       _showSnackBar('Error starting service: $e', Colors.red);
//     }
//   }

//   Future<void> _stopBackgroundService() async {
//     if (collectedPoints.length < 2) {
//       _showSnackBar('Need at least 2 points to calculate route', Colors.orange);
//       _finalizeStop();
//       return;
//     }

//     // Show loading dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(
//         child: Card(
//           child: Padding(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(),
//                 SizedBox(height: 16),
//                 Text('Calculating route with OpenRouteService...'),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );

//     try {
//       // Call ORS with all collected points
//       final routeData = await routeCalculator.calculateRouteFromPoints(
//         collectedPoints,
//       );

//       if (!mounted) return;
//       Navigator.of(context).pop(); // Close loading dialog

//       setState(() {
//         totalDistance = routeData['distance'] as double;
//         final routePoints = routeData['points'] as List<LatLng>;

//         // Display the route on map
//         polylines.clear();
//         polylines.add(
//           Polyline(
//             polylineId: const PolylineId('traveled_route'),
//             points: routePoints,
//             color: Colors.blue,
//             width: 5,
//           ),
//         );

//         // Add start and end markers
//         if (collectedPoints.isNotEmpty) {
//           markers.add(
//             Marker(
//               markerId: const MarkerId('start'),
//               position: collectedPoints.first,
//               infoWindow: const InfoWindow(title: 'Start'),
//               icon: BitmapDescriptor.defaultMarkerWithHue(
//                 BitmapDescriptor.hueGreen,
//               ),
//             ),
//           );
//           markers.add(
//             Marker(
//               markerId: const MarkerId('end'),
//               position: collectedPoints.last,
//               infoWindow: const InfoWindow(title: 'End'),
//               icon: BitmapDescriptor.defaultMarkerWithHue(
//                 BitmapDescriptor.hueRed,
//               ),
//             ),
//           );
//         }
//       });

//       // Upload to backend
//       await _uploadDriveData(routeData);

//       _showSnackBar(
//         'Route calculated: ${(totalDistance / 1000).toStringAsFixed(2)} km',
//         Colors.green,
//       );
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.of(context).pop(); // Close loading dialog
//       _showSnackBar('Error calculating route: $e', Colors.red);
//     }

//     _finalizeStop();
//   }

//   Future<void> _uploadDriveData(Map<String, dynamic> routeData) async {
//     try {
//       final success = await apiService.uploadDriveData(
//         points: collectedPoints,
//         distance: totalDistance,
//         duration: routeData['duration'] as double?,
//         polyline: routeData['points'] as List<LatLng>,
//         startTime: DateTime.now().subtract(
//           Duration(seconds: collectedPoints.length * 10),
//         ),
//         endTime: DateTime.now(),
//       );

//       if (success) {
//         print('Drive data uploaded successfully');
//       } else {
//         print('Failed to upload drive data');
//       }
//     } catch (e) {
//       print('Error uploading drive data: $e');
//     }
//   }

//   void _finalizeStop() async {
//     final service = FlutterBackgroundService();
//     service.invoke("stopService");

//     _stopTracking();

//     setState(() {
//       isServiceRunning = false;
//     });

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('is_tracking', false);

//     _showSnackBar('Tracking stopped', Colors.red);
//   }

//   void _clearRoute() {
//     setState(() {
//       markers.clear();
//       polylines.clear();
//       collectedPoints.clear();
//       totalDistance = 0.0;
//     });

//     // Add current location marker back
//     if (currentLocation != null) {
//       setState(() {
//         markers.add(
//           Marker(
//             markerId: const MarkerId('current_location'),
//             position: LatLng(
//               currentLocation!.latitude!,
//               currentLocation!.longitude!,
//             ),
//             infoWindow: const InfoWindow(title: 'Current Location'),
//             icon: BitmapDescriptor.defaultMarkerWithHue(
//               BitmapDescriptor.hueBlue,
//             ),
//           ),
//         );
//       });
//     }
//   }

//   Future<void> _exitToSplash() async {
//     if (isServiceRunning) {
//       _stopBackgroundService();
//     }

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('is_tracking', false);

//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const SplashScreen()),
//     );
//   }

//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         await _exitToSplash();
//         return false;
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Location Tracker'),
//           backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: _exitToSplash,
//           ),
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.my_location),
//               onPressed: _getCurrentLocation,
//               tooltip: 'Get Current Location',
//             ),
//             IconButton(
//               icon: const Icon(Icons.settings),
//               onPressed: () => perm.openAppSettings(),
//               tooltip: 'App Settings',
//             ),
//           ],
//         ),
//         body: Column(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Theme.of(context).cardColor,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton.icon(
//                           onPressed: isServiceRunning
//                               ? _stopBackgroundService
//                               : _startBackgroundService,
//                           icon: Icon(
//                             isServiceRunning ? Icons.stop : Icons.play_arrow,
//                             color: Colors.white,
//                           ),
//                           label: Text(
//                             isServiceRunning
//                                 ? 'End Drive & Calculate'
//                                 : 'Start Drive',
//                             style: const TextStyle(color: Colors.white),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: isServiceRunning
//                                 ? Colors.red
//                                 : Colors.green,
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 8,
//                         ),
//                         decoration: BoxDecoration(
//                           color: isServiceRunning ? Colors.green : Colors.grey,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           isServiceRunning ? 'TRACKING' : 'STOPPED',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.blue.shade200),
//                     ),
//                     child: Column(
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             const Icon(Icons.route, color: Colors.blue),
//                             const SizedBox(width: 8),
//                             Text(
//                               totalDistance > 0
//                                   ? 'Distance: ${(totalDistance / 1000).toStringAsFixed(2)} km'
//                                   : 'Distance: Pending calculation',
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'GPS Points: ${collectedPoints.length}',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey.shade700,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: currentLocation != null
//                   ? GoogleMap(
//                       onMapCreated: (GoogleMapController controller) {
//                         mapController = controller;
//                       },
//                       initialCameraPosition: CameraPosition(
//                         target: LatLng(
//                           currentLocation!.latitude!,
//                           currentLocation!.longitude!,
//                         ),
//                         zoom: 15,
//                       ),
//                       markers: markers,
//                       polylines: polylines,
//                       myLocationEnabled: true,
//                       myLocationButtonEnabled: false,
//                       compassEnabled: true,
//                       mapType: MapType.normal,
//                       trafficEnabled: false,
//                       buildingsEnabled: true,
//                     )
//                   : const Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           CircularProgressIndicator(),
//                           SizedBox(height: 16),
//                           Text('Getting your location...'),
//                         ],
//                       ),
//                     ),
//             ),
//           ],
//         ),
//         floatingActionButton: FloatingActionButton(
//           onPressed: _clearRoute,
//           child: const Icon(Icons.clear),
//           tooltip: 'Clear Route',
//         ),
//       ),
//     );
//   }
// }


// pages/homepage.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:googlemap/pages/splashpage.dart';
import 'package:googlemap/services/api_srv.dart';
import 'package:googlemap/services/route_calculation.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/locatin_srv.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  GoogleMapController? mapController;
  LocationData? currentLocation;
  final Set<Marker> markers = {};
  final Set<Polyline> polylines = {};
  final LocationService locationService = LocationService();
  final RouteCalculator routeCalculator = RouteCalculator();
  final ApiService apiService = ApiService();

  bool isServiceRunning = false;
  List<LatLng> collectedPoints = []; // Store all GPS points during tracking
  double totalDistance = 0.0;
  Timer? locationUpdateTimer;
  StreamSubscription<LocationData>? locationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    locationUpdateTimer?.cancel();
    locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _loadSavedData();
    await _getCurrentLocation();
    _checkServiceStatus();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final isTracking = prefs.getBool('is_tracking') ?? false;

    if (isTracking) {
      // Load previously collected points
      final savedPoints = prefs.getStringList('collected_points') ?? [];
      setState(() {
        isServiceRunning = true;
        collectedPoints = savedPoints.map((point) {
          final coords = point.split(',');
          return LatLng(double.parse(coords[0]), double.parse(coords[1]));
        }).toList();
      });
      _startTracking();
    }
  }

  Future<void> _requestPermissions() async {
    Map<perm.Permission, perm.PermissionStatus> permissions = await [
      perm.Permission.location,
      perm.Permission.locationAlways,
      perm.Permission.notification,
    ].request();

    if (permissions[perm.Permission.location]!.isDenied ||
        permissions[perm.Permission.locationAlways]!.isDenied) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs location permission to track your location in the background. '
            'Please grant "Allow all the time" permission for the app to work properly.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                perm.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      currentLocation = await locationService.getCurrentLocation();
      if (currentLocation != null) {
        final currentPos = LatLng(
          currentLocation!.latitude!,
          currentLocation!.longitude!,
        );

        setState(() {
          markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: currentPos,
              infoWindow: const InfoWindow(title: 'Current Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            ),
          );
        });

        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentPos, 15),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Error getting location: $e', Colors.red);
    }
  }

  void _checkServiceStatus() async {
    isServiceRunning = await FlutterBackgroundService().isRunning();
    setState(() {});
  }

  void _startTracking() {
    // Collect GPS points every 10 seconds
    locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _collectLocationPoint();
    });

    // Also listen to real-time location changes
    locationSubscription = locationService.getLocationStream().listen((
      LocationData newLocation,
    ) {
      _handleLocationUpdate(newLocation);
    });
  }

  void _stopTracking() {
    locationUpdateTimer?.cancel();
    locationSubscription?.cancel();
  }

  Future<void> _collectLocationPoint() async {
    try {
      final newLocation = await locationService.getCurrentLocation();
      if (newLocation != null) {
        final newPos = LatLng(newLocation.latitude!, newLocation.longitude!);

        setState(() {
          collectedPoints.add(newPos);
        });

        // Save points to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final pointStrings = collectedPoints
            .map((p) => '${p.latitude},${p.longitude}')
            .toList();
        await prefs.setStringList('collected_points', pointStrings);

        print(
          'Collected point ${collectedPoints.length}: ${newPos.latitude}, ${newPos.longitude}',
        );
      }
    } catch (e) {
      print('Error collecting location point: $e');
    }
  }

  Future<void> _handleLocationUpdate(LocationData newLocation) async {
    final newPos = LatLng(newLocation.latitude!, newLocation.longitude!);

    setState(() {
      // Update current location marker
      markers.removeWhere((m) => m.markerId.value == 'current_location');
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: newPos,
          infoWindow: const InfoWindow(title: 'Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });

    // Center map on current location
    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
    }
  }

  void _startBackgroundService() async {
    final service = FlutterBackgroundService();

    try {
      // Request notification permission first (Android 13+)
      final notificationStatus = await perm.Permission.notification.request();

      if (notificationStatus.isDenied) {
        _showSnackBar(
          'Notification permission required for background tracking',
          Colors.red,
        );
        return;
      }

      // Set tracking flag BEFORE starting service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_tracking', true);
      await prefs.setStringList('collected_points', []);
      await prefs.setInt('points_collected', 0);

      // Clear UI state
      setState(() {
        isServiceRunning = true;
        collectedPoints.clear();
        totalDistance = 0.0;
        polylines.clear();
      });

      // Small delay to ensure SharedPreferences is saved
      await Future.delayed(const Duration(milliseconds: 200));

      // Start or activate service
      if (await service.isRunning()) {
        print('Service already running, invoking setAsForeground');
        service.invoke("setAsForeground");
      } else {
        print('Starting new background service');
        await service.startService();
      }

      // Start UI tracking
      _startTracking();

      _showSnackBar('Tracking started - Collecting GPS points', Colors.green);
    } catch (e) {
      print('Error starting service: $e');
      _showSnackBar('Error starting service: $e', Colors.red);

      // Rollback on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_tracking', false);
      setState(() {
        isServiceRunning = false;
      });
    }
  }

  Future<void> _stopBackgroundService() async {
    if (collectedPoints.length < 2) {
      _showSnackBar('Need at least 2 points to calculate route', Colors.orange);
      _finalizeStop();
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Calculating route with OpenRouteService...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Call ORS with all collected points
      final routeData = await routeCalculator.calculateRouteFromPoints(
        collectedPoints,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      setState(() {
        totalDistance = routeData['distance'] as double;
        final routePoints = routeData['points'] as List<LatLng>;

        // Display the route on map
        polylines.clear();
        polylines.add(
          Polyline(
            polylineId: const PolylineId('traveled_route'),
            points: routePoints,
            color: Colors.blue,
            width: 5,
          ),
        );

        // Add start and end markers
        if (collectedPoints.isNotEmpty) {
          markers.add(
            Marker(
              markerId: const MarkerId('start'),
              position: collectedPoints.first,
              infoWindow: const InfoWindow(title: 'Start'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('end'),
              position: collectedPoints.last,
              infoWindow: const InfoWindow(title: 'End'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        }
      });

      // Upload to backend
      await _uploadDriveData(routeData);

      _showSnackBar(
        'Route calculated: ${(totalDistance / 1000).toStringAsFixed(2)} km',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showSnackBar('Error calculating route: $e', Colors.red);
    }

    _finalizeStop();
  }

  Future<void> _uploadDriveData(Map<String, dynamic> routeData) async {
    try {
      final success = await apiService.uploadDriveData(
        points: collectedPoints,
        distance: totalDistance,
        duration: routeData['duration'] as double?,
        polyline: routeData['points'] as List<LatLng>,
        startTime: DateTime.now().subtract(
          Duration(seconds: collectedPoints.length * 10),
        ),
        endTime: DateTime.now(),
      );

      if (success) {
        print('Drive data uploaded successfully');
      } else {
        print('Failed to upload drive data');
      }
    } catch (e) {
      print('Error uploading drive data: $e');
    }
  }

  void _finalizeStop() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");

    _stopTracking();

    setState(() {
      isServiceRunning = false;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking', false);

    _showSnackBar('Tracking stopped', Colors.red);
  }

  void _clearRoute() {
    setState(() {
      markers.clear();
      polylines.clear();
      collectedPoints.clear();
      totalDistance = 0.0;
    });

    // Add current location marker back
    if (currentLocation != null) {
      setState(() {
        markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(
              currentLocation!.latitude!,
              currentLocation!.longitude!,
            ),
            infoWindow: const InfoWindow(title: 'Current Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        );
      });
    }
  }

  Future<void> _exitToSplash() async {
    if (isServiceRunning) {
      _stopBackgroundService();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tracking', false);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _exitToSplash();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Location Tracker'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _exitToSplash,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _getCurrentLocation,
              tooltip: 'Get Current Location',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => perm.openAppSettings(),
              tooltip: 'App Settings',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isServiceRunning
                              ? _stopBackgroundService
                              : _startBackgroundService,
                          icon: Icon(
                            isServiceRunning ? Icons.stop : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          label: Text(
                            isServiceRunning
                                ? 'End Drive & Calculate'
                                : 'Start Drive',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isServiceRunning
                                ? Colors.red
                                : Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isServiceRunning ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isServiceRunning ? 'TRACKING' : 'STOPPED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.route, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              totalDistance > 0
                                  ? 'Distance: ${(totalDistance / 1000).toStringAsFixed(2)} km'
                                  : 'Distance: Pending calculation',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'GPS Points: ${collectedPoints.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: currentLocation != null
                  ? GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          currentLocation!.latitude!,
                          currentLocation!.longitude!,
                        ),
                        zoom: 15,
                      ),
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      compassEnabled: true,
                      mapType: MapType.normal,
                      trafficEnabled: false,
                      buildingsEnabled: true,
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Getting your location...'),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _clearRoute,
          child: const Icon(Icons.clear),
          tooltip: 'Clear Route',
        ),
      ),
    );
  }
}
