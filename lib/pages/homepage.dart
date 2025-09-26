// pages/homepage.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:googlemap/services/route_calculation.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:workmanager/workmanager.dart';
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
  bool isServiceRunning = false;

  LatLng? startPoint;
  LatLng? endPoint;
  String distance = "";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _getCurrentLocation();
    _checkServiceStatus();
  }

  Future<void> _requestPermissions() async {
    // Request multiple permissions
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

        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
              15,
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  void _checkServiceStatus() async {
    isServiceRunning = await FlutterBackgroundService().isRunning();
    setState(() {});
  }

  void _startBackgroundService() async {
    final service = FlutterBackgroundService();

    try {
      if (await service.isRunning()) {
        service.invoke("setAsForeground");
      } else {
        await perm.Permission.notification.request();
        service.startService();
      }

      // Register periodic task with WorkManager
      await Workmanager().registerPeriodicTask(
        "location_task",
        "locationUpdate",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      setState(() {
        isServiceRunning = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background service started'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting service: $e')));
    }
  }

  void _stopBackgroundService() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");

    await Workmanager().cancelByUniqueName("location_task");

    setState(() {
      isServiceRunning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Background service stopped'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onMapTap(LatLng position) async {
    if (startPoint == null) {
      setState(() {
        startPoint = position;
        markers.add(
          Marker(
            markerId: const MarkerId('start'),
            position: position,
            infoWindow: const InfoWindow(title: 'Start Point'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      });
    } else if (endPoint == null) {
      setState(() {
        endPoint = position;
        markers.add(
          Marker(
            markerId: const MarkerId('end'),
            position: position,
            infoWindow: const InfoWindow(title: 'End Point'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      });

      // Calculate route
      await _calculateRoute();
    } else {
      // Reset and start new route
      setState(() {
        startPoint = position;
        endPoint = null;
        distance = "";
        markers.clear();
        polylines.clear();
        markers.add(
          Marker(
            markerId: const MarkerId('start'),
            position: position,
            infoWindow: const InfoWindow(title: 'Start Point'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );

        // Add current location marker back if available
        if (currentLocation != null) {
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
        }
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (startPoint != null && endPoint != null) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final routeData = await routeCalculator.calculateRoute(
          startPoint!,
          endPoint!,
        );

        Navigator.of(context).pop(); // Remove loading indicator

        setState(() {
          distance = "${(routeData['distance'] / 1000).toStringAsFixed(2)} km";

          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeData['points'],
              color: Colors.blue,
              width: 5,
            ),
          );
        });

        // Fit map to show entire route
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            [
              startPoint!.latitude,
              endPoint!.latitude,
            ].reduce((a, b) => a < b ? a : b),
            [
              startPoint!.longitude,
              endPoint!.longitude,
            ].reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            [
              startPoint!.latitude,
              endPoint!.latitude,
            ].reduce((a, b) => a > b ? a : b),
            [
              startPoint!.longitude,
              endPoint!.longitude,
            ].reduce((a, b) => a > b ? a : b),
          ),
        );

        mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0),
        );
      } catch (e) {
        Navigator.of(context).pop(); // Remove loading indicator
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error calculating route: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Test Drive'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                          isServiceRunning ? 'Stop Tracking' : 'Start Tracking',
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
                        isServiceRunning ? 'ACTIVE' : 'INACTIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (distance.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.route, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Distance: $distance',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  startPoint == null
                      ? 'Tap on map to set start point'
                      : endPoint == null
                      ? 'Tap again to set end point and calculate route'
                      : 'Tap again to start a new route',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
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
                    onTap: _onMapTap,
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "refresh",
            mini: true,
            onPressed: _checkServiceStatus,
            child: const Icon(Icons.refresh),
            tooltip: 'Refresh Service Status',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "clear",
            onPressed: () {
              setState(() {
                markers.clear();
                polylines.clear();
                startPoint = null;
                endPoint = null;
                distance = "";
              });

              // Add current location marker back
              if (currentLocation != null) {
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
              }
            },
            child: const Icon(Icons.clear),
            tooltip: 'Clear Route',
          ),
        ],
      ),
    );
  }
}
