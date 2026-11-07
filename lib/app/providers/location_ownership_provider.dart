import 'package:flutter_riverpod/flutter_riverpod.dart';

final tripOwnsLocationProvider = NotifierProvider<LocationOwnership, bool>(
  LocationOwnership.new,
);

class LocationOwnership extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}
