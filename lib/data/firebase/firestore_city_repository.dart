import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/city.dart';
import '../../domain/repositories/city_repository.dart';

class FirestoreCityRepository implements CityRepository {
  FirestoreCityRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<City>> activeCities() async {
    final snap = await _db
        .collection('cities')
        .where('active', isEqualTo: true)
        .get();
    return snap.docs.map((d) => City.fromMap(d.data())).toList(growable: false);
  }
}
