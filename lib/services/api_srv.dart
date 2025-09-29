// services/api_srv.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ApiService {
  // Replace with your actual backend API endpoint
  static const String _baseUrl = 'https://your-backend-api.com/api';
  static const String _uploadEndpoint = '$_baseUrl/drives/upload';

  // Add your API key or authentication token if needed
  static const String? _apiKey = null;

  /// Upload complete drive data after tracking ends
  Future<bool> uploadDriveData({
    required List<LatLng> points,
    required double distance,
    required double? duration,
    required List<LatLng> polyline,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final url = Uri.parse(_uploadEndpoint);

      final headers = {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      };

      // Prepare GPS points data
      final gpsPoints = points
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList();

      // Prepare polyline data (simplified for storage)
      final polylineData = polyline
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList();

      final body = jsonEncode({
        'drive_data': {
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'total_distance': distance, // in meters
          'duration': duration, // in seconds (if available)
          'gps_points': gpsPoints,
          'polyline': polylineData,
          'points_count': points.length,
          'device_info': {
            'platform': 'flutter',
            'tracking_interval': 10, // seconds
          },
        },
        'metadata': {'uploaded_at': DateTime.now().toIso8601String()},
      });

      print('Uploading drive data...');
      print('Distance: ${distance}m, Points: ${points.length}');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timeout');
            },
          );

      print('Upload Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✓ Drive data uploaded successfully');
        final responseData = jsonDecode(response.body);
        print('Server response: $responseData');
        return true;
      } else {
        print('✗ Upload failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('✗ Error uploading drive data: $e');
      return false;
    }
  }

  /// Upload single location point (for real-time updates if needed)
  Future<bool> uploadLocation({
    required double latitude,
    required double longitude,
    required double distance,
    required DateTime timestamp,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/location/update');

      final headers = {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      };

      final body = jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'distance': distance,
        'timestamp': timestamp.toIso8601String(),
        'device_id': 'flutter_device',
      });

      print('Uploading location: $latitude, $longitude');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error uploading location: $e');
      return false;
    }
  }

  /// Get drive history from backend
  Future<List<Map<String, dynamic>>?> getDriveHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = {
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
      };

      final url = Uri.parse(
        '$_baseUrl/drives/history',
      ).replace(queryParameters: queryParams);

      final headers = {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      };

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['drives'] ?? []);
      } else {
        print('Failed to get drive history: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting drive history: $e');
      return null;
    }
  }

  /// Test API connectivity
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('API connection test failed: $e');
      return false;
    }
  }
}
