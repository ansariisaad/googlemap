import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteCalculator {
  // Replace with your OpenRouteService API key
  static const String _apiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImU3YjNjODhiMDI2NDQ0NjBhNzNmMzdlYzYzMWM0MmY0IiwiaCI6Im11cm11cjY0In0=';
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

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coordinates = data['features'][0]['geometry']['coordinates'];
        final distance =
            data['features'][0]['properties']['segments'][0]['distance'];

        List<LatLng> points = coordinates
            .map<LatLng>(
              (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
            )
            .toList();

        return {'points': points, 'distance': distance};
      } else {
        throw Exception('Failed to calculate route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error calculating route: $e');
    }
  }
}
