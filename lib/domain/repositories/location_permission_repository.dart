enum LocationAccess { denied, permanentlyDenied, allowed }

abstract interface class LocationPermissionRepository {
  Future<LocationAccess> check();
  Future<LocationAccess> request();
  Future<bool> openSettings();
}
