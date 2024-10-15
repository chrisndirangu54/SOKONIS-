import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryMap extends StatefulWidget {
  final LatLng initialLocation;
  final Stream<LatLng> locationStream;

  const DeliveryMap(
      {super.key, required this.initialLocation, required this.locationStream});

  @override
  DeliveryMapState createState() => DeliveryMapState();
}

class DeliveryMapState extends State<DeliveryMap> {
  GoogleMapController? _controller;
  LatLng _currentLocation = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;

    widget.locationStream.listen((newLocation) {
      _updateDeliveryLocation(newLocation);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation,
        zoom: 14.0,
      ),
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
      },
      markers: {
        Marker(
          markerId: const MarkerId('deliveryLocation'),
          position: _currentLocation,
        ),
      },
    );
  }

  void _updateDeliveryLocation(LatLng newLocation) {
    setState(() {
      _currentLocation = newLocation;
    });

    _controller?.animateCamera(
      CameraUpdate.newLatLng(newLocation),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
