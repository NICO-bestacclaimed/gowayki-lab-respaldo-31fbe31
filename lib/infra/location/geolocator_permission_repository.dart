import 'package:geolocator/geolocator.dart';
import '../../domain/repositories/location_permission_repository.dart';

class GeolocatorPermissionRepository implements LocationPermissionRepository {
  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.allowed,
        LocationPermission.deniedForever => LocationAccess.permanentlyDenied,
        _ => LocationAccess.denied,
      };
  @override
  Future<LocationAccess> check() async =>
      _map(await Geolocator.checkPermission());
  @override
  Future<LocationAccess> request() async =>
      _map(await Geolocator.requestPermission());
  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();
}
