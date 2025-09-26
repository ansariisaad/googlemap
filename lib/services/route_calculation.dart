// services/route_calculator.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteCalculator {
  // Your OpenRouteService API key
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImU3YjNjODhiMDI2NDQ0NjBhNzNmMzdlYzYzMWM0MmY0IiwiaCI6Im11cm11cjY0In0=';
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  Future<Map<String, dynamic>> calculateRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(_baseUrl);
      final headers = {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude],
        ],
        'format': 'geojson',
      });

      print(
        'Calculating route from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}',
      );

      final response = await http.post(url, headers: headers, body: body);

      print('Route API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          final coordinates = data['features'][0]['geometry']['coordinates'];
          final distance =
              data['features'][0]['properties']['segments'][0]['distance'];

          List<LatLng> points = coordinates
              .map<LatLng>(
                (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
              )
              .toList();

          print(
            'Route calculated successfully: ${points.length} points, distance: ${distance}m',
          );

          return {'points': points, 'distance': distance};
        } else {
          throw Exception('No route found in response');
        }
      } else {
        print('Route API Error Response: ${response.body}');
        throw Exception(
          'Failed to calculate route: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Route calculation error: $e');
      throw Exception('Error calculating route: $e');
    }
  }
}
