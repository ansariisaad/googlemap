// services/route_calculation.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class RouteCalculator {
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjcyYTdmN2EwODgxMDY1NTAxODgwMjExYWI5MzJmMjMyYjQ3ZDVlZDRkZmJiMzhlMDc3NzllZDg2IiwiaCI6Im11cm11cjY0In0=';
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  /// Calculate route from a list of collected GPS points
  /// This should be called at the END of tracking, not during
  Future<Map<String, dynamic>> calculateRouteFromPoints(
    List<LatLng> points,
  ) async {
    if (points.isEmpty) {
      throw Exception('No points provided');
    }

    if (points.length == 1) {
      return {'points': points, 'distance': 0.0, 'duration': 0.0};
    }

    try {
      // Prepare coordinates for ORS (format: [longitude, latitude])
      final coordinates = points
          .map((point) => [point.longitude, point.latitude])
          .toList();

      final url = Uri.parse(_baseUrl);
      final headers = {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'coordinates': coordinates,
        'format': 'geojson',
        'instructions': false,
        'preference': 'recommended', // Or 'fastest' or 'shortest'
      });

      print('Calling ORS with ${points.length} points...');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('ORS request timeout');
            },
          );

      print('ORS Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          final feature = data['features'][0];
          final coordinates = feature['geometry']['coordinates'];
          final properties = feature['properties'];
          final segments = properties['segments'][0];

          // Extract distance (in meters)
          final distance = segments['distance'].toDouble();

          // Extract duration (in seconds)
          final duration = segments['duration'].toDouble();

          // Convert coordinates to LatLng for polyline
          List<LatLng> routePoints = coordinates
              .map<LatLng>(
                (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
              )
              .toList();

          print(
            'ORS Route: ${routePoints.length} points, ${distance}m, ${duration}s',
          );

          return {
            'points': routePoints,
            'distance': distance,
            'duration': duration,
          };
        } else {
          throw Exception('No route found in ORS response');
        }
      } else if (response.statusCode == 403) {
        print('ORS API Key invalid or expired');
        throw Exception('API authentication failed');
      } else if (response.statusCode == 429) {
        print('ORS rate limit exceeded');
        throw Exception('API rate limit exceeded');
      } else {
        print('ORS Error Response: ${response.body}');
        throw Exception('Failed to calculate route: ${response.statusCode}');
      }
    } catch (e) {
      print('ORS calculation error: $e');
      // Fallback: calculate straight-line distance
      return _calculateFallbackRoute(points);
    }
  }

  /// Fallback method: calculate total straight-line distance
  Map<String, dynamic> _calculateFallbackRoute(List<LatLng> points) {
    double totalDistance = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _calculateStraightLineDistance(points[i], points[i + 1]);
    }

    print('Fallback route: ${totalDistance}m straight-line distance');

    return {'points': points, 'distance': totalDistance, 'duration': 0.0};
  }

  /// Calculate straight-line distance between two points (Haversine formula)
  double _calculateStraightLineDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000; // meters

    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadius * c;

    return distance;
  }

  /// Test ORS API connection
  Future<bool> testApiConnection() async {
    try {
      final testStart = LatLng(19.0760, 72.8777); // Mumbai
      final testEnd = LatLng(19.0896, 72.8656);

      final url = Uri.parse(_baseUrl);
      final headers = {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'coordinates': [
          [testStart.longitude, testStart.latitude],
          [testEnd.longitude, testEnd.latitude],
        ],
        'format': 'geojson',
      });

      print('Testing ORS API...');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('API timeout');
            },
          );

      print('ORS Test Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✓ ORS API working correctly');
        return true;
      } else {
        print('✗ ORS API error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('✗ ORS test failed: $e');
      return false;
    }
  }

  /// Get API info
  Map<String, String> getApiInfo() {
    return {
      'service': 'OpenRouteService',
      'base_url': _baseUrl,
      'has_key': _apiKey.isNotEmpty ? 'Yes' : 'No',
    };
  }
}

// // services/route_calculator.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class RouteCalculator {
//   // Your OpenRouteService API key
//   static const String _apiKey =
//       'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjcyYTdmN2EwODgxMDY1NTAxODgwMjExYWI5MzJmMjMyYjQ3ZDVlZDRkZmJiMzhlMDc3NzllZDg2IiwiaCI6Im11cm11cjY0In0=';
//   static const String _baseUrl =
//       'https://api.openrouteservice.org/v2/directions/driving-car';

//   Future<Map<String, dynamic>> calculateRoute(LatLng start, LatLng end) async {
//     try {
//       final url = Uri.parse(_baseUrl);
//       final headers = {
//         'Authorization': _apiKey,
//         'Content-Type': 'application/json',
//       };

//       final body = jsonEncode({
//         'coordinates': [
//           [start.longitude, start.latitude],
//           [end.longitude, end.latitude],
//         ],
//         'format': 'geojson',
//       });

//       print(
//         'Calculating route from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}',
//       );

//       final response = await http.post(url, headers: headers, body: body);

//       print('Route API Response Status: ${response.statusCode}');

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         if (data['features'] != null && data['features'].isNotEmpty) {
//           final coordinates = data['features'][0]['geometry']['coordinates'];
//           final distance =
//               data['features'][0]['properties']['segments'][0]['distance'];

//           List<LatLng> points = coordinates
//               .map<LatLng>(
//                 (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
//               )
//               .toList();

//           print(
//             'Route calculated successfully: ${points.length} points, distance: ${distance}m',
//           );

//           return {'points': points, 'distance': distance};
//         } else {
//           throw Exception('No route found in response');
//         }
//       } else {
//         print('Route API Error Response: ${response.body}');
//         throw Exception(
//           'Failed to calculate route: ${response.statusCode} - ${response.body}',
//         );
//       }
//     } catch (e) {
//       print('Route calculation error: $e');
//       throw Exception('Error calculating route: $e');
//     }
//   }
// }
