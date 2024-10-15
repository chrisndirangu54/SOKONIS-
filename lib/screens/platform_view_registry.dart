// platform_view_registry.dart

// This file will export the appropriate registry based on the platform.
export 'fake_platform_view_registry.dart' if (dart.library.html) 'dart:ui'
    show platformViewRegistry;
