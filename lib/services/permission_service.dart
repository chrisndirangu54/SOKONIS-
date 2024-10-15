// lib/services/permission_service.dart

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<void> requestLocationPermission() async {
    if (await Permission.location.request().isGranted) {
      // Permission granted
    } else {
      // Permission denied, show a dialog or redirect to settings
      // Handle this case in your UI logic
    }
  }
}
