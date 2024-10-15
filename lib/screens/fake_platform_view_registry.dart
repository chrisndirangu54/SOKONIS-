// fake_platform_view_registry.dart

// A class to simulate the platform view registry in non-web contexts.
class FakePlatformViewRegistry {
  void registerViewFactory(
      String viewTypeId, dynamic Function(int) viewFactory) {
    throw UnsupportedError("Platform view registry in non-web context");
  }
}

// Since this is only used in non-web, we don't define any platformViewRegistry here.
// Instead, this will be used if the web context is not present.
final FakePlatformViewRegistry platformViewRegistry =
    FakePlatformViewRegistry();
