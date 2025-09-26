import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  final Location _location = Location();

  Future<LocationData?> getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }

    try {
      final locationData = await _location.getLocation();

      // Save location to shared preferences for background service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_lat', locationData.latitude ?? 0.0);
      await prefs.setDouble('last_lng', locationData.longitude ?? 0.0);
      await prefs.setString('last_update', DateTime.now().toIso8601String());

      return locationData;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Stream<LocationData> getLocationStream() {
    return _location.onLocationChanged;
  }
}
