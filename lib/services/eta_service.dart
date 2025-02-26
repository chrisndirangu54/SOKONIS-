import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ETAService {
  final String? apiKey;
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  ETAService(this.apiKey);

  Future<Map<String, dynamic>> calculateETAAndDistance(
      LatLng origin, LatLng destination) async {
    // Handle missing API key before making a request
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('OpenRouteService API key is missing');
    }

    // Prepare the request body for ORS Directions API
    final body = json.encode({
      'coordinates': [
        [origin.longitude, origin.latitude], // ORS expects [lon, lat]
        [destination.longitude, destination.latitude],
      ],
      'units': 'km', // Distance in kilometers
    });

    // Make the HTTP POST request to ORS
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': apiKey!,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Check if the response contains the expected route data
      if (data['routes'] != null &&
          data['routes'].isNotEmpty &&
          data['routes'][0]['summary'] != null) {
        final summary = data['routes'][0]['summary'];
        final durationInSeconds = summary['duration']; // Duration in seconds
        final distanceInMeters =
            summary['distance'] * 1000; // Convert km to meters

        final duration = Duration(seconds: durationInSeconds.round());
        final distanceInKm =
            distanceInMeters / 1000; // Distance already in km from ORS

        return {
          'duration': duration,
          'distance': distanceInKm,
        };
      } else {
        throw Exception('Failed to retrieve ETA or distance from ORS response');
      }
    } else {
      throw Exception(
          'Failed to calculate ETA. Status code: ${response.statusCode}, Body: ${response.body}');
    }
  }
}
