import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';

class MockGeolocator extends Mock implements GeolocatorPlatform {}

class LocationService {
  final GeolocatorPlatform _geolocator;

  LocationService({GeolocatorPlatform? geolocator})
      : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  Future<Position> getCurrentPosition() {
    return _geolocator.getCurrentPosition();
  }
}

void main() {
  test('Location service returns current position', () async {
    final mockGeolocator = MockGeolocator();

    when(mockGeolocator.getCurrentPosition()).thenAnswer(
      (_) async => Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 30.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ),
    );

    final locationService = LocationService(geolocator: mockGeolocator);
    final position = await locationService.getCurrentPosition();
    expect(position.latitude, 37.7749);
    expect(position.longitude, -122.4194);
  });
}
