import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grocerry/providers/user_provider.dart';
import '../services/rider_location_service.dart';
import 'package:geocoding/geocoding.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final RiderLocationService riderLocationService;
  final UserProvider userProvider;

  const TrackingScreen({
    super.key,
    required this.orderId,
    required this.riderLocationService,
    required this.userProvider,
  });

  @override
  TrackingScreenState createState() => TrackingScreenState();
}

class TrackingScreenState extends State<TrackingScreen> {
  Stream<LatLng>? _riderLocationStream;
  Set<Polyline> _polylines = {};
  final List<LatLng> _polylinePoints = [];
  StreamSubscription<LatLng>? _locationSubscription;
  LatLng? _currentDeviceLocation;
  LatLng? _userSelectedLocation;
  bool _isLocationSelectedByUser = false;
  late String pinLocation; // Default user location address

  @override
  void initState() {
    super.initState();
    pinLocation = widget.userProvider.pinLocation; // Get default user address
    _initLocationService();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _initLocationService() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Prompt user to enable location services
        _promptEnableLocationServices();
        return; // Exit the method
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      _currentDeviceLocation = await _getCurrentLocation();
      _startLocationStream();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _promptEnableLocationServices() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enable Location Services'),
          content: const Text(
              'Location services are disabled. Please enable them in your device settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Settings'),
              onPressed: () {
                // Close the dialog and open device settings
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<LatLng> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return LatLng(position.latitude, position.longitude);
  }

  void _startLocationStream() {
    _riderLocationStream = widget.riderLocationService
        .getRiderLocationStream(widget.orderId as LocationAccuracy)
        .map((Position position) =>
            LatLng(position.latitude, position.longitude));

    _locationSubscription = _riderLocationStream?.listen((location) {
      _updatePolyline(location);
    });
  }

  void _updatePolyline(LatLng newPoint) {
    setState(() {
      if (_polylinePoints.length > 100) {
        _polylinePoints.removeAt(0); // Performance consideration
      }
      _polylinePoints.add(newPoint);
      _polylines = {
        Polyline(
          polylineId: const PolylineId('riderPath'),
          points: _polylinePoints,
          color: Colors.blue,
          width: 5,
        )
      };
    });
  }

  void _promptLocationChange() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Location'),
          content: const Text(
              'Would you like to select a location on the map or search for an address?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Map'),
              onPressed: () {
                // Allow the user to select a location on the map
                Navigator.of(context).pop(); // Close the dialog
                _enableMapTapSelection(); // Enable map tap functionality
              },
            ),
            TextButton(
              child: const Text('Search Address'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _searchAddress(); // Trigger the address search functionality
              },
            ),
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  bool _isMapTapEnabled = false;

  void _enableMapTapSelection() {
    setState(() {
      _isMapTapEnabled = true;
    });
  }

  void _onMapTap(LatLng point) {
    if (_isMapTapEnabled) {
      setState(() {
        _userSelectedLocation = point;
        _isLocationSelectedByUser = true;
        _isMapTapEnabled = false; // Disable map tap after selecting a location
      });
    }
  }

  void _onClearUserSelection() {
    setState(() {
      _userSelectedLocation = null;
      _isLocationSelectedByUser = false;
    });
  }

  void _searchAddress() async {
    String? address = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String enteredAddress = '';
        return AlertDialog(
          title: const Text('Enter Address'),
          content: TextField(
            autofocus: true,
            onChanged: (value) => enteredAddress = value,
            decoration: const InputDecoration(hintText: "Type an address"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('SEARCH'),
              onPressed: () {
                Navigator.of(context).pop(enteredAddress);
              },
            ),
          ],
        );
      },
    );

    if (address != null && address.isNotEmpty) {
      try {
        LatLng? location = await geocodeAddress(address);
        if (location != null) {
          _onMapTap(location); // Simulate map tap with geocoded location
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address not found.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error geocoding address: $e')),
        );
      }
    }
  }

  Future<LatLng?> geocodeAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  void changeLocation() async {
    _searchAddress(); // Calls search address dialog
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Rider'),
        actions: [
          if (_isLocationSelectedByUser)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _onClearUserSelection,
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchAddress,
          ),
        ],
      ),
      body: (_currentDeviceLocation == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    onTap: _onMapTap,
                    initialCameraPosition: CameraPosition(
                      target: _isLocationSelectedByUser
                          ? _userSelectedLocation!
                          : _currentDeviceLocation!,
                      zoom: 15,
                    ),
                    polylines: _polylines,
                    markers: _buildMarkers(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _promptLocationChange,
                    child: const Text('Change Location'),
                  ),
                ),
              ],
            ),
    );
  }

  Set<Marker> _buildMarkers() {
    return {
      if (_userSelectedLocation != null)
        Marker(
          markerId: const MarkerId('userSelected'),
          position: _userSelectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Selected Location'),
        ),
      if (_polylinePoints.isNotEmpty)
        Marker(
          markerId: const MarkerId('rider'),
          position: _polylinePoints.last,
          infoWindow: const InfoWindow(title: 'Rider Location'),
        ),
      if (!_isLocationSelectedByUser &&
          _currentDeviceLocation != null &&
          widget.userProvider.pinLocation == null)
        Marker(
          markerId: const MarkerId('device'),
          position: _currentDeviceLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
    };
  }
}
