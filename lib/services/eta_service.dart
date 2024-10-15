import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ETAService {
  final String? apiKey;

  ETAService(this.apiKey);

  Future<Map<String, dynamic>> calculateETAAndDistance(
      LatLng origin, LatLng destination) async {
    // Handle missing API key before making a request
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('API key is missing');
    }

    final response = await http.get(Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric'
      '&origins=${origin.latitude},${origin.longitude}'
      '&destinations=${destination.latitude},${destination.longitude}'
      '&key=$apiKey',
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Handle potential issues with the response data structure
      if (data['rows'] != null &&
          data['rows'].isNotEmpty &&
          data['rows'][0]['elements'] != null &&
          data['rows'][0]['elements'].isNotEmpty &&
          data['rows'][0]['elements'][0]['duration'] != null &&
          data['rows'][0]['elements'][0]['distance'] != null) {
        final durationInSeconds =
            data['rows'][0]['elements'][0]['duration']['value'];
        final distanceInMeters = data['rows'][0]['elements'][0]['distance']
            ['value']; // Distance in meters

        final duration = Duration(seconds: durationInSeconds);
        final distanceInKm = distanceInMeters / 1000; // Convert to kilometers

        return {
          'duration': duration,
          'distance': distanceInKm,
        };
      } else {
        throw Exception('Failed to retrieve ETA or distance from response');
      }
    } else {
      throw Exception(
          'Failed to calculate ETA. Status code: ${response.statusCode}');
    }
  }
}
